# Minedoku

A grid logic puzzle for phones. On an `n x n` board split into `n` coloured
regions, place `n` mines so that:

1. every **row** holds exactly one mine;
2. every **column** holds exactly one mine;
3. every **colour** holds exactly one mine;
4. no two mines **touch**, not even diagonally.

Every board has exactly one solution, and every board can be solved by logic
alone. You never have to guess.

Built with Flutter, so one codebase covers iOS, Android and the web.

## Try it without installing anything

`web-prototype/` builds a single self-contained HTML file that runs the real
engine (the Dart code compiled to JavaScript) behind a small hand-written UI.
Open it in any phone browser.

```bash
./web-prototype/build.sh     # writes web-prototype/minedoku-prototype.html
```

## Repository layout

```
engine/          The puzzle itself: rules, solver, generator, hints.
                 Pure Dart with no Flutter imports, so it runs under `dart test`
                 in about a second.
app/             The Flutter app: screens, board rendering, progress, settings.
web-prototype/   Single-file browser build of the engine, for quick play-testing.
.github/         CI: analyses, tests, and builds an installable Android APK.
```

Keeping the engine separate from the app is the main structural decision here.
The rules are the part most likely to be wrong and the part hardest to debug
through a UI, so they live somewhere they can be tested directly.

## Getting set up from scratch

You need the Flutter SDK. Nothing else.

1. Install Flutter: <https://docs.flutter.dev/get-started/install>
2. Check your machine is ready:

   ```bash
   flutter doctor
   ```

   Fix anything it flags with a red cross. A yellow exclamation mark is usually
   fine to ignore at first.

3. Run the app:

   ```bash
   cd app
   flutter pub get
   flutter run          # pick a device when prompted
   ```

`flutter run -d chrome` is the fastest way to see changes: it needs no phone,
no emulator and no signing.

## Testing on a real phone

**Android, no local setup.** Every push runs the CI workflow, which builds a
debug-signed APK. Open the run in the Actions tab, download the `minedoku-apk`
artifact, unzip it, and open the `.apk` on your phone. Android will ask you to
allow installs from that source.

**Android, from your own machine.** Turn on Developer Options and USB debugging
on the phone, plug it in, then `flutter run`.

**iPhone.** Apple requires a Mac with Xcode to build and sign iOS apps. With a
free Apple ID you can install onto your own device, and the app expires after
seven days. A paid Apple Developer account (99 USD a year) removes that limit
and is required for TestFlight and the App Store.

## Running the tests

```bash
cd engine && dart test          # rules, solver, generator, hints
cd app    && flutter test       # screens and saved progress
```

The engine suite generates and fully verifies boards at every size from 4x4 to
9x9 on each run, so a broken generator fails the build rather than shipping an
unsolvable puzzle.

## How boards are generated

Naively generating a random board and throwing it away unless it happens to
have one solution works up to about 6x6 and then falls apart: at 8x8 fewer than
one in ten attempts succeeds. The generator instead builds every board in three
steps:

1. **Pick the answer first.** Choose a random legal set of mines. This is cheap
   and guarantees the board is solvable.
2. **Grow the colours around it.** Seed one region on each mine and flood-fill
   outward, with lopsided weights so region sizes come out uneven. Even, blobby
   regions barely constrain the player; a two-cell colour pins down part of the
   answer immediately.
3. **Sand off the extra solutions.** While more than one solution exists, move a
   single cell across a region border and keep the change if the solution count
   did not go up. Regions stay connected and the intended answer always
   survives.

Step 3 is what makes the larger boards practical. Every size from 4x4 to 9x9 now
generates on the first attempt, in 60 ms or less on a laptop.

Boards are never stored. A level number maps to a `(size, seed)` pair, and the
generator rebuilds the identical board from it, so the whole campaign costs no
storage and levels can be shared by number. The engine ships its own small
random number generator rather than using `dart:math`, because the sequence in
`Random` is not guaranteed to be stable across Dart versions or platforms, and
level 42 has to be the same board everywhere.

## Themes

Five looks, all playing the identical game: **Enamel** (flat colour, heavy ink),
**Sweeper 95** (grey bevels and a little red flag), **Girlie Pop** (hearts,
glossy, very pink), **Candy** (sweet-shop colours) and **High Contrast**.

Accessibility is built into the theme system rather than bolted on. The central
rule is "one mine per colour", which is unplayable if two colours look the same,
and roughly one man in twelve cannot separate some pairs. So every palette is
measured, not assumed: `app/lib/theme/color_vision.dart` simulates protanopia,
deuteranopia and tritanopia and reports the closest pair in CIELAB. A test holds
each theme to its own claim.

Only High Contrast survives on colour alone, and its palette was found by search
rather than chosen by eye. The other four get per-region **patterns** switched on
automatically, which carry what colour cannot. Patterns can be forced on or off
in Look and feel.

## Hard mode

Off by default, a switch in settings. A mine that cannot be part of the solution
is **refused** rather than placed, and costs one of three mistakes. Spend all
three and the board detonates.

Refusing rather than allowing is deliberate: the mine is known to be wrong, and
leaving a wrong mine on the board while the game says "mistake" reads as a bug.
Marking a cell clear is never punished, only placing a mine.

Counting a legal-but-not-in-the-solution mine as a mistake is fair here in a way
it would not be in a guessing game: every board has exactly one solution and can
be reached by logic alone, so a mine anywhere else is an avoidable error rather
than bad luck.

Hard mode also has **no hints**. Limited mistakes mean little when the answer is
a button press away.

## What is built

- A title screen whose mark animates in, over a board that solves itself.
- Relaxed and hard modes.
- Five themes, plus accessibility patterns.
- Endless campaign, 5x5 up to 9x9, unlocking as you go, with best times.
- A daily puzzle keyed to the date, identical for everyone.
- Practice boards at any size.
- Tap to cycle a cell (clear, then mine, then empty), hold to place a mine.
- Auto-marking of cells a placement rules out, and it can be switched off.
- Undo, redo, clear, and a hint system that explains its reasoning instead of
  just giving the answer away.
- Live rule-breaking feedback, a timer, and saved games that survive closing
  the app.
- Light and dark themes.

## Not built yet

- Sound and richer win animations.
- Store listings, icons and screenshots.
- Any analytics, accounts or networking. The app is entirely offline and stores
  everything on the device.
