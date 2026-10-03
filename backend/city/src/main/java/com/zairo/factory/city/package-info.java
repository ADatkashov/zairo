/**
 * City management for multi-city support. Each country has its own set of cities stored in a database table.
 * Cities are managed exclusively through the Platform Admin interface — there is no public API for creating cities.
 *
 * Public endpoints (under /api/v1/cities) allow reading city information:
 * - GET /api/v1/cities — all cities
 * - GET /api/v1/cities/country/{countryCode} — all cities for a country
 * - GET /api/v1/cities/country/{countryCode}/active — active cities for a country
 * - GET /api/v1/cities/{code} — specific city
 *
 * Admin endpoints (under /api/v1/platform/cities) require PLATFORM_ADMIN role:
 * - POST /api/v1/platform/cities — create city
 * - PUT /api/v1/platform/cities/{code} — update city
 * - DELETE /api/v1/platform/cities/{code} — delete city
 */
package com.zairo.factory.city;
