package com.zairo.factory.invitations;

/** What the invited person becomes — derived from the business's vertical, never chosen by the client. */
public enum InvitationKind {
    MASTER,
    MECHANIC,
    CLEANER,
    STAFF;

    static InvitationKind forVertical(String vertical) {
        String normalized = vertical == null ? "" : vertical.trim().toLowerCase();
        return switch (normalized) {
            case "beauty" -> MASTER;
            case "auto" -> MECHANIC;
            case "cleaning" -> CLEANER;
            default -> STAFF;
        };
    }
}
