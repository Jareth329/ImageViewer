extends Control

#region (Effective) Constants
@onready var display:Display = $vbox/margin/display_image as Display
@onready var titlebar:ColorRect = $vbox/titlebar
@onready var counter:PanelContainer = $counter
@onready var minimize:Button = $vbox/titlebar/margin/hbox/minimize
@onready var maximize:Button = $vbox/titlebar/margin/hbox/maximize
@onready var close:Button = $vbox/titlebar/margin/hbox/close
@onready var view:MarginContainer = $vbox/margin
var supported_formats:PackedStringArray = [ "jpg", "jpeg", "jfif", "png", "bmp", "dds", "ktx", "exr", "hdr", "tga", "svg", "webp" ]
enum ImageType { JPEG, PNG, WEBP }
#endregion

#region Settings
var reset_camera_on_image_change:bool = true
var use_threading:bool = true
var use_history:bool = true
var use_horizontal_fit:bool = false
var history_max_size:int = 10
var virtual_row_size:int = 4 # make customizable
var window_max_size_percent:float = 0.75
var always_use_full_space:bool = true
var full_space_percent:float = 0.95 # how close to Right/Bottom borders does it get when using full space
#endregion

#region Variables
var image_index:int = 0
var image_aspect:float = 1.0
var image_paths:Array[String] = []
var history_queue:Array[String] = []
var history:Dictionary = {} # String(path) : ImageTexture(image)
#endregion

func _ready() -> void:
	# connect signals
	get_tree().root.files_dropped.connect(_files_dropped)
	get_tree().root.ready.connect(_load_cmdline_image)
	Globals.prev_pressed.connect(prev_image)
	Globals.next_pressed.connect(next_image)

#region User Input
func _unhandled_input(event:InputEvent) -> void:
	if event is InputEventKey:
		var ev:InputEventKey = event as InputEventKey
		if not ev.pressed: return
		# H V F R are used by display_image
		if ev.keycode == KEY_TAB: Globals.update_visibility_ui.emit()
		elif ev.keycode == KEY_B: _toggle_background_transparency()
		elif ev.keycode == KEY_Z: 
			use_horizontal_fit = not use_horizontal_fit
			resize_window()
		elif ev.keycode == KEY_X: 
			always_use_full_space = not always_use_full_space
			resize_window()
		elif ev.keycode == KEY_LEFT: prev_image(1)
		elif ev.keycode == KEY_RIGHT: next_image(1)
		elif ev.keycode == KEY_UP: prev_image(virtual_row_size)
		elif ev.keycode == KEY_DOWN: next_image(virtual_row_size)
		elif ev.keycode == KEY_F5: refresh_list()
		elif ev.keycode == KEY_F8 or ev.keycode == KEY_ESCAPE: get_tree().quit()
		elif ev.keycode == KEY_F9: _update_titlebar_visibility()
		elif ev.keycode == KEY_F10: _set_window_mode(Window.MODE_MAXIMIZED)
		elif ev.keycode == KEY_F11: _set_window_mode(Window.MODE_FULLSCREEN)
#endregion

#region User Interface
func _toggle_background_transparency() -> void:
	get_tree().root.transparent_bg = not get_tree().root.transparent_bg

func _update_titlebar_visibility() -> void:
	get_tree().root.borderless = not get_tree().root.borderless
	if get_tree().root.mode == Window.MODE_WINDOWED:
		resize_window()

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

func update_ui(image_name:String, image_dims:Vector2) -> void:
	get_tree().root.title = "(%d x %d) %s" % [image_dims.x, image_dims.y, image_name]
	
	if reset_camera_on_image_change: 
		display.reset_camera_state()
	
	if get_tree().root.mode == Window.MODE_WINDOWED:
		resize_window()

func _get_window_position() -> Vector2i:
	var curr_screen_size:Vector2i = DisplayServer.screen_get_size()
	var window_pos:Vector2i = DisplayServer.window_get_position()
	var screen:int = 0
	while window_pos.x > curr_screen_size.x:
		window_pos.x -= DisplayServer.screen_get_size(screen).x
		screen += 1
	screen = 0
	while window_pos.y > curr_screen_size.y:
		window_pos.y -= DisplayServer.screen_get_size(screen).y
		screen += 1
	return window_pos

