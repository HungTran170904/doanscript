package university.Security;

import java.io.IOException;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.authentication.AuthenticationCredentialsNotFoundException;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.util.StringUtils;
import org.springframework.web.filter.OncePerRequestFilter;


import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

public class JwtAuthenticationFilter extends OncePerRequestFilter{
	@Autowired
	JwtProvider jwtProvider;
	@Autowired
	CustomUserDetailsService customUserDetailsService;

	@Override
	protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain chain)
			throws ServletException, IOException {
		String header=request.getHeader(JwtConfig.header);
		if(header==null||!header.startsWith(JwtConfig.prefix)||request.getRequestURI().indexOf("/auth")>0) {
			chain.doFilter(request, response);
			return;
		}
		String token=header.substring(JwtConfig.prefix.length(),header.length());
		if(StringUtils.hasText(token)) {
			String id=jwtProvider.getIdFromToken(token);
			CustomUserDetails userDetails=customUserDetailsService.loadById(id);
			 UsernamePasswordAuthenticationToken authenticationToken = new UsernamePasswordAuthenticationToken(userDetails, null,
	                    userDetails.getAuthorities());
	            SecurityContextHolder.getContext().setAuthentication(authenticationToken);
		}
		chain.doFilter(request, response);
	}
}
