<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"%>
<%
    // Página antigua. El registro de pasajeros vive en la pestaña "Registrarse" de login.jsp.
    // Se conserva esta URL solo para no romper enlaces o favoritos viejos.
    // (La versión anterior insertaba usuarios sin definir su rol: era una vía insegura para crear cuentas.)
    response.sendRedirect("login.jsp?tab=registro");
%>