package university.Repository;

import org.springframework.data.jpa.repository.JpaRepository;

import university.Model.Role;

public interface RoleRepo extends JpaRepository<Role,Integer>{
	public Role findByRoleName(String roleName);
}
