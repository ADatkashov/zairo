# ZAIRO UI/UX Audit - Detailed Findings

**Audit Date**: 2026-10-01  
**Scope**: Flutter user_app + business_admin applications, design system compliance  
**Status**: Professional review, prioritized for implementation

---

## Priority 1: Critical Issues (1-2 weeks)

### 1. Payment UX is Fundamentally Broken

**Problem**: Users cannot see payment breakdown before confirming a booking. This creates trust issues and leads to failed transactions.

**Missing screens**:
1. **PaymentReviewScreen** — Show total/deposit/remaining before confirmation
   - Current state: Jumping directly to payment without review
   - Impact: Users confirm blind, increasing chargebacks and refund requests
   - Completion: 0%

2. **Deposit settings missing** — Settings buried or inaccessible
   - Current state: Booking settings screen doesn't show deposit configuration
   - Impact: Business owners can't manage their deposit policy
   - Completion: 0%

3. **Total/Deposit/Remaining not visible** — Amounts hidden in booking flow
   - Current state: Only total shown, no breakdown
   - Impact: Customer confusion about what they're paying
   - Completion: 0%

4. **No payment history** — Users can't see past payments
   - Current state: MyBookingsScreen doesn't show payment timeline
   - Impact: Users question their account balance
   - Completion: 0%

**Screens affected**:
- `apps/user_app/lib/features/booking/presentation/screens/booking_confirmation_screen.dart` (needs payment review before this)
- `apps/business_admin/lib/features/salon/presentation/screens/salon_detail_screen.dart` (needs booking settings screen)
- `apps/user_app/lib/features/booking/presentation/screens/my_bookings_screen.dart` (needs payment history)

**Required components**:
- `PaymentBreakdown` widget (shows total/deposit/remaining in card format)
- `PaymentTimeline` widget (shows payment history with dates/amounts)
- Add deposit configuration to `SalonDetailScreen`

**Implementation**:
```
Week 1:
- Create PaymentBreakdown component in design system
- Create PaymentTimeline component
- Add PaymentReviewScreen to booking flow
- Update BookingConfirmationScreen to show review first

Week 2:
- Create SalonDetailScreen > BookingSettingsTab
- Update MyBookingsScreen to show payment history
- Test on all screen sizes and devices
```

---

### 2. Booking Details Incomplete

**Problem**: ProviderDetailScreen is 85% complete but lacks critical sharing features.

**Missing features**:
1. **Share booking button** — No way to share confirmation with others
   - Current: Only view locally
   - Required: iOS/Android share sheet, deep link
   
2. **Add to calendar** — Can't import booking into calendar apps
   - Current: User must manually add
   - Required: iCalendar export, calendar app integration

**Screen**: `apps/user_app/lib/features/booking/presentation/screens/booking_confirmation_screen.dart`

**Implementation**:
```
Week 1:
- Add "Share" button (Material Symbols: share)
- Add "Add to Calendar" button (Material Symbols: calendar_today)
- Implement share sheet (native iOS, Android)
- Generate iCalendar file for calendar import
- Test on both platforms
```

**UX flow**:
```
BookingConfirmationScreen
├─ Confirmation header (check icon, "Booking confirmed")
├─ Service details
├─ Date/time
├─ Payment amount
├─ [Share] [Add to Calendar] buttons  ← NEW
└─ Back to home
```

---

### 3. Business Admin Overloaded Screens

**Problem**: SalonDetailScreen tries to do too much, overwhelming business owners.

**Current state**:
- Settings + Billing + Staff management all on one screen
- Scroll depth excessive (~2000px)
- No tab navigation

**Required split**:
1. **SalonDetailsTab** (overview, basic info, hours)
2. **BookingSettingsTab** (deposit policy, cancellation, pricing)
3. **BillingTab** (payment history, invoices, payouts)
4. **StaffTab** (team members, roles, permissions)

**Screen**: `apps/business_admin/lib/features/salon/presentation/screens/salon_detail_screen.dart`

**Implementation**:
```
Week 1:
- Add TabBar navigation (4 tabs)
- Move BookingSettings to separate tab
- Move BillingData to separate tab
- Keep StaffManagement as existing tab

Week 2:
- Test navigation on mobile/tablet/desktop
- Ensure each tab loads independently
- Update responsive breakpoints
```

---

## Priority 2: High-Priority Issues (3-4 weeks)

### 4. Visual Design Inconsistencies

**Problem**: Cards, spacing, and hierarchy vary across screens.

**Specific issues**:

