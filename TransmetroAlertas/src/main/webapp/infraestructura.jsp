<%@page contentType="text/html" pageEncoding="UTF-8"%>
<%@page import="java.sql.*"%>
<%@page import="java.math.BigDecimal"%>
<%@page import="java.util.*"%>
<%!
    // Escapa texto antes de imprimirlo en HTML
    static String h(String s) {
        if (s == null) return "";
        return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace("\"", "&quot;").replace("'", "&#39;");
    }
%>
<%
    // Cualquier usuario con sesión (pasajero, piloto, admin) puede CONSULTAR. Solo el admin puede editar.
    if (session.getAttribute("usuarioValido") == null) { response.sendRedirect("login.jsp"); return; }
    String rolActual = (String) session.getAttribute("rol");
    if (rolActual == null) rolActual = "pasajero";
    boolean esAdmin = "admin".equals(rolActual);

    String dbUrl = "jdbc:mysql://192.168.15.135:3306/transmetro_db"; 
    String dbUser = "admin"; String dbPass = "admin123";

    Connection con = null;
    String errorBD = null;
    try {
        Class.forName("com.mysql.cj.jdbc.Driver");
        con = DriverManager.getConnection(dbUrl, dbUser, dbPass);
    } catch (Exception e) { errorBD = e.getMessage(); }

    // Totales para las tarjetas de resumen
    int totParqueos = 0, totGuardias = 0, totEstaciones = 0, totMunis = 0;
    BigDecimal totKm = BigDecimal.ZERO;
    if (con != null) {
        try (Statement st = con.createStatement()) {
            ResultSet r = st.executeQuery("SELECT (SELECT COUNT(*) FROM parqueos), (SELECT COUNT(*) FROM guardias_seguridad), (SELECT COUNT(*) FROM estaciones_fisicas), (SELECT COALESCE(SUM(distancia_km),0) FROM distancias_tramos), (SELECT COUNT(*) FROM municipalidades)");
            if (r.next()) { totParqueos = r.getInt(1); totGuardias = r.getInt(2); totEstaciones = r.getInt(3); totKm = r.getBigDecimal(4); totMunis = r.getInt(5); }
            r.close();
        } catch (Exception e) { errorBD = e.getMessage(); }
    }
%>

