extends TextureRect

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
enum Pan { FREE, DAMPENED, CONSTRAINED }
@export_category("Pan")
@export var allow_pan:bool = true
@export var pan_mode:Pan = Pan.DAMPENED
@export var pan_limit_w:float = 1280 # need to actually allow setting these manually; probably as a multiplier of viewport size
@export var pan_limit_h:float = 720
@export var pan_step:float = 0.4
@export var pan_speed:float = 0.3
#endregion

#region Rotate Settings
@export_category("Rotation")
@export var allow_rotation:bool = true
@export var use_circular_rotation:bool = false
@export var rotation_step:float = 0.4
@export var rotation_speed:float = 0.7
#endregion

#region UI Settings
var window_max_x:float = 960
var window_max_y:float = 720
var window_size_percent:float = 0.75
var row_size_skip:int = 10
var use_history:bool = false
var history_max_size:int = 10
var reset_camera_on_image_change:bool = true
#endregion

#region (Effective) Constants
@onready var viewport:SubViewport = $viewport as SubViewport
@onready var image:TextureRect = $viewport/viewport_image as TextureRect
@onready var camera:Camera2D = $viewport/viewport_camera as Camera2D

var default_zoom:Vector2
var default_offset:Vector2
var default_rotation:float

var supported_formats:PackedStringArray = [ "jpg", "jpeg", "png", "bmp", "dds", "ktx", "exr", "hdr", "tga", "svg", "webp" ]
#endregion

#region Variables
var panning:bool = false
var rotating:bool = false
var fast_zooming:bool = false

var file_paths:Array[String] = []
var curr_index:int = 0

var history:Dictionary = {} # String : ImageTexture
var history_queue:Array[String] = []
#endregion

#region Functions
func _ready() -> void:
	# connect signals
	self.gui_input.connect(_on_gui_input)
	get_tree().root.files_dropped.connect(_files_dropped)
	get_tree().root.ready.connect(_load_cmdline_image)
	
	# set default camera state
	default_rotation = camera.rotation
	default_offset = camera.offset
	default_zoom = camera.zoom
	
	# set variables related to viewport size
	image.size = viewport.size
	camera.position = viewport.size / 2
	pan_limit_w = camera.position.x
	pan_limit_h = camera.position.y
	
	# set variables related to window size
	var screen_size:Vector2 = DisplayServer.screen_get_size()
	window_max_x = screen_size.x * window_size_percent
	window_max_y = screen_size.y * window_size_percent

func reset_camera_state() -> void:
	camera.zoom = default_zoom
	camera.offset = default_offset
	camera.rotation = 0
	image.flip_h = false
	image.flip_v = false

func toggle_filter() -> void:
	if image.texture_filter == TEXTURE_FILTER_NEAREST:
		image.texture_filter = TEXTURE_FILTER_LINEAR
	else: image.texture_filter = TEXTURE_FILTER_NEAREST 
#endregion

#region UI Functions
func _unhandled_input(event:InputEvent) -> void:
	if event is InputEventKey:
		var ev:InputEventKey = event as InputEventKey
		if not ev.pressed: return
		if ev.keycode == KEY_F5 or ev.keycode == KEY_R: reset_camera_state()
		elif ev.keycode == KEY_LEFT: prev_image(1)
		elif ev.keycode == KEY_RIGHT: next_image(1)
		elif ev.keycode == KEY_UP: prev_image(row_size_skip)
		elif ev.keycode == KEY_DOWN: next_image(row_size_skip)
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
			else: prev_image(1)
		elif ev.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if allow_zoom and use_scrollwheel: # zoom out
				if use_point_zoom: zoom_to_point(-zoom_step, ev.position)
				else: zoom_to_center(-zoom_step)
			else: next_image(1)
		elif ev.button_index == MOUSE_BUTTON_LEFT: panning = true
		elif ev.button_index == MOUSE_BUTTON_MIDDLE: fast_zooming = true
		elif ev.button_index == MOUSE_BUTTON_RIGHT: rotating = true
	elif event is InputEventMouseMotion:
		var ev:InputEventMouseMotion = event as InputEventMouseMotion
		if allow_pan and panning: pan(ev.relative)
		elif allow_rotation and rotating: rotate(event.position, event.relative)
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
	
	if camera.zoom.x > 1.0: 
		new_offset *= (zoom_max - camera.zoom.x) / (zoom_max * (pow(1.1 + (camera.zoom.x / zoom_max), 8)))
	else: new_offset /= camera.zoom.x
	
	if allow_rotation:
		var rot:float = camera.rotation
		var rsin:float = sin(rot)
		var rcos:float = cos(rot)
		var rmultx:float = (rcos * new_offset.x) - (rsin * new_offset.y)
		var rmulty:float = (rsin * new_offset.x) + (rcos * new_offset.y)
		new_offset = Vector2(rmultx, rmulty)
	
	new_offset *= 0.25 if step < 0 else -0.25
	camera.offset += new_offset
	camera.zoom = Vector2(new_zoom, new_zoom)
#endregion