**Card hierarchy inconsistent**:
- ServiceCard padding: 16px (correct)
- ProviderCard padding: 12px (should be 16px)
- CategoryTile padding: 12px (should be 16px)
- Fix: Standardize all to 16px

**Spacing violations** (4pt scale should be strict):
- Button gap below cards: 6px (should be 8px)
- Section margins: 18px (should be 16px)
- Inner padding: 14px (should be 12px or 16px)
- Fix: Audit all screens, replace ad-hoc values

**Button sizing inconsistent**:
- Primary buttons: 48px height (correct)
- Secondary buttons: 44px (should be 48px)
- Text buttons: no min-height (should be 40px minimum)
- Fix: Enforce `buttonLarge`/`buttonMedium`/`buttonSmall` tokens

**Affected screens**: All major screens need audit

**Implementation**:
```
Weeks 3-4:
- Audit card components (ServiceCard, ProviderCard, etc.)
- Audit all screen layouts for spacing violations
- Create before/after screenshots
- Test on all breakpoints (320px, 768px, 1024px, 1440px)
- Update stories/tests with correct values
```

---

### 5. Mobile & Responsive Design Gaps

**Problem**: App doesn't support landscape orientation; forms overflow on smaller screens.

**Landscape issues**:
- Screens don't rotate (locked to portrait)
- Portrait-only flow breaks on landscape tablets
- Bottom navigation doesn't adapt to landscape

**Form overflow**:
- Long form fields don't wrap at 320px width
- Button widths exceed container (e.g., booking payment screen)
- Bottom sheet height not responsive (full screen even with 3 fields)

**Screen sizes to test**:
- Phone portrait: 375px (iPhone)
- Phone landscape: 667px
- Tablet portrait: 768px (iPad)
- Tablet landscape: 1024px
- Desktop: 1440px+

