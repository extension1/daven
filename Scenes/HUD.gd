extends CanvasLayer

# by the way, if you're changing anything, DO NOT move "overlay" above the "Bedrock" layer. It won't work if you do.

const smol_numbers: Array[String] = [
	"", "k", "m", "b", "t", "qd", "qi", "sx", "sp", "oc", "no"
]

const medium_numbers: Array[String] = [
	"", "u", "d", "t", "qa", "qi", "sx", "sp", "oc", "no"
]

const large_numbers: Array[String] = [
	"", "d", "vg", "tg", "qag", "qig", "sxg", "spg", "ocg", "nog", "ce"
]

var shards: float = 0.0
@onready var counter: RichTextLabel = $HBoxContainer/RichTextLabel

func _ready() -> void:
	var worldnode = get_tree().get_first_node_in_group("chunk_world")
	worldnode.brick_broken.connect(_on_break)
	print(worldnode) ## debugg


func _on_break(_layer: TileMapLayer, _cell: Vector2i) -> void:
	shards += 1
	counter.text = format_number(shards)
	print("hit") ## debug


func _on_button_toggled(_toggled_on: bool) -> void:
	Engine.time_scale = 5

func format_number(value: float) -> String:
	if is_inf(value):
		return "INF"
	if abs(value) < 1000.0:
		return str(snapped(value, 0.01))
	
	var tier: int = int(floor(log(abs(value)) / log(1000.0)))
	var scaled: float = value / pow(1000.0, tier)
	
	if abs(scaled) >= 999.995:
		scaled /= 1000.0
		tier += 1
		
	return "%.2f%s" % [scaled, _get_suffix(tier)]

func _get_suffix(tier: int) -> String:
	if tier < smol_numbers.size():
		return smol_numbers[tier]
	
	var nindex: int = tier - 1
	var ones: int = nindex % 10
	@warning_ignore("integer_division")
	var tens: int = nindex / 10
	
	if tens == 1:
		return medium_numbers[ones] + "dc"
	if tens < large_numbers.size():
		return medium_numbers[ones] + large_numbers[tens]
		
	return "e" + str(tier * 3)
