package com.zairo.factory.providers;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.regex.Pattern;
import org.springframework.http.HttpStatus;
import org.springframework.web.server.ResponseStatusException;

/**
 * A business's weekly opening hours as a {@code day -> "HH:mm-HH:mm"} map. Days are {@code mon..sun}; a missing day
 * means closed. Stored in one short text column ({@code mon=09:00-20:00;tue=09:00-20:00}) because nothing queries
 * by hours — clients only display them and work out "open now".
 */
public final class WorkingHours {

    public static final List<String> DAYS = List.of("mon", "tue", "wed", "thu", "fri", "sat", "sun");

    private static final Pattern RANGE = Pattern.compile("([01]\\d|2[0-3]):[0-5]\\d-([01]\\d|2[0-3]):[0-5]\\d");

    private WorkingHours() {
    }

    /** Rejects unknown day keys and malformed or empty ranges (end must be after start). A null map is fine. */
    public static void validate(Map<String, String> hours) {
        if (hours == null) {
            return;
        }
        for (Map.Entry<String, String> entry : hours.entrySet()) {
            if (!DAYS.contains(entry.getKey())) {
                throw bad("Unknown day in workingHours: " + entry.getKey());
            }
            String range = entry.getValue();
            if (range == null || !RANGE.matcher(range).matches()
                    || range.substring(0, 5).compareTo(range.substring(6)) >= 0) {
                throw bad("workingHours." + entry.getKey() + " must be HH:mm-HH:mm with the end after the start");
            }
        }
    }

    /** Text form in week order; null for an empty/absent map (so the column stays null). */
    public static String format(Map<String, String> hours) {
        if (hours == null || hours.isEmpty()) {
            return null;
        }
        StringBuilder out = new StringBuilder();
        for (String day : DAYS) {
            String range = hours.get(day);
            if (range != null) {
                if (!out.isEmpty()) {
                    out.append(';');
                }
                out.append(day).append('=').append(range);
            }
        }
        return out.isEmpty() ? null : out.toString();
    }

    /** Inverse of {@link #format}; never null, malformed pieces are skipped rather than failing a read. */
    public static Map<String, String> parse(String stored) {
        Map<String, String> hours = new LinkedHashMap<>();
        if (stored == null || stored.isBlank()) {
            return hours;
        }
        for (String part : stored.split(";")) {
            int eq = part.indexOf('=');
            if (eq > 0 && DAYS.contains(part.substring(0, eq)) && RANGE.matcher(part.substring(eq + 1)).matches()) {
                hours.put(part.substring(0, eq), part.substring(eq + 1));
            }
        }
        return hours;
    }

    private static ResponseStatusException bad(String message) {
        return new ResponseStatusException(HttpStatus.BAD_REQUEST, message);
    }
}