func resize_window(too_large:bool=false) -> void:
	var screen_size:Vector2i = DisplayServer.screen_get_size()
	var window_max_size:Vector2i = screen_size * window_max_size_percent
	var window_pos:Vector2i = _get_window_position()
	
	if too_large or always_use_full_space:
		window_max_size = (screen_size - window_pos) * full_space_percent
	
	var max_aspect:float = float(window_max_size.x) / window_max_size.y
	var _size:Vector2i = window_max_size
	
	if use_horizontal_fit or (image_aspect > 1 and image_aspect >= max_aspect):
		_size.y = window_max_size.x / image_aspect
		if _size.y > window_max_size.y and not use_horizontal_fit:
			var ratio:float = float(window_max_size.y) / _size.y
			_size.y = window_max_size.y
			_size.x *= ratio
	else: 
		_size.x = window_max_size.y * image_aspect
		if _size.x > window_max_size.x:
			var ratio:float = float(window_max_size.x) / _size.x
			_size.x = window_max_size.x
			_size.y *= ratio
	
	if not too_large and not always_use_full_space:
		var tmp_size:Vector2i = _size + window_pos
		if tmp_size.x > screen_size.x or tmp_size.y > screen_size.y:
			resize_window(true)
			return
	
	get_tree().root.size = _size
	display.resize()

func prev_image(nth_index:int) -> void:
	if image_paths.is_empty(): return
	var num_images:int = image_paths.size()
	image_index = (num_images + (image_index - (nth_index % num_images))) % num_images
	change_image(image_paths[image_index])
	Globals.update_counter.emit(image_index + 1, num_images)

func next_image(nth_index:int) -> void:
	if image_paths.is_empty(): return
	var num_images:int = image_paths.size()
	image_index = (image_index + nth_index) % num_images
	change_image(image_paths[image_index])
	Globals.update_counter.emit(image_index + 1, num_images)

func refresh_list() -> void:
	if image_paths.is_empty(): return
	var path:String = image_paths[image_index]
	create_paths_array(path)
	resize_window()
#endregion

#region IO
func _load_cmdline_image() -> void:
	var args:PackedStringArray = OS.get_cmdline_args()
	if args.size() > 0 and not OS.is_debug_build():
		var path:String = args[0]
		create_paths_array(path)
		change_image(path)

func _files_dropped(paths:PackedStringArray) -> void:
	var tmp_paths:Array[String] = []
	for path:String in paths:
		if not FileAccess.file_exists(path): continue
		var extension:String = path.get_extension().to_lower()
		if not supported_formats.has(extension): continue
		tmp_paths.append(path)
	
	if tmp_paths.size() == 1:
		var path:String = tmp_paths[0]
		create_paths_array(path)
		change_image(path)
	
	elif tmp_paths.size() > 1:
		image_paths = tmp_paths
		change_image(tmp_paths[0])
		image_index = 0
		Globals.update_counter.emit(image_index + 1, image_paths.size())

func change_image(path:String) -> void:
	if use_history and history.has(path) and history[path] is ImageTexture:
		var _texture:ImageTexture = history[path] as ImageTexture
		var _image_dimensions:Vector2 = _texture.get_image().get_size()
		image_aspect = _image_dimensions.x / _image_dimensions.y
		update_ui(path.get_file(), _image_dimensions)
		display.change_image(_texture, image_aspect)
		return 
	
	if use_threading: 
		load_image(image_index, path)
		return
	
	if not FileAccess.file_exists(path): return
	var image:Image = Image.new()
	var error:int = image.load(path)
	if error != OK: 
		var ext:String = path.get_extension().to_lower()
		var result:Array = [-1, null]
		if ext == "png" or ext == "jfif": result = _load_custom(path, image, ImageType.JPEG)
		if ext == "jpg" or ext == "jpeg": result = _load_custom(path, image, ImageType.PNG)
		if result[0] != OK or result[1] == null:
			return
		image = result[1]
	
	var texture:ImageTexture = ImageTexture.create_from_image(image)
	if use_history: add_to_history(path, texture)
	var image_dimensions:Vector2 = image.get_size()
	image_aspect = image_dimensions.x / image_dimensions.y
	update_ui(path.get_file(), image_dimensions)
	display.change_image(texture, image_aspect)

