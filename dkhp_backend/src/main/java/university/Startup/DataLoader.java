package university.Startup;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.CommandLineRunner;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;

import university.Model.Role;
import university.Model.User;
import university.Repository.RoleRepo;
import university.Repository.UserRepo;

@Component
public class DataLoader implements CommandLineRunner{
	@Autowired
	private RoleRepo roleRepo;
	@Autowired
	private UserRepo userRepo;
	@Autowired
	private PasswordEncoder encoder;
	@Override
	public void run(String... args) throws Exception {
		Role adminRole=roleRepo.findByRoleName("ADMIN");
		Role studentRole=roleRepo.findByRoleName("STUDENT");
		if(adminRole==null) {
			adminRole=new Role();
			adminRole.setRoleName("ADMIN");
			adminRole=roleRepo.save(adminRole);
		}
		if(studentRole==null) {
			studentRole=new Role();
			studentRole.setRoleName("STUDENT");
			studentRole=roleRepo.save(studentRole);
		}
		if(!userRepo.existsByRole(adminRole)) {
			var admin= User.builder()
					.email("admin@gmail.com")
					.password(encoder.encode("admin"))
					.name("admin")
					.userId("00000001")
					.role(adminRole).build();
			userRepo.save(admin);
		}
	}
}