<%@page contentType="text/html" pageEncoding="UTF-8"%>
<%@page import="java.sql.*"%>
<%@page import="java.util.*"%>
<%!
    static String h(String s) {
        if (s == null) return "";
        return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace("\"", "&quot;").replace("'", "&#39;");
    }
%>
<%
    if (session.getAttribute("usuarioValido") == null) { response.sendRedirect("login.jsp"); return; }

    String rolActual = (String) session.getAttribute("rol");
    String nombreUsuario = (String) session.getAttribute("nombre");
    if (rolActual == null) rolActual = "pasajero";

    boolean isAdmin = "admin".equals(rolActual);
    boolean isPiloto = "piloto".equals(rolActual);
    boolean isPasajero = "pasajero".equals(rolActual);

    String dbUrl = "jdbc:mysql://192.168.15.135:3306/transmetro_db";
    String dbUser = "admin";
    String dbPass = "admin123";

    int totalFlota = 0, busesOperando = 0, rutasActivas = 0;
    int alertasTotales = 0, alertasPublicas = 0;
    int asientosTotalesRed = 0, asientosOcupadosRed = 0;
    java.math.BigDecimal kmRed = java.math.BigDecimal.ZERO;
    int totGuardias = 0, totParqueos = 0, totEstaciones = 0, totMunis = 0;

    List<Map<String, String>> resumenRutas = new ArrayList<>();
    Set<String> listaMunisActivas = new LinkedHashSet<>();

    try {
        Class.forName("com.mysql.cj.jdbc.Driver");
        Connection con = DriverManager.getConnection(dbUrl, dbUser, dbPass);
        Statement st = con.createStatement();

        ResultSet rsRutas = st.executeQuery("SELECT COUNT(*) AS total FROM rutas_operativas");
        if (rsRutas.next()) rutasActivas = rsRutas.getInt("total");
        rsRutas.close();

        ResultSet rsFlota = st.executeQuery("SELECT COUNT(*) AS total FROM flota_vehiculos");
        if (rsFlota.next()) totalFlota = rsFlota.getInt("total");
        rsFlota.close();

        String qOperando = "SELECT COUNT(DISTINCT id) AS activos FROM (" +
                           "SELECT id_vehiculo_main as id FROM rutas_operativas WHERE id_vehiculo_main IS NOT NULL UNION " +
                           "SELECT id_vehiculo_backup FROM rutas_operativas WHERE id_vehiculo_backup IS NOT NULL UNION " +
                           "SELECT id_vehiculo_extra FROM rutas_operativas WHERE id_vehiculo_extra IS NOT NULL) as operando";
        ResultSet rsOp = st.executeQuery(qOperando);
        if (rsOp.next()) busesOperando = rsOp.getInt("activos");
        rsOp.close();

        ResultSet rsAsientos = st.executeQuery("SELECT COUNT(*) AS tot, COALESCE(SUM(CASE WHEN estado != 'libre' THEN 1 ELSE 0 END), 0) AS ocu FROM asientos");
        if (rsAsientos.next()) {
            asientosTotalesRed = rsAsientos.getInt("tot");
            asientosOcupadosRed = rsAsientos.getInt("ocu");
        }
        rsAsientos.close();

        ResultSet rsAlertas = st.executeQuery("SELECT COUNT(*) AS total FROM alertas WHERE estado = 'Activa'");
        if (rsAlertas.next()) alertasTotales = rsAlertas.getInt("total");
        rsAlertas.close();

        ResultSet rsAlertasPub = st.executeQuery("SELECT COUNT(*) AS total FROM alertas WHERE estado = 'Activa' AND audiencia = 'publica'");
        if (rsAlertasPub.next()) alertasPublicas = rsAlertasPub.getInt("total");
        rsAlertasPub.close();

        ResultSet rsInfra = st.executeQuery(
            "SELECT (SELECT COALESCE(SUM(distancia_km),0) FROM distancias_tramos), " +
            "(SELECT COUNT(*) FROM guardias_seguridad), " +
            "(SELECT COUNT(*) FROM parqueos), " +
            "(SELECT COUNT(*) FROM estaciones_fisicas), " +
            "(SELECT COUNT(*) FROM municipalidades)");
        if (rsInfra.next()) {
            kmRed = rsInfra.getBigDecimal(1);
            totGuardias = rsInfra.getInt(2);
            totParqueos = rsInfra.getInt(3);
            totEstaciones = rsInfra.getInt(4);
            totMunis = rsInfra.getInt(5);
        }
        rsInfra.close();

        try {
            ResultSet rsM = st.executeQuery("SELECT nombre FROM municipalidades ORDER BY nombre");
            while (rsM.next()) {
                String nm = rsM.getString(1);
                if (nm != null && !nm.trim().isEmpty()) listaMunisActivas.add(nm.trim());
            }
            rsM.close();
        } catch (Exception ig) {}

        try {
            ResultSet rsResumen = st.executeQuery(
                "SELECT r.id_ruta, r.nombre_ruta, r.lista_estaciones, " +
                "vm.placa AS placa_main, vm.municipalidad AS muni_main, " +
                "(SELECT COUNT(*) FROM asientos a WHERE a.id_bus = r.id_vehiculo_main) AS tot_main, " +
                "(SELECT COALESCE(SUM(CASE WHEN a.estado != 'libre' THEN 1 ELSE 0 END), 0) FROM asientos a WHERE a.id_bus = r.id_vehiculo_main) AS ocu_main " +
                "FROM rutas_operativas r " +
                "JOIN flota_vehiculos vm ON r.id_vehiculo_main = vm.id_vehiculo " +
                "ORDER BY r.id_ruta ASC LIMIT 6"
            );
            while (rsResumen.next()) {
                Map<String, String> item = new HashMap<>();
                item.put("id", rsResumen.getString("id_ruta"));
                item.put("nombre", rsResumen.getString("nombre_ruta"));
                item.put("placa", rsResumen.getString("placa_main"));
                String mn = rsResumen.getString("muni_main");
                item.put("muni", mn != null ? mn : "General");
                if (mn != null && !mn.trim().isEmpty()) listaMunisActivas.add(mn.trim());
                int tm = rsResumen.getInt("tot_main");
                int om = rsResumen.getInt("ocu_main");
                int pct = tm > 0 ? (int) Math.round(((double) om / tm) * 100) : 0;
                item.put("tot", String.valueOf(tm));
                item.put("ocu", String.valueOf(om));
                item.put("pct", String.valueOf(pct));
                resumenRutas.add(item);
            }
            rsResumen.close();
        } catch (Exception ig) {}

        st.close();
        con.close();
    } catch (Exception e) {}

    int pctOcupacionGlobal = asientosTotalesRed > 0 ? (int) Math.round(((double) asientosOcupadosRed / asientosTotalesRed) * 100) : 0;
