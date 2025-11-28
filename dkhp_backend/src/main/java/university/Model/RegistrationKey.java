package university.Model;

import jakarta.persistence.Embeddable;

@Embeddable
public class RegistrationKey {
	private Integer studentId;

	private Integer courseId;
}
