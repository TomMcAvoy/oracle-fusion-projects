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
import java.util.Optional;

@WebServlet("/reset-password")
public class PasswordResetServlet extends HttpServlet {
    @Inject
    private UserDao userDao;
    @Inject
    private UserEncryptionService encryptionService;

    @Override
    protected void doPost(HttpServletRequest req, HttpServletResponse resp) throws ServletException, IOException {
        String token = req.getParameter("token");
        String password = req.getParameter("password");
        Optional<User> userOpt = userDao.findByResetToken(token);
        if (userOpt.isPresent()) {
            User user = userOpt.get();
            if (user.getResetTokenExpiry() != null && user.getResetTokenExpiry().isAfter(LocalDateTime.now())) {
                user.setPasswordHash(encryptionService.hashPassword(password));
                user.setResetToken(null);
                user.setResetTokenExpiry(null);
                userDao.save(user);
                req.setAttribute("message", "Password reset successful. Please log in.");
                req.getRequestDispatcher("/login.jsp").forward(req, resp);
                return;
            }
        }
        req.setAttribute("error", "Invalid or expired reset token.");
        req.getRequestDispatcher("/reset-password.jsp").forward(req, resp);
    }
}
