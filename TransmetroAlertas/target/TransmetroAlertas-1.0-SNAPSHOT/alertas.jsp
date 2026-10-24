<%@page contentType="text/html" pageEncoding="UTF-8"%>
<%@page import="java.sql.*"%>
<%
    // Seguridad: Solo Pilotos y Admins
    String rolActual = (String) session.getAttribute("rol");
    if (session.getAttribute("usuarioValido") == null || "pasajero".equals(rolActual)) {
        response.sendRedirect("index.jsp"); return; 
    }
    
    String dbUrl = "jdbc:mysql://192.168.15.135:3306/transmetro_db"; 
    String dbUser = "admin"; String dbPass = "admin123";
    
    // PROCESAMIENTO DE ACCIONES EN ALERTAS
    if ("POST".equalsIgnoreCase(request.getMethod())) {
        String accion = request.getParameter("accion");
        
        if ("resolver".equals(accion)) {
            try {
                Class.forName("com.mysql.cj.jdbc.Driver");
                Connection con = DriverManager.getConnection(dbUrl, dbUser, dbPass);
                int idAlerta = Integer.parseInt(request.getParameter("id_alerta"));
                PreparedStatement ps = con.prepareStatement("UPDATE alertas SET estado = 'Resuelta' WHERE id = ?");
                ps.setInt(1, idAlerta); ps.executeUpdate(); ps.close(); con.close();
                response.sendRedirect("alertas.jsp"); return;
            } catch(Exception e) {}
            
        } else if ("avisar_pasajeros".equals(accion)) {
            try {
                Class.forName("com.mysql.cj.jdbc.Driver");
                Connection con = DriverManager.getConnection(dbUrl, dbUser, dbPass);
                int idAlerta = Integer.parseInt(request.getParameter("id_alerta"));
                String rutaAfectada = request.getParameter("ruta");
                
                String descPublica = "⚠️ ATENCIÓN: Todas las unidades de esta ruta (incluyendo refuerzos de emergencia) se encuentran operando a su máxima capacidad (100%). Por favor, planifique su viaje y espere hasta el siguiente horario disponible.";
                
                PreparedStatement ps1 = con.prepareStatement("INSERT INTO alertas (tipo_gravedad, bus_ruta, descripcion, reportado_por, estado, audiencia) VALUES ('Logistica', ?, ?, 'Control Central', 'Activa', 'publica')");
                ps1.setString(1, rutaAfectada); ps1.setString(2, descPublica);
                ps1.executeUpdate(); ps1.close();
                
                PreparedStatement ps2 = con.prepareStatement("UPDATE alertas SET estado = 'Resuelta' WHERE id = ?");
                ps2.setInt(1, idAlerta); ps2.executeUpdate(); ps2.close();
                
                con.close();
                response.sendRedirect("alertas.jsp"); return;
            } catch(Exception e) {}
        }
    }
%>

