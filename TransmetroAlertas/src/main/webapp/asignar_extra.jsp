<%@page contentType="text/html" pageEncoding="UTF-8"%>
<%@page import="java.sql.*"%>
<%!
    static String h(String s) {
        if (s == null) return "";
        return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace("\"", "&quot;").replace("'", "&#39;");
    }
%>
<%
    String rolActual = (String) session.getAttribute("rol");
    if (session.getAttribute("usuarioValido") == null || "pasajero".equals(rolActual)) {
        response.sendRedirect("index.jsp");
        return;
    }

    String dbUrl = "jdbc:mysql://192.168.15.135:3306/transmetro_db";
    String dbUser = "admin";
    String dbPass = "admin123";

    String idAlerta = request.getParameter("id_alerta");
    String nombreRuta = request.getParameter("ruta");

    if ("POST".equalsIgnoreCase(request.getMethod())) {
        String idBusExtraStr = request.getParameter("id_vehiculo_extra");
        try {
            Class.forName("com.mysql.cj.jdbc.Driver");
            try (Connection con = DriverManager.getConnection(dbUrl, dbUser, dbPass)) {
                int idBusExtra = Integer.parseInt(idBusExtraStr);

                // 1. Asignamos este 2do refuerzo (3er bus) a la ruta colapsada
                try (PreparedStatement psRuta = con.prepareStatement("UPDATE rutas_operativas SET id_vehiculo_extra = ? WHERE nombre_ruta = ?")) {
                    psRuta.setInt(1, idBusExtra);
                    psRuta.setString(2, nombreRuta);
                    psRuta.executeUpdate();
                }

                // 2. Cambiamos el estado del vehículo a 'En Ruta' (sale de su parqueo) y aseguramos sus asientos libres
                try (PreparedStatement psVeh = con.prepareStatement("UPDATE flota_vehiculos SET estado = 'En Ruta' WHERE id_vehiculo = ?")) {
                    psVeh.setInt(1, idBusExtra);
                    psVeh.executeUpdate();
                }
                try (PreparedStatement psAs = con.prepareStatement("UPDATE asientos SET estado = 'libre' WHERE id_bus = ?")) {
                    psAs.setInt(1, idBusExtra);
                    psAs.executeUpdate();
                }

                // 3. Resolvemos la alerta automáticamente para que desaparezca del centro de control
                if (idAlerta != null && !idAlerta.isEmpty()) {
                    try (PreparedStatement psAlerta = con.prepareStatement("UPDATE alertas SET estado = 'Resuelta' WHERE id = ?")) {
                        psAlerta.setInt(1, Integer.parseInt(idAlerta));
                        psAlerta.executeUpdate();
                    }
                }
            }
            response.sendRedirect("operacion.jsp?msg=extra_despachado");
            return;
        } catch (Exception e) {
            out.print("Error: " + e.getMessage());
        }
    }
%>

<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <title>Despachar 2do Refuerzo - Transmetro</title>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;700;800&display=swap" rel="stylesheet">
    <style>
        body { font-family: 'Inter', sans-serif; background-color: #f0f2f5; margin: 0; padding-top: 70px; }
        .header { background: #ffffff; padding: 15px 25px; position: fixed; top: 0; width: 100%; border-bottom: 1px solid #e2e8f0; display: flex; }
        .header h1 { margin: 0; font-size: 18px; text-align: center; flex-grow: 1; }
        .main-container { max-width: 640px; margin: 40px auto; padding: 0 20px; }
        .card { background: white; padding: 30px; border-radius: 12px; border-top: 5px solid #dc2626; box-shadow: 0 4px 10px rgba(0,0,0,0.1); text-align: center; }
        h2 { color: #991b1b; margin-top: 0; }
        select { width: 100%; padding: 12px; margin: 20px 0; border: 2px solid #fca5a5; border-radius: 8px; font-size: 15px; font-weight: 600; }
        .btn-submit { background: #dc2626; color: white; padding: 15px; width: 100%; border: none; border-radius: 8px; font-weight: bold; font-size: 16px; cursor: pointer; transition: 0.2s; }
        .btn-submit:hover { background: #991b1b; }
        .btn-volver { display: inline-block; margin-bottom: 20px; color: #64748b; text-decoration: none; font-weight: 600; }
        .nota-parqueo { background: #fef2f2; border: 1px solid #fecaca; color: #7f1d1d; font-size: 13px; padding: 12px; border-radius: 8px; margin-bottom: 10px; line-height: 1.5; }
    </style>
    <link rel="stylesheet" href="css/transmetro.css">
</head>
<body>
    <div class="header"><h1>Centro Logístico de Emergencias</h1></div>
    <div class="main-container">
        <a href="alertas.jsp" class="btn-volver">← Cancelar y volver al Centro de Alertas</a>
        <div class="card">
            <h2>🚨 Despacho de Segundo Refuerzo (Bus Extra)</h2>
            <p>La ruta <b><%= h(nombreRuta) %></b> ha llenado su Bus Principal y su primer Refuerzo al 100%. Seleccione una unidad disponible en parqueo para desplegarla inmediatamente.</p>

            <div class="nota-parqueo">
                🅿️ <b>Ciclo Operativo:</b> La unidad saldrá de su parqueo asignado para cubrir este viaje y, al completarse el recorrido en <b>Operación en Vivo</b>, regresará automáticamente a su parqueo y se ocultará de la ruta hasta una nueva orden.
            </div>

            <form method="POST">
                <select name="id_vehiculo_extra" required>
                    <option value="">-- Seleccionar Unidad Disponible en Parqueo --</option>
                    <%
                        try (Connection con = DriverManager.getConnection(dbUrl, dbUser, dbPass);
                             Statement st = con.createStatement()) {
                            String queryLibres =
                                "SELECT f.id_vehiculo, f.placa, f.capacidad, f.municipalidad, p.nombre AS nombre_parqueo " +
                                "FROM flota_vehiculos f LEFT JOIN parqueos p ON f.id_parqueo = p.id_parqueo " +
                                "WHERE f.estado != 'Mantenimiento' AND f.id_vehiculo NOT IN (" +
                                "  SELECT id_vehiculo_main FROM rutas_operativas WHERE id_vehiculo_main IS NOT NULL UNION " +
                                "  SELECT id_vehiculo_backup FROM rutas_operativas WHERE id_vehiculo_backup IS NOT NULL UNION " +
                                "  SELECT id_vehiculo_extra FROM rutas_operativas WHERE id_vehiculo_extra IS NOT NULL" +
                                ") ORDER BY f.placa ASC";
                            try (ResultSet rs = st.executeQuery(queryLibres)) {
                                while (rs.next()) {
                                    String pq = rs.getString("nombre_parqueo") != null ? rs.getString("nombre_parqueo") : "Garaje Central";
                                    String muni = rs.getString("municipalidad") != null ? rs.getString("municipalidad") : "General";
                                    out.print("<option value='" + rs.getInt("id_vehiculo") + "'>🚍 Placa: " + h(rs.getString("placa")) +
                                              " · 💺 " + rs.getInt("capacidad") + " asientos · 🅿️ Parqueo: " + h(pq) +
                                              " (" + h(muni) + ")</option>");
                                }
                            }
                        } catch (Exception e) {}
                    %>
                </select>
                <button type="submit" class="btn-submit">🚀 Despachar 2do Refuerzo desde su Parqueo y Resolver Alerta</button>
            </form>
        </div>
    </div>
</body>
</html>