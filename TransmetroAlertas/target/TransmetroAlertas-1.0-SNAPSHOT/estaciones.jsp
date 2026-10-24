<%@page contentType="text/html" pageEncoding="UTF-8"%>
<%@page import="java.sql.*"%>
<%@page import="java.util.*"%>
<%!
    static String h(String s) {
        if (s == null) return "";
        return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace("\"", "&quot;").replace("'", "&#39;");
    }
    static String t(String s) { return s == null ? "" : s.trim(); }
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
    <title>Estaciones y Municipalidades - Transmetro</title>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&display=swap" rel="stylesheet">
    <style>
        body { font-family: 'Inter', sans-serif; background-color: #f8fafc; margin: 0; padding-top: 70px; color: #0f172a; }
        .header { background: #ffffff; padding: 15px 25px; position: fixed; top: 0; width: 100%; box-sizing: border-box; z-index: 1000; display: flex; justify-content: space-between; align-items: center; border-bottom: 1px solid #e2e8f0; }
        .header h1 { margin: 0; font-size: 18px; text-align: center; flex-grow: 1; font-weight: 700; color: #1e293b; }
        .menu-btn { background: none; border: none; font-size: 24px; cursor: pointer; color: #475569; }
        .overlay { display: none; position: fixed; width: 100%; height: 100%; top: 0; left: 0; background: rgba(15, 23, 42, 0.4); z-index: 999; }

        .main-container { max-width: 1100px; margin: 25px auto; padding: 0 20px 50px 20px; }
        .page-header { display: flex; justify-content: space-between; align-items: flex-end; flex-wrap: wrap; gap: 14px; margin-bottom: 24px; }
        .page-header h2 { margin: 0; font-size: 26px; color: #0f172a; font-weight: 800; }
        .page-header p { margin: 5px 0 0 0; color: #64748b; font-size: 14px; }

        .resumen-bar { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 14px; margin-bottom: 28px; }
        .resumen-card { background: #ffffff; border: 1px solid #e2e8f0; border-radius: 12px; padding: 14px 18px; box-shadow: 0 2px 6px rgba(0,0,0,0.02); text-decoration: none; color: inherit; display: block; transition: 0.18s; }
        .resumen-card:hover { border-color: #0d9488; transform: translateY(-1px); }
        .resumen-card .num { font-size: 24px; font-weight: 800; color: #0d9488; }
        .resumen-card .lbl { font-size: 12px; font-weight: 600; color: #64748b; margin-top: 2px; }

        .section-heading {
            display: flex;
            justify-content: space-between;
            align-items: center;
            flex-wrap: wrap;
            gap: 10px;
            margin: 30px 0 14px 0;
            padding-bottom: 10px;
            border-bottom: 1px solid #e2e8f0;
        }
        .section-heading h3 { margin: 0; font-size: 19px; font-weight: 800; color: #0f172a; display: flex; align-items: center; gap: 8px; }
        .section-heading span.sub { font-size: 12.5px; color: #64748b; font-weight: 500; }

        /* Grid de Municipalidades */
        .munis-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(310px, 1fr)); gap: 16px; margin-bottom: 32px; }
        .muni-card {
            background: #ffffff;
            border-radius: 12px;
            padding: 18px;
            border: 1px solid #e2e8f0;
            border-top: 4px solid #0d9488;
            display: flex;
            flex-direction: column;
            gap: 10px;
            transition: 0.2s;
            box-shadow: 0 2px 6px rgba(0,0,0,0.02);
        }
        .muni-card:hover { border-color: #0d9488; box-shadow: 0 6px 16px rgba(13, 148, 136, 0.12); transform: translateY(-2px); }
        .muni-top { display: flex; align-items: center; justify-content: space-between; gap: 10px; }
        .muni-title-wrap { display: flex; align-items: center; gap: 12px; }
        .muni-icon { font-size: 21px; background: #f0fdfa; color: #0d9488; width: 42px; height: 42px; display: flex; justify-content: center; align-items: center; border-radius: 10px; flex-shrink: 0; border: 1px solid #ccfbf1; }
        .muni-name { font-size: 16px; font-weight: 800; color: #0f172a; }
        .muni-sub { font-size: 11.5px; color: #64748b; margin-top: 2px; }
        .muni-stats { display: flex; gap: 8px; flex-wrap: wrap; }
        .muni-pill { font-size: 11px; font-weight: 700; padding: 3px 9px; border-radius: 999px; background: #f1f5f9; color: #334155; border: 1px solid #e2e8f0; }
        .muni-pill.activa { background: #f0fdfa; color: #0f766e; border-color: #99f6e4; }
        .muni-pill.nueva { background: #fef3c7; color: #92400e; border-color: #fde68a; }
        .muni-buses { font-size: 12px; color: #334155; background: #f8fafc; border: 1px solid #e2e8f0; padding: 8px 10px; border-radius: 8px; line-height: 1.5; }
        .muni-actions { display: flex; gap: 8px; margin-top: auto; padding-top: 4px; }
        .muni-link { font-size: 11.5px; font-weight: 700; color: #0d9488; text-decoration: none; background: #f0fdfa; border: 1px solid #99f6e4; padding: 5px 10px; border-radius: 7px; transition: 0.15s; }
        .muni-link:hover { background: #0d9488; color: #ffffff; }

        /* Grid de Estaciones */
        .estaciones-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(310px, 1fr)); gap: 16px; }

        .estacion-card {
            background: white;
            border-radius: 12px;
            padding: 18px;
            border: 1px solid #e2e8f0;
            border-top: 4px solid #3b82f6;
            display: flex;
            flex-direction: column;
            gap: 10px;
            transition: 0.2s;
            box-shadow: 0 2px 6px rgba(0,0,0,0.02);
        }
        .estacion-card:hover { border-color: #2563eb; box-shadow: 0 6px 16px rgba(59, 130, 246, 0.12); transform: translateY(-2px); }
        .est-top { display: flex; align-items: center; gap: 12px; }
        .icono { font-size: 22px; background: #eff6ff; width: 42px; height: 42px; display: flex; justify-content: center; align-items: center; border-radius: 10px; flex-shrink: 0; }
        .nombre { font-size: 16px; font-weight: 800; color: #0f172a; }
        .coords { font-size: 11px; color: #64748b; margin-top: 2px; }

        .rutas-badges { display: flex; flex-wrap: wrap; gap: 5px; }
        .badge-ruta { background: #e0f2fe; color: #0369a1; font-size: 11px; font-weight: 700; padding: 3px 8px; border-radius: 6px; border: 1px solid #bae6fd; text-decoration: none; }
        .badge-catalogo { background: #fef3c7; color: #92400e; font-size: 11px; font-weight: 700; padding: 3px 8px; border-radius: 6px; border: 1px solid #fde68a; }

        .info-seg { font-size: 12px; color: #065f46; background: #ecfdf5; border: 1px solid #a7f3d0; padding: 6px 10px; border-radius: 6px; font-weight: 600; }
        .info-seg.sin-datos { color: #94a3b8; background: #f8fafc; border: 1px dashed #cbd5e1; font-style: italic; font-weight: 500; }

        .info-km { font-size: 11px; color: #334155; background: #f1f5f9; padding: 6px 10px; border-radius: 6px; line-height: 1.5; }

        .btn-admin-link { background: #1e293b; color: white; text-decoration: none; padding: 9px 15px; border-radius: 8px; font-size: 13px; font-weight: 700; display: inline-block; }
        .btn-admin-link:hover { background: #334155; }

        .empty-state { grid-column: 1 / -1; text-align: center; padding: 50px; background: white; border-radius: 12px; color: #94a3b8; font-weight: 600; border: 1px dashed #cbd5e1; }
    </style>
    <link rel="stylesheet" href="css/transmetro.css">
</head>
<body>
    <jsp:include page="menu_izquierdo.jsp" />
    <jsp:include page="menu_derecho.jsp" />
    <div id="overlay" class="overlay" onclick="closeAllMenus()"></div>

    <div class="header">
        <button class="menu-btn" onclick="toggleMenu('left')">☰</button>
        <h1>Directorio de Estaciones y Municipalidades</h1>
        <% if ("admin".equals(rolActual)) { %><button class="menu-btn" onclick="toggleMenu('right')">⚙️</button><% } else { %><div style="width: 24px;"></div><% } %>
    </div>

    <%
        // Estructuras unificadas para Estaciones
        Map<String, String> todasLasEstaciones = new TreeMap<>();
        Map<String, String> coordenadasPorEst = new HashMap<>();
        Map<String, Set<String>> rutasPorEst = new HashMap<>();
        Map<String, List<String>> seguridadPorEst = new HashMap<>();
        Map<String, List<String>> tramosPorEst = new HashMap<>();

        // Estructuras unificadas para Municipalidades (tabla municipalidades + flota_vehiculos)
        Map<String, String> todasLasMunis = new TreeMap<>();
        Map<String, List<String>> busesPorMuni = new HashMap<>();
        Map<String, Integer> capacidadPorMuni = new HashMap<>();
        Map<String, Set<String>> rutasPorMuni = new HashMap<>();

        String errorMsg = null;

        try {
            Class.forName("com.mysql.cj.jdbc.Driver");
            try (Connection con = DriverManager.getConnection(dbUrl, dbUser, dbPass);
                 Statement st = con.createStatement()) {

                // 0. Municipalidades registradas en el catálogo oficial (municipalidades)
                try (ResultSet rsM = st.executeQuery("SELECT nombre FROM municipalidades ORDER BY nombre ASC")) {
                    while (rsM.next()) {
                        String nomM = t(rsM.getString("nombre"));
                        if (!nomM.isEmpty()) {
                            todasLasMunis.putIfAbsent(nomM.toLowerCase(), nomM);
                        }
                    }
                } catch (Exception ignorar) {}

                // 0.1 Buses registrados por municipalidad y su parqueo base
                try (ResultSet rsFlotaM = st.executeQuery(
                        "SELECT f.placa, f.municipalidad, f.capacidad, f.estado, p.nombre AS parqueo " +
                        "FROM flota_vehiculos f LEFT JOIN parqueos p ON f.id_parqueo = p.id_parqueo " +
                        "ORDER BY f.placa ASC")) {
                    while (rsFlotaM.next()) {
                        String nomM = t(rsFlotaM.getString("municipalidad"));
                        if (!nomM.isEmpty()) {
                            String keyM = nomM.toLowerCase();
                            todasLasMunis.putIfAbsent(keyM, nomM);
                            String placa = t(rsFlotaM.getString("placa"));
                            int cap = rsFlotaM.getInt("capacidad");
                            String parq = rsFlotaM.getString("parqueo");
                            String detBus = "🚍 <b>" + h(placa) + "</b> (" + cap + " asientos" + (parq != null ? " · 🅿️ " + h(parq) : "") + ")";
                            busesPorMuni.computeIfAbsent(keyM, k -> new ArrayList<>()).add(detBus);
                            capacidadPorMuni.put(keyM, capacidadPorMuni.getOrDefault(keyM, 0) + cap);
                        }
                    }
                } catch (Exception ignorar) {}

                // 0.2 Rutas operativas donde participan buses de cada municipalidad (Principal, Refuerzo o Extra)
                try (ResultSet rsRutM = st.executeQuery(
                        "SELECT r.nombre_ruta, vm.municipalidad AS m1, vb.municipalidad AS m2, vx.municipalidad AS m3 " +
                        "FROM rutas_operativas r " +
                        "LEFT JOIN flota_vehiculos vm ON r.id_vehiculo_main = vm.id_vehiculo " +
                        "LEFT JOIN flota_vehiculos vb ON r.id_vehiculo_backup = vb.id_vehiculo " +
                        "LEFT JOIN flota_vehiculos vx ON r.id_vehiculo_extra = vx.id_vehiculo " +
                        "ORDER BY r.nombre_ruta ASC")) {
                    while (rsRutM.next()) {
                        String nomR = t(rsRutM.getString("nombre_ruta"));
                        String[] ms = { rsRutM.getString("m1"), rsRutM.getString("m2"), rsRutM.getString("m3") };
                        for (String mItem : ms) {
                            String mClean = t(mItem);
                            if (!mClean.isEmpty() && !nomR.isEmpty()) {
                                String keyM = mClean.toLowerCase();
                                todasLasMunis.putIfAbsent(keyM, mClean);
                                rutasPorMuni.computeIfAbsent(keyM, k -> new LinkedHashSet<>()).add(nomR);
                            }
                        }
                    }
                } catch (Exception ignorar) {}

                // 1. Estaciones del catálogo general (estaciones_catalogo)
                try (ResultSet rsCat = st.executeQuery("SELECT nombre FROM estaciones_catalogo ORDER BY nombre ASC")) {
                    while (rsCat.next()) {
                        String nom = t(rsCat.getString("nombre"));
                        if (!nom.isEmpty()) {
                            todasLasEstaciones.putIfAbsent(nom.toLowerCase(), nom);
                        }
                    }
                } catch (Exception ignorar) {}

                // 2. Estaciones físicas de infraestructura (estaciones_fisicas)
                try (ResultSet rsFis = st.executeQuery("SELECT nombre, latitud, longitud FROM estaciones_fisicas ORDER BY nombre ASC")) {
                    while (rsFis.next()) {
                        String nom = t(rsFis.getString("nombre"));
                        if (!nom.isEmpty()) {
                            String key = nom.toLowerCase();
                            todasLasEstaciones.putIfAbsent(key, nom);
                            String lat = t(rsFis.getString("latitud"));
                            String lon = t(rsFis.getString("longitud"));
                            if (!lat.isEmpty() || !lon.isEmpty()) {
                                coordenadasPorEst.put(key, "📍 Lat: " + lat + " · Lon: " + lon);
                            }
                        }
                    }
                } catch (Exception ignorar) {}

                // 3. Estaciones utilizadas en rutas operativas (rutas_operativas)
                try (ResultSet rsRut = st.executeQuery("SELECT nombre_ruta, lista_estaciones FROM rutas_operativas ORDER BY nombre_ruta ASC")) {
                    while (rsRut.next()) {
                        String nomRuta = t(rsRut.getString("nombre_ruta"));
                        String lista = rsRut.getString("lista_estaciones");
                        if (lista != null && !lista.trim().isEmpty()) {
                            for (String s : lista.split(",")) {
                                String nomEst = s.trim();
                                if (!nomEst.isEmpty()) {
                                    String key = nomEst.toLowerCase();
                                    todasLasEstaciones.putIfAbsent(key, nomEst);
                                    rutasPorEst.computeIfAbsent(key, k -> new LinkedHashSet<>()).add(nomRuta);
                                }
                            }
                        }
                    }
                } catch (Exception ignorar) {}

                // 4. Molinetes y Guardias de Seguridad por estación (accesos_molinetes + guardias_seguridad)
                try (ResultSet rsSeg = st.executeQuery(
                        "SELECT e.nombre, a.codigo_puerta, g.nombre_completo, g.turno " +
                        "FROM estaciones_fisicas e " +
                        "JOIN accesos_molinetes a ON a.id_estacion = e.id_estacion " +
                        "LEFT JOIN guardias_seguridad g ON g.id_acceso = a.id_acceso " +
                        "ORDER BY a.codigo_puerta ASC")) {
                    while (rsSeg.next()) {
                        String key = t(rsSeg.getString("nombre")).toLowerCase();
                        String puerta = t(rsSeg.getString("codigo_puerta"));
                        String guardia = rsSeg.getString("nombre_completo");
                        String turno = rsSeg.getString("turno");
                        String detalle = "🚪 Molinete <b>" + h(puerta) + "</b>" +
                            (guardia != null ? " · 👮 " + h(guardia) + " (" + h(turno != null ? turno : "Diurno") + ")" : " · Sin guardia asignado");
                        seguridadPorEst.computeIfAbsent(key, k -> new ArrayList<>()).add(detalle);
                    }
                } catch (Exception ignorar) {}

                // 5. Distancias de tramos conectados a cada estación
                try (ResultSet rsKm = st.executeQuery(
                        "SELECT estacion_origen, estacion_destino, distancia_km FROM distancias_tramos ORDER BY id_tramo ASC")) {
                    while (rsKm.next()) {
                        String orig = t(rsKm.getString("estacion_origen"));
                        String dest = t(rsKm.getString("estacion_destino"));
                        String km = rsKm.getBigDecimal("distancia_km").toPlainString();
                        if (!orig.isEmpty() && !dest.isEmpty()) {
                            String item = "📏 Hacia <b>" + h(dest) + "</b>: " + h(km) + " km";
                            List<String> l = tramosPorEst.computeIfAbsent(orig.toLowerCase(), k -> new ArrayList<>());
                            if (!l.contains(item)) l.add(item);
                        }
                    }
                } catch (Exception ignorar) {}
            }
        } catch (Exception e) {
            errorMsg = e.getMessage();
        }
    %>

    <div class="main-container">
        <div class="page-header">
            <div>
                <h2>🚏 Directorio de Estaciones y Municipalidades</h2>
                <p>Consulta pública para pasajeros, pilotos y administradores de todas las municipalidades conectadas, estaciones del catálogo, accesos y tramos.</p>
            </div>
            <% if ("admin".equals(rolActual)) { %>
                <div style="display:flex; gap:8px; flex-wrap:wrap;">
                    <a href="admin_catalogos.jsp" class="btn-admin-link">⚙️ Gestionar Estaciones y Municipalidades</a>
                    <a href="admin_infra.jsp" class="btn-admin-link" style="background:#0369a1;">🏗️ Molinetes y Parqueos</a>
                </div>
            <% } %>
        </div>

        <div class="resumen-bar">
            <a href="#municipalidades" class="resumen-card">
                <div class="num"><%= todasLasMunis.size() %></div>
                <div class="lbl">🏛️ Municipalidades Registradas</div>
            </a>
            <a href="#estaciones" class="resumen-card">
                <div class="num"><%= todasLasEstaciones.size() %></div>
                <div class="lbl">🚏 Total de Estaciones</div>
            </a>
            <a href="#estaciones" class="resumen-card">
                <div class="num"><%= rutasPorEst.size() %></div>
                <div class="lbl">🗺️ Estaciones en Rutas Activas</div>
            </a>
            <a href="infraestructura.jsp" class="resumen-card">
                <div class="num"><%= seguridadPorEst.size() %></div>
                <div class="lbl">🚪 Estaciones con Molinete y Guardia</div>
            </a>
        </div>

        <!-- SECCIÓN 1: MUNICIPALIDADES REGISTRADAS (VISIBLE PARA PASAJEROS, PILOTOS Y ADMINS) -->
        <div class="section-heading" id="municipalidades">
            <h3><span>🏛️</span><span>Municipalidades y Cobertura Jurisdiccional</span></h3>
            <span class="sub">Todas las municipalidades agregadas en el catálogo del sistema y sus unidades vinculadas</span>
        </div>

        <div class="munis-grid">
            <%
                if (todasLasMunis.isEmpty()) {
                    out.print("<div class='empty-state'>No hay municipalidades registradas en el catálogo del sistema.</div>");
                } else {
                    for (Map.Entry<String, String> mEntry : todasLasMunis.entrySet()) {
                        String keyM = mEntry.getKey();
                        String nomMuni = mEntry.getValue();
                        List<String> busesM = busesPorMuni.get(keyM);
                        int nBuses = (busesM != null) ? busesM.size() : 0;
                        int capTotalM = capacidadPorMuni.getOrDefault(keyM, 0);
                        Set<String> rutasM = rutasPorMuni.get(keyM);
                        String urlMuniParam = java.net.URLEncoder.encode(nomMuni, "UTF-8");
            %>
                        <div class="muni-card">
                            <div class="muni-top">
                                <div class="muni-title-wrap">
                                    <div class="muni-icon">🏛️</div>
                                    <div>
                                        <div class="muni-name"><%= h(nomMuni) %></div>
                                        <div class="muni-sub">Jurisdicción Municipal Autorizada</div>
                                    </div>
                                </div>
                            </div>

                            <div class="muni-stats">
                                <% if (nBuses > 0) { %>
                                    <span class="muni-pill activa">🚍 <%= nBuses %> <%= nBuses == 1 ? "unidad" : "unidades" %></span>
                                    <span class="muni-pill">💺 <%= capTotalM %> asientos</span>
                                <% } else { %>
                                    <span class="muni-pill nueva">🆕 Recién agregada al catálogo</span>
                                <% } %>
                                <% if (rutasM != null && !rutasM.isEmpty()) { %>
                                    <span class="muni-pill activa">🗺️ <%= rutasM.size() %> <%= rutasM.size() == 1 ? "línea activa" : "líneas activas" %></span>
                                <% } %>
                            </div>

                            <!-- RUTAS QUE OPERAN CON ESTA MUNICIPALIDAD -->
                            <div class="rutas-badges">
                                <% if (rutasM != null && !rutasM.isEmpty()) {
                                    for (String rName : rutasM) { %>
                                        <a href="lineas.jsp?muni=<%= urlMuniParam %>" class="badge-ruta">🗺️ <%= h(rName) %></a>
                                <%  }
                                   } else { %>
                                    <span class="badge-catalogo">📍 Jurisdicción habilitada para nuevas rutas</span>
                                <% } %>
                            </div>

                            <!-- UNIDADES DE FLOTA PERTENECIENTES A LA MUNICIPALIDAD -->
                            <% if (busesM != null && !busesM.isEmpty()) { %>
                                <div class="muni-buses">
                                    <% for (String bInfo : busesM) { %>
                                        <div><%= bInfo %></div>
                                    <% } %>
                                </div>
                            <% } else { %>
                                <div class="info-seg sin-datos">Sin unidades asignadas aún — visible en toda la red como jurisdicción oficial.</div>
                            <% } %>

                            <div class="muni-actions">
                                <a href="lineas.jsp?muni=<%= urlMuniParam %>" class="muni-link">🛤️ Ver Líneas en Mapa</a>
                                <a href="operacion.jsp?filtro_muni=<%= urlMuniParam %>" class="muni-link">🎫 Ver Asientos</a>
                            </div>
                        </div>
            <%
                    }
                }
            %>
        </div>

        <!-- SECCIÓN 2: DIRECTORIO DE ESTACIONES -->
        <div class="section-heading" id="estaciones">
            <h3><span>🚏</span><span>Directorio de Estaciones y Accesos</span></h3>
            <span class="sub">Paradas activas y de catálogo con coordenadas GPS, molinetes, guardias y tramos en km</span>
        </div>

        <div class="estaciones-grid">
            <%
                if (errorMsg != null) {
                    out.print("<div class='empty-state'>Error al consultar estaciones: " + h(errorMsg) + "</div>");
                } else if (todasLasEstaciones.isEmpty()) {
                    out.print("<div class='empty-state'>Aún no hay estaciones registradas en el sistema.</div>");
                } else {
                    for (Map.Entry<String, String> entry : todasLasEstaciones.entrySet()) {
                        String key = entry.getKey();
                        String nomMostrar = entry.getValue();
                        String coords = coordenadasPorEst.get(key);
                        Set<String> rutas = rutasPorEst.get(key);
                        List<String> seguridad = seguridadPorEst.get(key);
                        List<String> tramos = tramosPorEst.get(key);
            %>
                        <div class="estacion-card">
                            <div class="est-top">
                                <div class="icono">🚏</div>
                                <div>
                                    <div class="nombre"><%= h(nomMostrar) %></div>
                                    <div class="coords"><%= coords != null ? h(coords) : "📍 Estación registrada en catálogo" %></div>
                                </div>
                            </div>

                            <!-- RUTAS QUE PASAN POR ESTA ESTACIÓN -->
                            <div class="rutas-badges">
                                <% if (rutas != null && !rutas.isEmpty()) {
                                    for (String rName : rutas) { %>
                                        <span class="badge-ruta">🗺️ <%= h(rName) %></span>
                                <%  }
                                   } else { %>
                                    <span class="badge-catalogo">🆕 Disponible para asignar a ruta</span>
                                <% } %>
                            </div>

                            <!-- MOLINETES Y GUARDIAS -->
                            <% if (seguridad != null && !seguridad.isEmpty()) {
                                for (String lineaSeg : seguridad) { %>
                                    <div class="info-seg"><%= lineaSeg %></div>
                            <%  }
                               } else { %>
                                <div class="info-seg sin-datos">⚠️ Sin molinete ni guardia asignado</div>
                            <% } %>

                            <!-- TRAMOS CONECTADOS (KM) -->
                            <% if (tramos != null && !tramos.isEmpty()) { %>
                                <div class="info-km">
                                    <% for (String tr : tramos) { %>
                                        <div><%= tr %></div>
                                    <% } %>
                                </div>
                            <% } %>
                        </div>
            <%
                    }
                }
            %>
        </div>
    </div>

    <script>
        function toggleMenu(side) {
            let left = document.getElementById("leftSidebar");
            let right = document.getElementById("rightSidebar");
            let over = document.getElementById("overlay");
            if (side === 'left') { left.style.width = "250px"; if (right) right.style.width = "0"; }
            else if (side === 'right') { if (right) right.style.width = "300px"; left.style.width = "0"; }
            over.style.display = "block";
        }
        function closeAllMenus() {
            document.getElementById("leftSidebar").style.width = "0";
            let right = document.getElementById("rightSidebar");
            if (right) right.style.width = "0";
            document.getElementById("overlay").style.display = "none";
        }
    </script>
</body>
</html>
