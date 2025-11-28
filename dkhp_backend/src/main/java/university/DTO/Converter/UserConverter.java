package university.DTO.Converter;

import lombok.RequiredArgsConstructor;
import org.modelmapper.ModelMapper;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Component;

import university.DTO.UserDTO;
import university.Model.User;

@Component
@RequiredArgsConstructor
public class UserConverter {
	private final ModelMapper modelMapper;

	public UserDTO convertToUserDTO(User u) {
		UserDTO dto=new UserDTO();
		dto.setUserId(u.getUserId());
		dto.setEmail(u.getEmail());
		dto.setName(u.getName());
		return dto;
	}

	public User convertToUser(UserDTO dto) {
		return modelMapper.map(dto, User.class);
	}
}
