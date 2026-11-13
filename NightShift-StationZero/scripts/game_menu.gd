extends CanvasLayer
## V0.6: front-end, pause menu, persistent saves and settings.
signal menu_closed
const SAVE_PATH := "user://station_zero_save.json"
const SETTINGS_PATH := "user://station_zero_settings.cfg"
const ACTIONS := [
    "life_up", "life_down", "cool_up", "cool_down", "comms_up", "comms_down",
    "battery", "ack", "breaker_1", "breaker_2", "breaker_3", "mute"
]
const ACTION_LABELS := [
    "Life support +", "Life support -", "Cooling +", "Cooling -",
    "Communications +", "Communications -", "Toggle battery", "Acknowledge alarm",
    "Reset breaker 1", "Reset breaker 2", "Reset breaker 3", "Mute audio"
]
const DEFAULT_KEYS := [KEY_Q, KEY_A, KEY_W, KEY_S, KEY_E, KEY_D, KEY_B, KEY_C, KEY_1, KEY_2, KEY_3, KEY_M]
const CYAN := Color("#65e2e8")
const WHITE := Color("#e7f3f7")
const MUTED := Color("#8ba6b7")
const BG := Color("#060d17")
const PANEL := Color("#102335")
const BORDER := Color("#28546a")
var game
var overlay: ColorRect
var content: VBoxContainer
var current_page := "title"
var settings_return := "title"
var in_session := false
var waiting_for_key := ""
var bindings: Dictionary = {}
var master_volume := 0.75
var ambience_volume := 0.45
var effects_volume := 0.85
var alarm_volume := 0.85
var show_audio := true
var status_message := ""
var confirm_dialog: ConfirmationDialog

func _ready() -> void:
    game = get_parent()
    process_mode = Node.PROCESS_MODE_ALWAYS
    _load_settings()
    _apply_audio()
    overlay = ColorRect.new()
    overlay.color = BG
    overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    overlay.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(overlay)
    var center := CenterContainer.new()
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    overlay.add_child(center)
    var panel := PanelContainer.new()
    panel.custom_minimum_size = Vector2(700.0, 0.0)
    var style := StyleBoxFlat.new()
    style.bg_color = PANEL
    style.border_color = BORDER
    style.set_border_width_all(2)
    style.set_corner_radius_all(12)
    style.set_content_margin_all(34)
    panel.add_theme_stylebox_override("panel", style)
    center.add_child(panel)
    var scroller := ScrollContainer.new()
    scroller.custom_minimum_size = Vector2(630.0, minf(680.0, get_viewport().get_visible_rect().size.y * 0.70))
    scroller.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    panel.add_child(scroller)
    content = VBoxContainer.new()
    content.custom_minimum_size.x = 620.0
    content.add_theme_constant_override("separation", 12)
    scroller.add_child(content)
    confirm_dialog = ConfirmationDialog.new()
    confirm_dialog.title = "Confirm action"
    confirm_dialog.ok_button_text = "Confirm"
    add_child(confirm_dialog)
    show_title()

func is_blocking() -> bool:
    return overlay.visible

func _input(event: InputEvent) -> void:
    if not event is InputEventKey or not event.pressed or event.echo:
        return
    var key_event := event as InputEventKey
    if waiting_for_key != "":
        get_viewport().set_input_as_handled()
        if key_event.keycode == KEY_ESCAPE:
            waiting_for_key = ""
            show_settings()
            return
        var chosen := key_event.keycode
        if chosen == KEY_NONE:
            chosen = key_event.physical_keycode
        if chosen == KEY_NONE:
            return
        for action in ACTIONS:
            if action != waiting_for_key and int(bindings.get(action, 0)) == chosen:
                status_message = "Key already assigned to %s. Choose another key." % ACTION_LABELS[ACTIONS.find(action)]
                waiting_for_key = ""
                show_settings()
                return
        bindings[waiting_for_key] = chosen
        waiting_for_key = ""
        _save_settings()
        show_settings()
        return
    if key_event.keycode == KEY_ESCAPE:
        get_viewport().set_input_as_handled()
        if current_page == "settings":
            _settings_back()
        elif in_session and overlay.visible:
            resume_game()
        elif in_session:
            show_pause()
        return

func action_for_key(code: int) -> String:
    for action in ACTIONS:
        if int(bindings.get(action, 0)) == code:
            return action
    return ""

func _clear() -> void:
    for child in content.get_children():
        content.remove_child(child)
        child.queue_free()

func _label(value: String, size: int = 18, color: Color = WHITE) -> Label:
    var label := Label.new()
    label.text = value
    label.add_theme_color_override("font_color", color)
    label.add_theme_font_size_override("font_size", size)
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    return label

func _button(value: String, callback: Callable) -> Button:
    var button := Button.new()
    button.text = value
    button.custom_minimum_size = Vector2(0.0, 44.0)
    button.add_theme_font_size_override("font_size", 17)
    button.pressed.connect(callback)
    content.add_child(button)
    return button

