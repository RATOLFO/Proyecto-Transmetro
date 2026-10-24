<%@page contentType="text/html" pageEncoding="UTF-8"%>
<%@page import="java.sql.*"%>
<%@page import="java.util.*"%>
<%@page import="java.math.BigDecimal"%>
<%!
    // Escapa texto antes de imprimirlo en HTML
    static String h(String s) {
        if (s == null) return "";
        return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace("\"", "&quot;").replace("'", "&#39;");
    }

    // Campo CSV entre comillas (las comillas internas se duplican)
    static String csv(String s) {
        if (s == null) s = "";
        return "\"" + s.replace("\"", "\"\"") + "\"";
    }

    static void asegurarColumnaPiloto(Connection con) {
        try (Statement st = con.createStatement()) {
            st.executeUpdate("ALTER TABLE rutas_operativas ADD COLUMN id_piloto INT DEFAULT NULL");
        } catch (SQLException ignorar) {}
    }

    // ---------------------------------------------------------------------------------------
    // CONSULTAS DE INTELIGENCIA OPERATIVA
    // ---------------------------------------------------------------------------------------
    static final String ASIENTOS_RUTA = "a.id_bus IN (r.id_vehiculo_main, r.id_vehiculo_backup, r.id_vehiculo_extra)";

    static final String SQL_OCUPACION =
        "SELECT r.id_ruta, r.nombre_ruta, r.lista_estaciones, " +
        "vm.placa AS placa_main, IFNULL(pm.nombre, 'Sin parqueo') AS parqueo_main, " +
        "vb.placa AS placa_backup, " +
        "ve.placa AS placa_extra, " +
        "IFNULL(pil.nombre, 'Sin piloto asignado') AS piloto_nombre, " +
        "IFNULL(pil.identificador_transmetro, '') AS piloto_id, " +
        "(SELECT COUNT(*) FROM asientos a WHERE a.id_bus = r.id_vehiculo_main) AS tot_main, " +
        "(SELECT COUNT(*) FROM asientos a WHERE a.id_bus = r.id_vehiculo_main AND a.estado <> 'libre') AS ocu_main, " +
        "(SELECT COUNT(*) FROM asientos a WHERE a.id_bus = r.id_vehiculo_backup) AS tot_backup, " +
        "(SELECT COUNT(*) FROM asientos a WHERE a.id_bus = r.id_vehiculo_backup AND a.estado <> 'libre') AS ocu_backup, " +
        "(SELECT COUNT(*) FROM asientos a WHERE r.id_vehiculo_extra IS NOT NULL AND a.id_bus = r.id_vehiculo_extra) AS tot_extra, " +
        "(SELECT COUNT(*) FROM asientos a WHERE r.id_vehiculo_extra IS NOT NULL AND a.id_bus = r.id_vehiculo_extra AND a.estado <> 'libre') AS ocu_extra, " +
        "(SELECT COUNT(*) FROM asientos a WHERE " + ASIENTOS_RUTA + ") AS total, " +
        "(SELECT COUNT(*) FROM asientos a WHERE " + ASIENTOS_RUTA + " AND a.estado <> 'libre') AS ocupados, " +
        "(SELECT COALESCE(SUM(d.distancia_km), 0) FROM distancias_tramos d WHERE d.id_ruta = r.id_ruta) AS km, " +
        "(SELECT COUNT(*) FROM distancias_tramos d WHERE d.id_ruta = r.id_ruta) AS num_tramos " +
        "FROM rutas_operativas r " +
        "LEFT JOIN flota_vehiculos vm ON r.id_vehiculo_main = vm.id_vehiculo " +
        "LEFT JOIN parqueos pm ON vm.id_parqueo = pm.id_parqueo " +
        "LEFT JOIN flota_vehiculos vb ON r.id_vehiculo_backup = vb.id_vehiculo " +
        "LEFT JOIN flota_vehiculos ve ON r.id_vehiculo_extra = ve.id_vehiculo " +
        "LEFT JOIN pilotos_catalogo pil ON r.id_piloto = pil.id " +
        "ORDER BY (ocupados / NULLIF(total, 0)) DESC, r.nombre_ruta ASC";

    static final String SQL_MUNICIPAL =
        "SELECT m.nombre, COUNT(f.id_vehiculo) AS unidades, " +
        "COALESCE(SUM(f.capacidad), 0) AS capacidad_total, " +
        "COALESCE(SUM(CASE WHEN f.estado = 'En Ruta' OR f.id_vehiculo IN (" +
            "SELECT id_vehiculo_main FROM rutas_operativas UNION " +
            "SELECT id_vehiculo_backup FROM rutas_operativas UNION " +
            "SELECT id_vehiculo_extra FROM rutas_operativas WHERE id_vehiculo_extra IS NOT NULL) THEN 1 ELSE 0 END), 0) AS en_ruta, " +
        "COALESCE(SUM(CASE WHEN f.estado = 'Mantenimiento' THEN 1 ELSE 0 END), 0) AS en_mantenimiento, " +
        "GROUP_CONCAT(f.placa ORDER BY f.placa SEPARATOR ', ') AS placas " +
        "FROM municipalidades m LEFT JOIN flota_vehiculos f ON f.municipalidad = m.nombre " +
        "GROUP BY m.nombre ORDER BY unidades DESC, m.nombre ASC";

    static final String SQL_PILOTOS =
        "SELECT p.id, IFNULL(p.nombre, '') AS nombre, IFNULL(p.edad, 0) AS edad, " +
        "IFNULL(p.identificador_transmetro, 'Sin ID') AS identificador_transmetro, " +
        "IFNULL(p.usuario_asignado, 'Sin asignar') AS usuario, " +
        "IFNULL((SELECT GROUP_CONCAT(CONCAT(r.nombre_ruta, ' (🚍 ', IFNULL(vm.placa, 'S/P'), IF(pm.nombre IS NOT NULL, CONCAT(' · 🅿️ ', pm.nombre), ''), ')') SEPARATOR ' | ') " +
        " FROM rutas_operativas r " +
        " LEFT JOIN flota_vehiculos vm ON r.id_vehiculo_main = vm.id_vehiculo " +
        " LEFT JOIN parqueos pm ON vm.id_parqueo = pm.id_parqueo " +
        " WHERE r.id_piloto = p.id), 'Sin ruta asignada') AS ruta_asignada " +
        "FROM pilotos_catalogo p ORDER BY p.nombre ASC";

    static final String SQL_INFRA_PARQUEOS =
        "SELECT p.id_parqueo, p.nombre, " +
        "p.capacidad_buses, COUNT(f.id_vehiculo) AS ocupados, " +
        "GROUP_CONCAT(CONCAT(f.placa, ' (', IFNULL(f.estado, 'Libre'), ')') ORDER BY f.placa SEPARATOR ', ') AS detalle_buses " +
        "FROM parqueos p LEFT JOIN flota_vehiculos f ON f.id_parqueo = p.id_parqueo " +
        "GROUP BY p.id_parqueo, p.nombre, p.capacidad_buses ORDER BY p.nombre ASC";

    static final String SQL_INFRA_ESTACIONES =
        "SELECT e.id_estacion, e.nombre, e.latitud, e.longitud, " +
        "a.codigo_puerta, g.nombre_completo AS guardia, g.turno " +
        "FROM estaciones_fisicas e " +
        "LEFT JOIN accesos_molinetes a ON a.id_estacion = e.id_estacion " +
        "LEFT JOIN guardias_seguridad g ON g.id_acceso = a.id_acceso " +
        "ORDER BY e.nombre ASC, a.codigo_puerta ASC";

    static final String SQL_ALERTAS =
        "SELECT id, tipo_gravedad, bus_ruta, descripcion, reportado_por, " +
        "DATE_FORMAT(fecha_hora, '%d/%m/%Y %H:%i') AS fecha_fmt, " +
        "IFNULL(estado, 'Activa') AS estado, IFNULL(audiencia, 'interna') AS audiencia " +
        "FROM alertas ORDER BY fecha_hora DESC LIMIT 100";

    static String pct(int parte, int total) {
        return total > 0 ? String.format(java.util.Locale.US, "%.1f", parte * 100.0 / total) : "0.0";
    }

    static String recomendacionMunicipal(int unidades, int enRuta, int enMant) {
        if (unidades == 0) return "Sin flota: asignar unidades";
        if (enMant > 0 && enMant == unidades) return "Crítico: toda la flota en taller";
        if (enRuta == 0) return "Unidades en garaje sin ruta";
        if (unidades < 2) return "Analizar ampliar cobertura";
        return "Cobertura operativa óptima";
    }
