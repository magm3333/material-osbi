#!/bin/bash

# Mayormente obtenido de estas fuentes:
# https://gist.github.com/jgeurts/3112065
# https://github.com/janoside/ubuntu-statsd-graphite-setup
# http://ericfarkas.com/posts/statsd-graphite-ubuntu/
# https://gist.github.com/chalmerj/1492384
# https://gist.github.com/perssontm/1326359


# Instalamos node.js a traves de PPA (para statsd)
sudo apt-get install python-software-properties --yes
sudo apt-add-repository ppa:chris-lea/node.js --yes
sudo apt-get update --yes
sudo apt-get install nodejs npm --yes


# Instalamos multiples paquetes
sudo apt-get install git apache2 apache2-mpm-worker apache2-utils apache2.2-bin apache2.2-common libapache2-mod-wsgi libaprutil1-ldap memcached python-cairo python-cairo-dev python-django python-ldap python-memcache python-pysqlite2 sqlite3 erlang-os-mon erlang-snmp rabbitmq-server bzr expect ssh python-setuptools python-dev python-pip libcairo2 libcairo2-dev --yes


# Obtenemos el ultimo pip
sudo pip install --upgrade pip


# Instalamos carbon y las dependencias de graphite
cat >> /tmp/graphite_reqs.txt << EOF
django==1.3
python-memcached
django-tagging
twisted
whisper==0.9.10
carbon==0.9.10
graphite-web==0.9.10
EOF

sudo pip install -r /tmp/graphite_reqs.txt


# Configuramos carbon
cd /opt/graphite/conf/
sudo cp carbon.conf.example carbon.conf
cat >> /tmp/storage-schemas.conf << EOF
# Schema definitions for Whisper files. Entries are scanned in order,
# and first match wins. This file is scanned for changes every 60 seconds.
#
# [name]
# pattern = regex
# retentions = timePerPoint:timeToStore, timePerPoint:timeToStore, ...
[stats]
priority = 110
pattern = ^stats\..*
retentions = 10s:6h,1m:7d,10m:1y
EOF

sudo cp /tmp/storage-schemas.conf storage-schemas.conf


# Nos aseguramos de que exista el directorio de logs para la webapp
sudo mkdir -p /opt/graphite/storage/log/webapp


# Copiamos local_settings e inicializamos la base de datos, en este paso creamos el super usuario de django (opcional)
cd /opt/graphite/webapp/graphite/
sudo cp local_settings.py.example local_settings.py
sudo python manage.py syncdb


# Obtenemos y configuramos statsd
cd /opt && sudo git clone git://github.com/etsy/statsd.git
cat >> /tmp/localConfig.js << EOF
{
graphitePort: 2003
, graphiteHost: "127.0.0.1"
, port: 8125
}
EOF

sudo cp /tmp/localConfig.js /opt/statsd/localConfig.js


# Configuramos apache
sudo cp /etc/apache2/sites-available/default /etc/apache2/sites-available/default.bak
sudo cat > /etc/apache2/sites-available/default << EOF
# This needs to be in your server's config somewhere, probably
# the main httpd.conf
# NameVirtualHost *:80

# This line also needs to be in your server's config.
# LoadModule wsgi_module modules/mod_wsgi.so

# You need to manually edit this file to fit your needs.
# This configuration assumes the default installation prefix
# of /opt/graphite/, if you installed graphite somewhere else
# you will need to change all the occurances of /opt/graphite/
# in this file to your chosen install location.

<IfModule !wsgi_module.c>
    LoadModule wsgi_module modules/mod_wsgi.so
</IfModule>

# XXX You need to set this up!
# Read http://code.google.com/p/modwsgi/wiki/ConfigurationDirectives#WSGISocketPrefix
#WSGISocketPrefix run/wsgi
#WSGISocketPrefix /etc/httpd/wsgi/
WSGISocketPrefix /var/run/apache2/wsgi