func _heading(subtitle: String) -> void:
    content.add_child(_label("NIGHT SHIFT", 38, CYAN))
    content.add_child(_label("STATION ZERO  //  ENGINEERING DIVISION", 18, WHITE))
    content.add_child(_label(subtitle, 15, MUTED))
    content.add_child(HSeparator.new())

func _notice() -> void:
    if status_message != "":
        content.add_child(_label(status_message, 14, CYAN))
        status_message = ""

func show_title() -> void:
    current_page = "title"
    overlay.show()
    _clear()
    _heading("GITHUB GAME OFF 2026  •  SHIFT")
    _button("NEW SHIFT", _new_game_request)
    var continue_button := _button("CONTINUE SAVED SHIFT", _continue_game)
    continue_button.disabled = not FileAccess.file_exists(SAVE_PATH)
    _button("SETTINGS", show_settings)
    _button("EXIT GAME", _exit_game)
    _notice()

func show_pause() -> void:
    current_page = "pause"
    overlay.show()
    game.station_audio.set_alarm(false)
    _clear()
    _heading("SHIFT PAUSED  //  OPERATIONS SUSPENDED")
    _button("RESUME SHIFT", resume_game)
    _button("SAVE SHIFT", _save_game)
    _button("LOAD SAVED SHIFT", _load_request).disabled = not FileAccess.file_exists(SAVE_PATH)
    _button("NEW SHIFT", _new_game_request)
    _button("SETTINGS", show_settings)
    _button("RETURN TO MAIN MENU", _return_to_title)
    _button("EXIT GAME", _exit_game)
    _notice()

func show_settings() -> void:
    if current_page != "settings":
        settings_return = current_page
    current_page = "settings"
    overlay.show()
    _clear()
    _heading("SETTINGS  //  AUDIO & CONTROL MAPPING")
    _slider("MASTER VOLUME", master_volume, _master_changed)
    _slider("STATION AMBIENCE", ambience_volume, _ambience_changed)
    _slider("UI & BREAKER SOUNDS", effects_volume, _effects_changed)
    _slider("ALARM VOLUME", alarm_volume, _alarm_changed)
    var audio_button := _button("SOUND: ON" if show_audio else "SOUND: OFF", _toggle_sound)
    audio_button.tooltip_text = "Enable or mute all station audio."
    content.add_child(HSeparator.new())
    content.add_child(_label("KEY BINDINGS  //  CLICK TO REASSIGN", 15, CYAN))
    for i in range(ACTIONS.size()):
        var action: String = ACTIONS[i]
        var row := HBoxContainer.new()
        row.add_theme_constant_override("separation", 10)
        var name_label := _label(ACTION_LABELS[i], 14, WHITE)
        name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
        row.add_child(name_label)
        var key_button := Button.new()
        key_button.text = OS.get_keycode_string(int(bindings[action]))
        key_button.custom_minimum_size = Vector2(160, 33)
        key_button.pressed.connect(_begin_rebind.bind(action))
        row.add_child(key_button)
        content.add_child(row)
    content.add_child(_label("ESC is reserved for pause/back. Duplicate keys are blocked.", 13, MUTED))
    _button("RESET DEFAULT KEYS", _reset_keys)
    _button("BACK", _settings_back)
    _notice()

func _slider(title: String, value: float, callback: Callable) -> void:
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 15)
    var title_label := _label(title, 13)
    title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    title_label.custom_minimum_size.x = 220
    row.add_child(title_label)
    var slider := HSlider.new()
    slider.min_value = 0.0
    slider.max_value = 1.0
    slider.step = 0.05
    slider.value = value
    slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(slider)
    var value_label := _label("%d%%" % int(round(value * 100.0)), 13, CYAN)
    value_label.custom_minimum_size.x = 52
    row.add_child(value_label)
    slider.value_changed.connect(func(v: float) -> void:
        value_label.text = "%d%%" % int(round(v * 100.0))
        callback.call(v)
    )
    content.add_child(row)

func _begin_rebind(action: String) -> void:
    waiting_for_key = action
    status_message = "Press new key for %s; Esc cancels." % ACTION_LABELS[ACTIONS.find(action)]
    _clear()
    _heading("PRESS A KEY")
    _notice()

func _reset_keys() -> void:
    for i in range(ACTIONS.size()):
        bindings[ACTIONS[i]] = DEFAULT_KEYS[i]
    _save_settings()
    show_settings()

func _settings_back() -> void:
    if settings_return == "pause":
        show_pause()
    else:
        show_title()

func _master_changed(value: float) -> void:
    master_volume = value
    _apply_audio()
    _save_settings()

func _ambience_changed(value: float) -> void:
    ambience_volume = value
    _apply_audio()
    _save_settings()

func _effects_changed(value: float) -> void:
    effects_volume = value
    _apply_audio()
    _save_settings()

