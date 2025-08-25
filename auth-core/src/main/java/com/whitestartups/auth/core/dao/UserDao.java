

package com.whitestartups.auth.core.dao;

import com.whitestartups.auth.core.model.User;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.persistence.EntityManager;
import jakarta.persistence.PersistenceContext;
import jakarta.transaction.Transactional;
import java.util.Optional;

@ApplicationScoped
public class UserDao {
    @PersistenceContext(unitName = "authPU")
    private EntityManager em;

    public Optional<User> findByUsername(String username) {
        try {
            return Optional.of(
                em.createNamedQuery("User.findByUsername", User.class)
                  .setParameter("username", username)
                  .getSingleResult()
            );
        } catch (Exception e) {
            return Optional.empty();
        }
    }

    public Optional<User> findByEmail(String email) {
        try {
            return Optional.of(
                em.createQuery("SELECT u FROM User u WHERE u.email = :email", User.class)
                  .setParameter("email", email)
                  .getSingleResult()
            );
        } catch (Exception e) {
            return Optional.empty();
        }
    }

    public Optional<User> findByResetToken(String token) {
        try {
            return Optional.of(
                em.createQuery("SELECT u FROM User u WHERE u.resetToken = :token", User.class)
                  .setParameter("token", token)
                  .getSingleResult()
            );
        } catch (Exception e) {
            return Optional.empty();
        }
    }

    public Optional<User> findByVerificationToken(String token) {
        try {
            return Optional.of(
                em.createQuery("SELECT u FROM User u WHERE u.verificationToken = :token", User.class)
                  .setParameter("token", token)
                  .getSingleResult()
            );
        } catch (Exception e) {
            return Optional.empty();
        }
    }

    @Transactional
    public void save(User user) {
        em.merge(user);
    }
}
