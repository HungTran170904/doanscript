package university.Util;

import java.util.regex.Pattern;

import org.springframework.stereotype.Component;
import university.Exception.RequestException;

@Component
public class InfoChecking {
	public int checkUsernameType(String username) {
		if(Pattern.matches("^\\d{8}$", username)) return 1;
		else if(Pattern.matches("^[\\w-_\\.+]*[\\w-_\\.]\\@([\\w]+\\.)+[\\w]+[\\w]$", username)) return 2;
		else return 0;
	}
	public String getSubjectId(String courseId) {
		String subjectId=courseId.substring(0,courseId.indexOf("."));
		String courseSection=courseId.substring(courseId.indexOf(".") + 1);
		if(!Pattern.matches("^O\\d+(\\.\\d+)?$", courseSection))
			throw new RequestException("The courseId must be in format '<subjectId>.O<number>[.<number>]'");
		return subjectId;
	}
	public boolean checkEmail(String email) {
		return Pattern.matches("^[\\w-_\\.+]*[\\w-_\\.]\\@([\\w]+\\.)+[\\w]+[\\w]$",email);
	}
}
