# Kazakh localization — items needing native-speaker review

Generated during the Phase 4 (production-ready MVP) localization audit,
2026-08-24. This is a **review list, not a to-do list of bugs** — none of
these are confirmed wrong. They were flagged because a non-native-speaker
audit can't tell loanword-parity from a missed translation, and the
project's own rule is to mark such cases for review rather than invent a
"fix" that might be worse than what's there. No ARB values were changed as
a result of this pass.

How these were found: a script diffed every kk key's value against the
matching en/ru value across `app_kk.arb`/`app_ru.arb`/`app_en.arb` in both
`apps/user_app/lib/l10n/` and `apps/business_admin/lib/l10n/`. No keys are
missing or extra in kk relative to en in either app — full key-set parity
already holds. Everything below is a *content* question, not a *coverage*
gap.

## apps/user_app

Keys where the kk value is spelled identically to the ru value (i.e. no
distinctly Kazakh word was used) — most likely intentional loanwords that
are genuinely common in everyday Kazakh, but worth a native check:

| Key | ru / kk value | Note |
|---|---|---|
| `masterPortfolioTitle` | "{masterName} — Портфолио" | "портфолио" as loanword — confirm this is how a Kazakh-speaking user would expect it, vs. a possessive/suffixed form |
| `navProfile` / `profileTitle` | "Профиль" | same question for "профиль" |
| `searchSortRating` | "Рейтинг" | same question for "рейтинг" |
| `registerPhoneLabel` | "Телефон" | universal loanword, low concern |
| `serviceDurationMinutes` | "{minutes} мин" | abbreviation shared with ru; likely fine but confirm "мин" reads naturally in kk context |
| `cardDistanceAndVertical` | "{distanceKm} км · {vertical}" | "км" shared abbreviation; likely fine |
| `emailLabel` | "Email" (same in en/ru/kk) | almost certainly fine as an international term, flagged only for completeness |

Everything else in `app_kk.arb` (189 lines) reads as genuinely translated,
grammatically distinct Kazakh — e.g. `homeAvailabilityHero`, all the
`error*`/`validation*` sentences, `bookingConfirmed*` family — not just
copied Russian.

## apps/business_admin

| Key | ru / kk value | Note |
|---|---|---|
| `phoneLabel` | "Телефон" | same loanword question as above |
| `serviceDurationMinutes` | "{minutes} мин" | same as above |
| `weekdayWed` | ru "Ср", kk "Ср" | **Higher-confidence flag.** All six other weekday abbreviations differ correctly between ru/kk (`Пн`/`Дс`, `Вт`/`Сс`, `Чт`/`Бс`, `Пт`/`Жм`, `Вс`/`Жс` — only `weekdaySat` "Сб" is shared, which is plausible since Сенбі and Суббота both start "С-б"/"С-б"). `Ср` for Kazakh "Сәрсенбі" (Wednesday) skips the vowel "ә" in a way none of the other six abbreviations do — worth confirming this is the actual Kazakh calendar convention and not a copy-paste from the Russian "Среда" abbreviation. Used in the recurring-schedule day-of-week chips (`recurring_schedule_dialog.dart`).

## Not flagged, checked and ruled out as false positives

The audit script's raw heuristics (kk value mostly ASCII, kk identical to
en) also caught these, but they're genuinely correct Kazakh once read in
context, not translation gaps:
- `ratingSemanticLabel` "5-тен {rating}", `starRatingSemanticLabel`
  "{count} жұлдыз қою" — real Kazakh grammar, just heavy on digits/
  placeholders which skewed the ASCII-ratio heuristic.
- `portfolioViewerCounter` "{current} / {total}", business_admin's
  `loginAppBarTitle` "Business Admin — Кіру" — no translatable content
  besides an intentionally-untranslated product/app name.

## Recommendation

Hand this file to a native Kazakh speaker for a yes/no pass on the two
tables above. None of these block the production-ready MVP milestone —
they're all either correct-as-is loanwords or, at worst, a single
weekday-abbreviation character choice.

## Platform console strings (2026-10-05)

The platform console (`apps/platform_admin`) was localized in one pass: ~300
keys in its own `app_en/ru/kk.arb`. The Kazakh (and Russian) wording was
written without a native speaker. Worth a read-through, especially: role names
(`roleAdmin`, `roleModerator`, `roleSupport`), the catalog level names
(`levelSpheres` "Салалар", `levelSubspheres` "Ішкі салалар"), the audit-log
action labels (`action*`), the payout / refund wording (`payout*`, `refund*`,
`reconcile*` — money-related, so precision matters) and the confirmation
dialogs (`suspendMessage`, `catalogHideMessage`, `cityDeleteMessage`,
`payoutMarkPaidMessage`).

