package com.zairo.factory.invitations;

public enum InvitationStatus {
    PENDING,
    ACCEPTED,
    CANCELLED,
    /** The person verified the number but could not be attached (e.g. the plan's staff limit was reached). */
    FAILED
}
