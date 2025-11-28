package university.Service;

import java.util.List;

import lombok.RequiredArgsConstructor;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.stereotype.Service;

import jakarta.transaction.Transactional;
import university.DTO.CourseDTO;
import university.DTO.Converter.CourseConverter;
import university.Exception.RequestException;
import university.Model.*;
import university.Repository.*;
import university.Util.InfoChecking;

@Service
@Transactional
@RequiredArgsConstructor
public class CourseService {
	private final CourseRepo courseRepo;
	private final StudentRepo studentRepo;
	private final SubjectRepo subjectRepo;
	private final SemesterRepo semesterRepo;
	private final CourseConverter courseConverter;
	private final InfoChecking infoChecking;
	
	public int getStudentIdFromSecurityContext() {
		Authentication auth = SecurityContextHolder.getContext().getAuthentication();
		if(auth==null) throw new BadCredentialsException("You need to login before register courses!");
		UserDetails userDetails=(UserDetails) auth.getPrincipal();
		int userId= Integer.valueOf(userDetails.getUsername());
		return studentRepo.findStudentIdByUserId(userId);
	}

	public List<CourseDTO> getAllCourses(){
		return courseConverter.convertToDTO(courseRepo.findAll());
	}

	public List<CourseDTO> getOpenedCourses(RegistrationPeriod currRegPeriod){
		List<Course> courses=courseRepo.findOpenedCourses(currRegPeriod.getSemester());
		return courseConverter.convertToDTO(courses);
	}

	public List<Integer> getEnrolledCourses(RegistrationPeriod currRegPeriod){
		int studentId=getStudentIdFromSecurityContext();
		List<Integer> courseIds=courseRepo.findEnrolledCourseIds(currRegPeriod.getSemester(),studentId);
		return courseIds;
	}

	public List<CourseDTO> getStudiedCourses(int semesterId){
		int studentId=getStudentIdFromSecurityContext();
		List<Course> courses=courseRepo.findEnrolledCourses(semesterId,studentId);
			return courseConverter.convertToDTO(courses);
	}

	public CourseDTO addCourse(CourseDTO dto) {
		if(dto.getCourseId()==null) throw new RequestException("CourseId is required");
		if(courseRepo.existsByCourseId(dto.getCourseId()))
			throw new RequestException("The course id "+dto.getCourseId()+" has already existed");
		if(dto.getBeginDate()==null||dto.getEndDate()==null) throw new RequestException("BeginDate and EndDate are required");
		if(dto.getBeginDate().isAfter(dto.getEndDate())) throw new RequestException("BeginDate must be before EndDate");
		if(dto.getBeginShift()>=dto.getEndShift()) throw new RequestException("BeginShift must be smaller than EndShift");
		Course c=courseConverter.convertToCourse(dto);
		String subjectId=infoChecking.getSubjectId(c.getCourseId());
		Subject s=subjectRepo.findBySubjectId(subjectId).orElseThrow(()->new RequestException("SubjectId "+subjectId+" does not exists!"));
		c.setSubject(s);
		if(dto.getMainCourseId()!=null) {
			Course mainCourse=courseRepo.findByCourseId(dto.getMainCourseId()).orElseThrow(()->new RequestException("mainCourseId "+dto.getMainCourseId()+" does not exist"));
			if(mainCourse.getMainCourse()!=null) throw new RequestException("MainCourse "+mainCourse.getCourseId()+" is not a theory course");
			c.setMainCourse(mainCourse);
		}
		Semester se=semesterRepo.findById(dto.getSemesterId()).orElseThrow(()->new RequestException("SemesterId "+dto.getSemesterId()+" not found!"));
		c.setSemester(se);
		Course savedCourse=courseRepo.save(c);
		return courseConverter.convertToDTO(savedCourse);
	}

	public String removeCourse(Integer courseId) {
		var c=courseRepo.findById(courseId).orElseThrow(()->new RequestException("CourseId "+courseId+" does not exist!"));
		if(c.getMainCourse()==null&&courseRepo.existsByMainCourse(c))
			throw new RequestException("The course "+courseId+" has practice courses. Please delete them first");
		courseRepo.delete(c);
		return c.getCourseId();
	}
}
