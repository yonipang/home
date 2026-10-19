extends Node2D
## 마을 (등불나무와 빛의 원). 그림은 모두 코드로 그린다 — 아트가 정해지면 스프라이트로 바꾼다.
## 플레이어·털뭉치 이동과 탭 대상 찾기도 여기서 한다.

signal arrived(target_id: String)
signal blocked_by_border
signal blocked_by_dark

const FONT := preload("res://assets/fonts/GowunDodum-Regular.ttf")

const C_DARK := Color(0.055, 0.05, 0.043)
const C_LIGHT_OUT := Color(0.23, 0.2, 0.15)
const C_LIGHT_MID := Color(0.29, 0.25, 0.18)
const C_LIGHT_IN := Color(0.36, 0.31, 0.22)
const C_AMBER := Color(0.914, 0.706, 0.353)
const C_WOOD_TOP := Color(0.54, 0.37, 0.21)
const C_PAPER := Color(0.95, 0.94, 0.92)
const C_MUTED := Color(0.79, 0.77, 0.73)
const C_DIM := Color(0.4, 0.38, 0.34)

const PLAYER_SPEED := 300.0
const INTERACT_RANGE := 90.0
const TAP_RADIUS := 80.0

## 고정된 장소와 이웃. 위치는 나무(0,0) 기준.
const SPOTS := {
	"tree": Vector2(0, 0),
	"home": Vector2(-250, -300),
	"hearth": Vector2(-110, -190),
	"field": Vector2(300, -170),
	"halmeoni": Vector2(170, -265),
	"moru": Vector2(185, 270),
	"gussi": Vector2(-160, 235),
	"pond": Vector2(-300, 320),
}
const MORU_HOUSE := Vector2(300, 385)
const NPC_IDS := ["halmeoni", "moru", "gussi"]
const NPC_COLORS := {"halmeoni": Color(0.78, 0.55, 0.42), "moru": Color(0.55, 0.66, 0.5), "gussi": Color(0.5, 0.58, 0.7)}

var player_pos := Vector2(0, 150)
var furball_pos := Vector2(-40, 170)
var move_input := Vector2.ZERO
var walk_target_id := ""
var _border_warned_at := -10.0
var _time := 0.0


func world() -> WorldState:
	return GameState.world


func light_radius() -> float:
	return world().radius * (0.97 + 0.03 * GameState.clock.breath())


func spot_pos(id: String) -> Vector2:
	if id == "furball":
		return furball_pos
	if SPOTS.has(id):
		return SPOTS[id]
	if id.begins_with("post_"):
		return world().post_pos(int(id.trim_prefix("post_")))
	var n := world().find_node(id)
	return world().node_pos(n) if not n.is_empty() else Vector2.INF


## 지금 탭할 수 있는 대상 id 목록
func target_ids() -> Array:
	var ids: Array = SPOTS.keys() + ["furball"]
	for i in WorldState.POSTS:
		ids.append("post_%d" % i)
	for n in world().nodes:
		if not n.taken:
			ids.append(n.id)
	return ids


## 월드 좌표 → 가장 가까운 탭 대상 id (없으면 "")
func target_at(world_pos: Vector2) -> String:
	var best := ""
	var best_d := TAP_RADIUS
	for id in target_ids():
		var d := world_pos.distance_to(spot_pos(id))
		if id == "tree":
			d = maxf(0.0, d - 50.0)  # 나무는 크다
		if d < best_d:
			best_d = d
			best = id
	return best


func walk_to(id: String) -> void:
	if id != "furball" and not world().reachable(spot_pos(id)):
		blocked_by_dark.emit()
		return
	walk_target_id = id
	if player_pos.distance_to(spot_pos(id)) <= INTERACT_RANGE:
		_arrive()


func cancel_walk() -> void:
	walk_target_id = ""


func _arrive() -> void:
	var id := walk_target_id
	walk_target_id = ""
	arrived.emit(id)


