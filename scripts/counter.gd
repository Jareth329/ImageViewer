extends PanelContainer

@onready var label:Label = $label as Label

func _ready() -> void:
	Globals.update_counter.connect(_update_counter)
	Globals.update_visibility_ui.connect(_update_visibility)

func _update_counter(value:int, max_value:int) -> void:
	label.text = " %d / %d " % [value, max_value]

func _update_visibility() -> void:
	self.visible = not self.visible
