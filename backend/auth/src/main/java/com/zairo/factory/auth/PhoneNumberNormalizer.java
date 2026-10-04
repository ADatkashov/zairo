package com.zairo.factory.auth;

import com.google.i18n.phonenumbers.NumberParseException;
import com.google.i18n.phonenumbers.PhoneNumberUtil;
import com.google.i18n.phonenumbers.Phonenumber.PhoneNumber;
import org.springframework.stereotype.Component;

/**
 * Canonicalizes any way a phone number can be typed ("+7 700 123 45 67",
 * "8 (700) 123-45-67", "77001234567", ...) to one E.164 string
 * ("+77001234567") so {@code user_identity.provider_subject} can enforce
 * "one phone == one account" with a plain unique constraint — without this,
 * "+7..." and "8..." and a spaced-out version of the same number would each
 * create a separate identity, and a separate account, for the same person.
 *
 * <p>Uses Google's libphonenumber (the same library Android's own
 * "Phone Number" input widgets are built on) rather than a hand-rolled
 * regex — international numbering plans have enough real-world exceptions
 * (variable length, leading zeros, area codes) that a bespoke parser would
 * either reject valid numbers or silently accept malformed ones.
 * defaultRegion is "KZ" (Kazakhstan): a bare national number with no "+"
 * or country code, as ZAIRO's own UI always collects (see the Flutter
 * phone screen's "+7 ___ ___ __ __" mask), is assumed local unless the
 * caller already typed a country code.
 */
@Component
class PhoneNumberNormalizer {

    private static final String DEFAULT_REGION = "KZ";

    private final PhoneNumberUtil phoneNumberUtil = PhoneNumberUtil.getInstance();

    /** @throws InvalidPhoneNumberException if the value isn't a valid, dialable phone number. */
    String normalize(String rawPhone) {
        if (rawPhone == null || rawPhone.isBlank()) {
            throw new InvalidPhoneNumberException("Phone number is required");
        }
        try {
            PhoneNumber parsed = phoneNumberUtil.parse(rawPhone, DEFAULT_REGION);
            if (!phoneNumberUtil.isValidNumber(parsed)) {
                throw new InvalidPhoneNumberException("Not a valid phone number: " + rawPhone);
            }
            return phoneNumberUtil.format(parsed, PhoneNumberUtil.PhoneNumberFormat.E164);
        } catch (NumberParseException e) {
            throw new InvalidPhoneNumberException("Not a valid phone number: " + rawPhone);
        }
    }

    /** ISO region ("KZ", "RU", ...) of an already-normalized E.164 number, or null if it can't be determined. */
    String regionOf(String e164Phone) {
        try {
            String region = phoneNumberUtil.getRegionCodeForNumber(phoneNumberUtil.parse(e164Phone, DEFAULT_REGION));
            return region == null || "ZZ".equals(region) ? null : region;
        } catch (NumberParseException e) {
            return null;
        }
    }
}
