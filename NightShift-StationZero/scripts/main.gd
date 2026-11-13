extends Control
## NIGHT SHIFT: STATION ZERO — V1.2 fixed console with fault-aware detail tabs.
## Self-contained UI: no downloaded artwork, plugins, or fonts required.

const SHIFT_SECONDS := 120.0
const REACTOR_NOMINAL := 6
const MAX_SYSTEM_POWER := 3
# Arcade balance parameters; tweak after playtesting.
const BATTERY_DRAIN_PER_UNIT := 1.0 # charge % per second per covered unit
const BATTERY_CHARGE_PER_SPARE_UNIT := 4.0 # charge % per second
const INTEGRITY_DAMAGE_PER_DEFICIT := 1.5
const INTEGRITY_RECOVERY_PER_SECOND := 2.5
const EVENT_INTERVAL := 15.0
const REACTOR_SAG_SECONDS := 6.0
const BREAKER_RESET_DELAY := 3.0 # time after trip before operator can reset
const SYSTEMS := ["LIFE SUPPORT", "REACTOR COOLING", "COMMUNICATIONS"]
const SHORT_KEYS := ["Q / A", "W / S", "E / D"]
const BG := Color("#070e18")
const PANEL := Color("#102335")
const PANEL_DARK := Color("#091824")
const BORDER := Color("#28546a")
const CYAN := Color("#65e2e8")
const TEXT := Color("#e7f3f7")
const MUTED := Color("#8ba6b7")
const GREEN := Color("#77e3ae")
const AMBER := Color("#ffc56e")
const RED := Color("#ff7187")
const COOL_BLUE := Color("#69aafa")
const LIFE_TEAL := Color("#72e2ad")
const COMMS_VIOLET := Color("#bd97ff")
const REACTOR_ORANGE := Color("#ffa96b")
const BATTERY_GOLD := Color("#f4d374")

var power: Array[int] = [2, 2, 2]
var demand: Array[int] = [2, 2, 2]
var integrity: Array[float] = [100.0, 100.0, 100.0]
var remaining := SHIFT_SECONDS
var event_timer := EVENT_INTERVAL
var reactor_output := REACTOR_NOMINAL
var sag_timer := 0.0
var battery_charge := 100.0
var battery_enabled := false
var finished := false
var event_count := 0
var log_lines: Array[String] = []
var rng := RandomNumberGenerator.new()
var clock_label: Label
var status_label: Label
var budget_label: Label
var reactor_label: Label
var reactor_bar: ProgressBar
var battery_label: Label
var battery_bar: ProgressBar
var battery_button: Button
var bus_label: Label
var log_label: RichTextLabel
var power_labels: Array[Label] = []
var demand_labels: Array[Label] = []
var integrity_labels: Array[Label] = []
var integrity_bars: Array[ProgressBar] = []
var line_labels: Array[Label] = []
var plus_buttons: Array[Button] = []
var minus_buttons: Array[Button] = []
var restart_button: Button
var alarm_label: Label
var alarm_button: Button
var bus_diagram: Control
var subsystem_leds: Array[Label] = []
var alarm_acknowledged := false
var alarm_signature := ""
var log_count := 0
var breakers_tripped: Array[bool] = [false, false, false]
var breaker_cooldowns: Array[float] = [0.0, 0.0, 0.0]
var breaker_labels: Array[Label] = []
var breaker_buttons: Array[Button] = []
var station_audio
var audio_button: Button
var game_menu
var shift_number: int = 1
var shift_duration: float = 90.0
var maintenance_integrity: float = 100.0
var maintenance_cooldown: float = 0.0
var maintenance_label: Label
var maintenance_button: Button
var shift_label: Label
var total_faults: int = 0
var reactor_temp_c: float = 62.0
var cooling_pump_mode: int = 1 # 0 OFF, 1 AUTO, 2 BOOST
var cooling_pump_fault_seconds: float = 0.0
var temperature_label: Label
var temperature_bar: ProgressBar
var cooling_pump_button: Button
var cooling_tip_label: Label
var temp_alert_state: int = 0
var oxygen_pct: float = 96.0
var cabin_pressure_kpa: float = 101.0
var oxygen_mode: int = 1 # 0 OFF, 1 AUTO, 2 BOOST
var pressure_leak_seconds: float = 0.0
var seal_cooldown: float = 0.0
var oxygen_label: Label
var oxygen_bar: ProgressBar
var pressure_label: Label
var pressure_bar: ProgressBar
var oxygen_mode_button: Button
var seal_button: Button
var atmosphere_hint: Label
var atmosphere_alert: int = 0
var incident_type: int = 0 # 0 NONE, 1 COOLANT, 2 HULL, 3 BUS ARC
var incident_timer: float = 0.0
var containment_cooldown: float = 0.0
var incidents_contained: int = 0
var incidents_total: int = 0
var incident_label: Label
var incident_button: Button
var incident_progress: ProgressBar
var detail_pages: Array[Control] = []
var detail_buttons: Array[Button] = []
var active_detail_tab: int = 0
var tab_alarm_flags: Array[bool] = [false, false, false, false, false]
var tab_flash_clock: float = 0.0

func _ready() -> void:
    rng.randomize()
    station_audio = Node.new()
    station_audio.set_script(load("res://scripts/station_audio.gd"))
    add_child(station_audio)
    _build_ui()
    game_menu = CanvasLayer.new()
    game_menu.set_script(load("res://scripts/game_menu.gd"))
    add_child(game_menu)
    remaining = get_shift_duration()
    shift_duration = remaining
    event_timer = get_event_interval()
    _add_log("NIGHT SHIFT INITIALIZED. ALL SYSTEMS NOMINAL.")
    _add_log("SHIFT POWER TO MATCH CHANGING DEMAND.")
    _add_log("BATTERY LASTS LONGER; FREE REACTOR UNITS TO RECHARGE.")
    _add_log("PROGRESSION: SHIFT 3 BREAKERS / SHIFT 5 REACTOR / SHIFT 7 AUXILIARY.")
    _refresh()

func _process(delta: float) -> void:
    if finished or (game_menu != null and game_menu.is_blocking()):
        return
    tab_flash_clock += delta
    remaining = maxf(0.0, remaining - delta)
    if shift_number >= 13:
        _update_incident(delta)
    if shift_number >= 7:
        maintenance_cooldown = maxf(0.0, maintenance_cooldown - delta)
        maintenance_integrity = maxf(0.0, maintenance_integrity - delta * (0.85 + float(shift_number - 7) * 0.07))
        if maintenance_integrity <= 0.0:
            _finish(false, "AUXILIARY STABILISER FAILED.")
            _refresh()
            return
    if shift_number >= 11:
        _update_atmosphere(delta)
        if finished:
            _refresh()
            return
    if shift_number >= 9:
        _update_thermal(delta)
        if finished:
            _refresh()
            return
    event_timer -= delta
    if sag_timer > 0.0:
        sag_timer -= delta
        if sag_timer <= 0.0:
            reactor_output = REACTOR_NOMINAL
            _add_log("REACTOR OUTPUT RESTORED TO 6 UNITS.")
    if event_timer <= 0.0:
        event_timer += get_event_interval()
        _trigger_event()
    for i in range(3):
        if breaker_cooldowns[i] > 0.0:
            breaker_cooldowns[i] = maxf(0.0, breaker_cooldowns[i] - delta)
    var extra_draw: int = maxi(0, _total_power() - reactor_output)
    if extra_draw > 0 and battery_enabled and battery_charge > 0.0:
        battery_charge = maxf(0.0, battery_charge - float(extra_draw) * BATTERY_DRAIN_PER_UNIT * delta)
        if battery_charge <= 0.0:
            battery_enabled = false
            _add_log("CRITICAL: BATTERY DEPLETED. BACKUP OFFLINE.")
    elif extra_draw == 0 and battery_charge < 100.0:
        # Recharge is deliberately slow; spare reactor capacity helps recharge.
        var spare: int = maxi(0, reactor_output - _total_power())
        battery_charge = minf(100.0, battery_charge + float(spare) * BATTERY_CHARGE_PER_SPARE_UNIT * delta)
    var covered: int = reactor_output
    if battery_enabled and battery_charge > 0.0:
        covered += 2
    var shortfall: int = maxi(0, _total_power() - covered)
    # Any bus deficit is shared across the three systems (electrical brownout).
    for i in range(3):
        var delivered: int = 0 if breakers_tripped[i] else power[i]
        var deficit: float = float(maxi(0, demand[i] - delivered)) + float(shortfall) / 3.0
        if incident_type == 3 and i == 2:
            deficit += 0.40
        if deficit > 0.0:
            integrity[i] = maxf(0.0, integrity[i] - deficit * INTEGRITY_DAMAGE_PER_DEFICIT * delta)
        else:
            integrity[i] = minf(100.0, integrity[i] + INTEGRITY_RECOVERY_PER_SECOND * delta)
        if integrity[i] <= 0.0:
            _finish(false, SYSTEMS[i] + " HAS FAILED.")
            break
    if remaining <= 0.0 and not finished:
        _finish(true, "SHIFT COMPLETE. STATION ZERO SURVIVED.")
    _refresh()

