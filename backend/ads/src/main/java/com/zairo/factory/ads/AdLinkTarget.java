package com.zairo.factory.ads;

/**
 * Where a tap on a banner (that has no video) opens inside the customer app. A closed list on purpose: the app
 * maps each value to one of its own screens, so a banner can never send a customer to an arbitrary URL.
 */
public enum AdLinkTarget {
    /** The customer's bonuses ("My rewards"). */
    REWARDS,
    /** The Search tab. */
    SEARCH
}
