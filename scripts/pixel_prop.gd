extends Node2D
## Small original code-drawn placeholder assets; swap this view for Sprite2D later.
var kind: String = "wall"
var turn: int = 0
var variant: int = 0
var damaged: int = 0
var moving: bool = false
var clock: float = 0
var tint := Color("74a389")
var top_texture: Texture2D = preload("res://assets/tiles/a_wtop_2_0.png")
var front_texture: Texture2D = preload("res://assets/tiles/a_wfront_2.png")
var front_exposed: bool = true
var facing := Vector2.DOWN
var frames: Dictionary = {
	"down": [preload("res://assets/tiles/pl_down_0.png"),preload("res://assets/tiles/pl_down_1.png")],
	"up": [preload("res://assets/tiles/pl_up_0.png"),preload("res://assets/tiles/pl_up_1.png")],
	"side": [preload("res://assets/tiles/pl_side_0.png"),preload("res://assets/tiles/pl_side_1.png")]
}

func box(x: float, y: float, w: float, h: float, color: String) -> void:
	draw_rect(Rect2(x,y,w,h), Color(color))

func _draw() -> void:
	match kind:
		"wall":
			draw_texture_rect(top_texture,Rect2(-16,-52,32,32),false)
			if front_exposed:
				draw_texture_rect(front_texture,Rect2(-16,-20,32,20),false)
			if damaged > 0:
				box(0,-20,2,7,"1d302c")
				box(-3,-14,4,2,"1d302c")
				if damaged > 1: box(-4,-13,2,9,"1d302c")
			return
		"player":
			box(-8,-3,16,6,"233c36")
			var direction: String = "side" if absf(facing.x) > absf(facing.y) else "up" if facing.y < 0 else "down"
			var frame_index: int = int(clock * 6) % 2 if moving else 0
			var destination := Rect2(-16,-34,32,38)
			if direction == "side" and facing.x < 0:
				destination.position.x = 16
				destination.size.x = -32
			draw_texture_rect(frames[direction][frame_index],destination,false)
			return
		"torch":
			box(-6,-3,12,5,"253a32")
			box(-3,-16,6,16,"6c5140")
			box(-1,-16,2,14,"aa8253")
			box(-5,-21,10,6,"614e38")
			box(-4,-28,8,9,"d58f4f")
			box(-2,-31,4,11,"efc577")
			box(-1,-26,3,5,"fff1b6")
		"bench":
			box(-14,-3,28,6,"22372f")
			box(-12,-12,4,13,"634a36")
			box(8,-12,4,13,"634a36")
			box(-15,-20,30,12,"563f30")
			box(-14,-21,28,9,"ac865a")
			box(-13,-20,26,2,"d0ad76")
			box(-13,-14,26,1,"79583e")
			box(-8+turn*2,-25,9,4,"7e978c")
			box(5,-24,2,9,"cdb787")
		"tree":
			box(-25,-6,50,13,"20392f")
			box(-12,-40,24,42,"453e30")
			box(-8,-42,15,39,"795b3b")
			box(-3,-38,4,34,"ac8450")
			box(-17,-4,34,6,"655134")
			box(-27,-66,54,28,"284e40")
			box(-35,-59,70,17,"284e40")
			box(-22,-77,44,37,"426e50")
			box(-31,-64,61,17,"426e50")
			box(-20,-73,35,12,"648b5d")
			box(-27,-61,22,7,"648b5d")
			box(-16,-72,20,3,"8ba96b")
			for p in [Vector2(-21,-48),Vector2(18,-53),Vector2(2,-64)]:
				draw_rect(Rect2(p,Vector2(4,6)),Color("efd493"))
		"planter":
			box(-10,-3,20,6,"263b31")
			box(-8,-13,16,13,"90694e")
			box(-10,-15,20,5,"bc9370")
			box(-9,-23,18,9,"3d6747")
			box(-6,-28,12,13,"6d9865")
			box(-4,-27,7,4,"a4b77b")
		_:
			draw_rect(Rect2(-10,-20,20,20),tint)
