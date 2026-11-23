extends Camera2D

var min_zoom: float = 0.5
var max_zoom: float = 2.0
var zoom_variable: float = 1.0
var zoom_speed: float = 8.0

func _ready() -> void:
	print(zoom)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("zoom_in"):
		zoom_variable *= 1.1
		print(zoom_variable)  ## debug
	elif event.is_action_pressed("zoom_out"):
		zoom_variable /= 1.1
		print(zoom_variable) ## debug
	# bugtesting so infinite zoom yayay 
	zoom_variable = clampf(zoom_variable, min_zoom, max_zoom)

# smooth criminal
func _process(delta: float) -> void:
	var zoom_x = zoom.x
	var zoom_y = zoom.y
	var weight = zoom_speed * delta
	var smooth_x = lerpf(zoom_x,zoom_variable,weight)
	var smooth_y = lerpf(zoom_y,zoom_variable,weight)
	zoom = Vector2(smooth_x,smooth_y)
