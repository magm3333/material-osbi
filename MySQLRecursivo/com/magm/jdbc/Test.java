package ar.com.magm.jdbc;
/*
 * Creado el 09-mar-2006
 */
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.ResultSet;
import java.sql.ResultSetMetaData;
import java.sql.SQLException;

/**
 * @author Mariano
 * @version 1.0.0 - 09-mar-2006 --- 2.0.0 - 17-abr-2012<br>
 */
public class Test {

	public static void main(String[] args) throws SQLException,
			ClassNotFoundException {


		Class.forName("com.mysql.jdbc.Driver");
		Connection cn = DriverManager.getConnection(
				"jdbc:mysql://localhost:3306/practico", "root", "root");
		SQLRecursivo sqlRec = new SQLRecursivo(cn);
		String consultaInicial = "SELECT idPadre,idHijo FROM arbol where idPadre=2";
		String aliasTablaPadre = "padre";
		String consultaRecursiva = "SELECT a.idPadre,a.idHijo FROM arbol a,//TablaPadre// WHERE a.idPadre=padre.idHijo";
		ResultSet rs = sqlRec.recursivo(consultaInicial, aliasTablaPadre,
				consultaRecursiva, null);
		showResultSet(rs);
	}

	private static void showResultSet(ResultSet rs) throws SQLException {
		String lineas = "-------------------------------------------------------------------";
		ResultSetMetaData rsm = rs.getMetaData();
		StringBuilder sb = new StringBuilder();
		for (int t = 0; t < rsm.getColumnCount(); t++) {
			System.out.print(rsm.getColumnName(t + 1) + "\t");
			sb.append(lineas.substring(0, rsm.getColumnName(t + 1).length())
					+ "\t");
		}
		System.out.println(sb.toString());
		int count = 0;
		while (rs.next()) {
			for (int t = 0; t < rsm.getColumnCount(); t++) {
				System.out.print(rs.getString(t + 1) + "\t");
			}
			count++;
			System.out.println();
		}
		System.out.println(count + " filas.");
	}

}
