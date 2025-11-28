package university.Security;

import java.util.Date;

import org.springframework.security.authentication.AuthenticationCredentialsNotFoundException;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.stereotype.Component;

import io.jsonwebtoken.Claims;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.SignatureAlgorithm;

@Component
public class JwtProvider {
	public String generateToken(Authentication auth) {
		String id=auth.getName();
		Date currentDate = new Date();
		Date expireDate = new Date(currentDate.getTime() + JwtConfig.expiration);
		String token= Jwts.builder()
				.setSubject(id)
				.setIssuedAt(currentDate)
				.setExpiration(expireDate)
				.signWith(SignatureAlgorithm.HS512,JwtConfig.secret.getBytes())
				.compact();
		return JwtConfig.prefix+token;
	}

	public String getIdFromToken(String token) {
		try {
			Claims claims = Jwts.parserBuilder()
					.setSigningKey(JwtConfig.secret.getBytes())
					.build()
					.parseClaimsJws(token)
					.getBody();
			return claims.getSubject();
		} catch (Exception ex) {
			throw new AuthenticationCredentialsNotFoundException("JWT was exprired or incorrect",ex.fillInStackTrace());
		}
	}

	public boolean validateToken(String token) {
		try {
			Jwts.parserBuilder()
			.setSigningKey(JwtConfig.secret)
			.build()
			.parseClaimsJws(token);
			return true;
		} catch (Exception ex) {
			throw new AuthenticationCredentialsNotFoundException("JWT was exprired or incorrect",ex.fillInStackTrace());
		}
	}
}
