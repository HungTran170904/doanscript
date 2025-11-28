package university.Repository;

import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;

import university.Model.Role;
import university.Model.Student;
import university.Model.User;

@Repository
public interface UserRepo extends JpaRepository<User,Integer> {
	Optional<User> findByEmail(String email);

	Optional<User> findByUserId(String UserId);

	Student findByName(String name);

	boolean existsByUserId(String userId);

	boolean existsByEmail(String email);

	boolean existsByRole(Role role);
}
