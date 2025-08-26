<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<html>
<head>
    <title>Request Password Reset</title>
</head>
<body>
<h2>Request Password Reset</h2>
<form method="post" action="request-reset">
    <label>Email: <input type="email" name="email" required></label><br>
    <button type="submit">Send Reset Link</button>
</form>
<c:if test="${not empty message}">
    <div style="color:green;">${message}</div>
</c:if>
<a href="login.jsp">Back to Login</a>
</body>
</html>
