# NIGHT SHIFT: STATION ZERO

GitHub Game Off 2026 — theme **SHIFT**. Godot 4.6 sci-fi SCADA control-room survival game.

Current development version: **V0.5 Audio & Atmosphere** (unverified locally), built on the balanced V0.4 circuit-breaker gameplay.

## Getting started

Open `project.godot` using Godot 4.6, then press F5 to run.

## Controls

| Keys | Action |
| --- | --- |
| Q/A | Life-support power up/down |
| W/S | Cooling power up/down |
| E/D | Communications power up/down |
| B | Battery connection |
| C | Acknowledge alarm |
| 1/2/3 | Reset corresponding breaker after cooldown |
| M | Toggle all game audio on/off |
| R | Restart |
| F11 | Toggle maximized/windowed |
| Esc | Exit |

Survive a 120-second shift while balancing reactor output, battery reserves, subsystem integrity, and electrical breaker trips.

## Audio (V0.5)

All sounds are generated in GDScript without external audio files: a quiet station hum, event clicks, breaker trips, warning/critical alarms and end-of-shift cues. **M** toggles sound. Acknowledging alarms with **C** silences the current alarm tone but does not fix the underlying electrical problem.

**Testing:** V0.5 is committed to GitHub but has not been executed in the Godot editor here. Keep your tested V0.4 copy as a fallback and report any parser/runtime errors before relying on this for the game jam.

## Licensing

- Source code: [MIT License](LICENSE)
- Original creative assets: [All rights reserved](ASSET-LICENSE.md)
- Any third-party assets retain their respective licenses.

This game uses AI assistance for development; disclose this in the jam entry.

The console is fictional and is not a real electrical-system simulator.
