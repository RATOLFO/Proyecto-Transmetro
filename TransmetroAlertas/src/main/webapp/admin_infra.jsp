<%@page contentType="text/html" pageEncoding="UTF-8"%>
<%@page import="java.sql.*"%>
<%@page import="java.math.BigDecimal"%>
<%!
    // Escapa texto antes de imprimirlo en HTML
    static String h(String s) {
        if (s == null) return "";
        return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace("\"", "&quot;").replace("'", "&#39;");
    }
    static String t(String v) { return v == null ? "" : v.trim(); }
    // Cuenta filas con un solo parámetro entero
    static int contar(Connection c, String sql, int p) throws SQLException {
        try (PreparedStatement ps = c.prepareStatement(sql)) {
            ps.setInt(1, p);
            try (ResultSet r = ps.executeQuery()) { return r.next() ? r.getInt(1) : 0; }
        }
    }
%>
<%
    // Seguridad extrema: Solo administradores pueden entrar aquí
    if (session.getAttribute("usuarioValido") == null || !"admin".equals(session.getAttribute("rol"))) {
        response.sendRedirect("index.jsp"); return;
    }

    String dbUrl = "jdbc:mysql://192.168.15.135:3306/transmetro_db"; 
    String dbUser = "admin"; String dbPass = "admin123";
    String mensaje = "";
    String tipoAlerta = "success";

    Connection con = null;
    try {
        Class.forName("com.mysql.cj.jdbc.Driver");
        con = DriverManager.getConnection(dbUrl, dbUser, dbPass);
    } catch (Exception e) { mensaje = "❌ No se pudo conectar a la base de datos: " + e.getMessage(); tipoAlerta = "error"; }

    // ======================= LÓGICA DE ESCRITURA (POST) =======================
    if ("POST".equalsIgnoreCase(request.getMethod()) && con != null) {
        request.setCharacterEncoding("UTF-8");
        String accion = t(request.getParameter("accion"));
        try {
            // ---------- PARQUEOS (RN04) ----------
            if ("add_parqueo".equals(accion)) {
                int cap = Integer.parseInt(t(request.getParameter("capacidad")));
                if (cap <= 0) throw new Exception("La capacidad debe ser mayor a cero.");
                try (PreparedStatement ps = con.prepareStatement("INSERT INTO parqueos (nombre, capacidad_buses) VALUES (?, ?)")) {
                    ps.setString(1, t(request.getParameter("nombre_parqueo"))); ps.setInt(2, cap); ps.executeUpdate();
                }
                mensaje = "✅ Parqueo registrado correctamente.";

            } else if ("edit_parqueo".equals(accion)) {
                int id = Integer.parseInt(request.getParameter("id"));
                int cap = Integer.parseInt(t(request.getParameter("capacidad")));
                int ocupados = contar(con, "SELECT COUNT(*) FROM flota_vehiculos WHERE id_parqueo = ?", id);
                if (cap <= 0) throw new Exception("La capacidad debe ser mayor a cero.");
                if (cap < ocupados) throw new Exception("No se puede reducir la capacidad a " + cap + ": el parqueo ya tiene " + ocupados + " buses asignados.");
                try (PreparedStatement ps = con.prepareStatement("UPDATE parqueos SET nombre = ?, capacidad_buses = ? WHERE id_parqueo = ?")) {
                    ps.setString(1, t(request.getParameter("nombre_parqueo"))); ps.setInt(2, cap); ps.setInt(3, id); ps.executeUpdate();
                }
                mensaje = "✅ Parqueo actualizado.";

            } else if ("del_parqueo".equals(accion)) {
                int id = Integer.parseInt(request.getParameter("id"));
                int ocupados = contar(con, "SELECT COUNT(*) FROM flota_vehiculos WHERE id_parqueo = ?", id);
                if (ocupados > 0) throw new Exception("No se puede eliminar: hay " + ocupados + " buses asignados a este parqueo (RN04). Reasígnalos primero.");
                try (PreparedStatement ps = con.prepareStatement("DELETE FROM parqueos WHERE id_parqueo = ?")) { ps.setInt(1, id); ps.executeUpdate(); }
                mensaje = "🗑️ Parqueo eliminado.";

            // ---------- ESTACIONES FÍSICAS ----------
            } else if ("add_estacion".equals(accion) || "edit_estacion".equals(accion)) {
                String lat = t(request.getParameter("latitud")); String lon = t(request.getParameter("longitud"));
                if ("add_estacion".equals(accion)) {
                    try (PreparedStatement ps = con.prepareStatement("INSERT INTO estaciones_fisicas (nombre, latitud, longitud) VALUES (?, ?, ?)")) {
                        ps.setString(1, t(request.getParameter("nombre_estacion")));
                        ps.setString(2, lat.isEmpty() ? null : lat); ps.setString(3, lon.isEmpty() ? null : lon); ps.executeUpdate();
                    }
                    mensaje = "✅ Estación física registrada.";
                } else {
                    try (PreparedStatement ps = con.prepareStatement("UPDATE estaciones_fisicas SET nombre = ?, latitud = ?, longitud = ? WHERE id_estacion = ?")) {
                        ps.setString(1, t(request.getParameter("nombre_estacion")));
                        ps.setString(2, lat.isEmpty() ? null : lat); ps.setString(3, lon.isEmpty() ? null : lon);
                        ps.setInt(4, Integer.parseInt(request.getParameter("id"))); ps.executeUpdate();
                    }
                    mensaje = "✅ Estación física actualizada.";
                }

            } else if ("del_estacion".equals(accion)) {
                int id = Integer.parseInt(request.getParameter("id"));
                int molinetes = contar(con, "SELECT COUNT(*) FROM accesos_molinetes WHERE id_estacion = ?", id);
                if (molinetes > 0) throw new Exception("No se puede eliminar: la estación tiene " + molinetes + " molinete(s) con guardia. Elimina primero esas asignaciones.");
                try (PreparedStatement ps = con.prepareStatement("DELETE FROM estaciones_fisicas WHERE id_estacion = ?")) { ps.setInt(1, id); ps.executeUpdate(); }
                mensaje = "🗑️ Estación física eliminada.";

            // ---------- DISTANCIAS (RF02) ----------
            } else if ("add_distancia".equals(accion) || "edit_distancia".equals(accion)) {
                BigDecimal km = new BigDecimal(t(request.getParameter("km")));
                if (km.compareTo(BigDecimal.ZERO) <= 0 || km.compareTo(new BigDecimal("999.99")) > 0) throw new Exception("La distancia debe estar entre 0.01 y 999.99 km.");
                String origen = t(request.getParameter("origen")); String destino = t(request.getParameter("destino"));
                if (origen.equalsIgnoreCase(destino)) throw new Exception("El origen y el destino no pueden ser la misma estación.");
                int idRuta = Integer.parseInt(request.getParameter("id_ruta"));
                if ("add_distancia".equals(accion)) {
                    try (PreparedStatement ps = con.prepareStatement("INSERT INTO distancias_tramos (id_ruta, estacion_origen, estacion_destino, distancia_km) VALUES (?, ?, ?, ?)")) {
                        ps.setInt(1, idRuta); ps.setString(2, origen); ps.setString(3, destino); ps.setBigDecimal(4, km); ps.executeUpdate();
                    }
                    mensaje = "✅ Tramo y distancia guardados correctamente.";
                } else {
                    try (PreparedStatement ps = con.prepareStatement("UPDATE distancias_tramos SET id_ruta = ?, estacion_origen = ?, estacion_destino = ?, distancia_km = ? WHERE id_tramo = ?")) {
                        ps.setInt(1, idRuta); ps.setString(2, origen); ps.setString(3, destino); ps.setBigDecimal(4, km);
                        ps.setInt(5, Integer.parseInt(request.getParameter("id"))); ps.executeUpdate();
                    }
                    mensaje = "✅ Tramo actualizado.";
                }

            } else if ("del_distancia".equals(accion)) {
                try (PreparedStatement ps = con.prepareStatement("DELETE FROM distancias_tramos WHERE id_tramo = ?")) {
                    ps.setInt(1, Integer.parseInt(request.getParameter("id"))); ps.executeUpdate();
                }
                mensaje = "🗑️ Tramo eliminado.";

            // ---------- GUARDIAS Y MOLINETES (RF03 / RN05) ----------
            } else if ("add_guardia".equals(accion)) {
                // Inserta acceso y guardia en una transacción para cumplir la regla RN05
                con.setAutoCommit(false);
                try {
                    int idAcceso = -1;
                    try (PreparedStatement ps1 = con.prepareStatement("INSERT INTO accesos_molinetes (id_estacion, codigo_puerta) VALUES (?, ?)", Statement.RETURN_GENERATED_KEYS)) {
                        ps1.setInt(1, Integer.parseInt(request.getParameter("id_estacion")));
                        ps1.setString(2, t(request.getParameter("puerta")));
                        ps1.executeUpdate();
                        try (ResultSet k = ps1.getGeneratedKeys()) { if (k.next()) idAcceso = k.getInt(1); }
                    }
                    if (idAcceso < 0) throw new Exception("No se pudo crear el molinete.");
                    try (PreparedStatement ps2 = con.prepareStatement("INSERT INTO guardias_seguridad (nombre_completo, id_acceso, turno) VALUES (?, ?, ?)")) {
                        ps2.setString(1, t(request.getParameter("nombre_guardia"))); ps2.setInt(2, idAcceso); ps2.setString(3, t(request.getParameter("turno")));
                        ps2.executeUpdate();
                    }
                    con.commit();
                } catch (Exception ex) { con.rollback(); throw ex; } finally { con.setAutoCommit(true); }
                mensaje = "✅ Guardia y molinete registrados (cumpliendo RN05).";

            } else if ("edit_guardia".equals(accion)) {
                int idGuardia = Integer.parseInt(request.getParameter("id"));
                con.setAutoCommit(false);
                try {
                    int idAcceso = -1;
                    try (PreparedStatement ps0 = con.prepareStatement("SELECT id_acceso FROM guardias_seguridad WHERE id_guardia = ?")) {
                        ps0.setInt(1, idGuardia);
                        try (ResultSet r = ps0.executeQuery()) { if (r.next()) idAcceso = r.getInt(1); }
                    }
                    if (idAcceso < 0) throw new Exception("El guardia ya no existe.");
                    try (PreparedStatement ps1 = con.prepareStatement("UPDATE accesos_molinetes SET id_estacion = ?, codigo_puerta = ? WHERE id_acceso = ?")) {
                        ps1.setInt(1, Integer.parseInt(request.getParameter("id_estacion"))); ps1.setString(2, t(request.getParameter("puerta"))); ps1.setInt(3, idAcceso); ps1.executeUpdate();
                    }
                    try (PreparedStatement ps2 = con.prepareStatement("UPDATE guardias_seguridad SET nombre_completo = ?, turno = ? WHERE id_guardia = ?")) {
                        ps2.setString(1, t(request.getParameter("nombre_guardia"))); ps2.setString(2, t(request.getParameter("turno"))); ps2.setInt(3, idGuardia); ps2.executeUpdate();
                    }
                    con.commit();
                } catch (Exception ex) { con.rollback(); throw ex; } finally { con.setAutoCommit(true); }
                mensaje = "✅ Asignación de guardia actualizada.";

            } else if ("del_guardia".equals(accion)) {
                // Un molinete sin guardia rompe RN05, así que se elimina el guardia junto con su molinete
                int idGuardia = Integer.parseInt(request.getParameter("id"));
                con.setAutoCommit(false);
                try {
                    int idAcceso = -1;
                    try (PreparedStatement ps0 = con.prepareStatement("SELECT id_acceso FROM guardias_seguridad WHERE id_guardia = ?")) {
                        ps0.setInt(1, idGuardia);
                        try (ResultSet r = ps0.executeQuery()) { if (r.next()) idAcceso = r.getInt(1); }
                    }
                    try (PreparedStatement ps1 = con.prepareStatement("DELETE FROM guardias_seguridad WHERE id_guardia = ?")) { ps1.setInt(1, idGuardia); ps1.executeUpdate(); }
                    if (idAcceso >= 0) {
                        try (PreparedStatement ps2 = con.prepareStatement("DELETE FROM accesos_molinetes WHERE id_acceso = ?")) { ps2.setInt(1, idAcceso); ps2.executeUpdate(); }
                    }
                    con.commit();
                } catch (Exception ex) { con.rollback(); throw ex; } finally { con.setAutoCommit(true); }
                mensaje = "🗑️ Guardia y molinete eliminados.";
            }
        } catch (NumberFormatException e) {
            mensaje = "❌ Dato numérico inválido. Revisa los campos del formulario."; tipoAlerta = "error";
        } catch (Exception e) {
            mensaje = "❌ " + e.getMessage(); tipoAlerta = "error";
        }
        // Patrón Post/Redirect/Get: evita que al recargar (F5) se repita la operación
        session.setAttribute("infraMsg", mensaje);
        session.setAttribute("infraTipo", tipoAlerta);
        try { con.close(); } catch (Exception e) {}
        response.sendRedirect("admin_infra.jsp");
        return;
    }

    // Mensaje pendiente de la operación anterior
    if (session.getAttribute("infraMsg") != null) {
        mensaje = (String) session.getAttribute("infraMsg");
        tipoAlerta = (String) session.getAttribute("infraTipo");
        session.removeAttribute("infraMsg"); session.removeAttribute("infraTipo");
    }

    // ======================= MODO EDICIÓN (precarga del formulario) =======================
    String editar = t(request.getParameter("editar"));
    int editId = 0;
    try { editId = Integer.parseInt(t(request.getParameter("id"))); } catch (Exception e) { editar = ""; }

    String eNombre = "", eCap = "", eLat = "", eLon = "", eOrigen = "", eDestino = "", eKm = "", ePuerta = "", eGuardia = "", eTurno = "Diurno";
    int eRuta = 0, eEstacion = 0;
    if (con != null && !editar.isEmpty()) {
        try {
            if ("parqueo".equals(editar)) {
                try (PreparedStatement ps = con.prepareStatement("SELECT nombre, capacidad_buses FROM parqueos WHERE id_parqueo = ?")) {
                    ps.setInt(1, editId); try (ResultSet r = ps.executeQuery()) { if (r.next()) { eNombre = r.getString(1); eCap = String.valueOf(r.getInt(2)); } else editar = ""; }
                }
            } else if ("estacion".equals(editar)) {
                try (PreparedStatement ps = con.prepareStatement("SELECT nombre, latitud, longitud FROM estaciones_fisicas WHERE id_estacion = ?")) {
                    ps.setInt(1, editId); try (ResultSet r = ps.executeQuery()) { if (r.next()) { eNombre = r.getString(1); eLat = t(r.getString(2)); eLon = t(r.getString(3)); } else editar = ""; }
                }
            } else if ("distancia".equals(editar)) {
                try (PreparedStatement ps = con.prepareStatement("SELECT id_ruta, estacion_origen, estacion_destino, distancia_km FROM distancias_tramos WHERE id_tramo = ?")) {
                    ps.setInt(1, editId); try (ResultSet r = ps.executeQuery()) { if (r.next()) { eRuta = r.getInt(1); eOrigen = r.getString(2); eDestino = r.getString(3); eKm = r.getBigDecimal(4).toPlainString(); } else editar = ""; }
                }
            } else if ("guardia".equals(editar)) {
                try (PreparedStatement ps = con.prepareStatement("SELECT g.nombre_completo, g.turno, a.codigo_puerta, a.id_estacion FROM guardias_seguridad g JOIN accesos_molinetes a ON g.id_acceso = a.id_acceso WHERE g.id_guardia = ?")) {
                    ps.setInt(1, editId); try (ResultSet r = ps.executeQuery()) { if (r.next()) { eGuardia = r.getString(1); eTurno = r.getString(2); ePuerta = r.getString(3); eEstacion = r.getInt(4); } else editar = ""; }
                }
            } else { editar = ""; }
        } catch (Exception e) { editar = ""; }
    }
    // Precarga desde otras pantallas (ej. editar_rutas.jsp?...&ruta=2&origen=A&destino=B)
    if (editar.isEmpty()) {
        try { eRuta = Integer.parseInt(t(request.getParameter("ruta"))); } catch (Exception e) {}
        eOrigen = t(request.getParameter("origen")); eDestino = t(request.getParameter("destino"));
    }
    boolean edP = "parqueo".equals(editar), edE = "estacion".equals(editar), edD = "distancia".equals(editar), edG = "guardia".equals(editar);