%>
<%
    if (session.getAttribute("usuarioValido") == null) { response.sendRedirect("login.jsp"); return; }
    String rolActual = (String) session.getAttribute("rol");
    if (!"admin".equals(rolActual) && !"piloto".equals(rolActual)) { response.sendRedirect("index.jsp"); return; }

    String usuarioActual = String.valueOf(session.getAttribute("nombre") != null ? session.getAttribute("nombre") : "Usuario");
    String dbUrl = "jdbc:mysql://192.168.15.135:3306/transmetro_db";
    String dbUser = "admin";
    String dbPass = "admin123";

    String tipoReporte = request.getParameter("tipo");
    if (!"ocupacion".equals(tipoReporte) && !"municipalidad".equals(tipoReporte)
            && !"pilotos".equals(tipoReporte) && !"infraestructura".equals(tipoReporte)
            && !"alertas".equals(tipoReporte)) {
        tipoReporte = "ocupacion";
    }

    // =========================================================================================
    // EXPORTACIÓN A EXCEL (CSV)
    // =========================================================================================
    if ("csv".equals(request.getParameter("exportar"))) {
        out.clear();
        response.setContentType("text/csv; charset=UTF-8");
        response.setHeader("Content-Disposition", "attachment; filename=\"Reporte_Transmetro_" + tipoReporte + ".csv\"");
        out.print("\uFEFF");

        try {
            Class.forName("com.mysql.cj.jdbc.Driver");
            try (Connection con = DriverManager.getConnection(dbUrl, dbUser, dbPass)) {
                asegurarColumnaPiloto(con);
                try (Statement st = con.createStatement()) {
                    if ("ocupacion".equals(tipoReporte)) {
                        out.println("Ruta,Bus Principal,Ocupacion Principal,Bus Refuerzo 1,Ocupacion Refuerzo 1,Bus Extra 2do Refuerzo,Ocupacion Extra,Parqueo Base,Piloto Asignado,Asientos Ocupados Totales,Capacidad Total Ruta,Porcentaje Ocupado,Distancia Km");
                        try (ResultSet rs = st.executeQuery(SQL_OCUPACION)) {
                            while (rs.next()) {
                                int ocu = rs.getInt("ocupados"), tot = rs.getInt("total");
                                String pExtra = rs.getString("placa_extra") != null ? rs.getString("placa_extra") : "En Parqueo (No activo)";
                                out.println(
                                    csv(rs.getString("nombre_ruta")) + "," +
                                    csv(rs.getString("placa_main")) + "," +
                                    csv(rs.getInt("ocu_main") + "/" + rs.getInt("tot_main")) + "," +
                                    csv(rs.getString("placa_backup")) + "," +
                                    csv(rs.getInt("ocu_backup") + "/" + rs.getInt("tot_backup")) + "," +
                                    csv(pExtra) + "," +
                                    csv(rs.getInt("ocu_extra") + "/" + rs.getInt("tot_extra")) + "," +
                                    csv(rs.getString("parqueo_main")) + "," +
                                    csv(rs.getString("piloto_nombre")) + "," +
                                    ocu + "," + tot + "," + pct(ocu, tot) + "%," + rs.getBigDecimal("km")
                                );
                            }
                        }
                    } else if ("municipalidad".equals(tipoReporte)) {
                        out.println("Municipalidad,Unidades en Flota,En Ruta,En Mantenimiento,Capacidad Total Asientos,Placas Registradas,Recomendacion");
                        try (ResultSet rs = st.executeQuery(SQL_MUNICIPAL)) {
                            while (rs.next()) {
                                int uni = rs.getInt("unidades"), enRuta = rs.getInt("en_ruta"), mant = rs.getInt("en_mantenimiento");
                                out.println(
                                    csv(rs.getString("nombre")) + "," + uni + "," + enRuta + "," + mant + "," +
                                    rs.getInt("capacidad_total") + "," +
                                    csv(rs.getString("placas") != null ? rs.getString("placas") : "Ninguna") + "," +
                                    csv(recomendacionMunicipal(uni, enRuta, mant))
                                );
                            }
                        }
                    } else if ("pilotos".equals(tipoReporte)) {
                        out.println("Piloto,Edad,Identificador Transmetro,Cuenta de Usuario,Ruta y Unidad Asignada");
                        try (ResultSet rs = st.executeQuery(SQL_PILOTOS)) {
                            while (rs.next()) {
                                out.println(
                                    csv(rs.getString("nombre")) + "," + rs.getInt("edad") + "," +
                                    csv(rs.getString("identificador_transmetro")) + "," +
                                    csv(rs.getString("usuario")) + "," +
                                    csv(rs.getString("ruta_asignada"))
                                );
                            }
                        }
                    } else if ("alertas".equals(tipoReporte)) {
                        out.println("ID,Fecha y Hora,Gravedad,Unidad o Ruta,Descripcion,Reportado Por,Audiencia,Estado");
                        try (ResultSet rs = st.executeQuery(SQL_ALERTAS)) {
                            while (rs.next()) {
                                out.println(
                                    rs.getInt("id") + "," +
                                    csv(rs.getString("fecha_fmt")) + "," +
                                    csv(rs.getString("tipo_gravedad")) + "," +
                                    csv(rs.getString("bus_ruta")) + "," +
                                    csv(rs.getString("descripcion")) + "," +
                                    csv(rs.getString("reportado_por")) + "," +
                                    csv(rs.getString("audiencia")) + "," +
                                    csv(rs.getString("estado"))
                                );
                            }
                        }
                    } else {
                        out.println("ID Parqueo,Parqueo,Capacidad (buses),Ocupados,Disponibles,Unidades Asignadas");
                        try (ResultSet rs = st.executeQuery(SQL_INFRA_PARQUEOS)) {
                            while (rs.next()) {
                                int cap = rs.getInt("capacidad_buses"), ocu = rs.getInt("ocupados");
                                out.println(
                                    rs.getInt("id_parqueo") + "," +
                                    csv(rs.getString("nombre")) + "," +
                                    cap + "," + ocu + "," + Math.max(0, cap - ocu) + "," +
                                    csv(rs.getString("detalle_buses") != null ? rs.getString("detalle_buses") : "Sin unidades")
                                );
                            }
                        }
                    }
                }
            }
        } catch (Exception e) {
            out.println("Error al generar CSV: " + e.getMessage());
        }
        return;
    }
