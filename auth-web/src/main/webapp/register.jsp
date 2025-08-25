<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<html>
<head>
    <title>Register</title>
</head>
<body>
<h2>Register</h2>
<form method="post" action="register">
    <label>Username: <input type="text" name="username" required></label><br>
    <label>Email: <input type="email" name="email" required></label><br>
    <label>Display Name: <input type="text" name="displayName" required></label><br>
    <label>Password: <input type="password" name="password" required></label><br>
    <label>Region: <input type="text" name="region" required></label><br>
    <button type="submit">Register</button>
</form>
<c:if test="${not empty error}">
    <div style="color:red;">${error}</div>
</c:if>
<a href="login.jsp">Back to Login</a>
</body>
</html>