func _unhandled_key_input(event: InputEvent) -> void:
    if not event is InputEventKey or not event.pressed or event.echo:
        return
    if game_menu == null or game_menu.is_blocking() or finished:
        return
    var action: String = game_menu.action_for_key(event.keycode)
    match action:
        "life_up": _shift_power(0, 1)
        "life_down": _shift_power(0, -1)
        "cool_up": _shift_power(1, 1)
        "cool_down": _shift_power(1, -1)
        "comms_up": _shift_power(2, 1)
        "comms_down": _shift_power(2, -1)
        "battery": _toggle_battery()
        "ack": _acknowledge_alarm()
        "breaker_1": _reset_breaker(0)
        "breaker_2": _reset_breaker(1)
        "breaker_3": _reset_breaker(2)
        "mute": _toggle_audio()
        "service": _service_auxiliary()
        "pump": _cycle_cooling_pump()
        "oxygen": _cycle_oxygen_generator()
        "seal": _seal_cabin()
        "contain": _contain_incident()

func _total_power() -> int:
    var result := 0
    for n in power:
        result += n
    return result

func _available_capacity() -> int:
    return reactor_output + (2 if battery_enabled and battery_charge > 0.0 else 0)

func _shift_power(index: int, change: int) -> void:
    if finished or (game_menu != null and game_menu.is_blocking()):
        return
    var updated: int = power[index] + change
    if updated < 0 or updated > MAX_SYSTEM_POWER:
        return
    if change > 0 and _total_power() >= _available_capacity():
        _add_log("POWER SHIFT BLOCKED: NO BUS CAPACITY. FREE A UNIT OR ENABLE BATTERY.")
        _refresh()
        return
    power[index] = updated
    station_audio.effect("click")
    _add_log("%s ALLOCATION -> %d UNITS." % [SYSTEMS[index], updated])
    _refresh()

func _toggle_battery() -> void:
    if finished or (game_menu != null and game_menu.is_blocking()):
        return
    if not battery_enabled and battery_charge <= 0.0:
        _add_log("BATTERY IS EMPTY. REDUCE LOAD TO RECHARGE.")
        return
    battery_enabled = not battery_enabled
    station_audio.effect("click")
    _add_log("BACKUP BUS %s." % ("CONNECTED" if battery_enabled else "DISCONNECTED"))
    _refresh()

func _trigger_event() -> void:
    event_count += 1
    if shift_number >= 13 and event_count % 4 == 0 and incident_type == 0:
        _start_compound_incident()
    var stressed: int = rng.randi_range(0, 2)
    demand = [2, 2, 2]
    demand[stressed] = 3
    # One trip at a time; no trip on the first demand event.
    # Alternating events keep faults recoverable and preserve a clear power puzzle.
    if shift_number >= 3 and event_count % 2 == 0 and not breakers_tripped.has(true):
        _trip_breaker(stressed)
    if shift_number >= 12 and event_count % 5 == 0 and pressure_leak_seconds <= 0.0:
        pressure_leak_seconds = 14.0
        _add_log("FAULT: CABIN PRESSURE LEAK DETECTED. ENGAGE EMERGENCY SEAL [H].")
    if shift_number >= 10 and event_count % 4 == 0:
        cooling_pump_fault_seconds = 8.0
        _add_log("FAULT: COOLING PUMP TEMPORARILY OFFLINE FOR 8 SECONDS.")
    if shift_number >= 5 and event_count % 3 == 0:
        reactor_output = 5
        sag_timer = REACTOR_SAG_SECONDS
        _add_log("FAULT %02d: REACTOR DERATED TO 5 UNITS FOR 6 SECONDS." % event_count)
    elif event_count % 2 == 0:
        _add_log("ALERT %02d: %s DEMAND SURGE. 7 UNITS REQUIRED." % [event_count, SYSTEMS[stressed]])
    else:
        var relaxed: int = (stressed + rng.randi_range(1, 2)) % 3
        demand[relaxed] = 1
        _add_log("ALERT %02d: %s SPIKE, %s LOAD REDUCED." % [event_count, SYSTEMS[stressed], SYSTEMS[relaxed]])

func _trip_breaker(index: int) -> void:
    breakers_tripped[index] = true
    total_faults += 1
    station_audio.effect("breaker")
    breaker_cooldowns[index] = BREAKER_RESET_DELAY
    _add_log("FAULT: %s BREAKER TRIPPED. RESET WITH KEY %d AFTER COOLDOWN." % [SYSTEMS[index], index + 1])

func _reset_breaker(index: int) -> void:
    if finished or shift_number < 3 or (game_menu != null and game_menu.is_blocking()):
        return
    if not breakers_tripped[index]:
        _add_log("BREAKER %d IS ALREADY CLOSED." % (index + 1))
    elif breaker_cooldowns[index] > 0.0:
        _add_log("BREAKER %d RESET BLOCKED: COOLING FOR %dS." % [index + 1, int(ceil(breaker_cooldowns[index]))])
    else:
        breakers_tripped[index] = false
        station_audio.effect("success")
        _add_log("BREAKER %d RESET. %s POWER RESTORED." % [index + 1, SYSTEMS[index]])
    _refresh()

func _finish(won: bool, reason: String) -> void:
    finished = true
    station_audio.set_alarm(false)
    station_audio.effect("success" if won else "critical")
    status_label.text = "SHIFT COMPLETE" if won else "STATION LOST"
    status_label.add_theme_color_override("font_color", GREEN if won else RED)
    _add_log(reason)
    restart_button.visible = false
    game_menu.show_result(won, reason)

func _reset() -> void:
    power = [2, 2, 2]
    demand = [2, 2, 2]
    integrity = [100.0, 100.0, 100.0]
    shift_duration = get_shift_duration()
    remaining = shift_duration
    event_timer = get_event_interval()
    reactor_output = REACTOR_NOMINAL
    sag_timer = 0.0
    battery_charge = 100.0
    battery_enabled = false
    finished = false
    event_count = 0
    log_lines.clear()
    total_faults = 0
    incident_type = 0
    incident_timer = 0.0
    containment_cooldown = 0.0
    incidents_contained = 0
    incidents_total = 0
    reactor_temp_c = 62.0
    cooling_pump_mode = 1
    cooling_pump_fault_seconds = 0.0
    temp_alert_state = 0
    oxygen_pct = 96.0
    cabin_pressure_kpa = 101.0
    oxygen_mode = 1
    pressure_leak_seconds = 0.0
    seal_cooldown = 0.0
    atmosphere_alert = 0
    maintenance_integrity = 100.0
    maintenance_cooldown = 0.0
    breakers_tripped = [false, false, false]
    breaker_cooldowns = [0.0, 0.0, 0.0]
    alarm_acknowledged = false
    alarm_signature = ""
    station_audio.set_alarm(false)
    log_count = 0
    status_label.text = "ON DUTY"
    status_label.add_theme_color_override("font_color", GREEN)
    restart_button.visible = false
    _add_log("SHIFT %d STARTED. %s." % [shift_number, get_shift_phase()])
    _refresh()

