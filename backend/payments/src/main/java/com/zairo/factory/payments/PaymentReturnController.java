package com.zairo.factory.payments;

import io.swagger.v3.oas.annotations.Hidden;
import java.nio.charset.StandardCharsets;
import java.util.Set;
import java.util.UUID;
import org.springframework.http.CacheControl;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestMethod;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/**
 * Where the payment provider sends the customer's browser after the payment page
 * ({@code PAYMENT_SUCCESS_URL} / {@code PAYMENT_FAILURE_URL} point at
 * {@code /pay/return/success} and {@code /pay/return/failure}). It is a plain web page that opens the
 * app through its {@code zairo://app/payment-result} deep link (with a button, because a browser may
 * refuse an automatic jump to another app).
 *
 * <p>This page proves nothing: whether the booking was really paid is decided by the provider's
 * webhook, and the app checks the server after coming back. Public and unauthenticated by nature
 * (the browser carries no app token); the only input it reflects is the booking id, and only after it
 * parses as a UUID, so nothing user-controlled ever reaches the page.
 */
@Hidden
@RestController
public class PaymentReturnController {

    private static final Set<String> OUTCOMES = Set.of("success", "failure");

    @RequestMapping(value = "/pay/return/{outcome}", method = { RequestMethod.GET, RequestMethod.POST })
    public ResponseEntity<byte[]> returnPage(@PathVariable String outcome,
            @RequestParam(name = "booking", required = false) String booking) {
        if (!OUTCOMES.contains(outcome)) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND).build();
        }
        String deepLink = "zairo://app/payment-result?status=" + outcome;
        UUID bookingId = parseUuid(booking);
        if (bookingId != null) {
            deepLink += "&booking=" + bookingId;
        }
        return ResponseEntity.ok()
                .contentType(new MediaType("text", "html", StandardCharsets.UTF_8))
                .cacheControl(CacheControl.noStore())
                .header("Referrer-Policy", "no-referrer")
                .header("Content-Security-Policy",
                        "default-src 'none'; style-src 'unsafe-inline'; script-src 'unsafe-inline'; base-uri 'none'")
                .body(page(outcome, deepLink).getBytes(StandardCharsets.UTF_8));
    }

    private static UUID parseUuid(String raw) {
        if (raw == null) {
            return null;
        }
        try {
            return UUID.fromString(raw);
        } catch (IllegalArgumentException e) {
            return null;
        }
    }

    private static String page(String outcome, String deepLink) {
        boolean success = "success".equals(outcome);
        String titleRu = success ? "Оплата принята" : "Оплата не прошла";
        String titleKk = success ? "Төлем қабылданды" : "Төлем өтпеді";
        String titleEn = success ? "Payment received" : "Payment didn't go through";
        // deepLink only holds the fixed scheme/path, the outcome from the allow-list and a parsed UUID.
        return """
                <!doctype html>
                <html lang="ru">
                <head>
                <meta charset="utf-8">
                <meta name="viewport" content="width=device-width, initial-scale=1">
                <title>ZAIRO</title>
                <style>
                body{font-family:system-ui,sans-serif;margin:0;padding:32px 20px;text-align:center;color:#1b1b1f}
                h1{font-size:22px;margin:0 0 8px}p{color:#555;margin:4px 0}
                a.btn{display:inline-block;margin-top:24px;padding:14px 28px;border-radius:12px;background:#4f46e5;color:#fff;text-decoration:none;font-weight:600}
                </style>
                </head>
                <body>
                <h1>%s</h1>
                <p>%s / %s</p>
                <p>Возвращаем вас в приложение ZAIRO…</p>
                <a class="btn" href="%s">Открыть приложение · Қолданбаны ашу · Open the app</a>
                <script>setTimeout(function(){window.location.href="%s";},300);</script>
                </body>
                </html>
                """.formatted(titleRu, titleKk, titleEn, deepLink.replace("&", "&amp;"), deepLink);
    }
}
