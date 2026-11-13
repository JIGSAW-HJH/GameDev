extends Control
## NIGHT SHIFT: STATION ZERO — V0.7 progressive shift campaign.
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
    _add_log("NIGHT SHIFT INITIALIZED. ALL SYSTEMS NOMINAL.")
    _add_log("SHIFT POWER TO MATCH CHANGING DEMAND.")
    _add_log("BATTERY LASTS LONGER; FREE REACTOR UNITS TO RECHARGE.")
    _add_log("BREAKER FAULTS: WAIT 3S, THEN RESET WITH 1 / 2 / 3.")
    _refresh()

func _process(delta: float) -> void:
    if finished or (game_menu != null and game_menu.is_blocking()):
        return
    remaining = maxf(0.0, remaining - delta)
    if shift_number >= 7:
        maintenance_cooldown = maxf(0.0, maintenance_cooldown - delta)
        maintenance_integrity = maxf(0.0, maintenance_integrity - delta * (0.15 + float(shift_number - 7) * 0.015))
        if maintenance_integrity <= 0.0:
            _finish(false, "AUXILIARY STABILISER FAILED.")
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
    var stressed: int = rng.randi_range(0, 2)
    demand = [2, 2, 2]
    demand[stressed] = 3
    # One trip at a time; no trip on the first demand event.
    # Alternating events keep faults recoverable and preserve a clear power puzzle.
    if shift_number >= 3 and event_count % 2 == 0 and not breakers_tripped.has(true):
        _trip_breaker(stressed)
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
    if log_lines.size() > 6:
        log_lines.resize(6)
    _render_log()

func _render_log() -> void:
    if log_label == null:
        return
    log_label.clear()
    for entry in log_lines:
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
    var secs: int = int(ceil(remaining))
    clock_label.text = "%02d:%02d" % [int(secs / 60), secs % 60]
    if shift_label != null:
        shift_label.text = "SHIFT %02d  /  %s" % [shift_number, get_shift_phase()]
    if maintenance_label != null:
        maintenance_label.text = "AUX STABILISER  %d%%  •  %s" % [int(ceil(maintenance_integrity)), ("READY [T]" if maintenance_cooldown <= 0.0 else "REPAIR COOLDOWN %dS" % int(ceil(maintenance_cooldown)))] if shift_number >= 7 else "AUX STABILISER  /  UNLOCKS SHIFT 07"
        maintenance_label.add_theme_color_override("font_color", RED if shift_number >= 7 and maintenance_integrity < 35.0 else CYAN)
    if maintenance_button != null:
        maintenance_button.disabled = shift_number < 7 or maintenance_cooldown > 0.0 or finished
    var allocated: int = _total_power()
    var capacity: int = _available_capacity()
    budget_label.text = "%d / %d UNITS ASSIGNED    •    %d FREE" % [allocated, capacity, maxi(0, capacity - allocated)]
    reactor_label.text = "%d / 6 UNITS" % reactor_output
    reactor_bar.value = reactor_output
    battery_label.text = "%d%% CHARGE" % int(ceil(battery_charge))
    battery_bar.value = battery_charge
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
    if shift_number >= 7 and maintenance_integrity < 35.0:
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
        line_labels[i].text = "BUS %s  %dU" % [["A", "B", "C"][i], power[i]]
        var okay: bool = power[i] >= demand[i] and not breakers_tripped[i]
        demand_labels[i].add_theme_color_override("font_color", GREEN if okay else RED)
        line_labels[i].add_theme_color_override("font_color", CYAN if okay else AMBER)
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
    style.set_content_margin_all(14)
    p.add_theme_stylebox_override("panel", style)
    return p

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
    b.custom_minimum_size = Vector2(49, 34)
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

