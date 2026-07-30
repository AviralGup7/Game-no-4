# Large Print Futoshiki

An offline, large-print, no-timer Futoshiki built for older adults.
Accessibility is the product, not a settings screen.

**Status:** builds and ships. Release APK and Play AAB both verified building
from this repo. Not yet run on a physical device.

| Artifact | Size | Verified |
|---|---|---|
| `app-release.apk` (arm64, R8) | 18.7 MB | ✅ builds |
| `app-release.aab` (Play) | 45.1 MB | ✅ builds |

Toolchain: Flutter 3.35.7 · JDK 21 · SDK 36 / build-tools 35.0.0.
See [RELEASE.md](RELEASE.md).

---

## Audio

Eight sound effects and three background-music tracks, all **CC0** (Kenney
*Interface Sounds*, MintoDog *Cozy Puzzle*). Full provenance in
[`ATTRIBUTION.md`](ATTRIBUTION.md); `tool/verify_assets.sh` checks in CI that
every path referenced in Dart exists, decodes, is long enough to be audible,
is declared in `pubspec.yaml`, and is attributed.

Background music **defaults to OFF** — audio that starts unasked is an
uninstall trigger for this audience. Sound effects default on, mono and quiet.
A wrong entry plays a soft click, never a buzzer. If the audio plugin is
unavailable the app runs silently rather than crashing.

## Why Futoshiki

Game #4 in a portfolio strategy, scoring 75.5 on the opportunity model. The
market read: **very thin competition** with a small but loyal audience — the
classic blue-ocean profile. Unlike sudoku (where Sudoku.com owns the head
term) there is no dominant incumbent to displace.

| Typical puzzle app | This app |
|---|---|
| Small numerals | Opens at 115%; 85–160% slider with live preview |
| Countdown timers | **No countdown ever** — elapsed clock only |
| Ads mid-puzzle | Interstitials only *after* a win, 1-in-3, 150 s floor |
| Assumes you know the rules | Onboarding explains the arrows |
| Colour-only error marking | Colour **+** underline **+** shake |
| Subscription | One-time "remove ads" purchase |

---

## Correctness

The non-negotiable invariant: **every generated puzzle has exactly one
solution.** A player who satisfies every visible constraint and is still told
they're wrong concludes the app is broken.

Generation uses the **dig-out method**: start from a fully revealed Latin
square, then remove givens one at a time, keeping a removal only while
uniqueness holds. That guarantees uniqueness *by construction* rather than by
rejection — which matters, because on game #3 (Kakuro) rejection-based
generation failed 60/60 times and needed a full redesign. Here it worked on
the first attempt.

**Measured:** 32/32 puzzles unique, worst case 69 ms (7×7). Given counts scale
sensibly — 1.5/16 on Gentle up to 10.9/49 on Hard.

### Test coverage — 34 tests

| Suite | What it proves |
|---|---|
| `engine_test.dart` (16) | Unique solutions; solver agrees with stored solution; solution is a valid Latin square; every sign points the correct way; signs only join adjacent cells; hints always correct |
| `app_test.dart` (18) | Accessibility defaults; streak logic; undo restores pencil notes; save/resume round-trip; corrupt save fails safe; 56 dp touch targets; **31-day daily sweep** |

```bash
flutter analyze   # clean
flutter test      # 34 tests
```

---

## The interesting layout problem

Inequality signs live **between** cells, not inside them. So the board is not
an N×N grid of equal cells — it is N cells plus N−1 narrow gutters per axis.
Cells take most of the space (numerals must stay large); gutters get just
enough for a legible chevron. Taps landing in a gutter map to the nearest cell,
so a shaky aim is never swallowed by a gap.

The number pad shows only 1..N — a 5×5 Futoshiki has no 6, and offering keys
that can never be used is a small but constant source of confusion.

---

## Architecture

```
lib/
  engine/futoshiki_engine.dart  solver, conflict detection, hints
  engine/generator.dart         Latin square, signs, dig-out
  models/game_state.dart        entries, notes, undo, save/resume
  services/                     daily puzzle, settings, progress, ads, IAP
  widgets/                      CustomPainter board, theme
  screens/                      home, game, settings, how-to-play
tool/
  generate_icons.py             deterministic branding
  make_keystore.sh              one-time signing setup
```

The engine has **no Flutter dependency**, so it unit-tests on a bare Dart VM.
The daily puzzle hashes the calendar date into a seed — same board worldwide,
zero server, fully offline.

---

## Branding is generated, not sourced

`tool/generate_icons.py` deterministically produces 15 icon files plus both
Play graphics — a 2×2 fragment showing `3 > 1`. The amber chevron *is* the
brand: it is the one visual that distinguishes Futoshiki from every other
number-grid puzzle on the store. No AI assets, no licence to track. CI fails
on drift.

---

## Before shipping

- [ ] Replace AdMob **test** IDs (manifest + `lib/services/ads.dart`)
- [ ] Run `./tool/make_keystore.sh`, back up the keystore
- [ ] Create the `remove_ads` IAP product in Play Console
- [ ] Test on a real device — **and with an actual older adult**

Do **not** claim cognitive or medical benefits; Lumosity paid a $2M FTC
settlement for exactly that.

## Licence

MIT — see `LICENSE`.
