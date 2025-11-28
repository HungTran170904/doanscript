package university.Service;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.LinkedList;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import java.util.TreeSet;


import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;

import jakarta.transaction.Transactional;
import university.DTO.StudentDTO;
import university.DTO.Converter.StudentConverter;
import university.Exception.DatabaseException;
import university.Exception.RequestException;
import university.Model.*;
import university.Repository.CourseRepo;
import university.Repository.RegistrationRepo;
import university.Repository.RoleRepo;
import university.Repository.StudentRepo;
import university.Repository.SubjectRepo;
import university.Repository.UserRepo;
import university.Security.CustomUserDetails;
import university.Util.InfoChecking;
import university.Util.OpeningRegPeriods;

@Service
@Transactional
@RequiredArgsConstructor
public class StudentService {
	private final CourseRepo courseRepo;
	private final SubjectRepo subjectRepo;
	private final RegistrationRepo regRepo;
	private final StudentRepo studentRepo;
	private final UserRepo userRepo;
	private final RoleRepo roleRepo;
	private final InfoChecking infoChecking;
	private final StudentConverter studentConverter;
	private final PasswordEncoder encoder;

	private List<Course> getUnenrolledCourses(List<Integer> courseIds,Map<String,String> result){
		List<Course> unenrolledCourses=new LinkedList();
		Map<Integer,List<Course>> unenrolledSubjects=new HashMap();
		List<Course> courses;
		Subject subject;
		for(Integer courseId: courseIds) {
			Optional<Course> oc=courseRepo.findById(courseId);
			if(oc.isEmpty()) throw new RequestException("Course id "+courseId+" not found");
			else {
				Course c=oc.get();
				courses=unenrolledSubjects.get(c.getSubject().getId());
				if(courses==null) {
					courses=new ArrayList();
					courses.add(c);
					unenrolledSubjects.put(c.getSubject().getId(), courses);
				}
				else courses.add(c);
			}
		}
		for(Map.Entry<Integer, List<Course>> p:unenrolledSubjects.entrySet()) {
			courses=p.getValue();
			subject=courses.get(0).getSubject();
			if(subject.getPracticeCreditNumber()==0) {
				if(courses.size()>1) {
					for(Course c: courses)
						result.put(c.getCourseId(),"You can only enroll one theory course for subject "+subject.getSubjectId());
				}
				else unenrolledCourses.add(courses.get(0));
			}
			else {
				if(courses.size()==2) {
					Course c1=courses.get(0);
					Course c2=courses.get(1);
					if(c1.getMainCourse()!=null&&c1.getMainCourse().getId()==c2.getId()) {
						unenrolledCourses.add(c1);
						continue;
					}
					else if(c2.getMainCourse()!=null&&c2.getMainCourse().getId()==c1.getId()) {
						unenrolledCourses.add(c2);
						continue;
					}
				}
				for(Course c: courses)
					result.put(c.getCourseId(),"You must enroll one theory course associated with one practice course for subject "+subject.getSubjectId());
			}
		}
		return unenrolledCourses;
	}
	
	private String checkByScheduleChild(Course c, Course c1) {
		if (c.getDayOfWeek() == c1.getDayOfWeek() && c.getBeginShift() <= c1.getEndShift()
				&& c.getEndShift() >= c1.getBeginShift())
			return "Course " + c.getCourseId() + " overlap the schedule with the course " + c1.getCourseId();
		return null;
	}

	private String checkBySchedule(Course c, Course c1) {
		String str=null;
		str=checkByScheduleChild(c,c1);
		if(str==null&&c.getMainCourse()!=null) {
			str=checkByScheduleChild(c.getMainCourse(),c1);
			if(str!=null&&c1.getMainCourse()!=null) {
				str=checkByScheduleChild(c,c1.getMainCourse());
				if(str!=null) str=checkByScheduleChild(c.getMainCourse(),c1.getMainCourse());
			}
		}
		return str;
	}

