package university.Controller;

import java.util.List;
import java.util.Map;

import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;

import aj.org.objectweb.asm.Type;
import university.DTO.StudentDTO;
import university.Service.StudentService;
import university.Util.OpeningRegPeriods;

@RestController
@RequestMapping("/api/student")
@RequiredArgsConstructor
public class StudentController {
	private final StudentService studentService;
	private final OpeningRegPeriods openingRegPeriods;
	private final ObjectMapper objectMapper=new ObjectMapper();

	@PostMapping("/enrollCourse")
	public ResponseEntity<Map<String,String>> enrollCourses(
			@RequestParam("courseIds") String courseIdsJson) throws Exception{
		var currRegPeriod=openingRegPeriods.validateRegPeriod();
		List<Integer> courseIds = objectMapper.readValue(courseIdsJson, new TypeReference<List<Integer>>(){});
		return ResponseEntity.ok(studentService.enrollCourses(courseIds, currRegPeriod));
	}

	@PostMapping("/unenrollCourse")
	public ResponseEntity<Map<String,String>> unenrollCourses(
			@RequestParam("courseIds") String courseIdsJson) throws Exception{
		var currRegPeriod=openingRegPeriods.validateRegPeriod();
		List<Integer> courseIds = objectMapper.readValue(courseIdsJson, new TypeReference<List<Integer>>(){});
		return ResponseEntity.ok(studentService.unenrollCourses(courseIds,currRegPeriod));
	}

	@GetMapping("/studentInfo")
	public ResponseEntity<StudentDTO> getStudentInfo(){
		return ResponseEntity.ok(studentService.getStudentInfo());
	}

	@GetMapping("/admin/getAllStudents")
	public ResponseEntity<List<StudentDTO>> getAllStudents(){
		return ResponseEntity.ok(studentService.getAllStudents());
	}

	@PostMapping("/admin/addStudent")
	public ResponseEntity<StudentDTO> addStudent(
			@RequestBody StudentDTO dto){
		return ResponseEntity.ok(studentService.addStudent(dto));
	}

	@DeleteMapping("/admin/removeStudent/{id}")
	public ResponseEntity<HttpStatus> removeStudent(
			@PathVariable("id") int id){
		studentService.removeStudent(id);
		return new ResponseEntity(HttpStatus.OK);
	}
}
