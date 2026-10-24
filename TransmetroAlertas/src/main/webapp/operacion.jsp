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
    
    String dbUrl = "jdbc:mysql://192.168.15.135:3306/transmetro_db"; 
    String dbUser = "admin"; String dbPass = "admin123";

    String rol = (String) session.getAttribute("rol");
    if (rol == null) rol = "pasajero";
    boolean isPasajero = rol.equals("pasajero");
    boolean isAdmin = rol.equals("admin");
    
    Integer miAsientoSession = (Integer) session.getAttribute("mi_asiento_comprado");
    int miAsiento = (miAsientoSession != null) ? miAsientoSession : -1;
    boolean tieneAsiento = (miAsiento != -1);

    String accion = request.getParameter("accion");
    if (accion != null) {
        try {
            Class.forName("com.mysql.cj.jdbc.Driver");
            Connection con = DriverManager.getConnection(dbUrl, dbUser, dbPass);
            PreparedStatement ps = null;
            
            int idAsiento = request.getParameter("id_asiento") != null ? Integer.parseInt(request.getParameter("id_asiento")) : 0;
            
            if (accion.equals("ocupar")) {
                boolean permitir = true;
                if (isPasajero) {
                    if (tieneAsiento) permitir = false; 
                    else session.setAttribute("mi_asiento_comprado", idAsiento); 
                }
                
                if (permitir) {
                    ps = con.prepareStatement("UPDATE asientos SET estado = 'ocupado' WHERE id = ?");
                    ps.setInt(1, idAsiento); ps.executeUpdate();
                    
                    // ALERTA AUTOMÁTICA ADAPTADA A LOS 3 BUSES
                    PreparedStatement psBus = con.prepareStatement(
                        "SELECT a.id_bus AS id_vehiculo_afectado, r.nombre_ruta, r.id_vehiculo_main, r.id_vehiculo_backup, r.id_vehiculo_extra " +
                        "FROM asientos a JOIN rutas_operativas r ON (a.id_bus = r.id_vehiculo_main OR a.id_bus = r.id_vehiculo_backup OR a.id_bus = r.id_vehiculo_extra) " +
                        "WHERE a.id = ?"
                    );
                    psBus.setInt(1, idAsiento);
                    ResultSet rsBus = psBus.executeQuery();
                    
                    if(rsBus.next()) {
                        int idVehiculoAfectado = rsBus.getInt("id_vehiculo_afectado");
                        String nombreRuta = rsBus.getString("nombre_ruta");
                        int idVehiculoPrincipal = rsBus.getInt("id_vehiculo_main");
                        int idVehiculoBackup = rsBus.getInt("id_vehiculo_backup");
                        int idVehiculoExtra = rsBus.getInt("id_vehiculo_extra");
                        
                        Statement stCount = con.createStatement();
                        ResultSet rsCount = stCount.executeQuery("SELECT COUNT(*) AS total, SUM(CASE WHEN estado != 'libre' THEN 1 ELSE 0 END) AS ocupados FROM asientos WHERE id_bus = " + idVehiculoAfectado);
                        
                        if(rsCount.next()) {
                            int total = rsCount.getInt("total");
                            int ocupados = rsCount.getInt("ocupados");
                            
                            if(total > 0 && ocupados == total) {
                                String mensajeAlerta = "";
                                if (idVehiculoAfectado == idVehiculoExtra) {
                                    mensajeAlerta = "🚨 COLAPSO TOTAL: La ruta completa y su bus extra de emergencia se han llenado al 100%.";
                                } else if (idVehiculoAfectado == idVehiculoBackup) {
                                    mensajeAlerta = "🚨 CRÍTICO: La ruta completa (Principal + Refuerzo) se ha llenado al 100%. Capacidad máxima alcanzada.";
                                } else {
                                    mensajeAlerta = "El bus principal se ha llenado al 100% de su capacidad. Se han habilitado los asientos del bus de refuerzo.";
                                }
                                
                                PreparedStatement psCheck = con.prepareStatement("SELECT id FROM alertas WHERE bus_ruta = ? AND estado = 'Activa' AND descripcion = ?");
                                psCheck.setString(1, nombreRuta); psCheck.setString(2, mensajeAlerta);
                                ResultSet rsCheck = psCheck.executeQuery();
                                
                                if(!rsCheck.next()) {
                                    PreparedStatement psAlert = con.prepareStatement("INSERT INTO alertas (tipo_gravedad, bus_ruta, descripcion, reportado_por, estado) VALUES ('Logistica', ?, ?, 'Sistema Automático', 'Activa')");
                                    psAlert.setString(1, nombreRuta); psAlert.setString(2, mensajeAlerta);
                                    psAlert.executeUpdate(); psAlert.close();
                                }
                                rsCheck.close(); psCheck.close();
                            }
                        }
                        rsCount.close(); stCount.close();
                    }
                    rsBus.close(); psBus.close();
                }
                
            } else if (accion.equals("liberar")) {
                boolean permitir = true;
                if (isPasajero) {
                    if (tieneAsiento && miAsiento == idAsiento) session.removeAttribute("mi_asiento_comprado");
                    else permitir = false; 
                }
                if (permitir) {
                    ps = con.prepareStatement("UPDATE asientos SET estado = 'libre' WHERE id = ?");
                    ps.setInt(1, idAsiento); ps.executeUpdate();
                }
            } else if (accion.equals("vaciar_bus") && !isPasajero) {
                int idMainP = Integer.parseInt(request.getParameter("id_main"));
                int idRefP = Integer.parseInt(request.getParameter("id_refuerzo"));
                int idEx = (request.getParameter("id_extra") != null && !request.getParameter("id_extra").isEmpty()) ? Integer.parseInt(request.getParameter("id_extra")) : -1;
                int idRutaP = (request.getParameter("id_ruta") != null && !request.getParameter("id_ruta").isEmpty()) ? Integer.parseInt(request.getParameter("id_ruta")) : -1;

                ps = con.prepareStatement("UPDATE asientos SET estado = 'libre' WHERE id_bus = ? OR id_bus = ? OR id_bus = ?");
                ps.setInt(1, idMainP);
                ps.setInt(2, idRefP);
                ps.setInt(3, idEx);
                ps.executeUpdate();
                ps.close();

                // Si había un 2do refuerzo (Bus Extra) desplegado, al completar/vaciar el viaje regresa a su parqueo y sale de la ruta
                if (idEx > 0) {
                    try (PreparedStatement psVeh = con.prepareStatement("UPDATE flota_vehiculos SET estado = 'Libre en Garaje' WHERE id_vehiculo = ?")) {
                        psVeh.setInt(1, idEx);
                        psVeh.executeUpdate();
                    }
                    if (idRutaP > 0) {
                        try (PreparedStatement psRut = con.prepareStatement("UPDATE rutas_operativas SET id_vehiculo_extra = NULL WHERE id_ruta = ?")) {
                            psRut.setInt(1, idRutaP);
                            psRut.executeUpdate();
                        }
                    } else {
                        try (PreparedStatement psRut = con.prepareStatement("UPDATE rutas_operativas SET id_vehiculo_extra = NULL WHERE id_vehiculo_extra = ?")) {
                            psRut.setInt(1, idEx);
                            psRut.executeUpdate();
                        }
                    }
                }
                ps = null;

            } else if (accion.equals("retornar_extra") && !isPasajero) {
                int idEx = (request.getParameter("id_extra") != null && !request.getParameter("id_extra").isEmpty()) ? Integer.parseInt(request.getParameter("id_extra")) : -1;
                int idRutaP = (request.getParameter("id_ruta") != null && !request.getParameter("id_ruta").isEmpty()) ? Integer.parseInt(request.getParameter("id_ruta")) : -1;

                if (idEx > 0) {
                    try (PreparedStatement psAs = con.prepareStatement("UPDATE asientos SET estado = 'libre' WHERE id_bus = ?")) {
                        psAs.setInt(1, idEx);
                        psAs.executeUpdate();
                    }
                    try (PreparedStatement psVeh = con.prepareStatement("UPDATE flota_vehiculos SET estado = 'Libre en Garaje' WHERE id_vehiculo = ?")) {
                        psVeh.setInt(1, idEx);
                        psVeh.executeUpdate();
                    }
                }
                if (idRutaP > 0) {
                    try (PreparedStatement psRut = con.prepareStatement("UPDATE rutas_operativas SET id_vehiculo_extra = NULL WHERE id_ruta = ?")) {
                        psRut.setInt(1, idRutaP);
                        psRut.executeUpdate();
                    }
                } else if (idEx > 0) {
                    try (PreparedStatement psRut = con.prepareStatement("UPDATE rutas_operativas SET id_vehiculo_extra = NULL WHERE id_vehiculo_extra = ?")) {
                        psRut.setInt(1, idEx);
                        psRut.executeUpdate();
                    }
                }
            }
            if(ps != null) ps.close(); con.close(); 
            
            String urlRedirect = "operacion.jsp";
            String sep = "?";
            if(request.getParameter("filtro_ruta") != null && !request.getParameter("filtro_ruta").isEmpty()) {
                urlRedirect += sep + "filtro_ruta=" + request.getParameter("filtro_ruta");
                sep = "&";
            }
            if ("retornar_extra".equals(accion)) {
                urlRedirect += sep + "msg=extra_retornado";
            } else if ("vaciar_bus".equals(accion)) {
                urlRedirect += sep + "msg=viaje_completado";
            }
            if(accion.equals("ocupar") || accion.equals("liberar")) return; 
            response.sendRedirect(urlRedirect); return;
        } catch(Exception e) {}
    }

    String filtroRutaParam = request.getParameter("filtro_ruta");
    String filtroMuniParam = request.getParameter("filtro_muni");
    if (filtroMuniParam != null) filtroMuniParam = filtroMuniParam.trim();
