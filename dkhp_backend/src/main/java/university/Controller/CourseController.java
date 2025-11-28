package university.Controller;

import java.net.http.HttpResponse;
import java.time.Duration;
import java.time.LocalTime;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.http.codec.ServerSentEvent;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter.SseEventBuilder;


import university.DTO.CourseDTO;
import university.Model.Course;
import university.Service.CourseService;
import university.Service.SseService;
import university.Util.OpeningRegPeriods;

@RestController
@RequestMapping("/api/courses")
@RequiredArgsConstructor
public class CourseController {
	private final CourseService courseService;
	private final OpeningRegPeriods openingRegPeriods;
	private final SseService sseService;

	@GetMapping("/admin/all")
	public ResponseEntity<List<CourseDTO>> getAllCourses() {
		List<CourseDTO> courses=courseService.getAllCourses();
		return new ResponseEntity(courses, HttpStatus.OK);
	}

	@GetMapping("/openedCourses")
	public ResponseEntity<List<CourseDTO>> getOpenedCourses() {
		var currRegPeriod=openingRegPeriods.validateRegPeriod();
		List<CourseDTO> courses=courseService.getOpenedCourses(currRegPeriod);
		return new ResponseEntity(courses, HttpStatus.OK);
	}

	@GetMapping("/enrolledCourses")
	public ResponseEntity<List<Integer>> getEnrolledCourses() {
		var currRegPeriod=openingRegPeriods.validateRegPeriod();
		List<Integer> courseIds=courseService.getEnrolledCourses(currRegPeriod);
		return new ResponseEntity(courseIds, HttpStatus.OK);
	}

	@GetMapping("/studiedCourses")
	public ResponseEntity<List<CourseDTO>> getStudiedCourses(
			@RequestParam(value="semesterId") int semesterId,
			@RequestParam(value="studentId") int studentId){
		openingRegPeriods.validateRegPeriod();
		List<CourseDTO> courses=courseService.getStudiedCourses(semesterId);
		return new ResponseEntity(courses, HttpStatus.OK);
	}

	@PostMapping("/admin/addCourse")
	public ResponseEntity<CourseDTO> addCourse(
			@RequestBody CourseDTO dto){
		return ResponseEntity.ok(courseService.addCourse(dto));
	}

	@DeleteMapping("/admin/removeCourse/{id}")
	public ResponseEntity<String> removeCourse(
			@PathVariable("id") int id){
		return ResponseEntity.ok(courseService.removeCourse(id));
	}

	@GetMapping("/updateRegNumbers")
	public SseEmitter streamRegNumbers(){
		return sseService.addEmitter();
	}
}
