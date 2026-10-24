<%@page pageEncoding="UTF-8"%>
<%
    String rolUsuario = (String) session.getAttribute("rol");
    if (rolUsuario == null) rolUsuario = "pasajero";

    String nombreUsuario = (String) session.getAttribute("nombre");
    if (nombreUsuario == null) nombreUsuario = "Usuario";

    String iniciales = "U";
    if (!nombreUsuario.isEmpty()) {
        iniciales = nombreUsuario.substring(0, 1).toUpperCase();
    }

    String uriActual = request.getRequestURI() != null ? request.getRequestURI() : "";
%>
<style>
    #leftSidebar {
        height: 100%;
        width: 0;
        position: fixed;
        z-index: 1001;
        top: 0;
        left: 0;
        background: #0f172a !important;
        overflow-x: hidden;
        overflow-y: auto;
        transition: width 0.28s cubic-bezier(0.4, 0, 0.2, 1);
        box-shadow: 8px 0 30px rgba(15, 23, 42, 0.35);
        white-space: nowrap;
        font-family: 'Inter', -apple-system, sans-serif;
        display: flex;
        flex-direction: column;
        border-right: 1px solid rgba(255, 255, 255, 0.08);
    }

    #leftSidebar .sb-top {
        padding: 20px 18px 14px 18px;
        display: flex;
        align-items: center;
        justify-content: space-between;
        border-bottom: 1px solid rgba(255, 255, 255, 0.07);
    }
    #leftSidebar .sb-brand {
        display: flex;
        align-items: center;
        gap: 10px;
        font-size: 16px;
        font-weight: 800;
        color: #ffffff;
        letter-spacing: -0.02em;
    }
    #leftSidebar .sb-brand-dot {
        width: 10px;
        height: 10px;
        border-radius: 50%;
        background: #14b8a6;
        box-shadow: 0 0 10px #14b8a6;
    }
    #leftSidebar .close-btn {
        width: 30px;
        height: 30px;
        border-radius: 8px;
        border: 1px solid rgba(255, 255, 255, 0.1);
        background: rgba(255, 255, 255, 0.04);
        color: #94a3b8;
        font-size: 18px;
        cursor: pointer;
        display: inline-flex;
        align-items: center;
        justify-content: center;
        transition: 0.18s;
    }
    #leftSidebar .close-btn:hover {
        background: rgba(255, 255, 255, 0.12);
        color: #ffffff;
    }

    /* Tarjeta de Perfil Minimalista */
    #leftSidebar .profile-card-sidebar {
        margin: 14px 14px 8px 14px;
        background: rgba(255, 255, 255, 0.04);
        border: 1px solid rgba(255, 255, 255, 0.08);
        border-radius: 12px;
        padding: 11px 12px !important;
        display: flex !important;
        align-items: center;
        text-decoration: none !important;
        transition: 0.2s;
    }
    #leftSidebar .profile-card-sidebar:hover {
        background: rgba(20, 184, 166, 0.12) !important;
        border-color: rgba(20, 184, 166, 0.35);
        padding-left: 12px !important;
    }
    #leftSidebar .profile-avatar {
        width: 36px;
        height: 36px;
        border-radius: 10px;
        background: linear-gradient(135deg, #0d9488, #0284c7);
        color: #ffffff;
        display: flex;
        align-items: center;
        justify-content: center;
        font-weight: 800;
        font-size: 15px;
        margin-right: 10px;
        flex-shrink: 0;
    }
    #leftSidebar .profile-info {
        flex-grow: 1;
        overflow: hidden;
    }
    #leftSidebar .profile-name {
        font-size: 13px;
        font-weight: 700;
        color: #f8fafc;
        margin: 0;
        overflow: hidden;
        text-overflow: ellipsis;
    }
    #leftSidebar .profile-sub {
        font-size: 11px;
        color: #94a3b8;
        margin: 2px 0 0 0;
        display: flex;
        align-items: center;
        gap: 6px;
    }
    #leftSidebar .rol-badge {
        font-size: 9.5px;
        background: rgba(20, 184, 166, 0.2);
        color: #5eead4;
        border: 1px solid rgba(20, 184, 166, 0.35);
        padding: 1px 6px;
        border-radius: 999px;
        font-weight: 700;
        text-transform: uppercase;
        letter-spacing: 0.04em;
    }

    /* Secciones y enlaces */
    #leftSidebar .sb-section {
        padding: 12px 18px 4px 18px;
        font-size: 10px;
        font-weight: 700;
        text-transform: uppercase;
        letter-spacing: 0.08em;
        color: #64748b;
    }
    #leftSidebar a.sb-link {
        margin: 2px 10px;
        padding: 9px 12px;
        border-radius: 9px;
        text-decoration: none;
        font-size: 13px;
        font-weight: 500;
        color: #cbd5e1;
        display: flex;
        align-items: center;
        gap: 10px;
        transition: 0.16s ease;
        border: none;
    }
    #leftSidebar a.sb-link:hover {
        background: rgba(255, 255, 255, 0.06);
        color: #ffffff;
        padding-left: 14px;
    }
    #leftSidebar a.sb-link.active {
        background: rgba(13, 148, 136, 0.18);
        color: #5eead4;
        font-weight: 700;
        border-left: 3px solid #14b8a6;
    }
    #leftSidebar a.sb-link .sb-icon {
        width: 20px;
        text-align: center;
        font-size: 15px;
    }

    #leftSidebar .sb-footer {
        margin-top: auto;
        padding: 12px 10px 18px 10px;
        border-top: 1px solid rgba(255, 255, 255, 0.07);
    }
    #leftSidebar a.sb-logout {
        padding: 9px 12px;
        border-radius: 9px;
        text-decoration: none;
        font-size: 13px;
        font-weight: 600;
        color: #fda4af;
        display: flex;
        align-items: center;
        gap: 10px;
        transition: 0.16s;
    }
    #leftSidebar a.sb-logout:hover {
        background: rgba(225, 29, 72, 0.15);
        color: #fecdd3;
    }
