<%@page contentType="text/html" pageEncoding="UTF-8"%>
<%@page import="java.sql.*"%>
<%
    if (session.getAttribute("usuarioValido") != null) { response.sendRedirect("index.jsp"); return; }

    String error = "";
    String exito = "";
    String tabActiva = "login";
    if ("registro".equals(request.getParameter("tab"))) tabActiva = "registro";

    if ("POST".equalsIgnoreCase(request.getMethod())) {
        String accion = request.getParameter("accion");
        String dbUrl = "jdbc:mysql://192.168.15.135:3306/transmetro_db";
        String dbUser = "admin";
        String dbPass = "admin123";

        try {
            Class.forName("com.mysql.cj.jdbc.Driver");
            Connection con = DriverManager.getConnection(dbUrl, dbUser, dbPass);

            if ("login".equals(accion)) {
                tabActiva = "login";
                String u = request.getParameter("usuario");
                String p = request.getParameter("password");

                PreparedStatement ps = con.prepareStatement("SELECT rol FROM usuarios WHERE username=? AND password=?");
                ps.setString(1, u);
                ps.setString(2, p);
                ResultSet rs = ps.executeQuery();

                if (rs.next()) {
                    String rol = rs.getString("rol");
                    session.setAttribute("usuarioValido", true);
                    session.setAttribute("nombre", u);
                    session.setAttribute("rol", rol);
                    rs.close(); ps.close(); con.close();
                    response.sendRedirect("index.jsp");
                    return;
                } else {
                    error = "Usuario o contraseña incorrectos.";
                }
                rs.close();
                ps.close();

            } else if ("registro".equals(accion)) {
                tabActiva = "registro";
                String u = request.getParameter("nuevo_usuario");
                String p = request.getParameter("nueva_password");
                String pConfirm = request.getParameter("confirm_password");

                if (!p.equals(pConfirm)) {
                    error = "Las contraseñas no coinciden.";
                } else {
                    PreparedStatement psCheck = con.prepareStatement("SELECT id FROM usuarios WHERE username=?");
                    psCheck.setString(1, u);
                    ResultSet rsCheck = psCheck.executeQuery();

                    if (rsCheck.next()) {
                        error = "El nombre de usuario ya está en uso. Elija otro.";
                        rsCheck.close();
                        psCheck.close();
                    } else {
                        rsCheck.close();
                        psCheck.close();

                        PreparedStatement psInsert = con.prepareStatement("INSERT INTO usuarios (username, password, rol) VALUES (?, ?, 'pasajero')");
                        psInsert.setString(1, u);
                        psInsert.setString(2, p);
                        psInsert.executeUpdate();
                        psInsert.close();

                        exito = "¡Cuenta creada exitosamente! Ya puede iniciar sesión.";
                        tabActiva = "login";
                    }
                }
            }
            con.close();
        } catch (Exception e) {
            error = "Error de conexión: " + e.getMessage();
        }
    }