## Added 2026-10 (machine-written, please have a Kazakh speaker check)

These keys were missing from `app_kk.arb` (the app showed them in English to
Kazakh users) and were filled in by a non-native pass: the deposit / payment
breakdown texts in both apps (`paymentBreakdownTitle`, `paymentTotalPrice`,
`paymentDepositAmount`, `paymentDepositPercentage`, `paymentRemainingAmount`,
`paymentRemainingInfo`), business_admin's `bookingSettingsTitle`,
`depositPercentageLabel`, `depositPercentageSaved`, and user_app's
`paymentMethodsTitle`, `paymentMethodOnline`, `paymentMethodCash`,
`paymentStatusPending`, `paymentStatusProcessing`,
`bookingConfirmationPaidLabel`, `bookingConfirmationRemainingLabel`,
`bookingPaymentInstructions`, `selectCity`. A `l10n_parity_test.dart` in each
app now fails if a key is added to English without Russian and Kazakh.

## apps/user_app — welcome pages (added 2026-10-12)

Written for the first-launch welcome (`welcomeTitle1..3`, `welcomeBody1..3`,
`welcomeNext`, `welcomeStart`, `welcomeSkip`), **not by a native speaker**. They
read as natural Kazakh to a non-native audit but have not been checked, so they
belong on the same review list as the rest:

| Key | kk value | What to confirm |
|---|---|---|
| `welcomeTitle1` | "Барлық қызметтер жақын жерде" | "жақын жерде" for "nearby" |
| `welcomeBody1` | "Сұлулық, авто және тазалау қызметтері — бір қолданбада." | "авто" as a loanword; "тазалау" for cleaning services |
| `welcomeTitle2` | "Уақытты таңдап, онлайн жазылыңыз" | "жазылыңыз" for "book" (as elsewhere in the app) |
| `welcomeBody2` | "Бос уақытты көріп, бірнеше рет түртіп жазылыңыз." | "бірнеше рет түртіп" for "in a few taps" |
| `welcomeTitle3` | "Қанша төлейтініңіз бірден көрінеді" | word order and "бірден көрінеді" |
| `welcomeBody3` | "Жалпы сома, алдын ала төлем және орнында төленетін қалдық — жазылуды растағанға дейін." | "алдын ала төлем" for deposit, "орнында төленетін қалдық" for the rest paid at the venue |
| `welcomeNext` / `welcomeStart` / `welcomeSkip` | "Әрі қарай" / "Бастау" / "Өткізіп жіберу" | button wording |
| `reviewsTitle` / `reviewsSeeAll` | "Пікірлер" / "Барлық пікір" | "пікір" vs "шолу" for reviews |
| `reviewsBasedOn` | "{count} пікір негізінде" | Kazakh has no plural forms here; "негізінде" for "based on" |
| `reviewsEmptyTitle` / `reviewsEmptyMessage` | "Әзірге пікір жоқ" / "Пікірлер келуден кейін пайда болады. Жазылып, алғашқы болып әсеріңізбен бөлісіңіз." | natural phrasing of "after a visit" |
| `reviewsBusinessReply` | "Бизнестің жауабы" | |
| `reviewsShowMore` / `reviewsError` / `reviewsStarRowSemantic` | "Тағы көрсету" / "Пікірлерді жүктеу мүмкін болмады. Қайталап көріңіз." / "{stars} жұлдыз: {count}" | |
| `reviewsFilterAll` / `reviewsFilterWithText` | "Барлығы" / "Мәтінімен" | filter chips |
| `reviewsSortNewest` / `reviewsSortHighest` / `reviewsSortLowest` | "Алдымен жаңалары" / "Алдымен жоғары бағалар" / "Алдымен төмен бағалар" | sort chips; length on a narrow phone |
| `reviewsNoMatchTitle` / `reviewsNoMatchMessage` / `reviewsResetFilters` | "Сәйкес пікір жоқ" / "Басқа бағаны таңдаңыз немесе барлық пікірді көрсетіңіз." / "Барлығын көрсету" | |
| `navNewBooking` | "Жаңа жазылу" | label of the + button (new booking) |
