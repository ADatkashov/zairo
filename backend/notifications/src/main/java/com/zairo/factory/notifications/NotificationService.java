package com.zairo.factory.notifications;

import com.zairo.factory.notifications.NotificationDtos.NotificationResponse;
import com.zairo.factory.notifications.NotificationDtos.UnreadCountResponse;
import java.math.BigDecimal;
import java.time.Instant;
import java.time.ZoneOffset;
import java.time.format.DateTimeFormatter;
import java.util.List;
import java.util.Locale;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

/**
 * Entry point other modules call to send a notification — callers never
 * touch {@link EmailNotificationProvider} directly. Email is the only
 * outbound channel (push/SMS provider interfaces aren't defined yet
 * because nothing in this project sends through them — add them, see the
 * Factory Master Architecture doc's NotificationProvider shape, once a
 * real push/SMS use case exists, not preemptively).
 *
 * A subset of the events also get an {@link InAppNotification} row —
 * only the customer-facing ones user_app's notification feed shows (see
 * {@link InAppNotificationType}'s doc comment for exactly which and why);
 * those methods take the recipient's {@code userId} in addition to their
 * email. Owner-facing and security/subscription emails stay email-only.
 */
@Service
public class NotificationService {

    private final EmailNotificationProvider emailProvider;
    private final InAppNotificationRepository inAppNotificationRepository;

    public NotificationService(EmailNotificationProvider emailProvider,
            InAppNotificationRepository inAppNotificationRepository) {
        this.emailProvider = emailProvider;
        this.inAppNotificationRepository = inAppNotificationRepository;
    }

    public void sendPasswordResetEmail(String toEmail, String resetToken) {
        String subject = "Reset your Factory password";
        String body = "Use this code to reset your password: " + resetToken
                + "\n\nThis code expires in an hour. If you didn't request a password reset, "
                + "you can safely ignore this email.";
        emailProvider.send(toEmail, subject, body);
    }

    /**
     * {@code REQUIRES_NEW}: every caller of this method is a
     * {@code @TransactionalEventListener(phase = AFTER_COMMIT)} — see
     * {@code BookingCancelledPaymentListener}'s doc comment for why a write
     * made from inside that post-commit callback needs a genuinely new,
     * independent transaction to actually persist, rather than silently
     * appearing to succeed while joining an already-completed one.
     */
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void sendBookingConfirmedEmail(UUID recipientUserId, String toEmail, UUID bookingId) {
        String title = "Booking confirmed";
        String body = "Your booking (" + bookingId + ") is confirmed. We'll see you there!";
        emailProvider.send(toEmail, title, body);
        recordInApp(recipientUserId, InAppNotificationType.BOOKING_CONFIRMED, title, body);
    }

    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void sendBookingCancelledEmail(UUID recipientUserId, String toEmail, UUID bookingId) {
        String title = "Booking cancelled";
        String body = "Your booking (" + bookingId + ") has been cancelled.";
        emailProvider.send(toEmail, title, body);
        recordInApp(recipientUserId, InAppNotificationType.BOOKING_CANCELLED, title, body);
    }

    public void sendNewBookingReceivedEmail(String toEmail, UUID bookingId) {
        emailProvider.send(toEmail, "New booking received",
                "You have a new booking (" + bookingId + ").");
    }

    public void sendProviderBookingCancelledEmail(String toEmail, UUID bookingId) {
        emailProvider.send(toEmail, "Booking cancelled",
                "A customer cancelled booking (" + bookingId + ").");
    }

    public void sendStaffCannotAttendEmail(String toEmail, UUID bookingId) {
        emailProvider.send(toEmail, "A staff member can't attend an appointment",
                "A staff member can't attend booking (" + bookingId + "). Open the app to reassign it, move it "
                        + "or cancel it.");
    }