%>
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Acceso — Transmetro GT</title>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&display=swap" rel="stylesheet">
    <style>
        * { box-sizing: border-box; }
        body {
            font-family: 'Inter', -apple-system, BlinkMacSystemFont, sans-serif;
            background: #f8fafc;
            background-image:
                radial-gradient(at 0% 0%, rgba(13, 148, 136, 0.09) 0px, transparent 50%),
                radial-gradient(at 100% 100%, rgba(2, 132, 199, 0.08) 0px, transparent 50%);
            min-height: 100vh;
            margin: 0;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 20px;
            color: #0f172a;
        }

        .auth-wrapper {
            width: 100%;
            max-width: 420px;
        }

        .brand-header {
            text-align: center;
            margin-bottom: 24px;
        }
        .brand-logo {
            width: 52px;
            height: 52px;
            border-radius: 14px;
            background: linear-gradient(135deg, #0d9488, #0284c7);
            display: inline-flex;
            align-items: center;
            justify-content: center;
            font-size: 26px;
            box-shadow: 0 8px 20px -4px rgba(13, 148, 136, 0.35);
            margin-bottom: 12px;
        }
        .brand-header h1 {
            margin: 0;
            font-size: 22px;
            font-weight: 800;
            letter-spacing: -0.025em;
            color: #0f172a;
        }
        .brand-header p {
            margin: 4px 0 0 0;
            font-size: 13.5px;
            color: #64748b;
        }

        .login-card {
            background: #ffffff;
            border: 1px solid #e2e8f0;
            border-radius: 18px;
            padding: 28px;
            box-shadow: 0 4px 24px -4px rgba(15, 23, 42, 0.06);
        }

        /* Control segmentado minimalista */
        .tabs-nav {
            display: grid;
            grid-template-columns: 1fr 1fr;
            background: #f1f5f9;
            padding: 4px;
            border-radius: 11px;
            margin-bottom: 22px;
        }
        .tab-btn {
            background: transparent;
            border: none;
            padding: 9px 12px;
            border-radius: 8px;
            font-family: inherit;
            font-weight: 600;
            font-size: 13px;
            color: #64748b;
            cursor: pointer;
            transition: all 0.18s ease;
        }
        .tab-btn.active {
            background: #ffffff;
            color: #0f172a;
            box-shadow: 0 1px 3px rgba(15, 23, 42, 0.08);
        }

        .form-section { display: none; }
        .form-section.active { display: block; }

        .field-group {
            margin-bottom: 15px;
            text-align: left;
        }
        .field-group label {
            display: block;
            font-size: 12px;
            font-weight: 600;
            color: #334155;
            margin-bottom: 6px;
        }
        .field-group input {
            width: 100%;
            padding: 11px 13px;
            border: 1px solid #cbd5e1;
            border-radius: 10px;
            font-size: 14px;
            font-family: inherit;
            color: #0f172a;
            background: #ffffff;
            transition: border-color 0.18s, box-shadow 0.18s;
        }
        .field-group input:focus {
            outline: none;
            border-color: #0d9488;
            box-shadow: 0 0 0 3px rgba(13, 148, 136, 0.14);
        }

        .btn-action {
            width: 100%;
            padding: 12px;
            border-radius: 10px;
            border: none;
            background: #0d9488;
            color: #ffffff;
            font-family: inherit;
            font-size: 14px;
            font-weight: 700;
            cursor: pointer;
            transition: background 0.18s, transform 0.18s;
            margin-top: 4px;
        }
        .btn-action:hover {
            background: #0f766e;
            transform: translateY(-1px);
        }

        .alert-msg {
            padding: 11px 14px;
            border-radius: 10px;
            font-size: 13px;
            font-weight: 600;
            margin-bottom: 18px;
            text-align: left;
        }
        .alert-error {
            background: #fff1f2;
            color: #9f1239;
            border: 1px solid #fecdd3;
        }
        .alert-exito {
            background: #f0fdf4;
            color: #166534;
            border: 1px solid #bbf7d0;
        }

        /* Accesos rápidos de demostración */
        .quick-demo {
            margin-top: 22px;
            padding-top: 18px;
            border-top: 1px solid #f1f5f9;
            text-align: left;
        }
        .quick-demo-label {
            font-size: 11px;
            font-weight: 700;
            color: #94a3b8;
            text-transform: uppercase;
            letter-spacing: 0.05em;
            margin-bottom: 8px;
        }
        .demo-chips {
            display: flex;
            gap: 8px;
            flex-wrap: wrap;
        }
        .demo-chip {
            flex: 1;
            background: #f8fafc;
            border: 1px solid #e2e8f0;
            border-radius: 8px;
            padding: 7px 10px;
            font-size: 12px;
            font-weight: 600;
            color: #334155;
            cursor: pointer;
            display: flex;
            align-items: center;
            justify-content: center;
            gap: 6px;
            transition: all 0.16s;
        }
        .demo-chip:hover {
            background: #f0fdfa;
            border-color: #99f6e4;
            color: #0f766e;
        }
    </style>
</head>
<body>
    <div class="auth-wrapper">
        <div class="brand-header">
            <div class="brand-logo">🚍</div>
            <h1>Transmetro GT</h1>
            <p>Plataforma de Gestión Operativa y Abordaje</p>
        </div>

        <div class="login-card">
            <% if (!error.isEmpty()) { %>
                <div class="alert-msg alert-error">⚠️ <%= error %></div>
            <% } %>
            <% if (!exito.isEmpty()) { %>
                <div class="alert-msg alert-exito">✅ <%= exito %></div>
            <% } %>

            <div class="tabs-nav">
                <button type="button" id="btnTabLogin" class="tab-btn <%= "login".equals(tabActiva) ? "active" : "" %>" onclick="cambiarTab('login')">Iniciar Sesión</button>
                <button type="button" id="btnTabRegistro" class="tab-btn <%= "registro".equals(tabActiva) ? "active" : "" %>" onclick="cambiarTab('registro')">Crear Cuenta</button>
            </div>

            <!-- LOGIN -->
            <div id="sectionLogin" class="form-section <%= "login".equals(tabActiva) ? "active" : "" %>">
                <form method="POST" id="formLogin">
                    <input type="hidden" name="accion" value="login">
                    <div class="field-group">
                        <label>Usuario</label>
                        <input type="text" name="usuario" id="inpUser" placeholder="Ej. admin o piloto juan" required>
                    </div>
                    <div class="field-group">
                        <label>Contraseña</label>
                        <input type="password" name="password" id="inpPass" placeholder="••••••••" required>
                    </div>
                    <button type="submit" class="btn-action">Continuar al Panel →</button>
                </form>

                <div class="quick-demo">
                    <div class="quick-demo-label">Acceso rápido de prueba (1 clic):</div>
                    <div class="demo-chips">
                        <button type="button" class="demo-chip" onclick="llenarDemo('admin', 'admin123')">
                            <span>👑</span><span>Admin</span>
                        </button>
                        <button type="button" class="demo-chip" onclick="llenarDemo('piloto juan', 'piloto123')">
                            <span>👨‍✈️</span><span>Piloto Juan</span>
                        </button>
                    </div>
                </div>
            </div>

            <!-- REGISTRO -->
            <div id="sectionRegistro" class="form-section <%= "registro".equals(tabActiva) ? "active" : "" %>">
                <form method="POST">
                    <input type="hidden" name="accion" value="registro">
                    <div class="field-group">
                        <label>Nombre de Usuario</label>
                        <input type="text" name="nuevo_usuario" placeholder="Elija su usuario" required>
                    </div>
                    <div class="field-group">
                        <label>Contraseña</label>
                        <input type="password" name="nueva_password" placeholder="Cree una contraseña" required>
                    </div>
                    <div class="field-group">
                        <label>Confirmar Contraseña</label>
                        <input type="password" name="confirm_password" placeholder="Repita la contraseña" required>
                    </div>
                    <button type="submit" class="btn-action">Registrar Cuenta de Pasajero</button>
                </form>
            </div>
        </div>
    </div>

    <script>
        function cambiarTab(tab) {
            const sLogin = document.getElementById('sectionLogin');
            const sRegistro = document.getElementById('sectionRegistro');
            const bLogin = document.getElementById('btnTabLogin');
            const bRegistro = document.getElementById('btnTabRegistro');

            if (tab === 'login') {
                sLogin.classList.add('active');
                sRegistro.classList.remove('active');
                bLogin.classList.add('active');
                bRegistro.classList.remove('active');
            } else {
                sRegistro.classList.add('active');
                sLogin.classList.remove('active');
                bRegistro.classList.add('active');
                bLogin.classList.remove('active');
            }
        }

        function llenarDemo(usr, pwd) {
            cambiarTab('login');
            document.getElementById('inpUser').value = usr;
            document.getElementById('inpPass').value = pwd;
        }
    </script>
</body>
</html>
