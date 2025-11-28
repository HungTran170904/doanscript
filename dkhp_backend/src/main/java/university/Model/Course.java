package university.Model;

import java.time.LocalDate;
import java.util.List;

import com.fasterxml.jackson.annotation.JsonFormat;

import jakarta.persistence.CascadeType;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.OneToMany;
import lombok.Data;
import lombok.NoArgsConstructor;

@Entity
@Data
@NoArgsConstructor
public class Course {
	@Id @GeneratedValue(strategy=GenerationType.IDENTITY)
	private Integer id;

	@Column(unique=true)
	private String courseId;

	@JsonFormat(pattern = "dd/MM/yyyy")
	private LocalDate beginDate;

	@JsonFormat(pattern = "dd/MM/yyyy")
	private LocalDate endDate;

	private String language;

	private Integer beginShift;

	private Integer endShift;

	private Integer dayOfWeek;

	private Integer totalNumber;

	private Integer registeredNumber=0;

	private Integer weekDistance;

	@ManyToOne(fetch=FetchType.LAZY)
	private Semester semester;

	private String room;

	private String lecturerName;

	@ManyToOne
	@JoinColumn(name="subjectId")
	private Subject subject;

	@ManyToOne
	@JoinColumn(name="mainCourseId")
	private Course mainCourse;

	@OneToMany(mappedBy = "course", cascade = CascadeType.ALL, fetch = FetchType.LAZY)
	List<Registration> registrations;

	public Course(String courseId, Integer beginShift,Integer endShift,
			Integer dayOfWeek, Integer totalNumber,Semester semester,Subject subject) {
		this.courseId = courseId;
		this.beginShift=beginShift;
		this.endShift=endShift;
		this.dayOfWeek = dayOfWeek;
		this.totalNumber = totalNumber;
		this.semester=semester;
		this.subject = subject;
	}
}
