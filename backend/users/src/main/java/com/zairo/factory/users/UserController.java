package com.zairo.factory.users;

import com.zairo.factory.users.UserDtos.CreateUserRequest;
import com.zairo.factory.users.UserDtos.UserResponse;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;

@RestController
public class UserController {

    private final UserRepository userRepository;

    public UserController(UserRepository userRepository) {
        this.userRepository = userRepository;
    }

    @PostMapping("/api/v1/users")
    @ResponseStatus(HttpStatus.CREATED)
    public UserResponse create(@RequestBody CreateUserRequest request) {
        User user = new User(UUID.randomUUID(), request.email(), request.phone(), request.displayName(),
                request.role(), Instant.now());
        return UserResponse.from(userRepository.save(user));
    }

    @GetMapping("/api/v1/users")
    public List<UserResponse> list() {
        return userRepository.findAll().stream().map(UserResponse::from).toList();
    }

    @GetMapping("/api/v1/users/{id}")
    public UserResponse getById(@PathVariable UUID id) {
        return userRepository.findById(id).map(UserResponse::from)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "User not found: " + id));
    }
}
