package university.Repository;

import java.util.Optional;
import java.util.Set;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;

import jakarta.transaction.Transactional;
import university.DTO.StudentDTO;
import university.Model.Student;
import university.Model.User;

@Repository
public interface StudentRepo extends JpaRepository<Student, Integer>{
	Optional<Student> findByUser(User u);
	
	@Query(value="select id from student where user_id=?1", nativeQuery=true)
	int findStudentIdByUserId(int userId);
}
