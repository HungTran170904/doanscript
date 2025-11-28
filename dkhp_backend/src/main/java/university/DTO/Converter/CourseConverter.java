package university.DTO.Converter;

import java.util.ArrayList;
import java.util.List;

import lombok.RequiredArgsConstructor;
import org.modelmapper.ModelMapper;
import org.springframework.stereotype.Component;

import university.DTO.CourseDTO;
import university.Model.Course;

@Component
@RequiredArgsConstructor
public class CourseConverter {
	private final ModelMapper modelMapper;
	private final SubjectConverter subjectConverter;

	public CourseDTO convertToDTO(Course c) {
		CourseDTO dto=modelMapper.map(c,CourseDTO.class);
		dto.setSubject(subjectConverter.convertToDTO(c.getSubject()));
		if(c.getMainCourse()!=null) dto.setMainCourseId(c.getMainCourse().getCourseId());
		return dto;
	}

	public List<CourseDTO> convertToDTO(List<Course> courses) {
		List<CourseDTO> dtos=new ArrayList();
		for(Course c:courses) dtos.add(convertToDTO(c));
		return dtos;
	}

	public Course convertToCourse(CourseDTO dto) {
		Course c=modelMapper.map(dto,Course.class); 
		c.setRegisteredNumber(0);
		return c;
	}
}