func step(delta: float) -> void:
	_time += delta
	var dir := move_input
	if dir.length() > 0.05:
		walk_target_id = ""
	elif walk_target_id != "":
		var p := spot_pos(walk_target_id)
		if p == Vector2.INF:
			walk_target_id = ""
		else:
			var reach := INTERACT_RANGE * (1.3 if walk_target_id == "tree" else 0.8)
			var to := p - player_pos
			if to.length() <= reach:
				_arrive()
				dir = Vector2.ZERO
			else:
				dir = to.normalized()
	player_pos += dir.limit_length(1.0) * PLAYER_SPEED * delta

	var limit := light_radius() + 20.0
	if player_pos.length() > limit:
		player_pos = player_pos.normalized() * limit
		if _time - _border_warned_at > 4.0:
			_border_warned_at = _time
			blocked_by_border.emit()

	var follow := player_pos + Vector2(-46, 26)
	furball_pos = furball_pos.lerp(follow, clampf(delta * 3.5, 0.0, 1.0))
	queue_redraw()


# ── 그리기 ────────────────────────────────────────

func _lit(p: Vector2) -> bool:
	return world().reachable(p)


func _draw() -> void:
	var w := world()
	var r := light_radius()
	var b := GameState.clock.breath()
	draw_rect(Rect2(-3000, -3000, 6000, 6000), C_DARK)
	draw_circle(Vector2.ZERO, r, C_DARK.lerp(C_LIGHT_OUT, b))
	draw_circle(Vector2.ZERO, r * 0.78, C_DARK.lerp(C_LIGHT_MID, b))
	draw_circle(Vector2.ZERO, r * 0.5, C_DARK.lerp(C_LIGHT_IN, b))
	# 처음 빛의 원 (줄어든 만큼 보이게)
	if w.radius < WorldState.START_RADIUS - 1.0:
		_dashed_circle(Vector2.ZERO, WorldState.START_RADIUS, Color(0.3, 0.28, 0.25, 0.6))

	_draw_house(Vector2(620, -760), "빈집", false, 1.0)

	# 버섯숲 표시
	_label(Vector2.from_angle(WorldState.MUSHROOM_ANGLE) * r * 0.72 + Vector2(0, 70), "버섯숲", Color(0.45, 0.6, 0.62))

	# 연못
	var pond: PackedVector2Array = []
	for i in 24:
		var a := TAU * float(i) / 24.0
		pond.append(SPOTS.pond + Vector2(cos(a) * 95.0, sin(a) * 52.0))
	draw_colored_polygon(pond, Color(0.16, 0.27, 0.32) if _lit(SPOTS.pond) else Color(0.1, 0.13, 0.14))
	_label(SPOTS.pond + Vector2(0, 85), "연못", C_MUTED if _lit(SPOTS.pond) else C_DIM)

	_draw_field()
	_draw_house(SPOTS.home, "내 집", _lit(SPOTS.home), 1.0)
	_draw_house(MORU_HOUSE, "모루네", _lit(MORU_HOUSE), float(w.house_wood) / WorldState.HOUSE_WOOD)

	# 화덕
	draw_circle(SPOTS.hearth, 26, Color(0.3, 0.27, 0.24))
	var ember := 1.0 if GameState.did_today("cook") else 0.4
	draw_circle(SPOTS.hearth, 12, Color(0.85, 0.42, 0.18, ember))
	_label(SPOTS.hearth + Vector2(0, 50), "화덕")

	# 채집물
	for n in w.nodes:
		if n.taken:
			continue
		var p := w.node_pos(n)
		if n.kind == "wood":
			draw_line(p + Vector2(-14, 6), p + Vector2(14, -6), C_WOOD_TOP, 7.0)
			draw_line(p + Vector2(-10, -8), p + Vector2(12, 8), Color(0.45, 0.31, 0.18), 6.0)
		else:
			draw_circle(p + Vector2(0, 6), 5, Color(0.8, 0.8, 0.75))
			draw_circle(p, 11, Color(0.45, 0.75, 0.82, 0.6 + 0.4 * sin(_time * 2.0 + p.x)))

	# 경계 등불
	for i in WorldState.POSTS:
		var p := w.post_pos(i)
		draw_rect(Rect2(p + Vector2(-4, -6), Vector2(8, 26)), Color(0.35, 0.3, 0.24))
		if w.lit_posts[i]:
			draw_circle(p + Vector2(0, -12), 20, Color(C_AMBER, 0.25))
			draw_circle(p + Vector2(0, -12), 9, C_AMBER)
		else:
			draw_circle(p + Vector2(0, -12), 8, Color(0.3, 0.29, 0.27))
			draw_arc(p + Vector2(0, -12), 8, 0, TAU, 16, Color(0.5, 0.48, 0.44), 2.0)

	_draw_tree(b)

	for id in NPC_IDS:
		_draw_npc(id)

	if walk_target_id != "":
		var tp := spot_pos(walk_target_id)
		if tp != Vector2.INF:
			_draw_ring(tp, 46.0)

	_draw_furball()
	draw_circle(player_pos, 24, C_PAPER)
	draw_arc(player_pos, 24, 0, TAU, 32, C_AMBER, 4.0)


