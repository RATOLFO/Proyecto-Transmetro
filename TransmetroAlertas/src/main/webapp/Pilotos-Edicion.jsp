<%@page contentType="text/html" pageEncoding="UTF-8"%>
<%@page import="java.sql.*"%>
<%@page import="java.util.*"%>
<%!
    static String h(String s) {
        if (s == null) return "";
        return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace("\"", "&quot;").replace("'", "&#39;");
    }
    static String js(String s) {
        if (s == null) return "";
        return s.replace("\\", "\\\\").replace("\"", "\\\"").replace("'", "\\'").replace("\r", "").replace("\n", " ");
    }
    static String t(String s) {
        return s == null ? "" : s.trim();
    }
    static void asegurarColumnaPiloto(Connection con) {
        try (Statement st = con.createStatement()) {
            st.executeUpdate("ALTER TABLE rutas_operativas ADD COLUMN id_piloto INT DEFAULT NULL");
        } catch (SQLException ignorar) {}
    }
%>
<%
    // BLOQUEO DE SEGURIDAD ESTRICTO: Solo entra si es Administrador
    String rolActual = (String) session.getAttribute("rol");
    if (session.getAttribute("usuarioValido") == null || !"admin".equals(rolActual)) {
        response.sendRedirect("index.jsp");
        return;
    }

    String dbUrl = "jdbc:mysql://192.168.15.135:3306/transmetro_db";
    String dbUser = "admin";
    String dbPass = "admin123";
    String mensaje = "";
    String tipoMensaje = "exito";

    Class.forName("com.mysql.cj.jdbc.Driver");
    try (Connection conInit = DriverManager.getConnection(dbUrl, dbUser, dbPass)) {
        asegurarColumnaPiloto(conInit);
    } catch (Exception ignorar) {}

    // PROCESAMIENTO DEL FORMULARIO (CREAR, EDITAR, ASIGNAR RUTA O ELIMINAR)
    if ("POST".equalsIgnoreCase(request.getMethod())) {
        request.setCharacterEncoding("UTF-8");
        String accion = t(request.getParameter("accion"));

        try (Connection con = DriverManager.getConnection(dbUrl, dbUser, dbPass)) {
            if ("crear".equals(accion)) {
                String nombre = t(request.getParameter("nombre"));
                int edad = 0;
                try { edad = Integer.parseInt(t(request.getParameter("edad"))); } catch (NumberFormatException e) { edad = 0; }
                String identificador = t(request.getParameter("identificador_transmetro"));
                String usrAsignado = t(request.getParameter("usuario_asignado"));
                String idRutaStr = t(request.getParameter("id_ruta_asignada"));

                int idNuevoPiloto = 0;
                try (PreparedStatement psInsert = con.prepareStatement(
                        "INSERT INTO pilotos_catalogo (nombre, edad, identificador_transmetro, usuario_asignado) VALUES (?, ?, ?, ?)",
                        Statement.RETURN_GENERATED_KEYS)) {
                    psInsert.setString(1, nombre);
                    psInsert.setInt(2, edad);
                    psInsert.setString(3, identificador);
                    psInsert.setString(4, usrAsignado.isEmpty() ? "Sin asignar" : usrAsignado);
                    psInsert.executeUpdate();
                    try (ResultSet rk = psInsert.getGeneratedKeys()) {
                        if (rk.next()) idNuevoPiloto = rk.getInt(1);
                    }
                }

                if (idNuevoPiloto > 0 && !idRutaStr.isEmpty()) {
                    try (PreparedStatement psRuta = con.prepareStatement("UPDATE rutas_operativas SET id_piloto = ? WHERE id_ruta = ?")) {
                        psRuta.setInt(1, idNuevoPiloto);
                        psRuta.setInt(2, Integer.parseInt(idRutaStr));
                        psRuta.executeUpdate();
                    }
                }

                mensaje = "✅ Piloto '" + nombre + "' registrado y vinculado exitosamente.";
                tipoMensaje = "exito";

            } else if ("editar".equals(accion)) {
                int idPiloto = Integer.parseInt(t(request.getParameter("id_piloto")));
                String nombre = t(request.getParameter("nombre"));
                int edad = 0;
                try { edad = Integer.parseInt(t(request.getParameter("edad"))); } catch (NumberFormatException e) { edad = 0; }
                String identificador = t(request.getParameter("identificador_transmetro"));
                String usrAsignado = t(request.getParameter("usuario_asignado"));
                String idRutaStr = t(request.getParameter("id_ruta_asignada"));

                try (PreparedStatement psUpd = con.prepareStatement(
                        "UPDATE pilotos_catalogo SET nombre = ?, edad = ?, identificador_transmetro = ?, usuario_asignado = ? WHERE id = ?")) {
                    psUpd.setString(1, nombre);
                    psUpd.setInt(2, edad);
                    psUpd.setString(3, identificador);
                    psUpd.setString(4, usrAsignado.isEmpty() ? "Sin asignar" : usrAsignado);
                    psUpd.setInt(5, idPiloto);
                    psUpd.executeUpdate();
                }

                // Actualizar asignación de ruta
                try (PreparedStatement psClear = con.prepareStatement("UPDATE rutas_operativas SET id_piloto = NULL WHERE id_piloto = ?")) {
                    psClear.setInt(1, idPiloto);
                    psClear.executeUpdate();
                }
                if (!idRutaStr.isEmpty()) {
                    try (PreparedStatement psSet = con.prepareStatement("UPDATE rutas_operativas SET id_piloto = ? WHERE id_ruta = ?")) {
                        psSet.setInt(1, idPiloto);
                        psSet.setInt(2, Integer.parseInt(idRutaStr));
                        psSet.executeUpdate();
                    }
                }

                mensaje = "✅ Datos del piloto '" + nombre + "' actualizados correctamente.";
                tipoMensaje = "exito";

            } else if ("asignar_ruta".equals(accion)) {
                int idPiloto = Integer.parseInt(t(request.getParameter("id_piloto")));
                String idRutaStr = t(request.getParameter("id_ruta"));

                // Limpiar primero cualquier ruta previa de este piloto para que el cambio se refleje limpio
                try (PreparedStatement psClear = con.prepareStatement("UPDATE rutas_operativas SET id_piloto = NULL WHERE id_piloto = ?")) {
                    psClear.setInt(1, idPiloto);
                    psClear.executeUpdate();
                }

                if (idRutaStr.isEmpty()) {
                    mensaje = "✅ Se desvinculó la ruta del piloto.";
                } else {
                    int idRuta = Integer.parseInt(idRutaStr);
                    try (PreparedStatement psSet = con.prepareStatement("UPDATE rutas_operativas SET id_piloto = ? WHERE id_ruta = ?")) {
                        psSet.setInt(1, idPiloto);
                        psSet.setInt(2, idRuta);
                        psSet.executeUpdate();
                    }
                    mensaje = "✅ Piloto asignado correctamente a la ruta seleccionada.";
                }
                tipoMensaje = "exito";

            } else if ("eliminar".equals(accion)) {
                int idPiloto = Integer.parseInt(t(request.getParameter("id_piloto")));
                try (PreparedStatement psClear = con.prepareStatement("UPDATE rutas_operativas SET id_piloto = NULL WHERE id_piloto = ?")) {
                    psClear.setInt(1, idPiloto);
                    psClear.executeUpdate();
                }
                try (PreparedStatement psDel = con.prepareStatement("DELETE FROM pilotos_catalogo WHERE id = ?")) {
                    psDel.setInt(1, idPiloto);
                    psDel.executeUpdate();
                }
                mensaje = "✅ Piloto dado de baja del catálogo.";
                tipoMensaje = "exito";
            }
        } catch (Exception e) {
            mensaje = "❌ Error de servidor: " + e.getMessage();
            tipoMensaje = "error";
        }
    }
