package com.whitestartups.auth.web.servlet;

import com.whitestartups.auth.core.dao.UserDao;
import com.whitestartups.auth.core.model.User;
import com.whitestartups.auth.core.service.UserEncryptionService;
import jakarta.inject.Inject;
import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.time.LocalDateTime;

@WebServlet("/register")
public class RegisterServlet extends HttpServlet {
    @Inject
    private UserDao userDao;
    @Inject
    private UserEncryptionService encryptionService;

    @Override
    protected void doPost(HttpServletRequest req, HttpServletResponse resp) throws ServletException, IOException {
        String username = req.getParameter("username");
        String email = req.getParameter("email");
        String displayName = req.getParameter("displayName");
        String password = req.getParameter("password");
        String region = req.getParameter("region");
        if (userDao.findByUsername(username).isPresent()) {
            req.setAttribute("error", "Username already exists");
            req.getRequestDispatcher("/register.jsp").forward(req, resp);
            return;
        }
    User user = new User();
    user.setUsername(username);
    user.setEmail(email);
    user.setDisplayName(displayName);
    user.setPasswordHash(encryptionService.hashPassword(password));
    user.setRegion(region);
    user.setCreatedAt(LocalDateTime.now());
    user.setEmailVerified(false);
    String verificationToken = java.util.UUID.randomUUID().toString();
    user.setVerificationToken(verificationToken);
    userDao.save(user);
    // TODO: Send email with verification link: /verify-email?token=verificationToken
    resp.sendRedirect("/login.jsp?registered=true");
    }
}
