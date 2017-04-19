import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.ResultSet;

public class TestPDIDS {

	public static void main(String[] args) throws Exception {
		Class.forName("org.pentaho.di.core.jdbc.ThinDriver");
		Connection cn = DriverManager.getConnection(
				"jdbc:pdi://localhost:8088/kettle", 
				"cluster", "cluster");
		String sql = "SELECT nombre,so,cancion "+
					 "FROM listaPersonas "+
					 "WHERE edad<50 ORDER BY edad";
		ResultSet rs = cn.createStatement().executeQuery(sql);
		System.out.println("Nombre\t\tSO\tCanción");
		System.out.println("------\t\t--\t-------");
		while (rs.next()) {
			String nombre = rs.getString(1);
			if (nombre.length() > 7)
				nombre += "\t";
			else
				nombre += "\t\t";
			System.out.println(nombre + rs.getString(2) + 
					"\t" + rs.getString(3));
		}
	}

}
