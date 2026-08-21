package com.zairo.factory.notifications;

import java.util.UUID;
import org.springframework.stereotype.Service;

/**
 * Entry point other modules call to send a notification — callers never
 * touch {@link EmailNotificationProvider} directly. Only an email channel
 * exists so far (auth's password reset; booking confirmation/cancellation
 * below) — push/SMS provider interfaces aren't defined yet because nothing
 * in this project sends through them; add them (see the Factory Master
 * Architecture doc's NotificationProvider shape) once a real push/SMS use
 * case exists, not preemptively.
 */
@Service
public class NotificationService {

    private final EmailNotificationProvider emailProvider;

    public NotificationService(EmailNotificationProvider emailProvider) {
        this.emailProvider = emailProvider;
    }

    public void sendPasswordResetEmail(String toEmail, String resetToken) {
        String subject = "Reset your Factory password";
        String body = "Use this code to reset your password: " + resetToken
                + "\n\nThis code expires in an hour. If you didn't request a password reset, "
                + "you can safely ignore this email.";
        emailProvider.send(toEmail, subject, body);
    }

    public void sendBookingConfirmedEmail(String toEmail, UUID bookingId) {
        emailProvider.send(toEmail, "Booking confirmed",
                "Your booking (" + bookingId + ") is confirmed. We'll see you there!");
    }

    public void sendBookingCancelledEmail(String toEmail, UUID bookingId) {
        emailProvider.send(toEmail, "Booking cancelled",
                "Your booking (" + bookingId + ") has been cancelled.");
    }

    public void sendNewBookingReceivedEmail(String toEmail, UUID bookingId) {
        emailProvider.send(toEmail, "New booking received",
                "You have a new booking (" + bookingId + ").");
    }

    public void sendProviderBookingCancelledEmail(String toEmail, UUID bookingId) {
        emailProvider.send(toEmail, "Booking cancelled",
                "A customer cancelled booking (" + bookingId + ").");
    }
}
