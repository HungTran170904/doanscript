package university.DTO.Converter;

import org.modelmapper.ModelMapper;
import org.modelmapper.PropertyMap;
import org.modelmapper.TypeMap;
import org.modelmapper.convention.MatchingStrategies;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import university.DTO.CourseDTO;
import university.DTO.SubjectDTO;
import university.Model.Course;
import university.Model.Subject;

@Configuration
public class ModelMapperConfig {
	@Bean
	public ModelMapper modelMapper() {
		// Tạo object và cấu hình
		ModelMapper modelMapper = new ModelMapper();
		modelMapper.getConfiguration().setMatchingStrategy(MatchingStrategies.STRICT);
		TypeMap<Subject,SubjectDTO> propertyMapper1 = modelMapper.createTypeMap(Subject.class, SubjectDTO.class);
	    propertyMapper1.addMappings(mapper -> mapper.skip(SubjectDTO::setRelations));
	    TypeMap<SubjectDTO,Subject> propertyMapper2 = modelMapper.createTypeMap(SubjectDTO.class, Subject.class);
	    propertyMapper2.addMappings(mapper -> mapper.skip(Subject::setRelations));
		return modelMapper;
	}
}
