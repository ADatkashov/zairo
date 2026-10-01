# Factory Design System Documentation

**Design System for**: Flutter + Spring Boot service marketplace platform  
**Verticals**: Beauty (salons, stylists), Auto (workshops, mechanics)  
**Apps**: user_app (customer), business_admin (owner/staff)  
**Status**: Comprehensive system with 24 React components + full token set

---

## Overview

The Factory Design System is a comprehensive design language built directly from the ZAIRO repository's `packages/core_ui/` Flutter widgets. It provides:

- Complete token set (colors, typography, spacing, radius, elevation, motion)
- 24 React UI component primitives (translated from Flutter)
- Two interactive UI kits (customer app + admin app)
- Foundation guidelines for content, brand, and visual principles

**Important**: "Factory" is a working codename, not the final brand.

---

## Visual Foundations

### Palette

**Stone Neutral** (warm off-white background, near-black text)
- Background: `#F7F6F3`
- Text: `#0F0E0C`
- Borders: `#E5E4E0`

**Pine Primary** (deep teal-green — main action/selection color)
- Light mode: `#1B5C52`
- Dark mode: `#4FCFB4` (brighter mint)

**Gold Accent** (tertiary — highlights, selected states)
- `#C99A3E`

**Dark Mode** (separately tuned, not inverted)
- Background: `#0F0E0C` (warm near-black)
- Primary: `#4FCFB4` (bright mint)
- Shadows: Light "glow" (warm near-white, low alpha)

### Typography

**Three typefaces, one system:**

1. **Unbounded** (Google Fonts)
   - Use case: Headline moments only (w600–700)
   - Sizes: Display/Large (up to 56px)

2. **Golos Text** (Google Fonts)
   - Use case: Everything else (UI, body, labels)
   - Supports native Cyrillic + Latin
   - Sizes: All body, headline small, label sizes

3. **JetBrains Mono** (Google Fonts)
   - Use case: Prices, times, distances
   - Always tabular figures
   - Example: `12 400 ₸` (space-grouped thousands)

**Type scale** (named system):
- `displayLarge`, `displayMedium`, `displaySmall`
- `headlineLarge`, `headlineMedium`, `headlineSmall`
- `titleLarge`, `titleMedium`, `titleSmall`
- `bodyLarge`, `bodyMedium`, `bodySmall`
- `labelLarge`, `labelMedium`, `labelSmall`

### Spacing

**Strict 4pt scale** — no ad-hoc values:
- `4px`, `8px`, `12px`, `16px`, `20px`, `24px`, `32px`, `40px`, `48px`

Applied to:
- Padding (component interior)
- Margin (component exterior)
- Gaps (between sibling elements in flex/grid)

### Radius

**Modest, considered corners** — never bubbly:
- `8px` — small components (buttons, badges)
- `12px` — default (cards, inputs)
- `16px` — larger surfaces (sheets, dialogs)
- `24px` — maximum (rarely used)
- `999px` — reserved for chips and status badges only

### Elevation & Shadows

**At rest**: Border only (`1px` in `--factory-border` color)

**Hover/Press state** (`sm` elevation):
- Soft double-layer shadow
- Micro-lift effect (subtle scale)

**Raised cards** (`md` elevation — provider/service cards):
- Border remains
- Soft double-layer shadow adds on top

**Floating UI** (`lg` elevation — sheets, dialogs):
- Border + strongest shadow
- Dark mode: Light "glow" (never black)

### Motion

**Confirms state changes, never performs** — no decorative animation:
- Three durations only: `120ms`, `200ms`, `320ms`
- One easing curve: `cubic-bezier(0.2,0,0,1)` (M3 emphasized-decelerate)
- Never bouncy, elastic, or scale/shrink effects

### Imagery & Backgrounds

**Flat color only**:
- No photography-driven heroes
- No gradients (except one specific: `_AvailabilityHero` `primaryStrong → primary`)
- No hand-drawn illustration
- No repeating pattern/texture

**Photo placeholders**:
- Tinted gradient: `primaryTint → surfaceAlt`
- Real photography needed before ship

---

## Components

### Core Primitives (8)

**Button**
- Variants: Default, Outline, Text, Disabled
- Sizes: Large, Medium, Small
- Interactive states: Hover (brightness-darkened), Press (ripple), Focus (outline)

**IconButton**
- Circular or square (compact)
- Variants: Default, Outline, Text
- Uses Material Symbols Rounded

**Card**
- Base: 1px border, 16px radius
- Padding: 16px
- Elevation variants: rest (border only), hover (sm), raised (md)
- Clickable cards can have ripple on press

**Badge**
- Variants: Default (filled), Outline
- Colors: Primary, Accent, Neutral (gray)
- Sizes: Medium, Small
- Used for status, count labels

**Chip**
- Pill-shaped (`999px` radius)
- Closable variant (with X icon)
- Selection state: border color + fill tint
- Interactive states: Hover, Press, Selected

**TextField**
- Label (always present, never placeholder-only)
- Variants: Default, Outline, Filled
- States: Focused, Disabled, Error
- Error messages below (never red text alone)

