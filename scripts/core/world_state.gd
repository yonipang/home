class_name WorldState
extends RefCounted
## 마을에 남는 것들: 주머니의 물건, 경계 등불, 빛의 원, 모루의 이층집, 할머니의 호박, 낚시.
## 망각해도 물건과 결과물은 남는다. 사라지는 건 이웃의 기억(부탁했다는 사실, 빌려준 낚싯대)뿐이다.

const START_RADIUS := 600.0
const MIN_RADIUS := 300.0
const POSTS := 6
const SHRINK_PER_DARK_POST := 3.0
const FORGET_SHRINK := 10.0
const DROPS_PER_DAY := 4
const HOUSE_WOOD := 9
const PUMPKIN_WATER := 4
const FISH_TRIES := 3
const WOOD_PER_DAY := 3
const MUSH_PER_DAY := 2

const FIELD_POS := Vector2(240, -200)
const POND_POS := Vector2(-280, 300)
const MORU_HOUSE_POS := Vector2(260, 360)
const HOME_POS := Vector2(-250, -300)
const MUSHROOM_ANGLE := PI * 0.82  ## 버섯숲은 서남쪽

const LANTERN_SECONDS := 30.0   ## 빛 방울 하나로 빛 밖에서 버티는 시간
const MALANG_DRAIN := 6.0       ## 말랑이에 닿으면 몇 배 더 빨리 닳는지
const SEARCH_COST := 4.0        ## 빈집에서 한 곳을 살피는 데 드는 등불

var radius := START_RADIUS
var items := {"wood": 0, "mushroom": 0, "drop": 0}
var lit_posts: Array = []
var drops_taken := 0

var moru_asked := false
var house_wood := 0

var halmeoni_asked := false
var pumpkin_water := 0
var pumpkin_watered_today := false
var pumpkins_harvested := 0

var rod_borrowed := false
var fish_tries := 0
var fish_caught_this_cycle := false
var fish_total := 0

## 오늘 생긴 채집물: { id, kind, angle, dist, taken }
var nodes: Array = []

## 손등불. 빛의 원 안에서는 닳지 않는다.
var lantern_fuel := 0.0
## 빈집에서 살핀 곳 (망각해도 남는다 — 이미 본 것은 공책에 적혀 있으니까)
var searched: Array = []


func _init() -> void:
	lit_posts = []
	for i in POSTS:
		lit_posts.append(false)


# ── 하루 시작·끝 ──────────────────────────────────

func new_day(cycle: int, day: int) -> void:
	drops_taken = 0
	fish_tries = 0
	pumpkin_watered_today = false
	var rng := RandomNumberGenerator.new()
	rng.seed = cycle * 1000 + day
	nodes = []
	for i in WOOD_PER_DAY:
		nodes.append({"id": "wood_%d" % i, "kind": "wood", "angle": rng.randf_range(0.0, TAU),
			"dist": rng.randf_range(0.66, 0.86), "taken": false})
	for i in MUSH_PER_DAY:
		nodes.append({"id": "mush_%d" % i, "kind": "mushroom", "angle": MUSHROOM_ANGLE + rng.randf_range(-0.35, 0.35),
			"dist": rng.randf_range(0.6, 0.82), "taken": false})


## 밤이 지나며 일어나는 일. {shrunk, wilted}
func end_night(forgot: bool) -> Dictionary:
	var dark := lit_posts.count(false)
	var before := radius
	radius -= dark * SHRINK_PER_DARK_POST
	if forgot:
		radius -= FORGET_SHRINK
	radius = maxf(MIN_RADIUS, radius)
	for i in POSTS:
		lit_posts[i] = false
	lantern_fuel = 0.0
	var wilted := false
	if halmeoni_asked and not pumpkin_watered_today and pumpkin_water > 0 and not pumpkin_ready():
		pumpkin_water -= 1
		wilted = true
	if forgot:
		moru_asked = false
		halmeoni_asked = false
		rod_borrowed = false
		fish_caught_this_cycle = false
	return {"shrunk": before - radius, "wilted": wilted}


# ── 빛의 원 ───────────────────────────────────────

func reachable(pos: Vector2) -> bool:
	return pos.length() <= radius - 10.0


func post_pos(i: int) -> Vector2:
	return Vector2.from_angle(TAU * i / POSTS + 0.3) * (radius - 34.0)


func take_drop() -> bool:
	if drops_taken >= DROPS_PER_DAY:
		return false
	drops_taken += 1
	items.drop += 1
	return true


func drops_left() -> int:
	return DROPS_PER_DAY - drops_taken


