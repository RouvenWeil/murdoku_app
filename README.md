# Murdoku

A small Android version of my Murdoku logic puzzles, built in Flutter. The point of this MVP is to get the cases, the board controls and the overall look right before adding anything else.

## The five cases

I'm using these five cases on purpose. They give me a useful mix of board shapes and visual features without having to support the entire case library yet.

| Case | Board | What it covers |
| --- | --- | --- |
| Car Repair | 6 × 6 | Small board, room labels, full portrait set |
| A Horse With No Name | 6 × 6 | Missing/blocked cells, second portrait set |
| River Crossing | 10 × 9 | Rectangular board, outdoor scenery |
| The Art Museum Heist | 9 × 9 | Objects, walls, distinct rooms |
| The Golf Course | 16 × 16 | Large board, partial view and minimap |

The case JSON files still define the actual puzzle: dimensions, available cells, suspects and solutions. The PNGs are **only the artwork**. A picture cannot decide where a player is allowed to place someone or whether a submission is correct.

## Why the boards use PNGs

I already have finished board images with the walls, objects, colors and room names in the right places. Rebuilding all of that from SVGs and a second drawing system would just add work and introduce small differences. So I'm using one complete PNG per case as the background.

The game still knows every cell by its row and column. Flutter draws the things the player changes on top: notes, crosses, placed characters, hold progress, the submitted-result rings and the minimap viewport. Moving around the board moves the PNG and the marks together. The main board, the minimap and the catalogue thumbnails all use this same setup.

The PNG is stretched to the exact board grid on purpose. Its edges are the edges of the board, not an image that should be cropped with `BoxFit.cover`. If I replace one, it needs to keep the same full-grid framing. The original grid painter remains as a fallback for test cases and missing artwork.

Images are in `assets/boards/`. The two portrait sets I have are in `assets/characters/car-repair/` and `assets/characters/horse-with-no-name/`. Museum, river and golf portraits are still placeholders. I don't want to pass them off as finished art.

## Playing a case

The catalogue shows a small board preview and the current attempt: **Not started**, **In progress** or **Solved**. A solved case gets a `CASE SOLVED` overlay. PLAY AGAIN starts a new attempt, so I deliberately don't keep a separate historical "solved once" badge. If a saved game cannot be read, the catalogue shows that as a problem to recover, not as a new case.

Inside a case:

- Select a character in the clue list. Tap a cell to toggle a note, or drag to paint notes across cells. Each visited cell can be undone separately.
- Pause on an eligible cell and complete the hold ring to place the selected character. Moving to another cell restarts the hold. A second finger cancels placement and lets you pan the board.
- Use Cross, Erase and Undo as needed. Holding Erase clears the board; I removed the extra "hold to reset" caption to keep the toolbar cleaner.
- Submit only once all characters are placed. The result rings show the **last submission**, not live hints. Editing a cell can remove its old feedback. PLAY AGAIN replaces the solved attempt with an empty one.
- On larger boards, drag with two fingers and use the minimap to jump around. There is no pinch zoom. The initial board cell size is intended to stay at least 48dp.

I kept the clue pin separate from character selection. Pinning a clue should not change whom I'm trying to place on the board.

## Project layout

| Path | Purpose |
| --- | --- |
| `assets/cases/` | Five case definitions; puzzle data stays here |
| `assets/boards/` | Full-grid board backgrounds for those cases |
| `assets/characters/` | Character portraits where available |
| `lib/domain/` | Board data, case rules and solution checks |
| `lib/session/` | One active game session and foreground timekeeping |
| `lib/data/progress/` | Versioned local saves, loading and recovery |
| `lib/ui/board/board_scene.dart` | The shared image-underlay + player-overlay composition |
| `lib/ui/board/board_scene_painter.dart` | Player marks, submission feedback and fallback grid |
| `lib/ui/widgets/board_viewport_stub.dart` | Gameplay touch handling and partial-board navigation |
| `lib/ui/widgets/tool_panel_stub.dart` | Tools and the interactive minimap |
| `lib/ui/widgets/case_preview.dart` | Read-only board thumbnails and attempt status |
| `lib/ui/screens/` | Case catalogue and responsive case screen |
| `test/` | Puzzle, storage, interaction and layout tests |

The UI can display progress, but it does not own a second board or check answers independently. The `GameSession` and `GameProgressStore` remain the source of truth.

## Running it

From the Flutter project directory:

```powershell
flutter pub get
dart format lib test
flutter analyze
flutter test
flutter run
```

The save system uses `path_provider` to keep progress in the app's private storage. Changing cases or leaving a screen must not silently discard an unfinished attempt. If a file is unreadable, the recovery flow keeps the damaged file until I explicitly archive it. Save and recovery behavior still needs real Android checks, including a process kill and reopening the app.

## What still needs checking

This README describes the implementation and choices, not a claim that every part has been tested on a phone. Before calling the MVP done, I want to check all five backgrounds against the actual cell hitboxes; panning and minimap alignment; the catalogue at phone sizes; and the 16 × 16 board on a real device. Text scaling and TalkBack need a real-device pass too.

The current case route still prefers/forces landscape, and portrait play needs a separate decision before it meets the no-orientation-lock goal. The missing portraits for three cases also remain open. I am not adding a tutorial, leaderboard or new game mechanics as part of this UI pass.

## A few decisions I don't want to lose

I'm keeping the 4dp board-mark strokes, the 8dp inset around placed marks, the readable clue typography, and the logo credit `by Manuel Garand` even at narrow widths. The catalogue reflects the *current* attempt, not historical achievements. The five cases are intentional, even though some are more complicated than the original MVP.

The goal is to finish this small game properly, not to turn the MVP into a framework for puzzles that aren't even in the app yet.
