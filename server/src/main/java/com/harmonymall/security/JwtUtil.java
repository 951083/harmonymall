package com.harmonymall.security;

import io.jsonwebtoken.Claims;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import javax.crypto.SecretKey;
import java.nio.charset.StandardCharsets;
import java.util.Date;

/**
 * JWT 工具：生成与解析 token
 */
@Component
public class JwtUtil {

    @Value("${harmonymall.jwt.secret}")
    private String secret;

    @Value("${harmonymall.jwt.expire-hours:24}")
    private long expireHours;

    private SecretKey key() {
        return Keys.hmacShaKeyFor(secret.getBytes(StandardCharsets.UTF_8));
    }

    public String createToken(Long userId, String username) {
        return Jwts.builder()
                .claim("userId", userId)
                .claim("username", username)
                .issuedAt(new Date())
                .expiration(new Date(System.currentTimeMillis() + expireHours * 3600 * 1000))
                .signWith(key())
                .compact();
    }

    public Claims parseToken(String token) {
        if (token == null || !token.startsWith("Bearer ")) {
            return null;
        }
        try {
            return Jwts.parser().verifyWith(key()).build()
                    .parseSignedClaims(token.substring(7)).getPayload();
        } catch (Exception e) {
            return null;
        }
    }

    public Long parseUserId(String token) {
        Claims claims = parseToken(token);
        if (claims == null) {
            return null;
        }
        Object userId = claims.get("userId");
        return userId == null ? null : Long.valueOf(userId.toString());
    }
}
