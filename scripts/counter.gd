extends PanelContainer

# counter does not display correctly on the first opened image when opened directly from file explorer

@onready var label:Label = $label

func _ready() -> void:
	Signals.update_counter.connect(_update_counter)
	Signals.update_visibility_ui.connect(_update_visibility)

func _update_counter(value:int, max_value:int) -> void:
	label.text = " %d / %d " % [value, max_value]

func _update_visibility() -> void:
	self.visible = not self.visible
