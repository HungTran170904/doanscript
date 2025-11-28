package university;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.LinkedList;
import java.util.List;
import java.util.Optional;

import org.modelmapper.ModelMapper;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.ConfigurableApplicationContext;
import org.springframework.core.env.Environment;

import com.google.gson.Gson;

import io.jsonwebtoken.SignatureAlgorithm;
import io.jsonwebtoken.security.Keys;
import university.DTO.CourseDTO;
import university.DTO.SubjectDTO;
import university.DTO.UserDTO;
import university.DTO.Converter.CourseConverter;
import university.Model.Course;
import university.Model.Semester;
import university.Model.Student;
import university.Model.Subject;
import university.Model.User;
import university.Repository.CourseRepo;
import university.Repository.SemesterRepo;
import university.Repository.StudentRepo;
import university.Repository.SubjectRepo;
import university.Repository.UserRepo;
import university.Service.AdminService;
import university.Service.SseService;
import university.Service.StudentService;
import university.Util.OpeningRegPeriods;


@SpringBootApplication
public class DemoApplication {

	public static void main(String[] args) {
		ConfigurableApplicationContext context=SpringApplication.run(DemoApplication.class, args);
		Environment env=context.getBean(Environment.class);
		System.out.println("Sql string: "+env.getProperty("spring.datasource.url"));

		SseService sseService=context.getBean(SseService.class);
		sseService.startSendingEvents();
	}
}