%>
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Abordaje y Control de Asientos — Transmetro GT</title>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&display=swap" rel="stylesheet">
    <style>
        * { box-sizing: border-box; }
        body {
            font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
            background-color: #f8fafc;
            color: #0f172a;
            margin: 0;
            padding-top: 68px;
        }

        /* Header fijo minimalista */
        .header {
            background: rgba(255, 255, 255, 0.94);
            backdrop-filter: blur(10px);
            color: #0f172a;
            padding: 0 24px;
            position: fixed;
            top: 0;
            left: 0;
            width: 100%;
            height: 64px;
            z-index: 1000;
            display: flex;
            justify-content: space-between;
            align-items: center;
            border-bottom: 1px solid #e2e8f0;
        }
        .header h1 {
            margin: 0;
            font-size: 16px;
            font-weight: 800;
            letter-spacing: -0.02em;
            text-align: center;
            flex-grow: 1;
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
            background: rgba(15, 23, 42, 0.4);
            backdrop-filter: blur(2px);
            z-index: 999;
        }

        /* Contenedor maestro */
        .page-shell {
            max-width: 1280px;
            margin: 22px auto 60px auto;
            padding: 0 20px;
        }

        /* Hero superior + leyenda */
        .top-hero {
            background: #ffffff;
            border: 1px solid #e2e8f0;
            border-radius: 16px;
            padding: 22px 26px;
            margin-bottom: 16px;
            display: flex;
            justify-content: space-between;
            align-items: center;
            flex-wrap: wrap;
            gap: 16px;
            box-shadow: 0 1px 3px rgba(15, 23, 42, 0.03);
        }
        .top-hero-left h2 {
            margin: 0 0 5px 0;
            font-size: 22px;
            font-weight: 800;
            letter-spacing: -0.025em;
            color: #0f172a;
            display: flex;
            align-items: center;
            gap: 8px;
        }
        .top-hero-left p {
            margin: 0;
            font-size: 13.5px;
            color: #64748b;
        }
        .top-hero-right {
            display: flex;
            align-items: center;
            gap: 10px;
            flex-wrap: wrap;
        }
        .btn-pids-link {
            background: #f0fdfa;
            color: #0f766e;
            border: 1px solid #99f6e4;
            padding: 9px 14px;
            border-radius: 10px;
            font-size: 12.5px;
            font-weight: 700;
            text-decoration: none;
            display: inline-flex;
            align-items: center;
            gap: 6px;
            transition: 0.16s;
        }
        .btn-pids-link:hover { background: #ccfbf1; transform: translateY(-1px); }

        /* Barra de leyenda de asientos */
        .legend-strip {
            background: #ffffff;
            border: 1px solid #e2e8f0;
            border-radius: 12px;
            padding: 10px 18px;
            margin-bottom: 16px;
            display: flex;
            align-items: center;
            justify-content: space-between;
            flex-wrap: wrap;
            gap: 12px;
            font-size: 12px;
            color: #475569;
        }
        .legend-items {
            display: flex;
            align-items: center;
            gap: 14px;
            flex-wrap: wrap;
        }
        .legend-item {
            display: inline-flex;
            align-items: center;
            gap: 6px;
            font-weight: 600;
        }
        .legend-swatch {
            width: 14px;
            height: 14px;
            border-radius: 4px;
            display: inline-block;
        }
        .sw-libre { background: #eff6ff; border: 1.5px solid #3b82f6; }
        .sw-mio { background: #0d9488; border: 1.5px solid #0f766e; }
        .sw-ocupado { background: #10b981; }
        .sw-50 { background: #f59e0b; }
        .sw-75 { background: #f97316; }
        .sw-90 { background: #e11d48; }
        .sw-espera { background: #e2e8f0; border: 1px dashed #94a3b8; }

        /* Panel de filtros (Rutas + Municipalidades) */
        .filtro-panel {
            background: #ffffff;
            border: 1px solid #e2e8f0;
            border-radius: 14px;
            padding: 14px 18px;
            margin-bottom: 22px;
            display: flex;
            flex-direction: column;
            gap: 10px;
            box-shadow: 0 1px 2px rgba(15, 23, 42, 0.03);
        }
        .filtro-row {
            display: flex;
            flex-wrap: wrap;
            gap: 7px;
            align-items: center;
        }
        .filtro-row + .filtro-row {
            border-top: 1px solid #f1f5f9;
            padding-top: 10px;
        }
        .filtro-label {
            font-size: 11px;
            font-weight: 800;
            color: #64748b;
            text-transform: uppercase;
            letter-spacing: 0.05em;
            margin-right: 4px;
            display: inline-flex;
            align-items: center;
            gap: 4px;
        }
        .filtro-pill {
            background: #f8fafc;
            color: #334155;
            border: 1px solid #e2e8f0;
            padding: 6px 12px;
            border-radius: 999px;
            font-size: 12px;
            font-weight: 600;
            text-decoration: none;
            transition: all 0.16s ease;
            display: inline-flex;
            align-items: center;
            gap: 5px;
        }
        .filtro-pill:hover {
            background: #f1f5f9;
            border-color: #cbd5e1;
            color: #0f172a;
        }
        .filtro-pill.active {
            background: #0d9488;
            color: #ffffff;
            border-color: #0d9488;
            box-shadow: 0 2px 8px rgba(13, 148, 136, 0.25);
        }
        .filtro-pill .pill-count {
            font-size: 10.5px;
            opacity: 0.85;
            font-weight: 700;
        }

        /* Banners de confirmación */
        .toast-banner {
            border-radius: 12px;
            padding: 13px 18px;
            margin-bottom: 18px;
            font-weight: 700;
            font-size: 13.5px;
            display: flex;
            align-items: center;
            justify-content: center;
            gap: 8px;
            text-align: center;
        }
        .toast-emerald { background: #ecfdf5; color: #065f46; border: 1px solid #a7f3d0; }
        .toast-blue { background: #eff6ff; color: #1e40af; border: 1px solid #bfdbfe; }

        /* Grid de tarjetas de ruta */
        .contenedor-principal {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(460px, 1fr));
            gap: 24px;
            align-items: start;
        }
        @media (max-width: 540px) {
            .contenedor-principal { grid-template-columns: 1fr; }
        }

        .columna-ruta {
            background: #ffffff;
            border: 1px solid #e2e8f0;
            border-radius: 18px;
            padding: 24px;
            box-shadow: 0 4px 20px -4px rgba(15, 23, 42, 0.05);
            position: relative;
            transition: border-color 0.2s;
        }
        .columna-ruta:hover {
            border-color: #cbd5e1;
        }

        /* Encabezado de cada ruta */
        .ruta-top-bar {
            display: flex;
            justify-content: space-between;
            align-items: flex-start;
            gap: 12px;
            margin-bottom: 12px;
            flex-wrap: wrap;
        }
        .ruta-title {
            margin: 0;
            color: #0f172a;
            font-size: 20px;
            font-weight: 800;
            letter-spacing: -0.02em;
            display: flex;
            align-items: center;
            gap: 8px;
        }
        .ruta-badges {
            display: flex;
            flex-wrap: wrap;
            gap: 6px;
            margin-bottom: 14px;
        }
        .meta-chip {
            display: inline-flex;
            align-items: center;
            gap: 4px;
            padding: 4px 10px;
            border-radius: 8px;
            font-size: 11.5px;
            font-weight: 600;
            border: 1px solid transparent;
        }
        .chip-muni { background: #f8fafc; color: #334155; border-color: #e2e8f0; }
        .chip-parqueo { background: #f0f9ff; color: #0369a1; border-color: #bae6fd; }
        .chip-km { background: #f0fdf4; color: #15803d; border-color: #bbf7d0; }
        .chip-piloto { background: #eef2ff; color: #3730a3; border-color: #c7d2fe; }
        .chip-horario { background: #fffbeb; color: #b45309; border-color: #fde68a; }

        /* Estado operativo del viaje */
        .status-pill {
            display: inline-flex;
            align-items: center;
            gap: 6px;
            padding: 6px 12px;
            border-radius: 999px;
            font-size: 11.5px;
            font-weight: 800;
            letter-spacing: 0.03em;
            text-transform: uppercase;
            white-space: nowrap;
        }
        .estado-abordaje { background: #dcfce7; color: #15803d; border: 1px solid #86efac; }
        .estado-abordaje-vuelta { background: #f3e8ff; color: #6b21a8; border: 1px solid #d8b4fe; }
        .estado-enruta { background: #ffedd5; color: #c2410c; border: 1px solid #fdba74; animation: pulsoEnRuta 2s infinite; }
        .estado-finalizado { background: #f1f5f9; color: #64748b; border: 1px solid #cbd5e1; }
        @keyframes pulsoEnRuta { 0%, 100% { opacity: 1; } 50% { opacity: 0.72; } }

        /* Barra de pasajero / botón vaciar ruta */
        .pasajero-info {
            background: #f0f9ff;
            color: #0369a1;
            padding: 10px 14px;
            border-radius: 10px;
            font-size: 12.5px;
            font-weight: 600;
            margin-bottom: 14px;
            border: 1px solid #bae6fd;
            display: flex;
            align-items: center;
            justify-content: space-between;
            gap: 8px;
        }
        .pasajero-info.con-reserva {
            background: #f0fdfa;
            color: #0f766e;
            border-color: #99f6e4;
        }
        .admin-actions-bar {
            display: flex;
            justify-content: flex-end;
            margin-bottom: 14px;
        }
        .btn-vaciar {
            display: inline-flex;
            align-items: center;
            gap: 6px;
            background: #fff1f2;
            color: #e11d48;
            border: 1px solid #fecdd3;
            padding: 8px 14px;
            border-radius: 9px;
            text-decoration: none;
            font-weight: 700;
            font-size: 12.5px;
            transition: 0.16s;
        }
        .btn-vaciar:hover {
            background: #e11d48;
            color: #ffffff;
            border-color: #e11d48;
        }

        /* Mapa lineal de estaciones */
        .mapa-wrapper {
            background: #f8fafc;
            border: 1px solid #e2e8f0;
            border-radius: 14px;
            padding: 14px 16px 16px 16px;
            margin-bottom: 18px;
        }
        .mapa-header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            font-size: 11px;
            font-weight: 700;
            color: #64748b;
            text-transform: uppercase;
            letter-spacing: 0.04em;
            margin-bottom: 14px;
        }
        .mapa-ruta {
            display: flex;
            align-items: flex-start;
            justify-content: space-between;
            position: relative;
            padding: 8px 4px 2px 4px;
        }
        .linea-conexion {
            position: absolute;
            top: 15px;
            left: 14px;
            right: 14px;
            height: 6px;
            background: #e2e8f0;
            z-index: 1;
            border-radius: 999px;
        }
        .linea-progreso {
            height: 100%;
            background: linear-gradient(90deg, #0d9488, #10b981);
            width: 0%;
            border-radius: 999px;
            transition: width 1s linear;
            position: relative;
        }
        .linea-progreso::after {
            content: '🚍';
            position: absolute;
            right: -11px;
            top: -13px;
            font-size: 19px;
            z-index: 10;
            filter: drop-shadow(0 2px 3px rgba(15, 23, 42, 0.25));
        }
        .estacion-punto {
            position: relative;
            z-index: 2;
            display: flex;
            flex-direction: column;
            align-items: center;
            flex: 1;
        }
        .punto {
            width: 14px;
            height: 14px;
            background: #ffffff;
            border: 3.5px solid #0d9488;
            border-radius: 50%;
            box-shadow: 0 1px 3px rgba(15, 23, 42, 0.15);
        }
        .nombre-estacion {
            font-size: 10.5px;
            font-weight: 700;
            color: #334155;
            margin-top: 6px;
            text-align: center;
            max-width: 78px;
            line-height: 1.25;
        }

        /* Alertas de capacidad */
        .alerta-lleno {
            background: #fffbeb;
            color: #92400e;
            border: 1px solid #fcd34d;
            padding: 12px 14px;
            border-radius: 12px;
            text-align: center;
            margin-bottom: 16px;
            font-weight: 700;
            font-size: 13px;
        }
        .alerta-colapso {
            background: #fef2f2;
            color: #991b1b;
            border: 1px solid #fecaca;
            padding: 14px;
            border-radius: 12px;
            text-align: center;
            margin-bottom: 16px;
            font-weight: 700;
            font-size: 13px;
        }

        /* Cabina de cada unidad (Principal / Refuerzo / 2do Refuerzo) */
        .bus-cabin {
            background: #f8fafc;
            border: 1px solid #e2e8f0;
            border-radius: 14px;
            padding: 15px 16px;
            margin-bottom: 16px;
        }
        .bus-cabin:last-child { margin-bottom: 0; }
        .bus-cabin.cabin-refuerzo {
            background: #fcfcfd;
        }
        .bus-cabin.cabin-extra {
            background: #faf5ff;
            border-color: #ddd6fe;
        }

        .cabin-header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            gap: 8px;
            flex-wrap: wrap;
            margin-bottom: 8px;
        }
        .subtitulo-bus {
            color: #0f172a;
            font-size: 14px;
            font-weight: 800;
            display: flex;
            align-items: center;
            gap: 7px;
            margin: 0;
        }
        .placa-pill {
            background: #0f172a;
            color: #ffffff;
            padding: 2px 8px;
            border-radius: 6px;
            font-family: ui-monospace, SFMono-Regular, Consolas, monospace;
            font-size: 11.5px;
            font-weight: 700;
            letter-spacing: 0.04em;
        }
        .cabin-stats {
            font-size: 12px;
            font-weight: 700;
            color: #475569;
            display: inline-flex;
            align-items: center;
            gap: 6px;
        }

        /* Barra de ocupación por bus */
        .ocupacion-bar-track {
            width: 100%;
            height: 6px;
            background: #e2e8f0;
            border-radius: 999px;
            overflow: hidden;
            margin-bottom: 12px;
        }
        .ocupacion-bar-fill {
            height: 100%;
            background: #10b981;
            border-radius: 999px;
            transition: width 0.3s ease;
        }
        .ocupacion-bar-fill.fill-50 { background: #f59e0b; }
        .ocupacion-bar-fill.fill-75 { background: #f97316; }
        .ocupacion-bar-fill.fill-90 { background: #e11d48; }

        /* Frente visual del bus (Cabina de conducción y puerta) */
        .cockpit-strip {
            display: flex;
            justify-content: space-between;
            align-items: center;
            padding: 6px 12px;
            margin-bottom: 10px;
            background: #ffffff;
            border: 1px dashed #cbd5e1;
            border-radius: 8px;
            font-size: 11px;
            font-weight: 700;
            color: #64748b;
        }

        /* Grid de asientos 2 + pasillo + 2 */
        .grid-asientos {
            display: grid;
            grid-template-columns: repeat(4, 1fr);
            gap: 9px;
        }
        .grid-asientos .asiento:nth-child(4n+2) {
            margin-right: 10px;
        }
        .grid-asientos .asiento:nth-child(4n+3) {
            margin-left: 10px;
        }

        .asiento {
            height: 52px;
            display: flex;
            flex-direction: column;
            align-items: center;
            justify-content: center;
            border-radius: 10px;
            font-size: 12px;
            text-decoration: none;
            transition: all 0.16s ease;
            font-weight: 800;
            gap: 2px;
            position: relative;
            user-select: none;
        }
        .libre {
            background-color: #ffffff;
            color: #1d4ed8;
            border: 1.5px solid #93c5fd;
            cursor: pointer;
            box-shadow: 0 1px 2px rgba(37, 99, 235, 0.06);
        }
        .libre:hover:not(.solo-lectura) {
            background-color: #eff6ff;
            border-color: #2563eb;
            transform: translateY(-2px);
            box-shadow: 0 4px 10px rgba(37, 99, 235, 0.15);
        }
        .libre::before { content: '💺'; font-size: 15px; line-height: 1; }

        .ocupado {
            background-color: #10b981;
            color: #ffffff;
            border: 1.5px solid #059669;
            cursor: pointer;
            box-shadow: 0 2px 6px rgba(16, 185, 129, 0.2);
        }
        .ocupado:hover:not(.solo-lectura) {
            transform: translateY(-2px);
            filter: brightness(0.96);
        }
        .ocupado::before { content: '👤'; font-size: 15px; line-height: 1; }

        .mi-asiento-propio {
            outline: 3px solid #0d9488;
            outline-offset: 1px;
        }

        .capacidad-50 { background-color: #f59e0b !important; border-color: #d97706 !important; color: #ffffff !important; }
        .capacidad-75 { background-color: #f97316 !important; border-color: #ea580c !important; color: #ffffff !important; }
        .capacidad-90 { background-color: #e11d48 !important; border-color: #be123c !important; color: #ffffff !important; }

        .solo-lectura { cursor: not-allowed; opacity: 0.78; }
        .asiento-apagado {
            background-color: #f1f5f9 !important;
            border: 1px dashed #cbd5e1 !important;
            color: #94a3b8 !important;
            opacity: 0.65;
            cursor: not-allowed;
            box-shadow: none !important;
        }

        .btn-return-extra {
            display: flex;
            align-items: center;
            justify-content: center;
            gap: 8px;
            background: #6d28d9;
            color: #ffffff;
            padding: 11px 14px;
            border-radius: 10px;
            text-decoration: none;
            font-weight: 700;
            font-size: 12.5px;
            margin-top: 12px;
            transition: 0.16s;
        }
        .btn-return-extra:hover { background: #5b21b6; transform: translateY(-1px); }
    </style>
    <link rel="stylesheet" href="css/transmetro.css">
</head>
<body>
    <jsp:include page="menu_izquierdo.jsp" />
    <jsp:include page="menu_derecho.jsp" />
    <div id="overlay" class="overlay" onclick="closeAllMenus()"></div>

    <div class="header">
        <button class="menu-btn" onclick="toggleMenu('left')" title="Menú Principal">☰</button>
        <h1>Transmetro GT · Control de Abordaje y Asientos</h1>
        <% if (isAdmin) { %>
            <button class="menu-btn" onclick="toggleMenu('right')" title="Panel de Administración">⚙️</button>
        <% } else { %>
            <div style="width: 38px;"></div>
        <% } %>
    </div>

    <div class="page-shell">

        <!-- HERO SUPERIOR -->
        <div class="top-hero">
            <div class="top-hero-left">
                <h2><span>🎫</span><span>Abordaje y Reserva de Asientos en Vivo</span></h2>
                <p>Monitoreo de capacidad en tiempo real para unidades principales, de refuerzo y despachos de emergencia.</p>
            </div>
            <div class="top-hero-right">
                <a href="lineas.jsp" class="btn-pids-link">🛤️ Mapa PIDS en Vivo</a>
                <a href="estaciones.jsp#municipalidades" class="btn-pids-link" style="background:#f8fafc; color:#334155; border-color:#cbd5e1;">🏛️ Directorio Municipal</a>
            </div>
        </div>

        <!-- LEYENDA VISUAL DE ASIENTOS -->
        <div class="legend-strip">
            <div class="legend-items">
                <span style="font-weight:800; color:#0f172a; text-transform:uppercase; font-size:11px; letter-spacing:0.04em;"> Guía de Asientos:</span>
                <span class="legend-item"><span class="legend-swatch sw-libre"></span> Libre (Disponible)</span>
                <span class="legend-item"><span class="legend-swatch sw-ocupado"></span> Ocupado (&lt;50%)</span>
                <span class="legend-item"><span class="legend-swatch sw-50"></span> Media (50%+)</span>
                <span class="legend-item"><span class="legend-swatch sw-75"></span> Alta (75%+)</span>
                <span class="legend-item"><span class="legend-swatch sw-90"></span> Crítica (90%+)</span>
                <span class="legend-item"><span class="legend-swatch sw-espera"></span> Unidad en Espera</span>
            </div>
            <div style="font-size:11.5px; color:#64748b; font-weight:600;">
                🔄 Sincronización automática cada 15s
            </div>
        </div>

        <!-- PANEL DE FILTROS: RUTAS Y MUNICIPALIDADES -->
        <div class="filtro-panel">
            <div class="filtro-row">
                <span class="filtro-label">🗺️ Rutas:</span>
                <a href="operacion.jsp" class="filtro-pill <%= (filtroRutaParam == null && (filtroMuniParam == null || filtroMuniParam.isEmpty())) ? "active" : "" %>">Todas las Líneas</a>
                <%
                    Set<String> munisCatOp = new LinkedHashSet<>();
                    Map<String, Integer> munisBusesOp = new LinkedHashMap<>();
                    try {
                        Connection conF = DriverManager.getConnection(dbUrl, dbUser, dbPass);
                        Statement stF = conF.createStatement();
                        ResultSet rsF = stF.executeQuery("SELECT id_ruta, nombre_ruta FROM rutas_operativas ORDER BY id_ruta");
                        while(rsF.next()) {
                            String idRStr = rsF.getString("id_ruta");
                            boolean activoR = (filtroRutaParam != null && filtroRutaParam.equals(idRStr));
                            out.print("<a href='operacion.jsp?filtro_ruta=" + idRStr + "' class='filtro-pill " + (activoR ? "active" : "") + "'>" + h(rsF.getString("nombre_ruta")) + "</a>");
                        }
                        rsF.close();
                        try {
                            ResultSet rsMC = stF.executeQuery("SELECT nombre FROM municipalidades ORDER BY nombre");
                            while(rsMC.next()) {
                                String nm = rsMC.getString("nombre");
                                if (nm != null && !nm.trim().isEmpty()) {
                                    munisCatOp.add(nm.trim());
                                    munisBusesOp.putIfAbsent(nm.trim(), 0);
                                }
                            }
                            rsMC.close();
                        } catch(Exception ig) {}
                        try {
                            ResultSet rsMB = stF.executeQuery("SELECT municipalidad, COUNT(*) AS cnt FROM flota_vehiculos WHERE municipalidad IS NOT NULL AND TRIM(municipalidad) <> '' GROUP BY municipalidad ORDER BY municipalidad");
                            while(rsMB.next()) {
                                String nm = rsMB.getString("municipalidad").trim();
                                munisCatOp.add(nm);
                                munisBusesOp.put(nm, rsMB.getInt("cnt"));
                            }
                            rsMB.close();
                        } catch(Exception ig) {}
                        stF.close(); conF.close();
                    } catch(Exception e) {}
                %>
            </div>

            <div class="filtro-row">
                <span class="filtro-label">🏛️ Municipalidades (<%= munisCatOp.size() %>):</span>
                <% for (String mItem : munisCatOp) {
                       boolean actM = (filtroMuniParam != null && filtroMuniParam.equalsIgnoreCase(mItem));
                       int bCount = munisBusesOp.getOrDefault(mItem, 0);
                       String urlM = "operacion.jsp?filtro_muni=" + java.net.URLEncoder.encode(mItem, "UTF-8");
                %>
                    <a href="<%= urlM %>" class="filtro-pill <%= actM ? "active" : "" %>">
                        <span>🏛️ <%= h(mItem) %></span>
                        <span class="pill-count">(<%= bCount > 0 ? bCount + " bus" + (bCount == 1 ? "" : "es") : "🆕 Catálogo" %>)</span>
                    </a>
                <% } %>
            </div>
        </div>

        <%
            String msgParam = request.getParameter("msg");
            if ("extra_retornado".equals(msgParam)) {
        %>
            <div class="toast-banner toast-emerald">
                ✅ Viaje de apoyo finalizado: El 2do Refuerzo (Bus Extra) regresó a su Parqueo Base y fue retirado de la ruta hasta una nueva orden en Alertas.
            </div>
        <% } else if ("extra_despachado".equals(msgParam)) { %>
            <div class="toast-banner toast-blue">
                🚑 Orden ejecutada: El 2do Refuerzo (Bus Extra) salió de su parqueo y se integró temporalmente a la ruta para cubrir la demanda.
            </div>
        <% } else if ("viaje_completado".equals(msgParam)) { %>
            <div class="toast-banner toast-emerald">
                🏁 Viaje completado: Se liberaron los asientos de la ruta y cualquier refuerzo extra regresó automáticamente a su parqueo.
            </div>
        <% } %>

        <!-- CONTENEDOR DE RUTAS -->
        <div class="contenedor-principal">
            <%
                try {
                    Connection con = DriverManager.getConnection(dbUrl, dbUser, dbPass);
                    try (Statement stAlter = con.createStatement()) {
                        stAlter.executeUpdate("ALTER TABLE rutas_operativas ADD COLUMN id_piloto INT DEFAULT NULL");
                    } catch (SQLException ignorar) {}
                    Statement stRutas = con.createStatement();
                    
                    String filtroRuta = request.getParameter("filtro_ruta");
                    String filtroMuni = request.getParameter("filtro_muni");
                    String whereClause = "";
                    if (filtroRuta != null && !filtroRuta.isEmpty()) {
                        whereClause = " WHERE r.id_ruta = " + Integer.parseInt(filtroRuta);
                    } else if (filtroMuni != null && !filtroMuni.trim().isEmpty()) {
                        String mEsc = filtroMuni.trim().replace("'", "''");
                        whereClause = " WHERE (vm.municipalidad = '" + mEsc + "' OR vb.municipalidad = '" + mEsc + "' OR vx.municipalidad = '" + mEsc + "')";
                    }
                    
                    String queryRutas = 
                        "SELECT r.*, " +
                        "vm.placa AS placa_main, vm.municipalidad AS muni_main, pm.nombre AS parqueo_main, " +
                        "pil.nombre AS nombre_piloto, pil.identificador_transmetro AS id_piloto_tm, " +
                        "(SELECT COALESCE(SUM(d.distancia_km), 0) FROM distancias_tramos d WHERE d.id_ruta = r.id_ruta) AS km_ruta, " +
                        "vb.placa AS placa_backup, vb.municipalidad AS muni_backup, " +
                        "vx.placa AS placa_extra, vx.municipalidad AS muni_extra, px.nombre AS parqueo_extra, " +
                        "CURTIME() as hora_actual, " +
                        "IFNULL(r.hora_salida_1, '06:00:00') as hs1, IFNULL(r.hora_llegada_1, '08:00:00') as hl1, " +
                        "r.hora_salida_2 as hs2, r.hora_llegada_2 as hl2, " +
                        "r.hora_salida_3 as hs3, r.hora_llegada_3 as hl3, " +
                        "r.hora_salida_4 as hs4, r.hora_llegada_4 as hl4, " +
                        "r.hora_salida_5 as hs5, r.hora_llegada_5 as hl5, " +
                        "r.hora_salida_6 as hs6, r.hora_llegada_6 as hl6 " +
                        "FROM rutas_operativas r " +
                        "JOIN flota_vehiculos vm ON r.id_vehiculo_main = vm.id_vehiculo " +
                        "LEFT JOIN parqueos pm ON vm.id_parqueo = pm.id_parqueo " +
                        "LEFT JOIN pilotos_catalogo pil ON r.id_piloto = pil.id " +
                        "JOIN flota_vehiculos vb ON r.id_vehiculo_backup = vb.id_vehiculo " + 
                        "LEFT JOIN flota_vehiculos vx ON r.id_vehiculo_extra = vx.id_vehiculo " +
                        "LEFT JOIN parqueos px ON vx.id_parqueo = px.id_parqueo" + whereClause;
                        
                    ResultSet rsRutas = stRutas.executeQuery(queryRutas);
                    int rutasMostradasOp = 0;
                    
                    while(rsRutas.next()) {
                        rutasMostradasOp++;
                        int idRutaActual = rsRutas.getInt("id_ruta");
                        int idVehiculoMain = rsRutas.getInt("id_vehiculo_main");
                        int idVehiculoBackup = rsRutas.getInt("id_vehiculo_backup");
                        int idVehiculoExtra = rsRutas.getInt("id_vehiculo_extra"); // 0 si es null
                        String nombreRuta = rsRutas.getString("nombre_ruta");
                        String placaMain = rsRutas.getString("placa_main");
                        String placaBackup = rsRutas.getString("placa_backup");
                        String placaExtra = rsRutas.getString("placa_extra");
                        String parqueoExtra = rsRutas.getString("parqueo_extra") != null ? rsRutas.getString("parqueo_extra") : "Garaje Central";
                        String muni = rsRutas.getString("muni_main");
                        String muniBackup = rsRutas.getString("muni_backup");
                        String muniExtra = rsRutas.getString("muni_extra");
                        String parqueoMain = rsRutas.getString("parqueo_main");
                        String nombrePiloto = rsRutas.getString("nombre_piloto");
                        String idPilotoTm = rsRutas.getString("id_piloto_tm");
                        java.math.BigDecimal kmRuta = rsRutas.getBigDecimal("km_ruta");
                        String listaEstaciones = rsRutas.getString("lista_estaciones");
                        String horaActual = rsRutas.getString("hora_actual");
                        String hs1 = rsRutas.getString("hs1"); String hl1 = rsRutas.getString("hl1");
                        String hs2 = rsRutas.getString("hs2"); String hl2 = rsRutas.getString("hl2");
                        String hs3 = rsRutas.getString("hs3"); String hl3 = rsRutas.getString("hl3");
                        String hs4 = rsRutas.getString("hs4"); String hl4 = rsRutas.getString("hl4");
                        String hs5 = rsRutas.getString("hs5"); String hl5 = rsRutas.getString("hl5");
                        String hs6 = rsRutas.getString("hs6"); String hl6 = rsRutas.getString("hl6");
                        
                        int turnoActivo = 1; 
                        String hsActiva = hs1, hlActiva = hl1;
                        String estadoViaje = "FINALIZADO"; 
                        
                        int horaActualSeg = Integer.parseInt(horaActual.split(":")[0]) * 3600 + Integer.parseInt(horaActual.split(":")[1]) * 60 + Integer.parseInt(horaActual.split(":")[2]);
                        
                        String[] salidas = {hs1, hs2, hs3, hs4, hs5, hs6};
                        String[] llegadas = {hl1, hl2, hl3, hl4, hl5, hl6};
                        
                        for (int i = 0; i < 6; i++) {
                            if (salidas[i] != null && llegadas[i] != null) {
                                int segSalida = Integer.parseInt(salidas[i].split(":")[0]) * 3600 + Integer.parseInt(salidas[i].split(":")[1]) * 60 + Integer.parseInt(salidas[i].split(":")[2]);
                                int segLlegada = Integer.parseInt(llegadas[i].split(":")[0]) * 3600 + Integer.parseInt(llegadas[i].split(":")[1]) * 60 + Integer.parseInt(llegadas[i].split(":")[2]);
                                
                                if (segLlegada < segSalida) {
                                    if (horaActualSeg >= segSalida || horaActualSeg <= segLlegada) {
                                        estadoViaje = "EN_RUTA"; turnoActivo = i + 1; hsActiva = salidas[i]; hlActiva = llegadas[i]; break;
                                    } else if (horaActualSeg < segSalida && (i == 0 || (horaActualSeg > (Integer.parseInt(llegadas[i-1].split(":")[0]) * 3600 + Integer.parseInt(llegadas[i-1].split(":")[1]) * 60)))) {
                                        estadoViaje = "ABORDAJE"; turnoActivo = i + 1; hsActiva = salidas[i]; hlActiva = llegadas[i]; break;
                                    }
                                } else {
                                    if (horaActualSeg >= segSalida && horaActualSeg <= segLlegada) {
                                        estadoViaje = "EN_RUTA"; turnoActivo = i + 1; hsActiva = salidas[i]; hlActiva = llegadas[i]; break;
                                    } else if (horaActualSeg < segSalida && (i == 0 || horaActualSeg > (Integer.parseInt(llegadas[i-1].split(":")[0]) * 3600 + Integer.parseInt(llegadas[i-1].split(":")[1]) * 60))) {
                                        estadoViaje = "ABORDAJE"; turnoActivo = i + 1; hsActiva = salidas[i]; hlActiva = llegadas[i]; break;
                                    }
                                }
                            }
                        }

                        boolean bloqueado = estadoViaje.equals("EN_RUTA") || estadoViaje.equals("FINALIZADO");
                        boolean esVuelta = (turnoActivo % 2 == 0);
                        String hsCorta = (hsActiva != null && hsActiva.length() >= 5) ? hsActiva.substring(0, 5) : "--:--";
                        String hlCorta = (hlActiva != null && hlActiva.length() >= 5) ? hlActiva.substring(0, 5) : "--:--";
            %>
                <div class="columna-ruta">
                    <!-- ENCABEZADO DE LA LÍNEA -->
                    <div class="ruta-top-bar">
                        <h2 class="ruta-title"><span>🗺️</span><span><%= h(nombreRuta) %></span></h2>
                        <% if(estadoViaje.equals("ABORDAJE")) { %>
                            <span class="status-pill <%= esVuelta ? "estado-abordaje-vuelta" : "estado-abordaje" %>">
                                <%= esVuelta ? "🟣 Abordaje (Retorno)" : "🟢 Abordaje Abierto" %>
                            </span>
                        <% } else if(estadoViaje.equals("EN_RUTA")) { %>
                            <span class="status-pill estado-enruta">🛑 En Ruta · Puertas Cerradas</span>
                        <% } else { %>
                            <span class="status-pill estado-finalizado">💤 En Espera de Turno</span>
                        <% } %>
                    </div>

                    <!-- METADATOS DE LA RUTA -->
                    <div class="ruta-badges">
                        <span class="meta-chip chip-muni">🏛️ <%= muni != null ? h(muni) : "General" %></span>
                        <% if (muniBackup != null && !muniBackup.equalsIgnoreCase(muni != null ? muni : "")) { %>
                            <span class="meta-chip chip-muni" title="Municipalidad Bus Refuerzo">🏛️ <%= h(muniBackup) %></span>
                        <% } %>
                        <% if (muniExtra != null && !muniExtra.equalsIgnoreCase(muni != null ? muni : "") && !muniExtra.equalsIgnoreCase(muniBackup != null ? muniBackup : "")) { %>
                            <span class="meta-chip chip-muni" title="Municipalidad 2do Refuerzo">🏛️ <%= h(muniExtra) %></span>
                        <% } %>
                        <% if (parqueoMain != null) { %>
                            <span class="meta-chip chip-parqueo">🅿️ <%= h(parqueoMain) %></span>
                        <% } %>
                        <% if (kmRuta != null && kmRuta.signum() > 0) { %>
                            <span class="meta-chip chip-km">📏 <%= kmRuta %> km</span>
                        <% } %>
                        <% if (nombrePiloto != null) { %>
                            <span class="meta-chip chip-piloto">👨‍✈️ <%= h(nombrePiloto) %><%= idPilotoTm != null ? " (" + h(idPilotoTm) + ")" : "" %></span>
                        <% } %>
                        <span class="meta-chip chip-horario">🕒 Turno #<%= turnoActivo %> (<%= hsCorta %> → <%= hlCorta %>)</span>
                    </div>

                    <!-- ACCIÓN O ESTADO DE RESERVA DEL USUARIO -->
                    <% if (isPasajero) { %>
                        <div class="pasajero-info <%= tieneAsiento ? "con-reserva" : "" %>">
                            <% if (tieneAsiento) { %>
                                <span>✅ Tienes 1 asiento reservado en tu sesión activa. Haz clic sobre tu asiento si deseas liberarlo.</span>
                            <% } else { %>
                                <span>🎫 Como pasajero puedes reservar <b>1 asiento</b> por viaje haciendo clic en un asiento libre.</span>
                            <% } %>
                        </div>
                    <% } else { %>
                        <div class="admin-actions-bar">
                            <a href="operacion.jsp?accion=vaciar_bus&id_ruta=<%=idRutaActual%>&id_main=<%=idVehiculoMain%>&id_refuerzo=<%=idVehiculoBackup%>&id_extra=<%=idVehiculoExtra > 0 ? idVehiculoExtra : ""%>&filtro_ruta=<%=filtroRuta != null ? filtroRuta : ""%>"
                               class="btn-vaciar"
                               onclick="return confirm('¿Finalizar viaje y vaciar todos los asientos de esta ruta? (Si hay un 2do refuerzo activo, regresará automáticamente a su parqueo)');">
                                🏁 Finalizar Viaje / Liberar Ruta Completa
                            </a>
                        </div>
                    <% } %>

                    <!-- TRAZADO DE ESTACIONES Y PROGRESO -->
                    <div class="mapa-wrapper">
                        <div class="mapa-header">
                            <span>📍 Recorrido de Estaciones</span>
                            <span><%= esVuelta ? "🔄 Sentido Retorno" : "➡️ Sentido Ida" %></span>
                        </div>
                        <div class="mapa-ruta">
                            <div class="linea-conexion">
                                <% if (estadoViaje.equals("EN_RUTA") && !hsActiva.isEmpty()) { %>
                                    <div class="linea-progreso barra-animada" data-id-ruta="<%=idRutaActual%>" data-id-extra="<%=idVehiculoExtra%>" data-inicio="<%=hsActiva%>" data-fin="<%=hlActiva%>" data-actual="<%=horaActual%>"></div>
                                <% } else if (estadoViaje.equals("FINALIZADO")) { %>
                                    <div class="linea-progreso" style="width: 100%;"></div>
                                <% } else { %>
                                    <div class="linea-progreso" style="width: 0%;"></div>
                                <% } %>
                            </div>
                            <%
                                String[] arrayEstaciones = listaEstaciones != null ? listaEstaciones.split(",") : new String[0];
                                if (esVuelta) {
                                    for(int i = 0; i < arrayEstaciones.length / 2; i++) {
                                        String temp = arrayEstaciones[i];
                                        arrayEstaciones[i] = arrayEstaciones[arrayEstaciones.length - 1 - i];
                                        arrayEstaciones[arrayEstaciones.length - 1 - i] = temp;
                                    }
                                }
                                for(String estacion : arrayEstaciones) {
                                    out.print("<div class='estacion-punto'><div class='punto'></div><div class='nombre-estacion'>" + h(estacion.trim()) + "</div></div>");
                                }
                            %>
                        </div>
                    </div>

                    <%
                        // CÁLCULOS PRINCIPAL
                        Statement stCountMain = con.createStatement();
                        ResultSet rsCountMain = stCountMain.executeQuery("SELECT COUNT(*) AS total_asientos, SUM(CASE WHEN estado != 'libre' THEN 1 ELSE 0 END) AS ocupados FROM asientos WHERE id_bus = " + idVehiculoMain);
                        int totalMain = 0; int ocupadosMain = 0; 
                        if(rsCountMain.next()) { totalMain = rsCountMain.getInt("total_asientos"); ocupadosMain = rsCountMain.getInt("ocupados"); }
                        rsCountMain.close(); stCountMain.close();
                        
                        String claseColorMain = "";
                        String fillBarMain = "";
                        int pctMain = totalMain > 0 ? (int) Math.round(((double) ocupadosMain / totalMain) * 100) : 0;
                        if (totalMain > 0) {
                            double porcentaje = (double) ocupadosMain / totalMain;
                            if (porcentaje >= 0.90) { claseColorMain = " capacidad-90"; fillBarMain = " fill-90"; }
                            else if (porcentaje >= 0.75) { claseColorMain = " capacidad-75"; fillBarMain = " fill-75"; }
                            else if (porcentaje >= 0.50) { claseColorMain = " capacidad-50"; fillBarMain = " fill-50"; }
                        }
                        boolean principalLleno = (totalMain > 0 && ocupadosMain >= totalMain);

                        // CÁLCULOS REFUERZO
                        Statement stCountRef = con.createStatement();
                        ResultSet rsCountRef = stCountRef.executeQuery("SELECT COUNT(*) AS total_asientos, SUM(CASE WHEN estado != 'libre' THEN 1 ELSE 0 END) AS ocupados FROM asientos WHERE id_bus = " + idVehiculoBackup);
                        int totalRef = 0; int ocupadosRef = 0; 
                        if(rsCountRef.next()) { totalRef = rsCountRef.getInt("total_asientos"); ocupadosRef = rsCountRef.getInt("ocupados"); }
                        rsCountRef.close(); stCountRef.close();
                        
                        String claseColorRef = "";
                        String fillBarRef = "";
                        int pctRef = totalRef > 0 ? (int) Math.round(((double) ocupadosRef / totalRef) * 100) : 0;
                        if (totalRef > 0) {
                            double porcentajeRef = (double) ocupadosRef / totalRef;
                            if (porcentajeRef >= 0.90) { claseColorRef = " capacidad-90"; fillBarRef = " fill-90"; }
                            else if (porcentajeRef >= 0.75) { claseColorRef = " capacidad-75"; fillBarRef = " fill-75"; }
                            else if (porcentajeRef >= 0.50) { claseColorRef = " capacidad-50"; fillBarRef = " fill-50"; }
                        }
                        boolean refuerzoLleno = (totalRef > 0 && ocupadosRef >= totalRef);
                        
                        // CÁLCULOS EXTRA (Solo si existe)
                        int totalExtra = 0; int ocupadosExtra = 0; String claseColorExtra = ""; String fillBarExtra = ""; int pctExtra = 0; boolean extraLleno = false;
                        if (idVehiculoExtra > 0) {
                            Statement stCountEx = con.createStatement();
                            ResultSet rsCountEx = stCountEx.executeQuery("SELECT COUNT(*) AS total_asientos, SUM(CASE WHEN estado != 'libre' THEN 1 ELSE 0 END) AS ocupados FROM asientos WHERE id_bus = " + idVehiculoExtra);
                            if(rsCountEx.next()) { totalExtra = rsCountEx.getInt("total_asientos"); ocupadosExtra = rsCountEx.getInt("ocupados"); }
                            rsCountEx.close(); stCountEx.close();
                            pctExtra = totalExtra > 0 ? (int) Math.round(((double) ocupadosExtra / totalExtra) * 100) : 0;
                            if (totalExtra > 0) {
                                double porcentajeEx = (double) ocupadosExtra / totalExtra;
                                if (porcentajeEx >= 0.90) { claseColorExtra = " capacidad-90"; fillBarExtra = " fill-90"; }
                                else if (porcentajeEx >= 0.75) { claseColorExtra = " capacidad-75"; fillBarExtra = " fill-75"; }
                                else if (porcentajeEx >= 0.50) { claseColorExtra = " capacidad-50"; fillBarExtra = " fill-50"; }
                            }
                            extraLleno = (totalExtra > 0 && ocupadosExtra >= totalExtra);
                        }
                    %>

                    <!-- AVISOS DE CAPACIDAD DE LA RUTA -->
                    <% if (idVehiculoExtra > 0 && extraLleno && !bloqueado) { %>
                        <div class="alerta-colapso">
                            🚨 <b>CRISIS DE CAPACIDAD:</b> Unidad Principal, Refuerzo y 2do Refuerzo están al 100%.
                        </div>
                    <% } else if (refuerzoLleno && !bloqueado && idVehiculoExtra == 0) { %>
                        <div class="alerta-colapso">
                            🚨 <b>RUTA AL 100% DE CAPACIDAD:</b> Unidad Principal y Refuerzo están llenos.
                            <% if (!isPasajero) { %>
                                <div style="margin-top:8px;">
                                    <a href="alertas.jsp" style="background:#dc2626; color:#ffffff; padding:7px 14px; border-radius:8px; text-decoration:none; font-size:12px; font-weight:800; display:inline-block;">
                                        🚑 Ir al Centro de Alertas para Desplegar 2do Refuerzo →
                                    </a>
                                </div>
                            <% } %>
                        </div>
                    <% } else if (refuerzoLleno && !bloqueado && idVehiculoExtra > 0) { %>
                        <div class="alerta-colapso" style="background:#eff6ff; color:#1e40af; border-color:#bfdbfe;">
                            🚑 <b>2DO REFUERZO ACTIVO:</b> Se habilitó la tercera unidad por orden del Centro de Alertas.
                        </div>
                    <% } else if (principalLleno && !bloqueado) { %>
                        <div class="alerta-lleno">
                            ⚠️ <b>Unidad Principal al 100%:</b> Se han habilitado automáticamente los asientos del Bus de Refuerzo.
                        </div>
                    <% } %>

                    <!-- CABINA 1: BUS PRINCIPAL -->
                    <div class="bus-cabin">
                        <div class="cabin-header">
                            <div class="subtitulo-bus">
                                <span>🚍 Unidad Principal</span>
                                <span class="placa-pill"><%= h(placaMain) %></span>
                                <span style="font-size:11.5px; color:#64748b; font-weight:600;">· 🏛️ <%= muni != null ? h(muni) : "General" %></span>
                            </div>
                            <div class="cabin-stats">
                                <span>💺 <%= ocupadosMain %> / <%= totalMain %></span>
                                <span style="color:#0d9488;">(<%= pctMain %>%)</span>
                            </div>
                        </div>
                        <div class="ocupacion-bar-track">
                            <div class="ocupacion-bar-fill<%= fillBarMain %>" style="width: <%= pctMain %>%;"></div>
                        </div>
                        <div class="cockpit-strip">
                            <span>🪪 Cabina de Conducción (<%= esVuelta ? "Retorno" : "Ida" %>)</span>
                            <span>Pasillo Central</span>
                            <span>🚪 Puerta de Abordaje</span>
                        </div>
                        <div class="grid-asientos">
                            <%
                                Statement stMain = con.createStatement();
                                ResultSet rsMain = stMain.executeQuery("SELECT id, estado, num_asiento FROM asientos WHERE id_bus = " + idVehiculoMain + " ORDER BY num_asiento");
                                while(rsMain.next()) {
                                    int id = rsMain.getInt("id"); String estado = rsMain.getString("estado"); int numAsiento = rsMain.getInt("num_asiento");
                                    String label = "A" + numAsiento;
                                    String claseMio = (isPasajero && miAsiento == id) ? " mi-asiento-propio" : "";
                                    if (estado.equals("libre")) {
                                        if (bloqueado || (isPasajero && tieneAsiento)) out.print("<div class='asiento libre solo-lectura'>" + label + "</div>");
                                        else out.print("<a href='#' onclick='accionarAsiento(event, "+id+", \"ocupar\", this)' class='asiento libre' title='Reservar asiento " + label + "'>" + label + "</a>");
                                    } else if (estado.equals("ocupado")) {
                                        if (bloqueado || (isPasajero && miAsiento != id)) out.print("<div class='asiento ocupado timer-asiento"+claseColorMain+" solo-lectura'>" + label + "</div>");
                                        else out.print("<a href='#' onclick='accionarAsiento(event, "+id+", \"liberar\", this)' class='asiento ocupado timer-asiento"+claseColorMain+claseMio+"' title='Liberar asiento " + label + "'>" + label + "</a>");
                                    }
                                }
                                rsMain.close(); stMain.close();
                            %>
                        </div>
                    </div>

                    <!-- CABINA 2: BUS DE REFUERZO -->
                    <div class="bus-cabin cabin-refuerzo">
                        <div class="cabin-header">
                            <div class="subtitulo-bus">
                                <span>🚌 Unidad de Refuerzo</span>
                                <span class="placa-pill"><%= h(placaBackup) %></span>
                                <span style="font-size:11.5px; color:#64748b; font-weight:600;">· 🏛️ <%= muniBackup != null ? h(muniBackup) : "General" %></span>
                            </div>
                            <div class="cabin-stats">
                                <% if (!principalLleno) { %>
                                    <span style="font-size:11px; color:#94a3b8; font-weight:600;">🔒 Se habilita al llenarse el Principal</span>
                                <% } %>
                                <span>💺 <%= ocupadosRef %> / <%= totalRef %></span>
                                <span style="color:#0284c7;">(<%= pctRef %>%)</span>
                            </div>
                        </div>
                        <div class="ocupacion-bar-track">
                            <div class="ocupacion-bar-fill<%= fillBarRef %>" style="width: <%= pctRef %>%;"></div>
                        </div>
                        <div class="grid-asientos">
                            <%
                                Statement stBackup = con.createStatement();
                                ResultSet rsBackup = stBackup.executeQuery("SELECT id, estado, num_asiento FROM asientos WHERE id_bus = " + idVehiculoBackup + " ORDER BY num_asiento");
                                while(rsBackup.next()) {
                                    int id = rsBackup.getInt("id"); String estado = rsBackup.getString("estado"); int numAsiento = rsBackup.getInt("num_asiento");
                                    String label = "R" + numAsiento;
                                    String claseMio = (isPasajero && miAsiento == id) ? " mi-asiento-propio" : "";
                                    if (estado.equals("libre")) {
                                        if (bloqueado || !principalLleno) out.print("<div class='asiento libre solo-lectura asiento-apagado' title='En espera de que se llene la Unidad Principal'>" + label + "</div>");
                                        else if (isPasajero && tieneAsiento) out.print("<div class='asiento libre solo-lectura'>" + label + "</div>");
                                        else out.print("<a href='#' onclick='accionarAsiento(event, "+id+", \"ocupar\", this)' class='asiento libre' title='Reservar asiento " + label + "'>" + label + "</a>");
                                    } else if (estado.equals("ocupado")) {
                                        if (bloqueado || (isPasajero && miAsiento != id)) out.print("<div class='asiento ocupado solo-lectura"+claseColorRef+"'>" + label + "</div>");
                                        else out.print("<a href='#' onclick='accionarAsiento(event, "+id+", \"liberar\", this)' class='asiento ocupado"+claseColorRef+claseMio+"' title='Liberar asiento " + label + "'>" + label + "</a>");
                                    }
                                }
                                rsBackup.close(); stBackup.close();
                            %>
                        </div>
                    </div>

                    <!-- CABINA 3: 2DO REFUERZO / BUS EXTRA DE EMERGENCIA -->
                    <% if(idVehiculoExtra > 0) { %>
                        <div class="bus-cabin cabin-extra">
                            <div class="cabin-header">
                                <div class="subtitulo-bus" style="color:#5b21b6;">
                                    <span>🚑 2do Refuerzo</span>
                                    <span class="placa-pill" style="background:#5b21b6;"><%= h(placaExtra) %></span>
                                    <span style="font-size:11.5px; color:#6d28d9; font-weight:600;">· 🏛️ <%= muniExtra != null ? h(muniExtra) : "General" %> · 🅿️ <%= h(parqueoExtra) %></span>
                                </div>
                                <div class="cabin-stats" style="color:#5b21b6;">
                                    <span>💺 <%= ocupadosExtra %> / <%= totalExtra %> (<%= pctExtra %>%)</span>
                                </div>
                            </div>
                            <div class="ocupacion-bar-track" style="background:#ede9fe;">
                                <div class="ocupacion-bar-fill<%= fillBarExtra %>" style="width: <%= pctExtra %>%; background:#7c3aed;"></div>
                            </div>
                            <div style="font-size:11.5px; color:#6d28d9; margin-bottom:10px; font-weight:500;">
                                Unidad desplegada por orden del Centro de Alertas. Al finalizar el viaje regresará automáticamente a su parqueo base (<b><%= h(parqueoExtra) %></b>).
                            </div>
                            <div class="grid-asientos">
                                <%
                                    Statement stExtra = con.createStatement();
                                    ResultSet rsExtra = stExtra.executeQuery("SELECT id, estado, num_asiento FROM asientos WHERE id_bus = " + idVehiculoExtra + " ORDER BY num_asiento");
                                    while(rsExtra.next()) {
                                        int id = rsExtra.getInt("id"); String estado = rsExtra.getString("estado"); int numAsiento = rsExtra.getInt("num_asiento");
                                        String label = "E" + numAsiento;
                                        String claseMio = (isPasajero && miAsiento == id) ? " mi-asiento-propio" : "";
                                        if (estado.equals("libre")) {
                                            if (bloqueado || !refuerzoLleno) out.print("<div class='asiento libre solo-lectura asiento-apagado' title='Espere a que el Refuerzo se llene'>" + label + "</div>");
                                            else if (isPasajero && tieneAsiento) out.print("<div class='asiento libre solo-lectura'>" + label + "</div>");
                                            else out.print("<a href='#' onclick='accionarAsiento(event, "+id+", \"ocupar\", this)' class='asiento libre' style='border-color:#a78bfa; color:#6d28d9;'>" + label + "</a>");
                                        } else if (estado.equals("ocupado")) {
                                            if (bloqueado || (isPasajero && miAsiento != id)) out.print("<div class='asiento ocupado solo-lectura"+claseColorExtra+"'>" + label + "</div>");
                                            else out.print("<a href='#' onclick='accionarAsiento(event, "+id+", \"liberar\", this)' class='asiento ocupado"+claseColorExtra+claseMio+"'>" + label + "</a>");
                                        }
                                    }
                                    rsExtra.close(); stExtra.close();
                                %>
                            </div>
                            <% if (!isPasajero) { %>
                                <a href="operacion.jsp?accion=retornar_extra&id_ruta=<%=idRutaActual%>&id_extra=<%=idVehiculoExtra%>&filtro_ruta=<%=filtroRuta != null ? filtroRuta : ""%>"
                                   class="btn-return-extra"
                                   onclick="return confirm('¿Confirmar que el 2do Refuerzo (<%=placaExtra%>) completó el viaje? Regresará a su parqueo (<%=parqueoExtra%>) y ya no aparecerá en esta ruta hasta una nueva orden en Alertas.');">
                                    🅿️ Completar Viaje: Retornar 2do Refuerzo a <%= h(parqueoExtra) %>
                                </a>
                            <% } %>
                        </div>
                    <% } %>
                </div>
            <%
                    }
                    if (rutasMostradasOp == 0 && filtroMuni != null && !filtroMuni.trim().isEmpty()) {
            %>
                <div class="columna-ruta" style="max-width:600px; margin:20px auto; text-align:center; padding:32px 24px; grid-column: 1 / -1;">
                    <div style="font-size:38px; margin-bottom:8px;">🏛️</div>
                    <h2 class="ruta-title" style="justify-content:center; margin-bottom:8px;">Municipalidad: <%= h(filtroMuni) %></h2>
                    <p style="font-size:13.5px; color:#64748b; line-height:1.55; margin-bottom:18px;">
                        Esta municipalidad está registrada en el catálogo oficial del sistema, pero actualmente no tiene una línea operativa activa en circulación o sus unidades se encuentran en garaje.
                    </p>
                    <div style="display:flex; gap:10px; justify-content:center; flex-wrap:wrap;">
                        <a href="operacion.jsp" style="background:#0d9488; color:white; padding:9px 16px; border-radius:9px; text-decoration:none; font-weight:700; font-size:13px;">Ver Todas las Rutas</a>
                        <a href="estaciones.jsp#municipalidades" style="background:#f0f9ff; color:#0369a1; border:1px solid #bae6fd; padding:9px 16px; border-radius:9px; text-decoration:none; font-weight:700; font-size:13px;">Ver Buses y Detalle de Municipalidades</a>
                    </div>
                </div>
            <%
                    }
                    rsRutas.close(); stRutas.close(); con.close();
                } catch(Exception e) {}
            %>
        </div>
    </div>
    
    <script>
        let menuAbierto = false;
        function toggleMenu(side) {
            let leftMenu = document.getElementById("leftSidebar"); let rightMenu = document.getElementById("rightSidebar"); let overlay = document.getElementById("overlay");
            if (side === 'left') { leftMenu.style.width = "250px"; if(rightMenu) rightMenu.style.width = "0"; } 
            else if (side === 'right') { if(rightMenu) rightMenu.style.width = "300px"; leftMenu.style.width = "0"; }
            overlay.style.display = "block"; menuAbierto = true;
        }

        function closeAllMenus() {
            document.getElementById("leftSidebar").style.width = "0";
            let rightMenu = document.getElementById("rightSidebar"); if(rightMenu) rightMenu.style.width = "0";
            document.getElementById("overlay").style.display = "none"; menuAbierto = false;
        }

        function accionarAsiento(event, idAsiento, accion, elemento) {
            event.preventDefault(); 
            let urlParam = new URLSearchParams(window.location.search);
            let idFiltro = urlParam.get('filtro_ruta');
            
            let url = 'operacion.jsp?accion=' + accion + '&id_asiento=' + idAsiento;
            if (idFiltro) url += '&filtro_ruta=' + idFiltro;
            
            fetch(url).then(() => { window.location.reload(); });
        }
        
        function timeToSeconds(t) {
            if(!t) return 0;
            let p = t.split(':'); return parseInt(p[0])*3600 + parseInt(p[1])*60 + parseInt(p[2]||0);
        }

        document.querySelectorAll('.barra-animada').forEach(barra => {
            barra.setAttribute('data-sec-ini', timeToSeconds(barra.getAttribute('data-inicio')));
            barra.setAttribute('data-sec-fin', timeToSeconds(barra.getAttribute('data-fin')));
            barra.setAttribute('data-sec-act', timeToSeconds(barra.getAttribute('data-actual')));
        });

        setInterval(() => {
            document.querySelectorAll('.barra-animada').forEach(barra => {
                let tIni = parseInt(barra.getAttribute('data-sec-ini'));
                let tFin = parseInt(barra.getAttribute('data-sec-fin'));
                let tAct = parseInt(barra.getAttribute('data-sec-act'));
                tAct += 1; barra.setAttribute('data-sec-act', tAct);
                if (tAct >= tIni && tAct <= tFin) {
                    let porcentaje = ((tAct - tIni) / (tFin - tIni)) * 100;
                    barra.style.width = Math.min(porcentaje, 100) + "%";
                } else if (tAct > tFin) {
                    barra.style.width = "100%";
                    // Si el viaje terminó en vivo y había un 2do refuerzo (Bus Extra), regresarlo automáticamente a su parqueo
                    let idExtra = parseInt(barra.getAttribute('data-id-extra') || '0');
                    let idRuta = barra.getAttribute('data-id-ruta');
                    if (idExtra > 0 && !barra.getAttribute('data-retornado')) {
                        barra.setAttribute('data-retornado', 'true');
                        fetch('operacion.jsp?accion=retornar_extra&id_ruta=' + idRuta + '&id_extra=' + idExtra)
                            .then(() => { window.location.reload(); });
                    }
                }
            });
        }, 1000);

        setInterval(() => { if (!menuAbierto) window.location.reload(); }, 15000);
    </script>
</body>
</html>
