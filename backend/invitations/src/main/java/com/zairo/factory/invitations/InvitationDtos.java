package com.zairo.factory.invitations;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import java.time.Instant;
import java.util.UUID;

public final class InvitationDtos {

    private InvitationDtos() {
    }

    public record CreateInvitationRequest(
            @NotBlank @Size(max = 32) @Schema(description = "Phone of the person to invite, in any common format.",
                    example = "+77001234567") String phone) {
    }

    public record InvitationResponse(
            @Schema(example = "550e8400-e29b-41d4-a716-446655440000") UUID id,
            @Schema(example = "550e8400-e29b-41d4-a716-446655440000") UUID providerId,
            @Schema(description = "Normalized E.164.", example = "+77001234567") String phone,
            InvitationKind kind,
            InvitationStatus status,
            Instant createdAt) {
        static InvitationResponse from(StaffInvitation invitation) {
            return new InvitationResponse(invitation.getId(), invitation.getProviderId(), invitation.getPhone(),
                    invitation.getKind(), invitation.getStatus(), invitation.getCreatedAt());
        }
    }
}
