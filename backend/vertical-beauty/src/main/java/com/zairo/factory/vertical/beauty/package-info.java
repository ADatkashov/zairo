/**
 * Beauty vertical: masters (stylists/technicians) attached to a Core
 * {@code Provider}, their portfolios, which Core {@code Service}s each
 * master can perform, and the booking rule that a beauty booking must name
 * a master who actually offers the requested service. Core (providers,
 * services, booking) knows nothing about masters or portfolios — see
 * docs/erd/core-domain.md, "Vertical-специфичные атрибуты ... живут в
 * отдельных таблицах vertical-модуля".
 */
package com.zairo.factory.vertical.beauty;
