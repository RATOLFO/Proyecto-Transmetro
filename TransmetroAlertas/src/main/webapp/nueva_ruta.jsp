<%@page contentType="text/html" pageEncoding="UTF-8"%>
<%@page import="java.sql.*"%>
<%@page import="java.util.*"%>
<%@page import="java.math.BigDecimal"%>
<%!
    static String h(String s) {
        if (s == null) return "";
        return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace("\"", "&quot;").replace("'", "&#39;");
    }
    static String js(String s) {
        if (s == null) return "";
        return s.replace("\\", "\\\\").replace("\"", "\\\"").replace("'", "\\'").replace("\r", "").replace("\n", " ");
    }
    static String t(String s) {
        return s == null ? "" : s.trim();
    }
    static void asegurarColumnaPiloto(Connection con) {
        try (Statement st = con.createStatement()) {
            st.executeUpdate("ALTER TABLE rutas_operativas ADD COLUMN id_piloto INT DEFAULT NULL");
        } catch (SQLException ignorar) {}
    }
%>
<%
    // Seguridad: Solo Administrador
    String rolActual = (String) session.getAttribute("rol");
    if (session.getAttribute("usuarioValido") == null || !"admin".equals(rolActual)) {
        response.sendRedirect("index.jsp");
        return;
    }

    String dbUrl = "jdbc:mysql://192.168.15.135:3306/transmetro_db";
    String dbUser = "admin";
    String dbPass = "admin123";
    String mensaje = "";
    String tipoMensaje = "exito";

    Class.forName("com.mysql.cj.jdbc.Driver");
    try (Connection conInit = DriverManager.getConnection(dbUrl, dbUser, dbPass)) {
        asegurarColumnaPiloto(conInit);
    } catch (Exception ignorar) {}

    // PROCESAMIENTO POST: CREAR RUTA COMPLETA CON PARQUEO, PILOTO, ESTACIONES, MOLINETES Y KILOMETRAJE
    if ("POST".equalsIgnoreCase(request.getMethod())) {
        request.setCharacterEncoding("UTF-8");
        Connection con = null;
        try {
            con = DriverManager.getConnection(dbUrl, dbUser, dbPass);
            con.setAutoCommit(false);

            String nombreRuta = t(request.getParameter("nombre_ruta"));
            int idMain = Integer.parseInt(t(request.getParameter("id_vehiculo_main")));
            int idBackup = Integer.parseInt(t(request.getParameter("id_vehiculo_backup")));
            String strExtra = t(request.getParameter("id_vehiculo_extra"));
            Integer idExtra = !strExtra.isEmpty() ? Integer.parseInt(strExtra) : null;

            String strPiloto = t(request.getParameter("id_piloto"));
            Integer idPiloto = !strPiloto.isEmpty() ? Integer.parseInt(strPiloto) : null;

            if (nombreRuta.isEmpty()) {
                throw new Exception("El nombre comercial de la ruta es obligatorio.");
            }
            if (idMain == idBackup || (idExtra != null && (idMain == idExtra || idBackup == idExtra))) {
                throw new Exception("Un mismo vehículo físico no puede ocupar dos roles simultáneos en la ruta.");
            }

            // Actualizar parqueos base si el administrador los ajustó en el formulario
            String pqMainStr = t(request.getParameter("parqueo_main"));
            String pqBackupStr = t(request.getParameter("parqueo_backup"));
            String pqExtraStr = t(request.getParameter("parqueo_extra"));
            try (PreparedStatement psUpdPq = con.prepareStatement("UPDATE flota_vehiculos SET id_parqueo = ? WHERE id_vehiculo = ?")) {
                if (!pqMainStr.isEmpty()) {
                    psUpdPq.setInt(1, Integer.parseInt(pqMainStr));
                    psUpdPq.setInt(2, idMain);
                    psUpdPq.executeUpdate();
                }
                if (!pqBackupStr.isEmpty()) {
                    psUpdPq.setInt(1, Integer.parseInt(pqBackupStr));
                    psUpdPq.setInt(2, idBackup);
                    psUpdPq.executeUpdate();
                }
                if (idExtra != null && !pqExtraStr.isEmpty()) {
                    psUpdPq.setInt(1, Integer.parseInt(pqExtraStr));
                    psUpdPq.setInt(2, idExtra);
                    psUpdPq.executeUpdate();
                }
            }

            // Procesar estaciones limpias
            String rawEstaciones = t(request.getParameter("estaciones"));
            String[] partesEst = rawEstaciones.split(",");
            List<String> listaEstLimpia = new ArrayList<>();
            for (String p : partesEst) {
                String limpia = p.trim();
                if (!limpia.isEmpty()) listaEstLimpia.add(limpia);
            }
            if (listaEstLimpia.size() < 2) {
                throw new Exception("La ruta debe contar con al menos 2 estaciones (Origen y Destino).");
            }
            String estacionesUnidas = String.join(", ", listaEstLimpia);

            String hs1 = t(request.getParameter("hs1"));
            String hl1 = t(request.getParameter("hl1"));
            String hs2 = t(request.getParameter("hs2")).isEmpty() ? null : t(request.getParameter("hs2"));
            String hl2 = t(request.getParameter("hl2")).isEmpty() ? null : t(request.getParameter("hl2"));
            String hs3 = t(request.getParameter("hs3")).isEmpty() ? null : t(request.getParameter("hs3"));
            String hl3 = t(request.getParameter("hl3")).isEmpty() ? null : t(request.getParameter("hl3"));
            String hs4 = t(request.getParameter("hs4")).isEmpty() ? null : t(request.getParameter("hs4"));
            String hl4 = t(request.getParameter("hl4")).isEmpty() ? null : t(request.getParameter("hl4"));
            String hs5 = t(request.getParameter("hs5")).isEmpty() ? null : t(request.getParameter("hs5"));
            String hl5 = t(request.getParameter("hl5")).isEmpty() ? null : t(request.getParameter("hl5"));
            String hs6 = t(request.getParameter("hs6")).isEmpty() ? null : t(request.getParameter("hs6"));
            String hl6 = t(request.getParameter("hl6")).isEmpty() ? null : t(request.getParameter("hl6"));

            // 1. Insertar Ruta Operativa
            int idNuevaRuta = 0;
            try (PreparedStatement psRuta = con.prepareStatement(
                    "INSERT INTO rutas_operativas (nombre_ruta, id_vehiculo_main, id_vehiculo_backup, id_vehiculo_extra, id_piloto, lista_estaciones, " +
                    "hora_salida_1, hora_llegada_1, hora_salida_2, hora_llegada_2, hora_salida_3, hora_llegada_3, " +
                    "hora_salida_4, hora_llegada_4, hora_salida_5, hora_llegada_5, hora_salida_6, hora_llegada_6) " +
                    "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
                    Statement.RETURN_GENERATED_KEYS)) {
                psRuta.setString(1, nombreRuta);
                psRuta.setInt(2, idMain);
                psRuta.setInt(3, idBackup);
                if (idExtra != null) psRuta.setInt(4, idExtra); else psRuta.setNull(4, Types.INTEGER);
                if (idPiloto != null) psRuta.setInt(5, idPiloto); else psRuta.setNull(5, Types.INTEGER);
                psRuta.setString(6, estacionesUnidas);
                psRuta.setString(7, hs1); psRuta.setString(8, hl1);
                psRuta.setString(9, hs2); psRuta.setString(10, hl2);
                psRuta.setString(11, hs3); psRuta.setString(12, hl3);
                psRuta.setString(13, hs4); psRuta.setString(14, hl4);
                psRuta.setString(15, hs5); psRuta.setString(16, hl5);
                psRuta.setString(17, hs6); psRuta.setString(18, hl6);
                psRuta.executeUpdate();
                try (ResultSet rsKeys = psRuta.getGeneratedKeys()) {
                    if (rsKeys.next()) idNuevaRuta = rsKeys.getInt(1);
                }
            }

            // Marcar unidades asignadas como 'En Ruta'
            try (PreparedStatement psEstadoVeh = con.prepareStatement("UPDATE flota_vehiculos SET estado = 'En Ruta' WHERE id_vehiculo = ?")) {
                psEstadoVeh.setInt(1, idMain); psEstadoVeh.executeUpdate();
                psEstadoVeh.setInt(1, idBackup); psEstadoVeh.executeUpdate();
                if (idExtra != null) { psEstadoVeh.setInt(1, idExtra); psEstadoVeh.executeUpdate(); }
            }

            // 2. Sincronizar Estaciones Físicas, Catálogo y Molinetes / Guardias (RN05)
            String[] arrNombresEst = request.getParameterValues("est_nombre");
            String[] arrLatEst = request.getParameterValues("est_lat");
            String[] arrLonEst = request.getParameterValues("est_lon");
            String[] arrPuertaEst = request.getParameterValues("est_puerta");
            String[] arrGuardiaEst = request.getParameterValues("est_guardia");
            String[] arrTurnoEst = request.getParameterValues("est_turno");

            if (arrNombresEst != null) {
                for (int i = 0; i < arrNombresEst.length; i++) {
                    String nomEst = t(arrNombresEst[i]);
                    if (nomEst.isEmpty()) continue;
                    String lat = (arrLatEst != null && i < arrLatEst.length && !t(arrLatEst[i]).isEmpty()) ? t(arrLatEst[i]) : "14.6349";
                    String lon = (arrLonEst != null && i < arrLonEst.length && !t(arrLonEst[i]).isEmpty()) ? t(arrLonEst[i]) : "-90.5069";
                    String puerta = (arrPuertaEst != null && i < arrPuertaEst.length) ? t(arrPuertaEst[i]) : "";
                    String guardia = (arrGuardiaEst != null && i < arrGuardiaEst.length) ? t(arrGuardiaEst[i]) : "";
                    String turnoG = (arrTurnoEst != null && i < arrTurnoEst.length && !t(arrTurnoEst[i]).isEmpty()) ? t(arrTurnoEst[i]) : "Diurno";

                    // Asegurar en estaciones_catalogo
                    try (PreparedStatement psCatCheck = con.prepareStatement("SELECT id FROM estaciones_catalogo WHERE LOWER(nombre) = LOWER(?) LIMIT 1")) {
                        psCatCheck.setString(1, nomEst);
                        try (ResultSet rsC = psCatCheck.executeQuery()) {
                            if (!rsC.next()) {
                                try (PreparedStatement psCatIns = con.prepareStatement("INSERT INTO estaciones_catalogo (nombre) VALUES (?)")) {
                                    psCatIns.setString(1, nomEst);
                                    psCatIns.executeUpdate();
                                }
                            }
                        }
                    }

                    // Asegurar en estaciones_fisicas
                    int idEstFisica = 0;
                    try (PreparedStatement psFisCheck = con.prepareStatement("SELECT id_estacion FROM estaciones_fisicas WHERE LOWER(nombre) = LOWER(?) LIMIT 1")) {
                        psFisCheck.setString(1, nomEst);
                        try (ResultSet rsF = psFisCheck.executeQuery()) {
                            if (rsF.next()) {
                                idEstFisica = rsF.getInt(1);
                                try (PreparedStatement psFisUpd = con.prepareStatement("UPDATE estaciones_fisicas SET latitud = ?, longitud = ? WHERE id_estacion = ?")) {
                                    psFisUpd.setString(1, lat);
                                    psFisUpd.setString(2, lon);
                                    psFisUpd.setInt(3, idEstFisica);
                                    psFisUpd.executeUpdate();
                                }
                            } else {
                                try (PreparedStatement psFisIns = con.prepareStatement("INSERT INTO estaciones_fisicas (nombre, latitud, longitud) VALUES (?, ?, ?)", Statement.RETURN_GENERATED_KEYS)) {
                                    psFisIns.setString(1, nomEst);
                                    psFisIns.setString(2, lat);
                                    psFisIns.setString(3, lon);
                                    psFisIns.executeUpdate();
                                    try (ResultSet rk = psFisIns.getGeneratedKeys()) {
                                        if (rk.next()) idEstFisica = rk.getInt(1);
                                    }
                                }
                            }
                        }
                    }

                    // Si se especificó Molinete y Guardia, asegurar su registro o actualización (RN05)
                    if (idEstFisica > 0 && !puerta.isEmpty() && !guardia.isEmpty()) {
                        int idAcceso = 0;
                        try (PreparedStatement psAccCheck = con.prepareStatement("SELECT id_acceso FROM accesos_molinetes WHERE id_estacion = ? ORDER BY id_acceso ASC LIMIT 1")) {
                            psAccCheck.setInt(1, idEstFisica);
                            try (ResultSet rsA = psAccCheck.executeQuery()) {
                                if (rsA.next()) {
                                    idAcceso = rsA.getInt(1);
                                    try (PreparedStatement psAccUpd = con.prepareStatement("UPDATE accesos_molinetes SET codigo_puerta = ? WHERE id_acceso = ?")) {
                                        psAccUpd.setString(1, puerta);
                                        psAccUpd.setInt(2, idAcceso);
                                        psAccUpd.executeUpdate();
                                    }
                                } else {
                                    try (PreparedStatement psAccIns = con.prepareStatement("INSERT INTO accesos_molinetes (id_estacion, codigo_puerta) VALUES (?, ?)", Statement.RETURN_GENERATED_KEYS)) {
                                        psAccIns.setInt(1, idEstFisica);
                                        psAccIns.setString(2, puerta);
                                        psAccIns.executeUpdate();
                                        try (ResultSet rkA = psAccIns.getGeneratedKeys()) {
                                            if (rkA.next()) idAcceso = rkA.getInt(1);
                                        }
                                    }
                                }
                            }
                        }

                        if (idAcceso > 0) {
                            try (PreparedStatement psGCheck = con.prepareStatement("SELECT id_guardia FROM guardias_seguridad WHERE id_acceso = ? LIMIT 1")) {
                                psGCheck.setInt(1, idAcceso);
                                try (ResultSet rsG = psGCheck.executeQuery()) {
                                    if (rsG.next()) {
                                        int idG = rsG.getInt(1);
                                        try (PreparedStatement psGUpd = con.prepareStatement("UPDATE guardias_seguridad SET nombre_completo = ?, turno = ? WHERE id_guardia = ?")) {
                                            psGUpd.setString(1, guardia);
                                            psGUpd.setString(2, turnoG);
                                            psGUpd.setInt(3, idG);
                                            psGUpd.executeUpdate();
                                        }
                                    } else {
                                        try (PreparedStatement psGIns = con.prepareStatement("INSERT INTO guardias_seguridad (nombre_completo, id_acceso, turno) VALUES (?, ?, ?)")) {
                                            psGIns.setString(1, guardia);
                                            psGIns.setInt(2, idAcceso);
                                            psGIns.setString(3, turnoG);
                                            psGIns.executeUpdate();
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // 3. Guardar Kilometraje de cada Tramo (RF02)
            String[] arrTramoOrigen = request.getParameterValues("tramo_origen");
            String[] arrTramoDestino = request.getParameterValues("tramo_destino");
            String[] arrTramoKm = request.getParameterValues("tramo_km");

            if (idNuevaRuta > 0 && arrTramoOrigen != null && arrTramoDestino != null && arrTramoKm != null) {
                try (PreparedStatement psInsKm = con.prepareStatement(
                        "INSERT INTO distancias_tramos (id_ruta, estacion_origen, estacion_destino, distancia_km) VALUES (?, ?, ?, ?)")) {
                    for (int i = 0; i < arrTramoOrigen.length; i++) {
                        String orig = t(arrTramoOrigen[i]);
                        String dest = t(arrTramoDestino[i]);
                        String kmStr = (i < arrTramoKm.length) ? t(arrTramoKm[i]) : "";
                        if (!orig.isEmpty() && !dest.isEmpty() && !kmStr.isEmpty()) {
                            BigDecimal kmVal = new BigDecimal(kmStr);
                            if (kmVal.compareTo(BigDecimal.ZERO) > 0) {
                                psInsKm.setInt(1, idNuevaRuta);
                                psInsKm.setString(2, orig);
                                psInsKm.setString(3, dest);
                                psInsKm.setBigDecimal(4, kmVal);
                                psInsKm.addBatch();
                            }
                        }
                    }
                    psInsKm.executeBatch();
                }
            }

            con.commit();
            mensaje = "✅ Ruta '" + nombreRuta + "' creada exitosamente con su flota, parqueo, piloto, estaciones, molinetes y kilometraje.";
            tipoMensaje = "exito";
        } catch (Exception e) {
            if (con != null) {
                try { con.rollback(); } catch (SQLException ex) {}
            }
            mensaje = "❌ Error al crear la ruta: " + e.getMessage();
            tipoMensaje = "error";
        } finally {
            if (con != null) {
                try { con.setAutoCommit(true); con.close(); } catch (SQLException ex) {}
            }
        }
    }
%>
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <title>Configurar Nueva Ruta - Transmetro</title>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&display=swap" rel="stylesheet">
    <style>
        body { font-family: 'Inter', sans-serif; background-color: #f0f2f5; margin: 0; padding-top: 70px; }
        .header { background: #ffffff; color: #1e293b; padding: 15px 25px; position: fixed; top: 0; width: 100%; box-sizing: border-box; z-index: 1000; display: flex; justify-content: space-between; align-items: center; border-bottom: 1px solid #e2e8f0; }
        .header h1 { margin: 0; font-size: 18px; text-align: center; flex-grow: 1; font-weight: 700; }
        .menu-btn { background: none; border: none; color: #475569; font-size: 24px; cursor: pointer; }
        .overlay { display: none; position: fixed; width: 100%; height: 100%; top: 0; left: 0; background: rgba(15, 23, 42, 0.4); z-index: 999; }

        .main-container { max-width: 1120px; margin: 30px auto; padding: 0 20px 50px 20px; }
        .page-title { display: flex; justify-content: space-between; align-items: flex-end; flex-wrap: wrap; gap: 12px; margin-bottom: 20px; }
        .page-title h2 { margin: 0 0 5px 0; font-size: 26px; font-weight: 800; color: #0f172a; }
        .page-title p { margin: 0; color: #64748b; font-size: 14px; }

        .card-container { background: #ffffff; border-radius: 14px; box-shadow: 0 4px 12px rgba(0,0,0,0.05); padding: 28px; border-top: 5px solid #10b981; }
        .form-section { background: #f8fafc; padding: 22px; border-radius: 10px; border: 1px solid #e2e8f0; margin-bottom: 22px; }
        .form-section h3 { margin-top: 0; color: #0f172a; border-bottom: 1px solid #cbd5e1; padding-bottom: 10px; font-size: 16px; display: flex; align-items: center; justify-content: space-between; flex-wrap: wrap; gap: 8px; }
        .form-group { margin-bottom: 15px; }
        .form-group label { display: block; font-size: 13px; font-weight: 700; color: #334155; margin-bottom: 6px; }
        .form-group input, .form-group select, .form-group textarea { width: 100%; padding: 10px 12px; border: 1px solid #cbd5e1; border-radius: 8px; font-size: 14px; box-sizing: border-box; background: #fff; }
        .grid-2 { display: grid; grid-template-columns: 1.3fr 1fr; gap: 16px; }
        .grid-3 { display: grid; grid-template-columns: repeat(3, 1fr); gap: 16px; }
        @media (max-width: 860px) { .grid-2, .grid-3 { grid-template-columns: 1fr; } }

        .vehiculo-box { background: #ffffff; border: 1px solid #e2e8f0; border-radius: 10px; padding: 14px; box-shadow: 0 1px 3px rgba(0,0,0,0.02); }
        .vehiculo-meta { margin-top: 8px; padding: 8px 10px; background: #f1f5f9; border-radius: 6px; font-size: 12px; color: #334155; line-height: 1.5; }
        .parqueo-inline { margin-top: 10px; padding-top: 8px; border-top: 1px dashed #cbd5e1; }
        .parqueo-inline label { font-size: 11px; color: #0369a1; font-weight: 700; text-transform: uppercase; }

        .chips { display: flex; flex-wrap: wrap; gap: 8px; align-items: center; margin-top: 10px; padding: 12px; background: #ffffff; border: 1px dashed #cbd5e1; border-radius: 8px; }
        .chips-label { font-size: 12px; color: #475569; font-weight: 700; width: 100%; margin-bottom: 4px; }
        .chip { background: #e0f2fe; color: #0369a1; border: 1px solid #bae6fd; border-radius: 20px; padding: 6px 12px; font-size: 12px; font-weight: 700; cursor: pointer; display: inline-flex; align-items: center; gap: 6px; transition: 0.15s; }
        .chip:hover { background: #0284c7; color: white; transform: translateY(-1px); }
        .chip .chip-sub { font-size: 10px; font-weight: 600; background: rgba(255,255,255,0.75); color: #0f172a; padding: 1px 6px; border-radius: 10px; }

        .infra-table { width: 100%; border-collapse: collapse; background: #fff; border-radius: 8px; overflow: hidden; border: 1px solid #e2e8f0; margin-top: 10px; }
        .infra-table th { background: #f1f5f9; color: #475569; font-size: 11px; font-weight: 800; text-transform: uppercase; padding: 10px 12px; text-align: left; border-bottom: 1px solid #cbd5e1; }
        .infra-table td { padding: 10px 12px; border-bottom: 1px solid #f1f5f9; font-size: 13px; vertical-align: middle; }
        .infra-table input, .infra-table select { padding: 7px 10px; font-size: 13px; border: 1px solid #cbd5e1; border-radius: 6px; width: 100%; box-sizing: border-box; }

        .km-summary-bar { display: flex; justify-content: space-between; align-items: center; background: #eff6ff; border: 1px solid #bfdbfe; color: #1e3a8a; padding: 12px 16px; border-radius: 8px; margin-top: 12px; font-weight: 700; font-size: 14px; }

        .grid-horarios { display: grid; grid-template-columns: repeat(3, 1fr); gap: 15px; background: white; padding: 16px; border: 1px solid #e2e8f0; border-radius: 8px; }
        @media (max-width: 860px) { .grid-horarios { grid-template-columns: 1fr; } }
        .turno-caja { text-align: center; border: 1px solid #f1f5f9; background: #f8fafc; padding: 12px; border-radius: 8px; }

        .btn-submit { background: linear-gradient(135deg, #10b981, #059669); color: white; border: none; padding: 16px; border-radius: 10px; font-weight: 800; cursor: pointer; width: 100%; font-size: 16px; box-shadow: 0 4px 12px rgba(16, 185, 129, 0.25); transition: 0.2s; }
        .btn-submit:hover { transform: translateY(-1px); background: #059669; }
        .btn-sec { background: #e2e8f0; color: #1e293b; border: none; padding: 7px 12px; border-radius: 6px; font-size: 12px; font-weight: 700; cursor: pointer; text-decoration: none; }
        .btn-sec:hover { background: #cbd5e1; }

        .alerta { padding: 15px; border-radius: 8px; font-weight: 600; margin-bottom: 20px; font-size: 14px; }
        .exito { background: #ecfdf5; color: #065f46; border: 1px solid #a7f3d0; }
        .error { background: #fef2f2; color: #991b1b; border: 1px solid #fecaca; }
    </style>
    <link rel="stylesheet" href="css/transmetro.css">
</head>
<body>
    <jsp:include page="menu_izquierdo.jsp" />
    <jsp:include page="menu_derecho.jsp" />
    <div id="overlay" class="overlay" onclick="closeAllMenus()"></div>

    <div class="header">
        <button class="menu-btn" onclick="toggleMenu('left')">☰</button>
        <h1>Configurador Integral de Rutas</h1>
        <button class="menu-btn" onclick="toggleMenu('right')">⚙️</button>
    </div>

    <%
        // Precargar datos de la BD para los selectores y diccionarios JS
        Connection conData = null;
        List<Map<String, String>> listaVehiculos = new ArrayList<>();
        List<Map<String, String>> listaParqueos = new ArrayList<>();
        List<Map<String, String>> listaPilotos = new ArrayList<>();
        Map<String, Map<String, String>> mapaEstaciones = new LinkedHashMap<>();
        StringBuilder jsEstaciones = new StringBuilder("{");
        StringBuilder jsVehiculos = new StringBuilder("{");
        StringBuilder jsDistancias = new StringBuilder("{");

        try {
            conData = DriverManager.getConnection(dbUrl, dbUser, dbPass);
            Statement st = conData.createStatement();

            // 1. Parqueos con su ocupación actual
            ResultSet rsPq = st.executeQuery(
                "SELECT p.id_parqueo, p.nombre, p.capacidad_buses, COUNT(f.id_vehiculo) AS ocupados " +
                "FROM parqueos p LEFT JOIN flota_vehiculos f ON f.id_parqueo = p.id_parqueo " +
                "GROUP BY p.id_parqueo, p.nombre, p.capacidad_buses ORDER BY p.nombre ASC");
            while (rsPq.next()) {
                Map<String, String> m = new HashMap<>();
                m.put("id", rsPq.getString("id_parqueo"));
                m.put("nombre", rsPq.getString("nombre"));
                m.put("cap", rsPq.getString("capacidad_buses"));
                m.put("ocu", rsPq.getString("ocupados"));
                listaParqueos.add(m);
            }
            rsPq.close();

            // 2. Flota de vehículos con su parqueo
            ResultSet rsVeh = st.executeQuery(
                "SELECT f.id_vehiculo, f.placa, f.municipalidad, f.capacidad, f.estado, f.id_parqueo, " +
                "p.nombre AS nombre_parqueo, p.capacidad_buses AS cap_parqueo, " +
                "(SELECT COUNT(*) FROM flota_vehiculos f2 WHERE f2.id_parqueo = f.id_parqueo) AS ocu_parqueo " +
                "FROM flota_vehiculos f LEFT JOIN parqueos p ON f.id_parqueo = p.id_parqueo ORDER BY f.placa ASC");
            boolean firstV = true;
            while (rsVeh.next()) {
                Map<String, String> v = new HashMap<>();
                String idV = rsVeh.getString("id_vehiculo");
                v.put("id", idV);
                v.put("placa", rsVeh.getString("placa"));
                v.put("muni", rsVeh.getString("municipalidad") != null ? rsVeh.getString("municipalidad") : "Sin municipalidad");
                v.put("cap", rsVeh.getString("capacidad"));
                v.put("estado", rsVeh.getString("estado"));
                v.put("id_parqueo", rsVeh.getString("id_parqueo") != null ? rsVeh.getString("id_parqueo") : "");
                v.put("parqueo", rsVeh.getString("nombre_parqueo") != null ? rsVeh.getString("nombre_parqueo") : "Sin parqueo");
                listaVehiculos.add(v);

                if (!firstV) jsVehiculos.append(",");
                firstV = false;
                jsVehiculos.append("\"").append(js(idV)).append("\":{")
                    .append("\"placa\":\"").append(js(v.get("placa"))).append("\",")
                    .append("\"muni\":\"").append(js(v.get("muni"))).append("\",")
                    .append("\"cap\":\"").append(js(v.get("cap"))).append("\",")
                    .append("\"estado\":\"").append(js(v.get("estado"))).append("\",")
                    .append("\"idParqueo\":\"").append(js(v.get("id_parqueo"))).append("\",")
                    .append("\"parqueo\":\"").append(js(v.get("parqueo"))).append("\",")
                    .append("\"capParqueo\":\"").append(js(rsVeh.getString("cap_parqueo"))).append("\",")
                    .append("\"ocuParqueo\":\"").append(js(rsVeh.getString("ocu_parqueo"))).append("\"")
                    .append("}");
            }
            rsVeh.close();
            jsVehiculos.append("}");

            // 3. Pilotos
            ResultSet rsPil = st.executeQuery(
                "SELECT p.id, p.nombre, p.edad, p.identificador_transmetro, IFNULL(p.usuario_asignado, 'Sin asignar') AS usr, " +
                "(SELECT GROUP_CONCAT(r.nombre_ruta SEPARATOR ', ') FROM rutas_operativas r WHERE r.id_piloto = p.id) AS rutas_actuales " +
                "FROM pilotos_catalogo p ORDER BY p.nombre ASC");
            while (rsPil.next()) {
                Map<String, String> p = new HashMap<>();
                p.put("id", rsPil.getString("id"));
                p.put("nombre", rsPil.getString("nombre"));
                p.put("edad", rsPil.getString("edad"));
                p.put("identificador", rsPil.getString("identificador_transmetro"));
                p.put("usr", rsPil.getString("usr"));
                p.put("rutas", rsPil.getString("rutas_actuales"));
                listaPilotos.add(p);
            }
            rsPil.close();

            // 4. Estaciones (unión de catálogo y físicas + sus molinetes y guardias)
            ResultSet rsEst = st.executeQuery(
                "SELECT e.id_estacion, e.nombre, e.latitud, e.longitud, " +
                "a.id_acceso, a.codigo_puerta, g.nombre_completo AS guardia, g.turno " +
                "FROM estaciones_fisicas e " +
                "LEFT JOIN accesos_molinetes a ON a.id_estacion = e.id_estacion " +
                "LEFT JOIN guardias_seguridad g ON g.id_acceso = a.id_acceso " +
                "ORDER BY e.nombre ASC, a.id_acceso ASC");
            while (rsEst.next()) {
                String nom = t(rsEst.getString("nombre"));
                String key = nom.toLowerCase();
                if (!mapaEstaciones.containsKey(key)) {
                    Map<String, String> me = new HashMap<>();
                    me.put("nombre", nom);
                    me.put("lat", rsEst.getString("latitud") != null ? rsEst.getString("latitud") : "14.6349");
                    me.put("lon", rsEst.getString("longitud") != null ? rsEst.getString("longitud") : "-90.5069");
                    me.put("puerta", rsEst.getString("codigo_puerta") != null ? rsEst.getString("codigo_puerta") : "");
                    me.put("guardia", rsEst.getString("guardia") != null ? rsEst.getString("guardia") : "");
                    me.put("turno", rsEst.getString("turno") != null ? rsEst.getString("turno") : "Diurno");
                    mapaEstaciones.put(key, me);
                }
            }
            rsEst.close();

            ResultSet rsCat = st.executeQuery("SELECT nombre FROM estaciones_catalogo ORDER BY nombre ASC");
            while (rsCat.next()) {
                String nom = t(rsCat.getString(1));
                String key = nom.toLowerCase();
                if (!nom.isEmpty() && !mapaEstaciones.containsKey(key)) {
                    Map<String, String> me = new HashMap<>();
                    me.put("nombre", nom);
                    me.put("lat", "14.6349");
                    me.put("lon", "-90.5069");
                    me.put("puerta", "");
                    me.put("guardia", "");
                    me.put("turno", "Diurno");
                    mapaEstaciones.put(key, me);
                }
            }
            rsCat.close();

            boolean firstE = true;
            for (Map.Entry<String, Map<String, String>> entry : mapaEstaciones.entrySet()) {
                if (!firstE) jsEstaciones.append(",");
                firstE = false;
                Map<String, String> me = entry.getValue();
                jsEstaciones.append("\"").append(js(entry.getKey())).append("\":{")
                    .append("\"nombre\":\"").append(js(me.get("nombre"))).append("\",")
                    .append("\"lat\":\"").append(js(me.get("lat"))).append("\",")
                    .append("\"lon\":\"").append(js(me.get("lon"))).append("\",")
                    .append("\"puerta\":\"").append(js(me.get("puerta"))).append("\",")
                    .append("\"guardia\":\"").append(js(me.get("guardia"))).append("\",")
                    .append("\"turno\":\"").append(js(me.get("turno"))).append("\"")
                    .append("}");
            }
            jsEstaciones.append("}");

            // 5. Distancias históricas registradas entre tramos (para autocompletar km si ya se conocen)
            ResultSet rsDist = st.executeQuery("SELECT estacion_origen, estacion_destino, distancia_km FROM distancias_tramos");
            boolean firstD = true;
            while (rsDist.next()) {
                String k1 = t(rsDist.getString(1)).toLowerCase() + "|" + t(rsDist.getString(2)).toLowerCase();
                String k2 = t(rsDist.getString(2)).toLowerCase() + "|" + t(rsDist.getString(1)).toLowerCase();
                String km = rsDist.getBigDecimal(3).toPlainString();
                if (!firstD) jsDistancias.append(",");
                firstD = false;
                jsDistancias.append("\"").append(js(k1)).append("\":\"").append(js(km)).append("\",")
                            .append("\"").append(js(k2)).append("\":\"").append(js(km)).append("\"");
            }
            rsDist.close();
            jsDistancias.append("}");

            st.close();
            conData.close();
        } catch (Exception e) {
            if (jsVehiculos.length() == 1) jsVehiculos.append("}");
            if (jsEstaciones.length() == 1) jsEstaciones.append("}");
            if (jsDistancias.length() == 1) jsDistancias.append("}");
        }
    %>

    <div class="main-container">
        <div class="page-title">
            <div>
                <h2>➕ Configurar Nueva Ruta Operativa</h2>
                <p>Integra en un solo lugar la flota, parqueo base, piloto asignado, estaciones, molinetes/guardias y kilometraje por tramo.</p>
            </div>
            <div style="display:flex; gap:10px;">
                <a href="editar_rutas.jsp" class="btn-sec">✏️ Ver / Editar Rutas Activas</a>
                <a href="admin_infra.jsp" class="btn-sec">🏗️ Panel de Infraestructura</a>
            </div>
        </div>

        <% if (!mensaje.isEmpty()) { %>
            <div class="alerta <%= tipoMensaje %>">
                <%= h(mensaje) %>
                <% if ("exito".equals(tipoMensaje)) { %>
                    &nbsp;— <a href="editar_rutas.jsp" style="color:#065f46; font-weight:800; text-decoration:underline;">Ir al listado de rutas</a>
                    o <a href="lineas.jsp" style="color:#065f46; font-weight:800; text-decoration:underline;">Ver en Mapa en Vivo</a>.
                <% } %>
            </div>
        <% } %>

        <div class="card-container">
            <form method="POST" action="nueva_ruta.jsp" id="formRuta">
                <!-- SECCIÓN 1: NOMBRE, PILOTO, FLOTA Y PARQUEOS BASE -->
                <div class="form-section">
                    <h3>
                        <span>1. Identificación, Piloto Titular, Flota y Parqueo Base (RN04)</span>
                        <span style="font-size:12px; color:#64748b; font-weight:600;">Cada unidad muestra su municipalidad, capacidad y parqueo oficial</span>
                    </h3>

                    <div class="grid-2">
                        <div class="form-group">
                            <label>🗺️ Nombre Comercial de la Ruta</label>
                            <input type="text" name="nombre_ruta" placeholder="Ej. Línea 12 - Trébol a Centra Sur" required>
                        </div>
                        <div class="form-group">
                            <label>👨‍✈️ Piloto Titular Asignado a la Ruta</label>
                            <select name="id_piloto">
                                <option value="">-- Seleccionar Piloto del Catálogo --</option>
                                <% for (Map<String, String> pil : listaPilotos) { %>
                                    <option value="<%= h(pil.get("id")) %>">
                                        👨‍✈️ <%= h(pil.get("nombre")) %> (ID: <%= h(pil.get("identificador")) %> · <%= h(pil.get("edad")) %> años)
                                        <%= (pil.get("rutas") != null && !pil.get("rutas").isEmpty()) ? " — Activo en: " + h(pil.get("rutas")) : " — Disponible" %>
                                    </option>
                                <% } %>
                            </select>
                        </div>
                    </div>

                    <div class="grid-3">
                        <!-- VEHÍCULO PRINCIPAL -->
                        <div class="vehiculo-box">
                            <div class="form-group" style="margin-bottom:0;">
                                <label>🟢 Vehículo Principal (Titular)</label>
                                <select name="id_vehiculo_main" id="sel_main" onchange="actualizarMetaVehiculo('main')" required>
                                    <option value="">-- Seleccione Unidad Principal --</option>
                                    <% for (Map<String, String> v : listaVehiculos) { %>
                                        <option value="<%= h(v.get("id")) %>">
                                            🚍 <%= h(v.get("placa")) %> · Cap: <%= h(v.get("cap")) %> · 🅿️ <%= h(v.get("parqueo")) %>
                                        </option>
                                    <% } %>
                                </select>
                            </div>
                            <div id="meta_main" class="vehiculo-meta">Seleccione una unidad para ver su municipalidad y parqueo.</div>
                            <div class="parqueo-inline">
                                <label>🅿️ Parqueo Base de esta Unidad</label>
                                <select name="parqueo_main" id="pq_main">
                                    <% for (Map<String, String> pq : listaParqueos) { %>
                                        <option value="<%= h(pq.get("id")) %>">🅿️ <%= h(pq.get("nombre")) %> (Ocupación: <%= h(pq.get("ocu")) %>/<%= h(pq.get("cap")) %>)</option>
                                    <% } %>
                                </select>
                            </div>
                        </div>

                        <!-- VEHÍCULO DE REFUERZO -->
                        <div class="vehiculo-box">
                            <div class="form-group" style="margin-bottom:0;">
                                <label>🔵 Vehículo de Refuerzo (Backup)</label>
                                <select name="id_vehiculo_backup" id="sel_backup" onchange="actualizarMetaVehiculo('backup')" required>
                                    <option value="">-- Seleccione Unidad de Refuerzo --</option>
                                    <% for (Map<String, String> v : listaVehiculos) { %>
                                        <option value="<%= h(v.get("id")) %>">
                                            🚍 <%= h(v.get("placa")) %> · Cap: <%= h(v.get("cap")) %> · 🅿️ <%= h(v.get("parqueo")) %>
                                        </option>
                                    <% } %>
                                </select>
                            </div>
                            <div id="meta_backup" class="vehiculo-meta">Seleccione una unidad para ver su municipalidad y parqueo.</div>
                            <div class="parqueo-inline">
                                <label>🅿️ Parqueo Base de esta Unidad</label>
                                <select name="parqueo_backup" id="pq_backup">
                                    <% for (Map<String, String> pq : listaParqueos) { %>
                                        <option value="<%= h(pq.get("id")) %>">🅿️ <%= h(pq.get("nombre")) %> (Ocupación: <%= h(pq.get("ocu")) %>/<%= h(pq.get("cap")) %>)</option>
                                    <% } %>
                                </select>
                            </div>
                        </div>

                        <!-- VEHÍCULO EXTRA -->
                        <div class="vehiculo-box">
                            <div class="form-group" style="margin-bottom:0;">
                                <label>🟣 Bus Extra (Emergencia - Opcional)</label>
                                <select name="id_vehiculo_extra" id="sel_extra" onchange="actualizarMetaVehiculo('extra')">
                                    <option value="">-- Ninguno Asignado --</option>
                                    <% for (Map<String, String> v : listaVehiculos) { %>
                                        <option value="<%= h(v.get("id")) %>">
                                            🚑 <%= h(v.get("placa")) %> · Cap: <%= h(v.get("cap")) %> · 🅿️ <%= h(v.get("parqueo")) %>
                                        </option>
                                    <% } %>
                                </select>
                            </div>
                            <div id="meta_extra" class="vehiculo-meta">Opcional: Se activa cuando Principal y Refuerzo llegan al 100%.</div>
                            <div class="parqueo-inline">
                                <label>🅿️ Parqueo Base de esta Unidad</label>
                                <select name="parqueo_extra" id="pq_extra">
                                    <option value="">-- Sin cambio --</option>
                                    <% for (Map<String, String> pq : listaParqueos) { %>
                                        <option value="<%= h(pq.get("id")) %>">🅿️ <%= h(pq.get("nombre")) %> (Ocupación: <%= h(pq.get("ocu")) %>/<%= h(pq.get("cap")) %>)</option>
                                    <% } %>
                                </select>
                            </div>
                        </div>
                    </div>
                </div>

                <!-- SECCIÓN 2: ESTACIONES, MOLINETES Y GUARDIAS DE SEGURIDAD -->
                <div class="form-section">
                    <h3>
                        <span>2. Estaciones del Recorrido, Molinetes y Guardias (RN05)</span>
                        <span style="font-size:12px; color:#0369a1; font-weight:600;">Haz clic en las estaciones o escríbelas separadas por coma</span>
                    </h3>

                    <div class="form-group">
                        <label>🚏 Secuencia de Estaciones (Separadas por comas en orden de recorrido)</label>
                        <textarea name="estaciones" id="txtEstaciones" rows="2" placeholder="Ejemplo: Trébol, Santa Cecilia, Bolívar, Don Bosco, Plaza Municipal" oninput="sincronizarRuta()" required></textarea>

                        <div class="chips">
                            <span class="chips-label">➕ Catálogo de Estaciones (Clic para añadir al recorrido):</span>
                            <% for (Map<String, String> me : mapaEstaciones.values()) {
                                String nom = me.get("nombre");
                                String puerta = me.get("puerta");
                                String guardia = me.get("guardia");
                                boolean tieneSeg = !puerta.isEmpty() && !guardia.isEmpty();
                            %>
                                <button type="button" class="chip" data-n="<%= h(nom) %>" onclick="agregarEstacion(this.getAttribute('data-n'))">
                                    <span>🚏 <%= h(nom) %></span>
                                    <span class="chip-sub"><%= tieneSeg ? "🚪 " + h(puerta) + " · 👮 " + h(guardia) : "⚠️ Sin molinete" %></span>
                                </button>
                            <% } %>
                        </div>
                    </div>

                    <div style="margin-top: 14px;">
                        <label style="display:block; font-size:13px; font-weight:700; color:#334155; margin-bottom:6px;">
                            🚪 Configuración de Molinetes, Guardias de Seguridad y Coordenadas por Estación de la Ruta:
                        </label>
                        <div id="contenedorTablaEstaciones">
                            <div style="padding:14px; background:#fff; border:1px dashed #cbd5e1; border-radius:8px; color:#64748b; font-size:13px; text-align:center;">
                                Selecciona o escribe al menos 2 estaciones arriba para configurar sus molinetes y guardias aquí mismo.
                            </div>
                        </div>
                    </div>
                </div>

                <!-- SECCIÓN 3: KILOMETRAJE POR TRAMO -->
                <div class="form-section">
                    <h3>
                        <span>3. Kilometraje por Tramo y Distancia Total de la Ruta (RF02)</span>
                        <button type="button" class="btn-sec" onclick="autocompletarKilometros()">⚡ Autocompletar tramos vacíos (1.50 km)</button>
                    </h3>
                    <div id="contenedorTablaTramos">
                        <div style="padding:14px; background:#fff; border:1px dashed #cbd5e1; border-radius:8px; color:#64748b; font-size:13px; text-align:center;">
                            Agrega al menos 2 estaciones para definir los kilómetros de cada tramo consecutivo.
                        </div>
                    </div>
                    <div class="km-summary-bar">
                        <span>📏 Distancia Total Acumulada del Recorrido:</span>
                        <span id="lblKmTotal" style="font-size:18px; color:#0369a1;">0.00 km (0 tramos)</span>
                    </div>
                </div>

                <!-- SECCIÓN 4: PLANIFICACIÓN DE TURNOS (HORARIOS) -->
                <div class="form-section">
                    <h3>
                        <span>4. Planificación de Turnos Operativos (T1 a T6)</span>
                        <button type="button" class="btn-sec" onclick="autocompletarHorarios()">🕒 Cargar Horarios Estándar (06:00 a 18:00)</button>
                    </h3>
                    <div class="grid-horarios">
                        <div class="turno-caja">
                            <label><b>Turno 1 (IDA - Obligatorio)</b></label><br>
                            <input type="time" name="hs1" id="hs1" value="06:00" required style="width:45%;"> a
                            <input type="time" name="hl1" id="hl1" value="07:30" required style="width:45%;">
                        </div>
                        <div class="turno-caja">
                            <label><b>Turno 2 (RETORNO)</b></label><br>
                            <input type="time" name="hs2" id="hs2" value="08:00" style="width:45%;"> a
                            <input type="time" name="hl2" id="hl2" value="09:30" style="width:45%;">
                        </div>
                        <div class="turno-caja">
                            <label><b>Turno 3 (IDA)</b></label><br>
                            <input type="time" name="hs3" id="hs3" value="10:00" style="width:45%;"> a
                            <input type="time" name="hl3" id="hl3" value="11:30" style="width:45%;">
                        </div>
                        <div class="turno-caja">
                            <label><b>Turno 4 (RETORNO)</b></label><br>
                            <input type="time" name="hs4" id="hs4" value="12:00" style="width:45%;"> a
                            <input type="time" name="hl4" id="hl4" value="13:30" style="width:45%;">
                        </div>
                        <div class="turno-caja">
                            <label><b>Turno 5 (IDA)</b></label><br>
                            <input type="time" name="hs5" id="hs5" value="14:00" style="width:45%;"> a
                            <input type="time" name="hl5" id="hl5" value="15:30" style="width:45%;">
                        </div>
                        <div class="turno-caja">
                            <label><b>Turno 6 (RETORNO)</b></label><br>
                            <input type="time" name="hs6" id="hs6" value="16:00" style="width:45%;"> a
                            <input type="time" name="hl6" id="hl6" value="18:00" style="width:45%;">
                        </div>
                    </div>
                </div>

                <button type="submit" class="btn-submit">🚀 Crear Ruta Completa con Infraestructura y Kilometraje</button>
            </form>
        </div>
    </div>

    <script>
        const VEHICULOS_DB = <%= jsVehiculos.toString() %>;
        const ESTACIONES_DB = <%= jsEstaciones.toString() %>;
        const DISTANCIAS_DB = <%= jsDistancias.toString() %>;

        // Memoria local para no perder lo que el usuario edite mientras cambia estaciones
        const edicionesEstacion = {};
        const edicionesTramo = {};

        function toggleMenu(side) {
            let left = document.getElementById("leftSidebar");
            let right = document.getElementById("rightSidebar");
            let over = document.getElementById("overlay");
            if (side === 'left') { left.style.width = "250px"; if (right) right.style.width = "0"; }
            else if (side === 'right') { if (right) right.style.width = "300px"; left.style.width = "0"; }
            over.style.display = "block";
        }
        function closeAllMenus() {
            document.getElementById("leftSidebar").style.width = "0";
            let right = document.getElementById("rightSidebar");
            if (right) right.style.width = "0";
            document.getElementById("overlay").style.display = "none";
        }

        function escHtml(s) {
            if (!s) return "";
            return String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
        }

        function actualizarMetaVehiculo(rol) {
            const sel = document.getElementById("sel_" + rol);
            const meta = document.getElementById("meta_" + rol);
            const pqSel = document.getElementById("pq_" + rol);
            const idV = sel.value;
            if (!idV || !VEHICULOS_DB[idV]) {
                meta.innerHTML = "Seleccione una unidad para ver su municipalidad y parqueo.";
                return;
            }
            const v = VEHICULOS_DB[idV];
            meta.innerHTML =
                "<b>🚍 Placa:</b> " + escHtml(v.placa) +
                " &nbsp;|&nbsp; <b>💺 Capacidad:</b> " + escHtml(v.cap) + " asientos<br>" +
                "<b>🏛️ Municipalidad:</b> " + escHtml(v.muni) +
                " &nbsp;|&nbsp; <b>🅿️ Parqueo actual:</b> " + escHtml(v.parqueo) + " (" + escHtml(v.ocuParqueo) + "/" + escHtml(v.capParqueo) + ")";
            if (pqSel && v.idParqueo) {
                pqSel.value = v.idParqueo;
            }
        }

        function agregarEstacion(nombre) {
            const t = document.getElementById("txtEstaciones");
            let actual = t.value.split(",").map(s => s.trim()).filter(s => s.length > 0);
            if (!actual.some(s => s.toLowerCase() === nombre.toLowerCase())) {
                actual.push(nombre);
                t.value = actual.join(", ");
                sincronizarRuta();
            }
        }

        function quitarEstacionIdx(idx) {
            const t = document.getElementById("txtEstaciones");
            let actual = t.value.split(",").map(s => s.trim()).filter(s => s.length > 0);
            actual.splice(idx, 1);
            t.value = actual.join(", ");
            sincronizarRuta();
        }

        function guardarEdicionEstacion(key, campo, valor) {
            if (!edicionesEstacion[key]) edicionesEstacion[key] = {};
            edicionesEstacion[key][campo] = valor;
        }

        function guardarEdicionTramo(key, valor) {
            edicionesTramo[key] = valor;
            recalcularKmTotal();
        }

        function sincronizarRuta() {
            const raw = document.getElementById("txtEstaciones").value;
            const estaciones = raw.split(",").map(s => s.trim()).filter(s => s.length > 0);

            // 1. Renderizar tabla de Estaciones + Molinete + Guardia
            const contEst = document.getElementById("contenedorTablaEstaciones");
            if (estaciones.length === 0) {
                contEst.innerHTML = "<div style='padding:14px; background:#fff; border:1px dashed #cbd5e1; border-radius:8px; color:#64748b; font-size:13px; text-align:center;'>Selecciona o escribe estaciones arriba para configurar sus molinetes y guardias.</div>";
            } else {
                let htmlE = "<table class='infra-table'><thead><tr>" +
                    "<th>#</th><th>Estación</th><th>🚪 Molinete / Puerta</th><th>👮 Guardia de Seguridad</th><th>🕒 Turno</th><th>📍 Coordenadas (Lat, Lon)</th><th>Quitar</th>" +
                    "</tr></thead><tbody>";

                estaciones.forEach((nom, i) => {
                    const key = nom.toLowerCase();
                    const db = ESTACIONES_DB[key] || {};
                    const ed = edicionesEstacion[key] || {};

                    const puerta = ed.puerta !== undefined ? ed.puerta : (db.puerta || ("M-0" + (i + 1)));
                    const guardia = ed.guardia !== undefined ? ed.guardia : (db.guardia || "");
                    const turno = ed.turno !== undefined ? ed.turno : (db.turno || "Diurno");
                    const lat = ed.lat !== undefined ? ed.lat : (db.lat || "14.6349");
                    const lon = ed.lon !== undefined ? ed.lon : (db.lon || "-90.5069");

                    htmlE += "<tr>" +
                        "<td style='font-weight:800; color:#64748b;'>#" + (i + 1) + "</td>" +
                        "<td style='font-weight:700; color:#0f172a;'>🚏 " + escHtml(nom) +
                        "<input type='hidden' name='est_nombre' value='" + escHtml(nom) + "'></td>" +
                        "<td><input type='text' name='est_puerta' value='" + escHtml(puerta) + "' placeholder='Ej. M-01' oninput='guardarEdicionEstacion(\"" + escHtml(key) + "\",\"puerta\",this.value)'></td>" +
                        "<td><input type='text' name='est_guardia' value='" + escHtml(guardia) + "' placeholder='Nombre del guardia (RN05)' oninput='guardarEdicionEstacion(\"" + escHtml(key) + "\",\"guardia\",this.value)'></td>" +
                        "<td><select name='est_turno' onchange='guardarEdicionEstacion(\"" + escHtml(key) + "\",\"turno\",this.value)'>" +
                        "<option value='Diurno'" + (turno === 'Diurno' ? " selected" : "") + ">☀️ Diurno</option>" +
                        "<option value='Nocturno'" + (turno === 'Nocturno' ? " selected" : "") + ">🌙 Nocturno</option>" +
                        "<option value='Mixto'" + (turno === 'Mixto' ? " selected" : "") + ">🔄 Mixto</option>" +
                        "</select></td>" +
                        "<td style='display:flex; gap:6px;'>" +
                        "<input type='text' name='est_lat' value='" + escHtml(lat) + "' placeholder='Lat' oninput='guardarEdicionEstacion(\"" + escHtml(key) + "\",\"lat\",this.value)'>" +
                        "<input type='text' name='est_lon' value='" + escHtml(lon) + "' placeholder='Lon' oninput='guardarEdicionEstacion(\"" + escHtml(key) + "\",\"lon\",this.value)'>" +
                        "</td>" +
                        "<td style='text-align:center;'><button type='button' class='btn-sec' style='background:#fee2e2; color:#dc2626;' onclick='quitarEstacionIdx(" + i + ")'>✕</button></td>" +
                        "</tr>";
                });
                htmlE += "</tbody></table>";
                contEst.innerHTML = htmlE;
            }

            // 2. Renderizar tabla de Kilometraje por Tramo
            const contTramos = document.getElementById("contenedorTablaTramos");
            if (estaciones.length < 2) {
                contTramos.innerHTML = "<div style='padding:14px; background:#fff; border:1px dashed #cbd5e1; border-radius:8px; color:#64748b; font-size:13px; text-align:center;'>Agrega al menos 2 estaciones para definir los kilómetros de cada tramo consecutivo.</div>";
                recalcularKmTotal();
            } else {
                let htmlT = "<table class='infra-table'><thead><tr>" +
                    "<th>Tramo</th><th>Estación Origen</th><th></th><th>Estación Destino</th><th>📏 Distancia (km)</th>" +
                    "</tr></thead><tbody>";

                for (let i = 0; i < estaciones.length - 1; i++) {
                    const orig = estaciones[i];
                    const dest = estaciones[i + 1];
                    const tKey = orig.toLowerCase() + "|" + dest.toLowerCase();
                    const kmVal = edicionesTramo[tKey] !== undefined ? edicionesTramo[tKey] : (DISTANCIAS_DB[tKey] || "1.50");

                    htmlT += "<tr>" +
                        "<td style='font-weight:800; color:#0369a1;'>Tramo #" + (i + 1) + "</td>" +
                        "<td style='font-weight:700;'>🚏 " + escHtml(orig) + "<input type='hidden' name='tramo_origen' value='" + escHtml(orig) + "'></td>" +
                        "<td style='color:#94a3b8; font-weight:bold;'>➔</td>" +
                        "<td style='font-weight:700;'>🏁 " + escHtml(dest) + "<input type='hidden' name='tramo_destino' value='" + escHtml(dest) + "'></td>" +
                        "<td style='max-width:180px;'><input type='number' step='0.01' min='0.05' max='500' name='tramo_km' class='input-km-tramo' value='" + escHtml(kmVal) + "' oninput='guardarEdicionTramo(\"" + escHtml(tKey) + "\", this.value)' required></td>" +
                        "</tr>";
                }
                htmlT += "</tbody></table>";
                contTramos.innerHTML = htmlT;
                recalcularKmTotal();
            }
        }

        function recalcularKmTotal() {
            const inputs = document.querySelectorAll(".input-km-tramo");
            let suma = 0;
            let count = 0;
            inputs.forEach(inp => {
                const v = parseFloat(inp.value);
                if (!isNaN(v) && v > 0) {
                    suma += v;
                    count++;
                }
            });
            document.getElementById("lblKmTotal").textContent = suma.toFixed(2) + " km (" + count + (count === 1 ? " tramo)" : " tramos)");
        }

        function autocompletarKilometros() {
            document.querySelectorAll(".input-km-tramo").forEach(inp => {
                if (!inp.value || parseFloat(inp.value) <= 0) {
                    inp.value = "1.50";
                }
            });
            recalcularKmTotal();
        }

        function autocompletarHorarios() {
            document.getElementById("hs1").value = "06:00"; document.getElementById("hl1").value = "07:30";
            document.getElementById("hs2").value = "08:00"; document.getElementById("hl2").value = "09:30";
            document.getElementById("hs3").value = "10:00"; document.getElementById("hl3").value = "11:30";
            document.getElementById("hs4").value = "12:00"; document.getElementById("hl4").value = "13:30";
            document.getElementById("hs5").value = "14:00"; document.getElementById("hl5").value = "15:30";
            document.getElementById("hs6").value = "16:00"; document.getElementById("hl6").value = "18:00";
        }
    </script>
</body>
</html>