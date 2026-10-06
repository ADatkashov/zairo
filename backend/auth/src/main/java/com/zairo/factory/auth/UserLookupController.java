package com.zairo.factory.auth;

import com.zairo.factory.users.User;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.servlet.http.HttpServletRequest;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;

/**
 * Finds a registered person by phone for the "add a master / mechanic / cleaner / staff member" flows. Lives in
 * auth because a phone is matched through the verified phone identity (normalized E.164), not the display-only
 * {@code User.phone} column.
 */
@RestController
@Tag(name = "Users")
public class UserLookupController {

    private final PhoneNumberNormalizer phoneNumberNormalizer;
    private final IdentityLookupService identityLookupService;

    UserLookupController(PhoneNumberNormalizer phoneNumberNormalizer, IdentityLookupService identityLookupService) {
        this.phoneNumberNormalizer = phoneNumberNormalizer;
        this.identityLookupService = identityLookupService;
    }

    public record UserLookupResponse(
            @Schema(example = "550e8400-e29b-41d4-a716-446655440000") UUID id,
            @Schema(example = "Aigerim Bekova") String displayName,
            @Schema(example = "http://localhost:8080/api/v1/uploads/a1b2c3d4.jpg") String avatarUrl) {
        static UserLookupResponse from(User user) {
            return new UserLookupResponse(user.getId(), user.getDisplayName(), user.getAvatarUrl());
        }
    }

    @Operation(summary = "Find a registered user by phone number", description = "For picking an existing "
            + "person (e.g. adding a master to a business). Any signed-in user may call it, but it only ever "
            + "answers a match on a verified phone and returns just the id, display name and avatar — never "
            + "email, phone or role. The phone may be typed in any common format.")
    @ApiResponse(responseCode = "200", description = "The matching user")
    @ApiResponse(responseCode = "400", description = "Not a valid phone number.")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "404", ref = "NotFound", description = "Nobody is registered with this phone.")
    @SecurityRequirement(name = "bearerAuth")
    @GetMapping("/api/v1/users/lookup")
    public UserLookupResponse lookupByPhone(
            @Parameter(description = "Phone number.", example = "+77001234567") @RequestParam String phone,
            HttpServletRequest httpRequest) {
        CurrentUser.requireUserId(httpRequest);
        String normalized = phoneNumberNormalizer.normalize(phone);
        return identityLookupService.findExisting(IdentityProvider.PHONE, normalized)
                .filter(user -> !user.isDeleted())
                .map(UserLookupResponse::from)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "User not found"));
    }
}