%>

<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <title>Gestión de Pilotos - Transmetro</title>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&display=swap" rel="stylesheet">
    <style>
        body { font-family: 'Inter', 'Segoe UI', sans-serif; background-color: #f0f2f5; margin: 0; padding-top: 70px; }
        .header { background: #ffffff; color: #1e293b; padding: 15px 25px; position: fixed; top: 0; width: 100%; box-sizing: border-box; z-index: 1000; display: flex; justify-content: space-between; align-items: center; border-bottom: 1px solid #e2e8f0; box-shadow: 0 1px 3px rgba(0,0,0,0.04); }
        .header h1 { margin: 0; font-size: 18px; text-align: center; flex-grow: 1; font-weight: 700; }
        .menu-btn { background: none; border: none; color: #475569; font-size: 24px; cursor: pointer; transition: 0.2s; border-radius: 5px; padding: 5px 10px; }
        .overlay { display: none; position: fixed; width: 100%; height: 100%; top: 0; left: 0; background: rgba(15, 23, 42, 0.4); backdrop-filter: blur(2px); z-index: 999; }

        .main-container { max-width: 1180px; margin: 30px auto; padding: 0 20px 50px 20px; }
        .page-title { display: flex; justify-content: space-between; align-items: flex-end; flex-wrap: wrap; gap: 12px; margin-bottom: 20px; }
        .page-title h2 { margin: 0 0 5px 0; font-size: 26px; font-weight: 800; color: #0f172a; }
        .page-title p { margin: 0; color: #64748b; font-size: 15px; }

        .card-container { background: #ffffff; border-radius: 12px; box-shadow: 0 4px 6px -1px rgba(0,0,0,0.05); border: 1px solid #e2e8f0; padding: 25px; border-top: 4px solid #e67e22; overflow-x: auto; }

        .admin-form { background: #fff7ed; padding: 20px; border-radius: 8px; border: 1px solid #ffedd5; margin-bottom: 25px; transition: 0.2s; }
        .admin-form.modo-edicion { background: #eff6ff; border-color: #bfdbfe; }
        .admin-form h3 { margin-top: 0; color: #9a3412; font-size: 16px; border-bottom: 1px solid #fed7aa; padding-bottom: 10px; margin-bottom: 15px; display: flex; justify-content: space-between; align-items: center; }
        .admin-form.modo-edicion h3 { color: #1e40af; border-bottom-color: #bfdbfe; }

        .form-grid { display: grid; grid-template-columns: 1.4fr 0.5fr 1fr 1.1fr 1.3fr auto; gap: 12px; align-items: end; }
        @media (max-width: 980px) { .form-grid { grid-template-columns: 1fr 1fr; } }
        .form-group label { display: block; font-size: 12px; font-weight: 700; color: #9a3412; margin-bottom: 5px; }
        .admin-form.modo-edicion .form-group label { color: #1e40af; }
        .form-group input, .form-group select { width: 100%; padding: 10px; border: 1px solid #fed7aa; border-radius: 6px; font-size: 13px; box-sizing: border-box; background: white; }
        .admin-form.modo-edicion .form-group input, .admin-form.modo-edicion .form-group select { border-color: #93c5fd; }

        .btn-submit { background: #e67e22; color: white; border: none; padding: 10px 18px; border-radius: 6px; font-weight: bold; cursor: pointer; transition: 0.2s; height: 40px; white-space: nowrap; }
        .btn-submit:hover { background: #d35400; }
        .admin-form.modo-edicion .btn-submit { background: #2563eb; }
        .admin-form.modo-edicion .btn-submit:hover { background: #1d4ed8; }

        table { width: 100%; border-collapse: collapse; text-align: left; }
        th { background-color: #f8fafc; padding: 14px 15px; font-size: 12px; color: #64748b; font-weight: 700; text-transform: uppercase; border-bottom: 2px solid #e2e8f0; }
        td { padding: 14px 15px; font-size: 14px; color: #334155; border-bottom: 1px solid #f1f5f9; vertical-align: middle; }
        tr:hover td { background-color: #f8fafc; }

        .badge-cuenta { background: #e0e7ff; color: #3730a3; padding: 5px 10px; border-radius: 6px; font-weight: 800; font-size: 12px; border: 1px solid #c7d2fe; display: inline-block; }
        .badge-sin-cuenta { background: #f1f5f9; color: #64748b; padding: 5px 10px; border-radius: 6px; font-weight: 700; font-size: 12px; border: 1px dashed #cbd5e1; display: inline-block; }
        .badge-ruta { background: #ecfdf5; color: #065f46; padding: 5px 10px; border-radius: 6px; font-weight: 700; font-size: 12px; border: 1px solid #a7f3d0; display: inline-block; margin-bottom: 4px; }

        .btn-edit { background: #eff6ff; color: #2563eb; border: 1px solid #bfdbfe; padding: 6px 10px; border-radius: 6px; font-weight: bold; font-size: 12px; cursor: pointer; transition: 0.2s; }
        .btn-edit:hover { background: #2563eb; color: white; }
        .btn-del { background: #fee2e2; color: #ef4444; border: 1px solid #fca5a5; padding: 6px 10px; border-radius: 6px; font-weight: bold; font-size: 12px; cursor: pointer; transition: 0.2s; }
        .btn-del:hover { background: #ef4444; color: white; }
        .btn-asignar { background: #e0f2fe; color: #0369a1; border: 1px solid #bae6fd; padding: 6px 10px; border-radius: 6px; font-weight: 700; font-size: 12px; cursor: pointer; }
        .btn-asignar:hover { background: #0284c7; color: white; }

        .alerta { padding: 15px; border-radius: 8px; font-weight: 600; margin-bottom: 20px; font-size: 14px; }
        .alerta.error { background: #fef2f2; color: #e74c3c; border: 1px solid #fecaca; }
        .alerta.exito { background: #ecfdf5; color: #10b981; border: 1px solid #a7f3d0; }
    </style>
    <link rel="stylesheet" href="css/transmetro.css">
</head>
<body>
    <jsp:include page="menu_izquierdo.jsp" />
    <jsp:include page="menu_derecho.jsp" />
    <div id="overlay" class="overlay" onclick="closeAllMenus()"></div>

    <div class="header">
        <button class="menu-btn" onclick="toggleMenu('left')">☰</button>
        <h1>Módulo de Flota y Personal</h1>
        <button class="menu-btn" onclick="toggleMenu('right')">⚙️</button>
    </div>

    <%
        List<Map<String, String>> rutasDisponibles = new ArrayList<>();
        try (Connection conR = DriverManager.getConnection(dbUrl, dbUser, dbPass);
             Statement stR = conR.createStatement();
             ResultSet rsR = stR.executeQuery(
                 "SELECT r.id_ruta, r.nombre_ruta, vm.placa AS placa_main " +
                 "FROM rutas_operativas r LEFT JOIN flota_vehiculos vm ON r.id_vehiculo_main = vm.id_vehiculo ORDER BY r.nombre_ruta ASC")) {
            while (rsR.next()) {
                Map<String, String> mr = new HashMap<>();
                mr.put("id", rsR.getString("id_ruta"));
                mr.put("nombre", rsR.getString("nombre_ruta"));
                mr.put("placa", rsR.getString("placa_main") != null ? rsR.getString("placa_main") : "Sin unidad");
                rutasDisponibles.add(mr);
            }
        } catch (Exception ignorar) {}
    %>

    <div class="main-container">
        <div class="page-title">
            <div>
                <h2>🪪 Gestión de Pilotos y Asignación de Rutas</h2>
                <p>Registro y edición de conductores físicos, vinculación con cuenta de usuario y asignación directa a rutas operativas.</p>
            </div>
            <a href="pilotos.jsp" style="background:#e2e8f0; color:#1e293b; padding:9px 15px; border-radius:8px; font-size:13px; font-weight:700; text-decoration:none;">📋 Ver Directorio de Pilotos</a>
        </div>

        <% if (!mensaje.isEmpty()) { %> <div class="alerta <%= tipoMensaje %>"><%= h(mensaje) %></div> <% } %>

        <div class="card-container">
            <div class="admin-form" id="cajaFormularioPiloto">
                <h3>
                    <span id="tituloFormularioPiloto">➕ Registrar Nuevo Piloto y Asignar Ruta</span>
                    <button type="button" id="btnCancelarEdicion" onclick="cancelarEdicionPiloto()" style="display:none; background:#e2e8f0; color:#1e293b; border:none; padding:5px 12px; border-radius:6px; font-size:12px; font-weight:700; cursor:pointer;">✕ Cancelar Edición</button>
                </h3>
                <form method="POST" action="Pilotos-Edicion.jsp" class="form-grid" id="formPiloto">
                    <input type="hidden" name="accion" id="inpAccion" value="crear">
                    <input type="hidden" name="id_piloto" id="inpIdPiloto" value="">

                    <div class="form-group">
                        <label>Nombre Completo</label>
                        <input type="text" name="nombre" id="inpNombre" placeholder="Ej. Carlos Mendoza" required>
                    </div>

                    <div class="form-group">
                        <label>Edad</label>
                        <input type="number" name="edad" id="inpEdad" placeholder="Años" min="18" max="80" required>
                    </div>

                    <div class="form-group">
                        <label>Identificador Transmetro</label>
                        <input type="text" name="identificador_transmetro" id="inpIdentificador" placeholder="Ej. TM-104" required>
                    </div>

                    <div class="form-group">
                        <label>Cuenta de Sistema</label>
                        <select name="usuario_asignado" id="inpUsuario">
                            <option value="Sin asignar">-- Sin cuenta --</option>
                            <%
                                try (Connection conUsr = DriverManager.getConnection(dbUrl, dbUser, dbPass);
                                     Statement stUsr = conUsr.createStatement();
                                     ResultSet rsUsr = stUsr.executeQuery("SELECT username FROM usuarios WHERE rol = 'piloto'")) {
                                    while (rsUsr.next()) {
                                        String usrPiloto = rsUsr.getString("username");
                                        out.print("<option value='" + h(usrPiloto) + "'>👤 " + h(usrPiloto) + "</option>");
                                    }
                                } catch (Exception e) {}
                            %>
                        </select>
                    </div>

                    <div class="form-group">
                        <label>Asignar a Ruta Operativa</label>
                        <select name="id_ruta_asignada" id="inpRuta">
                            <option value="">-- Sin ruta / Asignar después --</option>
                            <% for (Map<String, String> mr : rutasDisponibles) { %>
                                <option value="<%= h(mr.get("id")) %>">🗺️ <%= h(mr.get("nombre")) %> (🚍 <%= h(mr.get("placa")) %>)</option>
                            <% } %>
                        </select>
                    </div>

                    <div class="form-group">
                        <button type="submit" class="btn-submit" id="btnGuardarPiloto">➕ Guardar Piloto</button>
                    </div>
                </form>
            </div>

            <table>
                <thead>
                    <tr>
                        <th>ID</th>
                        <th>Nombre Completo</th>
                        <th>Edad</th>
                        <th>Identificador</th>
                        <th>Cuenta Vinculada</th>
                        <th>Ruta y Unidad Asignada</th>
                        <th style="text-align: center;">Acciones</th>
                    </tr>
                </thead>
                <tbody>
                    <%
                        try (Connection con = DriverManager.getConnection(dbUrl, dbUser, dbPass);
                             Statement st = con.createStatement();
                             ResultSet rs = st.executeQuery(
                                 "SELECT p.id, IFNULL(p.nombre, '') AS nombre, IFNULL(p.edad, 0) AS edad, " +
                                 "IFNULL(p.identificador_transmetro, 'Sin ID') AS identificador_transmetro, " +
                                 "IFNULL(p.usuario_asignado, 'Sin asignar') AS usuario_asignado, " +
                                 "(SELECT r.id_ruta FROM rutas_operativas r WHERE r.id_piloto = p.id LIMIT 1) AS id_ruta_actual, " +
                                 "(SELECT GROUP_CONCAT(CONCAT(r.nombre_ruta, ' (🚍 ', IFNULL(vm.placa, 'S/P'), ')') SEPARATOR ' | ') " +
                                 " FROM rutas_operativas r LEFT JOIN flota_vehiculos vm ON r.id_vehiculo_main = vm.id_vehiculo WHERE r.id_piloto = p.id) AS detalle_rutas " +
                                 "FROM pilotos_catalogo p ORDER BY p.id DESC")) {

                            boolean hayPilotos = false;
                            while (rs.next()) {
                                hayPilotos = true;
                                int id = rs.getInt("id");
                                String nombre = rs.getString("nombre");
                                int edad = rs.getInt("edad");
                                String identificador = rs.getString("identificador_transmetro");
                                String usrAsignado = rs.getString("usuario_asignado");
                                int idRutaAct = rs.getObject("id_ruta_actual") != null ? rs.getInt("id_ruta_actual") : 0;
                                String detalleRutas = rs.getString("detalle_rutas");
                    %>
                                <tr>
                                    <td style="font-weight: bold; color: #94a3b8;">#<%= id %></td>
                                    <td style="font-weight: 700; color: #1e293b; font-size: 15px;">👨‍✈️ <%= h(nombre) %></td>
                                    <td><%= edad %> años</td>
                                    <td>💳 <%= h(identificador) %></td>
                                    <td>
                                        <% if (usrAsignado.equals("Sin asignar") || usrAsignado.isEmpty()) { %>
                                            <span class="badge-sin-cuenta">⚠️ Sin cuenta</span>
                                        <% } else { %>
                                            <span class="badge-cuenta">👤 <%= h(usrAsignado) %></span>
                                        <% } %>
                                    </td>
                                    <td>
                                        <% if (detalleRutas != null && !detalleRutas.isEmpty()) { %>
                                            <div class="badge-ruta">🗺️ <%= h(detalleRutas) %></div>
                                        <% } else { %>
                                            <div style="font-size:12px; color:#94a3b8; margin-bottom:4px;">Sin ruta activa</div>
                                        <% } %>
                                        <form method="POST" action="Pilotos-Edicion.jsp" style="display:flex; gap:6px; align-items:center; margin:0;">
                                            <input type="hidden" name="accion" value="asignar_ruta">
                                            <input type="hidden" name="id_piloto" value="<%= id %>">
                                            <select name="id_ruta" style="padding:4px 8px; border:1px solid #cbd5e1; border-radius:6px; font-size:12px;">
                                                <option value="">-- Sin ruta --</option>
                                                <% for (Map<String, String> mr : rutasDisponibles) {
                                                    int idR = Integer.parseInt(mr.get("id"));
                                                    String sel = (idR == idRutaAct) ? "selected" : "";
                                                %>
                                                    <option value="<%= idR %>" <%= sel %>><%= h(mr.get("nombre")) %> (<%= h(mr.get("placa")) %>)</option>
                                                <% } %>
                                            </select>
                                            <button type="submit" class="btn-asignar">Vincular</button>
                                        </form>
                                    </td>
                                    <td style="text-align: center;">
                                        <div style="display:flex; gap:6px; justify-content:center; align-items:center;">
                                            <button type="button" class="btn-edit"
                                                onclick="cargarEdicionPiloto('<%= id %>', '<%= js(nombre) %>', '<%= edad %>', '<%= js(identificador) %>', '<%= js(usrAsignado) %>', '<%= idRutaAct > 0 ? idRutaAct : "" %>')">
                                                ✏️ Editar
                                            </button>
                                            <form method="POST" action="Pilotos-Edicion.jsp" style="margin: 0;" onsubmit="return confirm('¿Está seguro de eliminar a <%= js(nombre) %> del catálogo?');">
                                                <input type="hidden" name="accion" value="eliminar">
                                                <input type="hidden" name="id_piloto" value="<%= id %>">
                                                <button type="submit" class="btn-del">🗑️ Eliminar</button>
                                            </form>
                                        </div>
                                    </td>
                                </tr>
                    <%
                            }
                            if (!hayPilotos) {
                                out.print("<tr><td colspan='7' style='text-align:center; padding:25px; color:#94a3b8;'>No hay pilotos registrados en el catálogo.</td></tr>");
                            }
                        } catch (Exception e) {
                            out.print("<tr><td colspan='7'>Error: " + h(e.getMessage()) + "</td></tr>");
                        }
                    %>
                </tbody>
            </table>
        </div>
    </div>

    <script>
        function cargarEdicionPiloto(id, nombre, edad, identificador, usuario, idRuta) {
            document.getElementById("cajaFormularioPiloto").classList.add("modo-edicion");
            document.getElementById("tituloFormularioPiloto").textContent = "✏️ Editando Piloto #" + id + ": " + nombre;
            document.getElementById("btnCancelarEdicion").style.display = "inline-block";
            document.getElementById("inpAccion").value = "editar";
            document.getElementById("inpIdPiloto").value = id;
            document.getElementById("inpNombre").value = nombre;
            document.getElementById("inpEdad").value = edad;
            document.getElementById("inpIdentificador").value = identificador;
            document.getElementById("inpUsuario").value = usuario || "Sin asignar";
            document.getElementById("inpRuta").value = idRuta || "";
            document.getElementById("btnGuardarPiloto").textContent = "💾 Guardar Cambios";
            window.scrollTo({ top: 0, behavior: "smooth" });
        }

        function cancelarEdicionPiloto() {
            document.getElementById("cajaFormularioPiloto").classList.remove("modo-edicion");
            document.getElementById("tituloFormularioPiloto").textContent = "➕ Registrar Nuevo Piloto y Asignar Ruta";
            document.getElementById("btnCancelarEdicion").style.display = "none";
            document.getElementById("inpAccion").value = "crear";
            document.getElementById("inpIdPiloto").value = "";
            document.getElementById("inpNombre").value = "";
            document.getElementById("inpEdad").value = "";
            document.getElementById("inpIdentificador").value = "";
            document.getElementById("inpUsuario").value = "Sin asignar";
            document.getElementById("inpRuta").value = "";
            document.getElementById("btnGuardarPiloto").textContent = "➕ Guardar Piloto";
        }

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