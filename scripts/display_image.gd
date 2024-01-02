extends TextureRect

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

# initialization variables
@onready var viewport:SubViewport = $viewport as SubViewport
@onready var image:TextureRect = $viewport/viewport_image as TextureRect
@onready var camera:Camera2D = $viewport/viewport_camera as Camera2D
var default_zoom:Vector2
var default_offset:Vector2

# settings variables
var scroll_wheel_zooms:bool = true
var lock_zoom:bool = false
var lock_pan:bool = false
var lock_rotation:bool = false
var zoom_point:bool = true
var zoom_step:float = 0.1
var zoom_speed:float = 1.0
var zoom_min:float = 0.1
var zoom_max:float = 64
enum pan_modes { FREE, DAMPENED, CONSTRAINED }
var pan_mode:int = pan_modes.DAMPENED
var pan_speed:float = 0.3
var pan_step:float = 0.4
var pan_constraint_w:float = 1280
var pan_constraint_h:float = 720
var pan_dampen_start:float = 0.0
var rotation_speed:float = 0.7
var rotation_step:float = 0.4
var window_max_x:float = 960
var window_max_y:float = 720
var window_size_percent:float = 0.75
var row_size_skip:int = 10
var use_history:bool = false
var history_max_size:int = 10
var reset_camera_on_image_change:bool = true

# variables
var panning:bool = false
var rotating:bool = false
var zooming:bool = false
var supported_formats:PackedStringArray = [ "jpg", "jpeg", "png", "bmp", "dds", "ktx", "exr", "hdr", "tga", "svg", "webp" ]
var file_paths:Array[String] = []
var curr_index:int = 0
var history:Dictionary = {} # String : ImageTexture
var history_queue:Array[String] = []

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
	get_tree().root.ready.connect(_load_cmdline_image)
	
	var screen_size:Vector2 = DisplayServer.screen_get_size()
	window_max_x = screen_size.x * window_size_percent
	window_max_y = screen_size.y * window_size_percent

func _load_cmdline_image() -> void:
	# trying to open multiple images at once opens multiple instances, which is inline with other 
	# image viewers and ensures this code will work fine in correct use cases, just need to add 
	# popup for error images and remove their path from the array
	var args:PackedStringArray = OS.get_cmdline_args()
	if args.size() > 0:
		change_image(args[0])
		create_paths_array(args[0])

# ui functions
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
		if not ev.pressed:
			# prevents events from firing twice
			panning = false
			rotating = false
			zooming = false
			return
		elif ev.button_index == MOUSE_BUTTON_WHEEL_UP:
			if scroll_wheel_zooms:
				# zooming in
				if zoom_point: zoom_to_point(zoom_step, ev.position)
				else: zoom_to_center(zoom_step)
			else: prev_image(1)
		elif ev.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if scroll_wheel_zooms:
				# zooming out
				if zoom_point: zoom_to_point(-zoom_step, ev.position)
				else: zoom_to_center(-zoom_step)
			else: next_image(1)
		elif ev.button_index == MOUSE_BUTTON_LEFT: panning = true
		elif ev.button_index == MOUSE_BUTTON_MIDDLE: zooming = true
		elif ev.button_index == MOUSE_BUTTON_RIGHT: rotating = true
	elif event is InputEventMouseMotion:
		var ev:InputEventMouseMotion = event as InputEventMouseMotion
		if panning: pan(ev.relative)
		elif rotating: rotate(ev.relative)
		elif zooming: fast_zoom_to_center(ev.relative)

func zoom_to_center(step:float) -> void:
	var new_step:float = camera.zoom.x * step * zoom_speed
	var new_zoom:float = camera.zoom.x + new_step
	new_zoom = clampf(new_zoom, zoom_min, (zoom_max-zoom_min))
	camera.zoom = Vector2(new_zoom, new_zoom)

func fast_zoom_to_center(event_position:Vector2) -> void:
	var zoom_ratio:float = camera.zoom.x / zoom_max
	var zoom_target:float = camera.zoom.x + (event_position.x * zoom_speed * zoom_ratio)
	var _zoom_min:Vector2 = Vector2(zoom_min, zoom_min)
	var _zoom_max:Vector2 = Vector2(zoom_max, zoom_max)
	var _zoom_target:Vector2 = Vector2(zoom_target, zoom_target)
	camera.zoom = camera.zoom.lerp(_zoom_target, zoom_step).clamp(_zoom_min, _zoom_max)

