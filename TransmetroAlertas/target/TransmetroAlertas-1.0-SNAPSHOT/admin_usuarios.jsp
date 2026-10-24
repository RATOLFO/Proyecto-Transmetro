<%@page contentType="text/html" pageEncoding="UTF-8"%>
<%@page import="java.sql.*"%>
<%
    // BLOQUEO DE SEGURIDAD ESTRICTO: Solo entra si es Administrador
    String rolActual = (String) session.getAttribute("rol");
    String usuarioLogueado = (String) session.getAttribute("nombre");
    if (session.getAttribute("usuarioValido") == null || !"admin".equals(rolActual)) {
        response.sendRedirect("index.jsp"); return; 
    }
    
    String dbUrl = "jdbc:mysql://192.168.15.135:3306/transmetro_db"; 
    String dbUser = "admin"; String dbPass = "admin123";
    String mensaje = "";
    String tipoMensaje = "exito";
    
    if ("POST".equalsIgnoreCase(request.getMethod())) {
        String accion = request.getParameter("accion");
        
        try {
            Class.forName("com.mysql.cj.jdbc.Driver");
            Connection con = DriverManager.getConnection(dbUrl, dbUser, dbPass);
            
            // LÓGICA PARA CREAR NUEVO USUARIO (PILOTO O ADMIN)
            if ("crear".equals(accion)) {
                String nUser = request.getParameter("new_username");
                String nPass = request.getParameter("new_password");
                String nRol = request.getParameter("new_rol");
                
                PreparedStatement psCheck = con.prepareStatement("SELECT id FROM usuarios WHERE username=?");
                psCheck.setString(1, nUser);
                ResultSet rsCheck = psCheck.executeQuery();
                
                if(rsCheck.next()) {
                    mensaje = "❌ El nombre de usuario '" + nUser + "' ya está registrado.";
                    tipoMensaje = "error";
                } else {
                    PreparedStatement psInsert = con.prepareStatement("INSERT INTO usuarios (username, password, rol) VALUES (?, ?, ?)");
                    psInsert.setString(1, nUser);
                    psInsert.setString(2, nPass);
                    psInsert.setString(3, nRol);
                    psInsert.executeUpdate();
                    psInsert.close();
                    
                    mensaje = "✅ Cuenta de " + nRol.toUpperCase() + " ('" + nUser + "') creada exitosamente.";
                    tipoMensaje = "exito";
                }
                rsCheck.close(); psCheck.close();
            } 
            // LÓGICA PARA ELIMINAR USUARIO
            else if ("eliminar".equals(accion)) {
                String userAEliminar = request.getParameter("username_delete");
                
                if (userAEliminar.equals(usuarioLogueado) || userAEliminar.equals("admin")) {
                    mensaje = "❌ Seguridad: No puedes eliminar tu propia cuenta o la cuenta administradora principal.";
                    tipoMensaje = "error";
                } else {
                    PreparedStatement psDel = con.prepareStatement("DELETE FROM usuarios WHERE username = ?");
                    psDel.setString(1, userAEliminar);
                    psDel.executeUpdate();
                    psDel.close();
                    mensaje = "✅ Usuario '" + userAEliminar + "' dado de baja del sistema.";
                    tipoMensaje = "exito";
                }
            }
            con.close();
        } catch(Exception e) { 
            mensaje = "Error de servidor: " + e.getMessage(); 
            tipoMensaje = "error";
        }
    }
%>

