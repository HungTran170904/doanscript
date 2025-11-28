package university.Service;

import java.util.ArrayList;
import java.util.List;
import java.util.Optional;

import lombok.RequiredArgsConstructor;
import org.modelmapper.ModelMapper;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import jakarta.transaction.Transactional;
import university.DTO.SubjectDTO;
import university.DTO.SubjectRelationDTO;
import university.DTO.Converter.SubjectConverter;
import university.Exception.RequestException;
import university.Model.Course;
import university.Model.Subject;
import university.Model.SubjectRelation;
import university.Repository.SubjectRepo;

@Service
@Transactional
@RequiredArgsConstructor
public class SubjectService {
	private final SubjectRepo subjectRepo;
	private final SubjectConverter subjectConverter;

	public List<SubjectDTO> getAllSubjects(){
		List<Subject> subjects=subjectRepo.getAll();
		List<SubjectDTO> subjectDTOs=subjectConverter.convertToAllDependencies(subjects);
		return subjectDTOs;
	}

	@Transactional
	public SubjectDTO addSubject(SubjectDTO dto) {
		SubjectDTO subjectDTO=null;
		if(subjectRepo.existsBySubjectId(dto.getSubjectId()))
			throw new RequestException("The subject id "+dto.getSubjectId()+" has already existed");
		Subject s=subjectConverter.convertToSubject(dto);
		List<SubjectRelation> relations=new ArrayList();
		for(SubjectRelationDTO rsDTO: dto.getRelations()) {
			Integer preId=subjectRepo.getIdBySubjectId(rsDTO.getSubjectId());
			if(preId==null) throw new RequestException("preSubjectId "+rsDTO.getSubjectId()+" does not exists in the database");
			else {
				SubjectRelation rs=new SubjectRelation();
				rs.setCurrSubject(s);
				rs.setPreSubject(subjectRepo.getReferenceById(preId));
				rs.setType(rsDTO.getType());
				relations.add(rs);
			}
		}
		s.setRelations(relations);
		Subject saveSubject=subjectRepo.save(s);
		subjectDTO= subjectConverter.convertToAllDependency(saveSubject);
		return subjectDTO;
	}

	public void removeSubject(int subjectId) {
		Optional<Subject> s=subjectRepo.findById(subjectId);
		if(s.isEmpty()) throw new RequestException("Subject id"+subjectId+" not found!Please try again"); 
		subjectRepo.delete(s.get());
	}
}
