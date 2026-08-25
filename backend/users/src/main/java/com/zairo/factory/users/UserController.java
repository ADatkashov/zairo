package com.zairo.factory.users;

import com.zairo.factory.users.UserDtos.CreateUserRequest;
import com.zairo.factory.users.UserDtos.UserResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
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
@Tag(name = "Users")
public class UserController {

    /**
     * Mirrors {@code com.zairo.factory.auth.JwtAuthFilter.ROLE_ATTRIBUTE} —
     * duplicated by name rather than depending on the {@code auth} module,
     * since {@code auth} already depends on {@code users} (for
     * {@link UserRole}) and a {@code users -> auth} dependency would be a
     * Gradle cycle. Same cross-module-boundary trick as the OpenAPI
     * {@code $ref}-by-string workaround elsewhere in this codebase.
     */
    private static final String ROLE_REQUEST_ATTRIBUTE = "auth.role";

    private final UserRepository userRepository;

    public UserController(UserRepository userRepository) {
        this.userRepository = userRepository;
    }

    @Operation(summary = "Create a bare user record (no login credentials)", description = """
            Low-level: inserts a User row directly, with no Credential — a user created this way \
            **cannot log in** (AuthService.login requires a matching Credential row, which only \
            /auth/register creates). Admin-only. Prefer POST /auth/register for any real account \
            creation; this exists for lower-level/internal use (e.g. seeding data) rather than \
            end-user signup.""")
    @ApiResponse(responseCode = "201", description = "User record created")
    @ApiResponse(responseCode = "400", ref = "BadRequest")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", description = "The caller is authenticated but isn't ADMIN.")
    @SecurityRequirement(name = "bearerAuth")
    @PostMapping("/api/v1/users")
    @ResponseStatus(HttpStatus.CREATED)
    public UserResponse create(@Valid @RequestBody CreateUserRequest request, HttpServletRequest httpRequest) {
        requireAdmin(httpRequest);
        User user = new User(UUID.randomUUID(), request.email(), request.phone(), request.displayName(),
                request.role(), Instant.now());
        return UserResponse.from(userRepository.save(user));
    }

    @Operation(summary = "List every user", description = "Unfiltered, unpaginated — every user record in the "
            + "system. Admin-only.")
    @ApiResponse(responseCode = "200", description = "All users")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", description = "The caller is authenticated but isn't ADMIN.")
    @SecurityRequirement(name = "bearerAuth")
    @GetMapping("/api/v1/users")
    public List<UserResponse> list(HttpServletRequest httpRequest) {
        requireAdmin(httpRequest);
        return userRepository.findAll().stream().map(UserResponse::from).toList();
    }

    @Operation(summary = "Get a user by id")
    @ApiResponse(responseCode = "200", description = "The user")
    @ApiResponse(responseCode = "404", ref = "NotFound")
    @GetMapping("/api/v1/users/{id}")
    public UserResponse getById(@Parameter(description = "The user's id.") @PathVariable UUID id) {
        return userRepository.findById(id).map(UserResponse::from)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "User not found: " + id));
    }

    private static void requireAdmin(HttpServletRequest httpRequest) {
        Object role = httpRequest.getAttribute(ROLE_REQUEST_ATTRIBUTE);
        if (!(role instanceof String)) {
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Missing or invalid access token");
        }
        if (!UserRole.ADMIN.name().equals(role)) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Admin role required");
        }
    }
}
