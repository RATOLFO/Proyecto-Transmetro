<%@page contentType="text/html" pageEncoding="UTF-8"%>
<%@page import="java.sql.*"%>
<%!
    static String h(String s) {
        if (s == null) return "";
        return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace("\"", "&quot;").replace("'", "&#39;");
    }
    static void asegurarColumnaPiloto(Connection con) {
        try (Statement st = con.createStatement()) {
            st.executeUpdate("ALTER TABLE rutas_operativas ADD COLUMN id_piloto INT DEFAULT NULL");
        } catch (SQLException ignorar) {}
    }
%>
<%
    if (session.getAttribute("usuarioValido") == null) { response.sendRedirect("login.jsp"); return; }
    String dbUrl = "jdbc:mysql://192.168.15.135:3306/transmetro_db";
    String dbUser = "admin";
    String dbPass = "admin123";
%>

<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <title>Directorio de Pilotos - Transmetro</title>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&display=swap" rel="stylesheet">
    <style>
        body { font-family: 'Inter', 'Segoe UI', sans-serif; background-color: #f0f2f5; margin: 0; padding-top: 70px; }
        .header { background: #ffffff; color: #1e293b; padding: 15px 25px; position: fixed; top: 0; width: 100%; box-sizing: border-box; z-index: 1000; display: flex; justify-content: space-between; align-items: center; border-bottom: 1px solid #e2e8f0; box-shadow: 0 1px 3px rgba(0,0,0,0.04); }
        .header h1 { margin: 0; font-size: 18px; text-align: center; flex-grow: 1; font-weight: 700; }
        .menu-btn { background: none; border: none; color: #475569; font-size: 24px; cursor: pointer; transition: 0.2s; border-radius: 5px; padding: 5px 10px; }
        .overlay { display: none; position: fixed; width: 100%; height: 100%; top: 0; left: 0; background: rgba(15, 23, 42, 0.4); backdrop-filter: blur(2px); z-index: 999; }

        .main-container { max-width: 1000px; margin: 30px auto; padding: 0 20px 50px 20px; }
        .page-title { display: flex; justify-content: space-between; align-items: flex-end; flex-wrap: wrap; gap: 12px; margin-bottom: 20px; }
        .page-title h2 { margin: 0 0 5px 0; font-size: 26px; font-weight: 800; color: #0f172a; }
        .page-title p { margin: 0; color: #64748b; font-size: 15px; }
        .card-container { background: #ffffff; border-radius: 12px; box-shadow: 0 4px 6px -1px rgba(0,0,0,0.05); border: 1px solid #e2e8f0; padding: 25px; overflow-x: auto; }

        table { width: 100%; border-collapse: collapse; text-align: left; }
        th { background-color: #f8fafc; padding: 12px 15px; font-size: 12px; color: #64748b; font-weight: 700; text-transform: uppercase; border-bottom: 2px solid #e2e8f0; }
        td { padding: 14px 15px; font-size: 14px; color: #334155; border-bottom: 1px solid #f1f5f9; }
        tr:hover td { background-color: #f8fafc; }
        .badge-id { background: #e0e7ff; color: #3730a3; padding: 4px 10px; border-radius: 6px; font-weight: bold; font-size: 12px; }
        .badge-ruta { background: #ecfdf5; color: #065f46; padding: 5px 10px; border-radius: 6px; font-weight: 700; font-size: 12px; border: 1px solid #a7f3d0; display: inline-block; }
    </style>
    <link rel="stylesheet" href="css/transmetro.css">
</head>
<body>
    <jsp:include page="menu_izquierdo.jsp" />
    <jsp:include page="menu_derecho.jsp" />
    <div id="overlay" class="overlay" onclick="closeAllMenus()"></div>

    <div class="header">
        <button class="menu-btn" onclick="toggleMenu('left')">☰</button>
        <h1>Directorio Personal</h1>
        <% if ("admin".equals(session.getAttribute("rol"))) { %><button class="menu-btn" onclick="toggleMenu('right')">⚙️</button><% } else { %><div style="width: 24px;"></div><% } %>
    </div>

    <div class="main-container">
        <div class="page-title">
            <div>
                <h2>🪪 Directorio Oficial de Pilotos</h2>
                <p>Personal operativo autorizado junto con su ruta, unidad principal y parqueo asignado.</p>
            </div>
            <% if ("admin".equals(session.getAttribute("rol"))) { %>
                <a href="Pilotos-Edicion.jsp" style="background:#e67e22; color:#fff; padding:9px 15px; border-radius:8px; font-size:13px; font-weight:700; text-decoration:none;">⚙️ Administrar Pilotos</a>
            <% } %>
        </div>

        <div class="card-container">
            <table>
                <thead>
                    <tr>
                        <th>Identificador</th>
                        <th>Nombre del Piloto</th>
                        <th>Edad</th>
                        <th>Cuenta Operativa</th>
                        <th>Ruta y Unidad Asignada</th>
                    </tr>
                </thead>
                <tbody>
                    <%
                        try {
                            Class.forName("com.mysql.cj.jdbc.Driver");
                            try (Connection con = DriverManager.getConnection(dbUrl, dbUser, dbPass)) {
                                asegurarColumnaPiloto(con);
                                try (Statement st = con.createStatement();
                                     ResultSet rs = st.executeQuery(
                                         "SELECT p.nombre, IFNULL(p.edad, 0) AS edad, " +
                                         "IFNULL(p.identificador_transmetro, 'Sin ID') AS identificador, " +
                                         "IFNULL(p.usuario_asignado, 'Sin asignar') AS usr, " +
                                         "(SELECT GROUP_CONCAT(CONCAT(r.nombre_ruta, ' · 🚍 ', IFNULL(vm.placa, 'S/P'), IF(pm.nombre IS NOT NULL, CONCAT(' (🅿️ ', pm.nombre, ')'), '')) SEPARATOR ' | ') " +
                                         " FROM rutas_operativas r " +
                                         " LEFT JOIN flota_vehiculos vm ON r.id_vehiculo_main = vm.id_vehiculo " +
                                         " LEFT JOIN parqueos pm ON vm.id_parqueo = pm.id_parqueo " +
                                         " WHERE r.id_piloto = p.id) AS ruta_asignada " +
                                         "FROM pilotos_catalogo p ORDER BY p.nombre ASC")) {
                                    boolean hayDatos = false;
                                    while (rs.next()) {
                                        hayDatos = true;
                                        String nombre = rs.getString("nombre");
                                        int edad = rs.getInt("edad");
                                        String identificador = rs.getString("identificador");
                                        String usr = rs.getString("usr");
                                        String rutaAsignada = rs.getString("ruta_asignada");
                    %>
                                        <tr>
                                            <td><span class="badge-id">🎫 <%= h(identificador) %></span></td>
                                            <td style="font-weight: 700; color: #0f172a;">👨‍✈️ <%= h(nombre) %></td>
                                            <td><%= edad > 0 ? edad + " años" : "N/A" %></td>
                                            <td><%= "Sin asignar".equals(usr) ? "<span style='color:#94a3b8;'>Sin cuenta</span>" : "👤 <b>" + h(usr) + "</b>" %></td>
                                            <td>
                                                <% if (rutaAsignada != null && !rutaAsignada.isEmpty()) { %>
                                                    <span class="badge-ruta">🗺️ <%= h(rutaAsignada) %></span>
                                                <% } else { %>
                                                    <span style="color:#94a3b8; font-size:13px;">En reserva / Sin ruta asignada</span>
                                                <% } %>
                                            </td>
                                        </tr>
                    <%
                                    }
                                    if (!hayDatos) {
                                        out.print("<tr><td colspan='5' style='text-align:center; padding:25px; color:#94a3b8;'>No hay pilotos registrados.</td></tr>");
                                    }
                                }
                            }
                        } catch (Exception e) {
                            out.print("<tr><td colspan='5'>Error: " + h(e.getMessage()) + "</td></tr>");
                        }
                    %>
                </tbody>
            </table>
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