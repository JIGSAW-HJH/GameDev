# NIGHT SHIFT: STATION ZERO

**GitHub Game Off 2026** — theme **SHIFT**. Single-screen, SCADA-inspired sci-fi engineering survival game built with **Godot 4.6**.

**Current development:** V0.6 menu, saving and settings, layered onto the tested V0.5 gameplay. V0.6 still needs an in-editor playtest.

## Start

1. Import `project.godot` using the standard Godot 4.6 editor.
2. Press **F5**. The game starts in full-screen at its **Main Menu**.
3. Choose **New Shift** to play, or **Continue Saved Shift** if you previously saved.

## Menus

- **Main Menu:** New Shift, Continue Saved Shift, Settings, Exit Game.
- **Esc during gameplay:** Pause menu: Resume, Save, Load, New Shift, Settings, Main Menu, Exit.
- **Settings:** Master, ambience, effects and alarm volume; mute audio; remap gameplay keys; restore default controls.
- Esc is reserved for pause/back, and duplicate key assignments are prevented.
- Changing settings automatically stores them for future launches.

## Default keys

| Keys | Action |
| --- | --- |
| Q / A | Life-support power up / down |
| W / S | Cooling power up / down |
| E / D | Communications power up / down |
| B | Connect / disconnect battery |
| C | Acknowledge alarm |
| 1 / 2 / 3 | Reset corresponding breaker after cooldown |
| M | Toggle game sound |
| Esc | Pause / back |

## Save files

A single manual save slot stores the running shift's remaining time, demands, reactor state, battery, integrity, breaker cooldowns and event log. To save, press **Esc → Save Shift**. On the next launch, use **Continue Saved Shift**.

Saves and settings are stored locally in Godot's `user://` directory, not in this repository. The game does not automatically save or upload these files. A finished or failed shift is not eligible for saving.

## Development notes

The battery and integrity balancing remain unchanged from the successful V0.3.1 playtest. Audio is procedurally generated in GDScript with no third-party sound files.

## Licensing

- [MIT License](LICENSE) — source code
- [All Rights Reserved](ASSET-LICENSE.md) — original creative assets
- Third-party assets, if any are added, retain their original licenses.

AI tools were used to assist development and will be disclosed in the game-jam submission.

**Testing status:** The code is committed but V0.6 has not been executed in Godot by the assistant. Keep a local backup of the tested V0.5 version.
