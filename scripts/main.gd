extends Control

#region (Effective) Constants
@onready var display:Display = $margin/display_image as Display
var supported_formats:PackedStringArray = [ "jpg", "jpeg", "png", "bmp", "dds", "ktx", "exr", "hdr", "tga", "svg", "webp" ]
#endregion

#region Settings
var reset_camera_on_image_change:bool = true
var virtual_row_size:int = 10
var window_max_size:Vector2 = Vector2(960, 720)
var window_max_size_percent:float = 0.75

var use_threading:bool = true
var use_history:bool = true
var history_max_size:int = 10
#endregion

#region Variables
var image_paths:Array[String] = []
var image_index:int = 0
var image_aspect:float = 1.0

var history:Dictionary = {} # String(path) : ImageTexture(image)
var history_queue:Array[String] = []
#endregion

func _ready() -> void:
	# need to make this a setting the user can toggle; alternatively,
	# can just put a colorrect in the background and allow user to choose color, including transparent
	# connect signals
	# get_tree().root.transparent_bg = true
	get_tree().root.files_dropped.connect(_files_dropped)
	get_tree().root.ready.connect(_load_cmdline_image)
	Globals.prev_pressed.connect(prev_image)
	Globals.next_pressed.connect(next_image)
	
	# calc max window size
	var screen_size:Vector2i = DisplayServer.screen_get_size()
	window_max_size = screen_size * window_max_size_percent

#region User Input
func _unhandled_input(event:InputEvent) -> void:
	if event is InputEventKey:
		var ev:InputEventKey = event as InputEventKey
		if not ev.pressed: return
		if ev.keycode == KEY_TAB: Globals.update_visibility_ui.emit()
		elif ev.keycode == KEY_B: _toggle_background_transparency()
		elif ev.keycode == KEY_LEFT: prev_image(1)
		elif ev.keycode == KEY_RIGHT: next_image(1)
		elif ev.keycode == KEY_UP: prev_image(virtual_row_size)
		elif ev.keycode == KEY_DOWN: next_image(virtual_row_size)
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

func update_ui(image_name:String) -> void:
	get_tree().root.title = "ImageViewer - %s" % [image_name]
	
	if reset_camera_on_image_change: 
		display.reset_camera_state()
	
	if get_tree().root.mode == Window.MODE_WINDOWED:
		resize_window()

func resize_window() -> void:
	var max_aspect:float = float(window_max_size.x) / window_max_size.y
	var _size:Vector2 = window_max_size
	
	if image_aspect > 1 and image_aspect >= max_aspect:
		_size.y = window_max_size.x / image_aspect
	else: _size.x = window_max_size.y * image_aspect
	
	get_tree().root.size = _size
	display.resize()

func prev_image(nth_index:int) -> void:
	if image_paths.is_empty(): return
	image_index = (image_paths.size() + ((image_index - nth_index) + image_paths.size())) % image_paths.size()
	change_image(image_paths[image_index])
	Globals.update_counter.emit(image_index + 1, image_paths.size())

func next_image(nth_index:int) -> void:
	if image_paths.is_empty(): return
	image_index = (image_paths.size() + ((image_index + nth_index) - image_paths.size())) % image_paths.size()
	change_image(image_paths[image_index])
	Globals.update_counter.emit(image_index + 1, image_paths.size())
#endregion

#region IO
func _load_cmdline_image() -> void:
	var args:PackedStringArray = OS.get_cmdline_args()
	if args.size() > 0 and not OS.is_debug_build():
		var path:String = args[0]
		create_paths_array(path)
		change_image(path)

func _files_dropped(paths:PackedStringArray) -> void:
	# ignore extra paths for now
	var path:String = paths[0]
	create_paths_array(path)
	change_image(path)

func change_image(path:String) -> void:
	if use_history and history.has(path) and history[path] is ImageTexture:
		var _texture:ImageTexture = history[path] as ImageTexture
		var _tmp:Vector2 = _texture.get_image().get_size()
		image_aspect = _tmp.x / _tmp.y
		update_ui(path.get_file())
		display.change_image(_texture, image_aspect)
		return 
	
	if use_threading: 
		load_image(image_index, path)
		return
	
	if not FileAccess.file_exists(path): return
	var image:Image = Image.new()
	var error:int = image.load(path)
	if error != OK: return
	
	var texture:ImageTexture = ImageTexture.create_from_image(image)
	if use_history: add_to_history(path, texture)
	var tmp:Vector2 = image.get_size()
	image_aspect = tmp.x / tmp.y
	update_ui(path.get_file())
	display.change_image(texture, image_aspect)

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
	if not FileAccess.file_exists(path): return
	if index != image_index: return
	
	var image:Image = Image.new()
	if index != image_index: return
	var error:int = image.load(path)
	if error != OK: return
	if index != image_index: return
	
	var texture:ImageTexture = ImageTexture.create_from_image(image)
	if index != image_index: return
	_finished.call_deferred(index, path, texture)
	thread.wait_to_finish.call_deferred()

func _finished(index:int, path:String, texture:ImageTexture) -> void:
	if index != image_index: return
	if use_history: add_to_history(path, texture)
	var tmp:Vector2 = texture.get_image().get_size()
	image_aspect = tmp.x / tmp.y
	update_ui(path.get_file())
	display.change_image(texture, image_aspect)
#endregion
