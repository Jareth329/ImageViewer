extends TextureRect

# the lock_ bools can be used to prevent resetting parts of the camera state when r-click is pressed
# (I might add a freeze_ variant to prevent changing those values at all)

# initialization variables
const default_image:CompressedTexture2D = preload("res://assets/icon.svg")
@onready var viewport:SubViewport = $viewport
@onready var image:TextureRect = $viewport/viewport_image
@onready var camera:Camera2D = $viewport/viewport_camera
var default_zoom:Vector2
var default_offset:Vector2

# settings variables
var lock_zoom:bool = false
var lock_pan:bool = false
var lock_rotation:bool = false
var zoom_point:bool = false
var zoom_step:float = 0.1
var zoom_speed:float = 1.0
var zoom_min:float = 0.05
var zoom_max:float = 16
enum pan_modes { FREE, DAMPENED, CONSTRAINED }
var pan_mode:int = pan_modes.DAMPENED
var pan_speed:float = 1.0
var pan_step:float = 0.4
var pan_constraint_w:float = 1280
var pan_constraint_h:float = 720
var pan_dampen_start:float = 0.90

# variables
var panning:bool = false

# initialization functions
func _ready() -> void:
	self.gui_input.connect(_on_gui_input)
	get_tree().root.files_dropped.connect(_files_dropped)
	default_offset = camera.offset
	default_zoom = camera.zoom
	image.size = viewport.size
	camera.position = viewport.size / 2
	pan_constraint_w = camera.position.x
	pan_constraint_h = camera.position.y 

# ui functions
func _on_gui_input(event:InputEvent) -> void:
	if event is InputEventMouseButton:
		if not event.pressed:
			# prevents events from firing twice
			panning = false
			return
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			# zooming in
			if zoom_point: zoom_to_point(zoom_step, event.position)
			else: zoom_to_center(zoom_step)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			# zooming out
			if zoom_point: zoom_to_point(-zoom_step, event.position)
			else: zoom_to_center(-zoom_step)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			# activate panning
			panning = true
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			# reset camera state
			if not lock_zoom: camera.zoom = default_zoom
			if not lock_pan: camera.offset = default_offset
			if not lock_rotation: camera.rotation = 0
	elif event is InputEventMouseMotion and panning:
		# pan
		pan(event.relative)

func zoom_to_center(step:float) -> void:
	var new_step:float = camera.zoom.x * step * zoom_speed
	var new_zoom:float = camera.zoom.x + new_step
	new_zoom = clamp(new_zoom, zoom_min, zoom_max)
	camera.zoom = Vector2(new_zoom, new_zoom)

func zoom_to_point(step:float, event_position:Vector2) -> void:
	var new_step:float = camera.zoom.x * step * zoom_speed
	var new_zoom:float = camera.zoom.x + new_step
	new_zoom = clamp(new_zoom, zoom_min, zoom_max)
	# this part needs fixed
	#var direction:int = -1 if new_step < 0 else 1
	#var ratio:Vector2 = self.size / viewport_image.size
	#var new_offset:Vector2 = (event_position - ((viewport_image.size / 2) * ratio)) * new_step
	var new_offset:Vector2 = (((self.position + self.size) / 2) - event_position) * -new_step
	print(new_offset)
	camera.offset += new_offset
	camera.zoom = Vector2(new_zoom, new_zoom)

func pan(relative_position:Vector2) -> void:
	var rot:float = camera.rotation
	var rot_sin:float = sin(rot)
	var rot_cos:float = cos(rot)
	var rot_mult_x:float = (rot_cos * relative_position.x) - (rot_sin * relative_position.y)
	var rot_mult_y:float = (rot_sin * relative_position.x) + (rot_cos * relative_position.y)
	var zoom_mult:float = (zoom_max / camera.zoom.x) * 0.07
	var rot_offset:Vector2 = Vector2(rot_mult_x, rot_mult_y) * zoom_mult * pan_speed
	
	# restricts pan from leaving predefined constraints; sets the pan speed of an axis at the perimeter to 0
	if pan_mode == pan_modes.CONSTRAINED:
		if rot_offset.x > 0 and camera.offset.x <= -pan_constraint_w: rot_offset.x = 0
		elif rot_offset.x < 0 and camera.offset.x >= pan_constraint_w: rot_offset.x = 0
		if rot_offset.y > 0 and camera.offset.y <= -pan_constraint_h: rot_offset.y = 0
		elif rot_offset.y < 0 and camera.offset.y >= pan_constraint_h: rot_offset.y = 0
	
	# restricts pan from leaving predefined constraints; gradually reduces pan speed to 0 near perimeter
	if pan_mode == pan_modes.DAMPENED:
		if rot_offset.x > 0 and camera.offset.x <= (-pan_constraint_w * pan_dampen_start):
			rot_offset.x *= 1 - (max(0, abs(camera.offset.x) / pan_constraint_w))
		elif rot_offset.x < 0 and camera.offset.x >= (pan_constraint_w * pan_dampen_start):
			rot_offset.x *= 1 - (max(0, abs(camera.offset.x) / pan_constraint_w))
		if rot_offset.y > 0 and camera.offset.y <= (-pan_constraint_h * pan_dampen_start):
			rot_offset.y *= 1 - (max(0, abs(camera.offset.y) / pan_constraint_h))
		elif rot_offset.y < 0 and camera.offset.y >= (pan_constraint_h * pan_dampen_start):
			rot_offset.y *= 1 - (max(0, abs(camera.offset.y) / pan_constraint_h))
	
	camera.offset -= rot_offset
	camera.offset = lerp(camera.offset, camera.offset - rot_offset, pan_step)

# api functions
func _files_dropped(paths:PackedStringArray) -> void:
	# ignore extra paths for now
	change_image(paths[0])

func change_image(path:String) -> void:
	if not FileAccess.file_exists(path): return
	var img:Image = Image.new()
	var err:int = img.load(path)
	if err != OK: return
	var tex:ImageTexture = ImageTexture.create_from_image(img)
	image.texture = tex
