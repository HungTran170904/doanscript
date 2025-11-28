package university.DTO;

import java.util.List;
import java.util.Map;

import lombok.AllArgsConstructor;
import lombok.Data;

@Data
public class SubjectDTO {
	private Integer id;
	private String subjectId;
	private String subjectName;
	private Integer theoryCreditNumber;
	private Integer practiceCreditNumber;
	private List<SubjectRelationDTO> relations=null;
}