<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <title>Centro de Alertas - Transmetro</title>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&display=swap" rel="stylesheet">
    <style>
        body { font-family: 'Inter', sans-serif; background-color: #f0f2f5; margin: 0; padding-top: 70px; }
        .header { background: #ffffff; color: #1e293b; padding: 15px 25px; position: fixed; top: 0; width: 100%; box-sizing: border-box; z-index: 1000; display: flex; justify-content: space-between; align-items: center; border-bottom: 1px solid #e2e8f0;}
        .header h1 { margin: 0; font-size: 18px; text-align: center; flex-grow: 1; font-weight: 700;}
        .menu-btn { background: none; border: none; color: #475569; font-size: 24px; cursor: pointer;}
        .overlay { display: none; position: fixed; width: 100%; height: 100%; top: 0; left: 0; background: rgba(15, 23, 42, 0.4); z-index: 999; }
        
        .main-container { max-width: 1000px; margin: 20px auto; padding: 0 20px; padding-bottom: 50px;}
        .top-panel { display: flex; justify-content: space-between; align-items: center; margin-bottom: 25px; background: white; padding: 20px; border-radius: 12px; border: 1px solid #e2e8f0; box-shadow: 0 4px 6px rgba(0,0,0,0.05);}
        .page-title h2 { margin: 0 0 5px 0; font-size: 24px; font-weight: 800; color: #0f172a;}
        .page-title p { margin: 0; color: #64748b; font-size: 14px; }
        .btn-crear-alerta { background: #3b82f6; color: white; padding: 15px 25px; border-radius: 8px; font-weight: bold; text-decoration: none; display: flex; align-items: center; transition: 0.2s;}
        .btn-crear-alerta:hover { background: #2563eb; transform: translateY(-2px);}
        
        .alerts-feed { display: flex; flex-direction: column; gap: 15px; }
        .alerta-item { background: white; border-radius: 10px; padding: 20px; position: relative; border-left: 6px solid #ccc; display: flex; flex-direction: column; gap: 10px; box-shadow: 0 4px 6px rgba(0,0,0,0.05);}
        
        .alerta-emergencia { border-left-color: #ef4444; background: #fef2f2; animation: pulsoRojo 2s infinite;}
        .alerta-trafico { border-left-color: #f59e0b; background: #fffbeb;}
        .alerta-mecanica { border-left-color: #3b82f6; background: #eff6ff;}
        .alerta-logistica { border-left-color: #8b5cf6; background: #f5f3ff;}
        @keyframes pulsoRojo { 0% { box-shadow: 0 0 0 0 rgba(239, 68, 68, 0.4); } 70% { box-shadow: 0 0 0 10px rgba(239, 68, 68, 0); } 100% { box-shadow: 0 0 0 0 rgba(239, 68, 68, 0); } }
        
        .alerta-header { display: flex; justify-content: space-between; align-items: center; border-bottom: 1px solid rgba(0,0,0,0.05); padding-bottom: 10px;}
        .alerta-tipo { font-weight: 800; font-size: 16px; display: flex; align-items: center; gap: 5px;}
        .alerta-emergencia .alerta-tipo { color: #b91c1c; }
        .alerta-trafico .alerta-tipo { color: #b45309; }
        .alerta-mecanica .alerta-tipo { color: #1d4ed8; }
        .alerta-logistica .alerta-tipo { color: #6d28d9; }
        
        .alerta-ruta { font-size: 14px; font-weight: 700; color: #334155;}
        .alerta-desc { font-size: 14px; color: #475569; margin-top: 5px; line-height: 1.5;}
        .alerta-footer { display: flex; justify-content: space-between; align-items: center; margin-top: 5px;}
        
        .btn-resolver { background: #10b981; color: white; border: none; padding: 8px 15px; border-radius: 6px; font-weight: bold; cursor: pointer; font-size: 12px; transition: 0.2s;}
        .btn-resolver:hover { background: #059669; }
        .btn-emergencia { background: #dc2626; color: white; border: none; padding: 8px 15px; border-radius: 6px; font-weight: bold; cursor: pointer; font-size: 12px; text-decoration: none; animation: pulsoBoton 1s infinite;}
        .btn-aviso { background: #f59e0b; color: white; border: none; padding: 8px 15px; border-radius: 6px; font-weight: bold; cursor: pointer; font-size: 12px; transition: 0.2s; box-shadow: 0 4px 6px rgba(245, 158, 11, 0.3);}
        .btn-aviso:hover { background: #d97706; transform: scale(1.05);}
        @keyframes pulsoBoton { 0% { transform: scale(1); } 50% { transform: scale(1.05); background: #b91c1c;} 100% { transform: scale(1); } }
        
        .badge-mantenimiento { background: #ffedd5; color: #c2410c; padding: 6px 10px; border-radius: 6px; display: inline-block; font-size: 12px; font-weight: bold; margin-bottom: 5px; margin-top: 5px; border: 1px solid #fdba74; animation: parpadeo 1.5s infinite;}
        @keyframes parpadeo { 0% { opacity: 1; } 50% { opacity: 0.6; } 100% { opacity: 1; } }
        
        .empty-state { text-align: center; padding: 50px; background: white; border-radius: 12px; border: 1px dashed #cbd5e1; color: #94a3b8; font-weight: 600;}
        
        /* Indicador de Refresh */
        .refresh-indicator { text-align: center; font-size: 12px; color: #94a3b8; margin-top: 20px; font-weight: 600; }
        .refresh-dot { display: inline-block; width: 8px; height: 8px; background: #2ecc71; border-radius: 50%; margin-right: 5px; animation: blink 1s infinite;}
        @keyframes blink { 0% {opacity: 1;} 50% {opacity: 0.3;} 100% {opacity: 1;} }
    </style>
    <link rel="stylesheet" href="css/transmetro.css">
</head>
<body>
    <jsp:include page="menu_izquierdo.jsp" />
    <jsp:include page="menu_derecho.jsp" />
    <div id="overlay" class="overlay" onclick="closeAllMenus()"></div>

    <div class="header">
        <button class="menu-btn" onclick="toggleMenu('left')">☰</button>
        <h1>Monitoreo y Alertas en Vivo</h1>
        <% if ("admin".equals(rolActual)) { %><button class="menu-btn" onclick="toggleMenu('right')">⚙️</button><% } else { %><div style="width: 34px;"></div><% } %>
    </div>

    <div class="main-container">
        <div class="top-panel">
            <div class="page-title">
                <h2>🚨 Centro de Control de Alertas</h2>
                <p>Reporte de incidencias en tiempo real de Transmetro.</p>
            </div>
            <a href="nueva_alerta.jsp" class="btn-crear-alerta">📢 Emitir Nueva Alerta</a>
        </div>

        <div class="alerts-feed">
            <%
                try {
                    Class.forName("com.mysql.cj.jdbc.Driver");
                    Connection con = DriverManager.getConnection(dbUrl, dbUser, dbPass);
                    Statement st = con.createStatement();
                    
                    // Consulta básica y universal
                    ResultSet rs = st.executeQuery("SELECT id, tipo_gravedad, bus_ruta, descripcion, reportado_por, DATE_FORMAT(fecha_hora, '%d/%m/%Y %H:%i') as fecha, audiencia FROM alertas WHERE estado = 'Activa' ORDER BY fecha_hora DESC");
                    
                    boolean hayAlertas = false;
                    while(rs.next()) {
                        hayAlertas = true;
                        int id = rs.getInt("id");
                        String tipo = rs.getString("tipo_gravedad");
                        String rutaCompleta = rs.getString("bus_ruta"); // Ej: "U-100 - Ruta Norte"
                        String desc = rs.getString("descripcion");
                        String autor = rs.getString("reportado_por");
                        String fecha = rs.getString("fecha");
                        String audiencia = rs.getString("audiencia");
                        
                        String claseTipo = "alerta-mecanica"; String icono = "🔵";
                        if(tipo.equals("Emergencia")) { claseTipo = "alerta-emergencia"; icono = "🚨"; }
                        else if(tipo.equals("Trafico")) { claseTipo = "alerta-trafico"; icono = "⚠️"; }
                        else if(tipo.equals("Logistica")) { claseTipo = "alerta-logistica"; icono = "🚍"; }
                        
                        // ---------------------------------------------------------
                        // VERIFICACIÓN LOGÍSTICA (TEXTUAL Y UNIVERSAL)
                        // ---------------------------------------------------------
                        boolean busNecesitaMantenimiento = false;
                        String nombreFiltro = rutaCompleta;

                        if (rutaCompleta != null && rutaCompleta.contains("|")) {
                             nombreFiltro = rutaCompleta.substring(rutaCompleta.indexOf("|") + 1);
                             rutaCompleta = nombreFiltro; 
                        }
                        
                        if (("Mecanica".equals(tipo) || "Emergencia".equals(tipo)) && nombreFiltro != null && !nombreFiltro.isEmpty()) {
                            
                            String placaExtraida = nombreFiltro;
                            if (nombreFiltro.contains(" - ")) {
                                placaExtraida = nombreFiltro.substring(0, nombreFiltro.indexOf(" - ")).trim();
                            }
                            
                            String qVal = "SELECT 1 FROM flota_vehiculos f " +
                                          "LEFT JOIN rutas_operativas r ON (r.id_vehiculo_main = f.id_vehiculo OR r.id_vehiculo_backup = f.id_vehiculo OR r.id_vehiculo_extra = f.id_vehiculo) " +
                                          "WHERE f.placa = ? AND f.estado != 'Mantenimiento' AND r.id_ruta IS NOT NULL";
                            
                            PreparedStatement psVer = con.prepareStatement(qVal);
                            psVer.setString(1, placaExtraida);
                            ResultSet rsVer = psVer.executeQuery();
                            
                            if(rsVer.next()) {
                                busNecesitaMantenimiento = true; 
                            }
                            rsVer.close(); psVer.close();
                        }
            %>
                        <div class="alerta-item <%= claseTipo %>">
                            <div class="alerta-header">
                                <div class="alerta-tipo"><%= icono %> <%= tipo.toUpperCase() %></div>
                                <div style="font-size: 12px; color: #64748b; font-weight: 600;">🕒 <%= fecha %></div>
                            </div>
                            
                            <div class="alerta-ruta">📍 Unidad/Ruta Afectada: <%= rutaCompleta %></div>
                            
                            <div>
                                <% if("publica".equals(audiencia)) { %>
                                    <span style="background: #dcfce7; color: #166534; padding: 4px 8px; border-radius: 4px; display: inline-block; font-size: 11px; font-weight: bold; margin-bottom: 5px; margin-top: 5px;">📢 Visible para Pasajeros</span>
                                <% } else { %>
                                    <span style="background: #f1f5f9; color: #475569; padding: 4px 8px; border-radius: 4px; display: inline-block; font-size: 11px; font-weight: bold; margin-bottom: 5px; margin-top: 5px;">🔒 Interna (Staff Oculto)</span>
                                <% } %>
                                
                                <% if(busNecesitaMantenimiento) { %>
                                    <br><span class="badge-mantenimiento">⚙️ Acción requerida: El bus debe ser retirado en <b>Gestión de Rutas</b> y pasado a <b>Mantenimiento</b> en Flota.</span>
                                <% } %>
                            </div>

                            <div class="alerta-desc"><%= desc %></div>
                            
                            <div class="alerta-footer">
                                <div style="font-size: 12px; color: #64748b; font-weight: 600;">Reportado por: <b>👤 <%= autor %></b></div>
                                <div style="display: flex; gap: 10px;">
                                    
                                    <% if(desc != null && desc.contains("La ruta completa (Principal + Refuerzo) se ha llenado")) { %>
                                        <a href="asignar_extra.jsp?id_alerta=<%= id %>&ruta=<%= java.net.URLEncoder.encode(rutaCompleta, "UTF-8") %>" class="btn-emergencia">🚑 Despachar Bus Extra</a>
                                    <% } %>

                                    <% if(desc != null && desc.contains("COLAPSO TOTAL")) { %>
                                        <form method="POST" style="margin:0;" onsubmit="return confirm('¿Deseas emitir un comunicado oficial a los pasajeros y cerrar esta alerta de crisis?');">
                                            <input type="hidden" name="accion" value="avisar_pasajeros">
                                            <input type="hidden" name="id_alerta" value="<%= id %>">
                                            <input type="hidden" name="ruta" value="<%= rutaCompleta %>">
                                            <button type="submit" class="btn-aviso">📢 Avisar a Pasajeros</button>
                                        </form>
                                    <% } %>
                                    
                                    <form method="POST" style="margin:0;" onsubmit="return confirm('¿Marcar esta alerta como resuelta?');">
                                        <input type="hidden" name="accion" value="resolver">
                                        <input type="hidden" name="id_alerta" value="<%= id %>">
                                        <button type="submit" class="btn-resolver">✅ Marcar Resuelta</button>
                                    </form>
                                </div>
                            </div>
                        </div>
            <%
                    }
                    if(!hayAlertas) out.print("<div class='empty-state'>✅ No hay alertas activas en este momento.</div>");
                    rs.close(); st.close(); con.close();
                } catch(Exception e) { out.print("Error: " + e.getMessage()); }
            %>
        </div>
        
        <div class="refresh-indicator">
            <span class="refresh-dot"></span> Sincronizado en tiempo real (Auto-Refresh 10s)
        </div>
    </div>
    
    <script>
        let menuAbierto = false;
        function toggleMenu(side) {
            let left = document.getElementById("leftSidebar"); let right = document.getElementById("rightSidebar"); let over = document.getElementById("overlay");
            if (side === 'left') { left.style.width = "250px"; if(right) right.style.width = "0"; } 
            else if (side === 'right') { if(right) right.style.width = "300px"; left.style.width = "0"; }
            over.style.display = "block"; menuAbierto = true;
        }
        function closeAllMenus() {
            document.getElementById("leftSidebar").style.width = "0"; let right = document.getElementById("rightSidebar"); if(right) right.style.width = "0";
            document.getElementById("overlay").style.display = "none"; menuAbierto = false;
        }
        
        // AUTO REFRESH DE 10 SEGUNDOS 
        setInterval(() => { 
            if(!menuAbierto) {
                window.location.reload(); 
            }
        }, 10000); 
    </script>
</body>
</html>