func _add_log(message: String) -> void:
    var elapsed: int = int(shift_duration - remaining)
    var severity := "INFO"
    if "CRITICAL" in message or "FAILED" in message or "LOST" in message:
        severity = "CRIT"
    elif "FAULT" in message or "ALERT" in message or "BLOCKED" in message:
        severity = "WARN"
    var stamp := "%02d:%02d" % [int(elapsed / 60), elapsed % 60]
    log_lines.push_front("[%s] [%s] %s" % [stamp, severity, message])
    if log_lines.size() > 150:
        log_lines.resize(150)
    _render_log()

func _render_log() -> void:
    if log_label == null:
        return
    log_label.clear()
    for i in range(mini(6, log_lines.size())):
        var entry: String = log_lines[i]
        var ink := MUTED
        if "[CRIT]" in entry:
            ink = RED
        elif "[WARN]" in entry:
            ink = AMBER
        elif "[INFO]" in entry:
            ink = CYAN
        log_label.push_color(ink)
        log_label.add_text(entry + "\n")
        log_label.pop()
    # Newest records are inserted first; keep the viewer anchored at the top.
    # Fixed six-line view intentionally has no scrollbar.

func _acknowledge_alarm() -> void:
    if finished or (game_menu != null and game_menu.is_blocking()):
        return
    if alarm_signature == "":
        _add_log("ALARM ACKNOWLEDGEMENT: NOTHING ACTIVE.")
        return
    if not alarm_acknowledged:
        alarm_acknowledged = true
        station_audio.set_alarm(false)
        station_audio.effect("click")
        _add_log("OPERATOR ACKNOWLEDGED ACTIVE WARNING.")
    _refresh()

func _refresh() -> void:
    _update_detail_tabs()
    var secs: int = int(ceil(remaining))
    clock_label.text = "%02d:%02d" % [int(secs / 60), secs % 60]
    if shift_label != null:
        shift_label.text = "SHIFT %02d  /  %s" % [shift_number, get_shift_phase()]
    if maintenance_label != null:
        maintenance_label.text = "AUX STABILISER  %d%%  •  %s" % [int(ceil(maintenance_integrity)), ("READY [T]" if maintenance_cooldown <= 0.0 else "REPAIR COOLDOWN %dS" % int(ceil(maintenance_cooldown)))] if shift_number >= 7 else "AUX STABILISER  /  UNLOCKS SHIFT 07"
        maintenance_label.add_theme_color_override("font_color", RED if shift_number >= 7 and maintenance_integrity < 35.0 else CYAN)
    if maintenance_button != null:
        maintenance_button.disabled = shift_number < 7 or maintenance_cooldown > 0.0 or finished
    if temperature_label != null:
        temperature_label.text = "REACTOR CORE  %.1f°C  /  %s" % [reactor_temp_c, _thermal_status()] if shift_number >= 9 else "REACTOR THERMAL CONTROLS  /  UNLOCK SHIFT 09"
        temperature_label.add_theme_color_override("font_color", RED if reactor_temp_c >= 105.0 and shift_number >= 9 else (AMBER if reactor_temp_c >= 85.0 and shift_number >= 9 else CYAN))
    if temperature_bar != null:
        temperature_bar.value = reactor_temp_c
    if cooling_pump_button != null:
        cooling_pump_button.text = "PUMP: %s [P]" % _pump_mode_name() if shift_number >= 9 else "PUMP LOCKED"
        cooling_pump_button.disabled = finished or shift_number < 9
    if cooling_tip_label != null:
        cooling_tip_label.text = "TEMP WARNING 85°C  /  CRITICAL 105°C  /  SHUTDOWN 130°C" if shift_number >= 9 else "AUTO / BOOST COOLING CONTROL UNLOCKS AT SHIFT 09"
    if oxygen_label != null:
        oxygen_label.text = "OXYGEN RESERVE  %.0f%%" % oxygen_pct if shift_number >= 11 else "OXYGEN GENERATOR / UNLOCKS SHIFT 11"
        oxygen_label.add_theme_color_override("font_color", RED if shift_number >= 11 and oxygen_pct <= 25.0 else (AMBER if shift_number >= 11 and oxygen_pct <= 50.0 else CYAN))
    if pressure_label != null:
        pressure_label.text = "CABIN PRESSURE  %.1f kPa" % cabin_pressure_kpa if shift_number >= 11 else "PRESSURE MONITOR / UNLOCKS SHIFT 11"
        pressure_label.add_theme_color_override("font_color", RED if shift_number >= 11 and cabin_pressure_kpa <= 65.0 else (AMBER if shift_number >= 11 and cabin_pressure_kpa <= 80.0 else CYAN))
    if oxygen_bar != null:
        oxygen_bar.value = oxygen_pct
    if pressure_bar != null:
        pressure_bar.value = cabin_pressure_kpa
    if oxygen_mode_button != null:
        oxygen_mode_button.text = "OXYGEN: %s [G]" % _oxygen_mode_name() if shift_number >= 11 else "OXYGEN LOCKED"
        oxygen_mode_button.disabled = finished or shift_number < 11
    if seal_button != null:
        seal_button.text = "SEAL CABIN [H]" if pressure_leak_seconds > 0.0 else "CABIN SEALED"
        seal_button.disabled = finished or shift_number < 12 or pressure_leak_seconds <= 0.0 or seal_cooldown > 0.0
    if atmosphere_hint != null:
        atmosphere_hint.text = "KEEP OXYGEN > 0% / PRESSURE > 50 kPa  •  SEAL LEAKS WITH [H]" if shift_number >= 11 else "ATMOSPHERIC SYSTEMS UNLOCK AT SHIFT 11"
    if incident_label != null:
        incident_label.text = "ACTIVE INCIDENT  /  %s  /  %.0fS REMAINING" % [_incident_name(), incident_timer] if incident_type != 0 else ("COMPOUND INCIDENT PROTOCOL / STANDBY" if shift_number >= 13 else "COMPOUND INCIDENT PROTOCOL / UNLOCK SHIFT 13")
        incident_label.add_theme_color_override("font_color", RED if incident_type != 0 else CYAN)
    if incident_progress != null:
        incident_progress.value = incident_timer
    if incident_button != null:
        incident_button.text = "CONTAIN [J]" if incident_type != 0 else "NO ACTIVE INCIDENT"
        incident_button.disabled = finished or shift_number < 13 or incident_type == 0 or containment_cooldown > 0.0
    var allocated: int = _total_power()
    var capacity: int = _available_capacity()
    budget_label.text = "%d / %d UNITS ASSIGNED    •    %d FREE" % [allocated, capacity, maxi(0, capacity - allocated)]
    reactor_label.text = "%d / 6 UNITS" % reactor_output
    reactor_bar.value = reactor_output
    _set_bar_accent(reactor_bar, AMBER if reactor_output < REACTOR_NOMINAL else REACTOR_ORANGE)
    battery_label.text = "%d%% CHARGE" % int(ceil(battery_charge))
    battery_bar.value = battery_charge
    _set_bar_accent(battery_bar, RED if battery_charge <= 20.0 else BATTERY_GOLD)
    battery_button.text = "DISCONNECT BACKUP [B]" if battery_enabled else "CONNECT BACKUP [B]"
    battery_button.disabled = finished or (battery_charge <= 0.0 and not battery_enabled)
    bus_label.text = "REACTOR  %dU   > > >   MAIN BUS  %dU   > > >   LOAD  %dU" % [reactor_output, capacity, allocated]
    bus_label.add_theme_color_override("font_color", GREEN if allocated <= capacity else RED)
    if bus_diagram != null:
        bus_diagram.set("reactor_units", reactor_output)
        bus_diagram.set("load_units", power.duplicate())
        bus_diagram.set("demand_units", demand.duplicate())
        bus_diagram.set("battery_online", battery_enabled and battery_charge > 0.0)
        bus_diagram.set("brownout", allocated > capacity)
        bus_diagram.set("breakers_tripped", breakers_tripped.duplicate())
    var warning := ""
    if shift_number >= 13 and incident_type != 0:
        warning = "COMPOUND INCIDENT: " + _incident_name()
    elif shift_number >= 11 and (oxygen_pct <= 25.0 or cabin_pressure_kpa <= 65.0):
        warning = "CRITICAL ATMOSPHERIC CONDITIONS"
    elif shift_number >= 11 and (oxygen_pct <= 50.0 or cabin_pressure_kpa <= 80.0):
        warning = "ATMOSPHERIC LEVELS LOW"
    elif shift_number >= 12 and pressure_leak_seconds > 0.0:
        warning = "CABIN PRESSURE LEAK"
    elif shift_number >= 9 and reactor_temp_c >= 105.0:
        warning = "REACTOR TEMPERATURE CRITICAL"
    elif shift_number >= 9 and reactor_temp_c >= 85.0:
        warning = "REACTOR TEMPERATURE HIGH"
    elif shift_number >= 9 and cooling_pump_fault_seconds > 0.0:
        warning = "COOLING PUMP OFFLINE"
    elif shift_number >= 7 and maintenance_integrity < 35.0:
        warning = "AUXILIARY MAINTENANCE REQUIRED"
    elif breakers_tripped.has(true):
        warning = "CIRCUIT BREAKER TRIPPED"
    elif allocated > capacity:
        warning = "MAIN BUS OVERLOAD"
    elif reactor_output < REACTOR_NOMINAL:
        warning = "REACTOR DERATING"
    else:
        for i in range(3):
            if power[i] < demand[i] or integrity[i] < 40.0:
                warning = "SUBSYSTEM WARNING"
                break
    if warning != alarm_signature:
        alarm_signature = warning
        alarm_acknowledged = false
    if warning == "":
        alarm_label.text = "●  ALL SYSTEMS NOMINAL"
        alarm_label.add_theme_color_override("font_color", GREEN)
    elif alarm_acknowledged:
        alarm_label.text = "◆  ACKNOWLEDGED / " + warning
        alarm_label.add_theme_color_override("font_color", MUTED)
    else:
        alarm_label.text = "▲  ACTIVE ALARM / " + warning
        alarm_label.add_theme_color_override("font_color", RED)
    alarm_button.disabled = warning == "" or alarm_acknowledged or finished
    if station_audio != null:
        station_audio.set_alarm(warning != "" and not alarm_acknowledged and not finished, warning == "CIRCUIT BREAKER TRIPPED" or warning == "MAIN BUS OVERLOAD")
    for i in range(3):
        power_labels[i].text = "%d / 3" % power[i]
        demand_labels[i].text = "DEMAND  %d UNITS" % demand[i]
        integrity_labels[i].text = "%d%%" % int(ceil(integrity[i]))
        integrity_bars[i].value = integrity[i]
        _set_bar_accent(integrity_bars[i], RED if integrity[i] <= 30.0 else (AMBER if integrity[i] <= 60.0 else [LIFE_TEAL, COOL_BLUE, COMMS_VIOLET][i]))
        line_labels[i].text = "BUS %s  %dU" % [["A", "B", "C"][i], power[i]]
        var okay: bool = power[i] >= demand[i] and not breakers_tripped[i]
        demand_labels[i].add_theme_color_override("font_color", GREEN if okay else RED)
        line_labels[i].add_theme_color_override("font_color", [LIFE_TEAL, COOL_BLUE, COMMS_VIOLET][i] if okay else AMBER)
        integrity_labels[i].add_theme_color_override("font_color", GREEN if integrity[i] > 60.0 else (AMBER if integrity[i] > 30.0 else RED))
        subsystem_leds[i].text = "●  BREAKER TRIPPED" if breakers_tripped[i] else ("●  NOMINAL" if okay else "●  UNDERSUPPLIED")
        subsystem_leds[i].add_theme_color_override("font_color", RED if breakers_tripped[i] else (GREEN if okay else AMBER))
        if breakers_tripped[i]:
            breaker_labels[i].text = "OPEN / COOLING %dS" % int(ceil(breaker_cooldowns[i])) if breaker_cooldowns[i] > 0.0 else "OPEN / READY TO RESET"
        else:
            breaker_labels[i].text = "CLOSED / HEALTHY"
        breaker_labels[i].add_theme_color_override("font_color", RED if breakers_tripped[i] else GREEN)
        breaker_buttons[i].disabled = finished or shift_number < 3 or not breakers_tripped[i] or breaker_cooldowns[i] > 0.0
        plus_buttons[i].disabled = finished or power[i] >= MAX_SYSTEM_POWER or allocated >= capacity
        minus_buttons[i].disabled = finished or power[i] <= 0

