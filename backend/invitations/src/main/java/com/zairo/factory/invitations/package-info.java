/**
 * Staff invitations. An owner invites someone who has no account yet by phone number; the number is stored
 * normalized (E.164). When a person later verifies that number by SMS (phone sign-up/sign-in or linking a
 * phone — see {@code auth.PhoneVerifiedEvent}) every open invitation for it is turned into the matching
 * master / mechanic / cleaner / staff record through the directory's own create-from-user method, so the
 * subscription staff limit and vertical checks still apply. People who are already registered are added
 * directly (see {@code GET /users/lookup}), no invitation needed.
 */
package com.zairo.factory.invitations;