<VirtualHost *:80>
        ServerName graphite
        DocumentRoot "/opt/graphite/webapp"
        ErrorLog /opt/graphite/storage/log/webapp/error.log
        CustomLog /opt/graphite/storage/log/webapp/access.log common

        # I've found that an equal number of processes & threads tends
        # to show the best performance for Graphite (ymmv).
        WSGIDaemonProcess graphite processes=5 threads=5 display-name='%{GROUP}' inactivity-timeout=120
        WSGIProcessGroup graphite
        WSGIApplicationGroup %{GLOBAL}
        WSGIImportScript /opt/graphite/conf/graphite.wsgi process-group=graphite application-group=%{GLOBAL}

        # XXX You will need to create this file! There is a graphite.wsgi.example
        # file in this directory that you can safely use, just copy it to graphite.wgsi
        WSGIScriptAlias / /opt/graphite/conf/graphite.wsgi

        Alias /content/ /opt/graphite/webapp/content/
        <Location "/content/">
                SetHandler None
        </Location>

        # XXX In order for the django admin site media to work you
        # must change @DJANGO_ROOT@ to be the path to your django
        # installation, which is probably something like:
        # /usr/lib/python2.6/site-packages/django
        #Alias /media/ "@DJANGO_ROOT@/contrib/admin/media/"
        Alias /media/ "/usr/lib/python2.7/dist-packages/django/contrib/admin/media/"
        <Location "/media/">
                SetHandler None
        </Location>

        # The graphite.wsgi file has to be accessible by apache. It won't
        # be visible to clients because of the DocumentRoot though.
        <Directory /opt/graphite/conf/>
                Order deny,allow
                Allow from all
        </Directory>
</VirtualHost>
EOF


# Creamos un init-script para carbon-cache
sudo cat >> /etc/init.d/carbon-cache << "EOF"
#! /bin/sh
### BEGIN INIT INFO
# Provides:          carbon-cache
# Required-Start:    $remote_fs $syslog
# Required-Stop:     $remote_fs $syslog
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: carbon-cache init script
# Description:       An init script for Graphite's carbon-cache daemon.
### END INIT INFO

# Author: Jeremy Chalmer
#
# This init script was written for Ubuntu 11.10 using start-stop-daemon.
# 
# Note: Make sure you set the USER field in /opt/graphite/conf/carbon.conf to be the same
#     user that owns the /opt/graphite/storage/ folder. Carbon-cache will be invoked as that
#     username on start.
#
# Enable with update-rc.d carbon-cache defaults


# Source init-functions:
#source /lib/lsb/init-functions
. /lib/lsb/init-functions

# PATH should only include /usr/* if it runs after the mountnfs.sh script
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# Path to Graphite
GRAPHITE_HOME=/opt/graphite

# Name of executable daemon
NAME=carbon-cache
DESC=carbon-cache

#Carbon has its own logging facility, by default in /opt/graphite/storage/log/carbon-cache-*

# Path to Executable
DAEMON=$GRAPHITE_HOME/bin/carbon-cache.py

# NOTE: This is a hard-coded PID file, based on carbon-cache.py. If you have more the one carbon-cache
#    instance running on this machine, you'll need to figure out a better way to calculate the PID file.
PIDFILE=/opt/graphite/storage/carbon-cache-a.pid

SCRIPTNAME=/etc/init.d/$NAME

# Exit if the package is not installed
if [ ! -x "$DAEMON" ]; then {
    echo "Couldn't find $DAEMON or not executable"
    exit 99
}
fi

# Load the VERBOSE setting and other rcS variables
[ -f /etc/default/rcS ] && . /etc/default/rcS

#
# Function that starts the daemon/service
#
do_start()
{
    # Return
    #   0 if daemon has been started
    #   1 if daemon was already running
    #   2 if daemon could not be started
    
        # Test to see if the daemon is already running - return 1 if it is. 
    start-stop-daemon --start --pidfile $PIDFILE \
        --exec $DAEMON --test -- start > /dev/null || return 1
        
        # Start the daemon for real, return 2 if failed
    start-stop-daemon --start --pidfile $PIDFILE \
        --exec $DAEMON -- start > /dev/null || return 2
}

