<%@page contentType="text/html" pageEncoding="UTF-8"%>
<%@page import="java.sql.*"%>
<%@page import="java.util.*"%>
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

    static void guardarInfraEstacion(Connection con, String nombreEst, String lat, String lon, String puerta, String guardia, String turno) throws SQLException {
        if (lat.isEmpty()) lat = "14.6349";
        if (lon.isEmpty()) lon = "-90.5069";
        if (turno.isEmpty()) turno = "Diurno";

        int idEstFisica = 0;
        try (PreparedStatement psFisCheck = con.prepareStatement("SELECT id_estacion FROM estaciones_fisicas WHERE LOWER(nombre) = LOWER(?) LIMIT 1")) {
            psFisCheck.setString(1, nombreEst);
            try (ResultSet rsF = psFisCheck.executeQuery()) {
                if (rsF.next()) {
                    idEstFisica = rsF.getInt(1);
                    try (PreparedStatement psFisUpd = con.prepareStatement("UPDATE estaciones_fisicas SET nombre = ?, latitud = ?, longitud = ? WHERE id_estacion = ?")) {
                        psFisUpd.setString(1, nombreEst);
                        psFisUpd.setString(2, lat);
                        psFisUpd.setString(3, lon);
                        psFisUpd.setInt(4, idEstFisica);
                        psFisUpd.executeUpdate();
                    }
                } else {
                    try (PreparedStatement psFisIns = con.prepareStatement(
                            "INSERT INTO estaciones_fisicas (nombre, latitud, longitud) VALUES (?, ?, ?)",
                            Statement.RETURN_GENERATED_KEYS)) {
                        psFisIns.setString(1, nombreEst);
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

        if (idEstFisica > 0 && !puerta.isEmpty()) {
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
                        try (PreparedStatement psAccIns = con.prepareStatement(
                                "INSERT INTO accesos_molinetes (id_estacion, codigo_puerta) VALUES (?, ?)",
                                Statement.RETURN_GENERATED_KEYS)) {
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

            if (idAcceso > 0 && !guardia.isEmpty()) {
                try (PreparedStatement psGCheck = con.prepareStatement("SELECT id_guardia FROM guardias_seguridad WHERE id_acceso = ? LIMIT 1")) {
                    psGCheck.setInt(1, idAcceso);
                    try (ResultSet rsG = psGCheck.executeQuery()) {
                        if (rsG.next()) {
                            int idG = rsG.getInt(1);
                            try (PreparedStatement psGUpd = con.prepareStatement("UPDATE guardias_seguridad SET nombre_completo = ?, turno = ? WHERE id_guardia = ?")) {
                                psGUpd.setString(1, guardia);
                                psGUpd.setString(2, turno);
                                psGUpd.setInt(3, idG);
                                psGUpd.executeUpdate();
                            }
                        } else {
                            try (PreparedStatement psGIns = con.prepareStatement("INSERT INTO guardias_seguridad (nombre_completo, id_acceso, turno) VALUES (?, ?, ?)")) {
                                psGIns.setString(1, guardia);
                                psGIns.setInt(2, idAcceso);
                                psGIns.setString(3, turno);
                                psGIns.executeUpdate();
                            }
                        }
                    }
                }
            }
        }
    }
%>
<%
    // BLOQUEO DE SEGURIDAD EXTREMA: Solo el "admin" entra aquí
    if (session.getAttribute("usuarioValido") == null || !"admin".equals(session.getAttribute("rol"))) {
        response.sendRedirect("index.jsp");
        return;
    }

    String dbUrl = "jdbc:mysql://192.168.15.135:3306/transmetro_db";
    String dbUser = "admin";
    String dbPass = "admin123";
    String mensaje = "";
    String tipoMensaje = "ok";

    request.setCharacterEncoding("UTF-8");
    String accion = request.getParameter("accion");
    if (accion != null) {
        try {
            Class.forName("com.mysql.cj.jdbc.Driver");
            try (Connection con = DriverManager.getConnection(dbUrl, dbUser, dbPass)) {
                con.setAutoCommit(false);
                try {
                    if ("agregar_muni".equals(accion)) {
                        String nomMuni = t(request.getParameter("nombre_muni"));
                        try (PreparedStatement ps = con.prepareStatement("INSERT INTO municipalidades (nombre) VALUES (?)")) {
                            ps.setString(1, nomMuni);
                            ps.executeUpdate();
                        }
                        mensaje = "✅ Municipalidad '" + nomMuni + "' agregada correctamente.";

                    } else if ("editar_muni".equals(accion)) {
                        String muniOriginal = t(request.getParameter("muni_original"));
                        String muniNueva = t(request.getParameter("nombre_muni"));
                        if (!muniOriginal.isEmpty() && !muniNueva.isEmpty()) {
                            try (PreparedStatement ps = con.prepareStatement("UPDATE municipalidades SET nombre = ? WHERE nombre = ?")) {
                                ps.setString(1, muniNueva);
                                ps.setString(2, muniOriginal);
                                ps.executeUpdate();
                            }
                            try (PreparedStatement psFlota = con.prepareStatement("UPDATE flota_vehiculos SET municipalidad = ? WHERE municipalidad = ?")) {
                                psFlota.setString(1, muniNueva);
                                psFlota.setString(2, muniOriginal);
                                psFlota.executeUpdate();
                            }
                            mensaje = "✅ Municipalidad actualizada a '" + muniNueva + "'.";
                        }

                    } else if ("eliminar_muni".equals(accion)) {
                        try (PreparedStatement ps = con.prepareStatement("DELETE FROM municipalidades WHERE nombre = ?")) {
                            ps.setString(1, t(request.getParameter("nombre_muni")));
                            ps.executeUpdate();
                        }
                        mensaje = "🗑️ Municipalidad eliminada.";

                    } else if ("agregar_estacion".equals(accion)) {
                        String nombreEst = t(request.getParameter("nombre_estacion"));
                        String lat = t(request.getParameter("latitud"));
                        String lon = t(request.getParameter("longitud"));
                        String puerta = t(request.getParameter("codigo_puerta"));
                        String guardia = t(request.getParameter("nombre_guardia"));
                        String turno = t(request.getParameter("turno_guardia"));

                        try (PreparedStatement psCheck = con.prepareStatement("SELECT id FROM estaciones_catalogo WHERE LOWER(nombre) = LOWER(?) LIMIT 1")) {
                            psCheck.setString(1, nombreEst);
                            try (ResultSet rsC = psCheck.executeQuery()) {
                                if (!rsC.next()) {
                                    try (PreparedStatement psIns = con.prepareStatement("INSERT INTO estaciones_catalogo (nombre) VALUES (?)")) {
                                        psIns.setString(1, nombreEst);
                                        psIns.executeUpdate();
                                    }
                                }
                            }
                        }

                        guardarInfraEstacion(con, nombreEst, lat, lon, puerta, guardia, turno);
                        mensaje = "✅ Estación '" + nombreEst + "' agregada y configurada correctamente.";

                    } else if ("editar_estacion".equals(accion)) {
                        int idEstacion = Integer.parseInt(t(request.getParameter("id_estacion")));
                        String nombreAnterior = t(request.getParameter("nombre_anterior"));
                        String nombreNuevo = t(request.getParameter("nombre_estacion"));
                        String lat = t(request.getParameter("latitud"));
                        String lon = t(request.getParameter("longitud"));
                        String puerta = t(request.getParameter("codigo_puerta"));
                        String guardia = t(request.getParameter("nombre_guardia"));
                        String turno = t(request.getParameter("turno_guardia"));

                        if (nombreNuevo.isEmpty()) {
                            throw new Exception("El nombre de la estación no puede estar vacío.");
                        }

                        // 1. Actualizar catálogo
                        try (PreparedStatement psUpdCat = con.prepareStatement("UPDATE estaciones_catalogo SET nombre = ? WHERE id = ?")) {
                            psUpdCat.setString(1, nombreNuevo);
                            psUpdCat.setInt(2, idEstacion);
                            psUpdCat.executeUpdate();
                        }

                        // 2. Si cambió el nombre, propagar cambio a estaciones_fisicas, distancias_tramos y rutas_operativas
                        if (!nombreAnterior.isEmpty() && !nombreAnterior.equalsIgnoreCase(nombreNuevo)) {
                            try (PreparedStatement psUpdFis = con.prepareStatement("UPDATE estaciones_fisicas SET nombre = ? WHERE LOWER(nombre) = LOWER(?)")) {
                                psUpdFis.setString(1, nombreNuevo);
                                psUpdFis.setString(2, nombreAnterior);
                                psUpdFis.executeUpdate();
                            }
                            try (PreparedStatement psUpdOrig = con.prepareStatement("UPDATE distancias_tramos SET estacion_origen = ? WHERE LOWER(estacion_origen) = LOWER(?)")) {
                                psUpdOrig.setString(1, nombreNuevo);
                                psUpdOrig.setString(2, nombreAnterior);
                                psUpdOrig.executeUpdate();
                            }
                            try (PreparedStatement psUpdDest = con.prepareStatement("UPDATE distancias_tramos SET estacion_destino = ? WHERE LOWER(estacion_destino) = LOWER(?)")) {
                                psUpdDest.setString(1, nombreNuevo);
                                psUpdDest.setString(2, nombreAnterior);
                                psUpdDest.executeUpdate();
                            }

                            // Actualizar lista_estaciones en rutas_operativas donde aparezca nombreAnterior
                            try (Statement stR = con.createStatement();
                                 ResultSet rsR = stR.executeQuery("SELECT id_ruta, lista_estaciones FROM rutas_operativas")) {
                                try (PreparedStatement psUpdRuta = con.prepareStatement("UPDATE rutas_operativas SET lista_estaciones = ? WHERE id_ruta = ?")) {
                                    while (rsR.next()) {
                                        int idR = rsR.getInt("id_ruta");
                                        String lista = rsR.getString("lista_estaciones");
                                        if (lista != null && !lista.trim().isEmpty()) {
                                            String[] partes = lista.split(",");
                                            boolean modificado = false;
                                            List<String> nuevasPartes = new ArrayList<>();
                                            for (String p : partes) {
                                                String limpia = p.trim();
                                                if (limpia.equalsIgnoreCase(nombreAnterior)) {
                                                    nuevasPartes.add(nombreNuevo);
                                                    modificado = true;
                                                } else if (!limpia.isEmpty()) {
                                                    nuevasPartes.add(limpia);
                                                }
                                            }
                                            if (modificado) {
                                                psUpdRuta.setString(1, String.join(", ", nuevasPartes));
                                                psUpdRuta.setInt(2, idR);
                                                psUpdRuta.executeUpdate();
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // 3. Actualizar coordenadas, molinete y guardia de la estación
                        guardarInfraEstacion(con, nombreNuevo, lat, lon, puerta, guardia, turno);
                        mensaje = "✅ Estación '" + nombreNuevo + "' actualizada en el catálogo, infraestructura y rutas.";

                    } else if ("eliminar_estacion".equals(accion)) {
                        int idEst = Integer.parseInt(t(request.getParameter("id_estacion")));
                        try (PreparedStatement ps = con.prepareStatement("DELETE FROM estaciones_catalogo WHERE id = ?")) {
                            ps.setInt(1, idEst);
                            ps.executeUpdate();
                        }
                        mensaje = "🗑️ Estación eliminada del catálogo.";
                    }

                    con.commit();
                } catch (Exception ex) {
                    con.rollback();
                    throw ex;
                } finally {
                    con.setAutoCommit(true);
                }
            }

            response.sendRedirect("admin_catalogos.jsp?msg=" + java.net.URLEncoder.encode(mensaje, "UTF-8"));
            return;
        } catch (Exception e) {
            mensaje = "❌ Error en la base de datos: " + e.getMessage();
            tipoMensaje = "err";
        }
    }

    if (request.getParameter("msg") != null) {
        mensaje = request.getParameter("msg");
    }
%>

<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <title>Catálogos del Sistema - Admin</title>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&display=swap" rel="stylesheet">
    <style>
        body { font-family: 'Inter', 'Segoe UI', sans-serif; background-color: #f0f2f5; margin: 0; padding-top: 70px; }
        .header { background: #ffffff; color: #1e293b; padding: 15px 25px; position: fixed; top: 0; width: 100%; box-sizing: border-box; z-index: 1000; display: flex; justify-content: space-between; align-items: center; border-bottom: 1px solid #e2e8f0; box-shadow: 0 1px 3px rgba(0,0,0,0.04); }
        .header h1 { margin: 0; font-size: 18px; text-align: center; flex-grow: 1; font-weight: 700; letter-spacing: 0.5px; }
        .menu-btn { background: none; border: none; color: #475569; font-size: 24px; cursor: pointer; transition: 0.2s; border-radius: 5px; padding: 5px 10px; }
        .overlay { display: none; position: fixed; width: 100%; height: 100%; top: 0; left: 0; background: rgba(15, 23, 42, 0.4); backdrop-filter: blur(2px); z-index: 999; }

        .main-container { max-width: 1160px; margin: 30px auto; padding: 0 20px 50px 20px; }
        .page-title { display: flex; justify-content: space-between; align-items: flex-end; flex-wrap: wrap; gap: 12px; margin-bottom: 20px; }
        .page-title h2 { margin: 0 0 5px 0; font-size: 26px; font-weight: 800; color: #0f172a; }
        .page-title p { margin: 0; color: #64748b; font-size: 15px; }

        .mensaje-alerta { background: #dcfce7; color: #166534; padding: 15px; border-radius: 8px; margin-bottom: 20px; font-weight: 600; border: 1px solid #bbf7d0; }
        .mensaje-alerta.err { background: #fef2f2; color: #991b1b; border-color: #fecaca; }

        .grid-catalogos { display: flex; flex-direction: column; gap: 28px; }

        .admin-card { background: #ffffff; border-radius: 12px; box-shadow: 0 4px 6px -1px rgba(0,0,0,0.05); border: 1px solid #e2e8f0; overflow: hidden; padding: 25px; }
        .admin-card-title { font-size: 18px; color: #0f172a; font-weight: 700; margin-top: 0; margin-bottom: 18px; border-bottom: 1px solid #f1f5f9; padding-bottom: 14px; display: flex; align-items: center; gap: 10px; flex-wrap: wrap; }

        .form-box { background: #f8fafc; border: 1px solid #e2e8f0; border-radius: 10px; padding: 18px; margin-bottom: 22px; transition: 0.2s; }
        .form-box.modo-edicion { background: #eff6ff; border-color: #93c5fd; box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.12); }
        .form-box-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 12px; font-size: 14px; font-weight: 800; color: #1e293b; }
        .form-box.modo-edicion .form-box-header { color: #1e40af; }

        .est-form-grid { display: grid; grid-template-columns: 1.5fr 0.8fr 0.8fr 0.9fr 1.3fr 0.9fr auto; gap: 10px; align-items: end; }
        @media (max-width: 1020px) { .est-form-grid { grid-template-columns: 1fr 1fr; } }
        .field label { display: block; font-size: 11px; font-weight: 700; color: #475569; margin-bottom: 4px; text-transform: uppercase; }
        .field input, .field select { width: 100%; padding: 9px 11px; border: 1px solid #cbd5e1; border-radius: 6px; font-size: 13px; box-sizing: border-box; background: #fff; }

        .form-group-inline { display: flex; gap: 10px; align-items: center; }
        .form-group-inline input { flex-grow: 1; padding: 10px 12px; border: 1px solid #cbd5e1; border-radius: 6px; font-size: 14px; }

        .btn-primary { background: #0284c7; color: white; border: none; padding: 10px 18px; border-radius: 6px; font-weight: 700; cursor: pointer; transition: 0.2s; height: 37px; white-space: nowrap; }
        .btn-primary:hover { background: #0369a1; }
        .btn-cancel { background: #e2e8f0; color: #1e293b; border: none; padding: 6px 12px; border-radius: 6px; font-size: 12px; font-weight: 700; cursor: pointer; }

        table { width: 100%; border-collapse: collapse; text-align: left; }
        th { background-color: #f8fafc; padding: 11px 14px; font-size: 12px; color: #64748b; font-weight: 700; text-transform: uppercase; border-bottom: 2px solid #e2e8f0; }
        td { padding: 12px 14px; font-size: 14px; color: #334155; border-bottom: 1px solid #f1f5f9; vertical-align: middle; }
        tr:hover td { background-color: #f8fafc; }

        .btn-edit { background: #eff6ff; color: #2563eb; border: 1px solid #bfdbfe; padding: 5px 10px; border-radius: 6px; font-weight: 700; font-size: 12px; cursor: pointer; transition: 0.15s; }
        .btn-edit:hover { background: #2563eb; color: #fff; }
        .btn-delete { background: #fee2e2; color: #dc2626; border: 1px solid #fecaca; padding: 5px 10px; border-radius: 6px; font-weight: 700; font-size: 12px; cursor: pointer; transition: 0.15s; }
        .btn-delete:hover { background: #dc2626; color: #fff; }

        .tag { display: inline-block; padding: 4px 8px; border-radius: 6px; font-size: 12px; font-weight: 700; text-decoration: none; }
        .tag-ok { background: #dcfce7; color: #166534; }
        .tag-warn { background: #fef3c7; color: #92400e; }
        .tag-km { background: #e0f2fe; color: #0369a1; }
    </style>
    <link rel="stylesheet" href="css/transmetro.css">
</head>
<body>

    <jsp:include page="menu_izquierdo.jsp" />
    <jsp:include page="menu_derecho.jsp" />
    <div id="overlay" class="overlay" onclick="closeAllMenus()"></div>

    <div class="header">
        <button class="menu-btn" onclick="toggleMenu('left')">☰</button>
        <h1>Ajustes y Catálogos</h1>
        <button class="menu-btn" onclick="toggleMenu('right')">⚙️</button>
    </div>

    <div class="main-container">
        <div class="page-title">
            <div>
                <h2>⚙️ Mantenimiento de Catálogos y Estaciones</h2>
                <p>Gestione y edite las estaciones del sistema (nombre, coordenadas, molinete y guardia) y las municipalidades autorizadas.</p>
            </div>
            <div style="display:flex; gap:10px;">
                <a href="estaciones.jsp" style="background:#e0f2fe; color:#0369a1; padding:9px 14px; border-radius:8px; font-size:13px; font-weight:700; text-decoration:none;">🚏 Ver Directorio de Estaciones</a>
                <a href="admin_infra.jsp" style="background:#e2e8f0; color:#1e293b; padding:9px 14px; border-radius:8px; font-size:13px; font-weight:700; text-decoration:none;">🏗️ Panel Infraestructura</a>
            </div>
        </div>

        <% if (mensaje != null && !mensaje.isEmpty()) { %>
            <div class="mensaje-alerta <%= "err".equals(tipoMensaje) ? "err" : "" %>"><%= h(mensaje) %></div>
        <% } %>

        <div class="grid-catalogos">

            <!-- TARJETA 1: ESTACIONES (CON EDICIÓN COMPLETA) -->
            <div class="admin-card">
                <h3 class="admin-card-title">
                    <span>🚏 Catálogo de Estaciones (Crear y Editar)</span>
                    <span style="margin-left:auto; font-size:12px; color:#64748b; font-weight:600;">Al renombrar una estación se actualiza automáticamente en sus rutas y tramos</span>
                </h3>

                <div class="form-box" id="cajaFormEstacion">
                    <div class="form-box-header">
                        <span id="tituloFormEstacion">➕ Agregar Nueva Estación al Catálogo</span>
                        <button type="button" class="btn-cancel" id="btnCancelarEst" onclick="cancelarEdicionEstacion()" style="display:none;">✕ Cancelar Edición</button>
                    </div>
                    <form method="POST" action="admin_catalogos.jsp">
                        <input type="hidden" name="accion" id="estAccion" value="agregar_estacion">
                        <input type="hidden" name="id_estacion" id="estId" value="">
                        <input type="hidden" name="nombre_anterior" id="estNombreAnt" value="">

                        <div class="est-form-grid">
                            <div class="field">
                                <label>🚏 Nombre de la Estación</label>
                                <input type="text" name="nombre_estacion" id="estNombre" placeholder="Ej. El Carmen" required>
                            </div>
                            <div class="field">
                                <label>📍 Latitud</label>
                                <input type="text" name="latitud" id="estLat" value="14.6349" placeholder="14.6349">
                            </div>
                            <div class="field">
                                <label>📍 Longitud</label>
                                <input type="text" name="longitud" id="estLon" value="-90.5069" placeholder="-90.5069">
                            </div>
                            <div class="field">
                                <label>🚪 Molinete / Puerta</label>
                                <input type="text" name="codigo_puerta" id="estPuerta" placeholder="Ej. M-01">
                            </div>
                            <div class="field">
                                <label>👮 Guardia Asignado (RN05)</label>
                                <input type="text" name="nombre_guardia" id="estGuardia" placeholder="Nombre del guardia">
                            </div>
                            <div class="field">
                                <label>🕒 Turno</label>
                                <select name="turno_guardia" id="estTurno">
                                    <option value="Diurno">☀️ Diurno</option>
                                    <option value="Nocturno">🌙 Nocturno</option>
                                    <option value="Mixto">🔄 Mixto</option>
                                </select>
                            </div>
                            <div class="field">
                                <button type="submit" class="btn-primary" id="btnSubmitEstacion">➕ Agregar</button>
                            </div>
                        </div>
                    </form>
                </div>

                <div style="max-height: 520px; overflow-y: auto;">
                    <table>
                        <thead>
                            <tr>
                                <th>Nombre de la Parada</th>
                                <th>Coordenadas GPS</th>
                                <th>Molinete y Guardia (RN05)</th>
                                <th>Km Conectados</th>
                                <th>Rutas</th>
                                <th style="text-align:center;">Acciones</th>
                            </tr>
                        </thead>
                        <tbody>
                            <%
                                try (Connection con = DriverManager.getConnection(dbUrl, dbUser, dbPass);
                                     Statement st = con.createStatement()) {

                                    // Asegurar que todas las estaciones físicas también estén presentes en estaciones_catalogo para poder editarlas aquí
                                    st.executeUpdate(
                                        "INSERT INTO estaciones_catalogo (nombre) " +
                                        "SELECT e.nombre FROM estaciones_fisicas e " +
                                        "WHERE NOT EXISTS (SELECT 1 FROM estaciones_catalogo c WHERE LOWER(c.nombre) = LOWER(e.nombre))");

                                    try (ResultSet rs = st.executeQuery(
                                            "SELECT c.id, c.nombre, " +
                                            "(SELECT e.latitud FROM estaciones_fisicas e WHERE LOWER(e.nombre) = LOWER(c.nombre) LIMIT 1) AS latitud, " +
                                            "(SELECT e.longitud FROM estaciones_fisicas e WHERE LOWER(e.nombre) = LOWER(c.nombre) LIMIT 1) AS longitud, " +
                                            "(SELECT a.codigo_puerta FROM estaciones_fisicas e JOIN accesos_molinetes a ON a.id_estacion = e.id_estacion WHERE LOWER(e.nombre) = LOWER(c.nombre) ORDER BY a.id_acceso ASC LIMIT 1) AS puerta, " +
                                            "(SELECT g.nombre_completo FROM estaciones_fisicas e JOIN accesos_molinetes a ON a.id_estacion = e.id_estacion JOIN guardias_seguridad g ON g.id_acceso = a.id_acceso WHERE LOWER(e.nombre) = LOWER(c.nombre) ORDER BY a.id_acceso ASC LIMIT 1) AS guardia, " +
                                            "(SELECT g.turno FROM estaciones_fisicas e JOIN accesos_molinetes a ON a.id_estacion = e.id_estacion JOIN guardias_seguridad g ON g.id_acceso = a.id_acceso WHERE LOWER(e.nombre) = LOWER(c.nombre) ORDER BY a.id_acceso ASC LIMIT 1) AS turno, " +
                                            "(SELECT COALESCE(SUM(d.distancia_km), 0) FROM distancias_tramos d WHERE LOWER(d.estacion_origen) = LOWER(c.nombre) OR LOWER(d.estacion_destino) = LOWER(c.nombre)) AS km, " +
                                            "(SELECT COUNT(*) FROM rutas_operativas r WHERE FIND_IN_SET(LOWER(c.nombre), LOWER(REPLACE(REPLACE(r.lista_estaciones, ', ', ','), ' ,', ','))) > 0) AS rutas " +
                                            "FROM estaciones_catalogo c ORDER BY c.nombre ASC")) {

                                        while (rs.next()) {
                                            int idEstacion = rs.getInt("id");
                                            String nombreEstacion = t(rs.getString("nombre"));
                                            String lat = rs.getString("latitud") != null ? rs.getString("latitud") : "";
                                            String lon = rs.getString("longitud") != null ? rs.getString("longitud") : "";
                                            String puerta = rs.getString("puerta") != null ? rs.getString("puerta") : "";
                                            String guardia = rs.getString("guardia") != null ? rs.getString("guardia") : "";
                                            String turno = rs.getString("turno") != null ? rs.getString("turno") : "Diurno";
                                            int nRutas = rs.getInt("rutas");
                                            java.math.BigDecimal kmCon = rs.getBigDecimal("km");
                                            String avisoBorrar = (nRutas > 0 ? "Esta estación aparece en " + nRutas + " ruta(s). " : "") + "¿Seguro que desea eliminar " + nombreEstacion + "?";
                            %>
                                            <tr>
                                                <td style="font-weight: 700; color:#0f172a;">🚏 <%= h(nombreEstacion) %></td>
                                                <td style="font-size:12px; color:#64748b;">
                                                    <%= (!lat.isEmpty() && !lon.isEmpty()) ? ("📍 " + h(lat) + ", " + h(lon)) : "<span style='color:#94a3b8;'>Sin coordenadas</span>" %>
                                                </td>
                                                <td>
                                                    <% if (puerta.isEmpty()) { %>
                                                        <span class="tag tag-warn">⚠️ Sin molinete configurado</span>
                                                    <% } else if (guardia.isEmpty()) { %>
                                                        <span class="tag tag-warn">🚪 <%= h(puerta) %> · ⚠️ Sin guardia</span>
                                                    <% } else { %>
                                                        <span class="tag tag-ok">🚪 <%= h(puerta) %> · 👮 <%= h(guardia) %> (<%= h(turno) %>)</span>
                                                    <% } %>
                                                </td>
                                                <td><%= (kmCon == null || kmCon.signum() == 0) ? "<span style='color:#94a3b8;'>—</span>" : "<span class='tag tag-km'>📏 " + kmCon + " km</span>" %></td>
                                                <td><%= nRutas == 0 ? "<span style='color:#94a3b8;'>Sin rutas</span>" : "<span style='font-weight:700; color:#0369a1;'>🗺️ " + nRutas + " ruta(s)</span>" %></td>
                                                <td style="text-align:center;">
                                                    <div style="display:flex; gap:6px; justify-content:center; align-items:center;">
                                                        <button type="button" class="btn-edit"
                                                            onclick="cargarEdicionEstacion('<%= idEstacion %>', '<%= js(nombreEstacion) %>', '<%= js(lat.isEmpty() ? "14.6349" : lat) %>', '<%= js(lon.isEmpty() ? "-90.5069" : lon) %>', '<%= js(puerta) %>', '<%= js(guardia) %>', '<%= js(turno) %>')">
                                                            ✏️ Editar
                                                        </button>
                                                        <form method="POST" action="admin_catalogos.jsp" style="margin:0;" onsubmit="return confirm('<%= js(avisoBorrar) %>');">
                                                            <input type="hidden" name="accion" value="eliminar_estacion">
                                                            <input type="hidden" name="id_estacion" value="<%= idEstacion %>">
                                                            <button type="submit" class="btn-delete" title="Eliminar">🗑️</button>
                                                        </form>
                                                    </div>
                                                </td>
                                            </tr>
                            <%
                                        }
                                    }
                                } catch (Exception e) {
                                    out.print("<tr><td colspan='6'>Error: " + h(e.getMessage()) + "</td></tr>");
                                }
                            %>
                        </tbody>
                    </table>
                </div>
            </div>

            <!-- TARJETA 2: MUNICIPALIDADES (CON EDICIÓN) -->
            <div class="admin-card">
                <h3 class="admin-card-title">🏛️ Base de Municipalidades</h3>

                <div class="form-box" id="cajaFormMuni">
                    <div class="form-box-header">
                        <span id="tituloFormMuni">➕ Agregar Nueva Municipalidad</span>
                        <button type="button" class="btn-cancel" id="btnCancelarMuni" onclick="cancelarEdicionMuni()" style="display:none;">✕ Cancelar Edición</button>
                    </div>
                    <form method="POST" action="admin_catalogos.jsp" class="form-group-inline">
                        <input type="hidden" name="accion" id="muniAccion" value="agregar_muni">
                        <input type="hidden" name="muni_original" id="muniOriginal" value="">
                        <input type="text" name="nombre_muni" id="muniNombre" placeholder="Nombre de Municipalidad (Ej. Mixco)" required>
                        <button type="submit" class="btn-primary" id="btnSubmitMuni" style="background:#1a2a6c;">➕ Agregar</button>
                    </form>
                </div>

                <div style="max-height: 380px; overflow-y: auto;">
                    <table>
                        <thead>
                            <tr>
                                <th>Nombre Registrado</th>
                                <th style="text-align:center;">Acciones</th>
                            </tr>
                        </thead>
                        <tbody>
                            <%
                                try (Connection con = DriverManager.getConnection(dbUrl, dbUser, dbPass);
                                     Statement st = con.createStatement();
                                     ResultSet rs = st.executeQuery("SELECT nombre FROM municipalidades ORDER BY nombre ASC")) {
                                    while (rs.next()) {
                                        String nombre = rs.getString("nombre");
                            %>
                                        <tr>
                                            <td style="font-weight: 600;">🏛️ <%= h(nombre) %></td>
                                            <td style="text-align:center;">
                                                <div style="display:flex; gap:6px; justify-content:center;">
                                                    <button type="button" class="btn-edit" onclick="cargarEdicionMuni('<%= js(nombre) %>')">✏️ Editar</button>
                                                    <form method="POST" action="admin_catalogos.jsp" style="margin:0;" onsubmit="return confirm('¿Seguro que desea eliminar esta municipalidad?');">
                                                        <input type="hidden" name="accion" value="eliminar_muni">
                                                        <input type="hidden" name="nombre_muni" value="<%= h(nombre) %>">
                                                        <button type="submit" class="btn-delete" title="Eliminar">🗑️</button>
                                                    </form>
                                                </div>
                                            </td>
                                        </tr>
                            <%
                                    }
                                } catch (Exception e) {}
                            %>
                        </tbody>
                    </table>
                </div>
            </div>

        </div>
    </div>

    <script>
        function cargarEdicionEstacion(id, nombre, lat, lon, puerta, guardia, turno) {
            document.getElementById("cajaFormEstacion").classList.add("modo-edicion");
            document.getElementById("tituloFormEstacion").textContent = "✏️ Editando Estación: " + nombre;
            document.getElementById("btnCancelarEst").style.display = "inline-block";
            document.getElementById("estAccion").value = "editar_estacion";
            document.getElementById("estId").value = id;
            document.getElementById("estNombreAnt").value = nombre;
            document.getElementById("estNombre").value = nombre;
            document.getElementById("estLat").value = lat || "14.6349";
            document.getElementById("estLon").value = lon || "-90.5069";
            document.getElementById("estPuerta").value = puerta || "";
            document.getElementById("estGuardia").value = guardia || "";
            document.getElementById("estTurno").value = turno || "Diurno";
            document.getElementById("btnSubmitEstacion").textContent = "💾 Guardar Cambios";
            document.getElementById("cajaFormEstacion").scrollIntoView({ behavior: "smooth", block: "center" });
        }

        function cancelarEdicionEstacion() {
            document.getElementById("cajaFormEstacion").classList.remove("modo-edicion");
            document.getElementById("tituloFormEstacion").textContent = "➕ Agregar Nueva Estación al Catálogo";
            document.getElementById("btnCancelarEst").style.display = "none";
            document.getElementById("estAccion").value = "agregar_estacion";
            document.getElementById("estId").value = "";
            document.getElementById("estNombreAnt").value = "";
            document.getElementById("estNombre").value = "";
            document.getElementById("estLat").value = "14.6349";
            document.getElementById("estLon").value = "-90.5069";
            document.getElementById("estPuerta").value = "";
            document.getElementById("estGuardia").value = "";
            document.getElementById("estTurno").value = "Diurno";
            document.getElementById("btnSubmitEstacion").textContent = "➕ Agregar";
        }

        function cargarEdicionMuni(nombre) {
            document.getElementById("cajaFormMuni").classList.add("modo-edicion");
            document.getElementById("tituloFormMuni").textContent = "✏️ Editando Municipalidad: " + nombre;
            document.getElementById("btnCancelarMuni").style.display = "inline-block";
            document.getElementById("muniAccion").value = "editar_muni";
            document.getElementById("muniOriginal").value = nombre;
            document.getElementById("muniNombre").value = nombre;
            document.getElementById("btnSubmitMuni").textContent = "💾 Guardar Cambios";
            document.getElementById("cajaFormMuni").scrollIntoView({ behavior: "smooth", block: "center" });
        }

        function cancelarEdicionMuni() {
            document.getElementById("cajaFormMuni").classList.remove("modo-edicion");
            document.getElementById("tituloFormMuni").textContent = "➕ Agregar Nueva Municipalidad";
            document.getElementById("btnCancelarMuni").style.display = "none";
            document.getElementById("muniAccion").value = "agregar_muni";
            document.getElementById("muniOriginal").value = "";
            document.getElementById("muniNombre").value = "";
            document.getElementById("btnSubmitMuni").textContent = "➕ Agregar";
        }

        function toggleMenu(side) {
            let leftMenu = document.getElementById("leftSidebar");
            let rightMenu = document.getElementById("rightSidebar");
            let overlay = document.getElementById("overlay");
            if (side === 'left') { leftMenu.style.width = "250px"; if(rightMenu) rightMenu.style.width = "0"; }
            else if (side === 'right') { if(rightMenu) rightMenu.style.width = "300px"; leftMenu.style.width = "0"; }
            overlay.style.display = "block";
        }
        function closeAllMenus() {
            document.getElementById("leftSidebar").style.width = "0";
            let rightMenu = document.getElementById("rightSidebar"); if(rightMenu) rightMenu.style.width = "0";
            document.getElementById("overlay").style.display = "none";
        }
    </script>
</body>
</html>