package com.zairo.factory.workforce;

import com.zairo.factory.auth.CurrentUser;
import com.zairo.factory.workforce.WorkerChangeDtos.ChangeRequestResponse;
import com.zairo.factory.workforce.WorkerChangeDtos.ChangeResponseRequest;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import java.util.List;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/** A customer decides what happens when the person they booked can't make it. */
@RestController
@Tag(name = "Workforce — booking")
@SecurityRequirement(name = "bearerAuth")
public class WorkerChangeController {

    private final WorkerChangeService changeService;

    public WorkerChangeController(WorkerChangeService changeService) {
        this.changeService = changeService;
    }

    @Operation(summary = "My appointments that need my decision", description = "Appointments whose person can't "
            + "make it and the business asked me to choose. Each lists the colleagues free at the same time and "
            + "other times with the same person; I can also cancel with a refund.")
    @ApiResponse(responseCode = "200", description = "The open requests (empty if none)")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @GetMapping("/api/v1/me/change-requests")
    public List<ChangeRequestResponse> list(HttpServletRequest request) {
        return changeService.list(CurrentUser.requireUserId(request));
    }

    @Operation(summary = "Decide: colleague, another time, or cancel", description = "REPLACE needs workerId, MOVE "
            + "needs slotId (both from the list); CANCEL refunds a paid booking. Each choice is re-checked against "
            + "what is still possible.")
    @ApiResponse(responseCode = "204", description = "Done")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", ref = "Forbidden")
    @ApiResponse(responseCode = "404", ref = "NotFound")
    @ApiResponse(responseCode = "409", description = "That choice is no longer possible.")
    @PostMapping("/api/v1/me/change-requests/{bookingId}/respond")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void respond(@PathVariable UUID bookingId, @Valid @RequestBody ChangeResponseRequest body,
            HttpServletRequest request) {
        changeService.respond(CurrentUser.requireUserId(request), bookingId, body);
    }
}