func _alarm_changed(value: float) -> void:
    alarm_volume = value
    _apply_audio()
    _save_settings()

func _toggle_sound() -> void:
    show_audio = not show_audio
    _apply_audio()
    _save_settings()
    show_settings()

func _apply_audio() -> void:
    if game == null or game.station_audio == null:
        return
    var audio = game.station_audio
    var master_db := linear_to_db(maxf(master_volume, 0.001))
    AudioServer.set_bus_volume_db(0, master_db)
    AudioServer.set_bus_mute(0, not show_audio)
    audio.ambience.volume_db = -29.0 + linear_to_db(maxf(ambience_volume, 0.001))
    audio.effects.volume_db = -9.0 + linear_to_db(maxf(effects_volume, 0.001))
    audio.alarm.volume_db = -13.0 + linear_to_db(maxf(alarm_volume, 0.001))

func _load_settings() -> void:
    for i in range(ACTIONS.size()):
        bindings[ACTIONS[i]] = DEFAULT_KEYS[i]
    var config := ConfigFile.new()
    if config.load(SETTINGS_PATH) != OK:
        return
    master_volume = clampf(float(config.get_value("audio", "master", 0.75)), 0.0, 1.0)
    ambience_volume = clampf(float(config.get_value("audio", "ambience", 0.45)), 0.0, 1.0)
    effects_volume = clampf(float(config.get_value("audio", "effects", 0.85)), 0.0, 1.0)
    alarm_volume = clampf(float(config.get_value("audio", "alarm", 0.85)), 0.0, 1.0)
    show_audio = bool(config.get_value("audio", "enabled", true))
    for action in ACTIONS:
        var key := int(config.get_value("keys", action, int(bindings[action])))
        if key != KEY_ESCAPE and key != KEY_NONE and not bindings.values().has(key):
            bindings[action] = key
    # Keep bindings unique even if an old settings file contains duplicates.
    var taken: Array[int] = []
    for i in range(ACTIONS.size()):
        var action: String = ACTIONS[i]
        var code: int = int(bindings[action])
        if taken.has(code) or code == KEY_ESCAPE:
            code = DEFAULT_KEYS[i]
        bindings[action] = code
        taken.append(code)

func _save_settings() -> void:
    var config := ConfigFile.new()
    config.set_value("audio", "master", master_volume)
    config.set_value("audio", "ambience", ambience_volume)
    config.set_value("audio", "effects", effects_volume)
    config.set_value("audio", "alarm", alarm_volume)
    config.set_value("audio", "enabled", show_audio)
    for action in ACTIONS:
        config.set_value("keys", action, bindings[action])
    var error := config.save(SETTINGS_PATH)
    if error != OK:
        push_warning("Could not save settings: %d" % error)

func _new_game_request() -> void:
    if in_session and not game.finished:
        _confirm("Discard Current Shift?", "Unsaved progress will be lost. Start a new shift?", _start_new)
    else:
        _start_new()

func _start_new() -> void:
    game._reset()
    in_session = true
    resume_game()

func _save_game() -> void:
    if game.finished:
        status_message = "Completed or failed shifts cannot be saved."
        show_pause()
        return
    var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if file == null:
        status_message = "Save failed: could not open local save file."
        show_pause()
        return
    file.store_string(JSON.stringify(game.get_save_data(), "\t"))
    file.close()
    status_message = "Shift saved to the local save slot."
    show_pause()

func _load_request() -> void:
    if in_session and not game.finished:
        _confirm("Load Saved Shift?", "Replace your current unsaved progress?", _continue_game)
    else:
        _continue_game()

func _continue_game() -> void:
    if not FileAccess.file_exists(SAVE_PATH):
        status_message = "No saved shift found."
        show_title()
        return
    var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
    if file == null:
        status_message = "Could not open the save."
        show_title()
        return
    var decoded: Variant = JSON.parse_string(file.get_as_text())
    file.close()
    if typeof(decoded) != TYPE_DICTIONARY or not game.load_save_data(decoded):
        status_message = "Invalid or unsupported save file."
        if in_session:
            show_pause()
        else:
            show_title()
        return
    in_session = true
    resume_game()

func _return_to_title() -> void:
    show_title()

func resume_game() -> void:
    overlay.hide()
    current_page = "game"
    game._refresh()
    menu_closed.emit()

func _exit_game() -> void:
    if in_session and not game.finished:
        _confirm("Exit Station Zero?", "Unsaved progress will be lost. Exit the game?", func() -> void: get_tree().quit())
    else:
        get_tree().quit()

func _confirm(title: String, message: String, callback: Callable) -> void:
    confirm_dialog.title = title
    confirm_dialog.dialog_text = message
    for c in confirm_dialog.confirmed.get_connections():
        confirm_dialog.confirmed.disconnect(c.callable)
    confirm_dialog.confirmed.connect(callback, CONNECT_ONE_SHOT)
    confirm_dialog.popup_centered()
