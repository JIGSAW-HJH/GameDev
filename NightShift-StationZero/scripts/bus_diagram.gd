extends Control
## Visual single-line electrical diagram; gameplay is handled in main.gd.
var reactor_units: int = 6
var load_units: Array[int] = [2, 2, 2]
var demand_units: Array[int] = [2, 2, 2]
var battery_online: bool = false
var brownout: bool = false
var breakers_tripped: Array[bool] = [false, false, false]
var animation_time: float = 0.0

const BLUE := Color("#58d6e9")
const GREEN := Color("#77e3ae")
const YELLOW := Color("#ffc56e")
const RED := Color("#ff7187")
const FAINT := Color("#325367")
const TEXT := Color("#b3cedc")

func _process(delta: float) -> void:
    animation_time += delta
    queue_redraw()

func _draw() -> void:
    var w: float = size.x
    if w < 120.0:
        return
    var font: Font = ThemeDB.fallback_font
    var label_size := 12
    var mid_y := 51.0
    var source_x := 95.0
    var bus_x := w * 0.38
    var branch_x := w * 0.58
    var ends := [w * 0.70, w * 0.83, w * 0.96]
    var branch_ys := [18.0, 51.0, 84.0]
    var live_color: Color = RED if brownout else BLUE
    draw_rect(Rect2(9.0, 31.0, 104.0, 40.0), Color("#102f40"), true)
    draw_rect(Rect2(9.0, 31.0, 104.0, 40.0), BLUE, false, 1.0)
    draw_string(font, Vector2(20.0, 47.0), "REACTOR", HORIZONTAL_ALIGNMENT_LEFT, -1, label_size, TEXT)
    draw_string(font, Vector2(25.0, 62.0), "%d / 6 UNITS" % reactor_units, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, GREEN if reactor_units == 6 else YELLOW)
    _wire(Vector2(113.0, mid_y), Vector2(bus_x, mid_y), live_color, reactor_units > 0)
    var battery_x := w * 0.25
    var battery_color: Color = GREEN if battery_online else FAINT
    _wire(Vector2(battery_x, 17.0), Vector2(battery_x, mid_y), battery_color, battery_online)
    draw_rect(Rect2(battery_x - 49.0, 1.0, 98.0, 20.0), battery_color, false, 1.0)
    draw_string(font, Vector2(battery_x - 44.0, 15.0), "BATTERY +2" if battery_online else "BATTERY OFF", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, battery_color)
    draw_line(Vector2(bus_x, 10.0), Vector2(bus_x, 94.0), live_color, 5.0, true)
    draw_string(font, Vector2(bus_x - 30.0, 109.0), "MAIN BUS", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, TEXT)
    _wire(Vector2(bus_x, mid_y), Vector2(branch_x, mid_y), live_color, true)
    draw_line(Vector2(branch_x, branch_ys[0]), Vector2(branch_x, branch_ys[2]), live_color, 3.0, true)
    var names := ["LIFE", "COOLING", "COMMS"]
    for i in range(3):
        var y: float = branch_ys[i]
        var okay: bool = load_units[i] >= demand_units[i]
        var branch_color: Color = GREEN if okay else YELLOW
        if load_units[i] == 0 or breakers_tripped[i]:
            branch_color = RED
        _wire(Vector2(branch_x, y), Vector2(ends[i] - 72.0, y), branch_color, load_units[i] > 0 and not breakers_tripped[i])
        draw_rect(Rect2(ends[i] - 72.0, y - 11.0, 69.0, 23.0), Color("#0d2633"), true)
        draw_rect(Rect2(ends[i] - 72.0, y - 11.0, 69.0, 23.0), branch_color, false, 1.0)
        draw_string(font, Vector2(ends[i] - 68.0, y - 1.0), names[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, TEXT)
        draw_string(font, Vector2(ends[i] - 68.0, y + 9.0), "CB OPEN" if breakers_tripped[i] else "%dU / %dU" % [load_units[i], demand_units[i]], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, branch_color)

func _wire(a: Vector2, b: Vector2, color: Color, animated: bool) -> void:
    draw_line(a, b, FAINT, 4.0, true)
    draw_line(a, b, color, 2.0, true)
    if not animated:
        return
    var length: float = a.distance_to(b)
    if length < 8.0:
        return
    var direction: Vector2 = (b - a).normalized()
    var pulse: float = fposmod(animation_time * 54.0, length)
    draw_circle(a + direction * pulse, 3.7, Color.WHITE)