func _load_custom(path:String, image:Image, type:ImageType) -> Array:
	var err:int = -1
	var buf:PackedByteArray = FileAccess.get_file_as_bytes(path)
	if type == ImageType.JPEG: err = image.load_jpg_from_buffer(buf)
	elif type == ImageType.PNG: err = image.load_png_from_buffer(buf)
	return [err, image]

func create_paths_array(path:String) -> void:
	image_paths.clear()
	var folder:String = path.get_base_dir()
	if not DirAccess.dir_exists_absolute(folder): return
	var files:Array[String] = Array(Array(DirAccess.get_files_at(folder)), TYPE_STRING, "", null) as Array[String]
	files.sort_custom(Globals.SortNatural.sort)
	
	var index:int = 0
	for file:String in files:
		if supported_formats.has(file.get_extension().to_lower()):
			image_paths.append(folder.path_join(file))
			if path.get_file() == file: 
				image_index = index
			else: index += 1
	Globals.update_counter.emit(image_index + 1, image_paths.size())
#endregion

#region History
func add_to_history(path:String, texture:ImageTexture) -> void:
	if history_queue.size() >= history_max_size:
		history.erase(history_queue.pop_front())
	history[path] = texture
	history_queue.push_back(path)
#endregion

#region Threading
func load_image(index:int, path:String) -> void:
	var thread:Thread = Thread.new()
	thread.start(_load_image.bindv([index, path, thread]))

func _load_image(index:int, path:String, thread:Thread) -> void:
	if not FileAccess.file_exists(path) or index != image_index:
		thread.wait_to_finish.call_deferred()
		return
	
	var image:Image = Image.new()
	var error:int = image.load(path)
	if error != OK or index != image_index:
		var ext:String = path.get_extension().to_lower()
		var result:Array = [-1, null]
		if ext == "png" or ext == "jfif": result = _load_custom(path, image, ImageType.JPEG)
		if ext == "jpg" or ext == "jpeg": result = _load_custom(path, image, ImageType.PNG)
		if result[0] != OK or result[1] == null or index != image_index:
			thread.wait_to_finish.call_deferred()
			return
		image = result[1]
	
	var texture:ImageTexture = ImageTexture.create_from_image(image)
	if index == image_index: 
		_finished.call_deferred(index, path, texture)
	thread.wait_to_finish.call_deferred()

func _finished(index:int, path:String, texture:ImageTexture) -> void:
	if index != image_index: return
	if use_history: add_to_history(path, texture)
	var image_dimensions:Vector2 = texture.get_image().get_size()
	image_aspect = image_dimensions.x / image_dimensions.y
	update_ui(path.get_file(), image_dimensions)
	display.change_image(texture, image_aspect)

#region Title Bar
func _on_minimize_pressed() -> void:
	get_tree().root.mode = Window.MODE_MINIMIZED
	minimize.release_focus()

func _on_maximize_pressed() -> void:
	_set_window_mode(Window.MODE_MAXIMIZED)
	maximize.release_focus()

func _on_close_pressed() -> void:
	get_tree().quit()

var dragging:bool = false
func _on_titlebar_gui_input(event:InputEvent) -> void:
	if event is InputEventMouseButton:
		var ev:InputEventMouseButton = event as InputEventMouseButton
		if not ev.pressed: # prevent events from firing twice
			dragging = false
			resize_window()
		elif ev.button_index == MOUSE_BUTTON_LEFT: 
			dragging = true
	elif event is InputEventMouseMotion:
		var ev:InputEventMouseMotion = event as InputEventMouseMotion
		if dragging: 
			get_tree().root.position += Vector2i(ev.relative)
			# prevent glitch where it rapidly alternates between 2 positions
			var tb_center:Vector2 = (titlebar.size - titlebar.position) / 2
			tb_center *= 1.5
			if ev.relative.x > tb_center.x or ev.relative.y > tb_center.y:
				dragging = false
#endregion