#
# Function that stops the daemon/service
#
do_stop() {
    # Return
    #   0 if daemon has been stopped
    #   1 if daemon was already stopped
    #   2 if daemon could not be stopped
    #   other if a failure occurred
    log_daemon_msg "Stopping $DESC" "$NAME"
    start-stop-daemon --stop --signal 2 --retry 5 --quiet --pidfile $PIDFILE
    RETVAL="$?"
    [ "$RETVAL" = 2 ] && return 2

        # Delete the exisitng PID file
    if [ -e "$PIDFILE" ]; then {
        rm $PIDFILE
    }
        fi
        
        return "$RETVAL"
}


# Display / Parse Init Options
case "$1" in
  start)
      [ "$VERBOSE" != no ] && log_daemon_msg "Starting $DESC" "$NAME"
      do_start
      case "$?" in
        0|1) [ "$VERBOSE" != no ] && log_end_msg 0 ;;
        2) [ "$VERBOSE" != no ] && log_end_msg 1 ;;
      esac
  ;;
  stop)
      [ "$VERBOSE" != no ] && log_daemon_msg "Stopping $DESC" "$NAME"
      do_stop
      case "$?" in
        0|1) [ "$VERBOSE" != no ] && log_end_msg 0 ;;
        2) [ "$VERBOSE" != no ] && log_end_msg 1 ;;
      esac
  ;;
  restart)
      log_daemon_msg "Restarting $DESC" "$NAME"
        do_stop
          case "$?" in
            0|1)
            do_start
            case "$?" in
              0) log_end_msg 0 ;;
              1) log_end_msg 1 ;; # Old process is still running
              *) log_end_msg 1 ;; # Failed to start
            esac
       ;;
    *)
      # Failed to stop
    log_end_msg 1
    ;;
  esac
  ;;
  status)
      if [ -s "$PIDFILE" ]; then
          pid=`cat "$PIDFILE"`
          kill -0 $pid >/dev/null 2>&1
          if [ "$?" = "0" ]; then
              echo "$NAME is running: pid $pid."
              RETVAL=0
          else
              echo "Couldn't find pid $pid for $NAME."
              RETVAL=1
          fi
      else
          echo "$NAME is stopped (no pid file)."
          RETVAL=1
      fi
  ;;
  *)
  echo "Usage: $SCRIPTNAME {start|stop|restart|status}" >&2
  exit 3
  ;;
esac
:
 
EOF

sudo update-rc.d carbon-cache defaults
chmod +x /etc/init.d/carbon-cache


# Nos aseguramos de que exista el directorio de logs para statsd
sudo mkdir -p /var/log/statsd/


# Creamos un init-script para statsd
sudo cat >> /etc/init.d/statsd << "EOF"
#! /bin/sh

# Do NOT "set -e"

PATH=$PATH:/usr/local/bin:/usr/bin:/bin
NODE_BIN=$(which nodejs||which node)

if [ ! -x "$NODE_BIN" ]; then
  echo "Can't find executable nodejs or node in PATH=$PATH"
  exit 1
fi

# PATH should only include /usr/* if it runs after the mountnfs.sh script
PATH=/sbin:/usr/sbin:/bin:/usr/bin
DESC="StatsD"
NAME=statsd
DAEMON=$NODE_BIN
DAEMON_ARGS="/opt/statsd/stats.js /opt/statsd/localConfig.js 2>&1 >> /var/log/statsd/statsd.log "
PIDFILE=/var/run/$NAME.pid
SCRIPTNAME=/etc/init.d/$NAME

# Exit if the package is not installed
# [ -x "$DAEMON" ] || exit 0

# Read configuration variable file if it is present
[ -r /etc/default/$NAME ] && . /etc/default/$NAME

# Load the VERBOSE setting and other rcS variables
. /lib/init/vars.sh

# Define LSB log_* functions.
# Depend on lsb-base (>= 3.0-6) to ensure that this file is present.
. /lib/lsb/init-functions

