extends Node
## Moves between top-level scenes with a fade to black.
## With a loading screen, the next scene streams in on a background thread
## (ResourceLoader threaded loading) while the loading screen shows progress.

const LOADING_SCREEN := preload("res://scenes/loading/loading_screen.tscn")
const FADE_SECONDS := 0.35
## Keeps the loading screen on screen long enough to read on fast machines.
const MIN_LOADING_SECONDS := 1.0

var _layer: CanvasLayer
var _fade: ColorRect
var _busy := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_layer = CanvasLayer.new()
	_layer.layer = 100
	add_child(_layer)

	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.modulate.a = 0.0
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(_fade)


func is_busy() -> bool:
	return _busy


## Fades out, swaps the current scene for the one at `path`, and fades back in.
func change_scene(path: String, with_loading_screen := false) -> void:
	if _busy:
		return
	_busy = true
	await fade_out()
	if with_loading_screen:
		await _change_with_loading_screen(path)
	else:
		get_tree().change_scene_to_file(path)
		await get_tree().scene_changed
	await fade_in()
	_busy = false


func fade_out(seconds := FADE_SECONDS) -> void:
	await _fade_to(1.0, seconds)


func fade_in(seconds := FADE_SECONDS) -> void:
	await _fade_to(0.0, seconds)


func _fade_to(alpha: float, seconds: float) -> void:
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP if alpha > 0.0 else Control.MOUSE_FILTER_IGNORE
	var tween := create_tween().set_ignore_time_scale(true)
	tween.tween_property(_fade, "modulate:a", alpha, seconds)
	await tween.finished


func _change_with_loading_screen(path: String) -> void:
	var screen: LoadingScreen = LOADING_SCREEN.instantiate()
	_layer.add_child(screen)
	_layer.move_child(screen, 0) # keep the fade rect on top
	await fade_in()

	var error := ResourceLoader.load_threaded_request(path)
	if error != OK:
		push_error("SceneRouter: could not start loading %s (error %d)" % [path, error])
		screen.queue_free()
		return

	var elapsed := 0.0
	var progress: Array = []
	while true:
		var status := ResourceLoader.load_threaded_get_status(path, progress)
		var real_progress: float = progress[0] if not progress.is_empty() else 0.0
		# Show whichever is slower: the real progress or the minimum display time.
		screen.set_progress(minf(real_progress, elapsed / MIN_LOADING_SECONDS))
		if status == ResourceLoader.THREAD_LOAD_LOADED and elapsed >= MIN_LOADING_SECONDS:
			break
		if status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			push_error("SceneRouter: loading %s failed" % path)
			screen.queue_free()
			return
		await get_tree().process_frame
		elapsed += get_process_delta_time()

	screen.set_progress(1.0)
	var packed := ResourceLoader.load_threaded_get(path) as PackedScene
	await fade_out()
	screen.queue_free()
	get_tree().change_scene_to_packed(packed)
	await get_tree().scene_changed
