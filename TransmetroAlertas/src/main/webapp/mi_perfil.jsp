<%@page contentType="text/html" pageEncoding="UTF-8"%>
<%@page import="java.sql.*"%>
<%
    // Verificamos que el usuario esté logueado
    if (session.getAttribute("usuarioValido") == null) { response.sendRedirect("login.jsp"); return; }
    
    String dbUrl = "jdbc:mysql://192.168.15.135:3306/transmetro_db"; 
    String dbUser = "admin"; String dbPass = "admin123";
    
    // Obtenemos los datos de la sesión
    String currentUsername = (String) session.getAttribute("nombre");
    String currentRol = (String) session.getAttribute("rol");
    
    // Variables para pre-cargar en el formulario
    String currentTelefono = "";
    String currentCorreo = "";
    String mensaje = "";
    String tipoMensaje = ""; 

    // 1. CARGAMOS LOS DATOS ACTUALES DE LA BASE DE DATOS
    try {
        Class.forName("com.mysql.cj.jdbc.Driver");
        Connection con = DriverManager.getConnection(dbUrl, dbUser, dbPass);
        PreparedStatement psInfo = con.prepareStatement("SELECT telefono, correo FROM usuarios WHERE username=?");
        psInfo.setString(1, currentUsername);
        ResultSet rsInfo = psInfo.executeQuery();
        if (rsInfo.next()) {
            currentTelefono = rsInfo.getString("telefono"); if(currentTelefono == null) currentTelefono = "";
            currentCorreo = rsInfo.getString("correo"); if(currentCorreo == null) currentCorreo = "";
        }
        rsInfo.close(); psInfo.close(); con.close();
    } catch(Exception e) {}

    // 2. PROCESAMOS EL FORMULARIO SI EL USUARIO LE DA A GUARDAR
    if ("POST".equalsIgnoreCase(request.getMethod())) {
        String oldUser = request.getParameter("old_username");
        String oldPass = request.getParameter("old_password");
        
        String newUser = request.getParameter("new_username");
        String newTel = request.getParameter("new_telefono");
        String newCor = request.getParameter("new_correo");
        
        String newPass = request.getParameter("new_password");
        String confirmPass = request.getParameter("confirm_password");
        
        try {
            Class.forName("com.mysql.cj.jdbc.Driver");
            Connection con = DriverManager.getConnection(dbUrl, dbUser, dbPass);
            
            // Verificamos si las credenciales de seguridad antiguas son correctas
            PreparedStatement psVerify = con.prepareStatement("SELECT id FROM usuarios WHERE username=? AND password=?");
            psVerify.setString(1, oldUser); psVerify.setString(2, oldPass);
            ResultSet rsVerify = psVerify.executeQuery();
            
            if (rsVerify.next()) {
                if (!currentUsername.equals(oldUser)) {
                    mensaje = "❌ El usuario de seguridad no coincide con su sesión activa."; tipoMensaje = "error";
                } else if (newPass != null && !newPass.isEmpty() && !newPass.equals(confirmPass)) {
                    mensaje = "❌ Las contraseñas nuevas no coinciden entre sí."; tipoMensaje = "error";
                } else {
                    // Verificamos que el NUEVO nombre de usuario no esté tomado
                    boolean usernameTomado = false;
                    if (!currentUsername.equals(newUser)) {
                        PreparedStatement psCheck = con.prepareStatement("SELECT id FROM usuarios WHERE username=?");
                        psCheck.setString(1, newUser);
                        ResultSet rsCheck = psCheck.executeQuery();
                        if(rsCheck.next()) usernameTomado = true;
                        rsCheck.close(); psCheck.close();
                    }
                    
                    if(usernameTomado) {
                        mensaje = "❌ El nombre de usuario '" + newUser + "' ya está en uso. Elija otro."; tipoMensaje = "error";
                    } else {
                        // Si dejó la nueva contraseña en blanco, conservamos la que ya tenía
                        String passToSave = (newPass != null && !newPass.isEmpty()) ? newPass : oldPass;
                        
                        // ACTUALIZACIÓN EN BASE DE DATOS CON LOS NUEVOS CAMPOS
                        PreparedStatement psUpdate = con.prepareStatement("UPDATE usuarios SET username=?, password=?, telefono=?, correo=? WHERE username=?");
                        psUpdate.setString(1, newUser);
                        psUpdate.setString(2, passToSave);
                        psUpdate.setString(3, newTel);
                        psUpdate.setString(4, newCor);
                        psUpdate.setString(5, currentUsername);
                        psUpdate.executeUpdate();
                        psUpdate.close();
                        
                        // Actualizamos la sesión y las variables de la página
                        session.setAttribute("nombre", newUser);
                        currentUsername = newUser; 
                        currentTelefono = newTel;
                        currentCorreo = newCor;
                        
                        mensaje = "✅ Sus datos fueron actualizados correctamente."; tipoMensaje = "exito";
                    }
                }
            } else {
                mensaje = "❌ Credenciales actuales incorrectas. Autorización denegada."; tipoMensaje = "error";
            }
            rsVerify.close(); psVerify.close(); con.close();
        } catch(Exception e) { mensaje = "❌ Error en el servidor: " + e.getMessage(); tipoMensaje = "error"; }
    }