</style>

<div id="leftSidebar">
    <div class="sb-top">
        <div class="sb-brand">
            <span class="sb-brand-dot"></span>
            <span>Transmetro GT</span>
        </div>
        <button class="close-btn" onclick="closeAllMenus()" title="Cerrar menú">×</button>
    </div>

    <a href="mi_perfil.jsp" class="profile-card-sidebar">
        <div class="profile-avatar"><%= iniciales %></div>
        <div class="profile-info">
            <p class="profile-name"><%= nombreUsuario %></p>
            <p class="profile-sub">
                <span class="rol-badge"><%= rolUsuario %></span>
                <span>Mi Perfil</span>
            </p>
        </div>
        <span style="color:#64748b; font-size:13px;">›</span>
    </a>

    <div class="sb-section">Operación y Viajes</div>
    <a href="index.jsp" class="sb-link <%= uriActual.endsWith("/index.jsp") || uriActual.endsWith("/") ? "active" : "" %>">
        <span class="sb-icon">🏠</span><span>Inicio / Dashboard</span>
    </a>
    <a href="lineas.jsp" class="sb-link <%= uriActual.contains("lineas.jsp") ? "active" : "" %>">
        <span class="sb-icon">🛤️</span><span>Mapa en Vivo (PIDS)</span>
    </a>
    <a href="operacion.jsp" class="sb-link <%= uriActual.contains("operacion.jsp") ? "active" : "" %>">
        <span class="sb-icon">🎫</span><span>Abordaje y Asientos</span>
    </a>
    <a href="notificaciones.jsp" class="sb-link <%= uriActual.contains("notificaciones.jsp") ? "active" : "" %>">
        <span class="sb-icon">🔔</span><span>Avisos a Pasajeros</span>
    </a>

    <div class="sb-section">Red e Infraestructura</div>
    <a href="estaciones.jsp" class="sb-link <%= uriActual.contains("estaciones.jsp") ? "active" : "" %>">
        <span class="sb-icon">🚏</span><span>Estaciones y Municipalidades</span>
    </a>
    <a href="flota.jsp" class="sb-link <%= uriActual.contains("flota.jsp") ? "active" : "" %>">
        <span class="sb-icon">🚌</span><span>Flota de Unidades</span>
    </a>
    <a href="pilotos.jsp" class="sb-link <%= uriActual.contains("pilotos.jsp") ? "active" : "" %>">
        <span class="sb-icon">🪪</span><span>Directorio de Pilotos</span>
    </a>
    <a href="infraestructura.jsp" class="sb-link <%= uriActual.contains("infraestructura.jsp") ? "active" : "" %>">
        <span class="sb-icon">🏢</span><span>Parqueos y Seguridad</span>
    </a>

    <% if ("admin".equals(rolUsuario) || "piloto".equals(rolUsuario)) { %>
        <div class="sb-section">Monitoreo y Analítica</div>
        <a href="alertas.jsp" class="sb-link <%= uriActual.contains("alertas.jsp") || uriActual.contains("nueva_alerta.jsp") ? "active" : "" %>">
            <span class="sb-icon">🚨</span><span>Centro de Alertas</span>
        </a>
        <a href="reportes.jsp" class="sb-link <%= uriActual.contains("reportes.jsp") ? "active" : "" %>">
            <span class="sb-icon">📊</span><span>Reportes e Inteligencia</span>
        </a>
    <% } %>

    <div class="sb-section">Zona Recreativa</div>
    <a href="juego.jsp" class="sb-link <%= uriActual.contains("juego.jsp") ? "active" : "" %>">
        <span class="sb-icon">🎮</span><span>Transmetro Rush</span>
    </a>

    <div class="sb-footer">
        <a href="logout.jsp" class="sb-logout">
            <span class="sb-icon">🚪</span><span>Cerrar Sesión</span>
        </a>
    </div>
</div>
