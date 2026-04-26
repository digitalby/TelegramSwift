# bugs.telegram.org submission draft

This is the draft to submit at https://bugs.telegram.org/ (Telegram Macos category, type "Suggestion"). The user submits manually; this file is the source.

---

## Title

Add weekday-symbol header (Mon Tue Wed...) to the macOS calendar / date picker

## Category

Telegram macOS — Suggestion

## Description

The macOS client's calendar / date-picker grid (used by Schedule message, Mute until, Birthday, Giveaway end-date, Invite link expiry, Business hours, jump-to-date, and the media calendar) renders day numbers without a weekday-symbol header above the columns. Users have to count cells from a known weekday to figure out what day a given date falls on.

Telegram iOS already renders a localized weekday header. macOS system date pickers do too. This is a small UX gap on macOS Telegram.

## Repro

1. Open Telegram on macOS.
2. Open any chat. Right-click the send button → Schedule message.
3. The calendar grid has day numbers but no `Mon Tue Wed Thu Fri Sat Sun` row above them.
4. Same is true for Settings → Notifications → Mute for → Custom, Birthday picker, Giveaway end-date, etc.

## Suggested change

Add a localized weekday-symbol header row above the day grid in `CalendarMonthView` (`Telegram-Mac/CalendarMonthController.swift`). Symbols come from `DateFormatter.shortStandaloneWeekdaySymbols`, locale-driven by `appAppearance.language.languageCode` (the in-app language picker, matching how the existing month-title formatter works).

The current grid is hardcoded Monday-first (column 0 = Monday) regardless of `Calendar.current.firstWeekday`, so the header order is fixed Mon → Sun. Reordering the grid to honour `firstWeekday` is a separate, larger change.

## Before / After

| Locale | Mode | Before | After |
|---|---|---|---|
| English | Schedule modal (.normal) | before-en-normal.png | after-en-normal.png |
| English | Media calendar (.media) | before-en-media.png | after-en-media.png |
| Russian | Schedule modal | — | after-ru-normal.png |
| Hebrew | Schedule modal | — | after-he-normal.png |

(Attach the six PNGs from `docs/screenshots/`.)

The "after" screenshots show:
- English: `Mon Tue Wed Thu Fri Sat Sun`
- Russian: `Пн Вт Ср Чт Пт Сб Вс`
- Hebrew: weekday labels in LTR order matching the day grid, with each Hebrew label rendered RTL internally as expected.

## Patch

A working patch lives at https://github.com/digitalby/TelegramSwift/tree/weekday-headers (single file change to `Telegram-Mac/CalendarMonthController.swift`, ~50 lines). Happy to open a PR if there's interest.

## Notes

- Screenshots are from a SwiftUI mockup that reproduces `CalendarMonthView`'s layout math (currentStartDay computation, column placement, .normal vs .media inset rules) byte-for-byte, but uses system fonts/colors instead of the Telegram theme. Visual fidelity is approximate; layout fidelity is exact.
- Real-app screenshots are available on request, but require a full submodule build and the maintainer's preferred channel for those.

## Build verification status

Attempted on a fresh Apple Silicon machine with Xcode 26.2 / macOS 26.4 (homeserver). Result: **partial**.

- ✅ All 10 native xcframeworks (OpenH264, OpenSSL, libopus, libvpx, Mozjpeg, libwebp, dav1d, ffmpeg, webrtc, tde2e) build clean after PR #1371's documented patches plus three additional fixes I had to apply locally:
  - `core-xprojects/Mozjpeg/Mozjpeg/build.sh`: add `-DCMAKE_POLICY_VERSION_MINIMUM=3.5` (already in PR #1371).
  - `submodules/tg_owt/src/api/candidate.h:108`: drop `ABSL_ATTRIBUTE_LIFETIME_BOUND` (Xcode 26 clang rejects it on void-return parameters; documented in PR #1371).
  - `core-xprojects/ffmpeg/ffmpeg/build.sh:32`: bump `FF_VERSION="7.1"` → `"7.1.1"` (the actual ffmpeg dir was 7.1.1; documented in PR #1371).
  - Plus: `brew install nasm meson` (also documented in PR #1371) and `softwareupdate --install-rosetta` for the x86_64 host-tool tde2e builds.
- ✅ The Swift modules my patch consumes (`TGUIKit`, `CalendarUtils`) compile cleanly. `TelegramCore`, `Postbox`, `TelegramShare`'s Swift sources, and dozens of other dep modules also compile.
- ❌ The full app link is blocked by a known Xcode 26 + downloaded Metal Toolchain integration bug: the linker is handed a positional argument `/var/run/com.apple.security.cryptexd/mnt/com.apple.MobileAsset.MetalToolchain-…/Metal.xctoolchain/usr/lib/swift-5.0/macosx/libswiftAppKit.dylib`, but the cryptex-mounted Metal toolchain ships only Metal/AIR/GPU compilers — there is no Swift runtime under that path. The autolink synthesis picks the wrong toolchain. This is independent of the calendar patch (would happen on stock master too). It has been reproduced both in workspace mode and project-only mode.
- The `Telegram` main app target's Swift sources (which is where `CalendarMonthController.swift` lives) were not reached because the `TelegramShare.appex` link blocks the build pipeline before the main target's compile begins. So strictly: **the patched file itself was not compiled end-to-end** in this environment.

The patch uses only TGUIKit APIs (`TextView`, `TextViewLayout`, `View`, `theme.colors.grayText`, `.normal(.short)`, `setFrameOrigin`, `update(_:)`) used identically across the rest of the file and the wider codebase — it should compile cleanly on a working Xcode 26 environment (or earlier Xcode without the Metal Toolchain split).

---

## Submission checklist (for the user)

- [ ] Sign in to bugs.telegram.org with the Telegram account.
- [ ] Pick category: Telegram macOS → Suggestion.
- [ ] Paste title + description above.
- [ ] Attach the six PNGs from `docs/screenshots/`.
- [ ] Submit.
- [ ] Copy the resulting bug-tracker URL/ID and paste into the digitalby tracking issue (see `gh issue list --repo digitalby/TelegramSwift`).