%>
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Inicio — Transmetro GT</title>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&display=swap" rel="stylesheet">
    <style>
        * { box-sizing: border-box; }
        body {
            font-family: 'Inter', -apple-system, BlinkMacSystemFont, sans-serif;
            background-color: #f8fafc;
            margin: 0;
            padding-top: 72px;
            color: #0f172a;
        }
        .header {
            background: rgba(255, 255, 255, 0.94);
            backdrop-filter: blur(10px);
            color: #0f172a;
            padding: 0 24px;
            position: fixed;
            top: 0;
            left: 0;
            width: 100%;
            z-index: 1000;
            display: flex;
            justify-content: space-between;
            align-items: center;
            border-bottom: 1px solid #e2e8f0;
            height: 64px;
        }
        .header h1 {
            margin: 0;
            font-size: 16px;
            text-align: center;
            flex-grow: 1;
            font-weight: 800;
            letter-spacing: -0.02em;
        }
        .menu-btn {
            background: #f8fafc;
            border: 1px solid #e2e8f0;
            color: #334155;
            font-size: 20px;
            cursor: pointer;
            width: 38px;
            height: 38px;
            border-radius: 10px;
            display: inline-flex;
            align-items: center;
            justify-content: center;
            transition: 0.18s;
        }
        .menu-btn:hover { background: #f1f5f9; color: #0f172a; }
        .overlay {
            display: none;
            position: fixed;
            width: 100%;
            height: 100%;
            top: 0;
            left: 0;
            background: rgba(15, 23, 42, 0.35);
            backdrop-filter: blur(2px);
            z-index: 999;
        }

        .main-container {
            max-width: 1160px;
            margin: 20px auto;
            padding: 0 20px 56px 20px;
        }

        /* Hero Minimalista y Ejecutivo */
        .welcome-banner {
            background: #ffffff;
            border: 1px solid #e2e8f0;
            border-radius: 18px;
            padding: 28px 32px;
            margin-bottom: 26px;
            display: flex;
            justify-content: space-between;
            align-items: center;
            flex-wrap: wrap;
            gap: 22px;
            box-shadow: 0 1px 3px rgba(15, 23, 42, 0.03), 0 10px 26px -8px rgba(15, 23, 42, 0.05);
            position: relative;
            overflow: hidden;
        }
        .welcome-banner::before {
            content: '';
            position: absolute;
            top: 0;
            left: 0;
            right: 0;
            height: 4px;
            background: linear-gradient(90deg, #0d9488 0%, #0284c7 50%, #6366f1 100%);
        }
        .welcome-left { max-width: 640px; }
        .badge-row {
            display: flex;
            align-items: center;
            gap: 8px;
            flex-wrap: wrap;
            margin-bottom: 10px;
        }
        .role-badge {
            display: inline-flex;
            align-items: center;
            gap: 6px;
            padding: 4px 11px;
            border-radius: 999px;
            font-size: 11px;
            font-weight: 700;
            letter-spacing: 0.04em;
            text-transform: uppercase;
        }
        .role-admin { background: #f0fdfa; color: #0f766e; border: 1px solid #99f6e4; }
        .role-piloto { background: #f0f9ff; color: #0369a1; border: 1px solid #bae6fd; }
        .role-pasajero { background: #f8fafc; color: #475569; border: 1px solid #cbd5e1; }

        .live-pill {
            display: inline-flex;
            align-items: center;
            gap: 6px;
            padding: 4px 10px;
            border-radius: 999px;
            font-size: 11px;
            font-weight: 700;
            background: #ecfdf5;
            color: #047857;
            border: 1px solid #a7f3d0;
        }
        .live-dot {
            width: 7px;
            height: 7px;
            border-radius: 50%;
            background: #10b981;
            animation: blink 1.4s infinite;
        }

        .welcome-banner h2 {
            margin: 0 0 6px 0;
            font-size: 27px;
            font-weight: 800;
            color: #0f172a;
            letter-spacing: -0.025em;
        }
        .welcome-banner p {
            margin: 0;
            font-size: 14px;
            color: #64748b;
            line-height: 1.55;
        }

        .hero-ctas { display: flex; gap: 10px; flex-wrap: wrap; }
        .cta-primary {
            background: #0d9488;
            color: #ffffff;
            padding: 11px 18px;
            border-radius: 10px;
            font-size: 13.5px;
            font-weight: 700;
            text-decoration: none;
            display: inline-flex;
            align-items: center;
            gap: 8px;
            box-shadow: 0 4px 12px rgba(13, 148, 136, 0.22);
            transition: 0.18s;
        }
        .cta-primary:hover { background: #0f766e; transform: translateY(-1px); }
        .cta-secondary {
            background: #f8fafc;
            color: #0f172a;
            border: 1px solid #cbd5e1;
            padding: 11px 16px;
            border-radius: 10px;
            font-size: 13.5px;
            font-weight: 600;
            text-decoration: none;
            display: inline-flex;
            align-items: center;
            gap: 8px;
            transition: 0.18s;
        }
        .cta-secondary:hover { background: #f1f5f9; }

        /* Encabezados de sección */
        .section-header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin: 0 2px 12px 2px;
            flex-wrap: wrap;
            gap: 8px;
        }
        .section-label {
            font-size: 11.5px;
            font-weight: 800;
            text-transform: uppercase;
            letter-spacing: 0.06em;
            color: #475569;
            margin: 0;
            display: flex;
            align-items: center;
            gap: 6px;
        }
        .section-hint {
            font-size: 12px;
            color: #64748b;
            font-weight: 500;
        }

        /* Grid de Indicadores de la Red en Tiempo Real */
        .stats-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(205px, 1fr));
            gap: 14px;
            margin-bottom: 26px;
        }
        .stat-card {
            background: #ffffff;
            padding: 18px 20px;
            border-radius: 15px;
            border: 1px solid #e2e8f0;
            display: flex;
            flex-direction: column;
            gap: 8px;
            text-decoration: none;
            color: inherit;
            transition: all 0.18s ease;
            box-shadow: 0 1px 2px rgba(15, 23, 42, 0.02);
        }
        .stat-card:hover {
            border-color: #0d9488;
            transform: translateY(-2px);
            box-shadow: 0 8px 20px -6px rgba(13, 148, 136, 0.12);
        }
        .stat-top {
            display: flex;
            justify-content: space-between;
            align-items: center;
        }
        .stat-icon {
            font-size: 18px;
            width: 38px;
            height: 38px;
            display: flex;
            justify-content: center;
            align-items: center;
            border-radius: 10px;
            background: #f1f5f9;
        }
        .stat-title {
            font-size: 12px;
            color: #64748b;
            font-weight: 700;
            text-transform: uppercase;
            letter-spacing: 0.03em;
        }
        .stat-value {
            font-size: 28px;
            font-weight: 800;
            color: #0f172a;
            line-height: 1.1;
            letter-spacing: -0.025em;
        }
        .stat-sub {
            font-size: 11.5px;
            color: #64748b;
            font-weight: 500;
            display: flex;
            align-items: center;
            justify-content: space-between;
            margin-top: 2px;
        }

        /* Pulso Operativo en Tiempo Real (Líneas + Municipalidades) */
        .pulse-card {
            background: #ffffff;
            border: 1px solid #e2e8f0;
            border-radius: 16px;
            padding: 20px 22px;
            margin-bottom: 26px;
            box-shadow: 0 1px 3px rgba(15, 23, 42, 0.02);
        }
        .pulse-routes-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
            gap: 12px;
        }
        .pulse-route-item {
            background: #f8fafc;
            border: 1px solid #e2e8f0;
            border-radius: 12px;
            padding: 13px 15px;
            text-decoration: none;
            color: inherit;
            transition: 0.16s;
            display: flex;
            flex-direction: column;
            gap: 8px;
        }
        .pulse-route-item:hover {
            background: #ffffff;
            border-color: #0d9488;
            box-shadow: 0 4px 12px rgba(15, 23, 42, 0.05);
        }
        .pr-top {
            display: flex;
            justify-content: space-between;
            align-items: center;
            gap: 8px;
        }
        .pr-name {
            font-size: 13.5px;
            font-weight: 800;
            color: #0f172a;
        }
        .pr-muni {
            font-size: 11px;
            font-weight: 700;
            color: #0369a1;
            background: #e0f2fe;
            padding: 2px 8px;
            border-radius: 6px;
        }
        .pr-bar-track {
            width: 100%;
            height: 6px;
            background: #e2e8f0;
            border-radius: 999px;
            overflow: hidden;
        }
        .pr-bar-fill {
            height: 100%;
            background: #0d9488;
            border-radius: 999px;
        }
        .pr-meta {
            display: flex;
            justify-content: space-between;
            font-size: 11.5px;
            color: #64748b;
            font-weight: 600;
        }
        .muni-pills-row {
            margin-top: 14px;
            padding-top: 12px;
            border-top: 1px solid #f1f5f9;
            display: flex;
            align-items: center;
            flex-wrap: wrap;
            gap: 6px;
        }
        .muni-mini-pill {
            background: #f8fafc;
            border: 1px solid #e2e8f0;
            color: #334155;
            padding: 4px 10px;
            border-radius: 999px;
            font-size: 11.5px;
            font-weight: 600;
            text-decoration: none;
            transition: 0.15s;
        }
        .muni-mini-pill:hover {
            background: #f0fdfa;
            color: #0f766e;
            border-color: #99f6e4;
        }

        /* Banner Minimalista del Mini-Juego */
        .play-banner {
            background: linear-gradient(135deg, #0f172a 0%, #1e293b 100%);
            padding: 24px 28px;
            border-radius: 16px;
            display: flex;
            justify-content: space-between;
            align-items: center;
            flex-wrap: wrap;
            gap: 16px;
            color: #ffffff;
            border: 1px solid #334155;
        }
        .play-info h3 { margin: 0 0 4px 0; font-size: 18px; font-weight: 800; display: flex; align-items: center; gap: 8px; }
        .play-info p { margin: 0; font-size: 13.5px; color: #94a3b8; max-width: 560px; }
        .btn-play-now {
            background: #14b8a6;
            color: #0f172a;
            font-size: 13.5px;
            font-weight: 800;
            padding: 11px 22px;
            border-radius: 10px;
            text-decoration: none;
            letter-spacing: 0.02em;
            transition: 0.18s;
        }
        .btn-play-now:hover { background: #2dd4bf; transform: translateY(-1px); }

        .refresh-indicator { text-align: center; font-size: 11.5px; color: #94a3b8; margin-top: 22px; font-weight: 500; }
        .refresh-dot { display: inline-block; width: 7px; height: 7px; background: #10b981; border-radius: 50%; margin-right: 6px; animation: blink 1.4s infinite; }
        @keyframes blink { 0%, 100% { opacity: 1; } 50% { opacity: 0.3; } }
    </style>
    <link rel="stylesheet" href="css/transmetro.css">
</head>
<body>
    <jsp:include page="menu_izquierdo.jsp" />
    <jsp:include page="menu_derecho.jsp" />
    <div id="overlay" class="overlay" onclick="closeAllMenus()"></div>

    <div class="header">
        <button class="menu-btn" onclick="toggleMenu('left')" title="Menú Principal">☰</button>
        <h1>Transmetro GT · Centro de Control</h1>
        <% if (isAdmin) { %>
            <button class="menu-btn" onclick="toggleMenu('right')" title="Administración">⚙️</button>
        <% } else { %>
            <div style="width: 38px;"></div>
        <% } %>
    </div>

    <div class="main-container">

        <!-- BIENVENIDA Y ESTADO GENERAL -->
        <div class="welcome-banner">
            <div class="welcome-left">
                <div class="badge-row">
                    <% if (isAdmin) { %>
                        <span class="role-badge role-admin">👑 Administrador General</span>
                    <% } else if (isPiloto) { %>
                        <span class="role-badge role-piloto">🪪 Piloto Operativo</span>
                    <% } else { %>
                        <span class="role-badge role-pasajero">🎫 Pasajero</span>
                    <% } %>
                    <span class="live-pill"><span class="live-dot"></span> Red en Línea</span>
                </div>

                <% if (isAdmin) { %>
                    <h2>Hola, <%= h(nombreUsuario) %></h2>
                    <p>Monitorea en tiempo real los indicadores de la red metropolitana. Utiliza el menú lateral izquierdo (☰) para navegar y el panel derecho (⚙️) para la configuración administrativa.</p>
                <% } else if (isPiloto) { %>
                    <h2>Buen turno, <%= h(nombreUsuario) %></h2>
                    <p>Revisa los indicadores operativos en vivo de la red y utiliza el menú lateral (☰) para gestionar alertas y recorridos.</p>
                <% } else { %>
                    <h2>¡Bienvenido, <%= h(nombreUsuario) %>!</h2>
                    <p>Consulta en tiempo real la disponibilidad de la red, municipalidades cubiertas y estado del servicio antes de abordar tu unidad.</p>
                <% } %>
            </div>

            <div class="hero-ctas">
                <a href="operacion.jsp" class="cta-primary">🎫 <%= isPasajero ? "Abordar / Elegir Asiento" : "Control de Asientos" %></a>
                <a href="lineas.jsp" class="cta-secondary">🛤️ Mapa en Vivo</a>
            </div>
        </div>

        <!-- INDICADORES DE LA RED EN TIEMPO REAL -->
        <div class="section-header">
            <div class="section-label"><span>📊</span><span>Indicadores de la Red en Tiempo Real</span></div>
            <div class="section-hint">Haz clic en cualquier indicador para explorar su detalle</div>
        </div>

        <div class="stats-grid">
            <% if (isAdmin || isPiloto) { %>
                <a href="lineas.jsp" class="stat-card">
                    <div class="stat-top"><span class="stat-title">Rutas Activas</span><div class="stat-icon">🛣️</div></div>
                    <div class="stat-value"><%= rutasActivas %></div>
                    <div class="stat-sub"><span>Líneas operativas</span><span>Ver mapa →</span></div>
                </a>
                <a href="flota.jsp" class="stat-card">
                    <div class="stat-top"><span class="stat-title">Flota de Unidades</span><div class="stat-icon">🚍</div></div>
                    <div class="stat-value"><%= busesOperando %> <span style="font-size: 14px; color: #94a3b8; font-weight:600;">/ <%= totalFlota %></span></div>
                    <div class="stat-sub"><span>Operando / Total</span><span>Ver flota →</span></div>
                </a>
                <a href="alertas.jsp" class="stat-card">
                    <div class="stat-top"><span class="stat-title">Alertas Activas</span><div class="stat-icon">🚨</div></div>
                    <div class="stat-value" style="color:<%= alertasTotales > 0 ? "#e11d48" : "#0d9488" %>;"><%= alertasTotales %></div>
                    <div class="stat-sub"><span><%= alertasTotales == 0 ? "Sin contingencias" : "Requieren atención" %></span><span>Monitoreo →</span></div>
                </a>
            <% } else { %>
                <a href="lineas.jsp" class="stat-card">
                    <div class="stat-top"><span class="stat-title">Líneas en Servicio</span><div class="stat-icon">🗺️</div></div>
                    <div class="stat-value"><%= rutasActivas %></div>
                    <div class="stat-sub"><span>Recorridos habilitados</span><span>Ver PIDS →</span></div>
                </a>
                <a href="flota.jsp" class="stat-card">
                    <div class="stat-top"><span class="stat-title">Flota de Unidades</span><div class="stat-icon">🚍</div></div>
                    <div class="stat-value"><%= busesOperando %> <span style="font-size: 14px; color: #94a3b8; font-weight:600;">/ <%= totalFlota %></span></div>
                    <div class="stat-sub"><span>En ruta / Total flota</span><span>Ver flota →</span></div>
                </a>
                <a href="notificaciones.jsp" class="stat-card">
                    <div class="stat-top"><span class="stat-title">Avisos Públicos</span><div class="stat-icon">🔔</div></div>
                    <div class="stat-value"><%= alertasPublicas %></div>
                    <div class="stat-sub"><span><%= (alertasPublicas == 0) ? "Operación normal" : "Avisos activos" %></span><span>Leer avisos →</span></div>
                </a>
            <% } %>

            <a href="operacion.jsp" class="stat-card">
                <div class="stat-top"><span class="stat-title">Ocupación de Asientos</span><div class="stat-icon">💺</div></div>
                <div class="stat-value"><%= pctOcupacionGlobal %><span style="font-size: 16px; color: #64748b; font-weight:700;">%</span></div>
                <div class="stat-sub"><span><%= asientosOcupadosRed %> / <%= asientosTotalesRed %> ocupados</span><span>Abordaje →</span></div>
            </a>

            <a href="estaciones.jsp" class="stat-card">
                <div class="stat-top"><span class="stat-title">Estaciones Físicas</span><div class="stat-icon">🚏</div></div>
                <div class="stat-value"><%= totEstaciones %></div>
                <div class="stat-sub"><span>Paradas geolocalizadas</span><span>Directorio →</span></div>
            </a>

            <a href="estaciones.jsp#municipalidades" class="stat-card">
                <div class="stat-top"><span class="stat-title">Municipalidades</span><div class="stat-icon">🏛️</div></div>
                <div class="stat-value"><%= totMunis %></div>
                <div class="stat-sub"><span>Jurisdicciones registradas</span><span>Ver cobertura →</span></div>
            </a>

            <a href="infraestructura.jsp" class="stat-card">
                <div class="stat-top"><span class="stat-title">Red Mapeada</span><div class="stat-icon">📏</div></div>
                <div class="stat-value"><%= kmRed %> <span style="font-size: 14px; color: #94a3b8; font-weight:600;">km</span></div>
                <div class="stat-sub"><span>Distancias por tramo</span><span>Ver tramos →</span></div>
            </a>

            <a href="infraestructura.jsp" class="stat-card">
                <div class="stat-top"><span class="stat-title">Seguridad y Predios</span><div class="stat-icon">👮</div></div>
                <div class="stat-value"><%= totGuardias %> <span style="font-size: 14px; color: #94a3b8; font-weight:600;">/ <%= totParqueos %> 🅿️</span></div>
                <div class="stat-sub"><span>Guardias RN05 y parqueos</span><span>Infraestructura →</span></div>
            </a>
        </div>

        <!-- PULSO OPERATIVO DE LÍNEAS Y MUNICIPALIDADES EN VIVO -->
        <% if (!resumenRutas.isEmpty() || !listaMunisActivas.isEmpty()) { %>
            <div class="section-header">
                <div class="section-label"><span>🚍</span><span>Estado de Líneas y Cobertura Municipal en Vivo</span></div>
                <div class="section-hint"><%= resumenRutas.size() %> línea(s) activa(s) · <%= listaMunisActivas.size() %> municipalidad(es)</div>
            </div>
            <div class="pulse-card">
                <% if (!resumenRutas.isEmpty()) { %>
                    <div class="pulse-routes-grid">
                        <% for (Map<String, String> rItem : resumenRutas) {
                               int pVal = Integer.parseInt(rItem.get("pct"));
                               String barColor = pVal >= 90 ? "#e11d48" : (pVal >= 75 ? "#f97316" : (pVal >= 50 ? "#f59e0b" : "#0d9488"));
                        %>
                            <a href="operacion.jsp?filtro_ruta=<%= rItem.get("id") %>" class="pulse-route-item">
                                <div class="pr-top">
                                    <span class="pr-name">🗺️ <%= h(rItem.get("nombre")) %></span>
                                    <span class="pr-muni">🏛️ <%= h(rItem.get("muni")) %></span>
                                </div>
                                <div class="pr-bar-track">
                                    <div class="pr-bar-fill" style="width:<%= pVal %>%; background:<%= barColor %>;"></div>
                                </div>
                                <div class="pr-meta">
                                    <span>🚍 Principal: <%= h(rItem.get("placa")) %></span>
                                    <span>💺 <%= rItem.get("ocu") %>/<%= rItem.get("tot") %> (<%= pVal %>%)</span>
                                </div>
                            </a>
                        <% } %>
                    </div>
                <% } %>

                <% if (!listaMunisActivas.isEmpty()) { %>
                    <div class="muni-pills-row">
                        <span style="font-size:11px; font-weight:800; color:#64748b; text-transform:uppercase; margin-right:4px;">🏛️ Municipalidades en el Sistema:</span>
                        <% for (String mNom : listaMunisActivas) { %>
                            <a href="operacion.jsp?filtro_muni=<%= java.net.URLEncoder.encode(mNom, "UTF-8") %>" class="muni-mini-pill">🏛️ <%= h(mNom) %></a>
                        <% } %>
                    </div>
                <% } %>
            </div>
        <% } %>

        <!-- ZONA RECREATIVA -->
        <div class="play-banner">
            <div class="play-info">
                <h3><span>🎮</span><span>Transmetro Rush &amp; Fly</span></h3>
                <p>¿Esperando tu próxima unidad? Esquiva obstáculos viales, activa el modo vuelo o turbo y compite en el Top 10 Mundial.</p>
            </div>
            <a href="juego.jsp" class="btn-play-now">▶ Jugar Ahora</a>
        </div>

        <div class="refresh-indicator">
            <span class="refresh-dot"></span> Sincronización automática activa cada 15 segundos
        </div>
    </div>

    <script>
        let menuAbierto = false;
        function toggleMenu(side) {
            let left = document.getElementById("leftSidebar");
            let right = document.getElementById("rightSidebar");
            let over = document.getElementById("overlay");
            if (side === 'left') { left.style.width = "250px"; if (right) right.style.width = "0"; }
            else if (side === 'right') { if (right) right.style.width = "300px"; left.style.width = "0"; }
            over.style.display = "block";
            menuAbierto = true;
        }
        function closeAllMenus() {
            document.getElementById("leftSidebar").style.width = "0";
            let right = document.getElementById("rightSidebar");
            if (right) right.style.width = "0";
            document.getElementById("overlay").style.display = "none";
            menuAbierto = false;
        }
        setInterval(() => { if (!menuAbierto) { window.location.reload(); } }, 15000);
    </script>
</body>
</html>
