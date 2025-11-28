package university.Controller;

import java.util.List;

import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import university.DTO.CourseDTO;
import university.DTO.StudentDTO;
import university.DTO.UserDTO;
import university.Model.RegistrationPeriod;
import university.Model.Semester;
import university.Service.AdminService;

@RestController
@RequestMapping("/api/admin")
@RequiredArgsConstructor
public class AdminController {
	private final AdminService adminService;

	@PostMapping("/addRegPeriod")
	public ResponseEntity<RegistrationPeriod> addRegPeriod(
			@RequestBody RegistrationPeriod regPeriod
			) {
		return ResponseEntity.ok(adminService.addRegPeriod(regPeriod));
	}

	@DeleteMapping("/removeRegPeriod/{id}")
	public ResponseEntity<HttpStatus> removeRegPeriod(
			@PathVariable("id") int id){
		adminService.removeRegPeriod(id);
		return new ResponseEntity(HttpStatus.OK);
	}

	@PutMapping("/updateRegPeriod")
	public ResponseEntity<RegistrationPeriod> updateRegPeriod(
			@RequestBody RegistrationPeriod regPeriod){
		return ResponseEntity.ok(adminService.updateRegPeriod(regPeriod));
	}

	@PostMapping("/addAdmin")
	public ResponseEntity<UserDTO> addAdmin(
			@RequestBody UserDTO dto){
		return ResponseEntity.ok(adminService.addAdmin(dto));
	}

	@GetMapping("/getAllRegperiods")
	public ResponseEntity<List<RegistrationPeriod>> getAllRegperiods(){
		return ResponseEntity.ok(adminService.getRegPeriods());
	}

	@GetMapping("/getLatestSemesters")
	public ResponseEntity<List<Semester>> getLatestSemesters(){
		return ResponseEntity.ok(adminService.getLatestSemesters());
	}

	@GetMapping("/getAllSemesters")
	public ResponseEntity<List<Semester>> getAllSemesters(){
		return ResponseEntity.ok(adminService.getAllSemesters());
	}

	@PostMapping("/addSemester")
	public ResponseEntity<Semester> addSemester(
			@RequestParam("semesterNum") int semesterNum,
			@RequestParam("year") int year){
		return ResponseEntity.ok(adminService.addSemester(semesterNum,year));
	}

	@DeleteMapping("/removeSemester/{id}")
	public ResponseEntity<HttpStatus> addSemester(
			@PathVariable("id") int id){
		adminService.removeSemester(id);
		return new ResponseEntity(HttpStatus.OK);
	}
}