#
# Function that starts the daemon/service
#
do_start()
{
    # Return
    #   0 if daemon has been started
    #   1 if daemon was already running
    #   2 if daemon could not be started
    start-stop-daemon --start --quiet --pidfile $PIDFILE --exec $DAEMON --test > /dev/null \
        || return 1
    start-stop-daemon --start --quiet -m --pidfile $PIDFILE --startas $DAEMON --background -- \
        $DAEMON_ARGS > /dev/null 2> /var/log/$NAME-stderr.log \
        || return 2
    # Add code here, if necessary, that waits for the process to be ready
    # to handle requests from services started subsequently which depend
    # on this one.  As a last resort, sleep for some time.
}

#
# Function that stops the daemon/service
#
do_stop()
{
    # Return
    #   0 if daemon has been stopped
    #   1 if daemon was already stopped
    #   2 if daemon could not be stopped
    #   other if a failure occurred
    start-stop-daemon --stop --quiet --retry=0/0/KILL/5 --pidfile $PIDFILE 
    RETVAL="$?"
    [ "$RETVAL" = 2 ] && return 2
    # Wait for children to finish too if this is a daemon that forks
    # and if the daemon is only ever run from this initscript.
    # If the above conditions are not satisfied then add some other code
    # that waits for the process to drop all resources that could be
    # needed by services started subsequently.  A last resort is to
    # sleep for some time.
    start-stop-daemon --stop --quiet --oknodo --retry=0/30/KILL/5 --exec $DAEMON
    [ "$?" = 2 ] && return 2
    # Many daemons don't delete their pidfiles when they exit.
    rm -f $PIDFILE
    return "$RETVAL"
}

#
# Function that sends a SIGHUP to the daemon/service
#
do_reload() {
    #
    # If the daemon can reload its configuration without
    # restarting (for example, when it is sent a SIGHUP),
    # then implement that here.
    #
    start-stop-daemon --stop --signal 1 --quiet --pidfile $PIDFILE --name $NAME
    return 0
}

case "$1" in
  start)
    [ "$VERBOSE" != no ] && log_daemon_msg "Starting $DESC" "$NAME"
    do_start
    case "$?" in
        0|1) [ "$VERBOSE" != no ] && log_end_msg 0 ;;
        2) [ "$VERBOSE" != no ] && log_end_msg 1 ;;
    esac
    ;;
  stop)
    [ "$VERBOSE" != no ] && log_daemon_msg "Stopping $DESC" "$NAME"
    do_stop
    case "$?" in
        0|1) [ "$VERBOSE" != no ] && log_end_msg 0 ;;
        2) [ "$VERBOSE" != no ] && log_end_msg 1 ;;
    esac
    ;;
  #reload|force-reload)
    #
    # If do_reload() is not implemented then leave this commented out
    # and leave 'force-reload' as an alias for 'restart'.
    #
    #log_daemon_msg "Reloading $DESC" "$NAME"
    #do_reload
    #log_end_msg $?
    #;;
  restart|force-reload)
    #
    # If the "reload" option is implemented then remove the
    # 'force-reload' alias
    #
    log_daemon_msg "Restarting $DESC" "$NAME"
    do_stop
    case "$?" in
      0|1)
        do_start
        case "$?" in
            0) log_end_msg 0 ;;
            1) log_end_msg 1 ;; # Old process is still running
            *) log_end_msg 1 ;; # Failed to start
        esac
        ;;
      *)
          # Failed to stop
        log_end_msg 1
        ;;
    esac
    ;;
  *)
    #echo "Usage: $SCRIPTNAME {start|stop|restart|reload|force-reload}" >&2
    echo "Usage: $SCRIPTNAME {start|stop|restart|force-reload}" >&2
    exit 3
    ;;
esac

:
 
EOF

sudo update-rc.d statsd defaults
chmod +x /etc/init.d/statsd


#Activamos la configuracion de graphite para WSGI y acomodamos los permisos para apache
sudo cp /opt/graphite/conf/graphite.wsgi.example /opt/graphite/conf/graphite.wsgi
chown www-data:root /opt/graphite/storage/ -R
chown www-data:root /var/log/statsd/ -R


#Reiniciamos servicios
sudo /etc/init.d/apache2 restart
sudo /etc/init.d/carbon-cache restart
sudo /etc/init.d/statsd restart



