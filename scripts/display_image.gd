class_name Display extends TextureRect

#region Notes
# viewport size dictates the resolution available, but if the user zooms in then a smaller portion of 
# the image is visible and is effectively at a higher resolution -- which is to say that I can just 
# set the viewport size to ~4k or so to cover the upper end of monitors and that should be fine; I 
# could also set it to the size of program window, and adjust it if resized

# need to add buttons for:
#	locking rotation/zoom/pan	(& freezing?)
#	flipping image horizontally/vertically
#	rotating image
#	toggling filter

# for use as an asset; would be better to define viewport size as an export variable

# should probably add a toggle key + setting to have scroll switch between zoom and skipping to next image,
#	maybe even default it to next image since there is alt way of zooming now

# trying to open multiple images at once opens multiple instances, which is inline with other 
# image viewers and ensures this code will work fine in correct use cases, just need to add 
# popup for error images and remove their path from the array
#endregion

#region Viewport Settings
@export_category("Viewport")
@export var viewport_size:Vector2 = Vector2(2560, 1440)
#endregion

#region Zoom Settings
@export_category("Zoom")
@export var allow_zoom:bool = true
@export var use_point_zoom:bool = true
@export var use_scrollwheel:bool = true
@export var zoom_min:float = 0.1
@export var zoom_max:float = 64
@export var zoom_step:float = 0.1
@export var zoom_speed:float = 1.0
#endregion

#region Pan Settings
enum Pan { FREE, DAMPED, CONSTRAINED }
@export_category("Pan")
@export var allow_pan:bool = true
@export var pan_mode:Pan = Pan.DAMPED
@export var pan_limit:float = 0.5 # what percentage of image can leave window at default zoom
@export var pan_step:float = 0.4
@export var pan_speed:float = 0.3
@export var pan_damping_start:float = 0.5 # distance from center as a percentage (0=always damp, 1=same as constrained)
#endregion

#region Rotate Settings
@export_category("Rotation")
@export var allow_rotation:bool = true
@export var rotation_step:float = 0.4
@export var rotation_speed:float = 0.7
#endregion

#region (Effective) Constants
@onready var viewport:SubViewport = $viewport as SubViewport
@onready var image:TextureRect = $viewport/viewport_image as TextureRect
@onready var camera:Camera2D = $viewport/viewport_camera as Camera2D

var default_zoom:Vector2
var default_offset:Vector2
var default_rotation:float
#endregion

#region Variables
var panning:bool = false
var rotating:bool = false
var fast_zooming:bool = false
var viewport_aspect:float = viewport_size.x / viewport_size.y # needs to be updated when viewport_size changes
var image_aspect:float = 1.0
#endregion

#region Functions
func _ready() -> void:
	# connect signals
	self.gui_input.connect(_on_gui_input)
	self.resized.connect(resize)
	
	# set default camera state
	default_rotation = camera.rotation
	default_offset = camera.offset
	default_zoom = camera.zoom
	
	# set variables related to viewport size
	viewport.size = viewport_size
	image.size = viewport_size
	camera.position = viewport_size / 2

func reset_camera_state() -> void:
	camera.zoom = default_zoom
	camera.offset = default_offset
	camera.rotation = default_rotation
	image.flip_h = false
	image.flip_v = false

func toggle_filter() -> void:
	if image.texture_filter == TEXTURE_FILTER_NEAREST:
		image.texture_filter = TEXTURE_FILTER_LINEAR
	else: image.texture_filter = TEXTURE_FILTER_NEAREST

func resize() -> void:
	if image.texture == null: return
	var self_aspect:float = self.size.x / self.size.y
	var _ratio:float = viewport_aspect / self_aspect
	var _size:Vector2 = viewport_size
	
	if image_aspect > self_aspect: _size.y *= _ratio
	elif image_aspect < self_aspect: _size.x /= _ratio
	
	viewport.size = _size
	image.size = _size
	camera.position = _size / 2

func change_image(_texture:ImageTexture, _aspect:float) -> void:
	image.texture = _texture
	image_aspect = _aspect
#endregion

