package com.whitestartups.auth.web.servlet;

import com.whitestartups.auth.core.dao.UserDao;
import com.whitestartups.auth.core.model.User;
import jakarta.inject.Inject;
import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.time.LocalDateTime;
import java.util.Optional;
import java.util.UUID;

@WebServlet("/request-reset")
public class PasswordResetRequestServlet extends HttpServlet {
    @Inject
    private UserDao userDao;

    @Override
    protected void doPost(HttpServletRequest req, HttpServletResponse resp) throws ServletException, IOException {
        String email = req.getParameter("email");
        Optional<User> userOpt = userDao.findByEmail(email);
        if (userOpt.isPresent()) {
            User user = userOpt.get();
            String token = UUID.randomUUID().toString();
            user.setResetToken(token);
            user.setResetTokenExpiry(LocalDateTime.now().plusHours(1));
            userDao.save(user);
            // TODO: Send email with reset link (e.g., /reset-password.jsp?token=...)
        }
        req.setAttribute("message", "If your email is registered, you will receive a reset link.");
        req.getRequestDispatcher("/request-reset.jsp").forward(req, resp);
    }
}
