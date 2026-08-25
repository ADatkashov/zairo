/**
 * Auto vertical: mechanics (technicians/staff) attached to a Core
 * {@code Provider} (a workshop), vehicles owned by a Core {@code User}, and
 * the booking rules that an auto booking must name a mechanic who actually
 * offers the requested service, and a vehicle the booking's own user
 * actually owns. Core (providers, services, booking) knows nothing about
 * mechanics or vehicles — same Core/Vertical boundary vertical-beauty
 * already established (see docs/erd/core-domain.md).
 */
package com.zairo.factory.vertical.auto;
