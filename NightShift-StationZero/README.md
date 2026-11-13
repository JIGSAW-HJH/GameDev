# NIGHT SHIFT: STATION ZERO

**GitHub Game Off 2026** — theme **SHIFT**. Single-screen science-fiction engineering survival game built using **Godot 4.6**.

**Current candidate: V1.2 — Fixed SCADA Dashboard & Fault-Aware Tabs** (not yet playtested in the Godot editor). Previous V0.6 was tested successfully.

## Running

1. Open `project.godot` in Godot 4.6.
2. Press **F5**. The game opens full-screen with the main menu.
3. Select **New Campaign** to start at Shift 1, or load a saved campaign.

## Fixed gameplay dashboard (V1.2)

The gameplay interface no longer uses a full-page ScrollContainer. **The shift clock, global alarm/acknowledgement, reactor/battery, three power-allocation cards, subsystem integrity, and breaker controls remain visible continuously.** This is intended to eliminate hunting for a control during emergencies.

The lower detail region uses five fixed tabs: **BUS + AUX**, **THERMAL**, **ATMOSPHERE**, **INCIDENTS**, and **EVENT LOG**. Faults blink the relevant tab heading red, even while another tab is open. The bus tab covers the power single-line diagram and auxiliary service; thermal/atmosphere/incidents contain their existing controls. The event-log view displays the six newest records without a scrollbar; full log history still stays in saved game data. Keyboard shortcuts continue working regardless of the selected tab, including B / 1–3 / T / P / G / H / J / C.

This UI pass is designed for the project's 1920×1080 reference canvas using Godot's canvas scaling. **Godot runtime fitting and visual layout have not yet been tested**, especially on smaller displays. No gameplay balancing values or save version changed.

## Animated main menu (V1.1)

The main menu now displays a **procedurally animated, visual-only station-monitoring background**, behind a translucent dark focus layer and the existing clickable menu panel. It shows electrical power flows, moving system meters, reactor and atmospheric readings, sensor links, and an event-recorder feed. The simulation is deliberately fictional and independent of gameplay state: it **does not run the real campaign or modify saved data**. Its animation stops when the player enters gameplay.

The **Esc pause menu and shift results** instead display the actual frozen control room behind a translucent dark tint; the fake SCADA background does not replace the real gameplay screen. No shaders, external artwork, audio files, or new plugins are needed.

The attract-mode script is `scripts/menu_scada_bg.gd`. The title/pause presentation is controlled by `scripts/game_menu.gd`. This is a first visual pass with dimming and reduced contrast, **not a Gaussian blur shader**. It is designed to run with Godot 4.6's Compatibility renderer.

## Campaign

| Shift | Mechanic added | Approx. shift duration |
| --- | --- | --- |
| 1–2 | Easy power allocation training; no breaker trips or reactor sag | 90 s |
| 3–4 | Circuit breakers trip; reset after cooldown | 105 s |
| 5–6 | Temporary reduction in reactor output | 120 s |
| 7–8 | Auxiliary stabiliser maintenance | 135–150 s |
| 9–10 | Reactor thermal gauges, pump OFF/AUTO/BOOST; pump faults from Shift 10 | 165–180 s |
| 11–12 | Oxygen generation and pressure; cabin leaks from Shift 12 | 195–210 s |
| 13+ | Concurrent incident containment: coolant ruptures, pressure breaches and communications arcs | 225–240 s |

Events become gradually more frequent, though the balanced V0.3.1 battery, recovery and integrity-damage rates are retained. This is an arcade simulation, not a real electrical model.

When you win, select **Start Next Shift**. After a loss select **Retry This Shift**. The result screen reports number of events, breaker trips, remaining battery and mean integrity.

## Event recorder and small-screen layout

The engineering event recorder now has its own vertical scrollbar and retains up to 150 log entries. Newest messages appear first, and the viewer returns to the top whenever a new event is logged. The complete control-room page can also scroll on monitors where the whole interface does not fit vertically; this prevents the bottom controls from being clipped.

## Thermal controls (V0.8)

At Shift 9, the reactor temperature gauge and **P** pump control unlock. The pump defaults to **AUTO**, which normally provides enough cooling when the cooling subsystem receives its required electrical allocation. **BOOST** cools faster if temperature climbs; **OFF** is only safe briefly. A cooling-circuit breaker trip or inadequate power prevents the pump cooling effectively. Thermal warnings begin at 85°C, become critical at 105°C and the reactor shuts down at 130°C. Temporary pump faults begin at Shift 10. All numbers are game-balancing parameters rather than engineering calculations.

Saves now record reactor temperature, pump mode and temporary outages (save schema V3); prior save versions remain readable.

## Atmospheric controls (V0.9)

At Shift 11, oxygen reserves and cabin pressure become active. The **G** key cycles oxygen generation OFF / AUTO / BOOST. The generator requires the life-support circuit to be powered sufficiently; AUTO is designed to maintain normal conditions with adequate power and BOOST can rebuild oxygen reserves faster. At Shift 12, temporary leaks can depressurise the habitat: press **H** to engage the emergency cabin seal. Leaks also self-contain after a short period, giving the player recovery opportunities.

Warnings occur at oxygen 50% / pressure 80 kPa, with critical alerts at 25% / 65 kPa; a shift fails if oxygen reaches 0% or pressure reaches 50 kPa. All rates and thresholds are fictional game-balance values, not crew-life-support engineering specifications.

Saves now include oxygen, pressure, generator mode and leak/seal cooldown timers (save schema V4). Existing V1–V3 saves remain readable.

## Advanced emergency operations (V1.0)

Beginning at **Shift 13**, every fourth event triggers a compound incident while normal breaker, pump, reactor and life-support faults continue. One incident is active at a time for up to 18 seconds. Coolant ruptures increase reactor heating, hull breaches drain cabin pressure, and communications bus arcs wear communications integrity. Press **J** or the **CONTAIN** button to isolate the incident immediately. The containment control has a 10-second cooldown, and the end-of-shift results report **incidents contained / incidents generated**. Incidents subside on their own after 18 seconds if uncontained, but can still cause equipment damage in the meantime. All rates are intentionally arcade-balanced.

Save format V5 includes incident type, remaining duration, containment cooldown and incident statistics; V1–V4 saved games remain readable. The existing three save slots and settings are unchanged. This version does not add GitHub Actions or automated builds.

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
| P | Cycle cooling pump OFF / AUTO / BOOST (Shift 9+) |
| G | Cycle oxygen generator OFF / AUTO / BOOST (Shift 11+) |
| H | Seal a cabin pressure leak (Shift 12+) |
| J | Contain a compound emergency incident (Shift 13+) |
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

V1.2 was committed to GitHub but **has not been verified inside Godot 4.6** here. The previous gameplay mechanics and the V1.0 save schema are unchanged. The previously tested V0.6 should be retained as a local backup. Please test the first shift, Shift 3 breaker introduction, Shift 5 reactor sag, Shift 7 auxiliary maintenance, save-slot overwrite/loading, and full-screen pause navigation before distribution.
