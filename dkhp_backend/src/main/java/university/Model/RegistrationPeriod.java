package university.Model;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;

import com.fasterxml.jackson.annotation.JsonFormat;

import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import lombok.Data;
import lombok.NoArgsConstructor;

@Entity
@Data
@NoArgsConstructor
public class RegistrationPeriod implements Comparable<RegistrationPeriod>{
	@Id @GeneratedValue(strategy=GenerationType.IDENTITY)
	private Integer id;

	@JsonFormat(pattern = "yyyy-MM-dd HH:mm:ss")
	private LocalDateTime openTime;

	@JsonFormat(pattern = "yyyy-MM-dd HH:mm:ss")
	private LocalDateTime closeTime;

	@ManyToOne
	@JoinColumn(name="semesterId")
	private Semester semester;

	@Override
	public int compareTo(RegistrationPeriod o) {
		if(this.getOpenTime().isBefore(o.getOpenTime())) return 1;
		else return -1;
	}
}
