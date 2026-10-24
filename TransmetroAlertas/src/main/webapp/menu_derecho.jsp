<%@page contentType="text/html" pageEncoding="UTF-8"%>
<%
    String rolActualDer = (String) session.getAttribute("rol");
    boolean isAdminDer = "admin".equals(rolActualDer);
    String uriDer = request.getRequestURI() != null ? request.getRequestURI() : "";
%>

<% if (isAdminDer) { %>
<style>
    .sidebar-right {
        height: 100%;
        width: 0;
        position: fixed;
        z-index: 1001;
        top: 0;
        right: 0;
        background: #ffffff !important;
        overflow-x: hidden;
        overflow-y: auto;
        transition: width 0.28s cubic-bezier(0.4, 0, 0.2, 1);
        box-shadow: -8px 0 30px rgba(15, 23, 42, 0.12) !important;
        font-family: 'Inter', -apple-system, sans-serif;
        display: flex;
        flex-direction: column;
        white-space: nowrap;
        border-left: 1px solid #e2e8f0;
    }

    .sidebar-right .sr-top {
        padding: 18px 20px;
        display: flex;
        align-items: center;
        justify-content: space-between;
        border-bottom: 1px solid #f1f5f9;
    }
    .sidebar-right .sr-title {
        display: flex;
        align-items: center;
        gap: 8px;
        font-size: 15px;
        font-weight: 800;
        color: #0f172a;
        margin: 0;
    }
    .sidebar-right .closebtn {
        width: 30px;
        height: 30px;
        border-radius: 8px;
        border: 1px solid #e2e8f0;
        background: #f8fafc;
        color: #64748b;
        font-size: 18px;
        cursor: pointer;
        display: inline-flex;
        align-items: center;
        justify-content: center;
        transition: 0.18s;
    }
    .sidebar-right .closebtn:hover {
        background: #f1f5f9;
        color: #0f172a;
    }

    .sidebar-right .sr-section {
        padding: 14px 20px 6px 20px;
        font-size: 10px;
        font-weight: 700;
        text-transform: uppercase;
        letter-spacing: 0.08em;
        color: #94a3b8;
    }

    .sidebar-right .admin-item {
        margin: 3px 12px;
        padding: 10px 12px;
        border-radius: 10px;
        border: 1px solid transparent;
        background: #ffffff;
        display: flex;
        align-items: center;
        gap: 12px;
        text-decoration: none;
        transition: 0.16s ease;
    }
    .sidebar-right .admin-item:hover {
        background: #f8fafc;
        border-color: #e2e8f0;
        transform: translateX(-2px);
    }
    .sidebar-right .admin-item.active {
        background: #f0fdfa;
        border-color: #99f6e4;
    }
    .sidebar-right .admin-icon {
        width: 34px;
        height: 34px;
        border-radius: 9px;
        background: #f1f5f9;
        display: flex;
        align-items: center;
        justify-content: center;
        font-size: 16px;
        flex-shrink: 0;
    }
    .sidebar-right .admin-item.active .admin-icon {
        background: #ccfbf1;
    }
    .sidebar-right .admin-text {
        display: flex;
        flex-direction: column;
        overflow: hidden;
    }
    .sidebar-right .admin-text b {
        font-size: 13px;
        font-weight: 700;
        color: #0f172a;
    }
    .sidebar-right .admin-text span {
        font-size: 11px;
        color: #64748b;
    }

    .sidebar-right .sr-footer {
        margin-top: auto;
        padding: 14px 12px 18px 12px;
        border-top: 1px solid #f1f5f9;
    }
    .sidebar-right .btn-logout-sr {
        display: flex;
        align-items: center;
        justify-content: center;
        gap: 8px;
        padding: 10px;
        border-radius: 9px;
        border: 1px solid #fecdd3;
        background: #fff1f2;
        color: #e11d48;
        font-size: 12.5px;
        font-weight: 700;
        text-decoration: none;
        transition: 0.16s;
    }
    .sidebar-right .btn-logout-sr:hover {
        background: #e11d48;
        color: #ffffff;
    }
</style>

<div id="rightSidebar" class="sidebar-right">
    <div class="sr-top">
        <h3 class="sr-title"><span>⚙️</span><span>Administración</span></h3>
        <button class="closebtn" onclick="closeAllMenus()" title="Cerrar panel">&times;</button>
    </div>

    <div class="sr-section">Rutas y Trazado</div>
    <a href="nueva_ruta.jsp" class="admin-item <%= uriDer.contains("nueva_ruta.jsp") ? "active" : "" %>">
        <div class="admin-icon">➕</div>
        <div class="admin-text">
            <b>Nueva Ruta Operativa</b>
            <span>Flota, piloto, molinetes y km</span>
        </div>
    </a>
    <a href="editar_rutas.jsp" class="admin-item <%= uriDer.contains("editar_rutas.jsp") ? "active" : "" %>">
        <div class="admin-icon">✏️</div>
        <div class="admin-text">
            <b>Editar / Eliminar Rutas</b>
            <span>Modificar recorridos y turnos</span>
        </div>
    </a>

    <div class="sr-section">Flota e Infraestructura</div>
    <a href="admin_buses.jsp" class="admin-item <%= uriDer.contains("admin_buses.jsp") ? "active" : "" %>">
        <div class="admin-icon">🚍</div>
        <div class="admin-text">
            <b>Garaje: Crear Unidades</b>
            <span>Registrar buses y asientos</span>
        </div>
    </a>
    <a href="flota.jsp" class="admin-item <%= uriDer.contains("flota.jsp") ? "active" : "" %>">
        <div class="admin-icon">🚌</div>
        <div class="admin-text">
            <b>Inventario de Flota</b>
            <span>Estados, taller y parqueos</span>
        </div>
    </a>
    <a href="admin_infra.jsp" class="admin-item <%= uriDer.contains("admin_infra.jsp") ? "active" : "" %>">
        <div class="admin-icon">🏗️</div>
        <div class="admin-text">
            <b>Panel de Infraestructura</b>
            <span>Parqueos, molinetes y tramos</span>
        </div>
    </a>

    <div class="sr-section">Catálogos y Personal</div>
    <a href="Pilotos-Edicion.jsp" class="admin-item <%= uriDer.contains("Pilotos-Edicion.jsp") ? "active" : "" %>">
        <div class="admin-icon">🪪</div>
        <div class="admin-text">
            <b>Gestión de Pilotos</b>
            <span>Conductores y asignación</span>
        </div>
    </a>
    <a href="admin_catalogos.jsp" class="admin-item <%= uriDer.contains("admin_catalogos.jsp") ? "active" : "" %>">
        <div class="admin-icon">🚏</div>
        <div class="admin-text">
            <b>Catálogos y Estaciones</b>
            <span>Editar paradas y municipios</span>
        </div>
    </a>
    <a href="admin_usuarios.jsp" class="admin-item <%= uriDer.contains("admin_usuarios.jsp") ? "active" : "" %>">
        <div class="admin-icon">👥</div>
        <div class="admin-text">
            <b>Directorio de Usuarios</b>
            <span>Cuentas y permisos del sistema</span>
        </div>
    </a>

    <div class="sr-footer">
        <a href="logout.jsp" class="btn-logout-sr">🔓 Cerrar Sesión Segura</a>
    </div>
</div>
<% } %>
