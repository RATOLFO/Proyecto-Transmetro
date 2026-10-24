<%@page contentType="text/html" pageEncoding="UTF-8"%>
<%@page import="java.sql.*"%>
<%@page import="java.util.ArrayList"%>
<%@page import="java.util.List"%>
<%
    if (session.getAttribute("usuarioValido") == null) { response.sendRedirect("login.jsp"); return; }
    
    String rolActual = (String) session.getAttribute("rol");
    if (rolActual == null) rolActual = "pasajero";
    boolean isPasajero = rolActual.equals("pasajero");

    String dbUrl = "jdbc:mysql://192.168.15.135:3306/transmetro_db"; 
    String dbUser = "admin"; String dbPass = "admin123";

    // LÓGICA DE "MARCAR COMO LEÍDO": Usamos la memoria de sesión para no borrar la alerta global
    List<Integer> alertasOcultas = (List<Integer>) session.getAttribute("alertasOcultas");
    if (alertasOcultas == null) {
        alertasOcultas = new ArrayList<>();
    }
    
    if ("POST".equalsIgnoreCase(request.getMethod()) && "ocultar".equals(request.getParameter("accion"))) {
        try {
            int idOcultar = Integer.parseInt(request.getParameter("id_alerta"));
            if (!alertasOcultas.contains(idOcultar)) {
                alertasOcultas.add(idOcultar);
                session.setAttribute("alertasOcultas", alertasOcultas); // Actualizamos la memoria
            }
            response.sendRedirect("notificaciones.jsp");
            return;
        } catch (Exception e) {}
    }
%>

