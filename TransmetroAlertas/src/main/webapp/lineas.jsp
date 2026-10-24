<%@page contentType="text/html" pageEncoding="UTF-8"%>
<%@page import="java.sql.*"%>
<%@page import="java.util.*"%>
<%@page import="java.math.BigDecimal"%>
<%!
    static String h(String s) {
        if (s == null) return "";
        return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace("\"", "&quot;").replace("'", "&#39;");
    }
    static String t(String s) { return s == null ? "" : s.trim(); }
    static void asegurarColumnaPiloto(Connection con) {
        try (Statement st = con.createStatement()) {
            st.executeUpdate("ALTER TABLE rutas_operativas ADD COLUMN id_piloto INT DEFAULT NULL");
        } catch (SQLException ignorar) {}
    }
%>
<%
    if (session.getAttribute("usuarioValido") == null) { response.sendRedirect("login.jsp"); return; }
    String rolActual = (String) session.getAttribute("rol");
    if (rolActual == null) rolActual = "pasajero";

    String dbUrl = "jdbc:mysql://192.168.15.135:3306/transmetro_db";
    String dbUser = "admin";
    String dbPass = "admin123";
%>
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <title>Líneas y Monitoreo en Vivo - Transmetro</title>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800;900&display=swap" rel="stylesheet">
    <style>
        body { font-family: 'Inter', sans-serif; background-color: #f1f5f9; margin: 0; padding-top: 70px; color: #0f172a; }
        .header { background: #ffffff; padding: 15px 25px; position: fixed; top: 0; width: 100%; box-sizing: border-box; z-index: 1000; display: flex; justify-content: space-between; align-items: center; border-bottom: 1px solid #e2e8f0; box-shadow: 0 1px 3px rgba(0,0,0,0.04); }
        .header h1 { margin: 0; font-size: 18px; text-align: center; flex-grow: 1; font-weight: 800; color: #0f172a; }
        .menu-btn { background: none; border: none; font-size: 24px; cursor: pointer; color: #475569; }
        .overlay { display: none; position: fixed; width: 100%; height: 100%; top: 0; left: 0; background: rgba(15, 23, 42, 0.4); z-index: 999; }

        .main-container { max-width: 1180px; margin: 24px auto; padding: 0 20px 60px 20px; }

        /* HERO PANEL DE TELEMETRÍA GLOBAL */
        .hero-pids {
            background: linear-gradient(135deg, #0f172a 0%, #1e3a8a 55%, #0f766e 100%);
            color: white;
            border-radius: 16px;
            padding: 24px 28px;
            margin-bottom: 28px;
            box-shadow: 0 10px 25px rgba(15, 23, 42, 0.15);
            display: flex;
            justify-content: space-between;
            align-items: center;
            flex-wrap: wrap;
            gap: 20px;
        }
        .hero-pids h2 { margin: 0 0 6px 0; font-size: 26px; font-weight: 900; letter-spacing: -0.3px; }
        .hero-pids p { margin: 0; color: #cbd5e1; font-size: 14px; }
        .reloj-vivo-box {
            background: rgba(255, 255, 255, 0.1);
            border: 1px solid rgba(255, 255, 255, 0.2);
            padding: 12px 20px;
            border-radius: 12px;
            text-align: right;
            backdrop-filter: blur(6px);
        }
        .reloj-vivo-box .lbl { font-size: 11px; text-transform: uppercase; letter-spacing: 1px; color: #93c5fd; font-weight: 700; }
        .reloj-vivo-box .time { font-size: 24px; font-weight: 900; font-variant-numeric: tabular-nums; color: #38bdf8; }

        /* BARRA DE MUNICIPALIDADES REGISTRADAS (VISIBLE PARA PASAJEROS Y TODOS LOS USUARIOS) */
        .munis-bar {
            background: #ffffff;
            border: 1px solid #e2e8f0;
            border-radius: 14px;
            padding: 14px 18px;
            margin-bottom: 24px;
            display: flex;
            align-items: center;
            justify-content: space-between;
            flex-wrap: wrap;
            gap: 12px;
            box-shadow: 0 2px 8px rgba(15, 23, 42, 0.03);
        }
        .munis-bar-title {
            font-size: 12px;
            font-weight: 800;
            color: #475569;
            text-transform: uppercase;
            letter-spacing: 0.04em;
            display: flex;
            align-items: center;
            gap: 6px;
        }
        .munis-pills {
            display: flex;
            flex-wrap: wrap;
            gap: 8px;
            align-items: center;
        }
        .muni-filter-chip {
            display: inline-flex;
            align-items: center;
            gap: 6px;
            padding: 6px 12px;
            border-radius: 999px;
            font-size: 12.5px;
            font-weight: 700;
            text-decoration: none;
            background: #f8fafc;
            color: #334155;
            border: 1px solid #cbd5e1;
            transition: 0.18s;
        }
        .muni-filter-chip:hover {
            border-color: #0d9488;
            color: #0f766e;
            background: #f0fdfa;
        }
        .muni-filter-chip.activo {
            background: #0d9488;
            color: #ffffff;
            border-color: #0d9488;
            box-shadow: 0 3px 10px rgba(13, 148, 136, 0.22);
        }
        .muni-chip-count {
            font-size: 10.5px;
            padding: 1px 6px;
            border-radius: 999px;
            background: rgba(15, 23, 42, 0.08);
            color: inherit;
        }
        .muni-filter-chip.activo .muni-chip-count {
            background: rgba(255, 255, 255, 0.22);
        }

        /* TARJETA DE CADA RUTA */
        .rutas-grid { display: flex; flex-direction: column; gap: 30px; }
        .ruta-card {
            background: #ffffff;
            border-radius: 16px;
            border: 1px solid #e2e8f0;
            box-shadow: 0 6px 20px rgba(15, 23, 42, 0.05);
            overflow: hidden;
        }
        .ruta-card-header {
            background: #f8fafc;
            padding: 20px 26px;
            border-bottom: 1px solid #e2e8f0;
            display: flex;
            justify-content: space-between;
            align-items: center;
            flex-wrap: wrap;
            gap: 14px;
        }
        .ruta-title-group { display: flex; align-items: center; gap: 12px; flex-wrap: wrap; }
        .ruta-title-group h3 { margin: 0; font-size: 22px; font-weight: 900; color: #0f172a; }
        .badge-muni { background: #e0f2fe; color: #0369a1; padding: 4px 10px; border-radius: 20px; font-size: 12px; font-weight: 700; }
        .badge-sentido { font-size: 12px; padding: 5px 12px; border-radius: 20px; font-weight: 800; text-transform: uppercase; letter-spacing: 0.4px; }
        .sentido-ida { background: #dcfce7; color: #166534; border: 1px solid #86efac; }
        .sentido-vuelta { background: #f3e8ff; color: #6b21a8; border: 1px solid #d8b4fe; }

        .estado-pill { padding: 7px 14px; border-radius: 999px; font-size: 13px; font-weight: 800; display: inline-flex; align-items: center; gap: 6px; }
        .estado-en-curso { background: #ecfdf5; color: #047857; border: 1px solid #6ee7b7; animation: pulsoEstado 2s infinite; }
        .estado-espera { background: #fffbeb; color: #b45309; border: 1px solid #fcd34d; }
        .estado-finalizado { background: #f1f5f9; color: #475569; border: 1px solid #cbd5e1; }
        @keyframes pulsoEstado { 0%, 100% { box-shadow: 0 0 0 0 rgba(16, 185, 129, 0.35); } 50% { box-shadow: 0 0 0 6px rgba(16, 185, 129, 0); } }

        .ruta-body { padding: 24px 26px; }

        /* BARRA DE TURNOS Y BOTÓN SIMULAR */
        .turnos-bar {
            display: flex;
            justify-content: space-between;
            align-items: center;
            flex-wrap: wrap;
            gap: 12px;
            margin-bottom: 20px;
            background: #f8fafc;
            padding: 12px 16px;
            border-radius: 10px;
            border: 1px solid #e2e8f0;
        }
        .turnos-list { display: flex; gap: 8px; flex-wrap: wrap; align-items: center; }
        .btn-turno {
            padding: 7px 13px;
            border-radius: 8px;
            font-size: 12px;
            font-weight: 700;
            text-decoration: none;
            border: 1px solid #cbd5e1;
            background: #ffffff;
            color: #334155;
            transition: 0.2s;
        }
        .btn-turno:hover { background: #e2e8f0; }
        .btn-turno.activo {
            background: #0f766e;
            color: white;
            border-color: #0f766e;
            box-shadow: 0 3px 8px rgba(15, 118, 110, 0.25);
        }
        .btn-simular {
            background: linear-gradient(135deg, #2563eb, #1d4ed8);
            color: white;
            border: none;
            padding: 8px 14px;
            border-radius: 8px;
            font-size: 12px;
            font-weight: 800;
            cursor: pointer;
            display: inline-flex;
            align-items: center;
            gap: 6px;
            box-shadow: 0 3px 8px rgba(37, 99, 235, 0.25);
            transition: 0.2s;
        }
        .btn-simular:hover { transform: translateY(-1px); background: #1e40af; }

        /* GRID DE 4 TARJETAS DE DATOS PARA EL PASAJERO */
        .passenger-kpis {
            display: grid;
            grid-template-columns: repeat(4, 1fr);
            gap: 14px;
            margin-bottom: 22px;
        }
        @media (max-width: 960px) { .passenger-kpis { grid-template-columns: repeat(2, 1fr); } }
        @media (max-width: 560px) { .passenger-kpis { grid-template-columns: 1fr; } }
        .kpi-box {
            background: #f8fafc;
            border: 1px solid #e2e8f0;
            border-radius: 12px;
            padding: 14px 16px;
            display: flex;
            flex-direction: column;
            justify-content: space-between;
        }
        .kpi-box .kpi-label { font-size: 11px; font-weight: 800; text-transform: uppercase; color: #64748b; margin-bottom: 6px; letter-spacing: 0.4px; }
        .kpi-box .kpi-main { font-size: 15px; font-weight: 800; color: #0f172a; margin-bottom: 4px; }
        .kpi-box .kpi-sub { font-size: 12px; color: #475569; line-height: 1.4; }
        .ocupacion-mini-bar { height: 7px; background: #e2e8f0; border-radius: 999px; overflow: hidden; margin-top: 6px; }
        .ocupacion-mini-fill { height: 100%; background: #10b981; border-radius: 999px; }

        /* ESCENARIO VISUAL DE ANIMACIÓN EN VIVO (PANTALLA PIDS) */
        .pids-stage {
            background: linear-gradient(180deg, #0f172a 0%, #1e293b 100%);
            border-radius: 14px;
            padding: 22px 24px 26px 24px;
            color: #f8fafc;
            position: relative;
            box-shadow: inset 0 2px 10px rgba(0,0,0,0.4);
            margin-bottom: 20px;
            border: 2px solid #334155;
        }
        .pids-top-telemetry {
            display: flex;
            justify-content: space-between;
            align-items: center;
            flex-wrap: wrap;
            gap: 12px;
            padding-bottom: 16px;
            border-bottom: 1px solid rgba(255,255,255,0.12);
            margin-bottom: 38px;
            font-size: 13px;
        }
        .telemetry-pill {
            background: rgba(255,255,255,0.08);
            border: 1px solid rgba(255,255,255,0.15);
            padding: 6px 12px;
            border-radius: 8px;
            font-weight: 600;
            color: #e2e8f0;
        }
        .telemetry-pill b { color: #38bdf8; }

        /* CARRIL EXCLUSIVO Y ANIMACIÓN DEL BUS */
        .track-wrapper {
            position: relative;
            padding: 36px 20px 10px 20px;
            overflow-x: auto;
        }
        .track-inner {
            position: relative;
            min-width: 680px;
        }
        .road-lane {
            position: relative;
            height: 22px;
            background: #334155;
            border-radius: 12px;
            border: 2px solid #475569;
            box-shadow: inset 0 2px 5px rgba(0,0,0,0.5);
            margin: 0 35px;
        }
        /* Línea punteada de carril exclusivo */
        .road-lane::before {
            content: '';
            position: absolute;
            top: 50%;
            left: 10px;
            right: 10px;
            height: 2px;
            background: repeating-linear-gradient(90deg, rgba(255,255,255,0.35) 0, rgba(255,255,255,0.35) 12px, transparent 12px, transparent 24px);
            transform: translateY(-50%);
            z-index: 1;
        }
        .road-progress {
            position: absolute;
            top: 0;
            left: 0;
            bottom: 0;
            width: 0%;
            background: linear-gradient(90deg, #059669, #10b981, #34d399);
            border-radius: 10px;
            box-shadow: 0 0 14px rgba(16, 185, 129, 0.65);
            transition: width 0.8s linear;
            z-index: 2;
        }

        /* MARCADOR DEL BUS ARTICULADO */
        .bus-marker {
            position: absolute;
            top: -28px;
            left: 0%;
            transform: translateX(-50%);
            z-index: 15;
            transition: left 0.8s linear;
            display: flex;
            flex-direction: column;
            align-items: center;
            pointer-events: none;
        }
        .bus-tooltip {
            background: #10b981;
            color: #052e16;
            font-size: 11px;
            font-weight: 900;
            padding: 3px 9px;
            border-radius: 999px;
            white-space: nowrap;
            box-shadow: 0 3px 8px rgba(0,0,0,0.4);
            margin-bottom: 3px;
            border: 1px solid #a7f3d0;
        }
        .bus-icon-box {
            background: linear-gradient(135deg, #22c55e, #15803d);
            border: 2px solid #ffffff;
            border-radius: 10px;
            padding: 3px 10px;
            font-size: 20px;
            line-height: 1;
            box-shadow: 0 4px 12px rgba(0,0,0,0.5), 0 0 16px rgba(34, 197, 94, 0.7);
            position: relative;
        }
        /* Haz de luz del bus cuando va en ruta */
        .bus-icon-box.en-movimiento::after {
            content: '';
            position: absolute;
            right: -18px;
            top: 50%;
            transform: translateY(-50%);
            width: 18px;
            height: 14px;
            background: radial-gradient(circle at left, rgba(253, 224, 71, 0.85), transparent 75%);
            pointer-events: none;
        }

        /* PÍLDORAS DE KILOMETRAJE ENTRE ESTACIONES */
        .tramos-km-layer {
            display: flex;
            justify-content: space-around;
            margin: 10px 45px 0 45px;
        }
        .tramo-km-pill {
            background: rgba(14, 165, 233, 0.18);
            border: 1px solid rgba(56, 189, 248, 0.45);
            color: #7dd3fc;
            font-size: 11px;
            font-weight: 800;
            padding: 2px 9px;
            border-radius: 999px;
            white-space: nowrap;
        }

        /* NODOS DE ESTACIONES Y TARJETAS DE MOLINETE/GUARDIA */
        .estaciones-row {
            display: flex;
            justify-content: space-between;
            align-items: flex-start;
            margin-top: -16px;
            position: relative;
            z-index: 10;
        }
        .estacion-nodo {
            display: flex;
            flex-direction: column;
            align-items: center;
            width: 150px;
            text-align: center;
        }
        .nodo-circulo {
            width: 22px;
            height: 22px;
            border-radius: 50%;
            background: #1e293b;
            border: 4px solid #64748b;
            box-shadow: 0 2px 6px rgba(0,0,0,0.4);
            transition: 0.3s;
            margin-bottom: 10px;
        }
        .estacion-nodo.completada .nodo-circulo {
            background: #10b981;
            border-color: #d1fae5;
            box-shadow: 0 0 12px rgba(16, 185, 129, 0.8);
        }
        .estacion-nodo.actual .nodo-circulo {
            background: #f59e0b;
            border-color: #fef3c7;
            box-shadow: 0 0 15px rgba(245, 158, 11, 0.95);
            transform: scale(1.18);
        }
        .estacion-card-pids {
            background: rgba(255, 255, 255, 0.06);
            border: 1px solid rgba(255, 255, 255, 0.14);
            border-radius: 10px;
            padding: 8px 10px;
            width: 100%;
            box-sizing: border-box;
        }
        .estacion-nodo.completada .estacion-card-pids {
            border-color: rgba(16, 185, 129, 0.5);
            background: rgba(16, 185, 129, 0.1);
        }
        .estacion-nodo.actual .estacion-card-pids {
            border-color: rgba(245, 158, 11, 0.7);
            background: rgba(245, 158, 11, 0.15);
        }
        .est-orden { font-size: 10px; font-weight: 800; color: #94a3b8; text-transform: uppercase; }
        .est-nombre { font-size: 13px; font-weight: 800; color: #ffffff; margin: 2px 0 5px 0; }
        .est-molinete { font-size: 11px; color: #a7f3d0; font-weight: 600; line-height: 1.35; }
        .est-sin-molinete { font-size: 10px; color: #94a3b8; font-style: italic; }

        /* ACCIONES INFERIORES DE LA TARJETA */
        .ruta-footer-actions {
            display: flex;
            justify-content: space-between;
            align-items: center;
            flex-wrap: wrap;
            gap: 12px;
            padding-top: 8px;
        }
        .btn-ver-asientos {
            flex: 1;
            min-width: 240px;
            text-align: center;
            background: linear-gradient(135deg, #0f766e, #11998e);
            color: white;
            text-decoration: none;
            padding: 13px 20px;
            border-radius: 10px;
            font-weight: 800;
            font-size: 14px;
            box-shadow: 0 4px 12px rgba(17, 153, 142, 0.25);
            transition: 0.2s;
        }
        .btn-ver-asientos:hover { transform: translateY(-1px); background: #0d9488; }
        .btn-link-sec {
            background: #f1f5f9;
            color: #334155;
            text-decoration: none;
            padding: 12px 16px;
            border-radius: 10px;
            font-weight: 700;
            font-size: 13px;
            border: 1px solid #cbd5e1;
            transition: 0.2s;
        }
        .btn-link-sec:hover { background: #e2e8f0; color: #0f172a; }

        .empty-state { text-align: center; padding: 50px; background: white; border-radius: 12px; color: #94a3b8; font-weight: 600; border: 1px dashed #cbd5e1; }
        .refresh-indicator { text-align: center; font-size: 12px; color: #64748b; margin-top: 25px; font-weight: 600; }
        .refresh-dot { display: inline-block; width: 8px; height: 8px; background: #10b981; border-radius: 50%; margin-right: 5px; animation: blink 1s infinite; }
        @keyframes blink { 0%, 100% { opacity: 1; } 50% { opacity: 0.3; } }
    </style>
    <link rel="stylesheet" href="css/transmetro.css">
</head>
<body>
    <jsp:include page="menu_izquierdo.jsp" />
    <jsp:include page="menu_derecho.jsp" />
    <div id="overlay" class="overlay" onclick="closeAllMenus()"></div>

    <div class="header">
        <button class="menu-btn" onclick="toggleMenu('left')">☰</button>
        <h1>Red de Transporte y Telemetría para Pasajeros</h1>
        <% if (!"pasajero".equals(rolActual)) { %><button class="menu-btn" onclick="toggleMenu('right')">⚙️</button><% } else { %><div style="width: 24px;"></div><% } %>
    </div>

    <div class="main-container">
        <div class="hero-pids">
            <div>
                <h2>🚍 Pantalla de Líneas y Seguimiento en Vivo</h2>
                <p>Consulta en tiempo real la ubicación del bus, kilómetros por tramo, molinetes y seguridad de cada estación, piloto asignado y disponibilidad de asientos.</p>
            </div>
            <div class="reloj-vivo-box">
                <div class="lbl">🕒 Hora Oficial Transmetro</div>
                <div class="time" id="relojDigital">--:--:--</div>
            </div>
        </div>

        <div class="rutas-grid">
            <%
                String filtroMuni = t(request.getParameter("muni"));
                try {
                    Class.forName("com.mysql.cj.jdbc.Driver");
                    try (Connection con = DriverManager.getConnection(dbUrl, dbUser, dbPass)) {
                        asegurarColumnaPiloto(con);
                        Statement st = con.createStatement();

                        // 0. Cargar todas las municipalidades registradas en el catálogo y su conteo de unidades/rutas
                        Map<String, String> todasLasMunis = new TreeMap<>();
                        Map<String, Integer> busesPorMuni = new HashMap<>();
                        try (ResultSet rsM = st.executeQuery("SELECT nombre FROM municipalidades ORDER BY nombre ASC")) {
                            while (rsM.next()) {
                                String nm = t(rsM.getString("nombre"));
                                if (!nm.isEmpty()) todasLasMunis.putIfAbsent(nm.toLowerCase(), nm);
                            }
                        } catch (Exception ignorar) {}
                        try (ResultSet rsFM = st.executeQuery("SELECT municipalidad, COUNT(*) AS tot FROM flota_vehiculos GROUP BY municipalidad")) {
                            while (rsFM.next()) {
                                String nm = t(rsFM.getString("municipalidad"));
                                if (!nm.isEmpty()) {
                                    todasLasMunis.putIfAbsent(nm.toLowerCase(), nm);
                                    busesPorMuni.put(nm.toLowerCase(), rsFM.getInt("tot"));
                                }
                            }
                        } catch (Exception ignorar) {}
            %>
                        <!-- BARRA PÚBLICA DE MUNICIPALIDADES REGISTRADAS EN EL SISTEMA -->
                        <div class="munis-bar">
                            <div class="munis-bar-title">
                                <span>🏛️ Municipalidades Registradas (<%= todasLasMunis.size() %>):</span>
                            </div>
                            <div class="munis-pills">
                                <a href="lineas.jsp" class="muni-filter-chip <%= filtroMuni.isEmpty() ? "activo" : "" %>">
                                    🌐 Todas las Jurisdicciones
                                </a>
                                <% for (Map.Entry<String, String> me : todasLasMunis.entrySet()) {
                                    String mKey = me.getKey();
                                    String mNom = me.getValue();
                                    int nBusM = busesPorMuni.getOrDefault(mKey, 0);
                                    boolean esMuniActiva = filtroMuni.equalsIgnoreCase(mNom);
                                %>
                                    <a href="lineas.jsp?muni=<%= java.net.URLEncoder.encode(mNom, "UTF-8") %>" class="muni-filter-chip <%= esMuniActiva ? "activo" : "" %>">
                                        <span>🏛️ <%= h(mNom) %></span>
                                        <span class="muni-chip-count"><%= nBusM > 0 ? (nBusM + " 🚍") : "🆕 Catálogo" %></span>
                                    </a>
                                <% } %>
                                <a href="estaciones.jsp#municipalidades" class="muni-filter-chip" style="background:#f0fdfa; color:#0f766e; border-color:#99f6e4;">
                                    📋 Ver Directorio Municipal →
                                </a>
                            </div>
                        </div>
            <%
                        // 1. Pre-cargar mapa de seguridad por estación (molinetes + guardias)
                        Map<String, String> segPorEstacion = new HashMap<>();
                        try (ResultSet rsSeg = st.executeQuery(
                                "SELECT e.nombre, a.codigo_puerta, g.nombre_completo, g.turno " +
                                "FROM estaciones_fisicas e " +
                                "JOIN accesos_molinetes a ON a.id_estacion = e.id_estacion " +
                                "JOIN guardias_seguridad g ON g.id_acceso = a.id_acceso ORDER BY a.id_acceso ASC")) {
                            while (rsSeg.next()) {
                                String k = t(rsSeg.getString("nombre")).toLowerCase();
                                String item = "🚪 " + h(rsSeg.getString("codigo_puerta")) + "<br>👮 " + h(rsSeg.getString("nombre_completo")) + " (" + h(rsSeg.getString("turno")) + ")";
                                if (!segPorEstacion.containsKey(k)) {
                                    segPorEstacion.put(k, item);
                                }
                            }
                        } catch (Exception ignorar) {}

                        // 2. Pre-cargar distancias de tramos por ruta y globales
                        Map<String, BigDecimal> mapaTramosKm = new HashMap<>();
                        try (ResultSet rsTr = st.executeQuery("SELECT id_ruta, estacion_origen, estacion_destino, distancia_km FROM distancias_tramos")) {
                            while (rsTr.next()) {
                                int idR = rsTr.getInt("id_ruta");
                                String o = t(rsTr.getString("estacion_origen")).toLowerCase();
                                String d = t(rsTr.getString("estacion_destino")).toLowerCase();
                                BigDecimal km = rsTr.getBigDecimal("distancia_km");
                                mapaTramosKm.put(idR + "|" + o + "|" + d, km);
                                mapaTramosKm.put(idR + "|" + d + "|" + o, km);
                                mapaTramosKm.put("0|" + o + "|" + d, km);
                                mapaTramosKm.put("0|" + d + "|" + o, km);
                            }
                        } catch (Exception ignorar) {}

                        // 3. Consultar todas las rutas con su flota, parqueos, piloto y ocupación de asientos
                        String query =
                            "SELECT r.*, CURTIME() AS hora_actual, " +
                            "vm.placa AS placa_main, vm.municipalidad AS muni_main, pm.nombre AS parqueo_main, " +
                            "vb.placa AS placa_backup, vb.municipalidad AS muni_backup, " +
                            "vx.placa AS placa_extra, vx.municipalidad AS muni_extra, " +
                            "pil.nombre AS nombre_piloto, pil.identificador_transmetro AS id_piloto_tm, " +
                            "(SELECT COUNT(*) FROM asientos a WHERE a.id_bus IN (r.id_vehiculo_main, r.id_vehiculo_backup, r.id_vehiculo_extra)) AS total_asientos, " +
                            "(SELECT COUNT(*) FROM asientos a WHERE a.id_bus IN (r.id_vehiculo_main, r.id_vehiculo_backup, r.id_vehiculo_extra) AND a.estado <> 'libre') AS asientos_ocupados " +
                            "FROM rutas_operativas r " +
                            "LEFT JOIN flota_vehiculos vm ON r.id_vehiculo_main = vm.id_vehiculo " +
                            "LEFT JOIN parqueos pm ON vm.id_parqueo = pm.id_parqueo " +
                            "LEFT JOIN flota_vehiculos vb ON r.id_vehiculo_backup = vb.id_vehiculo " +
                            "LEFT JOIN flota_vehiculos vx ON r.id_vehiculo_extra = vx.id_vehiculo " +
                            "LEFT JOIN pilotos_catalogo pil ON r.id_piloto = pil.id " +
                            "ORDER BY r.nombre_ruta ASC";

                        ResultSet rs = st.executeQuery(query);
                        boolean hayRutas = false;

                        while (rs.next()) {
                            String muniMain = rs.getString("muni_main") != null ? rs.getString("muni_main") : "General";
                            String muniBackup = rs.getString("muni_backup") != null ? rs.getString("muni_backup") : "";
                            String muniExtra = rs.getString("muni_extra") != null ? rs.getString("muni_extra") : "";

                            if (!filtroMuni.isEmpty()) {
                                boolean coincideMuni = filtroMuni.equalsIgnoreCase(muniMain)
                                    || filtroMuni.equalsIgnoreCase(muniBackup)
                                    || filtroMuni.equalsIgnoreCase(muniExtra);
                                if (!coincideMuni) continue;
                            }

                            hayRutas = true;
                            int idRuta = rs.getInt("id_ruta");
                            String nombreRuta = rs.getString("nombre_ruta");
                            String listaEstaciones = rs.getString("lista_estaciones");
                            String horaActual = rs.getString("hora_actual");

                            String placaMain = rs.getString("placa_main") != null ? rs.getString("placa_main") : "S/P";
                            String parqueoBase = rs.getString("parqueo_main") != null ? rs.getString("parqueo_main") : "Sin parqueo";
                            String placaBackup = rs.getString("placa_backup") != null ? rs.getString("placa_backup") : "S/P";
                            String placaExtra = rs.getString("placa_extra");

                            String nombrePiloto = rs.getString("nombre_piloto");
                            String idPilotoTm = rs.getString("id_piloto_tm");

                            int totalAsientos = rs.getInt("total_asientos");
                            int asientosOcupados = rs.getInt("asientos_ocupados");
                            int asientosLibres = Math.max(0, totalAsientos - asientosOcupados);
                            int pctOcupacion = totalAsientos > 0 ? (int) Math.round((asientosOcupados * 100.0) / totalAsientos) : 0;

                            String[] salidas = {
                                rs.getString("hora_salida_1"), rs.getString("hora_salida_2"),
                                rs.getString("hora_salida_3"), rs.getString("hora_salida_4"),
                                rs.getString("hora_salida_5"), rs.getString("hora_salida_6")
                            };
                            String[] llegadas = {
                                rs.getString("hora_llegada_1"), rs.getString("hora_llegada_2"),
                                rs.getString("hora_llegada_3"), rs.getString("hora_llegada_4"),
                                rs.getString("hora_llegada_5"), rs.getString("hora_llegada_6")
                            };

                            int horaActualSeg = Integer.parseInt(horaActual.split(":")[0]) * 3600 +
                                                Integer.parseInt(horaActual.split(":")[1]) * 60 +
                                                Integer.parseInt(horaActual.split(":")[2]);

                            // Determinar automáticamente el turno actual o próximo según la hora del servidor
                            int turnoActivoRuta = 1;
                            for (int i = 0; i < 6; i++) {
                                if (salidas[i] != null && llegadas[i] != null) {
                                    int sSal = Integer.parseInt(salidas[i].split(":")[0]) * 3600 + Integer.parseInt(salidas[i].split(":")[1]) * 60;
                                    int sLleg = Integer.parseInt(llegadas[i].split(":")[0]) * 3600 + Integer.parseInt(llegadas[i].split(":")[1]) * 60;
                                    if (horaActualSeg <= sLleg) {
                                        turnoActivoRuta = i + 1;
                                        break;
                                    }
                                    turnoActivoRuta = i + 1;
                                }
                            }

                            // Si el pasajero seleccionó manualmente un turno específico para esta ruta
                            String tParam = request.getParameter("t_" + idRuta);
                            if (tParam != null) {
                                try {
                                    int tp = Integer.parseInt(tParam);
                                    if (tp >= 1 && tp <= 6 && salidas[tp - 1] != null) turnoActivoRuta = tp;
                                } catch (Exception ignorar) {}
                            }

                            String hsActiva = salidas[turnoActivoRuta - 1] != null ? salidas[turnoActivoRuta - 1] : "06:00:00";
                            String hlActiva = llegadas[turnoActivoRuta - 1] != null ? llegadas[turnoActivoRuta - 1] : "08:00:00";
                            boolean esVuelta = (turnoActivoRuta % 2 == 0);

                            int segSalida = Integer.parseInt(hsActiva.split(":")[0]) * 3600 + Integer.parseInt(hsActiva.split(":")[1]) * 60 + Integer.parseInt(hsActiva.split(":")[2]);
                            int segLlegada = Integer.parseInt(hlActiva.split(":")[0]) * 3600 + Integer.parseInt(hlActiva.split(":")[1]) * 60 + Integer.parseInt(hlActiva.split(":")[2]);

                            String estadoTexto = "💤 Turno Finalizado";
                            String claseEstado = "estado-finalizado";
                            boolean enRutaActiva = false;
                            double progresoInicial = 0.0;

                            if (horaActualSeg >= segSalida && horaActualSeg <= segLlegada && segLlegada > segSalida) {
                                estadoTexto = "🟢 EN RUTA: Unidad en Movimiento";
                                claseEstado = "estado-en-curso";
                                enRutaActiva = true;
                                progresoInicial = Math.min(100.0, Math.max(0.0, ((horaActualSeg - segSalida) * 100.0) / (segLlegada - segSalida)));
                            } else if (horaActualSeg < segSalida) {
                                estadoTexto = "⏳ En Abordaje / Inicia " + hsActiva.substring(0, 5);
                                claseEstado = "estado-espera";
                                progresoInicial = 0.0;
                            } else {
                                progresoInicial = 100.0;
                            }

                            // Procesar estaciones en el orden del turno (Ida o Vuelta)
                            String[] rawEst = (listaEstaciones != null && !listaEstaciones.trim().isEmpty()) ? listaEstaciones.split(",") : new String[]{"Origen", "Destino"};
                            List<String> estacionesOrdenadas = new ArrayList<>();
                            for (String s : rawEst) {
                                if (!s.trim().isEmpty()) estacionesOrdenadas.add(s.trim());
                            }
                            if (estacionesOrdenadas.size() < 2) {
                                estacionesOrdenadas.clear();
                                estacionesOrdenadas.add("Estación Origen");
                                estacionesOrdenadas.add("Estación Destino");
                            }
                            if (esVuelta) {
                                Collections.reverse(estacionesOrdenadas);
                            }
                            String origenActual = estacionesOrdenadas.get(0);
                            String destinoActual = estacionesOrdenadas.get(estacionesOrdenadas.size() - 1);

                            // Calcular distancias por tramo y suma total
                            List<BigDecimal> kmsTramos = new ArrayList<>();
                            BigDecimal sumaKmRuta = BigDecimal.ZERO;
                            for (int i = 0; i < estacionesOrdenadas.size() - 1; i++) {
                                String ea = estacionesOrdenadas.get(i).toLowerCase();
                                String eb = estacionesOrdenadas.get(i + 1).toLowerCase();
                                BigDecimal kmT = mapaTramosKm.get(idRuta + "|" + ea + "|" + eb);
                                if (kmT == null) kmT = mapaTramosKm.get("0|" + ea + "|" + eb);
                                if (kmT == null) kmT = BigDecimal.ZERO;
                                kmsTramos.add(kmT);
                                sumaKmRuta = sumaKmRuta.add(kmT);
                            }
            %>
                            <div class="ruta-card" id="card_ruta_<%= idRuta %>">
                                <!-- CABECERA DE LA LÍNEA -->
                                <div class="ruta-card-header">
                                    <div class="ruta-title-group">
                                        <h3>🗺️ <%= h(nombreRuta) %></h3>
                                        <span class="badge-muni">🏛️ <%= h(muniMain) %></span>
                                        <% if (!muniBackup.isEmpty() && !muniBackup.equalsIgnoreCase(muniMain)) { %>
                                            <span class="badge-muni" style="background:#f0fdfa; color:#0f766e;">🏛️ <%= h(muniBackup) %> (Refuerzo)</span>
                                        <% } %>
                                        <% if (!muniExtra.isEmpty() && !muniExtra.equalsIgnoreCase(muniMain) && !muniExtra.equalsIgnoreCase(muniBackup)) { %>
                                            <span class="badge-muni" style="background:#f5f3ff; color:#6d28d9;">🏛️ <%= h(muniExtra) %> (Extra)</span>
                                        <% } %>
                                        <span class="badge-sentido <%= esVuelta ? "sentido-vuelta" : "sentido-ida" %>">
                                            <%= esVuelta ? "🔄 Turno T" + turnoActivoRuta + " · Sentido Retorno" : "➡️ Turno T" + turnoActivoRuta + " · Sentido Ida" %>
                                        </span>
                                    </div>
                                    <div class="estado-pill <%= claseEstado %>" id="badge_estado_<%= idRuta %>">
                                        <%= estadoTexto %>
                                    </div>
                                </div>

                                <div class="ruta-body">
                                    <!-- SELECTOR DE TURNOS + BOTÓN SIMULACIÓN DEMO -->
                                    <div class="turnos-bar">
                                        <div class="turnos-list">
                                            <span style="font-size:12px; font-weight:800; color:#475569; margin-right:4px;">🕒 Horarios por Turno:</span>
                                            <%
                                                for (int i = 0; i < 6; i++) {
                                                    if (salidas[i] != null && !salidas[i].isEmpty()) {
                                                        int numT = i + 1;
                                                        String activoClass = (numT == turnoActivoRuta) ? "activo" : "";
                                                        String dirT = (numT % 2 == 0) ? "Vuelta" : "Ida";
                                                        String hSalCorta = salidas[i].length() >= 5 ? salidas[i].substring(0, 5) : salidas[i];
                                                        String hLlegCorta = (llegadas[i] != null && llegadas[i].length() >= 5) ? llegadas[i].substring(0, 5) : "";
                                            %>
                                                        <a href="lineas.jsp?t_<%= idRuta %>=<%= numT %>#card_ruta_<%= idRuta %>" class="btn-turno <%= activoClass %>">
                                                            T<%= numT %> <%= dirT %> (<%= hSalCorta %> - <%= hLlegCorta %>)
                                                        </a>
                                            <%
                                                    }
                                                }
                                            %>
                                        </div>
                                        <button type="button" class="btn-simular" onclick="simularRecorrido(<%= idRuta %>)">
                                            ▶️ Simular Recorrido en Vivo
                                        </button>
                                    </div>

                                    <!-- 4 TARJETAS DE DATOS CLAVE PARA EL PASAJERO -->
                                    <div class="passenger-kpis">
                                        <div class="kpi-box">
                                            <div class="kpi-label">🚍 Flota, Parqueo y Municipalidad</div>
                                            <div class="kpi-main">Titular: <%= h(placaMain) %> (<%= h(muniMain) %>)</div>
                                            <div class="kpi-sub">
                                                🅿️ Base: <b><%= h(parqueoBase) %></b><br>
                                                🔵 Refuerzo: <b><%= h(placaBackup) %></b><%= !muniBackup.isEmpty() ? " (" + h(muniBackup) + ")" : "" %>
                                                <% if (placaExtra != null) { %> · 🟣 Extra: <b><%= h(placaExtra) %></b><%= !muniExtra.isEmpty() ? " (" + h(muniExtra) + ")" : "" %><% } %>
                                            </div>
                                        </div>

                                        <div class="kpi-box">
                                            <div class="kpi-label">👨‍✈️ Piloto Operativo</div>
                                            <div class="kpi-main"><%= nombrePiloto != null ? h(nombrePiloto) : "Pendiente de asignar" %></div>
                                            <div class="kpi-sub">
                                                🪪 ID Transmetro: <b><%= idPilotoTm != null ? h(idPilotoTm) : "N/A" %></b><br>
                                                🕒 Horario Turno: <b><%= hsActiva.substring(0,5) %> a <%= hlActiva.substring(0,5) %></b>
                                            </div>
                                        </div>

                                        <div class="kpi-box">
                                            <div class="kpi-label">📏 Kilometraje de la Ruta</div>
                                            <div class="kpi-main">
                                                <%= sumaKmRuta.compareTo(BigDecimal.ZERO) > 0 ? sumaKmRuta.toPlainString() + " km totales" : "Sin tramos registrados" %>
                                            </div>
                                            <div class="kpi-sub">
                                                🚏 <b><%= estacionesOrdenadas.size() %></b> estaciones (<%= estacionesOrdenadas.size() - 1 %> tramos)<br>
                                                Avance: <b id="km_avance_<%= idRuta %>">0.00 km</b> recorridos
                                            </div>
                                        </div>

                                        <div class="kpi-box">
                                            <div class="kpi-label">💺 Disponibilidad de Asientos</div>
                                            <div class="kpi-main" style="color:<%= asientosLibres > 0 ? "#059669" : "#dc2626" %>;">
                                                <%= asientosLibres %> libres de <%= totalAsientos %>
                                            </div>
                                            <div class="kpi-sub">
                                                Ocupación actual: <b><%= pctOcupacion %>%</b> (<%= asientosOcupados %> ocupados)
                                                <div class="ocupacion-mini-bar">
                                                    <div class="ocupacion-mini-fill" style="width:<%= pctOcupacion %>%; background:<%= pctOcupacion >= 90 ? "#ef4444" : (pctOcupacion >= 60 ? "#f59e0b" : "#10b981") %>;"></div>
                                                </div>
                                            </div>
                                        </div>
                                    </div>

                                    <!-- ESCENARIO VISUAL ANIMADO DEL RECORRIDO (PIDS) -->
                                    <div class="pids-stage"
                                         id="stage_<%= idRuta %>"
                                         data-id="<%= idRuta %>"
                                         data-placa="<%= h(placaMain) %>"
                                         data-km-total="<%= sumaKmRuta.toPlainString() %>"
                                         data-en-curso="<%= enRutaActiva %>"
                                         data-sec-ini="<%= segSalida %>"
                                         data-sec-fin="<%= segLlegada %>"
                                         data-sec-act="<%= horaActualSeg %>"
                                         data-progreso="<%= String.format(java.util.Locale.US, "%.2f", progresoInicial) %>">

                                        <div class="pids-top-telemetry">
                                            <div class="telemetry-pill">📍 Origen: <b><%= h(origenActual) %></b></div>
                                            <div class="telemetry-pill">🚏 Estado / Próxima Parada: <b id="prox_est_<%= idRuta %>">Calculando...</b></div>
                                            <div class="telemetry-pill">📈 Progreso del Viaje: <b id="pct_txt_<%= idRuta %>"><%= String.format(java.util.Locale.US, "%.0f", progresoInicial) %>%</b></div>
                                            <div class="telemetry-pill">🏁 Destino: <b><%= h(destinoActual) %></b></div>
                                        </div>

                                        <div class="track-wrapper">
                                            <div class="track-inner">
                                                <!-- CARRIL Y BUS ANIMADO -->
                                                <div class="road-lane">
                                                    <div class="road-progress" id="barra_<%= idRuta %>" style="width: <%= String.format(java.util.Locale.US, "%.2f", progresoInicial) %>%;"></div>

                                                    <!-- COMPONENTE DEL BUS EN MOVIMIENTO -->
                                                    <div class="bus-marker" id="bus_<%= idRuta %>" style="left: <%= String.format(java.util.Locale.US, "%.2f", progresoInicial) %>%;">
                                                        <div class="bus-tooltip" id="tooltip_<%= idRuta %>">🚍 <%= h(placaMain) %> · <%= String.format(java.util.Locale.US, "%.0f", progresoInicial) %>%</div>
                                                        <div class="bus-icon-box <%= enRutaActiva ? "en-movimiento" : "" %>" id="bus_icon_<%= idRuta %>">🚍</div>
                                                    </div>
                                                </div>

                                                <!-- NODOS DE ESTACIONES CON SU MOLINETE Y GUARDIA -->
                                                <div class="estaciones-row" id="nodos_<%= idRuta %>">
                                                    <%
                                                        for (int idx = 0; idx < estacionesOrdenadas.size(); idx++) {
                                                            String nomEst = estacionesOrdenadas.get(idx);
                                                            String segInfo = segPorEstacion.get(nomEst.toLowerCase());
                                                    %>
                                                            <div class="estacion-nodo" data-est-nombre="<%= h(nomEst) %>" data-est-idx="<%= idx %>">
                                                                <div class="nodo-circulo"></div>
                                                                <div class="estacion-card-pids">
                                                                    <div class="est-orden">Parada #<%= idx + 1 %></div>
                                                                    <div class="est-nombre">🚏 <%= h(nomEst) %></div>
                                                                    <% if (segInfo != null) { %>
                                                                        <div class="est-molinete"><%= segInfo %></div>
                                                                    <% } else { %>
                                                                        <div class="est-sin-molinete">Sin molinete registrado</div>
                                                                    <% } %>
                                                                </div>
                                                            </div>
                                                    <%
                                                        }
                                                    %>
                                                </div>

                                                <!-- DISTANCIAS EN KM DE CADA TRAMO -->
                                                <% if (!kmsTramos.isEmpty()) { %>
                                                    <div class="tramos-km-layer">
                                                        <% for (int idx = 0; idx < kmsTramos.size(); idx++) {
                                                            BigDecimal kmSeg = kmsTramos.get(idx);
                                                            String origC = estacionesOrdenadas.get(idx);
                                                            String destC = estacionesOrdenadas.get(idx + 1);
                                                        %>
                                                            <div class="tramo-km-pill" title="<%= h(origC) %> ➔ <%= h(destC) %>">
                                                                📏 Tramo <%= idx + 1 %>: <%= kmSeg.compareTo(BigDecimal.ZERO) > 0 ? kmSeg.toPlainString() + " km" : "S/D" %>
                                                            </div>
                                                        <% } %>
                                                    </div>
                                                <% } %>
                                            </div>
                                        </div>
                                    </div>

                                    <!-- BOTONES DE ACCIÓN PARA EL PASAJERO Y ADMIN -->
                                    <div class="ruta-footer-actions">
                                        <a href="operacion.jsp?filtro_ruta=<%= idRuta %>" class="btn-ver-asientos">
                                            💺 Abordar / Ver Mapa de Asientos en Vivo (<%= asientosLibres %> disponibles) →
                                        </a>
                                        <a href="infraestructura.jsp" class="btn-link-sec">🏢 Ver Seguridad y Molinetes</a>
                                        <% if ("admin".equals(rolActual)) { %>
                                            <a href="editar_rutas.jsp?accion=editar&id_ruta=<%= idRuta %>" class="btn-link-sec" style="background:#e0f2fe; color:#0369a1; border-color:#bae6fd;">
                                                ✏️ Editar Ruta y Kilometraje
                                            </a>
                                        <% } %>
                                    </div>
                                </div>
                            </div>
            <%
                        }
                        if (!hayRutas) {
                            if (!filtroMuni.isEmpty()) {
                                out.print("<div class='empty-state'>🏛️ La municipalidad <b>" + h(filtroMuni) + "</b> ya está registrada en el sistema, pero aún no tiene rutas operativas asignadas.<br><br><a href='lineas.jsp' style='color:#0d9488; font-weight:800;'>← Ver todas las rutas activas</a> · <a href='estaciones.jsp#municipalidades' style='color:#0284c7; font-weight:800;'>Ver Directorio de Municipalidades →</a></div>");
                            } else {
                                out.print("<div class='empty-state'>Actualmente no hay rutas operativas configuradas en el sistema.</div>");
                            }
                        }
                        rs.close();
                        st.close();
                    }
                } catch (Exception e) {
                    out.print("<div class='empty-state'>Error cargando líneas: " + h(e.getMessage()) + "</div>");
                }
            %>
        </div>

        <div class="refresh-indicator">
            <span class="refresh-dot"></span> Telemetría sincronizada en tiempo real (Auto-actualización inteligente cada 20s)
        </div>
    </div>

    <script>
        let menuAbierto = false;
        let simulacionActiva = false;
        const timersSimulacion = {};

        function toggleMenu(side) {
            let left = document.getElementById("leftSidebar");
            let right = document.getElementById("rightSidebar");
            let overlay = document.getElementById("overlay");
            if (side === 'left') { left.style.width = "250px"; if (right) right.style.width = "0"; }
            else if (side === 'right') { if (right) right.style.width = "300px"; left.style.width = "0"; }
            overlay.style.display = "block";
            menuAbierto = true;
        }
        function closeAllMenus() {
            document.getElementById("leftSidebar").style.width = "0";
            let right = document.getElementById("rightSidebar");
            if (right) right.style.width = "0";
            document.getElementById("overlay").style.display = "none";
            menuAbierto = false;
        }

        // Reloj digital en vivo
        function actualizarReloj() {
            const ahora = new Date();
            const hh = String(ahora.getHours()).padStart(2, '0');
            const mm = String(ahora.getMinutes()).padStart(2, '0');
            const ss = String(ahora.getSeconds()).padStart(2, '0');
            const el = document.getElementById("relojDigital");
            if (el) el.textContent = hh + ":" + mm + ":" + ss;
        }
        setInterval(actualizarReloj, 1000);
        actualizarReloj();

        // Actualiza visualmente la posición del bus, los kilómetros recorridos y qué estación está activa/completada
        function renderizarEstadoPids(idRuta, porcentaje) {
            const stage = document.getElementById("stage_" + idRuta);
            if (!stage) return;

            const pct = Math.min(100, Math.max(0, porcentaje));
            const placa = stage.getAttribute("data-placa") || "Bus";
            const kmTotal = parseFloat(stage.getAttribute("data-km-total") || "0");
            const kmRecorridos = (kmTotal * (pct / 100.0)).toFixed(2);

            const barra = document.getElementById("barra_" + idRuta);
            const bus = document.getElementById("bus_" + idRuta);
            const tooltip = document.getElementById("tooltip_" + idRuta);
            const pctTxt = document.getElementById("pct_txt_" + idRuta);
            const kmAvance = document.getElementById("km_avance_" + idRuta);
            const proxEstEl = document.getElementById("prox_est_" + idRuta);

            if (barra) barra.style.width = pct.toFixed(1) + "%";
            if (bus) bus.style.left = pct.toFixed(1) + "%";
            if (tooltip) tooltip.textContent = "🚍 " + placa + " · " + pct.toFixed(0) + "% (" + kmRecorridos + " km)";
            if (pctTxt) pctTxt.textContent = pct.toFixed(0) + "%";
            if (kmAvance) kmAvance.textContent = kmRecorridos + " km";

            // Iluminar estaciones según el porcentaje
            const contNodos = document.getElementById("nodos_" + idRuta);
            if (contNodos) {
                const nodos = contNodos.querySelectorAll(".estacion-nodo");
                const totalNodos = nodos.length;
                let proximaNombre = "Terminal alcanzada";

                nodos.forEach((nodo, i) => {
                    nodo.classList.remove("completada", "actual");
                    const umbralEstacion = totalNodos > 1 ? (i / (totalNodos - 1)) * 100.0 : 0;
                    const nombreE = nodo.getAttribute("data-est-nombre");

                    if (pct >= umbralEstacion + 2 || (pct >= 99.5 && i === totalNodos - 1)) {
                        nodo.classList.add("completada");
                    } else if (proximaNombre === "Terminal alcanzada") {
                        nodo.classList.add("actual");
                        proximaNombre = nombreE;
                    }
                });

                if (proxEstEl) {
                    if (pct <= 0.1) {
                        proxEstEl.textContent = "En estación de origen (" + (nodos[0] ? nodos[0].getAttribute("data-est-nombre") : "") + ")";
                    } else if (pct >= 99.5) {
                        proxEstEl.textContent = "Llegó a destino (" + (nodos[totalNodos - 1] ? nodos[totalNodos - 1].getAttribute("data-est-nombre") : "") + ")";
                    } else {
                        proxEstEl.textContent = "Hacia " + proximaNombre;
                    }
                }
            }
        }

        // Inicializar todas las tarjetas y avanzar segundo a segundo las que están en curso
        document.querySelectorAll(".pids-stage").forEach(stage => {
            const idRuta = stage.getAttribute("data-id");
            const prog = parseFloat(stage.getAttribute("data-progreso") || "0");
            renderizarEstadoPids(idRuta, prog);
        });

        setInterval(() => {
            document.querySelectorAll(".pids-stage").forEach(stage => {
                const idRuta = stage.getAttribute("data-id");
                if (timersSimulacion[idRuta]) return; // Si está en modo demo manual, lo controla su propio timer

                const enCurso = stage.getAttribute("data-en-curso") === "true";
                if (!enCurso) return;

                let tIni = parseInt(stage.getAttribute("data-sec-ini") || "0");
                let tFin = parseInt(stage.getAttribute("data-sec-fin") || "1");
                let tAct = parseInt(stage.getAttribute("data-sec-act") || "0") + 1;
                stage.setAttribute("data-sec-act", tAct);

                if (tAct >= tIni && tAct <= tFin && tFin > tIni) {
                    const pct = ((tAct - tIni) / (tFin - tIni)) * 100.0;
                    renderizarEstadoPids(idRuta, pct);
                }
            });
        }, 1000);

        // Modo Demo: Permite ver la animación completa del bus recorriendo todas las estaciones en cualquier momento
        function simularRecorrido(idRuta) {
            simulacionActiva = true;
            if (timersSimulacion[idRuta]) {
                clearInterval(timersSimulacion[idRuta]);
            }
            const iconBox = document.getElementById("bus_icon_" + idRuta);
            const badgeEstado = document.getElementById("badge_estado_" + idRuta);
            if (iconBox) iconBox.classList.add("en-movimiento");
            if (badgeEstado) {
                badgeEstado.className = "estado-pill estado-en-curso";
                badgeEstado.innerHTML = "🟢 SIMULACIÓN EN VIVO: Unidad recorriendo estaciones";
            }

            let pctDemo = 0;
            renderizarEstadoPids(idRuta, 0);

            timersSimulacion[idRuta] = setInterval(() => {
                pctDemo += 2.5;
                if (pctDemo >= 100) {
                    pctDemo = 100;
                    renderizarEstadoPids(idRuta, 100);
                    clearInterval(timersSimulacion[idRuta]);
                    timersSimulacion[idRuta] = null;
                    if (badgeEstado) {
                        badgeEstado.innerHTML = "✅ Recorrido Completado (100%)";
                    }
                } else {
                    renderizarEstadoPids(idRuta, pctDemo);
                }
            }, 350);
        }

        // Auto-Refresh cada 20 segundos si no se está usando el menú ni ejecutando una demostración
        setInterval(() => {
            if (!menuAbierto && !simulacionActiva) {
                window.location.reload();
            }
        }, 20000);
    </script>
</body>
</html>