func _draw_field() -> void:
	var w := world()
	var lit := _lit(SPOTS.field)
	var base := SPOTS.field + Vector2(-80, -40)
	for i in 4:
		draw_rect(Rect2(base + Vector2(0, i * 22), Vector2(150, 8)), Color(0.36, 0.42, 0.17) if lit else Color(0.2, 0.22, 0.14))
	var size := 10.0 + 7.0 * w.pumpkin_water
	if w.pumpkin_ready():
		size = 42.0
	var pc := Color(0.85, 0.54, 0.19) if lit else Color(0.4, 0.3, 0.18)
	if w.pumpkin_water == 0 and w.pumpkins_harvested > 0:
		draw_circle(SPOTS.field + Vector2(10, 0), 6, Color(0.45, 0.6, 0.25))
	else:
		draw_circle(SPOTS.field + Vector2(10, 0), size, pc)
	if w.halmeoni_asked and not w.pumpkin_watered_today and not w.pumpkin_ready():
		_label(SPOTS.field + Vector2(10, -size - 14), "물", Color(0.55, 0.75, 0.85))
	_label(SPOTS.field + Vector2(0, 70), "할머니 밭", C_MUTED if lit else C_DIM)


func _draw_tree(b: float) -> void:
	draw_circle(Vector2.ZERO, 120, Color(0.55, 0.43, 0.24, 0.35 + 0.3 * b))
	draw_circle(Vector2.ZERO, 74, Color(0.55, 0.48, 0.32))
	draw_arc(Vector2.ZERO, 74, 0, TAU, 48, C_AMBER, 3.0)
	# 뿌리의 빛 방울 (남은 만큼)
	for i in world().drops_left():
		var a := PI * 0.35 + i * 0.28
		draw_circle(Vector2.from_angle(a) * 84.0, 6.0, Color(1.0, 0.85, 0.55, 0.6 + 0.4 * sin(_time * 3.0 + i)))
	# 꼭대기 열매 = 행복 신호
	var h := GameState.happiness.ratio()
	var fruits := [Vector2(-42, -108), Vector2(0, -128), Vector2(42, -108)]
	for i in 3:
		var lit := h >= (float(i) + 1.0) / 3.0 - 0.001
		var c: Color = C_AMBER if lit else Color(0.43, 0.39, 0.31)
		if lit and i == 2:
			c = Color(1.0, 0.85, 0.55)
		draw_circle(fruits[i], 11.0 if lit else 8.0, c)


