package com.zairo.factory.search;

import com.zairo.factory.auth.CurrentUser;
import com.zairo.factory.search.BookAgainDtos.BookAgainSuggestion;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.servlet.http.HttpServletRequest;
import java.util.List;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;

@RestController
@Tag(name = "Search")
public class BookAgainController {

    private final BookAgainService bookAgainService;

    public BookAgainController(BookAgainService bookAgainService) {
        this.bookAgainService = bookAgainService;
    }

    @Operation(summary = "\"Repeat your last appointment\" suggestions", description = """
            Self-service only: the caller must be the exact user named by `userId`. One suggestion per \
            distinct service the customer has a COMPLETED booking for, newest visit first, capped at 5. \
            Empty if they have no completed bookings yet.""")
    @ApiResponse(responseCode = "200", description = "Suggestions, newest visit first (empty if none)")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", ref = "Forbidden")
    @SecurityRequirement(name = "bearerAuth")
    @GetMapping("/api/v1/users/{userId}/book-again")
    public List<BookAgainSuggestion> bookAgain(@Parameter(description = "The user's id.") @PathVariable UUID userId,
            HttpServletRequest httpRequest) {
        UUID callerId = CurrentUser.requireUserId(httpRequest);
        if (!callerId.equals(userId)) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Cannot view another user's suggestions");
        }
        return bookAgainService.suggestionsForUser(userId);
    }
}