#region Pan Functions
func pan(relative_position:Vector2) -> void:
	var rot:float = camera.rotation
	var rot_sin:float = sin(rot)
	var rot_cos:float = cos(rot)
	var rot_mult_x:float = (rot_cos * relative_position.x) - (rot_sin * relative_position.y)
	var rot_mult_y:float = (rot_sin * relative_position.x) + (rot_cos * relative_position.y)
	var zoom_mult:float = (zoom_max / camera.zoom.x) * 0.07
	var rot_offset:Vector2 = Vector2(rot_mult_x, rot_mult_y) * zoom_mult * pan_speed
	
	# sets the pan speed to 0 at the perimeter
	if pan_mode == Pan.CONSTRAINED:
		if rot_offset.x > 0 and camera.offset.x <= -pan_limit_w: rot_offset.x = 0
		elif rot_offset.x < 0 and camera.offset.x >= pan_limit_w: rot_offset.x = 0
		if rot_offset.y > 0 and camera.offset.y <= -pan_limit_h: rot_offset.y = 0
		elif rot_offset.y < 0 and camera.offset.y >= pan_limit_h: rot_offset.y = 0
	
	# reduces pan speed with increased distance from center (0 at perimeter)
	if pan_mode == Pan.DAMPENED:
		if rot_offset.x > 0 and camera.offset.x <= 0:
			rot_offset.x *= 1 - (maxf(0, absf(camera.offset.x) / pan_limit_w))
		elif rot_offset.x < 0 and camera.offset.x >= 0:
			rot_offset.x *= 1 - (maxf(0, absf(camera.offset.x) / pan_limit_w))
		if rot_offset.y > 0 and camera.offset.y <= 0:
			rot_offset.y *= 1 - (maxf(0, absf(camera.offset.y) / pan_limit_h))
		elif rot_offset.y < 0 and camera.offset.y >= 0:
			rot_offset.y *= 1 - (maxf(0, absf(camera.offset.y) / pan_limit_h))
	
	camera.offset -= rot_offset
	camera.offset = camera.offset.lerp(camera.offset - rot_offset, pan_step)
#endregion

#region Rotation Functions
func rotate(event_position:Vector2, relative_position:Vector2) -> void:
	if use_circular_rotation:
		var ratio:Vector2 = image.size / self.size
		var vector:Vector2 = (ratio * event_position) - camera.position
		var angle:float = atan2(vector.y, vector.x)
		camera.rotation = -angle
	else:
		var target:float = camera.rotation_degrees + (relative_position.x * rotation_speed)
		camera.rotation_degrees = lerpf(camera.rotation_degrees, target, rotation_step)
#endregion

#region IO Functions
func _load_cmdline_image() -> void:
	var args:PackedStringArray = OS.get_cmdline_args()
	if args.size() > 0:
		change_image(args[0])
		create_paths_array(args[0])

func _files_dropped(paths:PackedStringArray) -> void:
	# ignore extra paths for now
	change_image(paths[0])
	create_paths_array(paths[0])

func change_image(path:String) -> void:
	if reset_camera_on_image_change: reset_camera_state()
	if use_history and history.has(path): image.texture = history[path]
	else:
		if not FileAccess.file_exists(path): return
		var img:Image = Image.new()
		# this gives an error, but the error is nonsensical for my use case (non res:// paths)
		var err:int = img.load(path)
		if err != OK: return
		var tex:ImageTexture = ImageTexture.create_from_image(img)
		image.texture = tex
		if use_history: 
			add_to_history(path, tex)
	get_tree().root.title = "ImageViewer  -  %s" % [path.get_file()]
	
	if get_tree().root.mode == Window.MODE_WINDOWED:
		var res:Vector2 = image.texture.get_image().get_size()
		var max_ratio:float = window_max_x / window_max_y
		var img_ratio:float = res.x / res.y
		# could use 1 / img_ratio for if and img_ratio for else; but it makes code less clear; especially for if statement
		if res.x > res.y and img_ratio >= max_ratio: get_tree().root.size = Vector2(window_max_x, window_max_x * res.y / res.x)
		else: get_tree().root.size = Vector2(window_max_y * res.x / res.y, window_max_y)

func create_paths_array(file_path:String) -> void:
	file_paths.clear()
	var folder_path:String = file_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(folder_path): return
	# this technically works, but it is really ugly
	var files:Array[String] = Array(Array(DirAccess.get_files_at(folder_path)), TYPE_STRING, "", null) as Array[String]
	files.sort_custom(Signals.SortNatural.sort)
	var index:int = 0
	for file:String in files:
		if supported_formats.has(file.get_extension().to_lower()):
			file_paths.append(folder_path.path_join(file))
			if file_path.get_file() == file: curr_index = index
			else: index += 1
	Signals.update_counter.emit(curr_index + 1, file_paths.size())

func prev_image(nth_image:int) -> void:
	# skip to prev nth image
	if file_paths.is_empty(): return
	curr_index = (file_paths.size() + ((curr_index - nth_image) + file_paths.size())) % file_paths.size()
	change_image(file_paths[curr_index])
	Signals.update_counter.emit(curr_index + 1, file_paths.size())

func next_image(nth_image:int) -> void:
	# skip to next nth image
	if file_paths.is_empty(): return
	curr_index = (file_paths.size() + ((curr_index + nth_image) - file_paths.size())) % file_paths.size()
	change_image(file_paths[curr_index])
	Signals.update_counter.emit(curr_index + 1, file_paths.size())

func add_to_history(path:String, tex:ImageTexture) -> void:
	if history_queue.size() >= history_max_size:
		# made type safe by not using the output of pop_front()
		# should not cause issues as long as I enforce that:	history_max_size = maxi(1, history_max_size)
		# overall might be less performant than original though
		var oldest_path:String = history_queue[0]
		history_queue.pop_front()
		history.erase(oldest_path)
	# anything related to accessing Dictionary is Variant only
	history[path] = tex
	history_queue.push_back(path)
#endregion
