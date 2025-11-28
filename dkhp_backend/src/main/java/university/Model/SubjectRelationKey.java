package university.Model;

import java.io.Serializable;

import jakarta.persistence.Embeddable;

@Embeddable
public class SubjectRelationKey implements Serializable{
	private Integer currSubjectId;

	private Integer preSubjectId;
}
