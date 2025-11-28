package university.Model;

import java.time.LocalDate;
import java.util.Set;

import jakarta.persistence.CascadeType;
import jakarta.persistence.EmbeddedId;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.MapsId;
import jakarta.persistence.Table;
import lombok.*;

@Entity
@NoArgsConstructor
@Data
public class SubjectRelation {
	@EmbeddedId
	private SubjectRelationKey id=new SubjectRelationKey();

	@ManyToOne
	@MapsId("currSubjectId")
	private Subject currSubject;

	@ManyToOne
	@MapsId("preSubjectId")
	private Subject preSubject;

	private Integer type; //1:prerequisite subject, 2: ahead subject
}
