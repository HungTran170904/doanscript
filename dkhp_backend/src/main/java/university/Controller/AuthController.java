package university.Controller;

import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import university.DTO.LoginDTO;
import university.Service.UserService;

@RestController
@RequestMapping("/api/auth")
@RequiredArgsConstructor
public class AuthController {
	private final UserService userService;

	@PostMapping("/login")
	public ResponseEntity<LoginDTO> login(
			@RequestParam("username") String username,
			@RequestParam("password") String password
			){
		return ResponseEntity.ok(userService.login(username, password));
	}

	@PostMapping("/changePassword")
	public ResponseEntity<HttpStatus> changePassword(
			@RequestParam("username") String username,
			@RequestParam("newPassword") String newPassword
			){
		userService.changePassword(username, newPassword);
		return new ResponseEntity(HttpStatus.OK);
	}
}
