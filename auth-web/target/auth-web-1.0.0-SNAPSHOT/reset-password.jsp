<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<html>
<head>
    <title>Reset Password</title>
</head>
<body>
<h2>Reset Password</h2>
<form method="post" action="reset-password">
    <input type="hidden" name="token" value="${param.token}">
    <label>New Password: <input type="password" name="password" required></label><br>
    <button type="submit">Reset Password</button>
</form>
<c:if test="${not empty error}">
    <div style="color:red;">${error}</div>
</c:if>
<a href="login.jsp">Back to Login</a>
</body>
</html>