	private String checkByUnenrolledCourses(List<Course> unenrolledCourses,Course c) {
		String str=null;
		for(Course c1:unenrolledCourses) {
			if(c1.getId()!=c.getId()) {
				str=checkBySchedule(c, c1);
				if(str!=null) break;
			}
		}
		return str;
	}

	private String checkByEnrolledCourses(List<Course> enrolledCourses,Course c) {
		String str=null;
		for(Course c1: enrolledCourses) {
			if(c1.getId()==c.getId()) return "You have already enrolled the course "+c.getCourseId();
			str=checkBySchedule(c1,c);
			if(str!=null) break;
			if(c1.getSubject().getId()==c.getSubject().getId())
				return "You have already enrolled in subject "+c1.getSubject().getSubjectId();
		}
		return str;
	}

	private String checkByStudiedCourses(Set<Integer> studiedSubjectIds, Course c, Integer studentId) {
		List<SubjectRelation> relations=subjectRepo.getPreSRs(c.getSubject().getId());
		for(SubjectRelation sr: relations) {
			if(!studiedSubjectIds.contains(sr.getPreSubject().getId()))
				return "You need to learn subject "+sr.getPreSubject().getSubjectId()+" ahead"; 
			if(sr.getType()==1) {
				Boolean result=regRepo.getResult(studentId,c.getId());
				if(result==null) throw new DatabaseException("Result of registration( studentId:"+studentId+",courseId:"+c.getId()+") is null");
				else if(!result)
					return "You need to pass the subject "+sr.getPreSubject().getSubjectId()+" ahead";
			}
		}
		return null;
	}

	private String checkFull(Course c) {
		if(c.getRegisteredNumber()==c.getTotalNumber()) 
			return "The course "+c.getCourseId()+" is full now";
		Course mainCourse=c.getMainCourse();
		if(mainCourse!=null&&
			mainCourse.getRegisteredNumber()==mainCourse.getTotalNumber())
			return "The course "+c.getMainCourse().getCourseId()+" is full now";
		return null;
	}

	public int getStudentIdFromSecurityContext() {
		Authentication auth = SecurityContextHolder.getContext().getAuthentication();
		if(auth==null) throw new BadCredentialsException("You need to login before register courses!");
		UserDetails userDetails=(UserDetails) auth.getPrincipal();
		int userId= Integer.valueOf(userDetails.getUsername());
		return studentRepo.findStudentIdByUserId(userId);
	}

	public Map<String,String> enrollCourses(List<Integer> courseIds, RegistrationPeriod currRegPeriod){
		int studentId=getStudentIdFromSecurityContext();
		Map<String,String> result=new HashMap();
		List<Course> unenrolledCourses=getUnenrolledCourses(courseIds, result);
		if(unenrolledCourses.isEmpty()) return result;
		List<Course> enrolledCourses=courseRepo.findEnrolledCourses(currRegPeriod.getSemester(), studentId);
		Set<Integer> studiedSubjectIds=subjectRepo.getStudiedSubjectIds(currRegPeriod.getSemester(), studentId);
		String str;
		for(Course c: unenrolledCourses) {
			str=checkByUnenrolledCourses(unenrolledCourses,c);
			if(str==null) str=checkFull(c);
			if(str==null) str=checkByEnrolledCourses(enrolledCourses,c);
			if(str==null) str=checkByStudiedCourses(studiedSubjectIds,c, studentId);
			if(str!=null) {
				result.put(c.getCourseId(), str);
				if (c.getMainCourse() != null)
					result.put(c.getMainCourse().getCourseId(), str);
			}
			else {
				regRepo.addCourse(studentId,c.getId());
				if(c.getMainCourse()!=null) {
					regRepo.addCourse(studentId,c.getMainCourse().getId());
					result.put(c.getMainCourse().getCourseId(),"Enroll successfully");
				}
				result.put(c.getCourseId(),"Enroll successfully");
			}
		}
		return result;
	}

