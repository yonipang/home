extends Node2D
## 마을 (등불나무와 빛의 원). 그림은 모두 코드로 그린다 — 아트가 정해지면 스프라이트로 바꾼다.
## 플레이어·털뭉치 이동과 탭 대상 찾기도 여기서 한다.

signal arrived(target_id: String)
signal blocked_by_border

const FONT := preload("res://assets/fonts/GowunDodum-Regular.ttf")

const C_DARK := Color(0.055, 0.05, 0.043)
const C_LIGHT_OUT := Color(0.23, 0.2, 0.15)
const C_LIGHT_MID := Color(0.29, 0.25, 0.18)
const C_LIGHT_IN := Color(0.36, 0.31, 0.22)
const C_AMBER := Color(0.914, 0.706, 0.353)
const C_WOOD := Color(0.42, 0.29, 0.17)
const C_WOOD_TOP := Color(0.54, 0.37, 0.21)
const C_PAPER := Color(0.95, 0.94, 0.92)
const C_MUTED := Color(0.79, 0.77, 0.73)
const C_GREY := Color(0.54, 0.53, 0.5)

const PLAYER_SPEED := 300.0
const INTERACT_RANGE := 90.0
const TAP_RADIUS := 80.0

## 장소와 이웃. 위치는 나무(0,0) 기준.
const SPOTS := {
	"home": {"pos": Vector2(-250, -300), "kind": "object"},
	"hearth": {"pos": Vector2(-110, -190), "kind": "object"},
	"halmeoni": {"pos": Vector2(230, -250), "kind": "npc"},
	"moru": {"pos": Vector2(200, 300), "kind": "npc"},
	"gussi": {"pos": Vector2(-170, 250), "kind": "npc"},
}
const NPC_COLORS := {"halmeoni": Color(0.78, 0.55, 0.42), "moru": Color(0.55, 0.66, 0.5), "gussi": Color(0.5, 0.58, 0.7)}

var player_pos := Vector2(0, 150)
var furball_pos := Vector2(-40, 170)
var move_input := Vector2.ZERO
var walk_target_id := ""
var _border_warned_at := -10.0
var _time := 0.0


func light_radius() -> float:
	var base := 600.0 - float(GameState.day - 1) * 6.0
	return maxf(430.0, base) * (0.96 + 0.04 * GameState.clock.breath())


func spot_pos(id: String) -> Vector2:
	if id == "furball":
		return furball_pos
	return SPOTS[id].pos


## 화면 좌표 → 가장 가까운 탭 대상 id (없으면 "")
func target_at(world_pos: Vector2) -> String:
	var best := ""
	var best_d := TAP_RADIUS
	for id in SPOTS.keys() + ["furball"]:
		var d := world_pos.distance_to(spot_pos(id))
		if d < best_d:
			best_d = d
			best = id
	return best


func walk_to(id: String) -> void:
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
		var to := spot_pos(walk_target_id) - player_pos
		if to.length() <= INTERACT_RANGE * 0.8:
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


