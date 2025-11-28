package university.DTO.Converter;

import java.util.ArrayList;
import java.util.List;

import lombok.RequiredArgsConstructor;
import org.modelmapper.ModelMapper;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Component;

import university.DTO.SubjectDTO;
import university.DTO.SubjectRelationDTO;
import university.Model.Subject;
import university.Model.SubjectRelation;

@Component
@RequiredArgsConstructor
public class SubjectConverter {
	private final ModelMapper modelMapper;

	public List<SubjectRelationDTO> convertToSrDTOs(List<SubjectRelation> preSRs) {
		List<SubjectRelationDTO> rsDTOs=new ArrayList();
		for(SubjectRelation sr: preSRs) {
			SubjectRelationDTO dto=new SubjectRelationDTO();
			dto.setId(sr.getPreSubject().getId());
			dto.setSubjectId(sr.getPreSubject().getSubjectId());
			dto.setType(sr.getType());
			rsDTOs.add(dto);
		}
		return rsDTOs;
	}

	public SubjectDTO convertToDTO(Subject s) {
		SubjectDTO dto=new SubjectDTO();
		dto.setSubjectName(s.getSubjectName());
		dto.setTheoryCreditNumber(s.getTheoryCreditNumber());
		return dto;
	}

	public SubjectDTO convertToAllDependency(Subject s) {
		SubjectDTO dto=modelMapper.map(s,SubjectDTO.class);
		dto.setRelations(convertToSrDTOs(s.getRelations()));
		return dto;
	}

	public List<SubjectDTO> convertToAllDependencies(List<Subject> subjects) {
		List<SubjectDTO> dtos=new ArrayList();
		for(Subject s: subjects) dtos.add(convertToAllDependency(s));
		return dtos;
	}

	public Subject convertToSubject(SubjectDTO dto) {
		return modelMapper.map(dto,Subject.class);
	}
}
