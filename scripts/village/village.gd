extends Node2D
## 마을 (등불나무와 빛의 원). 그림은 모두 코드로 그린다 — 아트가 정해지면 스프라이트로 바꾼다.
## 플레이어·털뭉치 이동과 탭 대상 찾기도 여기서 한다.

signal arrived(target_id: String)
signal blocked_by_border
signal blocked_by_dark

const FONT := preload("res://assets/fonts/GowunDodum-Regular.ttf")
const FURBALL_TEX := preload("res://assets/art/characters/furball.png")
## 털뭉치 그림의 화면 높이 (빛이 가득할 때)
const FURBALL_HEIGHT := 66.0

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
var _furball_facing := 1.0
## 말랑이: 빛 밖 어둠에 사는 것. { pos, home, phase }
var malangs: Array = []
var malang_touch := false


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for hid in Content.HOUSES:
		var hp: Vector2 = Content.HOUSES[hid].pos
		for i in 3:
			var home := hp + Vector2.from_angle(rng.randf_range(0, TAU)) * rng.randf_range(160, 340)
			malangs.append({"pos": home, "home": home, "phase": rng.randf_range(0, TAU)})
	for i in 6:
		var home := Vector2.from_angle(TAU * i / 6.0 + 0.5) * rng.randf_range(800, 950)
		malangs.append({"pos": home, "home": home, "phase": rng.randf_range(0, TAU)})


func outside() -> bool:
	return player_pos.length() > world().radius


## 손등불이 비추는 반경 (빛 밖에서만 의미가 있다)
func view_radius() -> float:
	return 110.0 + 170.0 * world().lantern_ratio()


func world() -> WorldState:
	return GameState.world


func light_radius() -> float:
	return world().radius * (0.97 + 0.03 * GameState.clock.breath())


func spot_pos(id: String) -> Vector2:
	if id == "furball":
		return furball_pos
	if SPOTS.has(id):
		return SPOTS[id]
	if Content.HOUSES.has(id):
		return Content.HOUSES[id].pos
	if id.begins_with("post_"):
		return world().post_pos(int(id.trim_prefix("post_")))
	var n := world().find_node(id)
	return world().node_pos(n) if not n.is_empty() else Vector2.INF


## 지금 탭할 수 있는 대상 id 목록
func target_ids() -> Array:
	var ids: Array = SPOTS.keys() + ["furball"] + Content.HOUSES.keys()
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
		if id == "tree" or Content.HOUSES.has(id):
			d = maxf(0.0, d - 50.0)  # 나무와 집은 크다
		if d < best_d:
			best_d = d
			best = id
	return best


func walk_to(id: String) -> void:
	# 빛 밖(어둠에 먹힌 곳 포함)은 손등불이 있어야 갈 수 있다
	if id != "furball" and not world().reachable(spot_pos(id)) and not world().lantern_on():
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
			var big := walk_target_id == "tree" or Content.HOUSES.has(walk_target_id)
			var reach := INTERACT_RANGE * (1.3 if big else 0.8)
			var to := p - player_pos
			if to.length() <= reach:
				_arrive()
				dir = Vector2.ZERO
			else:
				dir = to.normalized()
	var speed := PLAYER_SPEED * (0.65 if outside() else 1.0)  # 어둠 속에서는 조심조심
	player_pos += dir.limit_length(1.0) * speed * delta

	var limit := 1900.0 if world().lantern_on() else light_radius() + 20.0
	if player_pos.length() > limit:
		player_pos = player_pos.normalized() * limit
		if not world().lantern_on() and _time - _border_warned_at > 4.0:
			_border_warned_at = _time
			blocked_by_border.emit()

	# 털뭉치는 빛 밖으로 따라 나오지 않는다 (어둠에 들어가면 흐려지니까)
	var follow := player_pos + Vector2(-46, 26)
	var edge := world().radius - 50.0
	if follow.length() > edge:
		follow = follow.normalized() * edge
	var before := furball_pos
	furball_pos = furball_pos.lerp(follow, clampf(delta * 3.5, 0.0, 1.0))
	var dx := furball_pos.x - before.x
	if absf(dx) > 0.6:
		_furball_facing = signf(dx)
	_step_malangs(delta)
	queue_redraw()


func _step_malangs(delta: float) -> void:
	malang_touch = false
	var out := outside()
	var weak := world().lantern_ratio() < 0.5
	for m in malangs:
		var to_player: Vector2 = player_pos - m.pos
		var d := to_player.length()
		var wander: Vector2 = m.home + Vector2(cos(_time * 0.4 + m.phase), sin(_time * 0.3 + m.phase)) * 60.0
		var target := wander
		if out and d < 380.0:
			if weak:
				target = player_pos  # 약한 빛과 온기에 몰려든다
			elif d < 230.0:
				target = m.pos - to_player.normalized() * 100.0  # 강한 빛은 피한다
		var spd := 85.0 if (out and weak and d < 380.0) else 45.0
		m.pos = m.pos.move_toward(target, spd * delta)
		# 빛의 원 안으로는 들어오지 못한다
		if m.pos.length() < world().radius + 30.0:
			m.pos = m.pos.normalized() * (world().radius + 30.0)
		if out and m.pos.distance_to(player_pos) < 42.0:
			malang_touch = true


