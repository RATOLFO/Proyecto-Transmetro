<%@page contentType="text/html" pageEncoding="UTF-8"%>
<%@page import="java.sql.*"%>
<%!
    // Escapa texto antes de imprimirlo en HTML
    static String h(String s) {
        if (s == null) return "";
        return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace("\"", "&quot;").replace("'", "&#39;");
    }
    static String t(String v) { return v == null ? "" : v.trim(); }

    // Crea los asientos 1..cantidad (estado 'libre') de un vehículo. operacion.jsp los lee de la tabla asientos.
    static void crearAsientos(Connection con, int idVehiculo, int cantidad) throws SQLException {
        try (PreparedStatement ps = con.prepareStatement("INSERT INTO asientos (id_bus, num_asiento, estado) VALUES (?, ?, 'libre')")) {
            for (int i = 1; i <= cantidad; i++) { ps.setInt(1, idVehiculo); ps.setInt(2, i); ps.addBatch(); }
            ps.executeBatch();
        }
    }
%>
<%
    // Seguridad: Solo el administrador puede entrar aquí
    String rolActual = (String) session.getAttribute("rol");
    if (rolActual == null || !"admin".equals(rolActual)) {
        response.sendRedirect("index.jsp"); return;
    }

    String dbUrl = "jdbc:mysql://192.168.15.135:3306/transmetro_db"; 
    String dbUser = "admin"; String dbPass = "admin123";
    String mensaje = "";
    String tipoAlerta = "success";
    final int CAPACIDAD_MAX = 300; // tope razonable de asientos por unidad

    // ======================= ESCRITURA (POST) =======================
    if ("POST".equalsIgnoreCase(request.getMethod())) {
        request.setCharacterEncoding("UTF-8");
        String accion = t(request.getParameter("accion"));
        Connection con = null;
        try {
            Class.forName("com.mysql.cj.jdbc.Driver");
            con = DriverManager.getConnection(dbUrl, dbUser, dbPass);

            if ("generar_asientos".equals(accion)) {
                // Genera los asientos de una unidad que ya existía pero no los tiene
                int idVeh = Integer.parseInt(request.getParameter("id_vehiculo"));
                int cap = -1, existentes = 0; String placaVeh = "";
                try (PreparedStatement ps = con.prepareStatement("SELECT f.capacidad, f.placa, (SELECT COUNT(*) FROM asientos a WHERE a.id_bus = f.id_vehiculo) FROM flota_vehiculos f WHERE f.id_vehiculo = ?")) {
                    ps.setInt(1, idVeh);
                    try (ResultSet r = ps.executeQuery()) { if (r.next()) { cap = r.getInt(1); placaVeh = r.getString(2); existentes = r.getInt(3); } }
                }
                if (cap < 0) throw new Exception("La unidad ya no existe.");
                if (existentes > 0) throw new Exception("La unidad " + placaVeh + " ya tiene " + existentes + " asientos.");
                if (cap < 1 || cap > CAPACIDAD_MAX) throw new Exception("La capacidad registrada (" + cap + ") no es válida para generar asientos.");
                crearAsientos(con, idVeh, cap);
                mensaje = "✅ Se generaron " + cap + " asientos para la unidad " + placaVeh + ".";

            } else {
                // ---- Alta de una unidad nueva ----
                String placa = t(request.getParameter("placa")).toUpperCase();
                int capacidad = Integer.parseInt(t(request.getParameter("capacidad")));
                String estado = t(request.getParameter("estado"));
                int idParqueo = Integer.parseInt(request.getParameter("id_parqueo"));
                String municipalidad = t(request.getParameter("municipalidad"));

                if (placa.isEmpty()) throw new Exception("La placa es obligatoria.");
                if (capacidad < 1 || capacidad > CAPACIDAD_MAX) throw new Exception("La capacidad debe estar entre 1 y " + CAPACIDAD_MAX + " pasajeros.");
                if (!"Libre en Garaje".equals(estado) && !"Mantenimiento".equals(estado)) throw new Exception("Estado inicial inválido.");
                if (municipalidad.isEmpty()) throw new Exception("La municipalidad es obligatoria.");

                // La municipalidad debe existir en el catálogo
                int existeMuni = 0;
                try (PreparedStatement ps = con.prepareStatement("SELECT COUNT(*) FROM municipalidades WHERE nombre = ?")) {
                    ps.setString(1, municipalidad); try (ResultSet r = ps.executeQuery()) { if (r.next()) existeMuni = r.getInt(1); }
                }
                if (existeMuni == 0) throw new Exception("La municipalidad seleccionada no existe en el catálogo.");

                // No permitir placas duplicadas
                int placasIguales = 0;
                try (PreparedStatement ps = con.prepareStatement("SELECT COUNT(*) FROM flota_vehiculos WHERE placa = ?")) {
                    ps.setString(1, placa); try (ResultSet r = ps.executeQuery()) { if (r.next()) placasIguales = r.getInt(1); }
                }
                if (placasIguales > 0) throw new Exception("Ya existe una unidad con la placa " + placa + ".");

                // RN04: el parqueo debe existir y tener espacio disponible
                int capParqueo = 0, ocupadosParqueo = 0; boolean parqueoExiste = false;
                try (PreparedStatement ps = con.prepareStatement("SELECT p.capacidad_buses, (SELECT COUNT(*) FROM flota_vehiculos f WHERE f.id_parqueo = p.id_parqueo) FROM parqueos p WHERE p.id_parqueo = ?")) {
                    ps.setInt(1, idParqueo);
                    try (ResultSet r = ps.executeQuery()) { parqueoExiste = r.next(); if (parqueoExiste) { capParqueo = r.getInt(1); ocupadosParqueo = r.getInt(2); } }
                }
                if (!parqueoExiste) throw new Exception("El parqueo seleccionado no existe.");
                if (ocupadosParqueo >= capParqueo) throw new Exception("El parqueo está lleno (" + ocupadosParqueo + "/" + capParqueo + "). Elige otro parqueo o amplía su capacidad en Infraestructura.");

                // Unidad + asientos en una sola transacción: o se crea todo o no se crea nada
                con.setAutoCommit(false);
                try {
                    int idNuevo = -1;
                    try (PreparedStatement ps = con.prepareStatement("INSERT INTO flota_vehiculos (placa, municipalidad, capacidad, estado, id_parqueo) VALUES (?, ?, ?, ?, ?)", Statement.RETURN_GENERATED_KEYS)) {
                        ps.setString(1, placa); ps.setString(2, municipalidad); ps.setInt(3, capacidad); ps.setString(4, estado); ps.setInt(5, idParqueo);
                        ps.executeUpdate();
                        try (ResultSet k = ps.getGeneratedKeys()) { if (k.next()) idNuevo = k.getInt(1); }
                    }
                    if (idNuevo < 0) throw new Exception("No se pudo registrar la unidad.");
                    crearAsientos(con, idNuevo, capacidad);
                    con.commit();
                } catch (Exception ex) { con.rollback(); throw ex; } finally { con.setAutoCommit(true); }
                mensaje = "✅ Bus " + placa + " registrado con " + capacidad + " asientos, listo para operar desde su predio.";
            }
        } catch (NumberFormatException e) {
            mensaje = "❌ Dato numérico inválido. Revisa los campos del formulario."; tipoAlerta = "error";
        } catch (Exception e) {
            mensaje = "❌ " + e.getMessage(); tipoAlerta = "error";
        } finally {
            if (con != null) { try { con.close(); } catch (Exception ignorar) {} }
        }
        // Post/Redirect/Get: evita registrar el bus dos veces si se recarga la página
        session.setAttribute("busMsg", mensaje);
        session.setAttribute("busTipo", tipoAlerta);
        response.sendRedirect("admin_buses.jsp");
        return;
    }

    if (session.getAttribute("busMsg") != null) {
        mensaje = (String) session.getAttribute("busMsg");
        tipoAlerta = (String) session.getAttribute("busTipo");
        session.removeAttribute("busMsg"); session.removeAttribute("busTipo");
    }