func _label(value: String, size: int = 15, color: Color = TEXT) -> Label:
    var l := Label.new()
    l.text = value
    l.add_theme_font_size_override("font_size", size)
    l.add_theme_color_override("font_color", color)
    return l

func _panel(dark: bool = false) -> PanelContainer:
    var p := PanelContainer.new()
    var style := StyleBoxFlat.new()
    style.bg_color = PANEL_DARK if dark else PANEL
    style.border_color = BORDER
    style.set_border_width_all(1)
    style.set_corner_radius_all(7)
    style.set_content_margin_all(8)
    p.add_theme_stylebox_override("panel", style)
    return p

func _style_panel_accent(panel: PanelContainer, accent: Color) -> void:
    var border_style := panel.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
    border_style.border_color = accent.darkened(0.43)
    border_style.set_border_width_all(2)
    panel.add_theme_stylebox_override("panel", border_style)

func _set_bar_accent(bar: ProgressBar, accent: Color) -> void:
    var fill_style := StyleBoxFlat.new()
    fill_style.bg_color = accent
    fill_style.set_corner_radius_all(3)
    bar.add_theme_stylebox_override("fill", fill_style)

func _vbox(separation: int = 12) -> VBoxContainer:
    var v := VBoxContainer.new()
    v.add_theme_constant_override("separation", separation)
    return v

func _hbox(separation: int = 12) -> HBoxContainer:
    var h := HBoxContainer.new()
    h.add_theme_constant_override("separation", separation)
    return h

func _bar(maximum: float, current: float) -> ProgressBar:
    var b := ProgressBar.new()
    b.custom_minimum_size = Vector2(0, 13)
    b.max_value = maximum
    b.value = current
    b.show_percentage = false
    var fill := StyleBoxFlat.new()
    fill.bg_color = CYAN
    fill.set_corner_radius_all(3)
    b.add_theme_stylebox_override("fill", fill)
    var trough := StyleBoxFlat.new()
    trough.bg_color = Color("#07111d")
    trough.set_corner_radius_all(3)
    b.add_theme_stylebox_override("background", trough)
    return b

func _button(title: String) -> Button:
    var b := Button.new()
    b.text = title
    b.custom_minimum_size = Vector2(46, 30)
    b.add_theme_color_override("font_color", TEXT)
    b.add_theme_color_override("font_hover_color", Color.WHITE)
    var idle := StyleBoxFlat.new()
    idle.bg_color = Color("#16354a")
    idle.border_color = Color("#2c6b83")
    idle.set_border_width_all(1)
    idle.set_corner_radius_all(4)
    idle.set_content_margin_all(7)
    b.add_theme_stylebox_override("normal", idle)
    var hover := idle.duplicate()
    hover.bg_color = Color("#1f536a")
    b.add_theme_stylebox_override("hover", hover)
    return b

