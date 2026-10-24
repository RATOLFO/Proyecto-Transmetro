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
    // SEGURIDAD: Solo Administrador
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

    // PROCESAMIENTO DE POST (GUARDAR EDICIÓN COMPLETA O ELIMINAR)
    if ("POST".equalsIgnoreCase(request.getMethod())) {
        request.setCharacterEncoding("UTF-8");
        String accion = t(request.getParameter("accion"));
        Connection con = null;
        try {
            con = DriverManager.getConnection(dbUrl, dbUser, dbPass);
            con.setAutoCommit(false);

            if ("eliminar_ruta".equals(accion)) {
                int idDel = Integer.parseInt(t(request.getParameter("id_ruta")));
                try (PreparedStatement psD1 = con.prepareStatement("DELETE FROM distancias_tramos WHERE id_ruta = ?")) {
                    psD1.setInt(1, idDel);
                    psD1.executeUpdate();
                }
                try (PreparedStatement psD2 = con.prepareStatement("DELETE FROM rutas_operativas WHERE id_ruta = ?")) {
                    psD2.setInt(1, idDel);
                    psD2.executeUpdate();
                }
                con.commit();
                mensaje = "✅ Ruta operativa y sus tramos eliminados con éxito.";

            } else if ("guardar_edicion".equals(accion)) {
                int idRuta = Integer.parseInt(t(request.getParameter("id_ruta")));
                String nRuta = t(request.getParameter("nombre_ruta"));
                int idMain = Integer.parseInt(t(request.getParameter("id_vehiculo_main")));
                int idBackup = Integer.parseInt(t(request.getParameter("id_vehiculo_backup")));

                String strExtra = t(request.getParameter("id_vehiculo_extra"));
                Integer idExtra = !strExtra.isEmpty() ? Integer.parseInt(strExtra) : null;

                String strPiloto = t(request.getParameter("id_piloto"));
                Integer idPiloto = !strPiloto.isEmpty() ? Integer.parseInt(strPiloto) : null;

                if (idMain == idBackup || (idExtra != null && (idMain == idExtra || idBackup == idExtra))) {
                    throw new Exception("Un mismo vehículo físico no puede ocupar dos roles a la vez en la misma ruta.");
                }

                // Actualizar parqueos base si el administrador los modificó
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

                // Limpiar lista de estaciones
                String rawEstaciones = t(request.getParameter("estaciones"));
                String[] partesEst = rawEstaciones.split(",");
                List<String> listaEstLimpia = new ArrayList<>();
                for (String p : partesEst) {
                    String limpia = p.trim();
                    if (!limpia.isEmpty()) listaEstLimpia.add(limpia);
                }
                if (listaEstLimpia.size() < 2) {
                    throw new Exception("La ruta debe tener al menos 2 estaciones.");
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

                // 1. Actualizar datos de la ruta
                try (PreparedStatement ps = con.prepareStatement(
                        "UPDATE rutas_operativas SET nombre_ruta=?, id_vehiculo_main=?, id_vehiculo_backup=?, id_vehiculo_extra=?, id_piloto=?, lista_estaciones=?, " +
                        "hora_salida_1=?, hora_llegada_1=?, hora_salida_2=?, hora_llegada_2=?, hora_salida_3=?, hora_llegada_3=?, " +
                        "hora_salida_4=?, hora_llegada_4=?, hora_salida_5=?, hora_llegada_5=?, hora_salida_6=?, hora_llegada_6=? " +
                        "WHERE id_ruta=?")) {
                    ps.setString(1, nRuta);
                    ps.setInt(2, idMain);
                    ps.setInt(3, idBackup);
                    if (idExtra != null) ps.setInt(4, idExtra); else ps.setNull(4, Types.INTEGER);
                    if (idPiloto != null) ps.setInt(5, idPiloto); else ps.setNull(5, Types.INTEGER);
                    ps.setString(6, estacionesUnidas);
                    ps.setString(7, hs1); ps.setString(8, hl1);
                    ps.setString(9, hs2); ps.setString(10, hl2);
                    ps.setString(11, hs3); ps.setString(12, hl3);
                    ps.setString(13, hs4); ps.setString(14, hl4);
                    ps.setString(15, hs5); ps.setString(16, hl5);
                    ps.setString(17, hs6); ps.setString(18, hl6);
                    ps.setInt(19, idRuta);
                    ps.executeUpdate();
                }

                // 2. Sincronizar Estaciones, Molinetes y Guardias (RN05)
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

                        // Si se indicó Molinete y Guardia, crear o actualizar
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

                // 3. Actualizar Kilometraje por Tramo de esta ruta (RF02)
                String[] arrTramoOrigen = request.getParameterValues("tramo_origen");
                String[] arrTramoDestino = request.getParameterValues("tramo_destino");
                String[] arrTramoKm = request.getParameterValues("tramo_km");

                if (arrTramoOrigen != null && arrTramoDestino != null && arrTramoKm != null) {
                    try (PreparedStatement psDelKm = con.prepareStatement("DELETE FROM distancias_tramos WHERE id_ruta = ?")) {
                        psDelKm.setInt(1, idRuta);
                        psDelKm.executeUpdate();
                    }
                    try (PreparedStatement psInsKm = con.prepareStatement(
                            "INSERT INTO distancias_tramos (id_ruta, estacion_origen, estacion_destino, distancia_km) VALUES (?, ?, ?, ?)")) {
                        for (int i = 0; i < arrTramoOrigen.length; i++) {
                            String orig = t(arrTramoOrigen[i]);
                            String dest = t(arrTramoDestino[i]);
                            String kmStr = (i < arrTramoKm.length) ? t(arrTramoKm[i]) : "";
                            if (!orig.isEmpty() && !dest.isEmpty() && !kmStr.isEmpty()) {
                                BigDecimal kmVal = new BigDecimal(kmStr);
                                if (kmVal.compareTo(BigDecimal.ZERO) > 0) {
                                    psInsKm.setInt(1, idRuta);
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
                mensaje = "✅ Ruta '" + nRuta + "' actualizada correctamente junto con su flota, parqueos, piloto, estaciones, molinetes y kilometraje.";
            }
        } catch (Exception e) {
            if (con != null) {
                try { con.rollback(); } catch (SQLException ex) {}
            }
            mensaje = "❌ Error: " + e.getMessage();
            tipoMensaje = "error";
        } finally {
            if (con != null) {
                try { con.setAutoCommit(true); con.close(); } catch (SQLException ex) {}
            }
        }
    }

    boolean modoEdicion = "editar".equals(request.getParameter("accion"));
    int idRutaEdicion = 0;
    if (modoEdicion && request.getParameter("id_ruta") != null) {
        try { idRutaEdicion = Integer.parseInt(request.getParameter("id_ruta")); } catch (Exception ignorar) {}
    }
%>

<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <title>Gestión y Edición de Rutas - Transmetro</title>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&display=swap" rel="stylesheet">
    <style>
        body { font-family: 'Inter', sans-serif; background-color: #f0f2f5; margin: 0; padding-top: 70px; }
        .header { background: #ffffff; color: #1e293b; padding: 15px 25px; position: fixed; top: 0; width: 100%; box-sizing: border-box; z-index: 1000; display: flex; justify-content: space-between; align-items: center; border-bottom: 1px solid #e2e8f0; }
        .header h1 { margin: 0; font-size: 18px; text-align: center; flex-grow: 1; font-weight: 700; }
        .menu-btn { background: none; border: none; color: #475569; font-size: 24px; cursor: pointer; }
        .overlay { display: none; position: fixed; width: 100%; height: 100%; top: 0; left: 0; background: rgba(15, 23, 42, 0.4); z-index: 999; }

        .main-container { max-width: 1180px; margin: 30px auto; padding: 0 20px 50px 20px; }
        .page-title { display: flex; justify-content: space-between; align-items: flex-end; flex-wrap: wrap; gap: 12px; margin-bottom: 20px; }
        .page-title h2 { margin: 0 0 5px 0; font-size: 26px; font-weight: 800; color: #0f172a; }
        .page-title p { margin: 0; color: #64748b; font-size: 14px; }

        .card-container { background: #ffffff; border-radius: 14px; box-shadow: 0 4px 12px rgba(0,0,0,0.05); padding: 25px; border-top: 5px solid #3498db; overflow-x: auto; }

        table { width: 100%; border-collapse: collapse; text-align: left; }
        th { background-color: #f8fafc; padding: 13px 14px; font-size: 11px; color: #64748b; font-weight: 800; text-transform: uppercase; border-bottom: 2px solid #e2e8f0; }
        td { padding: 14px; font-size: 13px; color: #334155; border-bottom: 1px solid #f1f5f9; vertical-align: top; }
        tr:hover td { background-color: #f8fafc; }

        .btn-edit { background: #e0f2fe; color: #0284c7; border: 1px solid #bae6fd; padding: 8px 14px; border-radius: 8px; font-weight: 800; cursor: pointer; text-decoration: none; font-size: 12px; display: inline-block; white-space: nowrap; }
        .btn-edit:hover { background: #0284c7; color: white; }
        .btn-del { background: #fee2e2; color: #ef4444; border: 1px solid #fca5a5; padding: 8px 12px; border-radius: 8px; font-weight: bold; cursor: pointer; transition: 0.2s; }
        .btn-del:hover { background: #ef4444; color: white; }
        .btn-sec { background: #e2e8f0; color: #1e293b; border: none; padding: 8px 14px; border-radius: 8px; font-size: 12px; font-weight: 700; cursor: pointer; text-decoration: none; display: inline-block; }
        .btn-sec:hover { background: #cbd5e1; }

        .alerta { padding: 15px; border-radius: 8px; font-weight: 600; margin-bottom: 20px; font-size: 14px; }
        .exito { background: #ecfdf5; color: #065f46; border: 1px solid #a7f3d0; }
        .error { background: #fef2f2; color: #991b1b; border: 1px solid #fecaca; }
        .empty-state { text-align: center; padding: 40px; color: #94a3b8; font-weight: 600; border: 1px dashed #cbd5e1; border-radius: 8px; }

        /* ESTILOS DEL FORMULARIO DE EDICIÓN */
        .form-section { background: #f8fafc; padding: 22px; border-radius: 10px; border: 1px solid #e2e8f0; margin-bottom: 22px; }
        .form-section h3 { margin-top: 0; color: #1e293b; border-bottom: 1px solid #cbd5e1; padding-bottom: 10px; font-size: 16px; display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 8px; }
        .form-group { margin-bottom: 15px; }
        .form-group label { display: block; font-size: 13px; font-weight: 700; color: #475569; margin-bottom: 5px; }
        .form-group input, .form-group select, .form-group textarea { width: 100%; padding: 10px 12px; border: 1px solid #cbd5e1; border-radius: 8px; box-sizing: border-box; background: #fff; font-size: 14px; }
        .grid-2 { display: grid; grid-template-columns: 1.3fr 1fr; gap: 16px; }
        .grid-3 { display: grid; grid-template-columns: 1fr 1fr 1fr; gap: 16px; }
        @media (max-width: 860px) { .grid-2, .grid-3 { grid-template-columns: 1fr; } }

        .vehiculo-box { background: #ffffff; border: 1px solid #e2e8f0; border-radius: 10px; padding: 14px; }
        .vehiculo-meta { margin-top: 8px; padding: 8px 10px; background: #f1f5f9; border-radius: 6px; font-size: 12px; color: #334155; line-height: 1.5; }
        .parqueo-inline { margin-top: 10px; padding-top: 8px; border-top: 1px dashed #cbd5e1; }
        .parqueo-inline label { font-size: 11px; color: #0369a1; font-weight: 700; text-transform: uppercase; }

        .grid-horarios { display: grid; grid-template-columns: repeat(3, 1fr); gap: 15px; background: white; padding: 15px; border: 1px solid #e2e8f0; border-radius: 8px; }
        @media (max-width: 860px) { .grid-horarios { grid-template-columns: 1fr; } }
        .turno-caja { text-align: center; border: 1px solid #f1f5f9; background: #f8fafc; padding: 12px; border-radius: 8px; }

        .btn-submit { background: #3498db; color: white; border: none; padding: 15px; border-radius: 8px; font-weight: 800; cursor: pointer; width: 100%; font-size: 16px; }
        .btn-submit:hover { background: #2980b9; }
        .btn-cancelar { background: #64748b; color: white; border: none; padding: 15px; border-radius: 8px; font-weight: bold; cursor: pointer; width: 100%; font-size: 16px; text-decoration: none; display: inline-block; text-align: center; margin-top: 10px; box-sizing: border-box; }

        .chips { display: flex; flex-wrap: wrap; gap: 8px; align-items: center; margin-top: 10px; padding: 12px; background: #fff; border: 1px dashed #cbd5e1; border-radius: 8px; }
        .chips-label { font-size: 12px; color: #475569; font-weight: 700; width: 100%; margin-bottom: 4px; }
        .chip { background: #e0f2fe; color: #0369a1; border: 1px solid #bae6fd; border-radius: 20px; padding: 5px 11px; font-size: 12px; font-weight: 700; cursor: pointer; display: inline-flex; align-items: center; gap: 6px; }
        .chip:hover { background: #0369a1; color: white; }
        .chip .chip-sub { font-size: 10px; font-weight: 600; background: rgba(255,255,255,0.8); color: #0f172a; padding: 1px 6px; border-radius: 10px; }

        .infra-table { width: 100%; border-collapse: collapse; background: #fff; border-radius: 8px; overflow: hidden; border: 1px solid #e2e8f0; margin-top: 10px; }
        .infra-table th { background: #f1f5f9; color: #475569; font-size: 11px; font-weight: 800; text-transform: uppercase; padding: 10px 12px; text-align: left; border-bottom: 1px solid #cbd5e1; }
        .infra-table td { padding: 10px 12px; border-bottom: 1px solid #f1f5f9; font-size: 13px; vertical-align: middle; }
        .infra-table input, .infra-table select { padding: 7px 10px; font-size: 13px; border: 1px solid #cbd5e1; border-radius: 6px; width: 100%; box-sizing: border-box; }

        .km-summary-bar { display: flex; justify-content: space-between; align-items: center; background: #eff6ff; border: 1px solid #bfdbfe; color: #1e3a8a; padding: 12px 16px; border-radius: 8px; margin-top: 12px; font-weight: 700; font-size: 14px; }

        .est-mini-pill { display: inline-flex; align-items: center; gap: 4px; background: #f1f5f9; border: 1px solid #e2e8f0; border-radius: 6px; padding: 3px 8px; font-size: 11px; margin: 2px; color: #1e293b; }
        .est-mini-pill.con-seg { background: #ecfdf5; border-color: #a7f3d0; color: #065f46; }
    </style>
    <link rel="stylesheet" href="css/transmetro.css">
</head>
<body>
    <jsp:include page="menu_izquierdo.jsp" />
    <jsp:include page="menu_derecho.jsp" />
    <div id="overlay" class="overlay" onclick="closeAllMenus()"></div>

    <div class="header">
        <button class="menu-btn" onclick="toggleMenu('left')">☰</button>
        <h1>Módulo de Edición Logística e Infraestructura</h1>
        <button class="menu-btn" onclick="toggleMenu('right')">⚙️</button>
    </div>

    <div class="main-container">
        <div class="page-title">
            <div>
                <h2><%= modoEdicion ? "✏️ Editando Ruta Operativa #" + idRutaEdicion : "🗺️ Gestión Integral de Rutas Activas" %></h2>
                <p><%= modoEdicion ? "Configura en un solo paso vehículos, parqueos, piloto, estaciones, molinetes/guardias y kilometraje por tramo." : "Visualiza y edita las rutas junto con su piloto, parqueo base, molinetes de estaciones y kilometraje." %></p>
            </div>
            <div style="display:flex; gap:10px;">
                <a href="nueva_ruta.jsp" class="btn-sec" style="background:#10b981; color:#fff;">➕ Configurar Nueva Ruta</a>
                <a href="admin_infra.jsp" class="btn-sec">🏗️ Gestionar Infraestructura</a>
            </div>
        </div>

        <% if (!mensaje.isEmpty()) { %>
            <div class="alerta <%= tipoMensaje %>"><%= h(mensaje) %></div>
        <% } %>

        <div class="card-container">
            <%
                if (modoEdicion) {
                    Connection conEdit = null;
                    try {
                        conEdit = DriverManager.getConnection(dbUrl, dbUser, dbPass);
                        Statement stEdit = conEdit.createStatement();

                        // 1. Parqueos
                        List<Map<String, String>> listaParqueos = new ArrayList<>();
                        ResultSet rsPq = stEdit.executeQuery(
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

                        // 2. Vehículos
                        List<Map<String, String>> listaVehiculos = new ArrayList<>();
                        StringBuilder jsVehiculos = new StringBuilder("{");
                        ResultSet rsVeh = stEdit.executeQuery(
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
                        List<Map<String, String>> listaPilotos = new ArrayList<>();
                        ResultSet rsPil = stEdit.executeQuery(
                            "SELECT p.id, p.nombre, p.edad, p.identificador_transmetro, IFNULL(p.usuario_asignado, 'Sin asignar') AS usr " +
                            "FROM pilotos_catalogo p ORDER BY p.nombre ASC");
                        while (rsPil.next()) {
                            Map<String, String> p = new HashMap<>();
                            p.put("id", rsPil.getString("id"));
                            p.put("nombre", rsPil.getString("nombre"));
                            p.put("edad", rsPil.getString("edad"));
                            p.put("identificador", rsPil.getString("identificador_transmetro"));
                            p.put("usr", rsPil.getString("usr"));
                            listaPilotos.add(p);
                        }
                        rsPil.close();

                        // 4. Estaciones + Molinetes y Guardias
                        Map<String, Map<String, String>> mapaEstaciones = new LinkedHashMap<>();
                        ResultSet rsEst = stEdit.executeQuery(
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

                        ResultSet rsCat = stEdit.executeQuery("SELECT nombre FROM estaciones_catalogo ORDER BY nombre ASC");
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

                        StringBuilder jsEstaciones = new StringBuilder("{");
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

                        // 5. Distancias de tramos (primero generales, luego las de esta ruta con prioridad)
                        Map<String, String> mapaDistancias = new HashMap<>();
                        ResultSet rsDistAll = stEdit.executeQuery("SELECT estacion_origen, estacion_destino, distancia_km FROM distancias_tramos");
                        while (rsDistAll.next()) {
                            String o = t(rsDistAll.getString(1)).toLowerCase();
                            String d = t(rsDistAll.getString(2)).toLowerCase();
                            String km = rsDistAll.getBigDecimal(3).toPlainString();
                            mapaDistancias.put(o + "|" + d, km);
                            mapaDistancias.put(d + "|" + o, km);
                        }
                        rsDistAll.close();

                        ResultSet rsDistRuta = stEdit.executeQuery("SELECT estacion_origen, estacion_destino, distancia_km FROM distancias_tramos WHERE id_ruta = " + idRutaEdicion);
                        while (rsDistRuta.next()) {
                            String o = t(rsDistRuta.getString(1)).toLowerCase();
                            String d = t(rsDistRuta.getString(2)).toLowerCase();
                            String km = rsDistRuta.getBigDecimal(3).toPlainString();
                            mapaDistancias.put(o + "|" + d, km);
                            mapaDistancias.put(d + "|" + o, km);
                        }
                        rsDistRuta.close();

                        StringBuilder jsDistancias = new StringBuilder("{");
                        boolean firstD = true;
                        for (Map.Entry<String, String> ed : mapaDistancias.entrySet()) {
                            if (!firstD) jsDistancias.append(",");
                            firstD = false;
                            jsDistancias.append("\"").append(js(ed.getKey())).append("\":\"").append(js(ed.getValue())).append("\"");
                        }
                        jsDistancias.append("}");

                        // 6. Cargar la ruta a editar
                        ResultSet rsRuta = stEdit.executeQuery("SELECT * FROM rutas_operativas WHERE id_ruta = " + idRutaEdicion);
                        if (rsRuta.next()) {
                            int idMainActual = rsRuta.getInt("id_vehiculo_main");
                            int idBackupActual = rsRuta.getInt("id_vehiculo_backup");
                            int idExtraActual = rsRuta.getObject("id_vehiculo_extra") != null ? rsRuta.getInt("id_vehiculo_extra") : 0;
                            int idPilotoActual = 0;
                            try {
                                if (rsRuta.getObject("id_piloto") != null) idPilotoActual = rsRuta.getInt("id_piloto");
                            } catch (Exception ignorar) {}
            %>
                            <form method="POST" action="editar_rutas.jsp">
                                <input type="hidden" name="accion" value="guardar_edicion">
                                <input type="hidden" name="id_ruta" value="<%= idRutaEdicion %>">

                                <!-- SECCIÓN 1: DATOS GENERALES, PILOTO, FLOTA Y PARQUEO -->
                                <div class="form-section">
                                    <h3>
                                        <span>1. Datos Generales, Piloto Asignado, Flota y Parqueo Base (RN04)</span>
                                        <span style="font-size:12px; color:#64748b; font-weight:600;">Puedes reasignar unidad, piloto o parqueo directamente aquí</span>
                                    </h3>
                                    <div class="grid-2">
                                        <div class="form-group">
                                            <label>🗺️ Nombre Comercial de la Ruta</label>
                                            <input type="text" name="nombre_ruta" value="<%= h(rsRuta.getString("nombre_ruta")) %>" required>
                                        </div>
                                        <div class="form-group">
                                            <label>👨‍✈️ Piloto Titular Asignado</label>
                                            <select name="id_piloto">
                                                <option value="">-- Sin Piloto Asignado --</option>
                                                <% for (Map<String, String> pil : listaPilotos) {
                                                    int idP = Integer.parseInt(pil.get("id"));
                                                    String selP = (idP == idPilotoActual) ? "selected" : "";
                                                %>
                                                    <option value="<%= idP %>" <%= selP %>>
                                                        👨‍✈️ <%= h(pil.get("nombre")) %> (ID: <%= h(pil.get("identificador")) %> · <%= h(pil.get("edad")) %> años · Cuenta: <%= h(pil.get("usr")) %>)
                                                    </option>
                                                <% } %>
                                            </select>
                                        </div>
                                    </div>

                                    <div class="grid-3">
                                        <!-- PRINCIPAL -->
                                        <div class="vehiculo-box">
                                            <div class="form-group" style="margin-bottom:0;">
                                                <label>🟢 Vehículo Principal</label>
                                                <select name="id_vehiculo_main" id="sel_main" onchange="actualizarMetaVehiculo('main')" required>
                                                    <% for (Map<String, String> v : listaVehiculos) {
                                                        int idV = Integer.parseInt(v.get("id"));
                                                        String sel = (idV == idMainActual) ? "selected" : "";
                                                    %>
                                                        <option value="<%= idV %>" <%= sel %>>
                                                            🚍 <%= h(v.get("placa")) %> · Cap: <%= h(v.get("cap")) %> · 🅿️ <%= h(v.get("parqueo")) %>
                                                        </option>
                                                    <% } %>
                                                </select>
                                            </div>
                                            <div id="meta_main" class="vehiculo-meta"></div>
                                            <div class="parqueo-inline">
                                                <label>🅿️ Parqueo Base (Unidad Principal)</label>
                                                <select name="parqueo_main" id="pq_main">
                                                    <% for (Map<String, String> pq : listaParqueos) { %>
                                                        <option value="<%= h(pq.get("id")) %>">🅿️ <%= h(pq.get("nombre")) %> (<%= h(pq.get("ocu")) %>/<%= h(pq.get("cap")) %>)</option>
                                                    <% } %>
                                                </select>
                                            </div>
                                        </div>

                                        <!-- REFUERZO -->
                                        <div class="vehiculo-box">
                                            <div class="form-group" style="margin-bottom:0;">
                                                <label>🔵 Vehículo de Refuerzo</label>
                                                <select name="id_vehiculo_backup" id="sel_backup" onchange="actualizarMetaVehiculo('backup')" required>
                                                    <% for (Map<String, String> v : listaVehiculos) {
                                                        int idV = Integer.parseInt(v.get("id"));
                                                        String sel = (idV == idBackupActual) ? "selected" : "";
                                                    %>
                                                        <option value="<%= idV %>" <%= sel %>>
                                                            🚍 <%= h(v.get("placa")) %> · Cap: <%= h(v.get("cap")) %> · 🅿️ <%= h(v.get("parqueo")) %>
                                                        </option>
                                                    <% } %>
                                                </select>
                                            </div>
                                            <div id="meta_backup" class="vehiculo-meta"></div>
                                            <div class="parqueo-inline">
                                                <label>🅿️ Parqueo Base (Unidad Refuerzo)</label>
                                                <select name="parqueo_backup" id="pq_backup">
                                                    <% for (Map<String, String> pq : listaParqueos) { %>
                                                        <option value="<%= h(pq.get("id")) %>">🅿️ <%= h(pq.get("nombre")) %> (<%= h(pq.get("ocu")) %>/<%= h(pq.get("cap")) %>)</option>
                                                    <% } %>
                                                </select>
                                            </div>
                                        </div>

                                        <!-- EXTRA -->
                                        <div class="vehiculo-box">
                                            <div class="form-group" style="margin-bottom:0;">
                                                <label>🟣 Bus Extra (Emergencia)</label>
                                                <select name="id_vehiculo_extra" id="sel_extra" onchange="actualizarMetaVehiculo('extra')">
                                                    <option value="">-- Ninguno Asignado --</option>
                                                    <% for (Map<String, String> v : listaVehiculos) {
                                                        int idV = Integer.parseInt(v.get("id"));
                                                        String sel = (idExtraActual > 0 && idV == idExtraActual) ? "selected" : "";
                                                    %>
                                                        <option value="<%= idV %>" <%= sel %>>
                                                            🚑 <%= h(v.get("placa")) %> · Cap: <%= h(v.get("cap")) %> · 🅿️ <%= h(v.get("parqueo")) %>
                                                        </option>
                                                    <% } %>
                                                </select>
                                            </div>
                                            <div id="meta_extra" class="vehiculo-meta"></div>
                                            <div class="parqueo-inline">
                                                <label>🅿️ Parqueo Base (Unidad Extra)</label>
                                                <select name="parqueo_extra" id="pq_extra">
                                                    <option value="">-- Sin cambio --</option>
                                                    <% for (Map<String, String> pq : listaParqueos) { %>
                                                        <option value="<%= h(pq.get("id")) %>">🅿️ <%= h(pq.get("nombre")) %> (<%= h(pq.get("ocu")) %>/<%= h(pq.get("cap")) %>)</option>
                                                    <% } %>
                                                </select>
                                            </div>
                                        </div>
                                    </div>
                                </div>

                                <!-- SECCIÓN 2: ESTACIONES + MOLINETES Y GUARDIAS -->
                                <div class="form-section">
                                    <h3>
                                        <span>2. Estaciones de la Ruta, Molinetes y Guardias de Seguridad (RN05)</span>
                                        <span style="font-size:12px; color:#0369a1; font-weight:600;">Edita aquí mismo la puerta/molinete y guardia de cada estación</span>
                                    </h3>

                                    <div class="form-group">
                                        <label>🚏 Estaciones (Separadas por comas en orden de recorrido)</label>
                                        <textarea name="estaciones" id="txtEstaciones" rows="2" oninput="sincronizarRuta()" required><%= h(rsRuta.getString("lista_estaciones")) %></textarea>
                                        <div class="chips">
                                            <span class="chips-label">➕ Clic para agregar estación del catálogo:</span>
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
                                            🚪 Detalle de Molinetes, Guardias y Coordenadas de las Estaciones de esta Ruta:
                                        </label>
                                        <div id="contenedorTablaEstaciones"></div>
                                    </div>
                                </div>

                                <!-- SECCIÓN 3: KILOMETRAJE POR TRAMO -->
                                <div class="form-section">
                                    <h3>
                                        <span>3. Kilometraje entre Estaciones y Distancia Total (RF02)</span>
                                        <button type="button" class="btn-sec" onclick="autocompletarKilometros()">⚡ Autocompletar tramos vacíos (1.50 km)</button>
                                    </h3>
                                    <div id="contenedorTablaTramos"></div>
                                    <div class="km-summary-bar">
                                        <span>📏 Distancia Total de la Ruta:</span>
                                        <span id="lblKmTotal" style="font-size:18px; color:#0369a1;">0.00 km</span>
                                    </div>
                                </div>

                                <!-- SECCIÓN 4: HORARIOS -->
                                <div class="form-section">
                                    <h3>2. Planificación de Turnos (Horarios T1 a T6)</h3>
                                    <div class="grid-horarios">
                                        <div class="turno-caja">
                                            <label><b>Turno 1 (IDA)</b></label><br>
                                            <input type="time" name="hs1" value="<%= rsRuta.getString("hora_salida_1") != null ? rsRuta.getString("hora_salida_1") : "" %>" required style="width:45%;"> a
                                            <input type="time" name="hl1" value="<%= rsRuta.getString("hora_llegada_1") != null ? rsRuta.getString("hora_llegada_1") : "" %>" required style="width:45%;">
                                        </div>
                                        <div class="turno-caja">
                                            <label>Turno 2 (RETORNO)</label><br>
                                            <input type="time" name="hs2" value="<%= rsRuta.getString("hora_salida_2") != null ? rsRuta.getString("hora_salida_2") : "" %>" style="width:45%;"> a
                                            <input type="time" name="hl2" value="<%= rsRuta.getString("hora_llegada_2") != null ? rsRuta.getString("hora_llegada_2") : "" %>" style="width:45%;">
                                        </div>
                                        <div class="turno-caja">
                                            <label>Turno 3 (IDA)</label><br>
                                            <input type="time" name="hs3" value="<%= rsRuta.getString("hora_salida_3") != null ? rsRuta.getString("hora_salida_3") : "" %>" style="width:45%;"> a
                                            <input type="time" name="hl3" value="<%= rsRuta.getString("hora_llegada_3") != null ? rsRuta.getString("hora_llegada_3") : "" %>" style="width:45%;">
                                        </div>
                                        <div class="turno-caja">
                                            <label>Turno 4 (RETORNO)</label><br>
                                            <input type="time" name="hs4" value="<%= rsRuta.getString("hora_salida_4") != null ? rsRuta.getString("hora_salida_4") : "" %>" style="width:45%;"> a
                                            <input type="time" name="hl4" value="<%= rsRuta.getString("hora_llegada_4") != null ? rsRuta.getString("hora_llegada_4") : "" %>" style="width:45%;">
                                        </div>
                                        <div class="turno-caja">
                                            <label>Turno 5 (IDA)</label><br>
                                            <input type="time" name="hs5" value="<%= rsRuta.getString("hora_salida_5") != null ? rsRuta.getString("hora_salida_5") : "" %>" style="width:45%;"> a
                                            <input type="time" name="hl5" value="<%= rsRuta.getString("hora_llegada_5") != null ? rsRuta.getString("hora_llegada_5") : "" %>" style="width:45%;">
                                        </div>
                                        <div class="turno-caja">
                                            <label>Turno 6 (RETORNO)</label><br>
                                            <input type="time" name="hs6" value="<%= rsRuta.getString("hora_salida_6") != null ? rsRuta.getString("hora_salida_6") : "" %>" style="width:45%;"> a
                                            <input type="time" name="hl6" value="<%= rsRuta.getString("hora_llegada_6") != null ? rsRuta.getString("hora_llegada_6") : "" %>" style="width:45%;">
                                        </div>
                                    </div>
                                </div>

                                <button type="submit" class="btn-submit">💾 Guardar Todos los Cambios (Ruta, Parqueo, Molinetes y Kilometraje)</button>
                                <a href="editar_rutas.jsp" class="btn-cancelar">❌ Cancelar y Volver al Listado</a>
                            </form>

                            <script>
                                const VEHICULOS_DB = <%= jsVehiculos.toString() %>;
                                const ESTACIONES_DB = <%= jsEstaciones.toString() %>;
                                const DISTANCIAS_DB = <%= jsDistancias.toString() %>;
                                const edicionesEstacion = {};
                                const edicionesTramo = {};

                                function escHtml(s) {
                                    if (!s) return "";
                                    return String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
                                }

                                function actualizarMetaVehiculo(rol) {
                                    const sel = document.getElementById("sel_" + rol);
                                    const meta = document.getElementById("meta_" + rol);
                                    const pqSel = document.getElementById("pq_" + rol);
                                    if (!sel || !meta) return;
                                    const idV = sel.value;
                                    if (!idV || !VEHICULOS_DB[idV]) {
                                        meta.innerHTML = "Sin unidad seleccionada.";
                                        return;
                                    }
                                    const v = VEHICULOS_DB[idV];
                                    meta.innerHTML =
                                        "<b>🚍 Placa:</b> " + escHtml(v.placa) +
                                        " &nbsp;|&nbsp; <b>💺 Cap:</b> " + escHtml(v.cap) + " asientos<br>" +
                                        "<b>🏛️ Muni:</b> " + escHtml(v.muni) +
                                        " &nbsp;|&nbsp; <b>🅿️ Parqueo:</b> " + escHtml(v.parqueo) + " (" + escHtml(v.ocuParqueo) + "/" + escHtml(v.capParqueo) + ")";
                                    if (pqSel && v.idParqueo) pqSel.value = v.idParqueo;
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

                                    const contEst = document.getElementById("contenedorTablaEstaciones");
                                    if (estaciones.length === 0) {
                                        contEst.innerHTML = "<div style='padding:14px; background:#fff; border:1px dashed #cbd5e1; border-radius:8px; color:#64748b; text-align:center;'>Agrega estaciones arriba.</div>";
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
                                                "<td><input type='text' name='est_guardia' value='" + escHtml(guardia) + "' placeholder='Nombre del guardia' oninput='guardarEdicionEstacion(\"" + escHtml(key) + "\",\"guardia\",this.value)'></td>" +
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

                                    const contTramos = document.getElementById("contenedorTablaTramos");
                                    if (estaciones.length < 2) {
                                        contTramos.innerHTML = "<div style='padding:14px; background:#fff; border:1px dashed #cbd5e1; border-radius:8px; color:#64748b; text-align:center;'>Define al menos 2 estaciones para configurar el kilometraje de cada tramo.</div>";
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
                                        if (!inp.value || parseFloat(inp.value) <= 0) inp.value = "1.50";
                                    });
                                    recalcularKmTotal();
                                }

                                window.addEventListener("DOMContentLoaded", () => {
                                    actualizarMetaVehiculo('main');
                                    actualizarMetaVehiculo('backup');
                                    actualizarMetaVehiculo('extra');
                                    sincronizarRuta();
                                });
                            </script>
            <%
                        }
                        rsRuta.close();
                        stEdit.close();
                        conEdit.close();
                    } catch (Exception e) {
                        out.print("<div class='alerta error'>Error cargando ruta: " + h(e.getMessage()) + "</div>");
                    }
                } else {
            %>
            <!-- VISTA DE TABLA INTEGRAL DE RUTAS -->
            <table>
                <thead>
                    <tr>
                        <th>ID / Ruta</th>
                        <th>Piloto Asignado</th>
                        <th>Flota y Parqueos Base (RN04)</th>
                        <th>Estaciones, Molinetes y Guardias (RN05)</th>
                        <th>Kilometraje (RF02)</th>
                        <th style="text-align: center;">Acciones</th>
                    </tr>
                </thead>
                <tbody>
                    <%
                        try {
                            Connection con = DriverManager.getConnection(dbUrl, dbUser, dbPass);
                            Statement st = con.createStatement();

                            // Mapa rápido de estación -> molinete y guardia
                            Map<String, String> segEstMap = new HashMap<>();
                            ResultSet rsSeg = st.executeQuery(
                                "SELECT e.nombre, a.codigo_puerta, g.nombre_completo " +
                                "FROM estaciones_fisicas e " +
                                "JOIN accesos_molinetes a ON a.id_estacion = e.id_estacion " +
                                "JOIN guardias_seguridad g ON g.id_acceso = a.id_acceso");
                            while (rsSeg.next()) {
                                String k = t(rsSeg.getString(1)).toLowerCase();
                                if (!segEstMap.containsKey(k)) {
                                    segEstMap.put(k, "🚪 " + rsSeg.getString(2) + " · 👮 " + rsSeg.getString(3));
                                }
                            }
                            rsSeg.close();

                            String query =
                                "SELECT r.id_ruta, r.nombre_ruta, r.lista_estaciones, " +
                                "pil.nombre AS nombre_piloto, pil.identificador_transmetro AS id_trans_piloto, " +
                                "vm.placa AS placa_main, vm.capacidad AS cap_main, pm.nombre AS parqueo_main, " +
                                "vb.placa AS placa_backup, pb.nombre AS parqueo_backup, " +
                                "vx.placa AS placa_extra, px.nombre AS parqueo_extra, " +
                                "(SELECT COALESCE(SUM(d.distancia_km), 0) FROM distancias_tramos d WHERE d.id_ruta = r.id_ruta) AS km_total, " +
                                "(SELECT COUNT(*) FROM distancias_tramos d WHERE d.id_ruta = r.id_ruta) AS n_tramos " +
                                "FROM rutas_operativas r " +
                                "LEFT JOIN pilotos_catalogo pil ON r.id_piloto = pil.id " +
                                "LEFT JOIN flota_vehiculos vm ON r.id_vehiculo_main = vm.id_vehiculo " +
                                "LEFT JOIN parqueos pm ON vm.id_parqueo = pm.id_parqueo " +
                                "LEFT JOIN flota_vehiculos vb ON r.id_vehiculo_backup = vb.id_vehiculo " +
                                "LEFT JOIN parqueos pb ON vb.id_parqueo = pb.id_parqueo " +
                                "LEFT JOIN flota_vehiculos vx ON r.id_vehiculo_extra = vx.id_vehiculo " +
                                "LEFT JOIN parqueos px ON vx.id_parqueo = px.id_parqueo " +
                                "ORDER BY r.id_ruta DESC";

                            ResultSet rs = st.executeQuery(query);
                            boolean hayRutas = false;

                            while (rs.next()) {
                                hayRutas = true;
                                int idRuta = rs.getInt("id_ruta");
                                String nombre = rs.getString("nombre_ruta");
                                String listaEst = rs.getString("lista_estaciones");
                                String nomPiloto = rs.getString("nombre_piloto");
                                String idTransPiloto = rs.getString("id_trans_piloto");

                                String pMain = rs.getString("placa_main");
                                String pqMain = rs.getString("parqueo_main");
                                String pBackup = rs.getString("placa_backup");
                                String pqBackup = rs.getString("parqueo_backup");
                                String pExtra = rs.getString("placa_extra");
                                String pqExtra = rs.getString("parqueo_extra");

                                BigDecimal kmRuta = rs.getBigDecimal("km_total");
                                int nTramos = rs.getInt("n_tramos");
                    %>
                                <tr>
                                    <td>
                                        <div style="font-size:11px; font-weight:800; color:#94a3b8;">RUTA #<%= idRuta %></div>
                                        <div style="font-weight:800; color:#0f172a; font-size:15px; margin-top:2px;">🗺️ <%= h(nombre) %></div>
                                    </td>
                                    <td>
                                        <% if (nomPiloto != null) { %>
                                            <div style="font-weight:700; color:#1e3a8a;">👨‍✈️ <%= h(nomPiloto) %></div>
                                            <div style="font-size:11px; color:#64748b; margin-top:2px;">🪪 ID: <%= h(idTransPiloto) %></div>
                                        <% } else { %>
                                            <span style="background:#fef3c7; color:#92400e; padding:3px 8px; border-radius:6px; font-size:11px; font-weight:700;">⚠️ Sin piloto</span>
                                        <% } %>
                                    </td>
                                    <td style="line-height: 1.6;">
                                        <div>🟢 <b><%= h(pMain) %></b> <span style="color:#0369a1; font-size:11px; font-weight:600;">(🅿️ <%= pqMain != null ? h(pqMain) : "Sin parqueo" %>)</span></div>
                                        <div>🔵 <b><%= h(pBackup) %></b> <span style="color:#64748b; font-size:11px;">(🅿️ <%= pqBackup != null ? h(pqBackup) : "Sin parqueo" %>)</span></div>
                                        <% if (pExtra != null) { %>
                                            <div>🟣 <b><%= h(pExtra) %></b> <span style="color:#6b21a8; font-size:11px;">(🅿️ <%= pqExtra != null ? h(pqExtra) : "Sin parqueo" %>)</span></div>
                                        <% } else { %>
                                            <div style="font-size:11px; color:#94a3b8;">🟣 Extra: Ninguno</div>
                                        <% } %>
                                    </td>
                                    <td>
                                        <%
                                            if (listaEst != null && !listaEst.trim().isEmpty()) {
                                                String[] arrE = listaEst.split(",");
                                                for (String eItem : arrE) {
                                                    String eClean = eItem.trim();
                                                    if (eClean.isEmpty()) continue;
                                                    String infoSeg = segEstMap.get(eClean.toLowerCase());
                                        %>
                                                    <div class="est-mini-pill <%= infoSeg != null ? "con-seg" : "" %>">
                                                        <b>🚏 <%= h(eClean) %></b>
                                                        <% if (infoSeg != null) { %>
                                                            <span>(<%= h(infoSeg) %>)</span>
                                                        <% } else { %>
                                                            <span style="color:#92400e;">(⚠️ Sin molinete)</span>
                                                        <% } %>
                                                    </div>
                                        <%
                                                }
                                            }
                                        %>
                                    </td>
                                    <td>
                                        <% if (nTramos > 0 && kmRuta.compareTo(BigDecimal.ZERO) > 0) { %>
                                            <span style="background:#e0f2fe; color:#0369a1; padding:5px 10px; border-radius:6px; font-size:13px; font-weight:800; display:inline-block;">📏 <%= kmRuta %> km</span>
                                            <div style="font-size:11px; color:#64748b; margin-top:4px;"><%= nTramos %> tramo(s) mapeado(s)</div>
                                        <% } else { %>
                                            <a href="editar_rutas.jsp?accion=editar&id_ruta=<%= idRuta %>" style="background:#fef3c7; color:#92400e; padding:5px 10px; border-radius:6px; font-size:12px; font-weight:bold; text-decoration:none; display:inline-block;">⚠️ Configurar km</a>
                                        <% } %>
                                    </td>
                                    <td style="text-align: center; white-space: nowrap;">
                                        <div style="display:flex; gap:8px; justify-content:center;">
                                            <a href="editar_rutas.jsp?accion=editar&id_ruta=<%= idRuta %>" class="btn-edit">✏️ Editar Todo</a>
                                            <form method="POST" style="margin: 0;" onsubmit="return confirm('¿Seguro que deseas eliminar esta ruta de la logística?');">
                                                <input type="hidden" name="accion" value="eliminar_ruta">
                                                <input type="hidden" name="id_ruta" value="<%= idRuta %>">
                                                <button type="submit" class="btn-del" title="Eliminar Ruta">🗑️</button>
                                            </form>
                                        </div>
                                    </td>
                                </tr>
                    <%
                            }
                            if (!hayRutas) {
                                out.print("<tr><td colspan='6'><div class='empty-state'>No hay rutas logísticas configuradas en este momento.</div></td></tr>");
                            }
                            rs.close();
                            st.close();
                            con.close();
                        } catch (Exception e) {
                            out.print("<tr><td colspan='6'>Error: " + h(e.getMessage()) + "</td></tr>");
                        }
                    %>
                </tbody>
            </table>
            <% } %>
        </div>
    </div>

    <script>
        function toggleMenu(side) {
            let leftMenu = document.getElementById("leftSidebar");
            let rightMenu = document.getElementById("rightSidebar");
            let overlay = document.getElementById("overlay");
            if (side === 'left') { leftMenu.style.width = "250px"; if (rightMenu) rightMenu.style.width = "0"; }
            else if (side === 'right') { if (rightMenu) rightMenu.style.width = "300px"; leftMenu.style.width = "0"; }
            overlay.style.display = "block";
        }
        function closeAllMenus() {
            document.getElementById("leftSidebar").style.width = "0";
            let rightMenu = document.getElementById("rightSidebar");
            if (rightMenu) rightMenu.style.width = "0";
            document.getElementById("overlay").style.display = "none";
        }
    </script>
</body>
</html>