func _build_ui() -> void:
    var bg := ColorRect.new()
    bg.color = BG
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(bg)
    var margins := MarginContainer.new()
    margins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    for side in ["left", "right", "top", "bottom"]:
        margins.add_theme_constant_override("margin_" + side, 18)
    add_child(margins)
    var root := _vbox(9)
    margins.add_child(root)
    var header := _hbox()
    root.add_child(header)
    var head_left := _vbox(2)
    head_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    header.add_child(head_left)
    head_left.add_child(_label("OS / 07    ·    ORBITAL ENGINEERING NETWORK    ·    SECURE OPERATOR TERMINAL", 12, CYAN))
    head_left.add_child(_label("NIGHT SHIFT   /   STATION ZERO", 29))
    shift_label = _label("SHIFT 01 / POWER TRAINING", 14, CYAN)
    head_left.add_child(shift_label)
    var head_right := _vbox(2)
    header.add_child(head_right)
    head_right.add_child(_label("TIME UNTIL SHIFT HANDOVER", 11, MUTED))
    clock_label = _label("02:00", 30, CYAN)
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

    var power_row := _hbox(12)
    root.add_child(power_row)
    var reactor_panel := _panel()
    reactor_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    power_row.add_child(reactor_panel)
    var reactor_stack := _vbox(8)
    reactor_panel.add_child(reactor_stack)
    reactor_stack.add_child(_label("01   PRIMARY REACTOR", 15, CYAN))
    reactor_label = _label("6 / 6 UNITS", 20)
    reactor_stack.add_child(reactor_label)
    reactor_bar = _bar(6.0, 6.0)
    reactor_stack.add_child(reactor_bar)
    reactor_stack.add_child(_label("FAULT EVENTS CAN REDUCE AVAILABLE OUTPUT", 11, MUTED))

    var battery_panel := _panel()
    battery_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    power_row.add_child(battery_panel)
    var battery_stack := _vbox(7)
    battery_panel.add_child(battery_stack)
    battery_stack.add_child(_label("02   EMERGENCY BATTERY", 15, CYAN))
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
    battery_stack.add_child(_label("+2 BUS UNITS WHEN ENABLED  /  DRAINS ONLY WHEN NEEDED  /  FREE REACTOR CAPACITY TO RECHARGE", 11, MUTED))

    var bus_panel := _panel(true)
    root.add_child(bus_panel)
    var bus_stack := _vbox(4)
    bus_panel.add_child(bus_stack)
    bus_stack.add_child(_label("03   HIGH-VOLTAGE DISTRIBUTION  /  LIVE SINGLE-LINE DIAGRAM", 12, CYAN))
    bus_diagram = Control.new()
    bus_diagram.set_script(load("res://scripts/bus_diagram.gd"))
    bus_diagram.custom_minimum_size = Vector2(0, 112)
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

    var systems_row := _hbox(12)
    systems_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
    root.add_child(systems_row)
    for i in range(3):
        var p := _panel()
        p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        systems_row.add_child(p)
        var stack := _vbox(11)
        p.add_child(stack)
        stack.add_child(_label("0%d   %s" % [i + 4, SYSTEMS[i]], 15, CYAN))
        var led := _label("●  NOMINAL", 12, GREEN)
        stack.add_child(led)
        subsystem_leds.append(led)
        var line := _label("BUS %s  2U" % ['A', 'B', 'C'][i], 13, CYAN)
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
        integrity_bars.append(bar)
        var request := _label("DEMAND  2 UNITS", 16, GREEN)
        stack.add_child(request)
        demand_labels.append(request)
        var spacer := Control.new()
        spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
        stack.add_child(spacer)
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
        stack.add_child(_label("KEYBOARD  " + SHORT_KEYS[i], 12, MUTED))

    var log_panel := _panel(true)
    root.add_child(log_panel)
    var log_stack := _vbox(5)
    log_panel.add_child(log_stack)
    log_stack.add_child(_label("ENGINEERING EVENT RECORDER  /  LIVE SYSTEM LOG", 13, CYAN))
    log_label = RichTextLabel.new()
    log_label.custom_minimum_size.y = 106
    log_label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
    log_label.bbcode_enabled = false
    log_label.scroll_active = false
    log_label.add_theme_font_size_override("normal_font_size", 13)
    log_label.add_theme_color_override("default_color", MUTED)
    log_stack.add_child(log_label)
    var footer := _hbox()
    root.add_child(footer)
    var help := _label("Q/A LIFE   W/S COOL   E/D COMMS   B BATTERY   1/2/3 BREAKERS   C ACK   M MUTE   R RESTART", 12, MUTED)
    help.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    footer.add_child(help)
    restart_button = _button("RESTART SHIFT")
    restart_button.visible = false
    restart_button.pressed.connect(_reset)
    footer.add_child(restart_button)

func _toggle_audio() -> void:
    game_menu.show_audio = not game_menu.show_audio
    game_menu._apply_audio()
    game_menu._save_settings()
    audio_button.text = "SOUND ON [M]" if game_menu.show_audio else "SOUND OFF [M]"
    _add_log("AUDIO %s." % ("ENABLED" if game_menu.show_audio else "MUTED"))

func get_save_data() -> Dictionary:
    return {
        "version": 2,
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
    if int(data.get("version", -1)) not in [1, 2]:
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
        if log_lines.size() >= 6:
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
    return "AUXILIARY OPERATIONS"

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
