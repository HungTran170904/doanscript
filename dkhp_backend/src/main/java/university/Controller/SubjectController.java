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
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import university.DTO.SubjectDTO;
import university.Model.Subject;
import university.Service.SubjectService;

@RestController
@RequestMapping("/api/subject/admin")
@RequiredArgsConstructor
public class SubjectController {
	private final SubjectService subjectService;

	@GetMapping("/getAllSubjects")
	public ResponseEntity<List<SubjectDTO>> getAllSubject() {
		return ResponseEntity.ok(subjectService.getAllSubjects());
	}

	@PostMapping("/addSubject")
	public ResponseEntity<SubjectDTO> addSubject(
			@RequestBody SubjectDTO dto) {
		return ResponseEntity.ok(subjectService.addSubject(dto));
	}

	@DeleteMapping("/removeSubject/{id}")
	public ResponseEntity<HttpStatus> removeSubject(
			@PathVariable("id") int id){
		subjectService.removeSubject(id);
		return new ResponseEntity(HttpStatus.OK);
	}
}
