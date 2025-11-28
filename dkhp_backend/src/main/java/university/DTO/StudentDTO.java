package university.DTO;

import lombok.AllArgsConstructor;
import lombok.Data;

@Data
public class StudentDTO {
	private Integer id;
	private String falcutyName;
	private String program;
	private Integer khoaTuyen;
	private UserDTO user;
}