func _set_detail_tab(index: int) -> void:
    active_detail_tab = clampi(index, 0, detail_pages.size() - 1)
    for i in range(detail_pages.size()):
        detail_pages[i].visible = i == active_detail_tab
    _update_detail_tabs()

func _update_detail_tabs() -> void:
    if detail_buttons.size() != 5:
        return
    var trips: bool = breakers_tripped.has(true)
    var bus_fault: bool = trips or _total_power() > _available_capacity() or (shift_number >= 7 and maintenance_integrity < 35.0)
    var thermal_fault: bool = shift_number >= 9 and (reactor_temp_c >= 85.0 or cooling_pump_fault_seconds > 0.0)
    var atmospheric_fault: bool = shift_number >= 11 and (oxygen_pct <= 50.0 or cabin_pressure_kpa <= 80.0 or pressure_leak_seconds > 0.0)
    var incident_fault: bool = shift_number >= 13 and incident_type != 0
    var power_fault: bool = false
    for j in range(3):
        if power[j] < demand[j] or integrity[j] < 40.0:
            power_fault = true
            break
    tab_alarm_flags = [bus_fault or power_fault, thermal_fault, atmospheric_fault, incident_fault, false]
    var names := ["BUS + AUX", "THERMAL", "ATMOSPHERE", "INCIDENTS", "EVENT LOG"]
    var tab_accents := [CYAN, REACTOR_ORANGE, LIFE_TEAL, AMBER, COMMS_VIOLET]
    for i in range(5):
        var attention: bool = tab_alarm_flags[i]
        var blink: bool = fposmod(tab_flash_clock, 1.0) < 0.5
        var prefix: String = "▲ " if attention and blink else ("! " if attention else "")
        detail_buttons[i].text = prefix + names[i]
        detail_buttons[i].add_theme_color_override("font_color", RED if attention and blink else (tab_accents[i] if i == active_detail_tab else MUTED))
        detail_buttons[i].button_pressed = i == active_detail_tab

