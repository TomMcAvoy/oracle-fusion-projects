<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<html>
<head>
    <title>Dashboard</title>
</head>
<body>
<c:choose>
    <c:when test="${sessionScope.user.emailVerified}">
        <h2>Welcome, ${sessionScope.user.displayName}!</h2>
        <p>You are logged in as: ${sessionScope.user.username}</p>
        <p>Role: ${sessionScope.user.role}</p>
        <a href="logout">Logout</a>
    </c:when>
    <c:otherwise>
        <h2>Email Not Verified</h2>
        <p>Please check your email for a verification link.</p>
        <a href="logout">Logout</a>
    </c:otherwise>
</c:choose>
</body>
</html>