## progress: 0~1 (지어진 정도). 1이면 이층.
func _draw_house(pos: Vector2, label: String, lit: bool, progress: float) -> void:
	var w := 120.0
	var h := 90.0
	var edge := C_MUTED if lit else Color(0.3, 0.28, 0.25)
	var body := Color(0.2, 0.18, 0.15) if lit else Color(0.13, 0.12, 0.11)
	var rect := Rect2(pos - Vector2(w, h) / 2, Vector2(w, h))
	if progress < 1.0:
		_dashed_rect(rect, edge)
		var built := h * progress
		draw_rect(Rect2(rect.position + Vector2(0, h - built), Vector2(w, built)), body)
		_label(pos + Vector2(0, h / 2 + 30), "%s (%d%%)" % [label, int(progress * 100)], edge)
		return
	draw_rect(rect, body)
	draw_rect(rect, edge, false, 3.0)
	if lit:
		draw_rect(Rect2(rect.position, Vector2(w, 26)), C_WOOD_TOP)
	if label == "모루네":
		var up := Rect2(rect.position + Vector2(18, -60), Vector2(w - 36, 60))
		draw_rect(up, body)
		draw_rect(up, edge, false, 3.0)
		draw_rect(Rect2(up.position + Vector2(30, 18), Vector2(24, 20)), Color(C_AMBER, 0.7 if lit else 0.2))
	_label(pos + Vector2(0, h / 2 + 30), label, edge)


func _draw_npc(id: String) -> void:
	var p: Vector2 = SPOTS[id]
	var lit := _lit(p)
	draw_circle(p, 26, NPC_COLORS[id] if lit else NPC_COLORS[id].darkened(0.6))
	draw_circle(p + Vector2(-8, -4), 3, C_DARK)
	draw_circle(p + Vector2(8, -4), 3, C_DARK)
	# 이야기해 보기 전에는 이름을 모른다 (망각 후에도 마찬가지)
	var known := GameState.relationships.points(id) > 0
	_label(p + Vector2(0, -40), Content.NPCS[id].name if known else "?", C_PAPER if lit else C_DIM)


func _draw_furball() -> void:
	var s := 0.45 + 0.55 * GameState.furball_light / 100.0
	var bob := sin(_time * 3.0) * 2.0
	var p := furball_pos + Vector2(0, bob)
	draw_circle(p, 22.0 * s, Color(0.6, 0.59, 0.56))
	draw_circle(p + Vector2(-7, -3) * s, 3.2, C_DARK)
	draw_circle(p + Vector2(7, -3) * s, 3.2, C_DARK)
	if GameState.happiness.ratio() > 0.66:
		draw_circle(p + Vector2(-12, 4) * s, 3.5, Color(0.9, 0.55, 0.5, 0.7))
		draw_circle(p + Vector2(12, 4) * s, 3.5, Color(0.9, 0.55, 0.5, 0.7))


func _draw_ring(p: Vector2, radius: float) -> void:
	var n := 16
	for i in n:
		if i % 2 == 0:
			draw_arc(p, radius, TAU * i / n + _time, TAU * (i + 1) / n + _time, 6, C_PAPER, 2.5)


func _dashed_circle(c: Vector2, radius: float, color: Color) -> void:
	var n := 96
	for i in n:
		if i % 2 == 0:
			draw_arc(c, radius, TAU * i / n, TAU * (i + 1) / n, 4, color, 2.0)


func _dashed_rect(r: Rect2, color: Color) -> void:
	var pts := [r.position, r.position + Vector2(r.size.x, 0), r.end, r.position + Vector2(0, r.size.y), r.position]
	for k in 4:
		var a: Vector2 = pts[k]
		var bb: Vector2 = pts[k + 1]
		var steps := int(a.distance_to(bb) / 12.0)
		for i in steps:
			if i % 2 == 0:
				draw_line(a.lerp(bb, float(i) / steps), a.lerp(bb, float(i + 1) / steps), color, 2.5)


func _label(pos: Vector2, text: String, color := C_MUTED) -> void:
	draw_string(FONT, pos - Vector2(150, 0), text, HORIZONTAL_ALIGNMENT_CENTER, 300, 24, color)
