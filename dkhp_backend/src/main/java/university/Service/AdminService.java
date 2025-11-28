package university.Service;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;

import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;

import university.DTO.StudentDTO;
import university.DTO.UserDTO;
import university.DTO.Converter.UserConverter;
import university.Exception.RequestException;
import university.Model.Course;
import university.Model.RegistrationPeriod;
import university.Model.Semester;
import university.Model.User;
import university.Repository.RegistrationPeriodRepo;
import university.Repository.RoleRepo;
import university.Repository.SemesterRepo;
import university.Repository.StudentRepo;
import university.Repository.UserRepo;
import university.Util.OpeningRegPeriods;

@Service
@RequiredArgsConstructor
public class AdminService {
	private final SemesterRepo semesterRepo;
	private final UserRepo userRepo;
	private final RoleRepo roleRepo;
	private final UserConverter userConverter;
	private final RegistrationPeriodRepo regPeriodRepo;
	private final PasswordEncoder encoder;

	public RegistrationPeriod addRegPeriod(RegistrationPeriod dto) {
		Optional<Semester> semester=semesterRepo.findById(dto.getSemester().getId());
		if(semester.isEmpty()) throw new RequestException("SemesterId "+dto.getSemester().getId()+" does not exist");
		var openTime=dto.getOpenTime();
		var closeTime=dto.getCloseTime();
		if(openTime.isAfter(closeTime)) throw new RequestException("OpenTime must be before closeTime");
		LocalDateTime now=LocalDateTime.now();
		if(openTime.isBefore(now)) throw new RequestException("The openTime must be after the current time");
		for(RegistrationPeriod regPeriod: regPeriodRepo.findAll()) {
			if(regPeriod.getOpenTime().isBefore(closeTime)&&
					regPeriod.getCloseTime().isAfter(openTime))
				throw new RequestException("The added Registration Period is overlaped the schedule with "+regPeriod);
		}
		RegistrationPeriod regPeriod=new RegistrationPeriod();
		regPeriod.setSemester(semester.get());
		regPeriod.setOpenTime(openTime);
		regPeriod.setCloseTime(closeTime);
		RegistrationPeriod savedRegPeriod=regPeriodRepo.save(regPeriod);
		return savedRegPeriod;
	}

	public void removeRegPeriod(int regPeriodId) {
		RegistrationPeriod regPeriod=regPeriodRepo.findById(regPeriodId)
				.orElseThrow(()->new RequestException("RegPeriodId "+regPeriodId+" does not exist"));
		regPeriodRepo.delete(regPeriod);
	}

	public RegistrationPeriod updateRegPeriod(RegistrationPeriod dto) {
		if(dto==null||dto.getOpenTime()==null||dto.getCloseTime()==null||dto.getSemester()==null)
			throw new RequestException("All attributes of updatedRegPeriod are required");
		if(dto.getCloseTime().isBefore(LocalDateTime.now()))
			throw new RequestException("CloseTime must be before current time");
		RegistrationPeriod regPeriod=regPeriodRepo.findById(dto.getId())
				.orElseThrow(()->new RequestException("RegPeriodId "+dto.getId()+" does not exist in database!"));
		Semester se=semesterRepo.findById(dto.getSemester().getId())
				.orElseThrow(()->new RequestException("The updated semesterId does not exist in database"));

		regPeriod.setOpenTime(dto.getOpenTime());
		regPeriod.setCloseTime(dto.getCloseTime());
		regPeriod.setSemester(dto.getSemester());
		RegistrationPeriod savedRegPeriod= regPeriodRepo.save(regPeriod);
		return savedRegPeriod;
	}

	public List<RegistrationPeriod> getRegPeriods(){
		return regPeriodRepo.getAllRegPeriods();
	}
	public UserDTO addAdmin(UserDTO dto) {
		UserDTO response=null;
		if(userRepo.existsByUserId(dto.getUserId()))
			throw new RequestException("UserId "+dto.getUserId()+" has already existed");
		if(userRepo.existsByEmail(dto.getEmail()))
			throw new RequestException("Email "+dto.getEmail()+" has already existed");
		User admin=userConverter.convertToUser(dto);
		admin.setRole(roleRepo.findByRoleName("ADMIN"));
		admin.setPassword(encoder.encode(admin.getPassword()));
		User saveAdmin=userRepo.save(admin);
		if(saveAdmin!=null) response=userConverter.convertToUserDTO(saveAdmin);
		return response;
	}

	public Semester addSemester(int semesterNum, int year) {
		Semester semester=new Semester();
		if(semesterNum<1||semesterNum>3) throw new RequestException("Semester number must be between 1 and 3");
		semester.setSemesterNum(semesterNum);
		semester.setYear(year);
		Semester saveSemester=semesterRepo.save(semester);
		return saveSemester;
	}

	public void removeSemester(int semesterId) {
		Optional<Semester> se=semesterRepo.findById(semesterId);
		if(se.isEmpty()) throw new RequestException("Semester id"+semesterId+" not found!Please try again"); 
		semesterRepo.deleteById(semesterId);
	}

	public List<Semester> getLatestSemesters() {
		List<Semester> semesters= new ArrayList();
		LocalDate now=LocalDate.now();
		for(Semester se:semesterRepo.findAll()) {
			if(se.getYear()>=now.getYear()) semesters.add(se);
		}
		return semesters;
	}

	public List<Semester> getAllSemesters() {
		return semesterRepo.findAll();
	}
}
