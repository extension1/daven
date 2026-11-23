extends CanvasLayer

# by the way, if you're changing anything, DO NOT move "overlay" above the "Bedrock" layer. It won't work if you do.

var shards: int = 0
@onready var counter: RichTextLabel = $HBoxContainer/RichTextLabel

func _ready() -> void:
	var worldnode = get_tree().get_first_node_in_group("chunk_world")
	worldnode.brick_broken.connect(_on_break)
	print(worldnode) ## debugg


func _on_break(_layer: TileMapLayer, cell: Vector2i) -> void:
	shards += 1
	counter.text = str(shards)
	print("hit") ## debug


func _on_button_toggled(toggled_on: bool) -> void:
	Engine.time_scale = 5