%>

<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <title>Centro de Inteligencia y Reportes - Transmetro</title>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&display=swap" rel="stylesheet">
    <style>
        body { font-family: 'Inter', 'Segoe UI', sans-serif; background-color: #f1f5f9; margin: 0; padding-top: 70px; color: #0f172a; }
        .header { background: #ffffff; color: #1e293b; padding: 15px 25px; position: fixed; top: 0; width: 100%; box-sizing: border-box; z-index: 1000; display: flex; justify-content: space-between; align-items: center; border-bottom: 1px solid #e2e8f0; box-shadow: 0 1px 3px rgba(0,0,0,0.04); }
        .header h1 { margin: 0; font-size: 18px; text-align: center; flex-grow: 1; font-weight: 800; letter-spacing: 0.3px; }
        .menu-btn { background: none; border: none; color: #475569; font-size: 24px; cursor: pointer; transition: 0.2s; border-radius: 5px; padding: 5px 10px; }
        .overlay { display: none; position: fixed; width: 100%; height: 100%; top: 0; left: 0; background: rgba(15, 23, 42, 0.4); backdrop-filter: blur(2px); z-index: 999; }

        .main-container { max-width: 1240px; margin: 25px auto; padding: 0 20px 55px 20px; }

        /* Banner Superior Ejecutivo */
        .hero-banner {
            background: linear-gradient(135deg, #0f172a 0%, #1e3a8a 60%, #0284c7 100%);
            color: #ffffff;
            border-radius: 16px;
            padding: 24px 28px;
            margin-bottom: 22px;
            display: flex;
            justify-content: space-between;
            align-items: center;
            flex-wrap: wrap;
            gap: 16px;
            box-shadow: 0 10px 25px -5px rgba(15, 23, 42, 0.25);
        }
        .hero-banner h2 { margin: 0 0 6px 0; font-size: 24px; font-weight: 800; letter-spacing: -0.3px; }
        .hero-banner p { margin: 0; color: #bae6fd; font-size: 14px; }
        .hero-actions { display: flex; gap: 10px; flex-wrap: wrap; }
        .btn-export { display: inline-flex; align-items: center; gap: 8px; padding: 10px 16px; border-radius: 10px; text-decoration: none; font-weight: 700; font-size: 13px; transition: 0.2s; cursor: pointer; border: none; }
        .btn-print { background: rgba(255,255,255,0.14); color: #ffffff; border: 1px solid rgba(255,255,255,0.28); backdrop-filter: blur(4px); }
        .btn-print:hover { background: rgba(255,255,255,0.24); }
        .btn-excel { background: #10b981; color: #ffffff; box-shadow: 0 4px 12px rgba(16, 185, 129, 0.35); }
        .btn-excel:hover { background: #059669; transform: translateY(-1px); }

        /* Tarjetas KPI Globales */
        .kpi-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(215px, 1fr));
            gap: 14px;
            margin-bottom: 24px;
        }
        .kpi-card {
            background: #ffffff;
            border-radius: 14px;
            padding: 16px 18px;
            border: 1px solid #e2e8f0;
            box-shadow: 0 2px 6px rgba(0,0,0,0.03);
            display: flex;
            flex-direction: column;
            gap: 6px;
            position: relative;
            overflow: hidden;
        }
        .kpi-card::before {
            content: "";
            position: absolute;
            top: 0; left: 0; width: 4px; height: 100%;
            background: var(--kpi-color, #0284c7);
        }
        .kpi-top { display: flex; justify-content: space-between; align-items: center; font-size: 12px; font-weight: 700; color: #64748b; text-transform: uppercase; letter-spacing: 0.4px; }
        .kpi-val { font-size: 26px; font-weight: 800; color: #0f172a; line-height: 1.1; }
        .kpi-sub { font-size: 12px; color: #475569; font-weight: 500; }

        /* Barra de Pestañas y Buscador */
        .toolbar-row {
            display: flex;
            justify-content: space-between;
            align-items: center;
            gap: 14px;
            flex-wrap: wrap;
            margin-bottom: 18px;
        }
        .tabs-container { display: flex; gap: 8px; flex-wrap: wrap; }
        .tab-btn {
            padding: 10px 16px;
            text-decoration: none;
            color: #475569;
            background: #ffffff;
            border: 1px solid #e2e8f0;
            font-weight: 700;
            font-size: 13px;
            border-radius: 10px;
            transition: 0.2s;
            display: inline-flex;
            align-items: center;
            gap: 6px;
        }
        .tab-btn:hover { background: #f8fafc; color: #0f172a; border-color: #cbd5e1; }
        .tab-active {
            background: #1e3a8a !important;
            color: #ffffff !important;
            border-color: #1e3a8a !important;
            box-shadow: 0 4px 12px rgba(30, 58, 138, 0.25);
        }

        .search-box {
            position: relative;
            min-width: 260px;
        }
        .search-box input {
            width: 100%;
            padding: 10px 14px 10px 34px;
            border-radius: 10px;
            border: 1px solid #cbd5e1;
            background: #ffffff;
            font-size: 13px;
            box-sizing: border-box;
            outline: none;
        }
        .search-box input:focus { border-color: #0284c7; box-shadow: 0 0 0 3px rgba(2, 132, 199, 0.12); }
        .search-box .search-icon {
            position: absolute;
            left: 11px;
            top: 50%;
            transform: translateY(-50%);
            font-size: 13px;
            color: #64748b;
        }

        /* Tarjetas de Reporte */
        .report-card {
            background: #ffffff;
            border-radius: 14px;
            box-shadow: 0 4px 10px -2px rgba(0,0,0,0.04);
            border: 1px solid #e2e8f0;
            overflow-x: auto;
            padding: 24px;
            margin-bottom: 22px;
        }
        .report-card-header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            flex-wrap: wrap;
            gap: 10px;
            border-bottom: 1px solid #f1f5f9;
            padding-bottom: 14px;
            margin-bottom: 18px;
        }
        .report-card-title { font-size: 17px; color: #0f172a; font-weight: 800; margin: 0; }
        .report-note { font-size: 12px; color: #64748b; margin: 14px 0 0 0; line-height: 1.5; }

        /*Tablas*/
        table { width: 100%; border-collapse: collapse; text-align: left; }
        th { background-color: #f8fafc; padding: 12px 14px; font-size: 11px; color: #475569; font-weight: 800; text-transform: uppercase; letter-spacing: 0.4px; border-bottom: 2px solid #e2e8f0; }
        td { padding: 13px 14px; font-size: 13.5px; color: #334155; border-bottom: 1px solid #f1f5f9; vertical-align: middle; }
        tr:hover td { background-color: #f8fafc; }

        /* Badges */
        .badge { display: inline-flex; align-items: center; gap: 4px; padding: 4px 10px; border-radius: 999px; font-size: 11.5px; font-weight: 700; white-space: nowrap; }
        .badge-warning { background: #fef3c7; color: #92400e; border: 1px solid #fde68a; }
        .badge-danger { background: #fee2e2; color: #991b1b; border: 1px solid #fecaca; }
        .badge-success { background: #dcfce7; color: #166534; border: 1px solid #bbf7d0; }
        .badge-info { background: #e0f2fe; color: #0369a1; border: 1px solid #bae6fd; }
        .badge-purple { background: #f3e8ff; color: #6b21a8; border: 1px solid #e9d5ff; }
        .badge-neutral { background: #f1f5f9; color: #475569; border: 1px solid #e2e8f0; }

        /* Barras de progreso */
        .barra-wrap { display: flex; align-items: center; gap: 10px; }
        .barra { width: 110px; height: 9px; background: #e2e8f0; border-radius: 999px; overflow: hidden; flex-shrink: 0; }
        .barra > div { height: 100%; background: linear-gradient(90deg, #10b981, #059669); border-radius: 999px; transition: width 0.4s ease; }
        .barra.media > div { background: linear-gradient(90deg, #f59e0b, #d97706); }
        .barra.alta > div { background: linear-gradient(90deg, #ef4444, #dc2626); }

        .bus-pill-list { display: flex; flex-direction: column; gap: 5px; }
        .bus-pill { display: inline-flex; align-items: center; gap: 6px; font-size: 12px; background: #f8fafc; border: 1px solid #e2e8f0; padding: 4px 8px; border-radius: 6px; }
        .bus-pill b { color: #0f172a; }

        .vacio { text-align: center; padding: 30px; color: #94a3b8; font-weight: 600; }

        /* Encabezado exclusivo para Impresión / PDF */
        .print-only-header { display: none; }

        @media print {
            body { background: white; padding: 0; color: #000; }
            .header, .sidebar, .overlay, .toolbar-row, .hero-actions, .menu-btn { display: none !important; }
            .hero-banner { background: none !important; color: #000 !important; border: 2px solid #000; box-shadow: none; padding: 12px 16px; }
            .hero-banner p { color: #333 !important; }
            .print-only-header { display: block; margin-bottom: 12px; font-size: 12px; color: #333; border-bottom: 1px solid #ccc; padding-bottom: 8px; }
            .main-container { margin: 0; padding: 0; max-width: 100%; }
            .report-card { box-shadow: none; border: 1px solid #ccc; padding: 12px; break-inside: avoid; }
            th { border-bottom: 2px solid #000; color: #000; }
            td { border-bottom: 1px solid #ddd; color: #000; }
        }
    </style>
    <link rel="stylesheet" href="css/transmetro.css">
</head>
<body>

    <jsp:include page="menu_izquierdo.jsp" />
    <jsp:include page="menu_derecho.jsp" />
    <div id="overlay" class="overlay" onclick="closeAllMenus()"></div>

    <div class="header">
        <button class="menu-btn" onclick="toggleMenu('left')">☰</button>
        <h1>Centro de Inteligencia y Reportes</h1>
        <% if ("admin".equals(rolActual)) { %>
            <button class="menu-btn" onclick="toggleMenu('right')">⚙️</button>
        <% } else { %>
            <div style="width: 34px;"></div>
        <% } %>
    </div>

    <%
        Connection con = null;
        Statement st = null;
        String errorBD = null;

        // Variables de KPIs Globales
        int kpiTotalRutas = 0;
        BigDecimal kpiKmRed = BigDecimal.ZERO;
        int kpiFlotaTotal = 0, kpiFlotaEnRuta = 0, kpiFlotaGaraje = 0, kpiFlotaMant = 0;
        int kpiAsientosOcupados = 0, kpiAsientosTotales = 0;
        int kpiEstaciones = 0, kpiMolinetes = 0, kpiGuardias = 0;
        int kpiAlertasActivas = 0, kpiAlertasResueltas = 0;

        try {
            Class.forName("com.mysql.cj.jdbc.Driver");
            con = DriverManager.getConnection(dbUrl, dbUser, dbPass);
            asegurarColumnaPiloto(con);
            st = con.createStatement();

            // 1. KPI Rutas y Km
            try (ResultSet rsK = st.executeQuery(
                    "SELECT (SELECT COUNT(*) FROM rutas_operativas) AS rutas, " +
                    "(SELECT COALESCE(SUM(distancia_km), 0) FROM distancias_tramos) AS km")) {
                if (rsK.next()) {
                    kpiTotalRutas = rsK.getInt("rutas");
                    kpiKmRed = rsK.getBigDecimal("km") != null ? rsK.getBigDecimal("km") : BigDecimal.ZERO;
                }
            }

            // 2. KPI Flota
            try (ResultSet rsF = st.executeQuery(
                    "SELECT COUNT(*) AS total, " +
                    "COALESCE(SUM(CASE WHEN estado = 'En Ruta' THEN 1 ELSE 0 END), 0) AS en_ruta, " +
                    "COALESCE(SUM(CASE WHEN estado = 'Libre en Garaje' THEN 1 ELSE 0 END), 0) AS garaje, " +
                    "COALESCE(SUM(CASE WHEN estado = 'Mantenimiento' THEN 1 ELSE 0 END), 0) AS mant " +
                    "FROM flota_vehiculos")) {
                if (rsF.next()) {
                    kpiFlotaTotal = rsF.getInt("total");
                    kpiFlotaEnRuta = rsF.getInt("en_ruta");
                    kpiFlotaGaraje = rsF.getInt("garaje");
                    kpiFlotaMant = rsF.getInt("mant");
                }
            }

            // 3. KPI Ocupación Global de Asientos en Rutas Activas
            try (ResultSet rsO = st.executeQuery(
                    "SELECT COUNT(*) AS tot, COALESCE(SUM(CASE WHEN a.estado <> 'libre' THEN 1 ELSE 0 END), 0) AS ocu " +
                    "FROM asientos a WHERE a.id_bus IN (" +
                    "SELECT id_vehiculo_main FROM rutas_operativas UNION " +
                    "SELECT id_vehiculo_backup FROM rutas_operativas UNION " +
                    "SELECT id_vehiculo_extra FROM rutas_operativas WHERE id_vehiculo_extra IS NOT NULL)")) {
                if (rsO.next()) {
                    kpiAsientosTotales = rsO.getInt("tot");
                    kpiAsientosOcupados = rsO.getInt("ocu");
                }
            }

            // 4. KPI Estaciones, Molinetes y Guardias
            try (ResultSet rsI = st.executeQuery(
                    "SELECT (SELECT COUNT(*) FROM estaciones_fisicas) AS est, " +
                    "(SELECT COUNT(*) FROM accesos_molinetes) AS mol, " +
                    "(SELECT COUNT(*) FROM guardias_seguridad) AS gua")) {
                if (rsI.next()) {
                    kpiEstaciones = rsI.getInt("est");
                    kpiMolinetes = rsI.getInt("mol");
                    kpiGuardias = rsI.getInt("gua");
                }
            }

            // 5. KPI Alertas
            try (ResultSet rsA = st.executeQuery(
                    "SELECT COALESCE(SUM(CASE WHEN estado = 'Activa' THEN 1 ELSE 0 END), 0) AS act, " +
                    "COALESCE(SUM(CASE WHEN estado = 'Resuelta' THEN 1 ELSE 0 END), 0) AS res " +
                    "FROM alertas")) {
                if (rsA.next()) {
                    kpiAlertasActivas = rsA.getInt("act");
                    kpiAlertasResueltas = rsA.getInt("res");
                }
            }
        } catch (Exception e) {
            errorBD = e.getMessage();
        }
    %>

    <div class="main-container">
        <div class="print-only-header">
            <b>SISTEMA DE CONTROL OPERATIVO TRANSMETRO</b> — Reporte generado por: <b><%= h(usuarioActual) %></b> (<%= h(rolActual) %>) | Fecha: <%= new java.text.SimpleDateFormat("dd/MM/yyyy HH:mm").format(new java.util.Date()) %>
        </div>

        <div class="hero-banner">
            <div>
                <h2>📈 Inteligencia Operativa y Analítica en Tiempo Real</h2>
                <p>Monitoreo consolidado de demanda por unidad, cobertura municipal, parqueos, seguridad en estaciones, pilotos e incidencias.</p>
            </div>
            <div class="hero-actions">
                <button class="btn-export btn-print" onclick="window.print()">🖨️ Imprimir / Guardar PDF</button>
                <a href="reportes.jsp?tipo=<%= h(tipoReporte) %>&exportar=csv" class="btn-export btn-excel">📗 Exportar Pestaña a Excel (CSV)</a>
            </div>
        </div>

        <!-- TARJETAS KPI EJECUTIVAS -->
        <div class="kpi-grid">
            <div class="kpi-card" style="--kpi-color:#0284c7;">
                <div class="kpi-top"><span>🗺️ Red de Rutas</span><span>RF02</span></div>
                <div class="kpi-val"><%= kpiTotalRutas %> rutas</div>
                <div class="kpi-sub">📏 <b><%= kpiKmRed %> km</b> totales mapeados</div>
            </div>

            <div class="kpi-card" style="--kpi-color:#10b981;">
                <div class="kpi-top"><span>🚍 Estado de Flota</span><span>RN04</span></div>
                <div class="kpi-val"><%= kpiFlotaEnRuta %> / <%= kpiFlotaTotal %></div>
                <div class="kpi-sub">🟢 <%= kpiFlotaEnRuta %> en ruta · 🅿️ <%= kpiFlotaGaraje %> garaje · 🛠️ <%= kpiFlotaMant %> taller</div>
            </div>

            <div class="kpi-card" style="--kpi-color:#8b5cf6;">
                <div class="kpi-top"><span>💺 Ocupación en Vivo</span><span>Pasajeros</span></div>
                <div class="kpi-val"><%= pct(kpiAsientosOcupados, kpiAsientosTotales) %>%</div>
                <div class="kpi-sub"><b><%= kpiAsientosOcupados %></b> de <b><%= kpiAsientosTotales %></b> asientos ocupados hoy</div>
            </div>

            <div class="kpi-card" style="--kpi-color:#f59e0b;">
                <div class="kpi-top"><span>🚪 Estaciones y Seguridad</span><span>RN05</span></div>
                <div class="kpi-val"><%= kpiEstaciones %> paradas</div>
                <div class="kpi-sub">🚪 <b><%= kpiMolinetes %></b> molinetes · 👮 <b><%= kpiGuardias %></b> guardias</div>
            </div>

            <div class="kpi-card" style="--kpi-color:<%= kpiAlertasActivas > 0 ? "#ef4444" : "#64748b" %>;">
                <div class="kpi-top"><span>🚨 Centro de Alertas</span><span>Monitoreo</span></div>
                <div class="kpi-val"><%= kpiAlertasActivas %> activas</div>
                <div class="kpi-sub">✅ <b><%= kpiAlertasResueltas %></b> incidencias resueltas</div>
            </div>
        </div>

        <!-- BARRA DE PESTAÑAS + BUSCADOR EN TABLA -->
        <div class="toolbar-row">
            <div class="tabs-container">
                <a href="reportes.jsp?tipo=ocupacion" class="tab-btn <%= "ocupacion".equals(tipoReporte) ? "tab-active" : "" %>">📊 Demanda y Rutas</a>
                <a href="reportes.jsp?tipo=municipalidad" class="tab-btn <%= "municipalidad".equals(tipoReporte) ? "tab-active" : "" %>">🏛️ Cobertura Municipal y Flota</a>
                <a href="reportes.jsp?tipo=infraestructura" class="tab-btn <%= "infraestructura".equals(tipoReporte) ? "tab-active" : "" %>">🏗️ Parqueos, Molinetes y Tramos</a>
                <a href="reportes.jsp?tipo=pilotos" class="tab-btn <%= "pilotos".equals(tipoReporte) ? "tab-active" : "" %>">🪪 Directorio de Pilotos</a>
                <a href="reportes.jsp?tipo=alertas" class="tab-btn <%= "alertas".equals(tipoReporte) ? "tab-active" : "" %>">
                    🚨 Historial de Alertas
                    <% if (kpiAlertasActivas > 0) { %>
                        <span style="background:#ef4444; color:#fff; border-radius:999px; padding:1px 7px; font-size:11px;"><%= kpiAlertasActivas %></span>
                    <% } %>
                </a>
            </div>

            <div class="search-box">
                <span class="search-icon">🔍</span>
                <input type="text" id="buscadorTabla" placeholder="Filtrar registros en esta vista..." oninput="filtrarTablasReporte(this.value)">
            </div>
        </div>

        <% if (errorBD != null) { %>
            <div class="report-card">
                <div class="vacio">❌ No se pudo conectar a la base de datos: <%= h(errorBD) %></div>
            </div>

        <% } else if ("ocupacion".equals(tipoReporte)) { %>
            <div class="report-card">
                <div class="report-card-header">
                    <h3 class="report-card-title">📊 Desglose de Demanda, Flota (Principal / Refuerzo / 2do Refuerzo), Piloto y Kilometraje por Ruta</h3>
                    <a href="operacion.jsp" style="font-size:12px; font-weight:700; color:#0284c7; text-decoration:none;">⚡ Ir al Centro de Operación en Vivo →</a>
                </div>
                <table class="tabla-filtrable">
                    <thead>
                        <tr>
                            <th>Ruta y Paradas</th>
                            <th>Desglose de Unidades (Principal / 1er Ref / 2do Ref)</th>
                            <th>Parqueo Base</th>
                            <th>Piloto Titular</th>
                            <th>Ocupación Consolidada</th>
                            <th>Distancia (RF02)</th>
                            <th>Estado Operativo</th>
                        </tr>
                    </thead>
                    <tbody>
                        <%
                            boolean hayDatos = false;
                            try (ResultSet rs = st.executeQuery(SQL_OCUPACION)) {
                                while (rs.next()) {
                                    hayDatos = true;
                                    String nomRuta = rs.getString("nombre_ruta");
                                    String listaEst = rs.getString("lista_estaciones");
                                    int numParadas = (listaEst != null && !listaEst.trim().isEmpty()) ? listaEst.split(",").length : 0;

                                    String placaMain = rs.getString("placa_main");
                                    String placaBackup = rs.getString("placa_backup");
                                    String placaExtra = rs.getString("placa_extra");
                                    int ocuMain = rs.getInt("ocu_main"), totMain = rs.getInt("tot_main");
                                    int ocuBackup = rs.getInt("ocu_backup"), totBackup = rs.getInt("tot_backup");
                                    int ocuExtra = rs.getInt("ocu_extra"), totExtra = rs.getInt("tot_extra");

                                    int ocupados = rs.getInt("ocupados"), total = rs.getInt("total");
                                    double porc = total > 0 ? ocupados * 100.0 / total : 0;

                                    String badgeClass = "badge-success", estadoTexto = "🟢 Despejado", barraClass = "";
                                    if (total == 0) {
                                        badgeClass = "badge-neutral";
                                        estadoTexto = "Sin asientos";
                                    } else if (porc >= 95) {
                                        badgeClass = "badge-danger";
                                        estadoTexto = "🚨 Saturado (" + String.format(java.util.Locale.US, "%.0f", porc) + "%)";
                                        barraClass = "alta";
                                    } else if (placaExtra != null) {
                                        badgeClass = "badge-purple";
                                        estadoTexto = "🟣 2do Refuerzo Activo";
                                        barraClass = porc >= 75 ? "media" : "";
                                    } else if (ocuBackup > 0 || (totMain > 0 && ocuMain == totMain)) {
                                        badgeClass = "badge-info";
                                        estadoTexto = "🔵 1er Refuerzo Activo";
                                        barraClass = "media";
                                    } else if (porc >= 50) {
                                        badgeClass = "badge-warning";
                                        estadoTexto = "⚠️ Demanda Media";
                                        barraClass = "media";
                                    }

                                    BigDecimal km = rs.getBigDecimal("km");
                                    int numTramos = rs.getInt("num_tramos");
                                    String pq = rs.getString("parqueo_main");
                                    String pil = rs.getString("piloto_nombre");
                                    String pilId = rs.getString("piloto_id");
                        %>
                        <tr>
                            <td>
                                <div style="font-weight: 800; color:#0f172a; font-size:14px;">🗺️ <%= h(nomRuta) %></div>
                                <div style="font-size:11.5px; color:#64748b; margin-top:3px;">🚏 <%= numParadas %> estaciones en recorrido</div>
                            </td>
                            <td>
                                <div class="bus-pill-list">
                                    <span class="bus-pill">🟢 <b>Principal:</b> <%= h(placaMain != null ? placaMain : "S/A") %> (<%= ocuMain %>/<%= totMain %>)</span>
                                    <span class="bus-pill">🔵 <b>1er Refuerzo:</b> <%= h(placaBackup != null ? placaBackup : "S/A") %> (<%= ocuBackup %>/<%= totBackup %>)</span>
                                    <% if (placaExtra != null) { %>
                                        <span class="bus-pill" style="background:#f3e8ff; border-color:#d8b4fe; color:#6b21a8;">
                                            🟣 <b>2do Refuerzo:</b> <%= h(placaExtra) %> (<%= ocuExtra %>/<%= totExtra %>)
                                        </span>
                                    <% } else { %>
                                        <span class="bus-pill" style="color:#94a3b8;">🅿️ 2do Refuerzo: En Parqueo (Reserva)</span>
                                    <% } %>
                                </div>
                            </td>
                            <td><span class="badge badge-info">🅿️ <%= h(pq) %></span></td>
                            <td>
                                <% if ("Sin piloto asignado".equals(pil)) { %>
                                    <span class="badge badge-neutral">Sin asignar</span>
                                <% } else { %>
                                    <div style="font-weight:700; color:#0f172a;">👨‍✈️ <%= h(pil) %></div>
                                    <% if (pilId != null && !pilId.isEmpty()) { %>
                                        <div style="font-size:11px; color:#64748b;">🎫 <%= h(pilId) %></div>
                                    <% } %>
                                <% } %>
                            </td>
                            <td>
                                <div class="barra-wrap">
                                    <span class="barra <%= barraClass %>"><div style="width: <%= String.format(java.util.Locale.US, "%.0f", Math.min(100, porc)) %>%;"></div></span>
                                    <div>
                                        <b><%= ocupados %></b> / <%= total %>
                                        <div style="font-size:11px; color:#64748b;"><%= pct(ocupados, total) %>% ocupado</div>
                                    </div>
                                </div>
                            </td>
                            <td>
                                <% if (km == null || km.signum() == 0) { %>
                                    <span style="color:#94a3b8; font-size:12px;">Sin mapear</span>
                                <% } else { %>
                                    <div style="font-weight:800; color:#0369a1;">📏 <%= km %> km</div>
                                    <div style="font-size:11px; color:#64748b;"><%= numTramos %> tramo(s)</div>
                                <% } %>
                            </td>
                            <td><span class="badge <%= badgeClass %>"><%= estadoTexto %></span></td>
                        </tr>
                        <%
                                }
                            } catch (Exception e) {
                                out.print("<tr><td colspan='7' class='vacio'>Error: " + h(e.getMessage()) + "</td></tr>");
                            }
                            if (!hayDatos) out.print("<tr><td colspan='7' class='vacio'>No hay rutas operativas configuradas.</td></tr>");
                        %>
                    </tbody>
                </table>
                <p class="report-note">
                    💡 <b>Nota operativa:</b> Cuando el Bus Principal y el 1er Refuerzo alcanzan el 100%, se habilita el despacho del <b>2do Refuerzo (Bus Extra)</b> desde el módulo de Alertas. Al finalizar su viaje en Operación, el 2do Refuerzo retorna automáticamente a su parqueo base.
                </p>
            </div>

        <% } else if ("municipalidad".equals(tipoReporte)) { %>
            <div class="report-card">
                <div class="report-card-header">
                    <h3 class="report-card-title">🏛️ Cobertura de Flota por Jurisdicción Municipal</h3>
                    <% if ("admin".equals(rolActual)) { %>
                        <a href="flota.jsp" style="font-size:12px; font-weight:700; color:#0284c7; text-decoration:none;">🚍 Administrar Flota →</a>
                    <% } %>
                </div>
                <table class="tabla-filtrable">
                    <thead>
                        <tr>
                            <th>Municipalidad / Jurisdicción</th>
                            <th>Unidades Totales</th>
                            <th>En Ruta Activa</th>
                            <th>En Taller</th>
                            <th>Capacidad Total</th>
                            <th>Placas Registradas</th>
                            <th>Diagnóstico de Cobertura</th>
                        </tr>
                    </thead>
                    <tbody>
                        <%
                            boolean hayM = false;
                            try (ResultSet rs = st.executeQuery(SQL_MUNICIPAL)) {
                                while (rs.next()) {
                                    hayM = true;
                                    int unidades = rs.getInt("unidades");
                                    int enRuta = rs.getInt("en_ruta");
                                    int enMant = rs.getInt("en_mantenimiento");
                                    int capTotal = rs.getInt("capacidad_total");
                                    String placas = rs.getString("placas");
                                    String diag = recomendacionMunicipal(unidades, enRuta, enMant);
                                    String bClass = (unidades >= 2 && enRuta > 0) ? "badge-success" : (unidades == 0 ? "badge-danger" : "badge-warning");
                        %>
                        <tr>
                            <td style="font-weight: 800; color:#0f172a;">🏛️ <%= h(rs.getString("nombre")) %></td>
                            <td style="font-size:16px; font-weight:800; color:#1e3a8a;">🚍 <%= unidades %></td>
                            <td><span class="badge badge-info"><%= enRuta %> en ruta</span></td>
                            <td><%= enMant > 0 ? "<span class='badge badge-danger'>🛠️ " + enMant + "</span>" : "<span style='color:#94a3b8;'>0</span>" %></td>
                            <td><b><%= capTotal %></b> asientos</td>
                            <td style="font-size:12px; color:#475569; max-width:260px;"><%= placas != null ? h(placas) : "<span style='color:#94a3b8;'>Sin unidades asignadas</span>" %></td>
                            <td><span class="badge <%= bClass %>"><%= h(diag) %></span></td>
                        </tr>
                        <%
                                }
                            } catch (Exception e) {
                                out.print("<tr><td colspan='7' class='vacio'>Error: " + h(e.getMessage()) + "</td></tr>");
                            }
                            if (!hayM) out.print("<tr><td colspan='7' class='vacio'>No hay municipalidades registradas.</td></tr>");
                        %>
                    </tbody>
                </table>
            </div>

        <% } else if ("infraestructura".equals(tipoReporte)) { %>
            <!-- SUB-SECCIÓN 1: PARQUEOS -->
            <div class="report-card">
                <div class="report-card-header">
                    <h3 class="report-card-title">🅿️ Ocupación de Parqueos Oficiales y Unidades Resguardadas (RN04)</h3>
                    <% if ("admin".equals(rolActual)) { %>
                        <a href="admin_infra.jsp" style="font-size:12px; font-weight:700; color:#0284c7; text-decoration:none;">🏗️ Configurar Infraestructura →</a>
                    <% } %>
                </div>
                <table class="tabla-filtrable">
                    <thead>
                        <tr>
                            <th>ID</th>
                            <th>Parqueo Oficial</th>
                            <th>Capacidad</th>
                            <th>Nivel de Ocupación</th>
                            <th>Espacios Libres</th>
                            <th>Unidades Asignadas al Parqueo</th>
                        </tr>
                    </thead>
                    <tbody>
                        <%
                            boolean hayP = false;
                            try (ResultSet rs = st.executeQuery(SQL_INFRA_PARQUEOS)) {
                                while (rs.next()) {
                                    hayP = true;
                                    int cap = rs.getInt("capacidad_buses"), ocu = rs.getInt("ocupados");
                                    double porcP = cap > 0 ? Math.min(100, ocu * 100.0 / cap) : 100;
                                    String barraP = porcP >= 100 ? "alta" : (porcP >= 75 ? "media" : "");
                                    String buses = rs.getString("detalle_buses");
                        %>
                        <tr>
                            <td style="font-weight:700; color:#94a3b8;">#<%= rs.getInt("id_parqueo") %></td>
                            <td style="font-weight: 800; color:#0f172a;">🅿️ <%= h(rs.getString("nombre")) %></td>
                            <td><b><%= cap %></b> buses</td>
                            <td>
                                <div class="barra-wrap">
                                    <span class="barra <%= barraP %>"><div style="width: <%= String.format(java.util.Locale.US, "%.0f", porcP) %>%;"></div></span>
                                    <b><%= ocu %> / <%= cap %></b>
                                </div>
                            </td>
                            <td><span class="badge <%= (cap - ocu) > 0 ? "badge-success" : "badge-danger" %>"><%= Math.max(0, cap - ocu) %> disponibles</span></td>
                            <td style="font-size:12px; color:#475569;"><%= buses != null ? h(buses) : "<span style='color:#94a3b8;'>Ninguna unidad asignada</span>" %></td>
                        </tr>
                        <%
                                }
                            } catch (Exception e) {
                                out.print("<tr><td colspan='6' class='vacio'>Error: " + h(e.getMessage()) + "</td></tr>");
                            }
                            if (!hayP) out.print("<tr><td colspan='6' class='vacio'>No hay parqueos registrados.</td></tr>");
                        %>
                    </tbody>
                </table>
            </div>

            <!-- SUB-SECCIÓN 2: ESTACIONES, MOLINETES Y GUARDIAS -->
            <div class="report-card">
                <div class="report-card-header">
                    <h3 class="report-card-title">🚪 Auditoría de Seguridad en Estaciones: Molinetes y Guardias (RN05)</h3>
                    <a href="estaciones.jsp" style="font-size:12px; font-weight:700; color:#0284c7; text-decoration:none;">🚏 Ver Directorio de Estaciones →</a>
                </div>
                <table class="tabla-filtrable">
                    <thead>
                        <tr>
                            <th>Estación Física</th>
                            <th>Coordenadas GPS</th>
                            <th>Código de Molinete / Puerta</th>
                            <th>Guardia de Seguridad</th>
                            <th>Turno</th>
                            <th>Cumplimiento RN05</th>
                        </tr>
                    </thead>
                    <tbody>
                        <%
                            boolean hayEst = false;
                            try (ResultSet rsE = st.executeQuery(SQL_INFRA_ESTACIONES)) {
                                while (rsE.next()) {
                                    hayEst = true;
                                    String nomE = rsE.getString("nombre");
                                    String lat = rsE.getString("latitud");
                                    String lon = rsE.getString("longitud");
                                    String puerta = rsE.getString("codigo_puerta");
                                    String guardia = rsE.getString("guardia");
                                    String turno = rsE.getString("turno");
                                    boolean cumple = (puerta != null && !puerta.isEmpty() && guardia != null && !guardia.isEmpty());
                        %>
                        <tr>
                            <td style="font-weight:700; color:#0f172a;">🚏 <%= h(nomE) %></td>
                            <td style="font-size:12px; color:#64748b;">📍 <%= h(lat != null ? lat : "—") %>, <%= h(lon != null ? lon : "—") %></td>
                            <td><%= puerta != null ? "<span class='badge badge-info'>🚪 " + h(puerta) + "</span>" : "<span style='color:#94a3b8;'>Sin molinete</span>" %></td>
                            <td><%= guardia != null ? "👮 <b>" + h(guardia) + "</b>" : "<span style='color:#94a3b8;'>Sin guardia asignado</span>" %></td>
                            <td><%= turno != null ? h(turno) : "—" %></td>
                            <td>
                                <% if (cumple) { %>
                                    <span class="badge badge-success">✅ Cumple RN05</span>
                                <% } else { %>
                                    <span class="badge badge-warning">⚠️ Pendiente configurar</span>
                                <% } %>
                            </td>
                        </tr>
                        <%
                                }
                            } catch (Exception e) {
                                out.print("<tr><td colspan='6' class='vacio'>Error: " + h(e.getMessage()) + "</td></tr>");
                            }
                            if (!hayEst) out.print("<tr><td colspan='6' class='vacio'>No hay estaciones físicas registradas.</td></tr>");
                        %>
                    </tbody>
                </table>
            </div>

        <% } else if ("pilotos".equals(tipoReporte)) { %>
            <div class="report-card">
                <div class="report-card-header">
                    <h3 class="report-card-title">🪪 Directorio Oficial de Pilotos, Cuenta de Sistema y Ruta Operativa</h3>
                    <% if ("admin".equals(rolActual)) { %>
                        <a href="Pilotos-Edicion.jsp" style="font-size:12px; font-weight:700; color:#0284c7; text-decoration:none;">✏️ Gestionar Pilotos →</a>
                    <% } %>
                </div>
                <table class="tabla-filtrable">
                    <thead>
                        <tr>
                            <th>Nombre del Piloto</th>
                            <th>Edad</th>
                            <th>Identificador Transmetro</th>
                            <th>Cuenta de Usuario</th>
                            <th>Ruta, Unidad y Parqueo Asignado</th>
                            <th>Estado</th>
                        </tr>
                    </thead>
                    <tbody>
                        <%
                            boolean hayPil = false;
                            try (ResultSet rs = st.executeQuery(SQL_PILOTOS)) {
                                while (rs.next()) {
                                    hayPil = true;
                                    String usuario = rs.getString("usuario");
                                    String rutaAsig = rs.getString("ruta_asignada");
                                    boolean activoEnRuta = !"Sin ruta asignada".equals(rutaAsig);
                        %>
                        <tr>
                            <td style="font-weight: 800; color: #1e3a8a;">👨‍✈️ <%= h(rs.getString("nombre")) %></td>
                            <td><%= rs.getInt("edad") > 0 ? rs.getInt("edad") + " años" : "—" %></td>
                            <td><span class="badge badge-info">🎫 <%= h(rs.getString("identificador_transmetro")) %></span></td>
                            <td><%= "Sin asignar".equals(usuario) ? "<span class='badge badge-neutral'>Sin cuenta</span>" : "👤 <b>" + h(usuario) + "</b>" %></td>
                            <td>
                                <% if (activoEnRuta) { %>
                                    <span class="badge badge-success">🗺️ <%= h(rutaAsig) %></span>
                                <% } else { %>
                                    <span style="color:#94a3b8; font-size:12.5px;">Sin ruta activa asignada</span>
                                <% } %>
                            </td>
                            <td>
                                <span class="badge <%= activoEnRuta ? "badge-success" : "badge-neutral" %>">
                                    <%= activoEnRuta ? "🟢 En Servicio" : "⏸️ En Reserva" %>
                                </span>
                            </td>
                        </tr>
                        <%
                                }
                            } catch (Exception e) {
                                out.print("<tr><td colspan='6' class='vacio'>Error: " + h(e.getMessage()) + "</td></tr>");
                            }
                            if (!hayPil) out.print("<tr><td colspan='6' class='vacio'>No hay pilotos registrados.</td></tr>");
                        %>
                    </tbody>
                </table>
            </div>

        <% } else if ("alertas".equals(tipoReporte)) { %>
            <div class="report-card">
                <div class="report-card-header">
                    <h3 class="report-card-title">🚨 Bitácora e Historial de Alertas e Incidencias Operativas</h3>
                    <a href="alertas.jsp" style="font-size:12px; font-weight:700; color:#0284c7; text-decoration:none;">🚨 Ir al Centro de Control de Alertas →</a>
                </div>
                <table class="tabla-filtrable">
                    <thead>
                        <tr>
                            <th>ID</th>
                            <th>Fecha y Hora</th>
                            <th>Gravedad</th>
                            <th>Unidad / Ruta Afectada</th>
                            <th>Descripción del Incidente</th>
                            <th>Reportado Por</th>
                            <th>Audiencia</th>
                            <th>Estado</th>
                        </tr>
                    </thead>
                    <tbody>
                        <%
                            boolean hayAl = false;
                            try (ResultSet rsA = st.executeQuery(SQL_ALERTAS)) {
                                while (rsA.next()) {
                                    hayAl = true;
                                    String tipoG = rsA.getString("tipo_gravedad");
                                    String estadoA = rsA.getString("estado");
                                    String aud = rsA.getString("audiencia");
                                    String gBadge = "badge-info";
                                    if ("Emergencia".equalsIgnoreCase(tipoG)) gBadge = "badge-danger";
                                    else if ("Trafico".equalsIgnoreCase(tipoG)) gBadge = "badge-warning";
                                    else if ("Logistica".equalsIgnoreCase(tipoG)) gBadge = "badge-purple";
                        %>
                        <tr>
                            <td style="font-weight:700; color:#94a3b8;">#<%= rsA.getInt("id") %></td>
                            <td style="font-size:12px; white-space:nowrap;">🕒 <%= h(rsA.getString("fecha_fmt")) %></td>
                            <td><span class="badge <%= gBadge %>"><%= h(tipoG) %></span></td>
                            <td style="font-weight:700; color:#0f172a;"><%= h(rsA.getString("bus_ruta")) %></td>
                            <td style="font-size:12.5px; color:#334155; max-width:340px;"><%= h(rsA.getString("descripcion")) %></td>
                            <td style="font-size:12px;">👤 <%= h(rsA.getString("reportado_por")) %></td>
                            <td>
                                <span class="badge <%= "publica".equalsIgnoreCase(aud) ? "badge-info" : "badge-neutral" %>">
                                    <%= "publica".equalsIgnoreCase(aud) ? "📢 Pública" : "🔒 Interna" %>
                                </span>
                            </td>
                            <td>
                                <span class="badge <%= "Activa".equalsIgnoreCase(estadoA) ? "badge-danger" : "badge-success" %>">
                                    <%= "Activa".equalsIgnoreCase(estadoA) ? "🔴 Activa" : "✅ Resuelta" %>
                                </span>
                            </td>
                        </tr>
                        <%
                                }
                            } catch (Exception e) {
                                out.print("<tr><td colspan='8' class='vacio'>Error: " + h(e.getMessage()) + "</td></tr>");
                            }
                            if (!hayAl) out.print("<tr><td colspan='8' class='vacio'>No hay alertas registradas en el historial.</td></tr>");
                        %>
                    </tbody>
                </table>
            </div>
        <% } %>

        <%
            try { if (st != null) st.close(); } catch (Exception ignorar) {}
            try { if (con != null) con.close(); } catch (Exception ignorar) {}
        %>
    </div>

    <script>
        function filtrarTablasReporte(texto) {
            const filtro = (texto || "").toLowerCase().trim();
            document.querySelectorAll(".tabla-filtrable tbody tr").forEach(fila => {
                const contenido = fila.textContent.toLowerCase();
                fila.style.display = contenido.includes(filtro) ? "" : "none";
            });
        }

        function toggleMenu(side) {
            let leftMenu = document.getElementById("leftSidebar");
            let rightMenu = document.getElementById("rightSidebar");
            let overlay = document.getElementById("overlay");
            if (side === 'left') { leftMenu.style.width = "250px"; if(rightMenu) rightMenu.style.width = "0"; }
            else if (side === 'right') { if(rightMenu) rightMenu.style.width = "300px"; leftMenu.style.width = "0"; }
            overlay.style.display = "block";
        }

        function closeAllMenus() {
            document.getElementById("leftSidebar").style.width = "0";
            let rightMenu = document.getElementById("rightSidebar"); if(rightMenu) rightMenu.style.width = "0";
            document.getElementById("overlay").style.display = "none";
        }
    </script>
</body>
</html>