%>

<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <title>Mi Perfil - Transmetro</title>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&display=swap" rel="stylesheet">
    <style>
        body { font-family: 'Inter', 'Segoe UI', sans-serif; background-color: #f0f2f5; margin: 0; padding-top: 70px; }
        .header { background: #ffffff; color: #1e293b; padding: 15px 25px; position: fixed; top: 0; width: 100%; box-sizing: border-box; z-index: 1000; display: flex; justify-content: space-between; align-items: center; border-bottom: 1px solid #e2e8f0; box-shadow: 0 1px 3px rgba(0,0,0,0.04); }
        .header h1 { margin: 0; font-size: 18px; text-align: center; flex-grow: 1; font-weight: 700;}
        .menu-btn { background: none; border: none; color: #475569; font-size: 24px; cursor: pointer; transition: 0.2s; border-radius: 5px; padding: 5px 10px;}
        .overlay { display: none; position: fixed; width: 100%; height: 100%; top: 0; left: 0; background: rgba(15, 23, 42, 0.4); backdrop-filter: blur(2px); z-index: 999; }
        
        .main-container { max-width: 650px; margin: 30px auto; padding: 0 20px; }
        .page-title h2 { margin: 0 0 5px 0; font-size: 26px; font-weight: 800; color: #0f172a;}
        .page-title p { margin: 0 0 20px 0; color: #64748b; font-size: 15px; }

        .perfil-card { background: #ffffff; border-radius: 12px; box-shadow: 0 4px 6px -1px rgba(0,0,0,0.05); border: 1px solid #e2e8f0; padding: 30px; position: relative; overflow: hidden;}
        .perfil-card::before { content: ''; position: absolute; top: 0; left: 0; right: 0; height: 5px; background: linear-gradient(90deg, #1a2a6c, #11998e); }

        .rol-badge { display: inline-block; background: #e0e7ff; color: #3730a3; padding: 6px 12px; border-radius: 6px; font-weight: 800; font-size: 13px; text-transform: uppercase; margin-bottom: 25px; border: 1px solid #c7d2fe; letter-spacing: 0.5px;}
        
        .form-section-title { font-size: 14px; font-weight: 800; color: #475569; margin-bottom: 15px; border-bottom: 2px solid #f1f5f9; padding-bottom: 8px;}
        
        .form-group { margin-bottom: 20px; }
        .form-group label { display: block; font-size: 13px; font-weight: 700; color: #334155; margin-bottom: 6px; }
        .form-group input { width: 100%; padding: 12px; border: 1px solid #cbd5e1; border-radius: 8px; font-size: 14px; box-sizing: border-box; background: #f8fafc; transition: 0.2s;}
        .form-group input:focus { outline: none; border-color: #11998e; background: #ffffff; box-shadow: 0 0 0 3px rgba(17, 153, 142, 0.1); }
        
        /* Grid de 2 columnas para que el formulario se vea profesional */
        .form-grid-2 { display: grid; grid-template-columns: 1fr 1fr; gap: 15px; }
        
        .security-box { background: #fff1f2; border: 1px solid #fecdd3; padding: 20px; border-radius: 8px; margin-bottom: 25px;}
        .security-box label { color: #be123c; }
        .security-box input { border-color: #fecdd3; background: #ffffff;}
        
        .btn-submit { background: #1a2a6c; color: white; border: none; padding: 14px; width: 100%; border-radius: 8px; font-weight: bold; font-size: 15px; cursor: pointer; transition: 0.2s;}
        .btn-submit:hover { background: #11998e; transform: translateY(-2px); box-shadow: 0 4px 10px rgba(17, 153, 142, 0.3);}

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
        <h1>Ajustes de Cuenta</h1>
        <% if ("admin".equals(currentRol)) { %><button class="menu-btn" onclick="toggleMenu('right')">⚙️</button><% } else { %><div style="width: 34px;"></div><% } %>
    </div>

    <div class="main-container">
        <div class="page-title">
            <h2>⚙️ Mi Perfil</h2>
            <p>Visualiza y actualiza la información de tu cuenta.</p>
        </div>

        <% if(!mensaje.isEmpty()) { %>
            <div class="alerta <%= tipoMensaje %>"><%= mensaje %></div>
        <% } %>

        <div class="perfil-card">
            <span class="rol-badge">ROL ACTIVO: <%= currentRol %></span>
            
            <form method="POST" action="mi_perfil.jsp">
                <div class="form-section-title">✏️ DATOS PERSONALES</div>
                
                <div class="form-group">
                    <label>Nombre de Usuario</label>
                    <input type="text" name="new_username" value="<%= currentUsername %>" required>
                </div>
                
                <div class="form-grid-2">
                    <div class="form-group">
                        <label>Teléfono Móvil</label>
                        <input type="text" name="new_telefono" value="<%= currentTelefono %>" placeholder="Ej. 5555-1234">
                    </div>
                    <div class="form-group">
                        <label>Correo Electrónico</label>
                        <input type="email" name="new_correo" value="<%= currentCorreo %>" placeholder="ejemplo@correo.com">
                    </div>
                </div>
                
                <div class="form-section-title" style="margin-top: 10px;">🔑 ACTUALIZAR CONTRASEÑA</div>
                <div class="form-grid-2">
                    <div class="form-group">
                        <label>Nueva Contraseña (Opcional)</label>
                        <input type="password" name="new_password" placeholder="Dejar en blanco para no cambiarla">
                    </div>
                    <div class="form-group">
                        <label>Confirmar Nueva Contraseña</label>
                        <input type="password" name="confirm_password" placeholder="Repita si ingresó una nueva">
                    </div>
                </div>
                
                <div class="security-box">
                    <div class="form-section-title" style="color:#be123c; border-bottom-color:#fecdd3;">🔒 VERIFICACIÓN DE SEGURIDAD</div>
                    <p style="font-size:12px; color:#9f1239; margin-top:0; margin-bottom:15px;">Para autorizar los cambios, por favor ingrese sus credenciales actuales.</p>
                    
                    <div class="form-grid-2">
                        <div class="form-group" style="margin-bottom:0;">
                            <label>Usuario Actual</label>
                            <input type="text" name="old_username" placeholder="Su usuario actual" required>
                        </div>
                        <div class="form-group" style="margin-bottom:0;">
                            <label>Contraseña Actual</label>
                            <input type="password" name="old_password" placeholder="Su contraseña actual" required>
                        </div>
                    </div>
                </div>

                <button type="submit" class="btn-submit">💾 Guardar Cambios</button>
            </form>
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