    public void sendWorkerNotAcceptedEmail(String toEmail, String workerName, Instant startsAt) {
        emailProvider.send(toEmail, "An appointment hasn't been accepted",
                workerName + " hasn't accepted the appointment at " + startsAt + ". Open the app to check with "
                        + "them or hand it to a colleague.");
    }

    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void sendWorkerChangedEmail(UUID recipientUserId, String toEmail, UUID bookingId, String toName,
            boolean customerDidntMind, java.math.BigDecimal newPrice) {
        String title = "Your specialist has changed";
        String body = (customerDidntMind ? "For your appointment (" + bookingId + ") " : "Your appointment ("
                + bookingId + ") will be with ") + (customerDidntMind ? "we assigned " : "") + toName
                + ". The time is the same."
                + (newPrice == null ? "" : " The price is now " + newPrice.toPlainString()
                        + "; anything you already paid above it is returned to you.");
        emailProvider.send(toEmail, title, body);
        recordInApp(recipientUserId, InAppNotificationType.WORKER_CHANGED, title, body);
    }

    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void sendChangeRequestedEmail(UUID recipientUserId, String toEmail, UUID bookingId, String workerName) {
        String title = "Please choose how to proceed";
        String body = workerName + " can't make your appointment (" + bookingId + "). Open the app to pick a "
                + "colleague at the same time, another time, or cancel with a full refund.";
        emailProvider.send(toEmail, title, body);
        recordInApp(recipientUserId, InAppNotificationType.CHANGE_REQUESTED, title, body);
    }

    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void sendBookingMovedEmail(UUID recipientUserId, String toEmail, UUID bookingId, Instant newStartsAt) {
        String title = "Your appointment was moved";
        String body = "Your appointment (" + bookingId + ") now starts at " + newStartsAt + ".";
        emailProvider.send(toEmail, title, body);
        recordInApp(recipientUserId, InAppNotificationType.BOOKING_MOVED, title, body);
    }

    public void sendWorkerUnavailableEmail(String toEmail, String workerName, int affectedAppointments) {
        emailProvider.send(toEmail, workerName + " is unavailable",
                workerName + " closed their availability. " + (affectedAppointments > 0
                        ? affectedAppointments + " booked appointment(s) fall in that period — open the app to "
                                + "decide what to do with each."
                        : "No booked appointments are affected."));
    }

    public void sendSubscriptionPaymentFailedEmail(String toEmail) {
        emailProvider.send(toEmail, "Subscription payment failed",
                "We couldn't charge your PRO subscription. Please update your payment details — your plan "
                        + "will be downgraded to FREE if this isn't resolved within the grace period.");
    }

    public void sendSubscriptionDowngradedEmail(String toEmail) {
        emailProvider.send(toEmail, "Subscription downgraded to FREE",
                "Your subscription has been downgraded to the FREE plan. You can upgrade again at any time.");
    }

    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void sendBookingReminderEmail(UUID recipientUserId, String toEmail, UUID bookingId) {
        String title = "Upcoming booking reminder";
        String body = "Your booking (" + bookingId + ") is coming up in about an hour. See you soon!";
        emailProvider.send(toEmail, title, body);
        recordInApp(recipientUserId, InAppNotificationType.BOOKING_REMINDER, title, body);
    }

    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void sendPaymentRefundedEmail(UUID recipientUserId, String toEmail, UUID bookingId, BigDecimal amount,
            String currency) {
        String title = "Refund processed";
        String body = "Your refund of " + amount + " " + currency + " for booking (" + bookingId
                + ") has been processed.";
        emailProvider.send(toEmail, title, body);
        recordInApp(recipientUserId, InAppNotificationType.PAYMENT_REFUNDED, title, body);
    }

    private static final DateTimeFormatter SMART_FILL_SLOT_TIME = DateTimeFormatter
            .ofPattern("EEEE, MMM d 'at' HH:mm 'UTC'", Locale.ENGLISH).withZone(ZoneOffset.UTC);

    /**
     * {@code REQUIRES_NEW} -- same reasoning as {@link #sendBookingConfirmedEmail}.
     * The example this copy is modeled on (see the task Smart Fill was
     * built from): "A slot just opened up at Alia's today at 15:00 -- want
     * to book it?", provider/employee names substituted in, employee
     * omitted entirely when null (see {@code
     * smartfill.SmartFillOfferReadyEvent#employeeName}'s own doc comment
     * for why that can happen).
     */
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void sendSmartFillOfferEmail(UUID recipientUserId, String toEmail, String providerName,
            String serviceName, String employeeName, Instant slotStartsAt) {
        String title = "A slot just opened up!";
        String who = employeeName == null ? "at " + providerName : "with " + employeeName + " at " + providerName;
        String body = "Good news -- a " + serviceName + " slot " + who + " just opened up on "
                + SMART_FILL_SLOT_TIME.format(slotStartsAt) + ". Want to book it before someone else does?";
        emailProvider.send(toEmail, title, body);
        recordInApp(recipientUserId, InAppNotificationType.SMART_FILL_OFFER, title, body);
    }

