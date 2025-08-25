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
import java.util.Optional;
import java.util.UUID;

@WebServlet("/verify-email")
public class EmailVerificationServlet extends HttpServlet {
    @Inject
    private UserDao userDao;

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse resp) throws ServletException, IOException {
        String token = req.getParameter("token");
        Optional<User> userOpt = userDao.findByVerificationToken(token);
        if (userOpt.isPresent()) {
            User user = userOpt.get();
            user.setEmailVerified(true);
            user.setVerificationToken(null);
            userDao.save(user);
            req.setAttribute("message", "Email verified. You may now log in.");
            req.getRequestDispatcher("/login.jsp").forward(req, resp);
            return;
        }
        req.setAttribute("error", "Invalid or expired verification token.");
        req.getRequestDispatcher("/login.jsp").forward(req, resp);
    }
}
