package university.Model;

import jakarta.persistence.CascadeType;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.OneToOne;
import lombok.*;

@Entity
@Data
@NoArgsConstructor
public class Student {
	@Id @GeneratedValue(strategy=GenerationType.IDENTITY)
	private Integer id;

	private String falcutyName;

	private String program;

	private Integer khoaTuyen;

	@OneToOne(cascade=CascadeType.ALL)
	@JoinColumn(name="userId", nullable=false)
	private User user;
}
