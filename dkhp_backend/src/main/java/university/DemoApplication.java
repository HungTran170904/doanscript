package university;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.ConfigurableApplicationContext;
import org.springframework.core.env.Environment;
import university.Service.SseService;


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