#region User Input Functions
func _unhandled_input(event:InputEvent) -> void:
	if event is InputEventKey:
		var ev:InputEventKey = event as InputEventKey
		if not ev.pressed: return
		if ev.keycode == KEY_F5 or ev.keycode == KEY_R: reset_camera_state()
		elif ev.keycode == KEY_H: image.flip_h = not image.flip_h
		elif ev.keycode == KEY_V: image.flip_v = not image.flip_v
		elif ev.keycode == KEY_F: toggle_filter()

func _on_gui_input(event:InputEvent) -> void:
	if event is InputEventMouseButton:
		var ev:InputEventMouseButton = event as InputEventMouseButton
		if not ev.pressed: # prevent events from firing twice
			panning = false
			rotating = false
			fast_zooming = false
			return
		elif ev.button_index == MOUSE_BUTTON_WHEEL_UP:
			if allow_zoom and use_scrollwheel: # zoom in
				if use_point_zoom: zoom_to_point(zoom_step, ev.position)
				else: zoom_to_center(zoom_step)
			else: Globals.prev_pressed.emit(1)
		elif ev.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if allow_zoom and use_scrollwheel: # zoom out
				if use_point_zoom: zoom_to_point(-zoom_step, ev.position)
				else: zoom_to_center(-zoom_step)
			else: Globals.next_pressed.emit(1)
		elif ev.button_index == MOUSE_BUTTON_LEFT: panning = true
		elif ev.button_index == MOUSE_BUTTON_MIDDLE: fast_zooming = true
		elif ev.button_index == MOUSE_BUTTON_RIGHT: rotating = true
	elif event is InputEventMouseMotion:
		var ev:InputEventMouseMotion = event as InputEventMouseMotion
		if allow_pan and panning: pan(ev.relative)
		elif allow_rotation and rotating: rotate(ev.position, ev.relative)
		elif allow_zoom and fast_zooming: fast_zoom_to_center(ev.relative)
#endregion

#region Zoom Functions
func zoom_to_center(step:float) -> void:
	var new_step:float = camera.zoom.x * step * zoom_speed
	var new_zoom:float = camera.zoom.x + new_step
	new_zoom = clampf(new_zoom, zoom_min, (zoom_max-zoom_min))
	camera.zoom = Vector2(new_zoom, new_zoom)

func fast_zoom_to_center(event_position:Vector2) -> void:
	var zoom_ratio:float = camera.zoom.x / zoom_max
	var zoom_target:float = camera.zoom.x + (event_position.x * zoom_speed * zoom_ratio)
	var new_zoom:float = clampf(lerpf(camera.zoom.x, zoom_target, zoom_step), zoom_min, zoom_max)
	camera.zoom = Vector2(new_zoom, new_zoom)

func zoom_to_point(step:float, event_position:Vector2) -> void:
	var new_step:float = camera.zoom.x * step * zoom_speed
	var new_zoom:float = camera.zoom.x + new_step
	new_zoom = clampf(new_zoom, zoom_min, zoom_max)
	var new_offset:Vector2 = ((self.position + self.size) / 2) - event_position
	
	# account for zoom
	if camera.zoom.x > 1.0: 
		new_offset *= (zoom_max - camera.zoom.x) / (zoom_max * (pow(1.1 + (camera.zoom.x / zoom_max), 8)))
	else: new_offset /= camera.zoom.x
	
	# account for rotation
	var rot:float = camera.rotation
	var rsin:float = sin(rot)
	var rcos:float = cos(rot)
	var rmultx:float = (rcos * new_offset.x) - (rsin * new_offset.y)
	var rmulty:float = (rsin * new_offset.x) + (rcos * new_offset.y)
	
	# fix direction and scale
	new_offset = Vector2(rmultx, rmulty)
	new_offset *= 0.25 if step < 0 else -0.25
	
	# account for pan limit
	var limit:Vector2 = viewport.size * pan_limit
	if pan_mode == Pan.CONSTRAINED:
		if new_offset.x < 0 and camera.offset.x <= -limit.x: new_offset.x = 0
		elif new_offset.x > 0 and camera.offset.x >= limit.x: new_offset.x = 0
		if new_offset.y < 0 and camera.offset.y <= -limit.y: new_offset.y = 0
		elif new_offset.y > 0 and camera.offset.y >= limit.y: new_offset.y = 0
	
	elif pan_mode == Pan.DAMPED:
		var damped_offset:Vector2 = camera.offset * pan_damping_start
		if new_offset.x < 0 and camera.offset.x <= damped_offset.x:
			new_offset.x *= 1 - (maxf(0, absf(camera.offset.x) / limit.x))
		elif new_offset.x > 0 and camera.offset.x >= damped_offset.x:
			new_offset.x *= 1 - (maxf(0, absf(camera.offset.x) / limit.x))
		if new_offset.y < 0 and camera.offset.y <= damped_offset.y:
			new_offset.y *= 1 - (maxf(0, absf(camera.offset.y) / limit.y))
		elif new_offset.y > 0 and camera.offset.y >= damped_offset.y:
			new_offset.y *= 1 - (maxf(0, absf(camera.offset.y) / limit.y))
	
	# apply offset and zoom
	camera.offset += new_offset
	camera.zoom = Vector2(new_zoom, new_zoom)
