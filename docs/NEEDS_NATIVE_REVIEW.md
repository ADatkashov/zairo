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

The platform admin console (`apps/business_admin`, `features/platform_admin`)
was localized in one pass: ~110 new `pa*` keys in `app_en/ru/kk.arb`. The Kazakh
(and Russian) wording was written without a native speaker. Worth a read-through,
especially: role names (`paRoleAdmin`, `paRoleModerator`, `paRoleSupport`), the
catalog level names (`paLevelSpheres` "Салалар", `paLevelSubspheres`
"Ішкі салалар"), the audit-log action labels (`paAction*`) and the confirmation
dialogs (`paSuspendMessage`, `paHideMessage`, `paStaffDeactivateMessage`).
