package university.Model;


import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import jakarta.persistence.Transient;
import lombok.*;

@Entity
@Data
@NoArgsConstructor
public class Semester {
	@Id @GeneratedValue(strategy=GenerationType.IDENTITY)
	private Integer id;

	private Integer semesterNum;

	private Integer year;

	public Semester(Integer semesterNum, Integer year) {
		this.semesterNum = semesterNum;
		this.year = year;
	}
}