%>

<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <title>Administrar Garaje</title>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;600;800&display=swap" rel="stylesheet">
    <style>
        body { font-family: 'Inter', sans-serif; background-color: #f0f2f5; margin: 0; padding-top: 70px; }
        .header { background: #ffffff; padding: 15px 25px; position: fixed; top: 0; width: 100%; box-sizing: border-box; z-index: 1000; display: flex; justify-content: space-between; align-items: center; border-bottom: 1px solid #e2e8f0; }
        .header h1 { margin: 0; font-size: 18px; text-align: center; flex-grow: 1; font-weight: 700; color: #1e293b;}
        .menu-btn { background: none; border: none; font-size: 24px; cursor: pointer; color: #475569;}
        .overlay { display: none; position: fixed; width: 100%; height: 100%; top: 0; left: 0; background: rgba(15, 23, 42, 0.4); z-index: 999; }
        
        .main-container { max-width: 600px; margin: 40px auto; padding: 0 20px;}
        
        .form-card { background: white; padding: 30px; border-radius: 12px; box-shadow: 0 4px 15px rgba(0,0,0,0.05); border-top: 5px solid #f39c12; margin-bottom: 25px;}
        .form-card h2 { margin: 0 0 20px 0; color: #1e293b; font-size: 24px; font-weight: 800; display: flex; align-items: center; gap: 10px;}
        .form-card h3 { margin: 0 0 8px 0; color: #1e293b; font-size: 18px;}
        
        .alerta { padding: 15px; border-radius: 8px; margin-bottom: 20px; font-weight: bold; text-align: center;}
        .alerta.success { background: #dcfce7; color: #166534; border: 1px solid #86efac; }
        .alerta.error { background: #fee2e2; color: #991b1b; border: 1px solid #fca5a5; }
        .aviso { background: #fef3c7; color: #92400e; padding: 10px 12px; border-radius: 6px; font-size: 13px; margin-bottom: 12px; }

        .form-group { margin-bottom: 20px; }
        .form-group label { display: block; font-size: 14px; font-weight: bold; color: #475569; margin-bottom: 8px;}
        .form-group input, .form-group select { width: 100%; padding: 12px; border: 1px solid #cbd5e1; border-radius: 6px; box-sizing: border-box; font-family: 'Inter'; font-size: 14px;}
        
        .btn-submit { background: #1e293b; color: white; border: none; padding: 14px 20px; border-radius: 6px; font-weight: bold; font-size: 16px; cursor: pointer; transition: 0.2s; width: 100%;}
        .btn-submit:hover { background: #0f172a; transform: translateY(-2px);}

        .fila-bus { display: flex; justify-content: space-between; align-items: center; gap: 10px; padding: 10px 0; border-bottom: 1px solid #f1f5f9; font-size: 14px; color: #334155;}
        .fila-bus:last-child { border-bottom: none; }
        .fila-bus form { margin: 0; }
        .btn-gen { background: #11998e; color: white; border: none; padding: 8px 12px; border-radius: 6px; font-weight: bold; font-size: 12px; cursor: pointer; white-space: nowrap;}
        .btn-gen:hover { background: #0e7c74; }
    </style>
    <link rel="stylesheet" href="css/transmetro.css">
</head>
<body>
    <jsp:include page="menu_izquierdo.jsp" />
    <jsp:include page="menu_derecho.jsp" />
    <div id="overlay" class="overlay" onclick="closeAllMenus()"></div>

    <div class="header">
        <button class="menu-btn" onclick="toggleMenu('left')">☰</button>
        <h1>Centro de Administración</h1>
        <button class="menu-btn" onclick="toggleMenu('right')">⚙️</button>
    </div>

    <div class="main-container">
        <div class="form-card">
            <h2>🚍 Alta de Nueva Unidad</h2>
            <p style="color: #64748b; font-size: 14px; margin-bottom: 20px;">Ingresa los datos del nuevo bus. <strong>Regla RN04:</strong> Todo bus debe estar asignado a un parqueo oficial. Al guardarlo se crean automáticamente sus asientos.</p>

            <% if (!mensaje.isEmpty()) { %>
                <div class="alerta <%= tipoAlerta %>"><%= h(mensaje) %></div>
            <% } %>

            <%
                // Catálogo de municipalidades para el selector (obligatorio)
                java.util.List<String> municipalidades = new java.util.ArrayList<String>();
                try {
                    Class.forName("com.mysql.cj.jdbc.Driver");
                    Connection conM = DriverManager.getConnection(dbUrl, dbUser, dbPass);
                    Statement stM = conM.createStatement();
                    ResultSet rsM = stM.executeQuery("SELECT nombre FROM municipalidades ORDER BY nombre");
                    while (rsM.next()) municipalidades.add(rsM.getString(1));
                    rsM.close(); stM.close(); conM.close();
                } catch (Exception e) {}
                if (municipalidades.isEmpty()) { %>
                <div class="aviso">⚠️ No hay municipalidades registradas. Agrégalas primero en <a href="admin_catalogos.jsp">Gestionar Catálogos</a>.</div>
            <%  } %>

            <form action="admin_buses.jsp" method="POST">
                <div class="form-group">
                    <label>Placa del Vehículo</label>
                    <input type="text" name="placa" required maxlength="50" placeholder="Ej. UMG-1025">
                </div>
                <div class="form-group">
                    <label>Capacidad Máxima de Pasajeros (asientos)</label>
                    <input type="number" name="capacidad" required min="1" max="<%= CAPACIDAD_MAX %>" placeholder="Ej. 40">
                </div>

                <div class="form-group">
                    <label>Municipalidad</label>
                    <select name="municipalidad" required>
                        <option value="" disabled selected>-- Seleccione una municipalidad --</option>
                        <% for (String m : municipalidades) { %>
                            <option value="<%= h(m) %>">🏛️ <%= h(m) %></option>
                        <% } %>
                    </select>
                </div>
                
                <!-- Asignación de Parqueo -->
                <div class="form-group">
                    <label>Ubicación / Parqueo Base (RN04)</label>
                    <select name="id_parqueo" required>
                        <option value="" disabled selected>-- Seleccione un parqueo --</option>
                        <%
                            try {
                                Connection con = DriverManager.getConnection(dbUrl, dbUser, dbPass);
                                Statement st = con.createStatement();
                                ResultSet rsP = st.executeQuery("SELECT p.id_parqueo, p.nombre, p.capacidad_buses, COUNT(f.id_vehiculo) AS ocupados FROM parqueos p LEFT JOIN flota_vehiculos f ON f.id_parqueo = p.id_parqueo GROUP BY p.id_parqueo, p.nombre, p.capacidad_buses ORDER BY p.id_parqueo");
                                while(rsP.next()) {
                                    int capP = rsP.getInt("capacidad_buses"); int ocuP = rsP.getInt("ocupados");
                                    boolean llenoP = ocuP >= capP;
                                    out.print("<option value='" + rsP.getInt("id_parqueo") + "'" + (llenoP ? " disabled" : "") + ">🅿️ " + h(rsP.getString("nombre")) + " (" + ocuP + "/" + capP + ")" + (llenoP ? " - LLENO" : "") + "</option>");
                                }
                                rsP.close(); st.close(); con.close();
                            } catch(Exception e) {}
                        %>
                    </select>
                </div>

                <div class="form-group">
                    <label>Estado Inicial de Operación</label>
                    <select name="estado" required>
                        <option value="Libre en Garaje">Libre en Garaje (Reserva)</option>
                        <option value="Mantenimiento">Mantenimiento Correctivo</option>
                    </select>
                </div>
                
                <button type="submit" class="btn-submit" <%= municipalidades.isEmpty() ? "disabled" : "" %>>💾 Registrar y Guardar Bus</button>
            </form>
        </div>

        <%
            // Unidades ya registradas que no tienen asientos (por ejemplo, creadas antes de esta mejora)
            java.util.List<int[]> sinAsientosIds = new java.util.ArrayList<int[]>();
            java.util.List<String> sinAsientosInfo = new java.util.ArrayList<String>();
            try {
                Connection conS = DriverManager.getConnection(dbUrl, dbUser, dbPass);
                Statement stS = conS.createStatement();
                ResultSet rsS = stS.executeQuery("SELECT f.id_vehiculo, f.placa, f.capacidad FROM flota_vehiculos f WHERE NOT EXISTS (SELECT 1 FROM asientos a WHERE a.id_bus = f.id_vehiculo) ORDER BY f.placa");
                while (rsS.next()) { sinAsientosIds.add(new int[]{rsS.getInt(1)}); sinAsientosInfo.add(rsS.getString(2) + " — " + rsS.getInt(3) + " asientos por generar"); }
                rsS.close(); stS.close(); conS.close();
            } catch (Exception e) {}
            if (!sinAsientosIds.isEmpty()) {
        %>
        <div class="form-card" style="border-top-color: #11998e;">
            <h3>💺 Unidades sin asientos</h3>
            <p style="color: #64748b; font-size: 13px; margin: 0 0 12px 0;">Estas unidades no aparecen en la venta de asientos de <b>Operación</b> hasta que se generen sus asientos.</p>
            <% for (int i = 0; i < sinAsientosIds.size(); i++) { %>
                <div class="fila-bus">
                    <span>🚍 <%= h(sinAsientosInfo.get(i)) %></span>
                    <form action="admin_buses.jsp" method="POST">
                        <input type="hidden" name="accion" value="generar_asientos">
                        <input type="hidden" name="id_vehiculo" value="<%= sinAsientosIds.get(i)[0] %>">
                        <button type="submit" class="btn-gen">Generar asientos</button>
                    </form>
                </div>
            <% } %>
        </div>
        <% } %>
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