# NIGHT SHIFT: STATION ZERO

**GitHub Game Off 2026** — theme **SHIFT**. Single-screen science-fiction engineering survival game built using **Godot 4.6**.

**Current candidate: V0.7.1 — Scrollable Engineering Recorder** (not yet playtested in the Godot editor). Previous V0.6 was tested successfully.

## Running

1. Open `project.godot` in Godot 4.6.
2. Press **F5**. The game opens full-screen with the main menu.
3. Select **New Campaign** to start at Shift 1, or load a saved campaign.

## Campaign

| Shift | Mechanic added | Approx. shift duration |
| --- | --- | --- |
| 1–2 | Easy power allocation training; no breaker trips or reactor sag | 90 s |
| 3–4 | Circuit breakers trip; reset after cooldown | 105 s |
| 5–6 | Temporary reduction in reactor output | 120 s |
| 7+ | Auxiliary stabiliser maintenance added; gradually longer shifts | 135–240 s |

Events become gradually more frequent, though the balanced V0.3.1 battery, recovery and integrity-damage rates are retained. This is an arcade simulation, not a real electrical model.

When you win, select **Start Next Shift**. After a loss select **Retry This Shift**. The result screen reports number of events, breaker trips, remaining battery and mean integrity.

## Event recorder and small-screen layout

The engineering event recorder now has its own vertical scrollbar and retains up to 150 log entries. Newest messages appear first, and the viewer returns to the top whenever a new event is logged. The complete control-room page can also scroll on monitors where the whole interface does not fit vertically; this prevents the bottom controls from being clipped.

## Menu and saves

The main menu offers New Campaign, Continue / Load Game, How to Play, Settings, Credits and Exit. In game, **Esc** opens a pause menu with Resume, Save, Load, Settings, How to Play and exit/navigation options.

There are **three local manual save slots**, stored in Godot's `user://` directory. A save stores shift number, power allocation, timer, reactor and battery status, integrity, breaker state, and the auxiliary maintenance state. Saving after winning creates a checkpoint at the start of the next shift. Loading legacy V0.6 `station_zero_save.json` saves is also supported.

The key mapping and audio volume preferences are saved independently using Godot's local ConfigFile.

## Default keys

| Key | Action |
| --- | --- |
| Q / A | Increase / decrease life-support allocation |
| W / S | Increase / decrease cooling allocation |
| E / D | Increase / decrease communications allocation |
| B | Connect / disconnect backup battery |
| C | Acknowledge current alarm |
| 1 / 2 / 3 | Reset respective breaker after cooldown (Shift 3+) |
| T | Service auxiliary stabiliser when available (Shift 7+) |
| M | Toggle audio |
| Esc | Pause / back |

Key mappings can be changed in **Settings**. Esc is reserved.

## License and credits

- [MIT License](LICENSE) for original source code
- [All rights reserved](ASSET-LICENSE.md) for original creative game assets
- Third-party assets retain their own licenses, and must be attributed when used
- Game creator: JIGSAW-HJH
- Godot Engine by its contributors
- AI assistance: OpenAI ChatGPT assisted with game design, coding and technical development; this should be disclosed when submitting to the jam.

## Testing status

V0.7.1 was committed to GitHub but **has not been verified inside Godot 4.6** here. The previously tested V0.6 should be retained as a local backup. Please test the first shift, Shift 3 breaker introduction, Shift 5 reactor sag, Shift 7 auxiliary maintenance, save-slot overwrite/loading, and full-screen pause navigation before distribution.
