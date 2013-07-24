Esta clase está basada en la idea de recursividad de DB2.
La clase ar.com.magm.jdbc.SQLRecursivo permite implementar recursividad en MySQL. 
Aún no está bien testeada la indexación que es fundamental cuando se trabaja con muchos datos

La tabla con la que funciona la demo (clase Test) es:

CREATE TABLE `practico`.`arbol` ( 
    `idPadre` integer NOT NULL,
    `idHijo` integer NOT NULL, 
    `cantidad` integer NOT NULL, 
    PRIMARY KEY (`idPadre`, `idHijo`) 
)

Agunos datos:

INSERT INTO `practico`.`arbol` VALUES  
 (3,8,1),
 (5,6,3),
 (2,5,2),
 (1,4,2),
 (1,3,2),
 (1,2,1);
 
 Forma el siguiente árbol:
 
 1
 +--2
 |  +--5
 |     +--6
 |
 +--3
 |  +--8
 |
 +--4

El uso es muy simple, solo hay que crear una instancia de la clase SQLRecursivo, el constructor pide
una conexión JDBC, ejemplo;

SQLRecursivo sqlRec = new SQLRecursivo(cn);

Luego llamar al método recursivo(consultaInicial, aliasTablaPadre, consultaRecursiva, indexKey)

Este método retornará el resultado en forma de ResultSet.

Los parámetros son:

@param consultaInicial 
	 consulta que produce la población inicial de datos.
@param aliasTablaPadre 
	 alias que se utilizará en la consulta recursiva para la tabla padre
@param consultaRecursiva 
	 consulta que obtiene el resto de los datos en forma recursiva. 
         Esta consulta contiene la lógica de corte de cotrol.
	 Se hace referencia a la tabla padre con: //TablaPadre//
@param indexKey
         representa la clave del índice/indices que se crearán sobre la
	 tabla padre, la forma es: 
	 (opciones indice1)\t(clave indice1)\n(opciones indice2)\t(clave indice2), 
	 en otras palabras el \n determina la cantidad de índices a crear, 
	 el \t separa las opciones de la clave. 
	 Para no crear ningún índice enviar "" o null. 
	 Ejemplo: 
	   UNIQUE CLUSTERED\tidHijo,idFiltroArbol,idFiltroGeneral\nNONCLUSTERED\tcc 
	 Se crearán: 
	   CREATE UNIQUE CLUSTERED INDEX IX0_##TablaPadre ON ##TablaPadre (idHijo,idFiltroArbol,idFiltroGeneral) 
	   y 
	   CREATE NONCLUSTERED INDEX IX1_TablaPadre ON ##TablaPadre (cc)
	 

Se recomienda probar en el test las siguientes consultas:

String consultaInicial = "SELECT idPadre,idHijo FROM arbol where idPadre=1"; //Obtiene el árbol completo

para obtener el árbol completo o:
String consultaInicial = "SELECT idPadre,idHijo FROM arbol where idPadre=2"; //Obtiene el subarbol del nodo 2

En la consulta recursiva se puede (y en general se debe) hacer referencia a la tabla padre (consulta inicial),
esto se hace con la expresión: //TablaPadre//, esto se puede ver en el ejemplo. La tabla tiene un alias, 
que este ejemplo es 'padre' y es el segundo argumento del método recursivo.  Por ello en la consulta se ve:  
... a.idPadre=padre.idHijo


String consultaRecursiva = "SELECT a.idPadre,a.idHijo FROM arbol a,//TablaPadre// WHERE a.idPadre=padre.idHijo";

Enjoy

Mariano
