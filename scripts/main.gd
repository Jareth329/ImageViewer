extends Control

func _unhandled_input(event:InputEvent) -> void:
	if event is InputEventKey:
		if not event.pressed: return
		if event.keycode == KEY_H:
			Signals.update_visibility_ui.emit()