func zoom_to_point(step:float, event_position:Vector2) -> void:
	var new_step:float = camera.zoom.x * step * zoom_speed
	var new_zoom:float = camera.zoom.x + new_step
	new_zoom = clampf(new_zoom, zoom_min, zoom_max)
	var new_offset:Vector2 = ((self.position + self.size) / 2) - event_position
	
	if camera.zoom.x > 1.0: 
		# if zoomed in; normalize based on max zoom; minimize pan at high zoom
		new_offset *= (zoom_max - camera.zoom.x) / (zoom_max * (pow(1.1 + (camera.zoom.x / zoom_max), 8)))
	else:
		# if default zoom or zoomed out; multiply by 1/zoom
		new_offset /= camera.zoom.x
	
	# scale offset to reasonable value; invert offset if zooming in; take rotation into account
	new_offset *= 0.25 if step < 0 else -0.25
	var rot:float = camera.rotation
	var rsin:float = sin(rot)
	var rcos:float = cos(rot)
	var rmultx:float = (rcos * new_offset.x) - (rsin * new_offset.y)
	var rmulty:float = (rsin * new_offset.x) + (rcos * new_offset.y)
	new_offset = Vector2(rmultx, rmulty)
	
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
	
	# sets the pan speed to 0 at the perimeter
	if pan_mode == pan_modes.CONSTRAINED:
		if rot_offset.x > 0 and camera.offset.x <= -pan_constraint_w: rot_offset.x = 0
		elif rot_offset.x < 0 and camera.offset.x >= pan_constraint_w: rot_offset.x = 0
		if rot_offset.y > 0 and camera.offset.y <= -pan_constraint_h: rot_offset.y = 0
		elif rot_offset.y < 0 and camera.offset.y >= pan_constraint_h: rot_offset.y = 0
	
	# reduces pan speed with increased distance from center (0 at perimeter)
	if pan_mode == pan_modes.DAMPENED:
		if rot_offset.x > 0 and camera.offset.x <= (-pan_constraint_w * pan_dampen_start):
			rot_offset.x *= 1 - (maxf(0, absf(camera.offset.x) / pan_constraint_w))
		elif rot_offset.x < 0 and camera.offset.x >= (pan_constraint_w * pan_dampen_start):
			rot_offset.x *= 1 - (maxf(0, absf(camera.offset.x) / pan_constraint_w))
		if rot_offset.y > 0 and camera.offset.y <= (-pan_constraint_h * pan_dampen_start):
			rot_offset.y *= 1 - (maxf(0, absf(camera.offset.y) / pan_constraint_h))
		elif rot_offset.y < 0 and camera.offset.y >= (pan_constraint_h * pan_dampen_start):
			rot_offset.y *= 1 - (maxf(0, absf(camera.offset.y) / pan_constraint_h))
	
	camera.offset -= rot_offset
	camera.offset = camera.offset.lerp(camera.offset - rot_offset, pan_step)

func rotate(relative_position:Vector2) -> void:
	var rotation_target:float = camera.rotation_degrees + (relative_position.x * rotation_speed)
	camera.rotation_degrees = lerpf(camera.rotation_degrees, rotation_target, rotation_step)

# functions
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
	curr_index = (file_paths.size() + ((curr_index - nth_image) + file_paths.size())) % file_paths.size()
	change_image(file_paths[curr_index])
	Signals.update_counter.emit(curr_index + 1, file_paths.size())

func next_image(nth_image:int) -> void:
	# skip to next nth image
	curr_index = (file_paths.size() + ((curr_index + nth_image) - file_paths.size())) % file_paths.size()
	change_image(file_paths[curr_index])
	Signals.update_counter.emit(curr_index + 1, file_paths.size())

func reset_camera_state() -> void:
	if not lock_zoom: camera.zoom = default_zoom
	if not lock_pan: camera.offset = default_offset
	if not lock_rotation: camera.rotation = 0
	image.flip_h = false
	image.flip_v = false

func toggle_filter() -> void:
	if image.texture_filter == TEXTURE_FILTER_NEAREST:
		image.texture_filter = TEXTURE_FILTER_LINEAR
	else: image.texture_filter = TEXTURE_FILTER_NEAREST 

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