<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <title>Infraestructura y Seguridad - Transmetro</title>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;600;800&display=swap" rel="stylesheet">
    <style>
        body { font-family: 'Inter', sans-serif; background-color: #f8fafc; margin: 0; padding-top: 70px; }
        .header { background: #ffffff; padding: 15px 25px; position: fixed; top: 0; width: 100%; box-sizing: border-box; z-index: 1000; display: flex; justify-content: space-between; align-items: center; border-bottom: 1px solid #e2e8f0; }
        .header h1 { margin: 0; font-size: 18px; text-align: center; flex-grow: 1; font-weight: 700; color: #1e293b;}
        .menu-btn { background: none; border: none; font-size: 24px; cursor: pointer; color: #475569;}
        .overlay { display: none; position: fixed; width: 100%; height: 100%; top: 0; left: 0; background: rgba(15, 23, 42, 0.4); z-index: 999; }
        
        .main-container { max-width: 1000px; margin: 30px auto; padding: 0 20px;}
        .page-title { margin-bottom: 25px; display: flex; justify-content: space-between; align-items: flex-start; gap: 15px; flex-wrap: wrap;}
        .page-title h2 { margin: 0 0 5px 0; font-size: 26px; font-weight: 800; color: #0f172a;}
        .page-title p { margin: 0; color: #64748b;}
        .btn-editar-admin { background: #d35400; color: white; text-decoration: none; padding: 12px 18px; border-radius: 8px; font-weight: bold; font-size: 14px; transition: 0.2s; box-shadow: 0 4px 6px rgba(0,0,0,0.1); white-space: nowrap;}
        .btn-editar-admin:hover { background: #b34700; transform: translateY(-2px); }

        .resumen { display: grid; grid-template-columns: repeat(auto-fit, minmax(180px, 1fr)); gap: 15px; margin-bottom: 25px; }
        .stat { background: white; border-radius: 12px; padding: 18px; border: 1px solid #e2e8f0; text-align: center; }
        .stat .num { font-size: 28px; font-weight: 800; color: #1a2a6c; }
        .stat .lbl { font-size: 12px; color: #64748b; text-transform: uppercase; font-weight: 600; margin-top: 4px; }

        .grid-2col { display: grid; grid-template-columns: 1fr 1fr; gap: 20px; }
        @media (max-width: 800px) { .grid-2col { grid-template-columns: 1fr; } }
        .card { background: white; border-radius: 12px; padding: 25px; border: 1px solid #e2e8f0; box-shadow: 0 4px 6px rgba(0,0,0,0.02); overflow-x: auto;}
        .card h3 { margin: 0 0 20px 0; font-size: 18px; color: #1e293b; display: flex; align-items: center; gap: 8px;}
        .full { grid-column: 1 / -1; }
        
        table { width: 100%; border-collapse: collapse; margin-bottom: 5px; }
        th { background-color: #f1f5f9; padding: 12px; font-size: 12px; color: #64748b; text-transform: uppercase; text-align: left;}
        td { padding: 12px; font-size: 14px; border-bottom: 1px solid #e2e8f0; color: #334155;}
        
        .badge-guardia { background: #dcfce7; color: #166534; padding: 4px 8px; border-radius: 6px; font-size: 12px; font-weight: bold;}
        .badge-km { background: #e0f2fe; color: #0369a1; padding: 4px 8px; border-radius: 6px; font-size: 12px; font-weight: bold;}
        .badge-turno { background: #fef3c7; color: #92400e; padding: 3px 7px; border-radius: 6px; font-size: 11px; font-weight: bold;}
        .barra { background: #e2e8f0; border-radius: 10px; height: 8px; width: 100px; overflow: hidden; display: inline-block; vertical-align: middle; margin-right: 6px;}
        .barra > div { height: 100%; background: #11998e; }
        .barra.llena > div { background: #e74c3c; }
        
        .empty-state { text-align: center; padding: 25px; color: #94a3b8; font-size: 14px; font-style: italic; background: #f8fafc; border-radius: 8px;}
        .error-bd { background: #fee2e2; color: #991b1b; border: 1px solid #fca5a5; padding: 15px; border-radius: 8px; margin-bottom: 20px; font-weight: bold;}
    </style>
    <link rel="stylesheet" href="css/transmetro.css">
</head>
<body>
    <jsp:include page="menu_izquierdo.jsp" />
    <jsp:include page="menu_derecho.jsp" />
    <div id="overlay" class="overlay" onclick="closeAllMenus()"></div>

    <div class="header">
        <button class="menu-btn" onclick="toggleMenu('left')">☰</button>
        <h1>Infraestructura y Seguridad</h1>
        <% if (esAdmin) { %><button class="menu-btn" onclick="toggleMenu('right')">⚙️</button><% } else { %><div style="width: 24px;"></div><% } %>
    </div>

    <div class="main-container">
        <div class="page-title">
            <div>
                <h2>🏢 Infraestructura y Seguridad Logística</h2>
                <p>Parqueos, distancias entre estaciones, molinetes y personal de seguridad de la red.</p>
            </div>
            <% if (esAdmin) { %>
                <a href="admin_infra.jsp" class="btn-editar-admin">✏️ Editar Infraestructura</a>
            <% } %>
        </div>

        <% if (errorBD != null) { %><div class="error-bd">❌ Error de base de datos: <%= h(errorBD) %></div><% } %>

        <div class="resumen">
            <div class="stat"><div class="num"><%= totMunis %></div><div class="lbl">🏛️ Municipalidades</div></div>
            <div class="stat"><div class="num"><%= totParqueos %></div><div class="lbl">🅿️ Parqueos</div></div>
            <div class="stat"><div class="num"><%= totEstaciones %></div><div class="lbl">🚏 Estaciones físicas</div></div>
            <div class="stat"><div class="num"><%= totGuardias %></div><div class="lbl">👮 Guardias</div></div>
            <div class="stat"><div class="num"><%= totKm %></div><div class="lbl">📏 Km mapeados</div></div>
        </div>

        <div class="grid-2col">
            <!-- RF03 y RN05: Accesos y Guardias -->
            <div class="card">
                <h3>🛡️ Molinetes y Guardias</h3>
                <table>
                    <tr><th>Estación</th><th>Molinete</th><th>Guardia</th></tr>
                    <%
                        boolean hayG = false;
                        if (con != null) {
                            try (Statement st = con.createStatement()) {
                                ResultSet rs1 = st.executeQuery("SELECT e.nombre AS estacion, a.codigo_puerta, g.nombre_completo, g.turno " +
                                                   "FROM guardias_seguridad g " +
                                                   "JOIN accesos_molinetes a ON g.id_acceso = a.id_acceso " +
                                                   "JOIN estaciones_fisicas e ON a.id_estacion = e.id_estacion " +
                                                   "ORDER BY e.nombre, a.codigo_puerta");
                                while (rs1.next()) {
                                    hayG = true;
                    %>
                    <tr>
                        <td>🚏 <%= h(rs1.getString("estacion")) %></td>
                        <td>🚪 <%= h(rs1.getString("codigo_puerta")) %></td>
                        <td><span class="badge-guardia">👮 <%= h(rs1.getString("nombre_completo")) %></span> <span class="badge-turno"><%= h(rs1.getString("turno")) %></span></td>
                    </tr>
                    <%
                                }
                                rs1.close();
                            } catch (Exception e) { out.print("<tr><td colspan='3'>Error: " + h(e.getMessage()) + "</td></tr>"); }
                        }
                        if (!hayG) out.print("<tr><td colspan='3'><div class='empty-state'>No hay guardias ni accesos registrados.</div></td></tr>");
                    %>
                </table>
            </div>

            <!-- RF02: Distancias -->
            <div class="card">
                <h3>📏 Distancias por Tramo</h3>
                <table>
                    <tr><th>Ruta</th><th>Tramo</th><th>Distancia</th></tr>
                    <%
                        boolean hayD = false;
                        Map<String, BigDecimal> kmPorRuta = new LinkedHashMap<String, BigDecimal>();
                        if (con != null) {
                            try (Statement st = con.createStatement()) {
                                ResultSet rs2 = st.executeQuery("SELECT d.id_ruta, COALESCE(r.nombre_ruta, CONCAT('Ruta ', d.id_ruta)) AS ruta, d.estacion_origen, d.estacion_destino, d.distancia_km " +
                                                   "FROM distancias_tramos d LEFT JOIN rutas_operativas r ON d.id_ruta = r.id_ruta " +
                                                   "ORDER BY d.id_ruta, d.id_tramo");
                                while (rs2.next()) {
                                    hayD = true;
                                    String ruta = rs2.getString("ruta");
                                    BigDecimal km = rs2.getBigDecimal("distancia_km");
                                    BigDecimal previo = kmPorRuta.get(ruta);
                                    kmPorRuta.put(ruta, previo == null ? km : previo.add(km));
                    %>
                    <tr>
                        <td>🗺️ <%= h(ruta) %></td>
                        <td><%= h(rs2.getString("estacion_origen")) %> ➔ <%= h(rs2.getString("estacion_destino")) %></td>
                        <td><span class="badge-km"><%= km %> km</span></td>
                    </tr>
                    <%
                                }
                                rs2.close();
                            } catch (Exception e) { out.print("<tr><td colspan='3'>Error: " + h(e.getMessage()) + "</td></tr>"); }
                        }
                        if (!hayD) out.print("<tr><td colspan='3'><div class='empty-state'>Aún no se han mapeado las distancias de los tramos.</div></td></tr>");
                    %>
                </table>
                <% if (!kmPorRuta.isEmpty()) { %>
                    <div style="margin-top: 15px; padding-top: 12px; border-top: 2px dashed #e2e8f0;">
                        <strong style="font-size: 13px; color: #475569;">Total por ruta:</strong>
                        <% for (Map.Entry<String, BigDecimal> en : kmPorRuta.entrySet()) { %>
                            <div style="font-size: 13px; margin-top: 6px;">🗺️ <%= h(en.getKey()) %>: <span class="badge-km"><%= en.getValue() %> km</span></div>
                        <% } %>
                    </div>
                <% } %>
            </div>

            <!-- RN04: Parqueos -->
            <div class="card full">
                <h3>🅿️ Parqueos Oficiales</h3>
                <table>
                    <tr><th>ID</th><th>Parqueo</th><th>Ocupación</th><th>Disponibles</th></tr>
                    <%
                        boolean hayP = false;
                        if (con != null) {
                            try (Statement st = con.createStatement()) {
                                ResultSet rs3 = st.executeQuery("SELECT p.id_parqueo, p.nombre, p.capacidad_buses, COUNT(f.id_vehiculo) AS ocupados " +
                                                   "FROM parqueos p LEFT JOIN flota_vehiculos f ON f.id_parqueo = p.id_parqueo " +
                                                   "GROUP BY p.id_parqueo, p.nombre, p.capacidad_buses ORDER BY p.id_parqueo");
                                while (rs3.next()) {
                                    hayP = true;
                                    int cap = rs3.getInt("capacidad_buses");
                                    int ocu = rs3.getInt("ocupados");
                                    int pct = cap > 0 ? Math.min(100, ocu * 100 / cap) : 100;
                    %>
                    <tr>
                        <td># <%= rs3.getInt("id_parqueo") %></td>
                        <td><%= h(rs3.getString("nombre")) %></td>
                        <td><span class="barra <%= ocu >= cap ? "llena" : "" %>"><div style="width: <%= pct %>%;"></div></span> 🚍 <%= ocu %> / <%= cap %></td>
                        <td><%= Math.max(0, cap - ocu) %> espacios</td>
                    </tr>
                    <%
                                }
                                rs3.close();
                            } catch (Exception e) { out.print("<tr><td colspan='4'>Error: " + h(e.getMessage()) + "</td></tr>"); }
                        }
                        if (!hayP) out.print("<tr><td colspan='4'><div class='empty-state'>No hay parqueos registrados.</div></td></tr>");
                    %>
                </table>
            </div>

            <!-- Estaciones físicas -->
            <div class="card full">
                <h3>🚏 Estaciones Físicas</h3>
                <table>
                    <tr><th>ID</th><th>Estación</th><th>Molinetes</th><th>Ubicación (lat, lon)</th></tr>
                    <%
                        boolean hayE = false;
                        if (con != null) {
                            try (Statement st = con.createStatement()) {
                                ResultSet rs4 = st.executeQuery("SELECT e.id_estacion, e.nombre, e.latitud, e.longitud, COUNT(a.id_acceso) AS molinetes " +
                                                   "FROM estaciones_fisicas e LEFT JOIN accesos_molinetes a ON a.id_estacion = e.id_estacion " +
                                                   "GROUP BY e.id_estacion, e.nombre, e.latitud, e.longitud ORDER BY e.nombre");
                                while (rs4.next()) {
                                    hayE = true;
                                    String lat = rs4.getString("latitud"); String lon = rs4.getString("longitud");
                    %>
                    <tr>
                        <td># <%= rs4.getInt("id_estacion") %></td>
                        <td><%= h(rs4.getString("nombre")) %></td>
                        <td>🚪 <%= rs4.getInt("molinetes") %></td>
                        <td><%= (lat != null && lon != null) ? h(lat) + ", " + h(lon) : "<span style='color:#94a3b8;'>Sin coordenadas</span>" %></td>
                    </tr>
                    <%
                                }
                                rs4.close();
                            } catch (Exception e) { out.print("<tr><td colspan='4'>Error: " + h(e.getMessage()) + "</td></tr>"); }
                        }
                        if (!hayE) out.print("<tr><td colspan='4'><div class='empty-state'>No hay estaciones físicas registradas.</div></td></tr>");
                    %>
                </table>
            </div>

            <!-- Municipalidades Registradas -->
            <div class="card full" id="municipalidades">
                <h3>🏛️ Municipalidades y Jurisdicciones Registradas</h3>
                <table>
                    <tr><th>ID</th><th>Municipalidad</th><th>Buses Asignados</th><th>Capacidad Total</th><th>Unidades / Estado</th></tr>
                    <%
                        boolean hayM = false;
                        if (con != null) {
                            try (Statement st = con.createStatement()) {
                                ResultSet rsM = st.executeQuery(
                                    "SELECT m.id, m.nombre, COUNT(f.id_vehiculo) AS total_buses, COALESCE(SUM(f.capacidad), 0) AS cap_total, " +
                                    "GROUP_CONCAT(CONCAT(f.placa, ' (', COALESCE(f.estado, 'Operativo'), ')') ORDER BY f.placa SEPARATOR ', ') AS placas " +
                                    "FROM municipalidades m " +
                                    "LEFT JOIN flota_vehiculos f ON f.municipalidad = m.nombre " +
                                    "GROUP BY m.id, m.nombre ORDER BY m.nombre"
                                );
                                while (rsM.next()) {
                                    hayM = true;
                                    int idM = rsM.getInt("id");
                                    String nomM = rsM.getString("nombre");
                                    int tBuses = rsM.getInt("total_buses");
                                    int capT = rsM.getInt("cap_total");
                                    String placasM = rsM.getString("placas");
                    %>
                    <tr>
                        <td># <%= idM %></td>
                        <td><strong>🏛️ <%= h(nomM) %></strong></td>
                        <td><span class="badge-km">🚍 <%= tBuses %> unidad<%= tBuses == 1 ? "" : "es" %></span></td>
                        <td>💺 <%= capT %> asientos</td>
                        <td>
                            <% if (placasM != null && !placasM.isEmpty()) { %>
                                <span style="font-size:12px; color:#334155;"><%= h(placasM) %></span>
                            <% } else { %>
                                <span class="badge-turno">🆕 Recién agregada al catálogo (sin buses asignados aún)</span>
                            <% } %>
                        </td>
                    </tr>
                    <%
                                }
                                rsM.close();
                            } catch (Exception e) { out.print("<tr><td colspan='5'>Error: " + h(e.getMessage()) + "</td></tr>"); }
                        }
                        if (!hayM) out.print("<tr><td colspan='5'><div class='empty-state'>No hay municipalidades registradas en el catálogo.</div></td></tr>");
                        if (con != null) { try { con.close(); } catch (Exception e) {} }
                    %>
                </table>
            </div>
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