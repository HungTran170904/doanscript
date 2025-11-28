package university.Repository;

import java.util.HashSet;
import java.util.List;
import java.util.Optional;
import java.util.Set;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;

import jakarta.transaction.Transactional;
import university.Model.Semester;
import university.Model.Student;
import university.Model.Subject;
import university.Model.SubjectRelation;
@Repository
public interface SubjectRepo extends JpaRepository<Subject,Integer> {
	@Query("select s from Subject s left join fetch s.relations")
	List<Subject> getAll();
	
	@Query("select sr from SubjectRelation sr where sr.currSubject.id=?1")
	List<SubjectRelation> getPreSRs(int subjectId);
	
	@Query(value="insert into subject_relation(pre_subject_id, curr_subject_id, type) values(?1,?2,?3)", nativeQuery=true)
	@Modifying
    @Transactional
	void savePreSR(Integer preSubjectId, Integer currSubjectId, Integer type);
	
	@Query("select s.id from Subject s where s.subjectId=?1")
	Integer getIdBySubjectId(String subjectId);
	
	Optional<Subject> findBySubjectId(String subjectId);
	
	@Query(value="select c.subject.id from Course c where c.mainCourse=null and c.semester!=?1 and c IN( select reg.course from Registration reg where reg.student.id=?2)")
	Set<Integer> getStudiedSubjectIds(Semester semester,int studentId);
	
	@Query(value="select c.subject.id from Course c where c.mainCourse=null and c.semester.id=?1 and c IN( select reg.course from Registration reg where reg.student.id=?2)")
	Set<Integer> getEnrolledSubjectIds(int semesterId,int studentId);
	
	boolean existsBySubjectId(String subjectId);
	
	@Query("delete from SubjectRelation sr where sr.currSubject=?1")
	@Modifying
    @Transactional
	void deletePreSRs(Subject s);
}
