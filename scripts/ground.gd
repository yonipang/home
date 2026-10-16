extends Node2D
var state: RefCounted
var time: float = 0
var grass: Texture2D = preload("res://assets/tiles/a_grass.png")
var water_texture: Texture2D = preload("res://assets/tiles/a_water.png")
var cliff: Texture2D = preload("res://assets/tiles/a_cliff.png")

func _draw() -> void:
	if state == null: return
	for y in range(state.SIZE.y):
		for x in range(state.SIZE.x):
			var p := Vector2i(x,y)
			var pos: Vector2 = Vector2(p) * state.TILE
			var n: int = posmod(x * 73 + y * 137 + x*y*3, 17)
			var color := Color("405647") if n < 8 else Color("465d4b")
			if state.water.has(p):
				color = Color("31565b")
				draw_texture_rect_region(water_texture,Rect2(pos,Vector2.ONE*32),Rect2((Vector2(p)*16).posmodv(Vector2(64,64)),Vector2(16,16)))
				if not state.water.has(p+Vector2i.UP):
					draw_texture_rect(cliff,Rect2(pos,Vector2(32,18)),false)
				var ripple := int(time*2+x+y) % 3
				draw_rect(Rect2(pos+Vector2(4+ripple*3,10),Vector2(11,2)),Color("527b79"))
				continue
			draw_texture_rect_region(grass,Rect2(pos,Vector2.ONE*32),Rect2((Vector2(p)*16).posmodv(Vector2(64,64)),Vector2(16,16)))
			draw_rect(Rect2(pos+Vector2(n+3,n+4),Vector2(3,2)),Color("73816a") if n < 4 else Color("384e40"))
			if n % 5 == 0 and not state.walls.has(p):
				draw_rect(Rect2(pos+Vector2(8,21),Vector2(2,5)),Color("829567"))
				draw_rect(Rect2(pos+Vector2(6,23),Vector2(6,2)),Color("829567"))
			if n == 2 and not state.walls.has(p):
				draw_rect(Rect2(pos+Vector2(23,12),Vector2(2,5)),Color("9bbab0"))
				draw_rect(Rect2(pos+Vector2(21,10),Vector2(6,3)),Color("b4d5bd"))