%>

<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <title>Gestión de Infraestructura</title>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;600;800&display=swap" rel="stylesheet">
    <style>
        body { font-family: 'Inter', sans-serif; background-color: #f0f2f5; margin: 0; padding-top: 70px; }
        .header { background: #ffffff; padding: 15px 25px; position: fixed; top: 0; width: 100%; box-sizing: border-box; z-index: 1000; display: flex; justify-content: space-between; align-items: center; border-bottom: 1px solid #e2e8f0; }
        .header h1 { margin: 0; font-size: 18px; text-align: center; flex-grow: 1; font-weight: 700; color: #1e293b;}
        .menu-btn { background: none; border: none; font-size: 24px; cursor: pointer; color: #475569;}
        .overlay { display: none; position: fixed; width: 100%; height: 100%; top: 0; left: 0; background: rgba(15, 23, 42, 0.4); z-index: 999; }
        
        .main-container { max-width: 1000px; margin: 30px auto; padding: 0 20px;}
        .page-title { margin-bottom: 25px; display: flex; justify-content: space-between; align-items: flex-start; gap: 15px; flex-wrap: wrap;}
        .page-title h2 { margin: 0 0 5px 0; font-size: 26px; font-weight: 800; color: #0f172a;}
        .btn-ver { background: #1a2a6c; color: white; text-decoration: none; padding: 12px 18px; border-radius: 8px; font-weight: bold; font-size: 14px; white-space: nowrap;}
        .btn-ver:hover { background: #11205a; }
        
        .alerta { padding: 15px; border-radius: 8px; margin-bottom: 20px; font-weight: bold; }
        .alerta.success { background: #dcfce7; color: #166534; border: 1px solid #86efac; }
        .alerta.error { background: #fee2e2; color: #991b1b; border: 1px solid #fca5a5; }

        .form-card { background: white; border-radius: 12px; padding: 25px; border: 1px solid #e2e8f0; box-shadow: 0 4px 6px rgba(0,0,0,0.02); margin-bottom: 25px; border-top: 4px solid #1a2a6c; overflow-x: auto;}
        .form-card.editando { border-top-color: #d35400; background: #fffaf5; }
        .form-card h3 { margin: 0 0 15px 0; color: #1e293b;}
        .form-card h4 { margin: 25px 0 10px 0; color: #475569; font-size: 14px; text-transform: uppercase;}
        
        .form-row { display: grid; grid-template-columns: repeat(auto-fit, minmax(180px, 1fr)); gap: 15px; margin-bottom: 15px; }
        .form-group label { display: block; font-size: 13px; font-weight: bold; color: #475569; margin-bottom: 5px;}
        .form-group input, .form-group select { width: 100%; padding: 10px; border: 1px solid #cbd5e1; border-radius: 6px; box-sizing: border-box; font-family: 'Inter';}
        
        .btn-submit { background: #11998e; color: white; border: none; padding: 12px 20px; border-radius: 6px; font-weight: bold; cursor: pointer; transition: 0.2s;}
        .btn-submit:hover { background: #0e7c74; }
        .btn-cancel { display: inline-block; margin-left: 10px; color: #64748b; text-decoration: none; font-weight: bold; font-size: 14px;}
        
        table { width: 100%; border-collapse: collapse; }
        th { background-color: #f1f5f9; padding: 10px; font-size: 12px; color: #64748b; text-transform: uppercase; text-align: left;}
        td { padding: 10px; font-size: 14px; border-bottom: 1px solid #e2e8f0; color: #334155;}
        .acciones { white-space: nowrap; }
        .acciones form { display: inline; }
        .btn-mini { border: none; padding: 6px 10px; border-radius: 6px; font-size: 12px; font-weight: bold; cursor: pointer; text-decoration: none; display: inline-block; font-family: 'Inter';}
        .btn-edit { background: #dbeafe; color: #1d4ed8; }
        .btn-del { background: #fee2e2; color: #b91c1c; }
        .vacio { text-align: center; color: #94a3b8; font-style: italic; padding: 15px; }
        .aviso { background: #fef3c7; color: #92400e; padding: 10px 12px; border-radius: 6px; font-size: 13px; margin-bottom: 12px; }
    </style>
    <link rel="stylesheet" href="css/transmetro.css">
</head>
<body>
    <jsp:include page="menu_izquierdo.jsp" />
    <jsp:include page="menu_derecho.jsp" />
    <div id="overlay" class="overlay" onclick="closeAllMenus()"></div>

    <div class="header">
        <button class="menu-btn" onclick="toggleMenu('left')">☰</button>
        <h1>Panel de Control</h1>
        <button class="menu-btn" onclick="toggleMenu('right')">⚙️</button>
    </div>

    <div class="main-container">
        <div class="page-title">
            <div>
                <h2>🏗️ Gestión de Infraestructura</h2>
                <p style="color: #64748b; margin: 0;">Crea, edita y elimina parqueos, estaciones, guardias y distancias. Todos los usuarios ven estos datos en modo consulta.</p>
            </div>
            <a href="infraestructura.jsp" class="btn-ver">👁️ Ver vista pública</a>
        </div>

        <% if (!mensaje.isEmpty()) { %>
            <div class="alerta <%= tipoAlerta %>"><%= h(mensaje) %></div>
        <% } %>

        <!-- ======================= PARQUEOS ======================= -->
        <div class="form-card <%= edP ? "editando" : "" %>" id="parqueos">
            <h3>🅿️ <%= edP ? "Editando Parqueo #" + editId : "Registrar Nuevo Parqueo" %></h3>
            <form action="admin_infra.jsp" method="POST">
                <input type="hidden" name="accion" value="<%= edP ? "edit_parqueo" : "add_parqueo" %>">
                <% if (edP) { %><input type="hidden" name="id" value="<%= editId %>"><% } %>
                <div class="form-row">
                    <div class="form-group"><label>Nombre del Predio / Parqueo</label><input type="text" name="nombre_parqueo" required maxlength="100" value="<%= h(eNombre) %>" placeholder="Ej. Predio Sur"></div>
                    <div class="form-group"><label>Capacidad Máxima de Buses</label><input type="number" name="capacidad" required min="1" value="<%= h(eCap) %>" placeholder="Ej. 50"></div>
                </div>
                <button type="submit" class="btn-submit"><%= edP ? "💾 Guardar Cambios" : "Registrar Parqueo Oficial" %></button>
                <% if (edP) { %><a href="admin_infra.jsp" class="btn-cancel">Cancelar</a><% } %>
            </form>

            <h4>Parqueos registrados</h4>
            <table>
                <tr><th>ID</th><th>Parqueo</th><th>Ocupación</th><th></th></tr>
                <%
                    boolean hay = false;
                    if (con != null) {
                        try (Statement st = con.createStatement(); ResultSet r = st.executeQuery(
                                "SELECT p.id_parqueo, p.nombre, p.capacidad_buses, COUNT(f.id_vehiculo) AS ocupados FROM parqueos p LEFT JOIN flota_vehiculos f ON f.id_parqueo = p.id_parqueo GROUP BY p.id_parqueo, p.nombre, p.capacidad_buses ORDER BY p.id_parqueo")) {
                            while (r.next()) { hay = true; %>
                <tr>
                    <td>#<%= r.getInt("id_parqueo") %></td>
                    <td><%= h(r.getString("nombre")) %></td>
                    <td>🚍 <%= r.getInt("ocupados") %> / <%= r.getInt("capacidad_buses") %></td>
                    <td class="acciones">
                        <a class="btn-mini btn-edit" href="admin_infra.jsp?editar=parqueo&id=<%= r.getInt("id_parqueo") %>#parqueos">✏️ Editar</a>
                        <form action="admin_infra.jsp" method="POST" onsubmit="return confirm('¿Eliminar este parqueo?');">
                            <input type="hidden" name="accion" value="del_parqueo"><input type="hidden" name="id" value="<%= r.getInt("id_parqueo") %>">
                            <button type="submit" class="btn-mini btn-del">🗑️ Eliminar</button>
                        </form>
                    </td>
                </tr>
                <%          }
                        } catch (Exception e) { out.print("<tr><td colspan='4'>Error: " + h(e.getMessage()) + "</td></tr>"); }
                    }
                    if (!hay) out.print("<tr><td colspan='4' class='vacio'>Aún no hay parqueos.</td></tr>");
                %>
            </table>
        </div>

        <!-- ======================= ESTACIONES FÍSICAS ======================= -->
        <div class="form-card <%= edE ? "editando" : "" %>" id="estaciones">
            <h3>🚏 <%= edE ? "Editando Estación #" + editId : "Registrar Estación Física" %></h3>
            <form action="admin_infra.jsp" method="POST">
                <input type="hidden" name="accion" value="<%= edE ? "edit_estacion" : "add_estacion" %>">
                <% if (edE) { %><input type="hidden" name="id" value="<%= editId %>"><% } %>
                <div class="form-row">
                    <div class="form-group"><label>Nombre de la Estación</label><input type="text" name="nombre_estacion" required maxlength="100" value="<%= h(eNombre) %>" placeholder="Ej. El Carmen"></div>
                    <div class="form-group"><label>Latitud (opcional)</label><input type="text" name="latitud" maxlength="50" value="<%= h(eLat) %>" placeholder="Ej. 14.6349"></div>
                    <div class="form-group"><label>Longitud (opcional)</label><input type="text" name="longitud" maxlength="50" value="<%= h(eLon) %>" placeholder="Ej. -90.5069"></div>
                </div>
                <button type="submit" class="btn-submit"><%= edE ? "💾 Guardar Cambios" : "Registrar Estación" %></button>
                <% if (edE) { %><a href="admin_infra.jsp" class="btn-cancel">Cancelar</a><% } %>
            </form>

            <h4>Estaciones registradas</h4>
            <table>
                <tr><th>ID</th><th>Estación</th><th>Molinetes / Guardias</th><th>Km conectados</th><th>Rutas</th><th></th></tr>
                <%
                    hay = false;
                    if (con != null) {
                        try (Statement st = con.createStatement(); ResultSet r = st.executeQuery(
                                "SELECT e.id_estacion, e.nombre, " +
                                "(SELECT COUNT(*) FROM accesos_molinetes a WHERE a.id_estacion = e.id_estacion) AS molinetes, " +
                                "(SELECT COUNT(*) FROM accesos_molinetes a JOIN guardias_seguridad g ON g.id_acceso = a.id_acceso WHERE a.id_estacion = e.id_estacion) AS guardias, " +
                                "(SELECT COALESCE(SUM(d.distancia_km), 0) FROM distancias_tramos d WHERE d.estacion_origen = e.nombre OR d.estacion_destino = e.nombre) AS km, " +
                                "(SELECT COUNT(*) FROM rutas_operativas r WHERE FIND_IN_SET(e.nombre, REPLACE(REPLACE(r.lista_estaciones, ', ', ','), ' ,', ',')) > 0) AS rutas " +
                                "FROM estaciones_fisicas e ORDER BY e.nombre")) {
                            while (r.next()) { hay = true;
                                int nMol = r.getInt("molinetes"); int nGua = r.getInt("guardias"); int nRutas = r.getInt("rutas"); %>
                <tr>
                    <td>#<%= r.getInt("id_estacion") %></td>
                    <td><%= h(r.getString("nombre")) %></td>
                    <td><% if (nMol == 0) { %><span style="color:#b45309;">⚠️ Sin molinete</span><% } else { %>🚪 <%= nMol %> · 👮 <%= nGua %><% } %></td>
                    <td><%= r.getBigDecimal("km").signum() == 0 ? "<span style='color:#94a3b8;'>—</span>" : "📏 " + r.getBigDecimal("km") + " km" %></td>
                    <td><%= nRutas == 0 ? "<span style='color:#94a3b8;'>Ninguna</span>" : "🗺️ " + nRutas %></td>
                    <td class="acciones">
                        <a class="btn-mini btn-edit" href="admin_infra.jsp?editar=estacion&id=<%= r.getInt("id_estacion") %>#estaciones">✏️ Editar</a>
                        <form action="admin_infra.jsp" method="POST" onsubmit="return confirm('<%= nRutas > 0 ? "Esta estación aparece en " + nRutas + " ruta(s). " : "" %>¿Eliminar esta estación?');">
                            <input type="hidden" name="accion" value="del_estacion"><input type="hidden" name="id" value="<%= r.getInt("id_estacion") %>">
                            <button type="submit" class="btn-mini btn-del">🗑️ Eliminar</button>
                        </form>
                    </td>
                </tr>
                <%          }
                        } catch (Exception e) { out.print("<tr><td colspan='6'>Error: " + h(e.getMessage()) + "</td></tr>"); }
                    }
                    if (!hay) out.print("<tr><td colspan='6' class='vacio'>Aún no hay estaciones físicas.</td></tr>");
                %>
            </table>
        </div>

        <!-- ======================= GUARDIAS Y MOLINETES ======================= -->
        <div class="form-card <%= edG ? "editando" : "" %>" id="guardias">
            <h3>🛡️ <%= edG ? "Editando Asignación #" + editId : "Asignar Guardia a Molinete" %></h3>
            <%
                // Estaciones disponibles para el selector
                java.util.List<int[]> idsEst = new java.util.ArrayList<int[]>();
                java.util.List<String> nomEst = new java.util.ArrayList<String>();
                if (con != null) {
                    try (Statement st = con.createStatement(); ResultSet r = st.executeQuery("SELECT id_estacion, nombre FROM estaciones_fisicas ORDER BY nombre")) {
                        while (r.next()) { idsEst.add(new int[]{r.getInt(1)}); nomEst.add(r.getString(2)); }
                    } catch (Exception e) {}
                }
                if (idsEst.isEmpty()) { %><div class="aviso">⚠️ Primero registra al menos una estación física (sección de arriba).</div><% }
            %>
            <form action="admin_infra.jsp" method="POST">
                <input type="hidden" name="accion" value="<%= edG ? "edit_guardia" : "add_guardia" %>">
                <% if (edG) { %><input type="hidden" name="id" value="<%= editId %>"><% } %>
                <div class="form-row">
                    <div class="form-group">
                        <label>Estación Física</label>
                        <select name="id_estacion" required>
                            <% for (int i = 0; i < idsEst.size(); i++) { %>
                                <option value="<%= idsEst.get(i)[0] %>" <%= (edG && idsEst.get(i)[0] == eEstacion) ? "selected" : "" %>><%= h(nomEst.get(i)) %></option>
                            <% } %>
                        </select>
                    </div>
                    <div class="form-group"><label>Código de Puerta / Molinete</label><input type="text" name="puerta" required maxlength="50" value="<%= h(ePuerta) %>" placeholder="Ej. Puerta Norte-A"></div>
                    <div class="form-group"><label>Nombre del Guardia (RN05)</label><input type="text" name="nombre_guardia" required maxlength="100" value="<%= h(eGuardia) %>" placeholder="Nombre completo"></div>
                    <div class="form-group">
                        <label>Turno</label>
                        <select name="turno">
                            <option value="Diurno" <%= "Diurno".equals(eTurno) ? "selected" : "" %>>Diurno (AM)</option>
                            <option value="Nocturno" <%= "Nocturno".equals(eTurno) ? "selected" : "" %>>Nocturno (PM)</option>
                        </select>
                    </div>
                </div>
                <button type="submit" class="btn-submit" <%= idsEst.isEmpty() ? "disabled" : "" %>><%= edG ? "💾 Guardar Cambios" : "Guardar Asignación" %></button>
                <% if (edG) { %><a href="admin_infra.jsp" class="btn-cancel">Cancelar</a><% } %>
            </form>

            <h4>Guardias asignados</h4>
            <table>
                <tr><th>Estación</th><th>Molinete</th><th>Guardia</th><th>Turno</th><th></th></tr>
                <%
                    hay = false;
                    if (con != null) {
                        try (Statement st = con.createStatement(); ResultSet r = st.executeQuery(
                                "SELECT g.id_guardia, g.nombre_completo, g.turno, a.codigo_puerta, e.nombre AS estacion FROM guardias_seguridad g JOIN accesos_molinetes a ON g.id_acceso = a.id_acceso JOIN estaciones_fisicas e ON a.id_estacion = e.id_estacion ORDER BY e.nombre, a.codigo_puerta")) {
                            while (r.next()) { hay = true; %>
                <tr>
                    <td>🚏 <%= h(r.getString("estacion")) %></td>
                    <td>🚪 <%= h(r.getString("codigo_puerta")) %></td>
                    <td>👮 <%= h(r.getString("nombre_completo")) %></td>
                    <td><%= h(r.getString("turno")) %></td>
                    <td class="acciones">
                        <a class="btn-mini btn-edit" href="admin_infra.jsp?editar=guardia&id=<%= r.getInt("id_guardia") %>#guardias">✏️ Editar</a>
                        <form action="admin_infra.jsp" method="POST" onsubmit="return confirm('Se eliminará el guardia junto con su molinete (RN05). ¿Continuar?');">
                            <input type="hidden" name="accion" value="del_guardia"><input type="hidden" name="id" value="<%= r.getInt("id_guardia") %>">
                            <button type="submit" class="btn-mini btn-del">🗑️ Eliminar</button>
                        </form>
                    </td>
                </tr>
                <%          }
                        } catch (Exception e) { out.print("<tr><td colspan='5'>Error: " + h(e.getMessage()) + "</td></tr>"); }
                    }
                    if (!hay) out.print("<tr><td colspan='5' class='vacio'>Aún no hay guardias asignados.</td></tr>");
                %>
            </table>
        </div>

        <!-- ======================= DISTANCIAS ======================= -->
        <div class="form-card <%= edD ? "editando" : "" %>" id="distancias">
            <h3>📏 <%= edD ? "Editando Tramo #" + editId : "Nuevo Tramo (Kilómetros)" %></h3>
            <%
                java.util.List<int[]> idsRuta = new java.util.ArrayList<int[]>();
                java.util.List<String> nomRuta = new java.util.ArrayList<String>();
                java.util.List<String> nomsEstacion = new java.util.ArrayList<String>();
                if (con != null) {
                    try (Statement st = con.createStatement(); ResultSet r = st.executeQuery("SELECT id_ruta, nombre_ruta FROM rutas_operativas ORDER BY nombre_ruta")) {
                        while (r.next()) { idsRuta.add(new int[]{r.getInt(1)}); nomRuta.add(r.getString(2)); }
                    } catch (Exception e) {}
                    try (Statement st = con.createStatement(); ResultSet r = st.executeQuery("SELECT nombre FROM estaciones_fisicas UNION SELECT nombre FROM estaciones_catalogo ORDER BY 1")) {
                        while (r.next()) nomsEstacion.add(r.getString(1));
                    } catch (Exception e) {}
                }
                if (idsRuta.isEmpty()) { %><div class="aviso">⚠️ No hay rutas operativas. Crea una en "Configurar Nueva Ruta" para poder mapear distancias.</div><% }
            %>
            <datalist id="listaEstaciones">
                <% for (String ne : nomsEstacion) { %><option value="<%= h(ne) %>"><% } %>
            </datalist>
            <form action="admin_infra.jsp" method="POST">
                <input type="hidden" name="accion" value="<%= edD ? "edit_distancia" : "add_distancia" %>">
                <% if (edD) { %><input type="hidden" name="id" value="<%= editId %>"><% } %>
                <div class="form-row">
                    <div class="form-group">
                        <label>Ruta Operativa</label>
                        <select name="id_ruta" required>
                            <% for (int i = 0; i < idsRuta.size(); i++) { %>
                                <option value="<%= idsRuta.get(i)[0] %>" <%= (eRuta != 0 && idsRuta.get(i)[0] == eRuta) ? "selected" : "" %>><%= h(nomRuta.get(i)) %></option>
                            <% } %>
                        </select>
                    </div>
                    <div class="form-group"><label>Estación Origen</label><input type="text" name="origen" list="listaEstaciones" required maxlength="100" value="<%= h(eOrigen) %>" placeholder="Ej. El Carmen"></div>
                    <div class="form-group"><label>Estación Destino</label><input type="text" name="destino" list="listaEstaciones" required maxlength="100" value="<%= h(eDestino) %>" placeholder="Ej. Las Charcas"></div>
                    <div class="form-group"><label>Distancia (KM)</label><input type="number" step="0.01" min="0.01" max="999.99" name="km" required value="<%= h(eKm) %>" placeholder="Ej. 2.5"></div>
                </div>
                <button type="submit" class="btn-submit" <%= idsRuta.isEmpty() ? "disabled" : "" %>><%= edD ? "💾 Guardar Cambios" : "Guardar Distancia" %></button>
                <% if (edD) { %><a href="admin_infra.jsp" class="btn-cancel">Cancelar</a><% } %>
            </form>

            <h4>Tramos registrados</h4>
            <table>
                <tr><th>Ruta</th><th>Tramo</th><th>Distancia</th><th></th></tr>
                <%
                    hay = false;
                    if (con != null) {
                        try (Statement st = con.createStatement(); ResultSet r = st.executeQuery(
                                "SELECT d.id_tramo, COALESCE(r.nombre_ruta, CONCAT('Ruta ', d.id_ruta)) AS ruta, d.estacion_origen, d.estacion_destino, d.distancia_km FROM distancias_tramos d LEFT JOIN rutas_operativas r ON d.id_ruta = r.id_ruta ORDER BY d.id_ruta, d.id_tramo")) {
                            while (r.next()) { hay = true; %>
                <tr>
                    <td>🗺️ <%= h(r.getString("ruta")) %></td>
                    <td><%= h(r.getString("estacion_origen")) %> ➔ <%= h(r.getString("estacion_destino")) %></td>
                    <td><%= r.getBigDecimal("distancia_km") %> km</td>
                    <td class="acciones">
                        <a class="btn-mini btn-edit" href="admin_infra.jsp?editar=distancia&id=<%= r.getInt("id_tramo") %>#distancias">✏️ Editar</a>
                        <form action="admin_infra.jsp" method="POST" onsubmit="return confirm('¿Eliminar este tramo?');">
                            <input type="hidden" name="accion" value="del_distancia"><input type="hidden" name="id" value="<%= r.getInt("id_tramo") %>">
                            <button type="submit" class="btn-mini btn-del">🗑️ Eliminar</button>
                        </form>
                    </td>
                </tr>
                <%          }
                        } catch (Exception e) { out.print("<tr><td colspan='4'>Error: " + h(e.getMessage()) + "</td></tr>"); }
                    }
                    if (!hay) out.print("<tr><td colspan='4' class='vacio'>Aún no hay tramos mapeados.</td></tr>");
                    if (con != null) { try { con.close(); } catch (Exception e) {} }
                %>
            </table>
        </div>
    </div>

    <script>
        function toggleMenu(side) {
            let left = document.getElementById("leftSidebar"); let right = document.getElementById("rightSidebar"); let over = document.getElementById("overlay");
            if (side === 'left') { left.style.width = "250px"; if(right) right.style.width = "0"; } 
            else if (side === 'right') { if(right) right.style.width = "300px"; left.style.width = "0"; }
            over.style.display = "block";
        }
        function closeAllMenus() {
            document.getElementById("leftSidebar").style.width = "0"; let right = document.getElementById("rightSidebar"); if(right) right.style.width = "0";
            document.getElementById("overlay").style.display = "none";
        }
    </script>
</body>
</html>