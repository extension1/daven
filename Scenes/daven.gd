extends CharacterBody2D
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D

const SPEED = 350
var isBouncing: bool = false
var lightblocker = 97
func _ready() -> void:
	
	velocity = Vector2(-SPEED, 0)

func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("bounce"):
		isBouncing = not isBouncing
		if isBouncing:
			velocity = Vector2(-SPEED, -500) 

	if isBouncing:
		var col := move_and_collide(velocity * delta) 
		if col:
			check_breakable_tile(col)
			velocity = velocity.bounce(col.get_normal())
	else:
		if not is_on_floor():
			velocity += get_gravity() * delta

		var direction := Input.get_axis("left", "right")
		if direction:
			velocity.x = direction * SPEED
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED)

		move_and_slide()

	
	if velocity.x < 0: 
		animated_sprite_2d.play("Walk")
		animated_sprite_2d.flip_h = true
	elif velocity.x > 0: 
		animated_sprite_2d.play("Walk")
		animated_sprite_2d.flip_h = false

func check_breakable_tile(collision: KinematicCollision2D) -> void:
	var collider := collision.get_collider()
	
	if collider is TileMapLayer:
		var hit_pos := collision.get_position() - collision.get_normal()
		var tile_coords: Vector2i = collider.local_to_map(collider.to_local(hit_pos))
		
		var tile_data: TileData = collider.get_cell_tile_data(tile_coords)
		if tile_data and tile_data.get_custom_data("breakable"):
			
			collider.erase_cell(tile_coords)
			
			lightblocker = lightblocker -1
			
	if lightblocker ==0:
		get_tree().change_scene_to_file("res://Scenes/cut.tscn")
	
