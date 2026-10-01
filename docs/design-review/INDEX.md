# ZAIRO Design Review & Implementation Roadmap

**Date**: 2026-10-01  
**Project**: ZAIRO Service Marketplace Platform  
**Audit Scope**: Professional UI/UX review of Flutter apps (user_app, business_admin) and design system

---

## Overview

This directory contains the comprehensive UI/UX audit and implementation roadmap for the ZAIRO marketplace platform. The audit identifies critical usability gaps and provides specific, prioritized recommendations for improvement.

**Key Resources**:
- `FACTORY_DESIGN_SYSTEM.md` — Complete Factory Design System documentation
- `AUDIT_FINDINGS.md` — Detailed audit with critical issues and recommendations
- `IMPLEMENTATION_ROADMAP.md` — Priority-based action plan for fixes

---

## Audit Summary

### Critical Issues (Priority 1: 1-2 weeks)

**Payment UX is fundamentally broken:**
- ❌ No payment review screen — users can't see total/deposit/remaining breakdown before confirming
- ❌ Deposit settings hidden in wrong location
- ❌ Total, deposit, and remaining amounts not visible in booking flow
- ❌ No payment history or timeline view

**Booking details and sharing:**
- ❌ ProviderDetailScreen is 85% complete but lacks booking share + calendar add buttons
- ❌ No way to share booking confirmation or add to calendar

**Business Admin critical gaps:**
- ❌ SalonDetailScreen overloaded — needs split into settings/billing tabs
- ❌ No booking settings/preferences screen

### High Priority (Priority 2: 3-4 weeks)

**Visual design inconsistencies:**
- Card hierarchy and spacing not uniform
- Inconsistent padding/margins across screens
- Button sizes vary where they shouldn't

**Mobile & responsive gaps:**
- Landscape orientation unsupported
- Forms overflow on smaller screens
- Bottom sheet behavior not responsive

**Accessibility issues:**
- Semantic labels missing on interactive elements
- Color-only indicators (no icons/text)
- Focus states not visible
- No high-contrast mode support

**Localization gaps:**
- Money formatting not localized (using $ instead of ₸)
- Translations incomplete
- Date/time formatting not regional

### Medium Priority (Priority 3: 5+ weeks)

**New design system components needed:**
- PaymentTimeline component for booking history
- EmptyState with action buttons (not just text)
- PaymentBreakdown reusable widget

**Screen maturity scores:**
- BookingConfirmationScreen: 85% complete
- ProviderDetailScreen: 60% complete  
- MyBookingsScreen: 80% complete
- DashboardScreen: 85% complete
- BillingScreen: 85% complete

---

## Implementation Sequence

### Phase 1: Critical Payment Flow (Weeks 1-2)

**Screens to implement:**
1. `PaymentReviewScreen` — Show total/deposit/remaining breakdown
2. `BookingSettingsScreen` — Deposit and payment preferences in SalonDetailScreen
3. Update `MyBookingsScreen` — Add payment breakdown view
4. Update `BookingConfirmationScreen` — Add share + calendar add buttons

**Dependencies:**
- New `PaymentBreakdown` component
- New `PaymentTimeline` component
- Calendar/share integration

### Phase 2: Visual Design Refinement (Weeks 3-4)

**Tasks:**
- Standardize card styling across all screens
- Ensure consistent spacing (4pt scale)
- Update button sizing rules
- Test on multiple screen sizes

### Phase 3: Accessibility & Localization (Weeks 5+)

**Tasks:**
- Add semantic ARIA labels
- Implement focus states
- Add high-contrast mode
- Complete all translations
- Add regional money/date formatting

---

## Design System Reference

**Factory Design System** (defined in `packages/core_ui/`)

### Visual Foundations
- **Palette**: Stone neutral + Pine primary (deep teal-green) + Gold accent
- **Type**: Unbounded (headlines) + Golos Text (UI/body) + JetBrains Mono (prices/times)
- **Spacing**: Strict 4pt scale (4/8/12/16/20/24/32/40/48)
- **Radius**: 8/12/16/24px (modest, considered)
- **Elevation**: Border at rest, soft shadow on hover/raised states
- **Motion**: Three durations (120/200/320ms), one easing curve

### Component Inventory

**Core** (8):
- Button, IconButton, Card, Badge, Chip, TextField, SearchField, Avatar

**Navigation** (2):
- AppBar, BottomNavigation

**Feedback** (6):
- Dialog, BottomSheet, EmptyState, ErrorState, LoadingState, Skeleton

**Content** (8):
- CategoryTile, ServiceCard, ProviderCard, SelectableTile, SectionHeader, StatTile, TimeSlot, PriceText, RatingLabel

**Brand** (1):
- Logomark (Module Mark: 3 filled squares + 1 dashed/flat for next vertical)

### Source Files to Update

| Finding | Source File | Component |
|---------|------------|-----------|
| Payment UX | `packages/core_ui/lib/src/widgets/` | Add `PaymentBreakdown.dart`, `PaymentTimeline.dart` |
| Booking settings | `apps/business_admin/lib/features/salon/` | Add `SalonSettingsScreen.dart` |
| Booking share | `apps/user_app/lib/features/booking/` | Update `BookingConfirmationScreen.dart` |
| Card spacing | `packages/core_ui/lib/src/widgets/factory_card.dart` | Standardize `padding` and `margin` |
| Responsive forms | `apps/*/lib/features/*/presentation/` | Add responsive breakpoints |

---

## Localization Requirements

The product ships in **Kazakh, Russian, and English**.

**Priority translations:**
- Payment-related labels (deposit, total, remaining)
- Booking confirmation messages
- Error states and empty states
- Settings and preferences

**Formatting rules:**
- Prices: Space-grouped thousands (`12 400 ₸`), not `12,400 ₸`
- Dates: Regional format (DD.MM.YYYY for Cyrillic, MM/DD/YYYY for English)
- Times: 24-hour format (16:30, not 4:30 PM)

---

## Next Steps

1. **Week 1**: Start with `PaymentReviewScreen` and `BookingSettingsScreen`
2. **Review findings** with product team to validate priorities
3. **Create new components** in design system before implementing screens
4. **Test on all platforms** — mobile (portrait/landscape), tablet, desktop admin
5. **Validate accessibility** with keyboard navigation and screen reader testing

---

## References

- **Repository**: https://github.com/ADatkashov/zairo
- **Codebase structure**:
  - `packages/core_ui/` — Design system (Flutter widgets, tokens)
  - `apps/user_app/` — Customer-facing app
  - `apps/business_admin/` — Owner/staff app
  - `backend/` — Spring Boot modular monolith
- **Design system created**: 2026-09-04
- **Last sync with repository**: 2026-09-04T17:11:59Z