	public Map<String,String> unenrollCourses(List<Integer> courseIds, RegistrationPeriod currRegPeriod){
		int studentId=getStudentIdFromSecurityContext();
		Map<String,String> result=new HashMap();
		ArrayList<Course> courses=new ArrayList();
		for(Integer courseId: courseIds) {
			Course c=courseRepo.findEnrolledCourseById(studentId,courseId);
			if(c==null) throw new RequestException("CourseId "+courseId+" not found!");
			courses.add(c);
		}
		for(int i=0;i<courses.size();i++) {
			if(courses.get(i)==null) continue;
			if(courses.get(i).getSemester().getId()!=currRegPeriod.getSemester().getId()) {
				result.put(courses.get(i).getCourseId(),"Can not unenroll courses that were registered in previous semesters");
			}
			else if(courses.get(i).getSubject().getPracticeCreditNumber()>0) {
				int j=i+1;
				for (; j < courses.size(); j++) {
					if (courses.get(j).getSubject().getId() == courses.get(i).getSubject().getId()) {
						regRepo.removeCourse(studentId, courses.get(i).getId());
						regRepo.removeCourse(studentId, courses.get(j).getId());
						result.put(courses.get(i).getCourseId(),"Unenroll successfully");
						result.put(courses.get(j).getCourseId(),"Unenroll successfully");
						courses.set(j, null);
						break;
					}
				}
				if(j==courses.size()) result.put(courses.get(i).getCourseId(),"You need to unenroll both theory and practice courses for the subject "+courses.get(i).getSubject().getSubjectId()+" at the same time");
			}
			else {
				regRepo.removeCourse(studentId, courses.get(i).getId());
				result.put(courses.get(i).getCourseId(),"Unenroll successfully");
			}
		}
		return result;
	}

	public StudentDTO getStudentInfo() {
		Authentication auth = SecurityContextHolder.getContext().getAuthentication();
		if(auth==null) throw new BadCredentialsException("You need to login before register courses!");
		CustomUserDetails userDetails=(CustomUserDetails) auth.getPrincipal();
		Student s= studentRepo.findByUser(userDetails.getU()).orElseThrow(()->new RequestException("Student not found!Please try again"));
		return studentConverter.convertToStudentDTO(s);
	}

	public StudentDTO addStudent(StudentDTO dto) {
		if(dto.getUser()==null||dto.getUser().getEmail()==null||dto.getUser().getUserId()==null)
			throw new RequestException("UserId and Email fields are required");
		if(userRepo.existsByUserId(dto.getUser().getUserId()))
			throw new RequestException("UserId "+dto.getUser().getUserId()+" has already existed");
		if(userRepo.existsByEmail(dto.getUser().getEmail()))
			throw new RequestException("Email "+dto.getUser().getEmail()+" has already existed");
		if(!infoChecking.checkEmail(dto.getUser().getEmail())) 
			throw new RequestException("The email is invalid!");
		StudentDTO response=null;
		Student s=studentConverter.convertToStudent(dto);
		s.getUser().setRole(roleRepo.findByRoleName("STUDENT"));
		s.getUser().setPassword(encoder.encode(s.getUser().getPassword()));
		Student saveStudent=studentRepo.save(s);
		if(saveStudent!=null) response=studentConverter.convertToStudentDTO(saveStudent);
		return response;
	}

	public void removeStudent(Integer studentId) {
		Optional<Student> s=studentRepo.findById(studentId);
		if(s.isEmpty()) throw new RequestException("Student id"+studentId+" not found!Please try again"); 
		studentRepo.delete(s.get());
	}

	public List<StudentDTO> getAllStudents(){
		List<StudentDTO> dtos=new ArrayList();
		for(Student s: studentRepo.findAll()) {
			dtos.add(studentConverter.convertToStudentDTO(s));
		}
		return dtos;
	}
}