<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <title>Notificaciones - Transmetro</title>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;600;700;800&display=swap" rel="stylesheet">
    <style>
        body { font-family: 'Inter', sans-serif; background-color: #f8fafc; margin: 0; padding-top: 70px; }
        .header { background: #ffffff; padding: 15px 25px; position: fixed; top: 0; width: 100%; box-sizing: border-box; z-index: 1000; display: flex; justify-content: space-between; align-items: center; border-bottom: 1px solid #e2e8f0; }
        .header h1 { margin: 0; font-size: 18px; text-align: center; flex-grow: 1; font-weight: 700;}
        .menu-btn { background: none; border: none; font-size: 24px; cursor: pointer; }
        .overlay { display: none; position: fixed; width: 100%; height: 100%; top: 0; left: 0; background: rgba(15, 23, 42, 0.4); z-index: 999; }
        
        .main-container { max-width: 800px; margin: 20px auto; padding: 0 20px;}
        .page-header { text-align: center; margin-bottom: 30px; }
        .page-header h2 { margin: 0; font-size: 26px; color: #0f172a; font-weight: 800;}
        .page-header p { margin: 5px 0 0 0; color: #64748b;}

        .feed { display: flex; flex-direction: column; gap: 15px; }
        .notificacion { background: white; border-radius: 12px; padding: 20px; box-shadow: 0 4px 6px rgba(0,0,0,0.02); border-left: 5px solid #ccc; position: relative;}
        
        .noti-emergencia { border-left-color: #ef4444; } .noti-emergencia h3 { color: #b91c1c; }
        .noti-trafico { border-left-color: #f59e0b; } .noti-trafico h3 { color: #b45309; }
        .noti-mecanica { border-left-color: #3b82f6; } .noti-mecanica h3 { color: #1d4ed8; }
        .noti-logistica { border-left-color: #8b5cf6; } .noti-logistica h3 { color: #6d28d9; }

        .notificacion h3 { margin: 0 0 10px 0; font-size: 16px; display: flex; align-items: center; gap: 8px;}
        .notificacion .fecha { font-size: 12px; color: #94a3b8; font-weight: 600; float: right; margin-top: 3px; margin-right: 25px;}
        .notificacion p { margin: 0; font-size: 15px; color: #475569; line-height: 1.5; margin-bottom: 10px; padding-right: 20px;}
        .notificacion .ruta { display: inline-block; background: #f1f5f9; padding: 5px 10px; border-radius: 6px; font-size: 13px; font-weight: 700; color: #334155;}
        
        .badge-interna { position: absolute; bottom: 20px; right: 20px; background: #e2e8f0; color: #475569; padding: 4px 8px; border-radius: 4px; font-size: 11px; font-weight: bold;}
        
        /* Botón de ocultar/leer */
        .btn-dismiss { position: absolute; top: 18px; right: 15px; background: none; border: none; font-size: 18px; color: #94a3b8; cursor: pointer; transition: 0.2s; padding: 0;}
        .btn-dismiss:hover { color: #ef4444; transform: scale(1.2); }
        
        .empty-state { text-align: center; padding: 50px; background: white; border-radius: 12px; color: #94a3b8; font-weight: 600;}
        
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
        <h1>Notificaciones</h1>
        <% if ("admin".equals(rolActual)) { %><button class="menu-btn" onclick="toggleMenu('right')">⚙️</button><% } else { %><div style="width: 24px;"></div><% } %>
    </div>

    <div class="main-container">
        <div class="page-header">
            <h2>🔔 Avisos a Pasajeros</h2>
            <p>Manténgase informado sobre el estado del servicio.</p>
        </div>

        <div class="feed">
            <%
                try {
                    Connection con = DriverManager.getConnection(dbUrl, dbUser, dbPass);
                    Statement st = con.createStatement();
                    
                    // Aseguramos pedir el "id" en el SELECT
                    String query = isPasajero ? 
                        "SELECT id, tipo_gravedad, bus_ruta, descripcion, DATE_FORMAT(fecha_hora, '%d/%m/%Y %h:%i %p') as fecha, audiencia FROM alertas WHERE estado = 'Activa' AND audiencia = 'publica' ORDER BY fecha_hora DESC" :
                        "SELECT id, tipo_gravedad, bus_ruta, descripcion, DATE_FORMAT(fecha_hora, '%d/%m/%Y %h:%i %p') as fecha, audiencia FROM alertas WHERE estado = 'Activa' ORDER BY fecha_hora DESC";
                    
                    ResultSet rs = st.executeQuery(query);
                    boolean hayNotis = false;
                    
                    while(rs.next()) {
                        int idAlerta = rs.getInt("id");
                        
                        // Si el usuario ya la marcó como leída, la saltamos sin dibujarla
                        if (alertasOcultas.contains(idAlerta)) {
                            continue;
                        }
                        
                        hayNotis = true; // Solo marcamos true si dibujamos al menos una
                        String tipo = rs.getString("tipo_gravedad");
                        String ruta = rs.getString("bus_ruta");
                        String desc = rs.getString("descripcion");
                        String fecha = rs.getString("fecha");
                        String audiencia = rs.getString("audiencia");
                        
                        String claseTipo = "noti-mecanica"; String icono = "🔵";
                        if(tipo.equals("Emergencia")) { claseTipo = "noti-emergencia"; icono = "🚨"; }
                        else if(tipo.equals("Trafico")) { claseTipo = "noti-trafico"; icono = "⚠️"; }
                        else if(tipo.equals("Logistica")) { claseTipo = "noti-logistica"; icono = "🚍"; }
            %>
                        <div class="notificacion <%= claseTipo %>">
                            <!-- Botón para ocultar -->
                            <form method="POST" style="margin: 0;">
                                <input type="hidden" name="accion" value="ocultar">
                                <input type="hidden" name="id_alerta" value="<%= idAlerta %>">
                                <button type="submit" class="btn-dismiss" title="Marcar como leído">✖</button>
                            </form>
                            
                            <span class="fecha">🕒 <%= fecha %></span>
                            <h3><%= icono %> Aviso de <%= tipo %></h3>
                            <p><%= desc %></p>
                            <span class="ruta">📍 <%= ruta %></span>
                            
                            <% if(!isPasajero && "interna".equals(audiencia)) { %>
                                <span class="badge-interna">🔒 Oculto a pasajeros</span>
                            <% } %>
                        </div>
            <%
                    }
                    if(!hayNotis) out.print("<div class='empty-state'>✅ El servicio opera con normalidad. No hay avisos pendientes de leer.</div>");
                    rs.close(); st.close(); con.close();
                } catch(Exception e) { out.print("Error: " + e.getMessage()); }
            %>
        </div>
        
        <div class="refresh-indicator">
            <span class="refresh-dot"></span> Sincronizado en tiempo real (Auto-Update)
        </div>
    </div>
    
    <script>
        // Variables para pausar el refresh si el usuario tiene un menú abierto
        let menuAbierto = false;

        function toggleMenu(side) {
            let left = document.getElementById("leftSidebar"); let right = document.getElementById("rightSidebar"); let over = document.getElementById("overlay");
            if (side === 'left') { left.style.width = "250px"; if(right) right.style.width = "0"; } 
            else if (side === 'right') { if(right) right.style.width = "300px"; left.style.width = "0"; }
            over.style.display = "block";
            menuAbierto = true;
        }
        function closeAllMenus() {
            document.getElementById("leftSidebar").style.width = "0"; let right = document.getElementById("rightSidebar"); if(right) right.style.width = "0";
            document.getElementById("overlay").style.display = "none";
            menuAbierto = false;
        }
        
        // Auto Refresh cada 15 segundos (solo si no hay menús abiertos)
        setInterval(() => { 
            if(!menuAbierto) {
                window.location.reload(); 
            }
        }, 15000); 
    </script>
</body>
</html>