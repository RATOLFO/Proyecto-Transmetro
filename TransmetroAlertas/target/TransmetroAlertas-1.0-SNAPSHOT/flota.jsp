<%@page contentType="text/html" pageEncoding="UTF-8"%>
<%@page import="java.sql.*"%>
<%@page import="java.util.*"%>
<%!
    // Método auxiliar para proteger texto de ataques XSS y evitar errores de nulos
    static String h(String s) {
        if (s == null) return "";
        return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace("\"", "&quot;").replace("'", "&#39;");
    }
%>
<%
    // Cualquier usuario autenticado (pasajero, piloto o admin) puede consultar la flota.
    // Solo el administrador puede editar o eliminar unidades.
    if (session.getAttribute("usuarioValido") == null) {
        response.sendRedirect("login.jsp");
        return;
    }

    String rolActual = (String) session.getAttribute("rol");
    if (rolActual == null) rolActual = "pasajero";
    boolean esAdmin = "admin".equals(rolActual);

    String dbUrl = "jdbc:mysql://192.168.15.135:3306/transmetro_db"; 
    String dbUser = "admin"; String dbPass = "admin123";
    String mensaje = "";
    String tipoMensaje = "exito";

    // -------------------------------------------------------------------------
    // LÓGICA DE PROCESAMIENTO: ACTUALIZACIÓN (POST) O ELIMINACIÓN (SOLO ADMIN)
    // -------------------------------------------------------------------------
    if ("POST".equalsIgnoreCase(request.getMethod()) && esAdmin) {
        request.setCharacterEncoding("UTF-8");
        String accion = request.getParameter("accion");
        try {
            Class.forName("com.mysql.cj.jdbc.Driver");
            Connection con = DriverManager.getConnection(dbUrl, dbUser, dbPass);

            // ACCIÓN: ELIMINAR BUS
            if ("eliminar".equals(accion)) {
                int idBus = Integer.parseInt(request.getParameter("id_vehiculo"));

                PreparedStatement psVerificar = con.prepareStatement(
                    "SELECT COUNT(*) FROM rutas_operativas WHERE id_vehiculo_main = ? OR id_vehiculo_backup = ? OR id_vehiculo_extra = ?"
                );
                psVerificar.setInt(1, idBus); psVerificar.setInt(2, idBus); psVerificar.setInt(3, idBus);
                ResultSet rsV = psVerificar.executeQuery();
                int enUso = 0;
                if(rsV.next()) enUso = rsV.getInt(1);
                rsV.close(); psVerificar.close();

                if(enUso > 0) {
                    mensaje = "❌ No se puede eliminar: El bus está asignado a una ruta logística activa.";
                    tipoMensaje = "error";
                } else {
                    PreparedStatement psDelAsientos = con.prepareStatement("DELETE FROM asientos WHERE id_bus = ?");
                    psDelAsientos.setInt(1, idBus);
                    psDelAsientos.executeUpdate();
                    psDelAsientos.close();

                    PreparedStatement psDelBus = con.prepareStatement("DELETE FROM flota_vehiculos WHERE id_vehiculo = ?");
                    psDelBus.setInt(1, idBus);
                    psDelBus.executeUpdate();
                    psDelBus.close();
                    
                    mensaje = "🗑️ Unidad eliminada exitosamente del garaje.";
                    tipoMensaje = "exito";
                }
            } 
            // ACCIÓN: GUARDAR EDICIÓN DEL BUS
            else if ("editar".equals(accion)) {
                int idBus = Integer.parseInt(request.getParameter("id_vehiculo"));
                String nuevaPlaca = request.getParameter("placa");
                String nuevoEstado = request.getParameter("estado");
                int nuevoParqueo = Integer.parseInt(request.getParameter("id_parqueo"));
                String nuevaMuni = request.getParameter("municipalidad");
                
                // --- REGLA LOGÍSTICA: MANTENIMIENTO SEGURO Y ALERTA AUTOMÁTICA ---
                boolean bloqueadoPorMantenimiento = false;
                if ("Mantenimiento".equals(nuevoEstado)) {
                    PreparedStatement psEnUso = con.prepareStatement(
                        "SELECT r.nombre_ruta FROM rutas_operativas r " +
                        "WHERE r.id_vehiculo_main = ? OR r.id_vehiculo_backup = ? OR r.id_vehiculo_extra = ?"
                    );
                    psEnUso.setInt(1, idBus); psEnUso.setInt(2, idBus); psEnUso.setInt(3, idBus);
                    ResultSet rsEnUso = psEnUso.executeQuery();
                    
                    if(rsEnUso.next()) {
                        String rutaAfectada = rsEnUso.getString("nombre_ruta");
                        mensaje = "❌ Error crítico: El bus '" + h(nuevaPlaca) + "' no puede enviarse a mantenimiento porque está operando en la ruta '" + h(rutaAfectada) + "'. Asígnele un relevo en la Gestión de Rutas primero.";
                        tipoMensaje = "error";
                        bloqueadoPorMantenimiento = true;
                        
                        try {
                            String descAuto = "⚠️ ATENCIÓN: Se intentó enviar el bus al taller, pero está operando actualmente. Se requiere ir a Gestión de Rutas y asignarle un relevo urgente para liberarlo.";
                            String rutaAuto = nuevaPlaca + " - " + rutaAfectada;
                            
                            PreparedStatement psAlerta = con.prepareStatement(
                                "INSERT INTO alertas (tipo_gravedad, bus_ruta, descripcion, reportado_por, estado, audiencia) " +
                                "VALUES ('Logistica', ?, ?, 'Sistema Automático (Flota)', 'Activa', 'interna')"
                            );
                            psAlerta.setString(1, rutaAuto);
                            psAlerta.setString(2, descAuto);
                            psAlerta.executeUpdate();
                            psAlerta.close();
                        } catch(Exception exAlerta) {
                            System.out.println("Error creando alerta auto: " + exAlerta.getMessage());
                        }
                    }
                    rsEnUso.close(); psEnUso.close();
                }
                
                // Si pasó la validación, guardamos los cambios
                if (!bloqueadoPorMantenimiento) {
                    PreparedStatement psUpdate = con.prepareStatement(
                        "UPDATE flota_vehiculos SET placa = ?, estado = ?, id_parqueo = ?, municipalidad = ? WHERE id_vehiculo = ?"
                    );
                    psUpdate.setString(1, nuevaPlaca);
                    psUpdate.setString(2, nuevoEstado);
                    psUpdate.setInt(3, nuevoParqueo);
                    psUpdate.setString(4, nuevaMuni);
                    psUpdate.setInt(5, idBus);
                    
                    psUpdate.executeUpdate();
                    psUpdate.close();
                    
                    mensaje = "✅ Datos del bus '" + h(nuevaPlaca) + "' actualizados correctamente.";
                    tipoMensaje = "exito";
                }
            }
            con.close();
        } catch(Exception e) { 
            mensaje = "❌ Error al procesar solicitud: " + e.getMessage(); 
            tipoMensaje = "error";
        }
    }

    // -------------------------------------------------------------------------
    // LÓGICA DE EDICIÓN: OBTENER DATOS (GET, SOLO ADMIN)
    // -------------------------------------------------------------------------
    boolean modoEdicion = esAdmin && "cargar_editar".equals(request.getParameter("accion"));
    int idBusEdicion = 0;
    if (modoEdicion && request.getParameter("id") != null) {
        try { idBusEdicion = Integer.parseInt(request.getParameter("id")); } catch (Exception ig) {}
    }

    String filtroMuni = request.getParameter("muni");
    if (filtroMuni != null) filtroMuni = filtroMuni.trim();

    // Estadísticas y catálogo de municipalidades
    int totUnidades = 0, totEnRuta = 0, totLibres = 0, totTaller = 0;
    Set<String> todasMunis = new LinkedHashSet<>();
    Map<String, Integer> conteoBusesMuni = new LinkedHashMap<>();

    try {
        Class.forName("com.mysql.cj.jdbc.Driver");
        try (Connection conStats = DriverManager.getConnection(dbUrl, dbUser, dbPass);
             Statement stS = conStats.createStatement()) {

            try (ResultSet rsM = stS.executeQuery("SELECT nombre FROM municipalidades ORDER BY nombre")) {
                while (rsM.next()) {
                    String nm = rsM.getString(1);
                    if (nm != null && !nm.trim().isEmpty()) {
                        todasMunis.add(nm.trim());
                        conteoBusesMuni.putIfAbsent(nm.trim(), 0);
                    }
                }
            } catch (Exception ig) {}

            try (ResultSet rsF = stS.executeQuery(
                    "SELECT f.id_vehiculo, f.estado, f.municipalidad, " +
                    "(SELECT COUNT(*) FROM rutas_operativas r WHERE r.id_vehiculo_main = f.id_vehiculo OR r.id_vehiculo_backup = f.id_vehiculo OR r.id_vehiculo_extra = f.id_vehiculo) AS en_ruta " +
                    "FROM flota_vehiculos f")) {
                while (rsF.next()) {
                    totUnidades++;
                    String est = rsF.getString("estado") != null ? rsF.getString("estado") : "";
                    int enR = rsF.getInt("en_ruta");
                    if (est.contains("Mantenimiento")) totTaller++;
                    else if (enR > 0 || est.contains("Ruta")) totEnRuta++;
                    else totLibres++;

                    String m = rsF.getString("municipalidad");
                    if (m != null && !m.trim().isEmpty()) {
                        String mTrim = m.trim();
                        todasMunis.add(mTrim);
                        conteoBusesMuni.put(mTrim, conteoBusesMuni.getOrDefault(mTrim, 0) + 1);
                    }
                }
            } catch (Exception ig) {}
        }
    } catch (Exception ig) {}