func _build_ui() -> void:
    var bg := ColorRect.new()
    bg.color = BG
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(bg)
    var margins := MarginContainer.new()
    margins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    for side in ["left", "right", "top", "bottom"]:
        margins.add_theme_constant_override("margin_" + side, 10)
    add_child(margins)
    # Fixed dashboard. No vertical or horizontal scrolling in gameplay.
    var root := _vbox(6)
    root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    root.size_flags_vertical = Control.SIZE_EXPAND_FILL
    margins.add_child(root)
    var header := _hbox()
    root.add_child(header)
    var head_left := _vbox(2)
    head_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    header.add_child(head_left)
    head_left.add_child(_label("OS / 07    ·    ORBITAL ENGINEERING NETWORK    ·    SECURE OPERATOR TERMINAL", 12, CYAN))
    head_left.add_child(_label("NIGHT SHIFT   /   STATION ZERO", 24))
    shift_label = _label("SHIFT 01 / POWER TRAINING", 14, CYAN)
    head_left.add_child(shift_label)
    var head_right := _vbox(2)
    header.add_child(head_right)
    head_right.add_child(_label("TIME UNTIL SHIFT HANDOVER", 11, MUTED))
    clock_label = _label("02:00", 26, CYAN)
    head_right.add_child(clock_label)
    var top := _panel(true)
    root.add_child(top)
    var top_row := _hbox(15)
    top.add_child(top_row)
    budget_label = _label("", 17)
    budget_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    top_row.add_child(budget_label)
    status_label = _label("ON DUTY", 16, GREEN)
    top_row.add_child(status_label)
    var alarm_panel := _panel(true)
    root.add_child(alarm_panel)
    var alarms := _hbox(10)
    alarm_panel.add_child(alarms)
    alarm_label = _label("●  ALL SYSTEMS NOMINAL", 14, GREEN)
    alarm_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    alarms.add_child(alarm_label)
    alarm_button = _button("ACKNOWLEDGE [C]")
    alarm_button.pressed.connect(_acknowledge_alarm)
    alarms.add_child(alarm_button)
    audio_button = _button("SOUND ON [M]")
    audio_button.pressed.connect(_toggle_audio)
    alarms.add_child(audio_button)

    var power_row := _hbox(8)
    root.add_child(power_row)
    var reactor_panel := _panel()
    reactor_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _style_panel_accent(reactor_panel, REACTOR_ORANGE)
    power_row.add_child(reactor_panel)
    var reactor_stack := _vbox(8)
    reactor_panel.add_child(reactor_stack)
    reactor_stack.add_child(_label("01   PRIMARY REACTOR", 15, REACTOR_ORANGE))
    reactor_label = _label("6 / 6 UNITS", 20)
    reactor_stack.add_child(reactor_label)
    reactor_bar = _bar(6.0, 6.0)
    reactor_stack.add_child(reactor_bar)
    _set_bar_accent(reactor_bar, REACTOR_ORANGE)
    reactor_stack.add_child(_label("FAULT EVENTS CAN REDUCE AVAILABLE OUTPUT", 11, MUTED))

    var battery_panel := _panel()
    battery_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _style_panel_accent(battery_panel, BATTERY_GOLD)
    power_row.add_child(battery_panel)
    var battery_stack := _vbox(7)
    battery_panel.add_child(battery_stack)
    battery_stack.add_child(_label("02   EMERGENCY BATTERY", 15, BATTERY_GOLD))
    var battery_row := _hbox()
    battery_stack.add_child(battery_row)
    battery_label = _label("100% CHARGE", 20)
    battery_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    battery_row.add_child(battery_label)
    battery_button = _button("CONNECT BACKUP [B]")
    battery_button.pressed.connect(_toggle_battery)
    battery_row.add_child(battery_button)
    battery_bar = _bar(100.0, 100.0)
    battery_stack.add_child(battery_bar)
    _set_bar_accent(battery_bar, BATTERY_GOLD)
    battery_stack.add_child(_label("+2 BUS UNITS WHEN ENABLED  /  DRAINS ONLY WHEN NEEDED  /  FREE REACTOR CAPACITY TO RECHARGE", 11, MUTED))

    var systems_row := _hbox(12)
    systems_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
    root.add_child(systems_row)
    var system_accents := [LIFE_TEAL, COOL_BLUE, COMMS_VIOLET]
    for i in range(3):
        var p := _panel()
        _style_panel_accent(p, system_accents[i])
        p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        systems_row.add_child(p)
        var stack := _vbox(5)
        p.add_child(stack)
        stack.add_child(_label("0%d   %s" % [i + 4, SYSTEMS[i]], 15, system_accents[i]))
        var led := _label("●  NOMINAL", 12, GREEN)
        stack.add_child(led)
        subsystem_leds.append(led)
        var line := _label("BUS %s  2U" % ['A', 'B', 'C'][i], 13, system_accents[i])
        stack.add_child(line)
        line_labels.append(line)
        var health_row := _hbox()
        stack.add_child(health_row)
        var health_title := _label("SUBSYSTEM INTEGRITY", 12, MUTED)
        health_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        health_row.add_child(health_title)
        var health := _label("100%", 20, GREEN)
        health_row.add_child(health)
        integrity_labels.append(health)
        var bar := _bar(100.0, 100.0)
        stack.add_child(bar)
        _set_bar_accent(bar, system_accents[i])
        integrity_bars.append(bar)
        var request := _label("DEMAND  2 UNITS", 16, GREEN)
        stack.add_child(request)
        demand_labels.append(request)
        
        var breaker_row := _hbox(8)
        stack.add_child(breaker_row)
        var breaker_status := _label("CLOSED / HEALTHY", 12, GREEN)
        breaker_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        breaker_row.add_child(breaker_status)
        breaker_labels.append(breaker_status)
        var reset_cb := _button("RESET CB %d [%d]" % [i + 1, i + 1])
        reset_cb.pressed.connect(_reset_breaker.bind(i))
        breaker_row.add_child(reset_cb)
        breaker_buttons.append(reset_cb)
        stack.add_child(_label("POWER ALLOCATION", 12, MUTED))
        var inputs := _hbox(7)
        stack.add_child(inputs)
        var minus := _button("−")
        inputs.add_child(minus)
        var reading := _label("2 / 3", 22)
        reading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        reading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        inputs.add_child(reading)
        var plus := _button("+")
        inputs.add_child(plus)
        minus.pressed.connect(_shift_power.bind(i, -1))
        plus.pressed.connect(_shift_power.bind(i, 1))
        minus_buttons.append(minus)
        plus_buttons.append(plus)
        power_labels.append(reading)
        stack.add_child(_label("KEYBOARD  " + SHORT_KEYS[i], 11, MUTED))

    # Tabs only change the lower detail area. Power controls, integrity and alarms
    # stay visible continuously, so changing pages never hides vital operations.
    var tab_strip := _hbox(6)
    root.add_child(tab_strip)
    var tab_names := ["BUS + AUX", "THERMAL", "ATMOSPHERE", "INCIDENTS", "EVENT LOG"]
    for i in range(5):
        var tab := _button(tab_names[i])
        tab.toggle_mode = true
        tab.custom_minimum_size.y = 32.0
        tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        tab.pressed.connect(_set_detail_tab.bind(i))
        tab_strip.add_child(tab)
        detail_buttons.append(tab)
    var detail_host := Control.new()
    detail_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
    detail_host.custom_minimum_size.y = 214.0
    root.add_child(detail_host)
    for i in range(5):
        var page := VBoxContainer.new()
        page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        page.size_flags_vertical = Control.SIZE_EXPAND_FILL
        detail_host.add_child(page)
        detail_pages.append(page)
        page.visible = i == 0
    var bus_panel := _panel(true)
    detail_pages[0].add_child(bus_panel)
    _style_panel_accent(bus_panel, CYAN)
    var bus_stack := _vbox(4)
    bus_panel.add_child(bus_stack)
    bus_stack.add_child(_label("03   HIGH-VOLTAGE DISTRIBUTION  /  LIVE SINGLE-LINE DIAGRAM", 12, CYAN))
    bus_diagram = Control.new()
    bus_diagram.set_script(load("res://scripts/bus_diagram.gd"))
    bus_diagram.custom_minimum_size = Vector2(0, 153)
    bus_diagram.mouse_filter = Control.MOUSE_FILTER_IGNORE
    bus_stack.add_child(bus_diagram)
    bus_label = _label("", 12, MUTED)
    bus_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    bus_stack.add_child(bus_label)
    var aux_row := _hbox(12)
    bus_stack.add_child(aux_row)
    maintenance_label = _label("AUX STABILISER  /  UNLOCKS SHIFT 07", 13, MUTED)
    maintenance_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    aux_row.add_child(maintenance_label)
    maintenance_button = _button("SERVICE AUX [T]")
    maintenance_button.pressed.connect(_service_auxiliary)
    aux_row.add_child(maintenance_button)

    var thermal_panel := _panel(true)
    detail_pages[1].add_child(thermal_panel)
    _style_panel_accent(thermal_panel, REACTOR_ORANGE)
    var thermal_stack := _vbox(5)
    thermal_panel.add_child(thermal_stack)
    var thermal_row := _hbox(12)
    thermal_stack.add_child(thermal_row)
    temperature_label = _label("REACTOR THERMAL CONTROLS  /  UNLOCK SHIFT 09", 14, REACTOR_ORANGE)
    temperature_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    thermal_row.add_child(temperature_label)
    cooling_pump_button = _button("PUMP LOCKED")
    cooling_pump_button.pressed.connect(_cycle_cooling_pump)
    thermal_row.add_child(cooling_pump_button)
    temperature_bar = _bar(130.0, reactor_temp_c)
    thermal_stack.add_child(temperature_bar)
    _set_bar_accent(temperature_bar, REACTOR_ORANGE)
    cooling_tip_label = _label("AUTO / BOOST COOLING CONTROL UNLOCKS AT SHIFT 09", 11, MUTED)
    thermal_stack.add_child(cooling_tip_label)

    var atmosphere_panel := _panel(true)
    detail_pages[2].add_child(atmosphere_panel)
    _style_panel_accent(atmosphere_panel, LIFE_TEAL)
    var atmosphere_stack := _vbox(6)
    atmosphere_panel.add_child(atmosphere_stack)
    atmosphere_stack.add_child(_label("08   ATMOSPHERIC SYSTEMS / LIFE SUPPORT CONTROL", 13, LIFE_TEAL))
    var atmosphere_top := _hbox(12)
    atmosphere_stack.add_child(atmosphere_top)
    oxygen_label = _label("OXYGEN GENERATOR / UNLOCKS SHIFT 11", 14, CYAN)
    oxygen_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    atmosphere_top.add_child(oxygen_label)
    oxygen_mode_button = _button("OXYGEN LOCKED")
    oxygen_mode_button.pressed.connect(_cycle_oxygen_generator)
    atmosphere_top.add_child(oxygen_mode_button)
    oxygen_bar = _bar(100.0, 96.0)
    atmosphere_stack.add_child(oxygen_bar)
    _set_bar_accent(oxygen_bar, LIFE_TEAL)
    var atmosphere_bottom := _hbox(12)
    atmosphere_stack.add_child(atmosphere_bottom)
    pressure_label = _label("PRESSURE MONITOR / UNLOCKS SHIFT 11", 14, CYAN)
    pressure_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    atmosphere_bottom.add_child(pressure_label)
    seal_button = _button("CABIN SEALED")
    seal_button.pressed.connect(_seal_cabin)
    atmosphere_bottom.add_child(seal_button)
    pressure_bar = _bar(110.0, 101.0)
    atmosphere_stack.add_child(pressure_bar)
    _set_bar_accent(pressure_bar, COOL_BLUE)
    atmosphere_hint = _label("ATMOSPHERIC SYSTEMS UNLOCK AT SHIFT 11", 11, MUTED)
    atmosphere_stack.add_child(atmosphere_hint)

    var incident_panel := _panel(true)
    detail_pages[3].add_child(incident_panel)
    _style_panel_accent(incident_panel, AMBER)
    var incident_stack := _vbox(6)
    incident_panel.add_child(incident_stack)
    var incident_row := _hbox(10)
    incident_stack.add_child(incident_row)
    incident_label = _label("COMPOUND INCIDENT PROTOCOL / UNLOCK SHIFT 13", 13, CYAN)
    incident_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    incident_row.add_child(incident_label)
    incident_button = _button("NO ACTIVE INCIDENT")
    incident_button.pressed.connect(_contain_incident)
    incident_row.add_child(incident_button)
    incident_progress = _bar(18.0, 0.0)
    incident_stack.add_child(incident_progress)
    _set_bar_accent(incident_progress, AMBER)
    incident_stack.add_child(_label("SHIFT 13+: ISOLATE MULTI-SYSTEM INCIDENTS WITH [J] BEFORE THEY ESCALATE.", 11, MUTED))

    var log_panel := _panel(true)
    detail_pages[4].add_child(log_panel)
    _style_panel_accent(log_panel, COMMS_VIOLET)
    var log_stack := _vbox(5)
    log_panel.add_child(log_stack)
    log_stack.add_child(_label("ENGINEERING EVENT RECORDER  /  LATEST EVENTS  /  NO SCROLL", 13, CYAN))
    log_label = RichTextLabel.new()
    log_label.custom_minimum_size.y = 130
    log_label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
    log_label.bbcode_enabled = false
    log_label.scroll_active = false
    log_label.scroll_following = false
    log_label.fit_content = false
    log_label.add_theme_font_size_override("normal_font_size", 13)
    log_label.add_theme_color_override("default_color", MUTED)
    log_stack.add_child(log_label)
    var footer := _hbox()
    root.add_child(footer)
    var help := _label("Q/A LIFE   W/S COOL   E/D COMMS   B BATTERY  1/2/3 CB  T SERVICE  P PUMP  G OXYGEN  H SEAL  J CONTAIN  C ACK   M MUTE", 12, MUTED)
    help.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    footer.add_child(help)
    restart_button = _button("RESTART SHIFT")
    restart_button.visible = false
    restart_button.pressed.connect(_reset)
    footer.add_child(restart_button)
    _set_detail_tab(0)

