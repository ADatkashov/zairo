/**
 * Generic staff directory and staff-scoped booking — usable by ANY Core
 * {@code Provider} regardless of category/vertical. Unlike
 * {@code vertical.beauty}/{@code vertical.auto}/{@code vertical.cleaning}
 * (each gated to one hardcoded {@code Provider.vertical} string), this
 * module reads no vertical string at all: a medicine clinic, a tutoring
 * business, a repair shop — any provider — can add staff and take
 * staff-scoped bookings the moment the catalog admin creates their
 * category, no new module or release required. Those three existing
 * modules are untouched and keep working exactly as they do today; this is
 * additive, not a replacement.
 */
package com.zairo.factory.staff;
