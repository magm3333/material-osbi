package ar.com.magm.jdbc;

/*
 * Creado el 08-mar-2006
 */

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.ResultSetMetaData;
import java.sql.SQLException;
import java.sql.Statement;
import java.sql.Types;

/**
 * @author Mariano
 * @version 1.0.0 - 08-mar-2006 --- 2.0.0 - 17-abr-2012<br>
 * 
 *          Permite realizar consultas recursivas utilizando MySQL
 */
public class SQLRecursivo {

	private Connection cn = null;

	private Statement stm = null;

	private ResultSet rsT = null;

	private String tablaTemp = null;

	private String tablaTempUnaFila = null;

	private String consultaRecursiva = null;

	private String indexKey = null;

	public SQLRecursivo(Connection cn) throws SQLException {
		this.cn = cn;
	}

	/**
	 * 
	 * @param consultaInicial 
	 *            consulta que produce la población inicial de datos.
	 * @param aliasTablaPadre 
	 *            alias que se utilizará en la consulta recursiva para la tabla padre
	 * @param consultaRecursiva 
	 *            consulta que obtiene el resto de los datos en forma recursiva. 
	 *            Esta consulta contiene la lógica de corte de cotrol.
	 *            Se hace referencia a la tabla padre con: //TablaPadre//
	 * @param indexKey
	 *            representa la clave del índice/indices que se crearán sobre la
	 *            tabla padre, la forma es: (opciones indice1)\t(clave
	 *            indice1)\n(opciones indice2)\t(clave indice2), en otras
	 *            palabras el \n determina la cantidad de índices a crear, el \t
	 *            separa las opciones de la clave. Para no crear ningún índice
	 *            enviar "" o null. Ejemplo: UNIQUE
	 *            CLUSTERED\tidHijo,idFiltroArbol
	 *            ,idFiltroGeneral\nNONCLUSTERED\tcc crearán : CREATE UNIQUE
	 *            CLUSTERED INDEX IX0_##TablaPadre ON ##TablaPadre
	 *            (idHijo,idFiltroArbol,idFiltroGeneral) y CREATE NONCLUSTERED
	 *            INDEX IX1_TablaPadre ON ##TablaPadre (cc)
	 * 
	 * @return
	 * @throws SQLException
	 */
	public ResultSet recursivo(String consultaInicial, String aliasTablaPadre,
			String consultaRecursiva, String indexKey) throws SQLException {
		this.indexKey = indexKey;
		cn.setAutoCommit(false);
		if (stm == null)
			stm = cn.createStatement(ResultSet.TYPE_SCROLL_SENSITIVE,
					ResultSet.CONCUR_UPDATABLE);

		tablaTemp = "Tt" + (int) (Math.random() * 100000000) + "_"
				+ (int) (Math.random() * 100000000);
		tablaTempUnaFila = "Uf" + (int) (Math.random() * 100000000) + "_"
				+ (int) (Math.random() * 100000000);

		this.consultaRecursiva = consultaRecursiva.replaceFirst(
				"//TablaPadre//", tablaTempUnaFila + " as " + aliasTablaPadre
						+ " ");
		// Se crea la población inicial
		int cantFilas = crearTablaTemp(tablaTemp, consultaInicial, "");

		// Si no hay filas en la población inicial se retorna un resultset con 0 filas
		rsT = stm.executeQuery("SELECT * FROM " + tablaTemp);

		if (cantFilas == 0)
			return rsT;

		recursivoInterno(0, cantFilas);
		cn.commit();

		return stm.executeQuery("SELECT * FROM " + tablaTemp);

	}

	private PreparedStatement pstmUpdate = null;

	private void recursivoInterno(int puntero, int total) throws SQLException {
		ResultSet rsUF = null;
		if (puntero == 0) {
			// Se crea la tabla temporal para una fila, debe estar vacia
			crearTablaTemp(tablaTempUnaFila, "SELECT * FROM " + tablaTemp
					+ " WHERE 3=2", indexKey);
		}
		if (puntero < total) {
			// No se ha terminado de recorrer la tabla Acumulativa
			rsT.absolute(++puntero); // Próxima fila

			// Se elimina la Fila de la tabla desde una fila temporal
			cn.createStatement().executeUpdate(
					"DELETE FROM " + tablaTempUnaFila);

			insertarFilaActual(tablaTempUnaFila);

			if (puntero == 1) { // Soluciona el ordenamiento
				String tablaTemp1 = "Tt" + (int) (Math.random() * 100000000)
						+ "_" + (int) (Math.random() * 100000000);
				crearTablaTemp(tablaTemp1, "SELECT * FROM " + tablaTemp
						+ " WHERE 3=2", "");
				cn.createStatement().execute(
						"INSERT INTO " + tablaTemp1 + " SELECT * FROM "
								+ tablaTemp);
				cn.createStatement().execute("DROP TABLE " + tablaTemp);
				tablaTemp = tablaTemp1;

			}

			System.out.println(consultaRecursiva);
			total += cn.createStatement().executeUpdate(
					"INSERT INTO " + tablaTemp + " " + consultaRecursiva);
			rsT.close();
			rsT = stm.executeQuery("SELECT * FROM " + tablaTemp);
			recursivoInterno(puntero, total);
		}

	}

	private void insertarFilaActual(String tabla) throws SQLException {
		String sql = "INSERT INTO " + tabla + " VALUES (";
		ResultSetMetaData rsm = rsT.getMetaData();
		for (int c = 1; c <= rsm.getColumnCount(); c++) {
			String separador = getSeparadorPorTipo(rsm.getColumnType(c));
			sql += separador + rsT.getString(c) + separador
					+ (c < rsm.getColumnCount() ? "," : "");
		}
		sql += ")";
		cn.createStatement().execute(sql);
	}

	private String getSeparadorPorTipo(int tipo) {
		String result = "";
		switch (tipo) {
		case Types.CHAR:
		case Types.CLOB:
		case Types.DATE:
		case Types.LONGVARCHAR:
		case Types.TIME:
		case Types.TIMESTAMP:
		case Types.VARCHAR:
			result = "'";
		}
		return result;
	}

	private int crearTablaTemp(String nombre, String instruccion,
			String indexKey) throws SQLException {
		int filas = 0;

		String sqlTabla = "CREATE TEMPORARY TABLE "+nombre+" " + instruccion;
		System.out.println(sqlTabla);
		filas = cn.createStatement().executeUpdate(sqlTabla);
		if (indexKey != null && indexKey.length() != 0) {
			String[] lineasIdx = indexKey.split("\n");
			int idxNum = 0;
			for (String ln : lineasIdx) {
				String[] partsIdx = ln.split("\t");
				String sqlIndex = "CREATE " + partsIdx[0] + " INDEX IX"
						+ (idxNum++) + "_" + nombre + " ON " + nombre + " ("
						+ partsIdx[1] + ")";
				cn.createStatement().execute(sqlIndex);

				System.out.println("Indice creado " + sqlIndex);
			}

		}
		System.out.println(filas);
		return filas;
	}

}