func _toggle_audio() -> void:
    game_menu.show_audio = not game_menu.show_audio
    game_menu._apply_audio()
    game_menu._save_settings()
    audio_button.text = "SOUND ON [M]" if game_menu.show_audio else "SOUND OFF [M]"
    _add_log("AUDIO %s." % ("ENABLED" if game_menu.show_audio else "MUTED"))

func get_save_data() -> Dictionary:
    return {
        "version": 5,
        "incident_type": incident_type,
        "incident_timer": incident_timer,
        "containment_cooldown": containment_cooldown,
        "incidents_contained": incidents_contained,
        "incidents_total": incidents_total,
        "oxygen_pct": oxygen_pct,
        "cabin_pressure_kpa": cabin_pressure_kpa,
        "oxygen_mode": oxygen_mode,
        "pressure_leak_seconds": pressure_leak_seconds,
        "seal_cooldown": seal_cooldown,
        "reactor_temp_c": reactor_temp_c,
        "cooling_pump_mode": cooling_pump_mode,
        "cooling_pump_fault_seconds": cooling_pump_fault_seconds,
        "shift_number": shift_number,
        "shift_duration": shift_duration,
        "maintenance_integrity": maintenance_integrity,
        "maintenance_cooldown": maintenance_cooldown,
        "total_faults": total_faults,
        "remaining": remaining,
        "event_timer": event_timer,
        "reactor_output": reactor_output,
        "sag_timer": sag_timer,
        "battery_charge": battery_charge,
        "battery_enabled": battery_enabled,
        "event_count": event_count,
        "power": power.duplicate(),
        "demand": demand.duplicate(),
        "integrity": integrity.duplicate(),
        "breakers_tripped": breakers_tripped.duplicate(),
        "breaker_cooldowns": breaker_cooldowns.duplicate(),
        "log_lines": log_lines.duplicate(),
        "alarm_acknowledged": alarm_acknowledged,
        "alarm_signature": alarm_signature
    }

func load_save_data(data: Dictionary) -> bool:
    if int(data.get("version", -1)) not in [1, 2, 3, 4, 5]:
        return false
    for name in ["power", "demand", "integrity", "breakers_tripped", "breaker_cooldowns", "log_lines"]:
        if not data.has(name) or typeof(data[name]) != TYPE_ARRAY:
            return false
    for name in ["power", "demand", "integrity", "breakers_tripped", "breaker_cooldowns"]:
        if data[name].size() != 3:
            return false
    shift_number = clampi(int(data.get("shift_number", 1)), 1, 99)
    shift_duration = get_shift_duration()
    maintenance_integrity = clampf(float(data.get("maintenance_integrity", 100.0)), 0.0, 100.0)
    maintenance_cooldown = clampf(float(data.get("maintenance_cooldown", 0.0)), 0.0, 30.0)
    total_faults = maxi(0, int(data.get("total_faults", 0)))
    incident_type = clampi(int(data.get("incident_type", 0)), 0, 3)
    incident_timer = clampf(float(data.get("incident_timer", 0.0)), 0.0, 18.0)
    containment_cooldown = clampf(float(data.get("containment_cooldown", 0.0)), 0.0, 12.0)
    incidents_contained = maxi(0, int(data.get("incidents_contained", 0)))
    incidents_total = maxi(0, int(data.get("incidents_total", 0)))
    if incident_timer <= 0.0:
        incident_type = 0
    reactor_temp_c = clampf(float(data.get("reactor_temp_c", 62.0)), 0.0, 130.0)
    cooling_pump_mode = clampi(int(data.get("cooling_pump_mode", 1)), 0, 2)
    cooling_pump_fault_seconds = clampf(float(data.get("cooling_pump_fault_seconds", 0.0)), 0.0, 8.0)
    temp_alert_state = 0
    oxygen_pct = clampf(float(data.get("oxygen_pct", 96.0)), 0.0, 100.0)
    cabin_pressure_kpa = clampf(float(data.get("cabin_pressure_kpa", 101.0)), 0.0, 110.0)
    oxygen_mode = clampi(int(data.get("oxygen_mode", 1)), 0, 2)
    pressure_leak_seconds = clampf(float(data.get("pressure_leak_seconds", 0.0)), 0.0, 14.0)
    seal_cooldown = clampf(float(data.get("seal_cooldown", 0.0)), 0.0, 12.0)
    atmosphere_alert = 0
    remaining = clampf(float(data.get("remaining", shift_duration)), 0.1, shift_duration)
    event_timer = clampf(float(data.get("event_timer", get_event_interval())), 0.1, get_event_interval())
    reactor_output = clampi(int(data.get("reactor_output", REACTOR_NOMINAL)), 1, REACTOR_NOMINAL)
    sag_timer = clampf(float(data.get("sag_timer", 0.0)), 0.0, REACTOR_SAG_SECONDS)
    battery_charge = clampf(float(data.get("battery_charge", 100.0)), 0.0, 100.0)
    battery_enabled = bool(data.get("battery_enabled", false)) and battery_charge > 0.0
    event_count = maxi(0, int(data.get("event_count", 0)))
    power.clear()
    demand.clear()
    integrity.clear()
    breakers_tripped.clear()
    breaker_cooldowns.clear()
    for i in range(3):
        power.append(clampi(int(data["power"][i]), 0, MAX_SYSTEM_POWER))
        demand.append(clampi(int(data["demand"][i]), 0, MAX_SYSTEM_POWER))
        integrity.append(clampf(float(data["integrity"][i]), 0.0, 100.0))
        breakers_tripped.append(bool(data["breakers_tripped"][i]))
        breaker_cooldowns.append(clampf(float(data["breaker_cooldowns"][i]), 0.0, BREAKER_RESET_DELAY))
    log_lines.clear()
    for entry in data["log_lines"]:
        if log_lines.size() >= 150:
            break
        log_lines.append(str(entry).substr(0, 200))
    alarm_acknowledged = bool(data.get("alarm_acknowledged", false))
    alarm_signature = str(data.get("alarm_signature", ""))
    finished = false
    restart_button.visible = false
    status_label.text = "ON DUTY"
    status_label.add_theme_color_override("font_color", GREEN)
    station_audio.set_alarm(false)
    _render_log()
    _refresh()
    return true

func get_shift_duration() -> float:
    if shift_number <= 2:
        return 90.0
    if shift_number <= 4:
        return 105.0
    if shift_number <= 6:
        return 120.0
    return minf(240.0, 135.0 + float(shift_number - 7) * 15.0)

func get_event_interval() -> float:
    if shift_number <= 2:
        return 23.0
    if shift_number <= 4:
        return 19.0
    if shift_number <= 6:
        return 17.0
    return maxf(13.0, 16.0 - float(shift_number - 7) * 0.5)

func get_shift_phase() -> String:
    if shift_number <= 2:
        return "POWER TRAINING"
    if shift_number <= 4:
        return "BREAKER OPERATIONS"
    if shift_number <= 6:
        return "REACTOR STABILITY"
    if shift_number <= 8:
        return "AUXILIARY OPERATIONS"
    if shift_number <= 10:
        return "THERMAL OPERATIONS"
    if shift_number <= 12:
        return "ATMOSPHERIC OPERATIONS"
    return "ADVANCED EMERGENCY OPERATIONS"