<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <title>Gestión de Usuarios - Transmetro</title>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&display=swap" rel="stylesheet">
    <style>
        body { font-family: 'Inter', 'Segoe UI', sans-serif; background-color: #f0f2f5; margin: 0; padding-top: 70px; }
        .header { background: #ffffff; color: #1e293b; padding: 15px 25px; position: fixed; top: 0; width: 100%; box-sizing: border-box; z-index: 1000; display: flex; justify-content: space-between; align-items: center; border-bottom: 1px solid #e2e8f0; box-shadow: 0 1px 3px rgba(0,0,0,0.04); }
        .header h1 { margin: 0; font-size: 18px; text-align: center; flex-grow: 1; font-weight: 700;}
        .menu-btn { background: none; border: none; color: #475569; font-size: 24px; cursor: pointer; transition: 0.2s; border-radius: 5px; padding: 5px 10px;}
        .overlay { display: none; position: fixed; width: 100%; height: 100%; top: 0; left: 0; background: rgba(15, 23, 42, 0.4); backdrop-filter: blur(2px); z-index: 999; }
        
        .main-container { max-width: 1000px; margin: 30px auto; padding: 0 20px; }
        .page-title h2 { margin: 0 0 5px 0; font-size: 26px; font-weight: 800; color: #0f172a;}
        .page-title p { margin: 0 0 20px 0; color: #64748b; font-size: 15px; }

        .card-container { background: #ffffff; border-radius: 12px; box-shadow: 0 4px 6px -1px rgba(0,0,0,0.05); border: 1px solid #e2e8f0; padding: 25px; border-top: 4px solid #1abc9c;}
        
        /* Estilos del Formulario de Creación */
        .admin-form { background: #f8fafc; padding: 20px; border-radius: 8px; border: 1px solid #e2e8f0; margin-bottom: 25px;}
        .admin-form h3 { margin-top: 0; color: #1e293b; font-size: 16px; border-bottom: 1px solid #cbd5e1; padding-bottom: 10px; margin-bottom: 15px;}
        .form-grid { display: grid; grid-template-columns: 1fr 1fr 1fr 1fr; gap: 15px; align-items: end;}
        .form-group label { display: block; font-size: 12px; font-weight: 700; color: #475569; margin-bottom: 5px;}
        .form-group input, .form-group select { width: 100%; padding: 10px; border: 1px solid #cbd5e1; border-radius: 6px; font-size: 14px; box-sizing: border-box; background: white;}
        .btn-submit { background: #1abc9c; color: white; border: none; padding: 10px; border-radius: 6px; font-weight: bold; cursor: pointer; transition: 0.2s; height: 40px;}
        .btn-submit:hover { background: #16a085; }
        
        table { width: 100%; border-collapse: collapse; text-align: left; }
        th { background-color: #f8fafc; padding: 14px 15px; font-size: 12px; color: #64748b; font-weight: 700; text-transform: uppercase; border-bottom: 2px solid #e2e8f0; }
        td { padding: 15px; font-size: 14px; color: #334155; border-bottom: 1px solid #f1f5f9; vertical-align: middle;}
        tr:hover td { background-color: #f8fafc; }
        
        .badge { padding: 5px 10px; border-radius: 6px; font-size: 11px; font-weight: 800; text-transform: uppercase; letter-spacing: 0.5px; }
        .badge-admin { background: #fee2e2; color: #b91c1c; border: 1px solid #fecaca; }
        .badge-piloto { background: #ffedd5; color: #c2410c; border: 1px solid #fed7aa; }
        .badge-pasajero { background: #e0f2fe; color: #0369a1; border: 1px solid #bae6fd; }

        .contacto-info { font-size: 13px; color: #64748b; margin-top: 3px; display: block;}
        
        .btn-del { background: #fee2e2; color: #ef4444; border: 1px solid #fca5a5; padding: 6px 10px; border-radius: 6px; font-weight: bold; font-size: 12px; cursor: pointer; transition: 0.2s;}
        .btn-del:hover { background: #ef4444; color: white; }
        .btn-disabled { background: #f1f5f9; color: #94a3b8; border: 1px solid #e2e8f0; cursor: not-allowed; padding: 6px 10px; border-radius: 6px; font-weight: bold; font-size: 12px;}

        .alerta { padding: 15px; border-radius: 8px; font-weight: 600; margin-bottom: 20px; font-size: 14px;}
        .alerta.error { background: #fef2f2; color: #e74c3c; border: 1px solid #fecaca;}
        .alerta.exito { background: #ecfdf5; color: #10b981; border: 1px solid #a7f3d0;}
    </style>
    <link rel="stylesheet" href="css/transmetro.css">
</head>
<body>

    <jsp:include page="menu_izquierdo.jsp" />
    <jsp:include page="menu_derecho.jsp" />
    <div id="overlay" class="overlay" onclick="closeAllMenus()"></div>

    <div class="header">
        <button class="menu-btn" onclick="toggleMenu('left')">☰</button>
        <h1>Módulo de Auditoría</h1>
        <button class="menu-btn" onclick="toggleMenu('right')">⚙️</button>
    </div>

    <div class="main-container">
        <div class="page-title">
            <h2>👥 Directorio de Usuarios</h2>
            <p>Creación de cuentas operativas y monitoreo del sistema.</p>
        </div>

        <% if(!mensaje.isEmpty()) { %> <div class="alerta <%= tipoMensaje %>"><%= mensaje %></div> <% } %>

        <div class="card-container">
            
            <!-- FORMULARIO PARA CREAR PILOTOS O ADMINS -->
            <div class="admin-form">
                <h3>➕ Crear Nueva Cuenta de Acceso</h3>
                <form method="POST" action="admin_usuarios.jsp" class="form-grid">
                    <input type="hidden" name="accion" value="crear">
                    
                    <div class="form-group">
                        <label>Nombre de Usuario</label>
                        <input type="text" name="new_username" placeholder="Ej. piloto_luis" required>
                    </div>
                    
                    <div class="form-group">
                        <label>Contraseña Inicial</label>
                        <input type="password" name="new_password" placeholder="Contraseña temporal" required>
                    </div>
                    
                    <div class="form-group">
                        <label>Rol del Sistema</label>
                        <select name="new_rol" required>
                            <option value="piloto" selected>👨‍✈️ Piloto Operador</option>
                            <option value="admin">👑 Administrador</option>
                            <option value="pasajero">🧍 Pasajero</option>
                        </select>
                    </div>
                    
                    <div class="form-group">
                        <button type="submit" class="btn-submit">➕ Registrar Usuario</button>
                    </div>
                </form>
            </div>

            <!-- TABLA DE AUDITORÍA -->
            <table>
                <thead>
                    <tr>
                        <th>Usuario</th>
                        <th>Rol del Sistema</th>
                        <th>Datos de Contacto</th>
                        <th style="text-align: center;">Acciones</th>
                    </tr>
                </thead>
                <tbody>
                    <%
                        try {
                            Class.forName("com.mysql.cj.jdbc.Driver");
                            Connection con = DriverManager.getConnection(dbUrl, dbUser, dbPass);
                            Statement st = con.createStatement();
                            
                            ResultSet rs = st.executeQuery("SELECT username, rol, IFNULL(telefono, 'No registrado') as telefono, IFNULL(correo, 'No registrado') as correo FROM usuarios ORDER BY FIELD(rol, 'admin', 'piloto', 'pasajero'), username ASC");
                            
                            while(rs.next()) {
                                String user = rs.getString("username");
                                String rol = rs.getString("rol");
                                String telefono = rs.getString("telefono");
                                String correo = rs.getString("correo");
                                
                                String badgeClass = "badge-pasajero";
                                if(rol.equals("admin")) badgeClass = "badge-admin";
                                else if(rol.equals("piloto")) badgeClass = "badge-piloto";
                    %>
                                <tr>
                                    <td style="font-weight: 700; color: #1e293b; font-size: 15px;">👤 <%= user %></td>
                                    <td><span class="badge <%= badgeClass %>"><%= rol %></span></td>
                                    <td>
                                        <span class="contacto-info">📞 Tel: <%= telefono.isEmpty() ? "No registrado" : telefono %></span>
                                        <span class="contacto-info">📧 Correo: <%= correo.isEmpty() ? "No registrado" : correo %></span>
                                    </td>
                                    <td style="text-align: center;">
                                        <% if (user.equals(usuarioLogueado) || user.equals("admin")) { %>
                                            <button class="btn-disabled" title="No puedes eliminar esta cuenta">Protegido</button>
                                        <% } else { %>
                                            <form method="POST" style="margin: 0;" onsubmit="return confirm('ALERTA: ¿Está seguro de eliminar al usuario <%= user %>?');">
                                                <input type="hidden" name="accion" value="eliminar">
                                                <input type="hidden" name="username_delete" value="<%= user %>">
                                                <button type="submit" class="btn-del">🗑️ Dar de Baja</button>
                                            </form>
                                        <% } %>
                                    </td>
                                </tr>
                    <%
                            }
                            rs.close(); st.close(); con.close();
                        } catch(Exception e) { out.print("<tr><td colspan='4'>Error: " + e.getMessage() + "</td></tr>"); }
                    %>
                </tbody>
            </table>
        </div>
    </div>

    <script>
        function toggleMenu(side) {
            let leftMenu = document.getElementById("leftSidebar"); let rightMenu = document.getElementById("rightSidebar"); let overlay = document.getElementById("overlay");
            if (side === 'left') { leftMenu.style.width = "250px"; if(rightMenu) rightMenu.style.width = "0"; } 
            else if (side === 'right') { if(rightMenu) rightMenu.style.width = "300px"; leftMenu.style.width = "0"; }
            overlay.style.display = "block";
        }
        function closeAllMenus() {
            document.getElementById("leftSidebar").style.width = "0"; let rightMenu = document.getElementById("rightSidebar"); if(rightMenu) rightMenu.style.width = "0";
            document.getElementById("overlay").style.display = "none";
        }
    </script>
</body>
</html>