**SearchField**
- Leading search icon (Material Symbols)
- Clear button on interaction
- Placeholder text (secondary color)

**Avatar**
- Circle by default
- Sizes: Large (56px), Medium (40px), Small (32px)
- Fallback to initials or color-coded background
- Border variant for selection

### Navigation (2)

**AppBar**
- Height: 56px
- Leading (back icon), Title (center), Trailing (actions)
- Sticky at top of screen
- No shadow (border only when needed)
- Mobile: Full width
- Desktop: Sidebar alternative (NavigationRail equivalent)

**BottomNavigation**
- Height: 80px (includes safe area)
- Labels + Icons (Material Symbols Rounded)
- Five tabs (Home, Search, Bookings, Favorites, Profile)
- Selected: Pine primary color + filled icon
- Unselected: Gray icon
- Sticky at bottom

### Feedback (6)

**Dialog**
- Centered on screen
- 8px radius on corners
- Backdrop (semi-transparent black)
- Content: Headline + Body + Actions (typically 2 buttons)
- Actions: Primary button (right), Secondary/Cancel (left)

**BottomSheet**
- Floats from bottom
- Rounded top corners (16px)
- Swipe-to-close gesture
- Content: Headline, Body, Actions
- Responsive: Full width on mobile, centered width on tablet/desktop

**EmptyState**
- Large icon (Material Symbols, 56px)
- Headline (sentence case)
- Body text (plain language with path forward)
- Action button (never empty state without an action)
- Example: *"No available times today. Try another date."* + [Browse dates] button

**ErrorState**
- Error icon (Material Symbols, red)
- Headline: *"Something went wrong"*
- Body: Human-readable error message (never raw exception)
- Action: Retry button or back link

**LoadingState**
- Circular progress indicator
- Optional label below
- Never overlay content (use skeleton instead)

**Skeleton**
- Placeholder animated lines
- Match target component size/shape
- Gray background with shimmer animation
- Shows content loading in real-time

### Content Components (8)

**CategoryTile**
- Square card (aspect 1:1)
- Icon (Material Symbols, optional emoji if admin-set)
- Label (category name, sentence case)
- Tap selects category

**ServiceCard**
- Vertical card layout
- Image (gradient placeholder if no photo)
- Service name + price (mono typeface, ₸)
- Rating label
- Tap opens service detail

**ProviderCard**
- Vertical card layout (like ServiceCard)
- Avatar + name (heading)
- Location (secondary text)
- Rating + review count
- Image carousel (with fade indicators)
- Favorite button (translucent overlay)
- Tap opens provider detail

**SelectableTile**
- Horizontal card with checkbox/radio
- Icon/avatar (left), Label + description (center), Selection control (right)
- States: Selected (border + fill), Unselected
- Example: Service selection in booking flow

**SectionHeader**
- Label (uppercase, small type)
- Optional action link (right-aligned)
- Divider line (optional below)

**StatTile**
- Large number (headline style)
- Small label below (gray)
- Optional icon (corner)
- Used for dashboards (bookings count, revenue, etc.)

**TimeSlot**
- Pill-shaped button
- Time text (24-hour format)
- Availability state: Available (primary), Unavailable (dashed border + strikethrough)
- Selection: Filled background + check

**PriceText**
- Mono typeface (tabular figures)
- Space-grouped thousands: `12 400 ₸`
- Optional label ("From:" / "Total:")
- Color: Primary or accent

**RatingLabel**
- Star icon (Material Symbols Rounded, filled/outlined)
- Number (small, secondary color)
- Example: *"4.8 (234 reviews)"*
- Used on provider/service cards

### Brand (1)

**Logomark** (Module Mark)
- Three filled rounded squares (Core + first vertical, accent gold)
- One dashed/open square (next vertical slot, unbuilt on purpose)
- Confirmed from `apps/user_app/assets/icon/user_app_icon.png`
- Below ~32px: Dashed block swapped for flat "quiet" block
- No wordmark/lockup in source — render "Factory" (or real brand) in display type next to mark

**No other logo/illustration/photography assets exist** in the repository.

---

## Content Principles

### Voice & Tone

- **Second person implied** through UI labels, not narrated
  - ✅ "My bookings" (not "Your bookings, Almas!")
  - ✅ Greetings use first name: *"Good afternoon, {name}"*
- **Plain and functional**, not playful
  - Task labels: "Book", "Cancel booking", "Add another business"
  - Short confirmations, no exclamation marks, no emoji in product UI
  
### Casing

- **Sentence case everywhere**: buttons, titles, section headers
- Never Title Case, never ALL-CAPS (except tiny label chrome: 11–13px uppercase tracking on `labelSmall`/`labelMedium` only)
- Example: *"Add new address"* (not "Add New Address")

### Numbers

- **Prices/times/durations**: Always rendered in mono type role
- **Space-grouped thousands**: `12 400 ₸` (not `12,400 ₸`)
- **Named rule**: `formatFactoryAmount()` — deliberate, not afterthought
- **24-hour time format**: `16:30` (not `4:30 PM`)

