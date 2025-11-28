package university.DTO.Converter;

import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Component;

import university.DTO.StudentDTO;
import university.Model.Student;

@Component
@RequiredArgsConstructor
public class StudentConverter {
	private final UserConverter userConverter;

	public StudentDTO convertToStudentDTO(Student s) {
		StudentDTO dto=new StudentDTO();
		dto.setId(s.getId());
		dto.setFalcutyName(s.getFalcutyName());
		dto.setProgram(s.getProgram());
		dto.setKhoaTuyen(s.getKhoaTuyen());
		dto.setUser(userConverter.convertToUserDTO(s.getUser()));
		return dto;
	}

	public Student convertToStudent(StudentDTO dto) {
		Student s=new Student();
		s.setFalcutyName(dto.getFalcutyName());
		s.setProgram(dto.getProgram());
		s.setKhoaTuyen(dto.getKhoaTuyen());
		s.setUser(userConverter.convertToUser(dto.getUser()));
		return s;
	}
}
