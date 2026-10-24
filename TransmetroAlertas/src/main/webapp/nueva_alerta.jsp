<%@page contentType="text/html" pageEncoding="UTF-8"%>
<%@page import="java.sql.*"%>
<%
    String rolActual = (String) session.getAttribute("rol");
    String usuarioActual = (String) session.getAttribute("nombre");
    if (session.getAttribute("usuarioValido") == null || "pasajero".equals(rolActual)) {
        response.sendRedirect("index.jsp"); return; 
    }
    
    String dbUrl = "jdbc:mysql://192.168.15.135:3306/transmetro_db"; 
    String dbUser = "admin"; String dbPass = "admin123";
    
    if ("POST".equalsIgnoreCase(request.getMethod())) {
        try {
            Class.forName("com.mysql.cj.jdbc.Driver");
            Connection con = DriverManager.getConnection(dbUrl, dbUser, dbPass);
            
            String tipo = request.getParameter("tipo_gravedad");
            String desc = request.getParameter("descripcion");
            String audiencia = request.getParameter("audiencia");
            
            // SEPARAMOS EL VALOR (Ejemplo: "12|U-100 - Ruta A")
            String busRutaValue = request.getParameter("bus_ruta");
            int idVehiculo = 0;
            String busRutaTexto = "";
            
            if (busRutaValue != null && busRutaValue.contains("|")) {
                String[] partes = busRutaValue.split("\\|");
                idVehiculo = Integer.parseInt(partes[0]);
                busRutaTexto = partes[1];
            } else {
                busRutaTexto = busRutaValue; // Fallback por si acaso
            }
            
            try (Statement stCol = con.createStatement()) {
                stCol.executeUpdate("ALTER TABLE alertas ADD COLUMN id_vehiculo INT DEFAULT NULL");
            } catch (SQLException ig) {}
            
            // INSERTAMOS CON LA NUEVA COLUMNA id_vehiculo
            PreparedStatement ps = con.prepareStatement(
                "INSERT INTO alertas (tipo_gravedad, bus_ruta, id_vehiculo, descripcion, reportado_por, estado, audiencia) " +
                "VALUES (?, ?, ?, ?, ?, 'Activa', ?)"
            );
            ps.setString(1, tipo); 
            ps.setString(2, busRutaTexto); 
            if (idVehiculo > 0) ps.setInt(3, idVehiculo); else ps.setNull(3, Types.INTEGER);
            ps.setString(4, desc); 
            ps.setString(5, usuarioActual); 
            ps.setString(6, audiencia);
            
            ps.executeUpdate(); ps.close(); con.close();
            
            response.sendRedirect("alertas.jsp"); return;
        } catch(Exception e) { out.print("Error: " + e.getMessage()); }
    }
%>

