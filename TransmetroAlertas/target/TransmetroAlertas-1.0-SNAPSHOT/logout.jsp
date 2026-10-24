<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"%>
<%
    // Destruye todas las variables de sesión del servidor
    session.invalidate();
    
    // Redirige al usuario de vuelta a la pantalla de login
    response.sendRedirect("login.jsp");
%>