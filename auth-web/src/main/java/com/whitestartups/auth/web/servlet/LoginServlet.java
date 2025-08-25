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
import jakarta.servlet.http.HttpSession;
import java.io.IOException;
import java.util.Optional;

@WebServlet("/login")
public class LoginServlet extends HttpServlet {
    @Inject
    private UserDao userDao;
    @Inject
    private UserEncryptionService encryptionService;

    @Override
    protected void doPost(HttpServletRequest req, HttpServletResponse resp) throws ServletException, IOException {
        String username = req.getParameter("username");
        String password = req.getParameter("password");
        Optional<User> userOpt = userDao.findByUsername(username);
        if (userOpt.isPresent()) {
            User user = userOpt.get();
            if (encryptionService.verifyPassword(password, user.getPasswordHash())) {
                HttpSession session = req.getSession();
                session.setAttribute("user", user);
                resp.sendRedirect("/dashboard.jsp");
                return;
            }
        }
        req.setAttribute("error", "Invalid username or password");
        req.getRequestDispatcher("/login.jsp").forward(req, resp);
    }
}
