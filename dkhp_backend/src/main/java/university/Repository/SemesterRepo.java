package university.Repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import university.Model.Semester;

@Repository
public interface SemesterRepo extends JpaRepository<Semester, Integer> {
	
}