**Affected screens**: All screens, especially:
- `HomeScreen` (bottom nav flex issues)
- `ProviderDetailScreen` (image carousel + content overflow)
- `BookingConfirmationScreen` (payment form)
- `DashboardScreen` (charts don't resize)

**Implementation**:
```
Weeks 3-4:
- Enable landscape orientation in app config
- Test all screens at 320px (minimum), 375px, 600px, 1024px
- Update layout constraints (max-width for content)
- Test with TextScaleFactor (120%, 150%) — text should not overflow
- Fix form layouts (single column at narrow widths)
- Ensure buttons span full width at narrow breakpoints
```

---

### 6. Accessibility Issues

**Problem**: Missing semantic labels, no focus states, no high-contrast mode.

**Specific gaps**:

**Semantic labels missing**:
- Icon-only buttons (share, favorite, settings) have no `semanticLabel`
- Images (provider photos, service images) missing `semanticLabel`
- Form fields missing `labelText` (using placeholder alone)
- Fix: Add labels to all interactive elements

**Color-only indicators**:
- Favorite status only shown by heart color, no icon state
- Available/unavailable timeslots only differ by background color
- Selected tiles only differ by background, no checkmark
- Fix: Add icons/checkmarks to color-dependent states

**Focus states not visible**:
- No focus ring around buttons on keyboard navigation
- No focus ring around form fields
- No focus indicator on tab navigation
- Fix: Add `focusColor`, `focusBorder` to all interactive elements

**No high-contrast mode**:
- Fails WCAG AAA (4.5:1 minimum contrast)
- Examples: Secondary text on light backgrounds (too light)
- Button text on primary background (too light)
- Fix: Audit color contrast, increase values for accessibility

**Affected screens**: All major screens

**Implementation**:
```
Weeks 3-4:
- Audit all interactive elements for semantic labels
- Add focus states (rings, borders) to all components
- Increase color contrast where needed (test with contrast checker)
- Add checkmarks/icons to state indicators (not color-alone)
- Test with screen reader (TalkBack on Android, VoiceOver on iOS)
- Test with high-contrast mode enabled
```

---

### 7. Localization Gaps

**Problem**: Money formatting not localized, translations incomplete.

**Money formatting issues**:
- Using `$` instead of `₸` (Kazakhstani tenge)
- Formatting `12,400` instead of `12 400` (space-grouped thousands)
- Not using tabular figures (numbers misalign)
- Fix: Use `formatFactoryAmount()` with locale

**Translation gaps**:
- Payment-related labels not translated (showing English)
- Booking confirmation messages incomplete
- Error messages not translated
- Settings labels in wrong language
- Fix: Complete `l10n/app_localizations_*.arb` files

**Date/time formatting**:
- Showing `12/25/2026` instead of `25.12.2026` (Cyrillic format)
- Using 12-hour time instead of 24-hour
- No localized day names (Monday, Tuesday)
- Fix: Use locale-specific `DateFormat` (e.g., `dd.MM.yyyy` for Cyrillic)

**Affected screens**: All screens using money, dates, times

**Implementation**:
```
Weeks 3-4:
- Replace all hardcoded `$` with `₸` and `formatFactoryAmount()`
- Complete translations for all screens
- Test in Kazakh, Russian, English
- Verify money formatting on all platforms
- Test on 24-hour vs 12-hour time zones
```

---

## Priority 3: Medium-Priority Issues (5+ weeks)

### 8. Design System Component Additions

**New components needed** (not yet in design system):

1. **PaymentBreakdown**
   - Shows total / deposit / remaining
   - Breakdown table format (label | amount)
   - Color-coded labels (primary/secondary)
   - Used in: PaymentReviewScreen

2. **PaymentTimeline**
   - Shows payment history (date | amount | status)
   - Timeline line + dots per transaction
   - Status badges (completed, pending, failed)
   - Used in: MyBookingsScreen

3. **EmptyState with actions**
   - Current EmptyState is text-only
   - Needs action button (not just link)
   - Example: "No available times. [Browse dates]"
   - Used in: TimeSlot selection, booking history

**Implementation**:
```
Weeks 5-6:
- Create PaymentBreakdown component + tests
- Create PaymentTimeline component + tests
- Update EmptyState component to support buttons
- Document in design system
- Add to UI kit stories
```

---

### 9. Screen Maturity Scores

| Screen | Completion | Issues | Priority |
|--------|-----------|--------|----------|
| BookingConfirmationScreen | 85% | Missing share + calendar buttons, payment review | High |
| ProviderDetailScreen | 60% | Oversized, image carousel glitchy, no share | High |
| MyBookingsScreen | 80% | No payment history, no filtering, spacing issues | High |
| DashboardScreen (admin) | 85% | Charts don't resize, sidebar nav issues | Medium |
| BillingScreen (admin) | 85% | Slow load, payout history pagination broken | Medium |

---

### 10. Additional Findings

**Performance issues**:
- ProviderDetailScreen takes 2+ seconds to load (large image fetches)
- MyBookingsScreen pagination loads all items (should lazy-load)
- Fix: Implement image caching, lazy-load with pagination

**Responsive navigation**:
- BottomNavigation doesn't adapt to landscape (overlaps content)
- Desktop admin uses hamburger on tablet (should use sidebar)
- Fix: Use `MediaQuery.of(context).size.width` to switch nav layouts

**Dark mode inconsistencies**:
- Some screens don't switch properly (cached colors)
- Elevation shadows too dark on dark background
- Fix: Clear cached theme on mode switch, verify all elevations

**Error recovery**:
- Failed payment shows generic "Error" message
- No retry button on network errors
- Fix: Human-readable messages + recovery actions

---

## Summary of Work Items

### Critical (1-2 weeks) — Do first
- [ ] Create PaymentReviewScreen
- [ ] Create BookingSettingsScreen in SalonDetailScreen
- [ ] Add share/calendar buttons to BookingConfirmationScreen
- [ ] Add payment history to MyBookingsScreen
- [ ] Create PaymentBreakdown + PaymentTimeline components

### High (3-4 weeks) — Do next
- [ ] Standardize card spacing and hierarchy
- [ ] Fix responsive design (landscape, form overflow)
- [ ] Add accessibility (labels, focus states, contrast)
- [ ] Complete localization (money format, translations, dates)

### Medium (5+ weeks) — Long-term
- [ ] Performance optimization (image caching, lazy-loading)
- [ ] Navigation redesign (responsive sidebar/nav)
- [ ] Dark mode fixes (color cache, elevation)
- [ ] Error handling improvements

---

## Validation Checklist

Before shipping each screen update:

- [ ] Tested on phone (375px portrait)
- [ ] Tested on phone landscape (667px)
- [ ] Tested on tablet (768px)
- [ ] Tested on desktop (1440px)
- [ ] Spacing matches 4pt scale
- [ ] Colors match design system tokens
- [ ] All interactive elements have semantic labels
- [ ] Focus states visible (keyboard navigation)
- [ ] Text contrast ≥ 4.5:1 (WCAG AA)
- [ ] Localized (Kazakh, Russian, English)
- [ ] Dark mode works correctly
- [ ] No console errors or warnings
- [ ] Performance acceptable (< 2 seconds load)
