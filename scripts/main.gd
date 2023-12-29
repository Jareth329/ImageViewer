extends Control

var borderless:bool = false

func _unhandled_input(event:InputEvent) -> void:
	if event is InputEventKey:
		if not event.pressed: return
		if event.keycode == KEY_H:
			Signals.update_visibility_ui.emit()
		elif event.keycode == KEY_T:
			_update_titlebar_visibility()
		elif event.keycode == KEY_F8 or event.keycode == KEY_ESCAPE:
			get_tree().quit()
func _update_titlebar_visibility() -> void:
	get_tree().root.borderless = not borderless
	borderless = not borderless
