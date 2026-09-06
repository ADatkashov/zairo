package com.zairo.factory.notifications;

import com.zairo.factory.notifications.NotificationDtos.NotificationResponse;
import com.zairo.factory.notifications.NotificationDtos.UnreadCountResponse;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
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
