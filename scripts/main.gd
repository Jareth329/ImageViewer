extends Control

var borderless:bool = false

func _ready() -> void:
	# need to make this a setting the user can toggle; alternatively,
	# can just put a colorrect in the background and allow user to choose color, including transparent
	get_tree().root.transparent_bg = true

func _unhandled_input(event:InputEvent) -> void:
	if event is InputEventKey:
		if not event.pressed: return
		if event.keycode == KEY_TAB:
			Signals.update_visibility_ui.emit()
		elif event.keycode == KEY_F9:
			_update_titlebar_visibility()
		elif event.keycode == KEY_F8 or event.keycode == KEY_ESCAPE:
			get_tree().quit()
		elif event.keycode == KEY_F11:
			_set_window_mode(Window.MODE_FULLSCREEN)
		elif event.keycode == KEY_F10:
			_set_window_mode(Window.MODE_MAXIMIZED)
		elif event.keycode == KEY_B:
			_toggle_background_transparency()

func _toggle_background_transparency() -> void:
	get_tree().root.transparent_bg = not get_tree().root.transparent_bg

func _update_titlebar_visibility() -> void:
	get_tree().root.borderless = not borderless
	borderless = not borderless

func _set_window_mode(mode:int) -> void:
	var curr_mode:int = get_tree().root.mode
	# set actual mode to Windowed to prevent screen bugs
	if curr_mode != Window.MODE_WINDOWED:
		get_tree().root.mode = Window.MODE_WINDOWED
	if mode == Window.MODE_MAXIMIZED:
		# if windowed or fullscreen; set to maximized
		if curr_mode != Window.MODE_MAXIMIZED:
			get_tree().root.mode = Window.MODE_MAXIMIZED
		else:
			# does not unmaximize by default; fix by setting to fullscreen first
			get_tree().root.mode = Window.MODE_FULLSCREEN
			get_tree().root.mode = Window.MODE_WINDOWED
	elif mode == Window.MODE_FULLSCREEN:
		# if maximized or windowed; set to fullscreen
		if curr_mode != Window.MODE_FULLSCREEN:
			get_tree().root.mode = Window.MODE_FULLSCREEN
		else:
			get_tree().root.mode = Window.MODE_WINDOWED
