extends Control
## V1.1 visual-only station attract mode for the main menu.
## No gameplay state, save file access, or player controls are used here.
const C_BG := Color("#071421")
const C_PANEL := Color("#0e2533")
const C_EDGE := Color("#235063")
const C_CYAN := Color("#5cdae7")
const C_GREEN := Color("#75e2ac")
const C_AMBER := Color("#ffc476")
const C_MUTED := Color("#7597a7")
const C_TEXT := Color("#bad6e1")
const VIEW := Vector2(1600.0, 900.0)

var elapsed: float = 0.0
var redraw_timer: float = 0.0
var log_timer: float = 2.0
var warning_timer: float = 0.0
var rng := RandomNumberGenerator.new()
var entries: Array[String] = []
var log_index: int = 0

const MESSAGES := [
    "PRIMARY REACTOR OUTPUT STABLE",
    "POWER BUS SYNCHRONISATION COMPLETE",
    "COOLANT LOOP FLOW NOMINAL",
    "LIFE SUPPORT TELEMETRY RECEIVED",
    "BATTERY BUFFER AVAILABLE",
    "ATMOSPHERIC CONTROL LOOP ACTIVE",
    "ORBITAL RELAY UPLINK VERIFIED",
    "AUXILIARY STABILISER ONLINE",
    "AUTOMATED DIAGNOSTICS COMPLETE",
    "MINOR LOAD SHIFT DETECTED",
    "BUS VOLTAGE RETURNED TO NOMINAL"
]

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    rng.randomize()
    entries = [
        "00:00  SYSTEM INITIALISATION COMPLETE",
        "00:01  STATION POWER NETWORK ONLINE",
        "00:03  ALL CONTROL LOOPS READY",
        "00:04  ENGINEERING WATCH STANDBY"
    ]
    # Background is entirely procedural and intentionally independent from the game.
    queue_redraw()

func _process(delta: float) -> void:
    elapsed += delta
    log_timer -= delta
    warning_timer = maxf(0.0, warning_timer - delta)
    if log_timer <= 0.0:
        log_timer = rng.randf_range(4.2, 7.6)
        log_index += 1
        var message: String = MESSAGES[rng.randi_range(0, MESSAGES.size() - 1)]
        var mins: int = int(elapsed) / 60
        var secs: int = int(elapsed) % 60
        entries.push_front("%02d:%02d  %s" % [mins, secs, message])
        if entries.size() > 14:
            entries.resize(14)
        if log_index % 5 == 0:
            warning_timer = 2.8
    redraw_timer += delta
    if redraw_timer >= 0.04:
        redraw_timer = 0.0
        queue_redraw()

func _draw() -> void:
    if size.x < 10.0 or size.y < 10.0:
        return
    draw_set_transform(Vector2.ZERO, 0.0, Vector2(size.x / VIEW.x, size.y / VIEW.y))
    draw_rect(Rect2(Vector2.ZERO, VIEW), C_BG)
    _grid()
    _header()
    _power_network()
    _systems()
    _history()
    _footer()
    draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _grid() -> void:
    for x in range(0, 1601, 50):
        draw_line(Vector2(float(x), 0.0), Vector2(float(x), 900.0), Color("#123343", 0.55), 1.0)
    for y in range(0, 901, 50):
        draw_line(Vector2(0.0, float(y)), Vector2(1600.0, float(y)), Color("#123343", 0.55), 1.0)

func _font() -> Font:
    return ThemeDB.fallback_font

