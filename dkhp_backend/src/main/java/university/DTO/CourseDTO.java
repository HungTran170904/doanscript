package university.DTO;

import java.time.LocalDate;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;
import university.Model.Semester;
import university.Model.Subject;
@Data
public class CourseDTO {
	private Integer id;
	private String courseId;
	private LocalDate beginDate;
	private LocalDate endDate;
	private String language;
	private Integer beginShift;
	private Integer endShift;
	private Integer dayOfWeek;
	private Integer totalNumber;
	private Integer registeredNumber;
	private Integer weekDistance;
	private String room;
	private String lecturerName;
	private String mainCourseId=null;
	private Integer semesterId;
	private SubjectDTO subject;
}
