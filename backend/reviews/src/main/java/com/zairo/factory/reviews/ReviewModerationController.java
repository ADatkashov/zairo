package com.zairo.factory.reviews;

import com.zairo.factory.platformadmin.PlatformAdminService;
import com.zairo.factory.platformadmin.AnyPlatformRole;
import com.zairo.factory.platformadmin.PlatformModerationCapable;
import com.zairo.factory.platformadmin.PlatformCurrentAdmin;
import com.zairo.factory.reviews.ReviewDtos.ModerationDecisionRequest;
import com.zairo.factory.reviews.ReviewDtos.ModerationReviewResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import java.util.UUID;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/**
 * Platform-side review moderation. Reads: any platform role. Decisions: PLATFORM_ADMIN or PLATFORM_MODERATOR — hiding
 * a review changes what every customer sees and how a business is ranked.
 */
@RestController
@RequestMapping("/api/v1/platform/reviews")
@Tag(name = "Platform Admin - Reviews")
public class ReviewModerationController {

    private final ReviewModerationService service;
    private final PlatformAdminService platformAdminService;

    public ReviewModerationController(ReviewModerationService service, PlatformAdminService platformAdminService) {
        this.service = service;
        this.platformAdminService = platformAdminService;
    }

    @Operation(summary = "Reported reviews", description = "`status` = OPEN (default, waiting for a decision), "
            + "HIDDEN or DISMISSED; newest report first.")
    @ApiResponse(responseCode = "200", description = "Page of reviews")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @SecurityRequirement(name = "bearerAuth")
    @GetMapping
    @AnyPlatformRole
    public Page<ModerationReviewResponse> queue(@RequestParam(defaultValue = "OPEN") String status,
            Pageable pageable, HttpServletRequest httpRequest) {
        PlatformCurrentAdmin.requireAdminId(httpRequest);
        return service.queue(status, pageable);
    }

    @Operation(summary = "Hide a review", description = "Takes it out of every average, ranking and public list; "
            + "closes its report. Reversible with /restore.")
    @ApiResponse(responseCode = "204", description = "Hidden (or already was)")
    @ApiResponse(responseCode = "403", description = "PLATFORM_SUPPORT is read-only")
    @ApiResponse(responseCode = "404", ref = "NotFound")
    @SecurityRequirement(name = "bearerAuth")
    @PostMapping("/{id}/hide")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @PlatformModerationCapable
    public void hide(@PathVariable UUID id, @Valid @RequestBody(required = false) ModerationDecisionRequest request,
            HttpServletRequest httpRequest) {
        service.hide(actorId(httpRequest), actorEmail(httpRequest), id, request == null ? null : request.reason());
    }

    @Operation(summary = "Restore a hidden review")
    @ApiResponse(responseCode = "204", description = "Visible again (or already was)")
    @ApiResponse(responseCode = "404", ref = "NotFound")
    @SecurityRequirement(name = "bearerAuth")
    @PostMapping("/{id}/restore")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @PlatformModerationCapable
    public void restore(@PathVariable UUID id, @Valid @RequestBody(required = false) ModerationDecisionRequest request,
            HttpServletRequest httpRequest) {
        service.restore(actorId(httpRequest), actorEmail(httpRequest), id, request == null ? null : request.reason());
    }

    @Operation(summary = "Keep a reported review", description = "Closes the open report; the review stays and "
            + "cannot be reported again. 409 when there is no open report.")
    @ApiResponse(responseCode = "204", description = "Report dismissed")
    @ApiResponse(responseCode = "404", ref = "NotFound")
    @ApiResponse(responseCode = "409", description = "Nothing to dismiss")
    @SecurityRequirement(name = "bearerAuth")
    @PostMapping("/{id}/dismiss")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @PlatformModerationCapable
    public void dismiss(@PathVariable UUID id, @Valid @RequestBody(required = false) ModerationDecisionRequest request,
            HttpServletRequest httpRequest) {
        service.dismiss(actorId(httpRequest), actorEmail(httpRequest), id, request == null ? null : request.reason());
    }

    private UUID actorId(HttpServletRequest httpRequest) {
        UUID adminId = PlatformCurrentAdmin.requireAdminId(httpRequest);
        return adminId;
    }

    private String actorEmail(HttpServletRequest httpRequest) {
        return platformAdminService.me(PlatformCurrentAdmin.requireAdminId(httpRequest)).email();
    }
}