func _text(pos: Vector2, message: String, color: Color = C_TEXT, font_size: int = 14) -> void:
    draw_string(_font(), pos, message, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _panel(rect: Rect2, heading: String) -> void:
    draw_rect(rect, C_PANEL, true)
    draw_rect(rect, C_EDGE, false, 1.0)
    draw_rect(Rect2(rect.position, Vector2(rect.size.x, 32.0)), Color("#133849"), true)
    _text(rect.position + Vector2(13.0, 22.0), heading, C_CYAN, 13)

func _meter(position: Vector2, width: float, value: float, maximum: float, color: Color) -> void:
    draw_rect(Rect2(position, Vector2(width, 7.0)), Color("#244451"), true)
    draw_rect(Rect2(position, Vector2(width * clampf(value / maximum, 0.0, 1.0), 7.0)), color, true)

func _flow(a: Vector2, b: Vector2, color: Color, speed: float = 64.0) -> void:
    draw_line(a, b, Color("#244754"), 6.0, true)
    draw_line(a, b, color, 2.0, true)
    var distance: float = a.distance_to(b)
    if distance < 4.0:
        return
    var direction: Vector2 = (b - a) / distance
    for i in range(3):
        var offset: float = fposmod(elapsed * speed + float(i) * distance / 3.0, distance)
        draw_circle(a + direction * offset, 3.0, C_TEXT)

func _header() -> void:
    draw_rect(Rect2(28.0, 26.0, 1544.0, 58.0), C_PANEL, true)
    draw_rect(Rect2(28.0, 26.0, 1544.0, 58.0), C_EDGE, false, 1.0)
    _text(Vector2(48.0, 50.0), "SZ-00   /   ORBITAL ENGINEERING NETWORK", C_CYAN, 16)
    _text(Vector2(48.0, 71.0), "UNATTENDED TELEMETRY  //  DEMONSTRATION FEED", C_MUTED, 11)
    _text(Vector2(1215.0, 50.0), "STATION LINK  /  ACTIVE", C_GREEN, 15)
    _text(Vector2(1215.0, 71.0), "CONTROL STATUS  /  STANDBY", C_MUTED, 12)
    draw_circle(Vector2(1193.0, 46.0), 6.0 + sin(elapsed * 2.3) * 1.5, C_GREEN)

func _power_network() -> void:
    _panel(Rect2(38.0, 109.0, 372.0, 322.0), "01  /  PRIMARY GENERATION")
    var reactor: float = 5.72 + 0.24 * sin(elapsed * 0.33)
    var charge: float = 83.0 + 5.0 * sin(elapsed * 0.19)
    _text(Vector2(59.0, 166.0), "REACTOR OUTPUT", C_MUTED, 12)
    _text(Vector2(59.0, 199.0), "%.2f MW" % reactor, C_TEXT, 26)
    _meter(Vector2(59.0, 218.0), 322.0, reactor, 6.0, C_GREEN)
    _text(Vector2(59.0, 275.0), "EMERGENCY BATTERY", C_MUTED, 12)
    _text(Vector2(59.0, 306.0), "%.1f%%" % charge, C_TEXT, 24)
    _meter(Vector2(59.0, 326.0), 322.0, charge, 100.0, C_CYAN)
    _text(Vector2(59.0, 391.0), "GENERATION BUS: SYNCHRONISED", C_GREEN, 12)

    _panel(Rect2(1190.0, 109.0, 372.0, 322.0), "02  /  DISTRIBUTION CONTROL")
    var loads := ["LIFE SUPPORT", "REACTOR COOLING", "COMMS RELAY"]
    for i in range(3):
        var y: float = 165.0 + float(i) * 84.0
        _text(Vector2(1210.0, y), loads[i], C_MUTED, 13)
        var v: float = 63.0 + 22.0 * sin(elapsed * (0.31 + float(i) * 0.1) + float(i) * 1.6)
        _meter(Vector2(1210.0, y + 17.0), 324.0, v, 100.0, C_AMBER if warning_timer > 0.0 and i == 2 else C_CYAN)
        _text(Vector2(1458.0, y - 17.0), "%02d%%" % int(v), C_TEXT, 13)

    # Animated electrical network. The centre is intentionally left behind the menu.
    var bus_y := 465.0
    _flow(Vector2(410.0, 269.0), Vector2(570.0, 269.0), C_CYAN)
    _flow(Vector2(570.0, 269.0), Vector2(570.0, bus_y), C_CYAN)
    _flow(Vector2(570.0, bus_y), Vector2(1030.0, bus_y), C_CYAN, 96.0)
    _flow(Vector2(1030.0, bus_y), Vector2(1030.0, 269.0), C_CYAN)
    _flow(Vector2(1030.0, 269.0), Vector2(1190.0, 269.0), C_CYAN)
    _text(Vector2(665.0, 452.0), "MAIN DISTRIBUTION BUS", C_CYAN, 13)
    draw_circle(Vector2(570.0, bus_y), 6.0, C_GREEN)
    draw_circle(Vector2(1030.0, bus_y), 6.0, C_GREEN)

func _systems() -> void:
    _panel(Rect2(38.0, 456.0, 372.0, 156.0), "03  /  REACTOR THERMAL")
    var temperature: float = 64.4 + sin(elapsed * 0.38) * 5.3
    _text(Vector2(59.0, 529.0), "CORE TEMP     %.1f C" % temperature, C_TEXT, 20)
    _meter(Vector2(59.0, 554.0), 322.0, temperature, 130.0, C_CYAN)
    _text(Vector2(59.0, 590.0), "COOLANT LOOP / AUTOMATIC", C_GREEN, 12)

    _panel(Rect2(1190.0, 456.0, 372.0, 156.0), "04  /  HABITAT ATMOSPHERE")
    var oxygen: float = 96.0 + sin(elapsed * 0.21) * 1.8
    var pressure: float = 100.2 + sin(elapsed * 0.17) * 1.2
    _text(Vector2(1210.0, 525.0), "OXYGEN       %.1f%%" % oxygen, C_TEXT, 18)
    _meter(Vector2(1210.0, 537.0), 324.0, oxygen, 100.0, C_GREEN)
    _text(Vector2(1210.0, 574.0), "PRESSURE     %.1f kPa" % pressure, C_TEXT, 17)

func _history() -> void:
    _panel(Rect2(38.0, 633.0, 700.0, 215.0), "05  /  ENGINEERING EVENT RECORDER")
    for i in range(mini(entries.size(), 6)):
        var item: String = entries[i]
        var ink: Color = C_AMBER if item.contains("MINOR") else C_MUTED
        _text(Vector2(58.0, 688.0 + float(i) * 26.0), item, ink, 13)

    _panel(Rect2(852.0, 633.0, 710.0, 215.0), "06  /  COMMUNICATIONS & SENSORS")
    var signal: float = -82.0 + 3.0 * sin(elapsed * 0.5)
    _text(Vector2(875.0, 695.0), "RELAY  145.250 MHz         SIGNAL %.1f dBm" % signal, C_TEXT, 14)
    _text(Vector2(875.0, 730.0), "TELEMETRY LINK   /  RECEIVING", C_GREEN, 14)
    _meter(Vector2(875.0, 752.0), 648.0, 77.0 + 9.0 * sin(elapsed * 0.32), 100.0, C_CYAN)
    var event: String = "MINOR ATTENUATION DETECTED" if warning_timer > 0.0 else "NO ACTIVE COMMUNICATIONS ALARMS"
    _text(Vector2(875.0, 806.0), event, C_AMBER if warning_timer > 0.0 else C_MUTED, 13)

func _footer() -> void:
    _text(Vector2(47.0, 880.0), "SZ-00  //  AUTONOMOUS MONITORING SIMULATION  //  NO LIVE GAME DATA", C_MUTED, 11)
    _text(Vector2(1210.0, 880.0), "ENGINEERING WATCH / STANDBY", C_CYAN, 11)