    /**
     * {@code REQUIRES_NEW} -- same reasoning as {@link #sendBookingConfirmedEmail}.
     * The example this copy is modeled on: "Looks like it's time for your
     * next visit -- book your next [service] at [provider]?" -- deliberately
     * generic (no specific date/time to point at, unlike a Smart Fill offer)
     * since a rebook nudge just invites the customer back to the ordinary
     * booking flow rather than offering one specific slot.
     */
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void sendRebookOfferEmail(UUID recipientUserId, String toEmail, String providerName, String serviceName) {
        String title = "Time for your next visit?";
        String body = "Looks like it's about time for your next " + serviceName + " at " + providerName
                + " -- ready to book it?";
        emailProvider.send(toEmail, title, body);
        recordInApp(recipientUserId, InAppNotificationType.REBOOK_OFFER, title, body);
    }

    /**
     * {@code REQUIRES_NEW} -- same reasoning as {@link #sendBookingConfirmedEmail}.
     * Deliberately warmer/more direct than {@link #sendRebookOfferEmail}'s
     * neutral "time for your next visit?" -- this only ever goes to a
     * customer the Lost Customer Recovery sweep judged significantly
     * overdue, a colder lead worth a more pointed "we miss you" than a
     * routine cadence reminder. No discount mentioned here on purpose (see
     * {@code reactivationengine}'s package-info) -- whether to offer one is
     * Smart Promotion Engine's decision, not this one's.
     */
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void sendReactivationOfferEmail(UUID recipientUserId, String toEmail, String providerName,
            String serviceName) {
        String title = "We miss you!";
        String body = "It's been a while since your last " + serviceName + " at " + providerName
                + " -- we'd love to see you again. Ready to book?";
        emailProvider.send(toEmail, title, body);
        recordInApp(recipientUserId, InAppNotificationType.REACTIVATION_OFFER, title, body);
    }

    /**
     * Birthday greeting. A phone-only account has no email, so the email is skipped (not an error) and the in-app
     * notification still goes out.
     */
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void sendBirthdayBonusNotification(UUID recipientUserId, String toEmail, String providerName, int points) {
        String title = "Happy birthday!";
        String body = providerName + " congratulates you and gives you " + points
                + " bonus points as a birthday gift. Treat yourself!";
        if (toEmail != null && !toEmail.isBlank()) {
            emailProvider.send(toEmail, title, body);
        }
        recordInApp(recipientUserId, InAppNotificationType.BIRTHDAY_BONUS, title, body);
    }

    /**
     * A greeting the business owner sent by hand. {@code message} null/blank = the default text; a phone-only account
     * has no email, so the email is skipped and the in-app notification still goes out.
     */
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void sendGreetingNotification(UUID recipientUserId, String toEmail, String providerName, String message,
            int points) {
        String title = "A greeting from " + providerName;
        String body = message == null || message.isBlank() ? providerName + " congratulates you and wishes you all the best!"
                : message;
        if (points > 0) {
            body += " As a gift, " + points + " bonus points were added to your balance.";
        }
        if (toEmail != null && !toEmail.isBlank()) {
            emailProvider.send(toEmail, title, body);
        }
        recordInApp(recipientUserId, InAppNotificationType.GREETING, title, body);
    }

    private void recordInApp(UUID recipientUserId, InAppNotificationType type, String title, String body) {
        inAppNotificationRepository.save(
                new InAppNotification(UUID.randomUUID(), recipientUserId, type, title, body, Instant.now()));
    }

    public List<NotificationResponse> list(UUID userId) {
        return inAppNotificationRepository.findByRecipientUserIdOrderByCreatedAtDesc(userId).stream()
                .map(NotificationResponse::from)
                .toList();
    }

    public UnreadCountResponse unreadCount(UUID userId) {
        return new UnreadCountResponse(inAppNotificationRepository.countByRecipientUserIdAndReadFalse(userId));
    }

    public void markRead(UUID userId, UUID notificationId) {
        InAppNotification notification = inAppNotificationRepository.findByIdAndRecipientUserId(notificationId, userId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND,
                        "Notification not found: " + notificationId));
        notification.markRead();
        inAppNotificationRepository.save(notification);
    }

    public void markAllRead(UUID userId) {
        inAppNotificationRepository.markAllRead(userId);
    }
}
