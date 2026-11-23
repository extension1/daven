extends CharacterBody2D
# idk apparently comments are important. p.s: i had to use a bit of code from a tutorial for this cuz i couldnt for the love of me figure out the draw animation thingy

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D

const SPEED = 350
const SPIN_SPEED = 3240

const SLOWMO_SCALE = 0.25        
const LAUNCH_SPEED = 600.0      
const MIN_PULL = 20.0            

const RING_RADIUS = 68.0
const DOT_START = 60.0           
const DOT_SPACING = 16.0
const PREVIEW_LEN = 320.0        
const PREVIEW_BOUNCE_LEN = 160.0 
const COLOR_AIM = Color(1, 0.75, 0.25)

enum State { NORMAL, AIMING, BOUNCING }

var state: State = State.NORMAL
var spin_dir: int = 1 # 1 = clockwise, -1 = counter-clockwise
var lightblocker: int = 0        
var won: bool = false

var dragging: bool = false
var drag_start: Vector2 = Vector2.ZERO
var aim_vector: Vector2 = Vector2.ZERO  

var preview_hit_point: Vector2 = Vector2.ZERO
var preview_bounce_end: Vector2 = Vector2.ZERO
var preview_has_bounce: bool = false

func _ready() -> void:
	velocity = Vector2(-SPEED, 0)
	lightblocker = count_breakables(get_tree().root)
	add_to_group("player")

func _exit_tree() -> void:
	Engine.time_scale = 1.0

func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("bounce"):
		if state == State.NORMAL:
			_set_state(State.AIMING)
		else:
			_set_state(State.NORMAL)

	match state:
		State.AIMING:
			# slow mo wow so cool yay
			_move_normal(delta)
			_process_aiming()
		State.BOUNCING:
			animated_sprite_2d.rotation_degrees += SPIN_SPEED * spin_dir * delta
			
			var col := move_and_collide(velocity * delta)
			if col:
				check_breakable_tile(col)
				velocity = velocity.bounce(col.get_normal())
				spin_dir *= -1 # Flip spin direction on collision
		State.NORMAL:
			_move_normal(delta)

	_update_animation()

func _move_normal(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	var direction := Input.get_axis("left", "right")
	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()

# america

func _set_state(new_state: State) -> void:
	if new_state == state:
		return
	if state == State.AIMING:
		_end_aiming()
	elif state == State.BOUNCING:
		animated_sprite_2d.rotation_degrees = 0.0
		
	state = new_state
	if state == State.AIMING:
		_begin_aiming()

func _begin_aiming() -> void:
	dragging = false
	aim_vector = Vector2.ZERO
	preview_has_bounce = false
	Engine.time_scale = SLOWMO_SCALE
	queue_redraw()

func _end_aiming() -> void:
	Engine.time_scale = 1.0
	dragging = false
	aim_vector = Vector2.ZERO
	preview_has_bounce = false
	queue_redraw()

func _process_aiming() -> void:
	var mouse_down: bool = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var mouse_pos: Vector2 = get_viewport().get_mouse_position()

	if mouse_down and not dragging:
		dragging = true
		drag_start = mouse_pos

	if dragging:
		aim_vector = drag_start - mouse_pos

		if not mouse_down:
			if aim_vector.length() >= MIN_PULL:
				velocity = aim_vector.normalized() * LAUNCH_SPEED
				spin_dir = 1 if aim_vector.x >= 0 else -1
				_set_state(State.BOUNCING)
				return
			
			dragging = false
			aim_vector = Vector2.ZERO
		elif aim_vector.length() >= MIN_PULL:
			_update_preview()

	queue_redraw() 

func _update_preview() -> void:
	var dir: Vector2 = aim_vector.normalized()
	var hit: KinematicCollision2D = move_and_collide(dir * PREVIEW_LEN, true)
	if hit:
		preview_hit_point = hit.get_travel()
		var reflected: Vector2 = dir.bounce(hit.get_normal())
		preview_bounce_end = preview_hit_point + reflected * PREVIEW_BOUNCE_LEN
		preview_has_bounce = true
	else:
		preview_hit_point = dir * PREVIEW_LEN
		preview_has_bounce = false

func _draw() -> void:
	if state != State.AIMING:
		return

	draw_arc(Vector2.ZERO, RING_RADIUS, 0.0, TAU, 64, Color(1, 1, 1, 0.2), 2.0, true)

	if not dragging or aim_vector.length() < MIN_PULL:
		return

	var tint: Color = COLOR_AIM
	var dir: Vector2 = aim_vector.normalized()

	draw_arc(Vector2.ZERO, RING_RADIUS, 0.0, TAU, 64, tint, 4.0, true)

	_draw_dots(dir * DOT_START, preview_hit_point, tint, 1.0)

	if preview_has_bounce:
		draw_circle(preview_hit_point, 9.0, Color(tint.r, tint.g, tint.b, 0.3))
		draw_circle(preview_hit_point, 4.0, tint)
		_draw_dots(preview_hit_point, preview_bounce_end, tint, 0.5)

func _draw_dots(from: Vector2, to: Vector2, tint: Color, strength: float) -> void:
	var d: Vector2 = to - from
	var length: float = d.length()
	if length < 1.0:
		return
	var dir: Vector2 = d / length
	var dist: float = fposmod(float(Time.get_ticks_msec()) * 0.03, DOT_SPACING)  # makes the dots march
	while dist < length:
		var t: float = dist / length
		var alpha: float = lerpf(1.0, 0.25, t) * strength
		var radius: float = lerpf(4.0, 2.0, t)
		draw_circle(from + dir * dist, radius, Color(tint.r, tint.g, tint.b, alpha))
		dist += DOT_SPACING

# useless animation

func _update_animation() -> void:
	if state == State.BOUNCING or absf(velocity.x) > 1.0:
		animated_sprite_2d.play("Walk")
		if velocity.x < 0:
			animated_sprite_2d.flip_h = true
		elif velocity.x > 0:
			animated_sprite_2d.flip_h = false
	else:
		animated_sprite_2d.play("Idle")

# break tile yay

func check_breakable_tile(collision: KinematicCollision2D) -> void:
	var layer := collision.get_collider() as TileMapLayer
	if layer == null:
		return

	var hit_pos: Vector2 = collision.get_position() - collision.get_normal()
	var tile_coords: Vector2i = layer.local_to_map(layer.to_local(hit_pos))

	var tile_data: TileData = layer.get_cell_tile_data(tile_coords)
	if tile_data and tile_data.get_custom_data("breakable"):
		layer.erase_cell(tile_coords)
		get_tree().call_group("chunk_world", "notify_broken", layer, tile_coords)
		lightblocker -= 1
		
### i removed these for now cuz i havent figured out the ending thingymajigs yet
		# if lightblocker <= 0 and not won:
			# won = true
			# get_tree().change_scene_to_file("res://Scenes/cut.tscn")

# breakable flag count 
func count_breakables(node: Node) -> int:
	var total := 0
	var layer := node as TileMapLayer
	if layer and not layer.is_in_group("generated_bricks"):
		for cell in layer.get_used_cells():
			var tile_data: TileData = layer.get_cell_tile_data(cell)
			if tile_data and tile_data.get_custom_data("breakable"):
				total += 1
	for child in node.get_children():
		total += count_breakables(child)
	return total
