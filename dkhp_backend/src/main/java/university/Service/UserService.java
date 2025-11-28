package university.Service;

import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;

import university.DTO.LoginDTO;
import university.Model.User;
import university.Repository.UserRepo;
import university.Security.CustomUserDetails;
import university.Security.JwtProvider;
import university.Util.InfoChecking;

@Service
@RequiredArgsConstructor
public class UserService {
	private final JwtProvider jwtProvider;
	private final UserRepo userRepo;
	private final AuthenticationManager authManager;
	private final InfoChecking infoChecking;
	private final PasswordEncoder encoder;

	public LoginDTO login(String username, String password) {
		Authentication authentication = authManager.authenticate(
				new UsernamePasswordAuthenticationToken(username,password));
		SecurityContextHolder.getContext().setAuthentication(authentication);
		String token=jwtProvider.generateToken(authentication);
		CustomUserDetails userDetails=(CustomUserDetails) authentication.getPrincipal();
		LoginDTO dto=new LoginDTO();
		dto.setToken(token);
		dto.setRole(userDetails.getU().getRole().getRoleName());
		return dto;
	}

	public void changePassword(String username, String newPassword) {
		User u;
		int type=infoChecking.checkUsernameType(username);
		if(type==1) u=userRepo.findByUserId(username).orElseThrow(()->new BadCredentialsException("UserId you specified does not exists!"));
		else if(type==2) u=userRepo.findByEmail(username).orElseThrow(()->new BadCredentialsException("Email you specified does not exists!"));
		else throw new BadCredentialsException("Unable to validate the email/userId you entered");
		u.setPassword(encoder.encode(newPassword));
		userRepo.save(u);
	}
}
