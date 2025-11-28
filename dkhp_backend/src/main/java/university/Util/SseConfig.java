package university.Util;

import java.util.HashSet;
import java.util.Set;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

@Configuration
public class SseConfig {
	@Bean
	public ExecutorService sseExecutor() {
		return Executors.newSingleThreadExecutor();
	}
	@Bean
	public Set<SseEmitter> sseEmmitors() {
		return new HashSet<SseEmitter>();
	}
}
