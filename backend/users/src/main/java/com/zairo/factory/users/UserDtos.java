package com.zairo.factory.users;

import java.time.Instant;
import java.util.UUID;

public final class UserDtos {

    private UserDtos() {
    }

    public record CreateUserRequest(String email, String phone, String displayName, UserRole role) {
    }

    public record UserResponse(UUID id, String email, String phone, String displayName, UserRole role,
            Instant createdAt) {
        static UserResponse from(User user) {
            return new UserResponse(user.getId(), user.getEmail(), user.getPhone(), user.getDisplayName(),
                    user.getRole(), user.getCreatedAt());
        }
    }
}
