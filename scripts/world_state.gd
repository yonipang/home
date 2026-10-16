extends RefCounted
## Pure rules and save data. No scene or rendering dependencies.
const SIZE := Vector2i(36, 28)
const TILE := 32
const SAVE_VERSION := 1
var walls: Dictionary = {}
var water: Dictionary = {}
var objects: Dictionary = {}
var hits: Dictionary = {}
var player := Vector2(18.5, 15.5) * TILE
var stone: int = 12
var mined: int = 0
var placed: int = 0
var definitions: Dictionary = {}

func _init() -> void:
	definitions = JSON.parse_string(FileAccess.get_file_as_string("res://data/furniture.json"))
	generate()

func generate() -> void:
	walls.clear()
	water.clear()
	objects.clear()
	hits.clear()
	stone = 12
	mined = 0
	placed = 0
	player = Vector2(18.5, 15.5) * TILE
	for y in range(SIZE.y):
		for x in range(SIZE.x):
			var p := Vector2i(x, y)
			var edge := x == 0 or y == 0 or x == SIZE.x - 1 or y == SIZE.y - 1
			var d := Vector2((x - 18.0) / 14.0, (y - 14.0) / 10.0).length()
			if edge or d > 1.0 + sin(x * 0.8 + y * 0.7) * 0.09:
				walls[p] = true
			elif x >= 24 and x <= 28 and y >= 14 and y <= 19 and not (x == 24 and y == 14):
				water[p] = true
	# A short mineable seam near spawn, not a mandatory gate.
	for p in [Vector2i(15, 12), Vector2i(16, 12), Vector2i(17, 12), Vector2i(18, 12), Vector2i(19, 12), Vector2i(20, 12), Vector2i(21, 12)]:
		walls[p] = true
	objects[Vector2i(14, 14)] = {"kind":"tree", "rotation":0}
	objects[Vector2i(14, 16)] = {"kind":"torch", "rotation":0}
	objects[Vector2i(21, 16)] = {"kind":"torch", "rotation":0}
	objects[Vector2i(16, 17)] = {"kind":"bench", "rotation":0}

func inside(p: Vector2i) -> bool:
	return p.x >= 0 and p.y >= 0 and p.x < SIZE.x and p.y < SIZE.y

func border(p: Vector2i) -> bool:
	return p.x == 0 or p.y == 0 or p.x == SIZE.x - 1 or p.y == SIZE.y - 1

func cell(pos: Vector2) -> Vector2i:
	return Vector2i(floori(pos.x / TILE), floori(pos.y / TILE))

func reachable(p: Vector2i) -> bool:
	return player.distance_to(Vector2(p) * TILE + Vector2.ONE * TILE / 2.0) <= TILE * 2.25

func blocked(p: Vector2i) -> bool:
	if not inside(p) or walls.has(p) or water.has(p):
		return true
	if objects.has(p):
		return bool(definitions.get(objects[p].kind, {"solid":true}).solid)
	return false

func can_stand(pos: Vector2) -> bool:
	for offset in [Vector2(-7,-5), Vector2(7,-5), Vector2(-7,5), Vector2(7,5)]:
		if blocked(cell(pos + offset)):
			return false
	return true

func walk(delta: Vector2) -> void:
	# Axis separation allows sliding along corners.
	var next := player + Vector2(delta.x, 0)
	if can_stand(next):
		player = next
	next = player + Vector2(0, delta.y)
	if can_stand(next):
		player = next

func mine(p: Vector2i) -> String:
	if not reachable(p): return "가까이 다가가 주세요"
	if not walls.has(p): return "돌벽을 선택해 주세요"
	if border(p): return "시제품의 바깥 경계예요"
	hits[p] = int(hits.get(p, 0)) + 1
	if hits[p] < 3: return "돌벽 %d / 3" % hits[p]
	walls.erase(p)
	hits.erase(p)
	stone += 2
	mined += 1
	return "돌 +2 · 새로운 공간을 발견했어요"

func can_place(p: Vector2i, kind: String) -> bool:
	return definitions.has(kind) and inside(p) and reachable(p) and not blocked(p) and not objects.has(p) and cell(player) != p and stone >= int(definitions[kind].cost)

func place(p: Vector2i, kind: String, rotation: int) -> String:
	if not can_place(p, kind): return "빈칸·거리·재료를 확인해 주세요"
	stone -= int(definitions[kind].cost)
	objects[p] = {"kind":kind, "rotation":rotation % 4}
	placed += 1
	return "%s 배치 완료" % definitions[kind].name

func retrieve(p: Vector2i) -> String:
	if not reachable(p): return "가까이 다가가 주세요"
	if not objects.has(p) or objects[p].kind == "tree": return "회수할 가구가 없어요"
	stone += int(definitions[objects[p].kind].cost)
	objects.erase(p)
	return "회수 완료 · 재료를 돌려받았어요"

func snapshot() -> Dictionary:
	var wall_list: Array = []
	var object_list: Array = []
	for p in walls: wall_list.append([p.x, p.y])
	for p in objects: object_list.append([p.x, p.y, objects[p].kind, objects[p].rotation])
	return {"version":SAVE_VERSION, "walls":wall_list, "objects":object_list, "player":[player.x, player.y], "stone":stone, "mined":mined, "placed":placed}

func restore(data: Variant) -> bool:
	# Validate a candidate first; malformed saves never partially replace the world.
	if not data is Dictionary: return false
	if data.get("version") != SAVE_VERSION: return false
	if not data.get("walls") is Array or not data.get("objects") is Array: return false
	if not data.get("player") is Array or data.player.size() != 2: return false
	for v in data.player:
		if not numeric(v): return false
	for key in ["stone", "mined", "placed"]:
		if not numeric(data.get(key)) or data[key] < 0 or data[key] > 1000000: return false
	var candidate = get_script().new()
	candidate.walls.clear()
	candidate.objects.clear()
	for entry in data.walls:
		if not valid_cell_entry(entry, 2): return false
		var p := Vector2i(entry[0], entry[1])
		if water.has(p): return false
		candidate.walls[p] = true
	for y in range(SIZE.y):
		for x in range(SIZE.x):
			var p := Vector2i(x,y)
			if border(p) and not candidate.walls.has(p): return false
	for entry in data.objects:
		if not valid_cell_entry(entry, 4): return false
		if not entry[2] is String or (entry[2] != "tree" and not definitions.has(entry[2])): return false
		if not numeric(entry[3]) or entry[3] < 0 or entry[3] > 3 or entry[3] != int(entry[3]): return false
		var p := Vector2i(entry[0], entry[1])
		if candidate.blocked(p) or candidate.objects.has(p): return false
		candidate.objects[p] = {"kind":entry[2], "rotation":int(entry[3])}
	candidate.player = Vector2(data.player[0], data.player[1])
	if not candidate.can_stand(candidate.player): return false
	walls = candidate.walls
	objects = candidate.objects
	player = candidate.player
	stone = int(data.stone)
	mined = int(data.mined)
	placed = int(data.placed)
	hits.clear()
	return true

func numeric(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

func valid_cell_entry(entry: Variant, length: int) -> bool:
	if not entry is Array or entry.size() != length: return false
	for i in range(2):
		if not numeric(entry[i]) or entry[i] != int(entry[i]): return false
	return inside(Vector2i(entry[0], entry[1]))
