package com.zairo.factory.users;

/**
 * Optional self-reported gender. {@link #NOT_SPECIFIED} is only a request
 * value meaning "clear it" — it is never stored (the column stays NULL).
 */
public enum Gender {
    FEMALE,
    MALE,
    NOT_SPECIFIED
}
