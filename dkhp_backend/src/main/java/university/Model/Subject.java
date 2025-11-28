package university.Model;

import java.util.List;

import jakarta.persistence.CascadeType;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.OneToMany;
import lombok.*;

@Entity
@Data
@NoArgsConstructor
public class Subject {
	@Id @GeneratedValue(strategy=GenerationType.IDENTITY)
	private Integer id;

	private String subjectId;

	private String subjectName;

	private Integer theoryCreditNumber;

	private Integer practiceCreditNumber;

	@OneToMany(mappedBy="subject",cascade = CascadeType.ALL,fetch=FetchType.LAZY)
	List<Course> courses;

	@OneToMany(mappedBy="currSubject",cascade = CascadeType.ALL, fetch=FetchType.LAZY)
	List<SubjectRelation> relations;

	public Subject(String subjectName, Integer theoryCreditNumber, Integer practiceCreditNumber) {
		this.subjectName = subjectName;
		this.theoryCreditNumber = theoryCreditNumber;
		this.practiceCreditNumber = practiceCreditNumber;
	}
}
