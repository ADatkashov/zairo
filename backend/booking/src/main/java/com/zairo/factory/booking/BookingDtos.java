package com.zairo.factory.booking;

import com.zairo.factory.depositpolicy.DepositType;
import com.zairo.factory.depositpolicy.DepositValueType;
import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotNull;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

public final class BookingDtos {

    private BookingDtos() {
    }

    // totalPrice non-negative mirrors Money's own requireNonNegative check
    // (an uncaught IllegalArgumentException -> undocumented 500 without
    // this — see ServiceOfferingDtos for the same pattern). Kept @NotNull
    // for backward compatibility with every existing client, which always
    // sends it — but BookingService.createBooking ignores its value: the
    // stored price/currency always come from the service's own
    // ServiceOffering, never from this field (see BookingService's own
    // doc comment — this used to be a price-tampering hole).
    public record CreateBookingRequest(
            @NotNull @Schema(example = "550e8400-e29b-41d4-a716-446655440000") UUID userId,
            @NotNull @Schema(example = "550e8400-e29b-41d4-a716-446655440000") UUID serviceId,
            @NotNull @Schema(description = "Must currently be OPEN — claimed atomically on booking creation, "
                    + "so a race against another customer booking the same slot resolves to a 409 for "
                    + "whoever loses it.", example = "550e8400-e29b-41d4-a716-446655440000") UUID availabilitySlotId,
            @NotNull @DecimalMin("0") @Schema(description = "Ignored — kept for backward compatibility only. "
                    + "The booking's real price always comes from the service's own current price, never from "
                    + "this field.", example = "25.00") BigDecimal totalPrice) {
    }

    // Not @NotNull on purpose: every existing client (and test) calls
    // POST /bookings/{id}/cancel with no body at all — making this
    // mandatory now would break all of them for a policy decision (should
    // cancellation require a reason?) this codebase hasn't made yet. The
    // field exists so a client that HAS one can send it; enforcing it is
    // a deliberate follow-up, not an oversight.
    public record CancelBookingRequest(
            @Schema(description = "Optional — why the customer is cancelling.", example = "Change of plans")
            String reason) {
    }

    public record BookingResponse(
            @Schema(example = "550e8400-e29b-41d4-a716-446655440000") UUID id,
            @Schema(example = "550e8400-e29b-41d4-a716-446655440000") UUID userId,
            @Schema(example = "550e8400-e29b-41d4-a716-446655440000") UUID serviceId,
            @Schema(example = "550e8400-e29b-41d4-a716-446655440000") UUID availabilitySlotId,
            BookingStatus status,
            @Schema(example = "25.00") BigDecimal totalPrice,
            @Schema(example = "USD") String currency,
            DepositType depositType,
            DepositValueType depositValueType,
            BigDecimal depositValue,
            @Schema(description = "Amount required for deposit (if applicable)") BigDecimal depositAmount,
            @Schema(description = "Total amount paid so far") BigDecimal paidAmount,
            @Schema(description = "Remaining amount to be paid") BigDecimal remainingAmount,
            Instant createdAt,
            @Schema(description = "Null unless status is CANCELLED and the customer gave one.", example = "Change of plans")
            String cancellationReason,
            @Schema(description = "City code where the service is offered (e.g., 'almaty', 'shymkent').", example = "almaty")
            String cityCode,
            @Schema(description = "Title of the booked service. Null if the service no longer exists, and on "
                    + "write responses (create/cancel/...), which are not enriched.", example = "Haircut")
            String serviceTitle,
            @Schema(description = "The business (provider) the booking is with. Same null rules as serviceTitle.")
            UUID providerId,
            @Schema(description = "Business name. Same null rules as serviceTitle.", example = "Salon Aurora")
            String providerName,
            @Schema(description = "Business vertical, e.g. 'beauty'. Same null rules as serviceTitle.",
                    example = "beauty")
            String providerVertical,
            @Schema(description = "When the appointment starts (the booked slot's start). Same null rules as "
                    + "serviceTitle.") Instant startsAt,
            @Schema(description = "When the appointment ends. Same null rules as serviceTitle.") Instant endsAt) {
        /** Plain mapping with no enrichment — the extra fields are null. */
        static BookingResponse from(Booking booking) {
            return from(booking, null, null, null);
        }

        static BookingResponse from(Booking booking, String serviceTitle, ProviderRef provider,
                SlotTimes times) {
            return new BookingResponse(booking.getId(), booking.getUserId(), booking.getServiceId(),
                    booking.getAvailabilitySlotId(), booking.getStatus(), booking.getTotalPrice(),
                    booking.getCurrency(), booking.getDepositType(), booking.getDepositValueType(),
                    booking.getDepositValue(), booking.getDepositAmount(), booking.getPaidAmount(),
                    booking.getRemainingAmount(), booking.getCreatedAt(), booking.getCancellationReason(),
                    booking.getCityCode(), serviceTitle,
                    provider == null ? null : provider.id(), provider == null ? null : provider.name(),
                    provider == null ? null : provider.vertical(),
                    times == null ? null : times.startsAt(), times == null ? null : times.endsAt());
        }
    }

    record ProviderRef(UUID id, String name, String vertical) {
    }

    record SlotTimes(Instant startsAt, Instant endsAt) {
    }

    /**
     * One row of a provider's schedule: a booking together with when its
     * slot starts and ends. {@link BookingResponse} has no times (a booking
     * only references its slot), so an agenda needs this join.
     */
    public record ScheduleEntryResponse(
            @Schema(example = "550e8400-e29b-41d4-a716-446655440000") UUID bookingId,
            @Schema(example = "550e8400-e29b-41d4-a716-446655440000") UUID serviceId,
            @Schema(example = "550e8400-e29b-41d4-a716-446655440000") UUID availabilitySlotId,
            BookingStatus status,
            Instant startsAt,
            Instant endsAt,
            @Schema(example = "25.00") BigDecimal totalPrice,
            @Schema(example = "KZT") String currency,
            @Schema(description = "Total amount paid so far") BigDecimal paidAmount) {
    }
}