func _draw() -> void:
	var r := light_radius()
	var b := GameState.clock.breath()
	draw_rect(Rect2(-3000, -3000, 6000, 6000), C_DARK)
	draw_circle(Vector2.ZERO, r, C_DARK.lerp(C_LIGHT_OUT, b))
	draw_circle(Vector2.ZERO, r * 0.78, C_DARK.lerp(C_LIGHT_MID, b))
	draw_circle(Vector2.ZERO, r * 0.5, C_DARK.lerp(C_LIGHT_IN, b))

	# 빛 밖 빈집 (이전의 나)
	_draw_house(Vector2(560, -700), "빈집", true)

	# 경계 등불
	for i in 12:
		var a := TAU * float(i) / 12.0 + 0.2
		draw_circle(Vector2.from_angle(a) * (r - 8.0), 6.0, C_AMBER * Color(1, 1, 1, 0.55 + 0.45 * b))

	# 연못
	var pond: PackedVector2Array = []
	for i in 24:
		var a := TAU * float(i) / 24.0
		pond.append(Vector2(-280, 300) + Vector2(cos(a) * 95.0, sin(a) * 52.0))
	draw_colored_polygon(pond, Color(0.16, 0.27, 0.32))
	_label(Vector2(-280, 380), "연못")

	# 할머니 밭
	for i in 4:
		draw_rect(Rect2(170, -210 + i * 22, 150, 8), Color(0.36, 0.42, 0.17))
	draw_circle(Vector2(300, -186), 16, Color(0.85, 0.54, 0.19))
	_label(Vector2(245, -100), "할머니 밭")

	_draw_house(Vector2(-250, -300), "내 집", false)
	_draw_house(Vector2(260, 360), "모루네", false)

	# 화덕
	draw_circle(Vector2(-110, -190), 26, Color(0.3, 0.27, 0.24))
	var ember := 0.5 + 0.5 * float(GameState.happiness.times_done("cook") > 0)
	draw_circle(Vector2(-110, -190), 12, Color(0.85, 0.42, 0.18) * Color(1, 1, 1, 0.4 + 0.6 * ember))
	_label(Vector2(-110, -140), "화덕")

	_draw_tree(b)

	for id in ["halmeoni", "moru", "gussi"]:
		_draw_npc(id)

	if walk_target_id != "":
		_draw_ring(spot_pos(walk_target_id), 46.0)

	_draw_furball()
	draw_circle(player_pos, 24, C_PAPER)
	draw_arc(player_pos, 24, 0, TAU, 32, C_AMBER, 4.0)


func _draw_tree(b: float) -> void:
	draw_circle(Vector2.ZERO, 120, Color(0.55, 0.43, 0.24) * Color(1, 1, 1, 0.35 + 0.3 * b))
	draw_circle(Vector2.ZERO, 74, Color(0.55, 0.48, 0.32))
	draw_arc(Vector2.ZERO, 74, 0, TAU, 48, C_AMBER, 3.0)
	# 꼭대기 열매 = 행복 신호
	var h := GameState.happiness.ratio()
	var fruits := [Vector2(-42, -108), Vector2(0, -128), Vector2(42, -108)]
	for i in 3:
		var lit := h >= (float(i) + 1.0) / 3.0 - 0.001
		var c: Color = C_AMBER if lit else Color(0.43, 0.39, 0.31)
		if lit and i == 2:
			c = Color(1.0, 0.85, 0.55)
		draw_circle(fruits[i], 11.0 if lit else 8.0, c)


func _draw_house(pos: Vector2, label: String, dim: bool) -> void:
	var w := 120.0
	var h := 90.0
	var body := Color(0.18, 0.16, 0.14) if dim else Color(0.2, 0.18, 0.15)
	var edge := Color(0.3, 0.28, 0.25) if dim else C_MUTED
	draw_rect(Rect2(pos - Vector2(w, h) / 2, Vector2(w, h)), body)
	draw_rect(Rect2(pos - Vector2(w, h) / 2, Vector2(w, h)), edge, false, 3.0)
	if not dim:
		draw_rect(Rect2(pos - Vector2(w, h) / 2, Vector2(w, 26)), C_WOOD_TOP)
	_label(pos + Vector2(0, h / 2 + 30), label, Color(0.4, 0.38, 0.34) if dim else C_MUTED)


func _draw_npc(id: String) -> void:
	var p: Vector2 = SPOTS[id].pos
	draw_circle(p, 26, NPC_COLORS[id])
	draw_circle(p + Vector2(-8, -4), 3, C_DARK)
	draw_circle(p + Vector2(8, -4), 3, C_DARK)
	# 이야기해 보기 전에는 이름을 모른다 (망각 후에도 마찬가지)
	var known := GameState.relationships.points(id) > 0
	_label(p + Vector2(0, -40), Content.NPCS[id].name if known else "?", C_PAPER)


func _draw_furball() -> void:
	var s := 0.55 + 0.45 * GameState.furball_light / 100.0
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


func _label(pos: Vector2, text: String, color := C_MUTED) -> void:
	draw_string(FONT, pos - Vector2(150, 0), text, HORIZONTAL_ALIGNMENT_CENTER, 300, 24, color)