### Error Handling

- **Always translated to human sentence** before display
- Never a raw exception on screen (enforced in codebase)
- Include a way forward, not just a problem statement
- Example: *"Payment failed. Check your card details and try again."*

### Localization

**The product ships in Kazakh, Russian, English**:
- Golos Text typeface chosen for native Cyrillic + Latin support
- All copy should assume it will be translated
- Date/time/money formatting must be regional
- Incomplete translations are a Priority 1 bug

---

## Screen Mapping to Source

| Design Asset | Source File | Type |
|---|---|---|
| tokens/colors.css, typography.css, spacing.css, radius.css, elevation.css, motion.css, sizing.css | `packages/core_ui/lib/src/theme/factory_*.dart` | Flutter tokens |
| components/** (24 components) | `packages/core_ui/lib/src/widgets/factory_*.dart` | Flutter widgets |
| assets/brand/logomark*.svg | `apps/user_app/assets/icon/user_app_icon.png` | Brand asset |
| ui_kits/user_app/HomeScreen.jsx | `apps/user_app/lib/features/discovery/presentation/screens/home_screen.dart` | Customer app |
| ui_kits/user_app/BookingsScreen.jsx | `apps/user_app/lib/features/booking/presentation/screens/my_bookings_screen.dart` | Customer app |
| ui_kits/business_admin/index.html (AdminShell) | `apps/business_admin/lib/app/admin_shell.dart` | Admin app |
| ui_kits/business_admin/DashboardScreen.jsx | `apps/business_admin/lib/features/dashboard/presentation/screens/dashboard_screen.dart` | Admin app |

---

## Implementation Guidelines

### When Creating New Components

1. **Match existing token values** — spacing, radius, elevation, motion
2. **Use the type scale** — don't pick arbitrary font sizes
3. **Follow naming conventions** — `factory_*` for Flutter, `Factory*` for React
4. **Test on all platforms** — mobile (portrait/landscape), tablet, desktop
5. **Localization-first** — assume all text will be translated

### When Updating Existing Screens

1. **Validate against this system** — check tokens before inventing new values
2. **Consistent spacing** — use 4pt scale, never ad-hoc margins
3. **Accessible by default** — semantic labels, focus states, contrast checks
4. **Responsive design** — test on phone (320px+), tablet, desktop
5. **Dark mode support** — ensure both themes are legible

### Design System Entry Points

- **For new features**: Start with component inventory → extend if needed
- **For dark mode**: Use provided token values, never invert
- **For accessibility**: Follow semantic HTML, test with keyboard + screen reader
- **For mobile**: Start at ~400px width, scale up gracefully
- **For copy**: Plain language, sentence case, include error recovery

---

## Files in This System

```
styles.css                           → Root stylesheet (import this one file)
tokens/
  ├─ colors.css                      → Primary, accent, neutral, semantic colors
  ├─ typography.css                  → Type scale (headings, body, labels)
  ├─ spacing.css                     → 4pt scale (4/8/12/16/20/24/32/40/48)
  ├─ radius.css                      → Corner radius values (8/12/16/24/pill)
  ├─ elevation.css                   → Shadows (sm/md/lg)
  ├─ motion.css                      → Animation (120/200/320ms, easing)
  └─ sizing.css                      → Component sizes (buttons, avatars, etc.)

assets/
  └─ brand/
      ├─ logomark.svg                → Light mode mark
      └─ logomark-dark.svg           → Dark mode mark

components/
  ├─ core/                           → Button, Card, Badge, Chip, etc. (8)
  ├─ navigation/                     → AppBar, BottomNavigation (2)
  ├─ feedback/                       → Dialog, EmptyState, Skeleton, etc. (6)
  ├─ content/                        → ServiceCard, ProviderCard, etc. (8)
  └─ brand/                          → Logomark (1)

guidelines/
  ├─ colors-*.card.html              → Color palette specimens
  ├─ type-*.card.html                → Typography specimens
  ├─ spacing-scale.card.html         → Spacing scale
  ├─ elevation-scale.card.html       → Elevation examples
  ├─ radius-scale.card.html          → Radius examples
  └─ brand-mark.card.html            → Logo/mark guidelines

ui_kits/
  ├─ user_app/                       → Customer app (7 screens, interactive)
  └─ business_admin/                 → Admin app (4 screens, interactive)

readme.md                            → This system overview
github.md                            → Screen map to source repository
SKILL.md                             → Claude Code skill wrapper
```

---

## Design System Status

✅ **Complete and documented**
- All tokens extracted from `packages/core_ui/`
- 24 React components built from Flutter equivalents
- Two interactive UI kits (customer + admin)
- Full content guidelines

⚠️ **Audit Findings** (see `AUDIT_FINDINGS.md`)
- Payment UX gaps (no review screen, hidden settings)
- Visual design inconsistencies (spacing, card hierarchy)
- Accessibility issues (missing labels, focus states)
- Localization incomplete (translations, money formatting)

🚀 **Next Priority**: Implement audit recommendations (see `IMPLEMENTATION_ROADMAP.md`)