%>

<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Flota de Unidades — Transmetro GT</title>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&display=swap" rel="stylesheet">
    <style>
        * { box-sizing: border-box; }
        body { font-family: 'Inter', sans-serif; background-color: #f8fafc; margin: 0; padding-top: 70px; color: #0f172a; }
        .header { background: #ffffff; padding: 15px 25px; position: fixed; top: 0; width: 100%; box-sizing: border-box; z-index: 1000; display: flex; justify-content: space-between; align-items: center; border-bottom: 1px solid #e2e8f0; }
        .header h1 { margin: 0; font-size: 17px; text-align: center; flex-grow: 1; font-weight: 800; color: #0f172a; }
        .menu-btn { background: none; border: none; font-size: 24px; cursor: pointer; color: #475569; }
        .overlay { display: none; position: fixed; width: 100%; height: 100%; top: 0; left: 0; background: rgba(15, 23, 42, 0.4); z-index: 999; }
        
        .main-container { max-width: 1180px; margin: 26px auto 60px auto; padding: 0 20px; }
        .page-title { display: flex; justify-content: space-between; align-items: flex-start; flex-wrap: wrap; gap: 14px; margin-bottom: 22px; }
        .page-title h2 { margin: 0 0 5px 0; font-size: 25px; font-weight: 800; color: #0f172a; letter-spacing: -0.02em; }
        .page-title p { margin: 0; color: #64748b; font-size: 14px; }

        .btn-top-action {
            background: #0d9488;
            color: #ffffff;
            text-decoration: none;
            padding: 10px 16px;
            border-radius: 10px;
            font-weight: 700;
            font-size: 13px;
            display: inline-flex;
            align-items: center;
            gap: 6px;
            transition: 0.18s;
        }
        .btn-top-action:hover { background: #0f766e; transform: translateY(-1px); }

        /* KPIs de resumen */
        .kpi-row {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(185px, 1fr));
            gap: 14px;
            margin-bottom: 18px;
        }
        .kpi-card {
            background: #ffffff;
            border: 1px solid #e2e8f0;
            border-radius: 14px;
            padding: 16px 18px;
            display: flex;
            flex-direction: column;
            gap: 4px;
        }
        .kpi-card .k-num { font-size: 26px; font-weight: 800; color: #0f172a; line-height: 1.1; }
        .kpi-card .k-lbl { font-size: 11.5px; font-weight: 700; color: #64748b; text-transform: uppercase; letter-spacing: 0.04em; }

        /* Barra de filtro por municipalidad */
        .muni-filter-bar {
            background: #ffffff;
            border: 1px solid #e2e8f0;
            border-radius: 14px;
            padding: 13px 18px;
            margin-bottom: 20px;
            display: flex;
            flex-wrap: wrap;
            gap: 8px;
            align-items: center;
        }
        .muni-pill {
            background: #f8fafc;
            border: 1px solid #e2e8f0;
            color: #334155;
            padding: 6px 12px;
            border-radius: 999px;
            font-size: 12px;
            font-weight: 600;
            text-decoration: none;
            transition: 0.16s;
            display: inline-flex;
            align-items: center;
            gap: 5px;
        }
        .muni-pill:hover { background: #f1f5f9; border-color: #cbd5e1; }
        .muni-pill.active { background: #0d9488; color: #ffffff; border-color: #0d9488; }

        .alerta { padding: 15px; border-radius: 10px; font-weight: 600; margin-bottom: 20px; font-size: 14px; }
        .exito { background: #ecfdf5; color: #065f46; border: 1px solid #a7f3d0; }
        .error { background: #fef2f2; color: #991b1b; border: 1px solid #fecaca; }

        .card { background: white; border-radius: 14px; padding: 22px; border: 1px solid #e2e8f0; box-shadow: 0 2px 8px rgba(15, 23, 42, 0.03); margin-bottom: 30px; overflow-x: auto; }
        
        table { width: 100%; border-collapse: collapse; text-align: left; }
        th { background-color: #f8fafc; padding: 13px 12px; font-size: 11.5px; color: #64748b; text-transform: uppercase; letter-spacing: 0.04em; border-bottom: 2px solid #e2e8f0; }
        td { padding: 14px 12px; font-size: 13.5px; border-bottom: 1px solid #f1f5f9; color: #334155; vertical-align: middle; }
        tr:hover td { background-color: #f8fafc; }
        
        .badge { padding: 5px 10px; border-radius: 6px; font-size: 11.5px; font-weight: 700; display: inline-block; }
        .badge-libre { background: #dcfce7; color: #166534; }
        .badge-operando { background: #e0f2fe; color: #0369a1; }
        .badge-mantenimiento { background: #fef2f2; color: #dc2626; }
        .badge-parqueo { background: #f1f5f9; color: #475569; border: 1px solid #cbd5e1; }
        .badge-ruta { background: #f0fdfa; color: #0f766e; border: 1px solid #99f6e4; }
        .placa-box { background: #0f172a; color: white; padding: 4px 9px; border-radius: 6px; font-family: monospace; font-size: 13px; letter-spacing: 0.8px; font-weight: 700; }

        .form-section { background: #f8fafc; padding: 20px; border-radius: 10px; border: 1px solid #e2e8f0; }
        .form-section h3 { margin-top: 0; color: #1e293b; border-bottom: 1px solid #cbd5e1; padding-bottom: 10px; margin-bottom: 15px; font-size: 16px; }
        .form-group { margin-bottom: 15px; }
        .form-group label { display: block; font-size: 12.5px; font-weight: 700; color: #475569; margin-bottom: 5px; }
        .form-group input, .form-group select { width: 100%; padding: 11px; border: 1px solid #cbd5e1; border-radius: 8px; box-sizing: border-box; background: white; font-family: inherit; }
        .grid-4 { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 15px; align-items: end; }
        
        .btn-submit { background: #0d9488; color: white; border: none; padding: 11px 20px; border-radius: 8px; font-weight: 700; cursor: pointer; transition: 0.2s; }
        .btn-submit:hover { background: #0f766e; }
        .btn-cancelar { display: inline-block; background: #64748b; color: white; border: none; padding: 11px 18px; border-radius: 8px; font-weight: 700; text-decoration: none; text-align: center; margin-left: 8px; font-size: 13.5px; }

        .acciones-td { display: flex; gap: 8px; align-items: center; justify-content: center; }
        .btn-edit { background: #e0f2fe; color: #0284c7; border: 1px solid #bae6fd; padding: 6px 11px; border-radius: 6px; font-weight: 700; cursor: pointer; text-decoration: none; font-size: 12px; }
        .btn-edit:hover { background: #0284c7; color: white; }
        .btn-del { background: #fee2e2; color: #ef4444; border: 1px solid #fca5a5; padding: 6px 10px; border-radius: 6px; font-weight: 700; cursor: pointer; font-size: 12px; font-family: inherit; }
        .btn-del:hover { background: #ef4444; color: white; }
    </style>
    <link rel="stylesheet" href="css/transmetro.css">
</head>
<body>
    <jsp:include page="menu_izquierdo.jsp" />
    <jsp:include page="menu_derecho.jsp" />
    <div id="overlay" class="overlay" onclick="closeAllMenus()"></div>

    <div class="header">
        <button class="menu-btn" onclick="toggleMenu('left')">☰</button>
        <h1>Directorio e Inventario de Flota</h1>
        <% if (esAdmin) { %>
            <button class="menu-btn" onclick="toggleMenu('right')">⚙️</button>
        <% } else { %>
            <div style="width: 34px;"></div>
        <% } %>
    </div>

    <div class="main-container">
        <div class="page-title">
            <div>
                <h2>🚌 Flota Oficial de Unidades Transmetro</h2>
                <p>Consulta las unidades registradas, su municipalidad, capacidad de asientos, parqueo base y línea asignada.</p>
            </div>
            <% if (esAdmin) { %>
                <a href="admin_buses.jsp" class="btn-top-action">➕ Registrar Nueva Unidad</a>
            <% } %>
        </div>

        <!-- RESUMEN KPI DE LA FLOTA -->
        <div class="kpi-row">
            <div class="kpi-card">
                <div class="k-num"><%= totUnidades %></div>
                <div class="k-lbl">🚍 Unidades Totales</div>
            </div>
            <div class="kpi-card">
                <div class="k-num" style="color:#0284c7;"><%= totEnRuta %></div>
                <div class="k-lbl">🛣️ Operando en Ruta</div>
            </div>
            <div class="kpi-card">
                <div class="k-num" style="color:#16a34a;"><%= totLibres %></div>
                <div class="k-lbl">🅿️ Libres en Garaje</div>
            </div>
            <div class="kpi-card">
                <div class="k-num" style="color:#dc2626;"><%= totTaller %></div>
                <div class="k-lbl">🔧 En Mantenimiento</div>
            </div>
            <div class="kpi-card">
                <div class="k-num" style="color:#0d9488;"><%= todasMunis.size() %></div>
                <div class="k-lbl">🏛️ Municipalidades</div>
            </div>
        </div>

        <!-- FILTRO POR MUNICIPALIDAD -->
        <div class="muni-filter-bar">
            <span style="font-size:11px; font-weight:800; color:#64748b; text-transform:uppercase; letter-spacing:0.05em; margin-right:4px;">🏛️ Filtrar por Municipalidad:</span>
            <a href="flota.jsp" class="muni-pill <%= (filtroMuni == null || filtroMuni.isEmpty()) ? "active" : "" %>">Todas (<%= totUnidades %>)</a>
            <% for (String mItem : todasMunis) {
                   boolean act = (filtroMuni != null && filtroMuni.equalsIgnoreCase(mItem));
                   int cBus = conteoBusesMuni.getOrDefault(mItem, 0);
            %>
                <a href="flota.jsp?muni=<%= java.net.URLEncoder.encode(mItem, "UTF-8") %>" class="muni-pill <%= act ? "active" : "" %>">
                    <span>🏛️ <%= h(mItem) %></span>
                    <span style="font-size:10.5px; opacity:0.85;">(<%= cBus > 0 ? cBus + " bus" + (cBus == 1 ? "" : "es") : "🆕 Catálogo" %>)</span>
                </a>
            <% } %>
        </div>

        <% if(!mensaje.isEmpty()) { %> <div class="alerta <%= tipoMensaje %>"><%= mensaje %></div> <% } %>

        <%-- FORMULARIO DE EDICIÓN (SOLO ADMIN) --%>
        <% if(modoEdicion) { 
            try {
                Class.forName("com.mysql.cj.jdbc.Driver");
                Connection conEdit = DriverManager.getConnection(dbUrl, dbUser, dbPass);
                PreparedStatement psEdit = conEdit.prepareStatement("SELECT * FROM flota_vehiculos WHERE id_vehiculo = ?");
                psEdit.setInt(1, idBusEdicion);
                ResultSet rsEdit = psEdit.executeQuery();
                
                if(rsEdit.next()) {
        %>
            <div class="card" style="border-top: 4px solid #d97706; background: #fffbeb;">
                <div class="form-section">
                    <h3>✏️ Modificar Información del Bus #<%= idBusEdicion %></h3>
                    <form method="POST" action="flota.jsp" class="grid-4">
                        <input type="hidden" name="accion" value="editar">
                        <input type="hidden" name="id_vehiculo" value="<%= idBusEdicion %>">
                        
                        <div class="form-group">
                            <label>Placa de Matrícula</label>
                            <input type="text" name="placa" value="<%= h(rsEdit.getString("placa")) %>" required>
                        </div>

                        <div class="form-group">
                            <label>Jurisdicción / Municipalidad</label>
                            <select name="municipalidad" required>
                                <%
                                    Statement stMuni = conEdit.createStatement();
                                    ResultSet rsMuni = stMuni.executeQuery("SELECT nombre FROM municipalidades ORDER BY nombre");
                                    while(rsMuni.next()) {
                                        String mName = rsMuni.getString("nombre");
                                        String mSelected = mName.equals(rsEdit.getString("municipalidad")) ? "selected" : "";
                                        out.print("<option value='" + h(mName) + "' " + mSelected + ">🏛️ " + h(mName) + "</option>");
                                    }
                                    rsMuni.close(); stMuni.close();
                                %>
                            </select>
                        </div>
                        
                        <div class="form-group">
                            <label>Estado Operativo</label>
                            <select name="estado" required>
                                <option value="Libre en Garaje" <%= "Libre en Garaje".equals(rsEdit.getString("estado")) ? "selected" : "" %>>Libre en Garaje</option>
                                <option value="Mantenimiento" <%= "Mantenimiento".equals(rsEdit.getString("estado")) ? "selected" : "" %>>Mantenimiento Técnico</option>
                            </select>
                        </div>
                        
                        <div class="form-group">
                            <label>Asignación de Parqueo</label>
                            <select name="id_parqueo" required>
                                <%
                                    Statement stParq = conEdit.createStatement();
                                    ResultSet rsParq = stParq.executeQuery("SELECT id_parqueo, nombre FROM parqueos ORDER BY nombre");
                                    while(rsParq.next()) {
                                        int pId = rsParq.getInt("id_parqueo");
                                        String pSelected = (pId == rsEdit.getInt("id_parqueo")) ? "selected" : "";
                                        out.print("<option value='" + pId + "' " + pSelected + ">🅿️ " + h(rsParq.getString("nombre")) + "</option>");
                                    }
                                    rsParq.close(); stParq.close();
                                %>
                            </select>
                        </div>
                        
                        <div class="form-group" style="grid-column: 1 / -1; margin-bottom: 0;">
                            <button type="submit" class="btn-submit">💾 Guardar Cambios</button>
                            <a href="flota.jsp" class="btn-cancelar">Cancelar</a>
                        </div>
                    </form>
                </div>
            </div>
        <%
                }
                rsEdit.close(); psEdit.close(); conEdit.close();
            } catch(Exception e) { out.print("Error cargando el bus: " + h(e.getMessage())); }
        } %>

        <%-- TABLA DE INVENTARIO GENERAL --%>
        <div class="card">
            <table>
                <thead>
                    <tr>
                        <th>Unidad / Placa</th>
                        <th>Jurisdicción Municipal</th>
                        <th>Capacidad / Ocupación</th>
                        <th>Parqueo Base (RN04)</th>
                        <th>Línea Asignada</th>
                        <th>Estado Operativo</th>
                        <% if (esAdmin) { %>
                            <th style="text-align: center;">Acciones</th>
                        <% } %>
                    </tr>
                </thead>
                <tbody>
                    <%
                        try {
                            Class.forName("com.mysql.cj.jdbc.Driver");
                            Connection con = DriverManager.getConnection(dbUrl, dbUser, dbPass);
                            Statement st = con.createStatement();
                            
                            String whereMuni = "";
                            if (filtroMuni != null && !filtroMuni.isEmpty()) {
                                whereMuni = " WHERE f.municipalidad = '" + filtroMuni.replace("'", "''") + "' ";
                            }

                            String query = "SELECT f.id_vehiculo, f.placa, f.capacidad, f.estado, f.municipalidad, p.nombre as parqueo, " +
                                           "(SELECT COALESCE(SUM(CASE WHEN a.estado != 'libre' THEN 1 ELSE 0 END), 0) FROM asientos a WHERE a.id_bus = f.id_vehiculo) AS ocupados, " +
                                           "(SELECT GROUP_CONCAT(CONCAT(r.nombre_ruta, ' (', " +
                                           "  CASE WHEN r.id_vehiculo_main = f.id_vehiculo THEN 'Principal' " +
                                           "       WHEN r.id_vehiculo_backup = f.id_vehiculo THEN 'Refuerzo' " +
                                           "       ELSE '2do Refuerzo' END, ')') SEPARATOR ', ') " +
                                           " FROM rutas_operativas r " +
                                           " WHERE r.id_vehiculo_main = f.id_vehiculo OR r.id_vehiculo_backup = f.id_vehiculo OR r.id_vehiculo_extra = f.id_vehiculo) AS ruta_actual " +
                                           "FROM flota_vehiculos f " +
                                           "LEFT JOIN parqueos p ON f.id_parqueo = p.id_parqueo " +
                                           whereMuni +
                                           "ORDER BY f.id_vehiculo DESC";
                                           
                            ResultSet rs = st.executeQuery(query);
                            boolean hayDatos = false;

                            while (rs.next()) {
                                hayDatos = true;
                                int idVehiculo = rs.getInt("id_vehiculo");
                                String estado = rs.getString("estado");
                                String rutaActual = rs.getString("ruta_actual");
                                int cap = rs.getInt("capacidad");
                                int ocu = rs.getInt("ocupados");
                                String claseEstado = "badge-libre";
                                
                                if (estado != null) {
                                    if (estado.contains("Mantenimiento")) claseEstado = "badge-mantenimiento";
                                    else if ((rutaActual != null && !rutaActual.isEmpty()) || estado.contains("Ruta") || estado.contains("Refuerzo") || estado.contains("Extra")) {
                                        claseEstado = "badge-operando";
                                        if ("Libre en Garaje".equals(estado) && rutaActual != null && !rutaActual.isEmpty()) {
                                            estado = "Asignado a Ruta";
                                        }
                                    }
                                } else {
                                    estado = "Operativo";
                                }
                                
                                String nombreParqueo = rs.getString("parqueo");
                                if (nombreParqueo == null) nombreParqueo = "Sin Predio Asignado";
                                String muni = rs.getString("municipalidad");
                    %>
                                <tr>
                                    <td>
                                        <span style="color:#64748b; font-size:12px; font-weight:700; margin-right:6px;">#<%= idVehiculo %></span>
                                        <span class="placa-box"><%= h(rs.getString("placa")) %></span>
                                    </td>
                                    <td style="font-weight: 600;">🏛️ <%= h(muni != null ? muni : "General") %></td>
                                    <td>
                                        <strong>💺 <%= cap %> asientos</strong>
                                        <div style="font-size:11.5px; color:#64748b;">Ocupados: <%= ocu %> / <%= cap %></div>
                                    </td>
                                    <td><span class="badge badge-parqueo">🅿️ <%= h(nombreParqueo) %></span></td>
                                    <td>
                                        <% if (rutaActual != null && !rutaActual.isEmpty()) { %>
                                            <span class="badge badge-ruta">🗺️ <%= h(rutaActual) %></span>
                                        <% } else { %>
                                            <span style="color:#94a3b8; font-size:12.5px;">En reserva (Garaje)</span>
                                        <% } %>
                                    </td>
                                    <td><span class="badge <%= claseEstado %>"><%= h(estado) %></span></td>
                                    
                                    <% if (esAdmin) { %>
                                        <td class="acciones-td">
                                            <a href="flota.jsp?accion=cargar_editar&id=<%= idVehiculo %>" class="btn-edit">✏️ Editar</a>
                                            <form method="POST" action="flota.jsp" style="margin: 0;" onsubmit="return confirm('¿Seguro que deseas eliminar este bus del inventario?');">
                                                <input type="hidden" name="accion" value="eliminar">
                                                <input type="hidden" name="id_vehiculo" value="<%= idVehiculo %>">
                                                <button type="submit" class="btn-del" title="Eliminar unidad">🗑️</button>
                                            </form>
                                        </td>
                                    <% } %>
                                </tr>
                    <%
                            }
                            if(!hayDatos) {
                                int cols = esAdmin ? 7 : 6;
                                if (filtroMuni != null && !filtroMuni.isEmpty()) {
                                    out.print("<tr><td colspan='" + cols + "' style='text-align:center; padding: 36px; color:#64748b;'>🏛️ La municipalidad <b>" + h(filtroMuni) + "</b> está registrada en el catálogo, pero aún no tiene unidades de flota asignadas.</td></tr>");
                                } else {
                                    out.print("<tr><td colspan='" + cols + "' style='text-align:center; padding: 36px; color:#94a3b8; font-weight:600;'>El garaje está vacío.</td></tr>");
                                }
                            }
                            rs.close(); st.close(); con.close();
                        } catch (Exception e) {
                            out.print("<tr><td colspan='7'>Error BD: " + h(e.getMessage()) + "</td></tr>");
                        }
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