# ── 그리기 ────────────────────────────────────────

func _lit(p: Vector2) -> bool:
	return world().reachable(p)


func _draw() -> void:
	var w := world()
	var r := light_radius()
	var b := GameState.clock.breath()
	draw_rect(Rect2(-3000, -3000, 6000, 6000), C_DARK)
	# 손등불 (빛 밖에서만)
	var out := outside()
	var vr := view_radius()
	if out and world().lantern_on():
		draw_circle(player_pos, vr, Color(0.2, 0.17, 0.12))
		draw_circle(player_pos, vr * 0.6, Color(0.27, 0.22, 0.15))
	draw_circle(Vector2.ZERO, r, C_DARK.lerp(C_LIGHT_OUT, b))
	draw_circle(Vector2.ZERO, r * 0.78, C_DARK.lerp(C_LIGHT_MID, b))
	draw_circle(Vector2.ZERO, r * 0.5, C_DARK.lerp(C_LIGHT_IN, b))
	# 처음 빛의 원 (줄어든 만큼 보이게)
	if w.radius < WorldState.START_RADIUS - 1.0:
		_dashed_circle(Vector2.ZERO, WorldState.START_RADIUS, Color(0.3, 0.28, 0.25, 0.6))


	# 빛 밖 빈집 — 등불이 비출 때만 보인다
	for hid in Content.HOUSES:
		var hp: Vector2 = Content.HOUSES[hid].pos
		if out and world().lantern_on() and hp.distance_to(player_pos) < vr + 80.0:
			_draw_empty_house(hid, hp)

	# 말랑이 — 등불 가장자리에서 어렴풋이
	if out:
		for m in malangs:
			var md: float = m.pos.distance_to(player_pos)
			if md < vr * 1.4:
				var a := clampf(1.0 - md / (vr * 1.4), 0.0, 1.0)
				var wob := sin(_time * 3.0 + m.phase) * 4.0
				draw_circle(m.pos, 26.0 + wob, Color(0.24, 0.38, 0.24, 0.85 * a))
				draw_circle(m.pos + Vector2(14, 8), 15.0 - wob * 0.5, Color(0.24, 0.38, 0.24, 0.7 * a))

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


func _draw_empty_house(hid: String, pos: Vector2) -> void:
	var w := 130.0
	var h := 96.0
	var rect := Rect2(pos - Vector2(w, h) / 2, Vector2(w, h))
	draw_rect(rect, Color(0.16, 0.15, 0.13))
	draw_rect(rect, Color(0.5, 0.47, 0.42), false, 3.0)
	# 창문은 나무 쪽으로
	var win := pos + (-pos).normalized() * 40.0
	draw_rect(Rect2(win - Vector2(14, 12), Vector2(28, 24)), Color(0.3, 0.27, 0.22))
	if hid == "house_west":
		draw_rect(Rect2(pos + Vector2(-14, 8), Vector2(28, 40)), Color(0.55, 0.22, 0.17))
	elif hid == "house_mid":
		for i in 4:
			draw_circle(pos + Vector2(-40 + i * 22, 52), 4, Color(0.6, 0.65, 0.68, 0.6))
	var left := GameState._house_spots(hid).size()
	var name: String = Content.HOUSES[hid].name
	_label(pos + Vector2(0, h / 2 + 30), name + (" · 살필 곳 %d" % left if left > 0 else ""), C_MUTED)


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
	var light := GameState.furball_light / 100.0
	var s := 0.45 + 0.55 * light
	var bob := sin(_time * 3.0) * 2.0
	var p := furball_pos + Vector2(0, bob)
	var h := FURBALL_HEIGHT * s
	var w := h * FURBALL_TEX.get_width() / FURBALL_TEX.get_height()
	# 발밑 그림자와, 어둠에 묻히지 않게 하는 은은한 빛
	var glow := 0.16 + 0.14 * GameState.happiness.ratio()
	for i in 4:
		draw_circle(p + Vector2(0, -h * 0.1), h * (0.7 - i * 0.1), Color(C_AMBER, glow * 0.35))
	_draw_ellipse(p + Vector2(0, h * 0.42), Vector2(w * 0.36, h * 0.09), Color(0, 0, 0, 0.28))
	# 빛을 많이 나눠 줄수록 털 끝이 투명해진다
	var tint := Color(1, 1, 1, 0.55 + 0.45 * light)
	draw_set_transform(p, 0.0, Vector2(_furball_facing, 1.0))
	draw_texture_rect(FURBALL_TEX, Rect2(Vector2(-w * 0.5, -h * 0.55), Vector2(w, h)), false, tint)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_ellipse(c: Vector2, r: Vector2, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	draw_colored_polygon(pts, col)


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
