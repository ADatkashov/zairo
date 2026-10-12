package com.zairo.factory.reviews;

/**
 * Privacy-safe public author label: first name plus the initial of the last
 * word ("Aisha Karimova" -> "Aisha K."). Display names are free text and may
 * hold an email address, so anything containing '@' or digits-only/blank
 * input falls back to {@link #FALLBACK} rather than being echoed.
 */
final class ReviewerNames {

    static final String FALLBACK = "Customer";

    private ReviewerNames() {
    }

    static String abbreviate(String displayName) {
        if (displayName == null) {
            return FALLBACK;
        }
        String trimmed = displayName.trim();
        if (trimmed.isEmpty() || trimmed.indexOf('@') >= 0) {
            return FALLBACK;
        }
        String[] parts = trimmed.split("\\s+");
        String first = parts[0];
        if (!Character.isLetter(first.codePointAt(0))) {
            return FALLBACK;
        }
        if (parts.length == 1) {
            return first;
        }
        String last = parts[parts.length - 1];
        int initial = last.codePointAt(0);
        if (!Character.isLetter(initial)) {
            return first;
        }
        return first + " " + new String(Character.toChars(Character.toUpperCase(initial))) + ".";
    }
}
