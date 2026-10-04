package com.zairo.factory.auth;

import java.util.UUID;

/**
 * A module's hook to erase the personal data it owns when an account is deleted (favorites, saved vehicles,
 * notifications, preferences, derived behaviour profiles...). Runs inside the deletion transaction, so either all of
 * it is erased or none. Business records that merely reference the user (bookings, payments, reviews, the loyalty
 * ledger) are NOT erased -- they stay, attached to the anonymized "Deleted user".
 */
public interface AccountDataEraser {

    void eraseDataOf(UUID userId);
}