func start_campaign() -> void:
    shift_number = 1
    _reset()

func start_next_shift() -> void:
    shift_number += 1
    _reset()

func retry_shift() -> void:
    _reset()

func _service_auxiliary() -> void:
    if finished or shift_number < 7 or maintenance_cooldown > 0.0 or (game_menu != null and game_menu.is_blocking()):
        return
    maintenance_integrity = minf(100.0, maintenance_integrity + 45.0)
    maintenance_cooldown = 16.0
    station_audio.effect("success")
    _add_log("AUXILIARY STABILISER SERVICED. INTEGRITY RECOVERED.")
    _refresh()

func _pump_mode_name() -> String:
    match cooling_pump_mode:
        0: return "OFF"
        1: return "AUTO"
        _: return "BOOST"

func _thermal_status() -> String:
    if cooling_pump_fault_seconds > 0.0:
        return "PUMP FAULT"
    if reactor_temp_c >= 105.0:
        return "CRITICAL"
    if reactor_temp_c >= 85.0:
        return "WARNING"
    return "NORMAL"

func _cycle_cooling_pump() -> void:
    if shift_number < 9 or finished or (game_menu != null and game_menu.is_blocking()):
        return
    cooling_pump_mode = (cooling_pump_mode + 1) % 3
    station_audio.effect("click")
    _add_log("COOLING PUMP CONTROL SET TO %s." % _pump_mode_name())
    _refresh()

func _update_thermal(delta: float) -> void:
    if cooling_pump_fault_seconds > 0.0:
        cooling_pump_fault_seconds = maxf(0.0, cooling_pump_fault_seconds - delta)
        if cooling_pump_fault_seconds <= 0.0:
            _add_log("COOLING PUMP FAULT CLEARED; CONTROL RESTORED.")
    var powered: bool = not breakers_tripped[1] and power[1] >= demand[1]
    var cooling_rate: float = 0.0
    if powered and cooling_pump_fault_seconds <= 0.0:
        if cooling_pump_mode == 1:
            cooling_rate = 0.68
        elif cooling_pump_mode == 2:
            cooling_rate = 1.4
    # These are gameplay tuning rates, not thermodynamic calculations.
    var heat_rate: float = 0.50 + float(maxi(0, 6 - reactor_output)) * 0.12
    if incident_type == 1:
        heat_rate += 0.65
    if not powered:
        heat_rate += 0.12
    reactor_temp_c = clampf(reactor_temp_c + (heat_rate - cooling_rate) * delta, 35.0, 130.0)
    var new_alert := 0
    if reactor_temp_c >= 105.0:
        new_alert = 2
    elif reactor_temp_c >= 85.0:
        new_alert = 1
    if new_alert != temp_alert_state:
        temp_alert_state = new_alert
        if new_alert == 2:
            _add_log("CRITICAL: REACTOR CORE ABOVE 105°C! RESTORE COOLING.")
        elif new_alert == 1:
            _add_log("WARNING: REACTOR CORE ABOVE 85°C.")
        else:
            _add_log("REACTOR TEMPERATURE RETURNED TO NORMAL RANGE.")
    if reactor_temp_c >= 130.0:
        _finish(false, "REACTOR OVERHEAT SHUTDOWN.")

func _oxygen_mode_name() -> String:
    match oxygen_mode:
        0:
            return "OFF"
        1:
            return "AUTO"
        _:
            return "BOOST"

func _cycle_oxygen_generator() -> void:
    if shift_number < 11 or finished or (game_menu != null and game_menu.is_blocking()):
        return
    oxygen_mode = (oxygen_mode + 1) % 3
    station_audio.effect("click")
    _add_log("OXYGEN GENERATOR SET TO %s." % _oxygen_mode_name())
    _refresh()

func _seal_cabin() -> void:
    if shift_number < 12 or finished or pressure_leak_seconds <= 0.0 or seal_cooldown > 0.0 or (game_menu != null and game_menu.is_blocking()):
        return
    pressure_leak_seconds = 0.0
    seal_cooldown = 8.0
    station_audio.effect("success")
    _add_log("CABIN EMERGENCY SEAL ENGAGED. PRESSURE RECOVERY ACTIVE.")
    _refresh()

func _update_atmosphere(delta: float) -> void:
    seal_cooldown = maxf(0.0, seal_cooldown - delta)
    if pressure_leak_seconds > 0.0:
        pressure_leak_seconds = maxf(0.0, pressure_leak_seconds - delta)
        if pressure_leak_seconds <= 0.0:
            _add_log("CABIN LEAK AUTO-CONTAINED; PRESSURISATION RESTORING.")
    var life_powered: bool = not breakers_tripped[0] and power[0] >= demand[0]
    var generation := 0.0
    if life_powered:
        if oxygen_mode == 1:
            generation = 0.37
        elif oxygen_mode == 2:
            generation = 0.82
    # Fictional arcade balancing, not real crew oxygen dynamics.
    oxygen_pct = clampf(oxygen_pct + (generation - 0.25) * delta, 0.0, 100.0)
    var pressure_rate := 0.16 if life_powered and oxygen_mode != 0 else -0.12
    if pressure_leak_seconds > 0.0:
        pressure_rate -= 1.25
    if incident_type == 2:
        pressure_rate -= 0.8
    cabin_pressure_kpa = clampf(cabin_pressure_kpa + pressure_rate * delta, 0.0, 101.0)
    var level := 0
    if oxygen_pct <= 25.0 or cabin_pressure_kpa <= 65.0:
        level = 2
    elif oxygen_pct <= 50.0 or cabin_pressure_kpa <= 80.0:
        level = 1
    if level != atmosphere_alert:
        atmosphere_alert = level
        if level == 2:
            _add_log("CRITICAL: ATMOSPHERIC RESERVES LOW. RESTORE LIFE SUPPORT.")
        elif level == 1:
            _add_log("WARNING: OXYGEN OR CABIN PRESSURE LOW.")
        else:
            _add_log("ATMOSPHERIC CONDITIONS RETURNED TO SAFE RANGE.")
    if oxygen_pct <= 0.0 or cabin_pressure_kpa <= 50.0:
        _finish(false, "HABITAT ATMOSPHERE FAILED.")

func _incident_name() -> String:
    match incident_type:
        1:
            return "COOLANT MANIFOLD RUPTURE"
        2:
            return "HULL PRESSURE BREACH"
        3:
            return "COMMUNICATIONS BUS ARC"
        _:
            return "NONE"

func _start_compound_incident() -> void:
    # Every fourth event from Shift 13; a new event cannot overwrite an active one.
    incident_type = 1 + rng.randi_range(0, 2)
    incident_timer = 18.0
    incidents_total += 1
    station_audio.effect("critical")
    _add_log("CRITICAL: COMPOUND INCIDENT / %s. CONTAIN WITH [J]." % _incident_name())

func _update_incident(delta: float) -> void:
    containment_cooldown = maxf(0.0, containment_cooldown - delta)
    if incident_type == 0:
        return
    incident_timer = maxf(0.0, incident_timer - delta)
    if incident_timer <= 0.0:
        _add_log("WARNING: %s SUBSIDED WITHOUT OPERATOR CONTAINMENT." % _incident_name())
        incident_type = 0

func _contain_incident() -> void:
    if shift_number < 13 or finished or incident_type == 0 or containment_cooldown > 0.0 or (game_menu != null and game_menu.is_blocking()):
        return
    var name: String = _incident_name()
    incident_type = 0
    incident_timer = 0.0
    containment_cooldown = 10.0
    incidents_contained += 1
    station_audio.effect("success")
    _add_log("EMERGENCY CONTAINMENT COMPLETED: %s." % name)
    _refresh()