#endregion

#region Pan Functions
func pan(relative_position:Vector2) -> void:
	var rot:float = camera.rotation
	var rsin:float = sin(rot)
	var rcos:float = cos(rot)
	var rmultx:float = (rcos * relative_position.x) - (rsin * relative_position.y)
	var rmulty:float = (rsin * relative_position.x) + (rcos * relative_position.y)
	var zoom_mult:float = (zoom_max / camera.zoom.x) * 0.07
	var new_offset:Vector2 = Vector2(rmultx, rmulty) *  zoom_mult * pan_speed
	var limit:Vector2 = viewport.size * pan_limit
	
	# sets the pan speed to 0 at the perimeter
	if pan_mode == Pan.CONSTRAINED:
		if new_offset.x > 0 and camera.offset.x <= -limit.x: new_offset.x = 0
		elif new_offset.x < 0 and camera.offset.x >= limit.x: new_offset.x = 0
		if new_offset.y > 0 and camera.offset.y <= -limit.y: new_offset.y = 0
		elif new_offset.y < 0 and camera.offset.y >= limit.y: new_offset.y = 0
	
	# reduces pan speed with increased distance from center (0 at perimeter)
	elif pan_mode == Pan.DAMPED:
		var damped_offset:Vector2 = camera.offset * pan_damping_start
		if new_offset.x > 0 and camera.offset.x <= damped_offset.x:
			new_offset.x *= 1 - (maxf(0, absf(camera.offset.x) / limit.x))
		elif new_offset.x < 0 and camera.offset.x >= damped_offset.x:
			new_offset.x *= 1 - (maxf(0, absf(camera.offset.x) / limit.x))
		if new_offset.y > 0 and camera.offset.y <= damped_offset.y:
			new_offset.y *= 1 - (maxf(0, absf(camera.offset.y) / limit.y))
		elif new_offset.y < 0 and camera.offset.y >= damped_offset.y:
			new_offset.y *= 1 - (maxf(0, absf(camera.offset.y) / limit.y))
	
	camera.offset -= new_offset
	camera.offset = camera.offset.lerp(camera.offset - new_offset, pan_step)
#endregion

#region Rotation Functions
func rotate(event_position:Vector2, relative_position:Vector2) -> void:
	var ratio:Vector2 = image.size / self.size
	var vector:Vector2 = (ratio * event_position) - camera.position
	var angle:float = atan2(vector.y, vector.x)
	var clockwise:bool = get_clockwise(angle)
	var movement:float = absf(relative_position.x) + absf(relative_position.y)
	
	var target:float = camera.rotation_degrees
	if clockwise: target -= movement * rotation_speed
	else: target += movement * rotation_speed
	
	camera.rotation_degrees = lerpf(camera.rotation_degrees, target, rotation_step)

var prev_angle:float = 0
func get_clockwise(angle:float) -> bool:
	var result:bool = _get_clockwise(angle)
	prev_angle = angle
	return result

func _get_clockwise(angle:float) -> bool:
	# these first two statements handle the -PI/PI flip on the negative x axis
	if prev_angle < -PI/2 and angle > PI/2: return false
	if prev_angle > PI/2 and angle < -PI/2: return true
	return angle > prev_angle
#endregion