func light_post(i: int) -> bool:
	if lit_posts[i] or items.drop <= 0:
		return false
	items.drop -= 1
	lit_posts[i] = true
	return true


# ── 손등불과 빈집 ─────────────────────────────────

func light_lantern() -> bool:
	if items.drop <= 0:
		return false
	items.drop -= 1
	lantern_fuel = LANTERN_SECONDS
	return true


func lantern_on() -> bool:
	return lantern_fuel > 0.0


func lantern_ratio() -> float:
	return clampf(lantern_fuel / LANTERN_SECONDS, 0.0, 1.0)


## 빛 밖에서 등불이 닳는다. "ok" | "switched"(빛 방울을 갈아 끼움) | "out"(꺼짐)
func burn_lantern(delta: float, outside: bool, drained: bool) -> String:
	if not outside:
		return "ok"
	if lantern_fuel <= 0.0:
		return "unlit"  # 켜지 않은 등불은 꺼질 것도 없다 (쓰러지는 건 타다가 꺼질 때만)
	lantern_fuel -= delta * (1.0 + (MALANG_DRAIN if drained else 0.0))
	if lantern_fuel > 0.0:
		return "ok"
	if items.drop > 0:
		items.drop -= 1
		lantern_fuel = LANTERN_SECONDS
		return "switched"
	lantern_fuel = 0.0
	return "out"


## 빈집의 한 곳을 살핀다. 처음 살피면 true
func search(spot_id: String) -> bool:
	if searched.has(spot_id):
		return false
	searched.append(spot_id)
	lantern_fuel = maxf(1.0, lantern_fuel - SEARCH_COST) if lantern_fuel > 0.0 else 0.0
	return true


# ── 채집 ──────────────────────────────────────────

func node_pos(n: Dictionary) -> Vector2:
	return Vector2.from_angle(n.angle) * n.dist * radius


func find_node(id: String) -> Dictionary:
	for n in nodes:
		if n.id == id:
			return n
	return {}


## 주운 물건 종류를 돌려준다 (못 주우면 "")
func take_node(id: String) -> String:
	var n := find_node(id)
	if n.is_empty() or n.taken:
		return ""
	n.taken = true
	items[n.kind] += 1
	return n.kind


# ── 모루의 이층집 ─────────────────────────────────

func give_wood() -> int:
	var n := mini(items.wood, HOUSE_WOOD - house_wood)
	items.wood -= n
	house_wood += n
	return n


func house_complete() -> bool:
	return house_wood >= HOUSE_WOOD


# ── 할머니의 호박 ─────────────────────────────────

func water_pumpkin() -> bool:
	if pumpkin_watered_today or pumpkin_ready():
		return false
	pumpkin_watered_today = true
	pumpkin_water += 1
	return true


func pumpkin_ready() -> bool:
	return pumpkin_water >= PUMPKIN_WATER


func harvest_pumpkin() -> bool:
	if not pumpkin_ready():
		return false
	pumpkin_water = 0
	pumpkins_harvested += 1
	return true


# ── 낚시 ──────────────────────────────────────────

func can_fish() -> bool:
	return rod_borrowed and fish_tries < FISH_TRIES


## 이번 회차 첫 물고기면 true
func record_fish(success: bool) -> bool:
	fish_tries += 1
	if not success:
		return false
	fish_total += 1
	var first := not fish_caught_this_cycle
	fish_caught_this_cycle = true
	return first


# ── 저장 ──────────────────────────────────────────

const _FIELDS := ["radius", "items", "lit_posts", "drops_taken", "moru_asked", "house_wood", "halmeoni_asked",
	"pumpkin_water", "pumpkin_watered_today", "pumpkins_harvested", "rod_borrowed", "fish_tries",
	"fish_caught_this_cycle", "fish_total", "nodes", "lantern_fuel", "searched"]


func to_dict() -> Dictionary:
	var d := {}
	for f in _FIELDS:
		var v = get(f)
		d[f] = v.duplicate(true) if (v is Dictionary or v is Array) else v
	return d


func from_dict(d: Dictionary) -> void:
	for f in _FIELDS:
		if not d.has(f):
			continue
		var cur = get(f)
		var v = d[f]
		if cur is int:
			set(f, int(v))
		elif cur is float:
			set(f, float(v))
		elif cur is Dictionary:
			var copy := {}
			for k in v:
				copy[k] = int(v[k])
			set(f, copy)
		else:
			set(f, v.duplicate(true) if v is Array else v)
	for n in nodes:
		n.angle = float(n.angle)
		n.dist = float(n.dist)
		n.taken = bool(n.taken)
