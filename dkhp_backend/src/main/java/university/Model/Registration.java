package university.Model;

import java.time.LocalDate;

import jakarta.persistence.EmbeddedId;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinTable;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.MapsId;
import jakarta.persistence.Table;
import lombok.Data;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import lombok.ToString;

@Entity
@Data
@NoArgsConstructor
public class Registration {
	@EmbeddedId
	private RegistrationKey id;

	@ManyToOne(fetch=FetchType.LAZY)
	@MapsId("studentId")
	private Student student;

	@ManyToOne(fetch=FetchType.LAZY)
	@MapsId("courseId")
	private Course course;

	private Boolean result;
}