<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <title>Emitir Alerta - Transmetro</title>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&display=swap" rel="stylesheet">
    <style>
        body { font-family: 'Inter', sans-serif; background-color: #f0f2f5; margin: 0; padding-top: 70px; }
        .header { background: #ffffff; padding: 15px 25px; position: fixed; top: 0; width: 100%; box-sizing: border-box; z-index: 1000; display: flex; justify-content: space-between; align-items: center; border-bottom: 1px solid #e2e8f0; }
        .header h1 { margin: 0; font-size: 18px; text-align: center; flex-grow: 1; font-weight: 700;}
        .menu-btn { background: none; border: none; font-size: 24px; cursor: pointer; }
        .overlay { display: none; position: fixed; width: 100%; height: 100%; top: 0; left: 0; background: rgba(15, 23, 42, 0.4); z-index: 999; }
        .main-container { max-width: 600px; margin: 30px auto; padding: 0 20px; }
        .btn-volver { display: inline-block; margin-bottom: 20px; color: #64748b; text-decoration: none; font-weight: 600; font-size: 14px;}
        .report-card { background: #ffffff; border-radius: 12px; padding: 30px; border-top: 5px solid #3b82f6; box-shadow: 0 4px 15px rgba(0,0,0,0.05);}
        .report-card h2 { margin-top: 0; font-size: 22px; font-weight: 800;}
        .form-group { margin-bottom: 20px; }
        .form-group label { display: block; font-size: 13px; font-weight: 700; color: #334155; margin-bottom: 6px;}
        .form-group select, .form-group textarea { width: 100%; padding: 12px; border: 1px solid #cbd5e1; border-radius: 8px; font-size: 14px; box-sizing: border-box;}
        .form-group textarea { resize: vertical; min-height: 120px;}
        .btn-submit { background: #3b82f6; color: white; border: none; padding: 14px; border-radius: 8px; font-weight: bold; cursor: pointer; width: 100%; font-size: 16px;}
        .destacado { background: #e0f2fe; padding: 15px; border-radius: 8px; border: 1px solid #bae6fd; margin-bottom: 20px;}
    </style>
    <link rel="stylesheet" href="css/transmetro.css">
</head>
<body>
    <jsp:include page="menu_izquierdo.jsp" />
    <jsp:include page="menu_derecho.jsp" />
    <div id="overlay" class="overlay" onclick="closeAllMenus()"></div>
    <div class="header">
        <button class="menu-btn" onclick="toggleMenu('left')">☰</button>
        <h1>Emisión de Alertas</h1>
        <button class="menu-btn" onclick="toggleMenu('right')">⚙️</button>
    </div>

    <div class="main-container">
        <a href="alertas.jsp" class="btn-volver">← Volver al Centro de Monitoreo</a>
        <div class="report-card">
            <h2>📢 Emitir Nueva Alerta</h2>
            
            <form method="POST" action="nueva_alerta.jsp">
                <div class="destacado">
                    <div class="form-group" style="margin-bottom: 0;">
                        <label style="color: #0369a1;">👁️ Nivel de Visibilidad</label>
                        <select name="audiencia" required style="border-color: #38bdf8; font-weight: bold;">
                            <option value="interna">🔒 INTERNA: Solo para Pilotos y Administradores</option>
                            <option value="publica">📢 PÚBLICA: Notificar a todos los Pasajeros</option>
                        </select>
                    </div>
                </div>

                <div class="form-group">
                    <label>Tipo de Incidencia / Gravedad</label>
                    <select name="tipo_gravedad" required>
                        <option value="Emergencia">🔴 EMERGENCIA (Accidente / Seguridad)</option>
                        <option value="Trafico">🟠 RETRASO (Tráfico Pesado / Bloqueos)</option>
                        <option value="Mecanica">🔵 MECÁNICA (Falla de Unidad)</option>
                        <option value="Logistica">🟣 LOGÍSTICA (Bus Lleno / Solicita Apoyo)</option>
                    </select>
                </div>
                
                <div class="form-group">
                    <label>Unidad y Ruta Afectada</label>
                    <select name="bus_ruta" required>
                        <option value="">-- Seleccione una unidad de la flota --</option>
                        <%
                            try {
                                Connection conBus = DriverManager.getConnection(dbUrl, dbUser, dbPass);
                                Statement stBus = conBus.createStatement();
                                // Traemos el ID también para ponerlo en el value
                                String query = "SELECT f.id_vehiculo, r.nombre_ruta, f.placa " +
                                               "FROM rutas_operativas r " +
                                               "JOIN flota_vehiculos f ON (r.id_vehiculo_main = f.id_vehiculo OR r.id_vehiculo_backup = f.id_vehiculo OR r.id_vehiculo_extra = f.id_vehiculo) " +
                                               "ORDER BY r.nombre_ruta ASC";
                                ResultSet rsBus = stBus.executeQuery(query);
                                while(rsBus.next()) {
                                    int idVeh = rsBus.getInt("id_vehiculo");
                                    String ruta = rsBus.getString("nombre_ruta");
                                    String placa = rsBus.getString("placa");
                                    String n = (placa != null ? placa : "Sin Placa") + " - " + ruta;
                                    // VALUE: "ID|Texto"
                                    out.print("<option value='" + idVeh + "|" + n + "'>🚍 " + n + "</option>");
                                }
                                rsBus.close(); stBus.close(); conBus.close();
                            } catch(Exception e) {}
                        %>
                    </select>
                </div>
                
                <div class="form-group">
                    <label>Descripción de la Incidencia</label>
                    <textarea name="descripcion" placeholder="Explique la situación..." required></textarea>
                </div>
                
                <button type="submit" class="btn-submit">🚀 Transmitir Alerta</button>
            </form>
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