extends Node
## 게임 전체 상태 (autoload: GameState).
## 화면과 무관한 규칙은 모두 여기에 있고, tests/에서 직접 검사한다.
##
## 상호작용은 두 단계다:
##   interaction(id)          → {speaker, text, hint, options} 또는 {toast}
##   choose(id, option_id)    → {speaker, text, options, action}
## action: "" | "sleep" | "fish"

signal happiness_changed(ratio: float)
signal notebook_changed

const FURBALL_NIGHT_COST := 1.5
const FURBALL_WALK_COST := 3.0
const WALK_CALM := 30.0
const NPC_IDS := ["halmeoni", "moru", "gussi"]

var save_path := "user://save.json"
var suspend_path := "user://suspend.json"

var cycle := 1            ## 몇 번째 '나'인지
var day := 1              ## 이번 회차의 며칠째 (털뭉치가 뿌리에 긋는 금)
var tallies: Array = []   ## 지난 회차마다 그은 금의 수
var furball_light := 100.0
var morning_line := Content.MORNING_FIRST
var just_forgot := false
var last_night := {}      ## {shrunk, wilted}
var player_position := Vector2.INF  ## 이어 하기용

var happiness := Happiness.new()
var relationships := Relationships.new()
var notebook := Notebook.new()
var clock := DayClock.new()
var world := WorldState.new()


func new_game() -> void:
	cycle = 1
	day = 1
	tallies = []
	furball_light = 100.0
	morning_line = Content.MORNING_FIRST
	just_forgot = false
	last_night = {}
	player_position = Vector2.INF
	happiness = Happiness.new()
	relationships = Relationships.new()
	notebook = Notebook.new()
	world = WorldState.new()
	world.new_day(cycle, day)
	clock.reset()


# ── 기본 동작 ─────────────────────────────────────

func log_line(text: String, kind := "auto") -> void:
	notebook.add(cycle, day, text, kind)
	notebook_changed.emit()


func gain(source: String, amount: float = -1.0) -> float:
	if amount < 0.0:
		amount = Content.GAIN.get(source, 0.0)
	var g := happiness.add(source, amount)
	happiness_changed.emit(happiness.ratio())
	return g


func did_today(source: String) -> bool:
	return happiness.times_done(source) > 0


## 관계는 하루에 대화로 한 번, 함께한 일로 한 번까지만 깊어진다.
func _bump(npc_id: String, kind: String) -> void:
	var key := "bump_%s_%s" % [kind, npc_id]
	if did_today(key):
		return
	happiness.add(key, 0.0)
	relationships.bump(npc_id)
	notebook.record_person(npc_id, relationships.stage(npc_id))


func _big(source: String) -> void:
	gain(source)
	log_line(Content.BIG_LOGS[source])


# ── 이웃 ──────────────────────────────────────────

## 이웃과 이야기한다. {stage, line, title, hint} 를 돌려준다.
func talk(npc_id: String) -> Dictionary:
	var before := relationships.stage(npc_id)
	var hint := ""
	var first_ever_this_cycle := relationships.points(npc_id) == 0
	if first_ever_this_cycle and cycle > 1:
		hint = Content.NPCS[npc_id].forgot_hint
		if npc_id == "moru" and world.house_wood > 0:
			if notebook.learn_rule("hands"):
				log_line("모루는 자기가 짓던 집을 기억하지 못했다. 그래도 집은 그대로 서 있었다.")
	var first_today := not did_today("talk_" + npc_id)
	_bump(npc_id, "talk")
	gain("talk_" + npc_id, Content.GAIN.talk)
	var after := relationships.stage(npc_id)
	if first_today:
		var name: String = Content.NPCS[npc_id].name
		var title := Content.npc_title(npc_id, after)
		if title == "…":
			log_line("%s 이야기했다. 나를 부르지는 않았다." % Content.josa(name, "와", "과"))
		else:
			var particle := Content.josa(title, "라고", "이라고").substr(title.length())
			log_line("%s 이야기했다. 나를 '%s'%s 불렀다." % [Content.josa(name, "와", "과"), title, particle])
	_start_quest(npc_id)
	return {"stage": after, "line": Content.npc_line(npc_id, before), "title": Content.npc_title(npc_id, after), "hint": hint}


func _start_quest(npc_id: String) -> void:
	if npc_id == "moru" and not world.moru_asked and not world.house_complete():
		world.moru_asked = true
		log_line("모루가 이층집을 짓는다며 나무 조각을 구해 달라고 했다.")
	elif npc_id == "halmeoni" and not world.halmeoni_asked:
		world.halmeoni_asked = true
		log_line("할머니가 저 호박은 매일 물을 주면 아주 커질 거라고 했다.")


func quest_line(npc_id: String) -> String:
	var w := world
	match npc_id:
		"moru":
			if w.house_complete():
				if did_today("party"):
					return "잔치, 진짜 좋았죠? 오늘이 제일 좋은 날 같아요!"
				if cycle > 1 and relationships.points(npc_id) <= 1:
					return "저 이층집… 제가 지은 거래요. 손이 기억하는 것 같아요."
				return "이층집 다 됐어요! 저녁에 오세요, 잔치해요!"
			return "이층집, 지금 %d/%d. 나무 조각이 더 있으면 좋겠어요. 경계 쪽에 가끔 떨어져 있어요." % [w.house_wood, WorldState.HOUSE_WOOD]
		"halmeoni":
			if w.pumpkin_ready():
				return "호박이 다 컸어. 밭에 가서 따 보련?"
			if w.pumpkin_water > 0:
				return "호박이 %d/%d만큼 컸어. 하루라도 물을 거르면 시들어." % [w.pumpkin_water, WorldState.PUMPKIN_WATER]
			return "밭에 있는 저 호박, 매일 물을 주면 아주 커질 거야."
		"gussi":
			if w.fish_caught_this_cycle:
				return "……잡았지. 있다더니, 진짜 있었어."
			if w.rod_borrowed:
				return "찌가 쑥 들어가면, 그때야. 서두르면 놓쳐."
			if relationships.stage(npc_id) >= 2:
				return "……낚싯대, 빌려줄까."
	return ""


func npc_options(npc_id: String) -> Array:
	var w := world
	var opts := []
	match npc_id:
		"halmeoni":
			if not did_today("field_help"):
				opts.append({"id": "help", "label": "밭일 돕기", "primary": true})
		"moru":
			if not w.house_complete() and w.items.wood > 0:
				opts.append({"id": "give", "label": "나무 조각 건네기 (%d개)" % w.items.wood, "primary": true})
			if w.house_complete() and not did_today("party"):
				if clock.segment() >= 2 and relationships.stage(npc_id) >= 1:
					opts.append({"id": "party", "label": "잔치하기", "primary": true})
		"gussi":
			if not did_today("sit"):
				opts.append({"id": "sit", "label": "옆에 앉아 있기"})
			if not w.rod_borrowed and relationships.stage(npc_id) >= 2:
				opts.append({"id": "rod", "label": "낚싯대 빌리기", "primary": true})
	if can_greet_from_notebook(npc_id):
		opts.append({"id": "greet", "label": "공책에 적힌 대로 인사하기"})
	opts.append({"id": "close", "label": "그럼 또 봬요"})
	return opts


## 공책에 적힌 관계를 읽고 인사한다. 되살아난 단계를 돌려준다 (없으면 -1).
func greet_from_notebook(npc_id: String) -> int:
	var s := notebook.person_stage(npc_id)
	if s <= relationships.stage(npc_id):
		return -1
	relationships.restore_stage(npc_id, s)
	log_line("공책에 적힌 대로 %s 인사했다." % Content.josa(Content.NPCS[npc_id].name, "에게", "에게"))
	return s


func can_greet_from_notebook(npc_id: String) -> bool:
	return relationships.points(npc_id) > 0 and notebook.person_stage(npc_id) > relationships.stage(npc_id)


# ── 장소와 물건 ───────────────────────────────────

func cook() -> bool:
	if did_today("cook") or world.items.mushroom <= 0:
		return false
	world.items.mushroom -= 1
	furball_light = minf(100.0, furball_light + 4.0)
	gain("cook")
	log_line("빛버섯 수프를 끓였다. 털뭉치가 맛없다며 세 그릇 먹었다.")
	return true


func pet_furball() -> String:
	gain("furball")
	if furball_light < 70.0:
		return Content.FURBALL_TIRED_LINE
	return Content.FURBALL_LINES[(day + happiness.times_done("furball")) % Content.FURBALL_LINES.size()]


## 낚시 결과. 이번 회차 첫 물고기면 큰일.
func fish_result(success: bool) -> String:
	var first := world.record_fish(success)
	if not success:
		return "놓쳤다."
	if first:
		_big("first_fish")
		return "물고기다! 아저씨가 한참 아무 말도 못 했다.\n「있다더니, 진짜 있었구나.」"
	gain("fish")
	return "손바닥만 한 물고기를 잡았다. 아저씨가 놓아주라고 했다."


## 상호작용 시작. 대화창 내용이나 짧은 알림을 돌려준다.
func interaction(id: String) -> Dictionary:
	var w := world
	if NPC_IDS.has(id):
		var t := talk(id)
		var line: String = t.line
		var q := quest_line(id)
		if q != "":
			line += "\n" + q
		var npc: Dictionary = Content.NPCS[id]
		if id == "moru" and w.house_complete() and not did_today("party") and clock.segment() < 2:
			line += "\n(저녁에 다시 오면 잔치를 할 수 있다.)"
		var speaker: String = npc.name if t.title == "…" else "%s · 나를 '%s'" % [npc.name, t.title]
		return {"speaker": speaker, "text": line, "hint": t.hint, "options": npc_options(id)}
	if id.begins_with("wood_") or id.begins_with("mush_"):
		var kind := w.take_node(id)
		if kind == "wood":
			return {"toast": "나무 조각을 주웠다. (주머니 %d개)" % w.items.wood}
		if kind == "mushroom":
			return {"toast": "빛버섯을 땄다. (주머니 %d개)" % w.items.mushroom}
		return {}
	if id.begins_with("post_"):
		var i := int(id.trim_prefix("post_"))
		if w.lit_posts[i]:
			return {"toast": "이미 켜져 있다."}
		if w.light_post(i):
			gain("post")
			return {"toast": "경계 등불을 켰다. (%d/%d)" % [w.lit_posts.count(true), WorldState.POSTS]}
		return {"toast": "빛 방울이 없다. 나무 뿌리에서 받아 오자."}
	match id:
		"furball":
			return {"speaker": "털뭉치", "text": pet_furball(), "options": [{"id": "close", "label": "알았어"}]}
		"tree":
			var left := w.drops_left()
			var opts := []
			if left > 0:
				opts.append({"id": "drop", "label": "빛 방울 받기 (오늘 %d번 남음)" % left, "primary": true})
			opts.append({"id": "close", "label": "그만두기"})
			return {"speaker": "등불나무", "text": "뿌리 끝에 빛 방울이 이슬처럼 맺혀 있다.\n주머니의 빛 방울 %d개 · 꺼진 경계 등불 %d개\n꺼진 등불이 많을수록 밤사이 빛의 원이 줄어든다." % [w.items.drop, w.lit_posts.count(false)], "options": opts}
		"hearth":
			var opts := []
			if not did_today("cook") and w.items.mushroom > 0:
				opts.append({"id": "cook", "label": "빛버섯 수프 끓이기", "primary": true})
			opts.append({"id": "close", "label": "그만두기"})
			var text := "오늘은 이미 수프를 끓였다." if did_today("cook") else ("빛버섯이 %d개 있다." % w.items.mushroom if w.items.mushroom > 0 else "빛버섯이 없다. 서남쪽 버섯숲에 가끔 난다.")
			return {"speaker": "화덕", "text": text, "options": opts}
		"home":
			return {"speaker": "내 집", "text": "창문이 나무 쪽으로 나 있다.",
				"options": [{"id": "sleep", "label": "일찍 자기", "primary": true}, {"id": "close", "label": "아직 아니야"}]}
		"field":
			var opts := []
			var text := ""
			if w.pumpkin_ready():
				text = "호박이 아주 크게 자랐다."
				opts.append({"id": "harvest", "label": "호박 따기", "primary": true})
			else:
				text = "호박 %d/%d. " % [w.pumpkin_water, WorldState.PUMPKIN_WATER] + ("오늘은 이미 물을 줬다." if w.pumpkin_watered_today else "흙이 말라 있다.")
				if not w.pumpkin_watered_today:
					opts.append({"id": "water", "label": "호박에 물 주기", "primary": true})
			opts.append({"id": "close", "label": "그만두기"})
			return {"speaker": "할머니 밭", "text": text, "options": opts}
		"pond":
			if w.can_fish():
				return {"speaker": "연못", "text": "물 위로 나무 빛이 일렁인다. (오늘 %d번 남음)" % (WorldState.FISH_TRIES - w.fish_tries),
					"options": [{"id": "fish", "label": "낚시하기", "primary": true}, {"id": "close", "label": "그만두기"}]}
			var why := "오늘은 그만하자." if w.rod_borrowed else "낚싯대가 없다. 구 씨 아저씨라면 빌려줄지도."
			return {"speaker": "연못", "text": why, "options": [{"id": "close", "label": "그만두기"}]}
	return {}


## 선택지 처리. 다음에 보여 줄 대화창 내용을 돌려준다.
func choose(id: String, option: String) -> Dictionary:
	var w := world
	var name: String = Content.NPCS[id].name if NPC_IDS.has(id) else Content.SPOT_NAMES.get(id, "")
	var ok := [{"id": "close", "label": "좋았다"}]
	match option:
		"close":
			return {"action": "close"}
		"sleep":
			return {"action": "sleep"}
		"fish":
			return {"action": "fish"}
		"help":
			gain("field_help")
			_bump(id, "act")
			log_line("할머니와 씨앗을 두 알씩 심었다.")
			return {"speaker": name, "text": "할머니를 따라 씨앗을 두 알씩 심었다. 손이 금방 익숙해졌다.", "options": ok}
		"give":
			var n := w.give_wood()
			gain("give_wood")
			_bump(id, "act")
			log_line("모루에게 나무 조각 %d개를 건넸다. (%d/%d)" % [n, w.house_wood, WorldState.HOUSE_WOOD])
			var text := "「고마워요!」 모루가 망치를 들었다. 이층집 %d/%d." % [w.house_wood, WorldState.HOUSE_WOOD]
			if w.house_complete():
				text = "마지막 조각이다. 「다 됐어요! 이층집이에요! 저녁에 꼭 와요, 잔치해요!」"
			return {"speaker": name, "text": text, "options": ok}
		"party":
			_big("party")
			_bump(id, "act")
			return {"speaker": name, "text": "할머니가 호박전을 부치고, 아저씨도 왔다. 모두 웃었다. 털뭉치도 소리 내서 웃었다.", "options": ok}
		"sit":
			gain("sit")
			_bump(id, "act")
			log_line("구 씨 아저씨 옆에 말없이 앉아 있었다.")
			return {"speaker": name, "text": "물빛이 천천히 일렁였다. 아무 말도 하지 않아도 편했다.", "options": ok}
		"rod":
			w.rod_borrowed = true
			log_line("구 씨 아저씨가 낚싯대를 빌려주었다.")
			return {"speaker": name, "text": "「……찌가 쑥 들어가면, 그때야.」 연못에서 낚시를 할 수 있다.", "options": ok}
		"greet":
			var s := greet_from_notebook(id)
			return {"speaker": "%s · 나를 '%s'" % [name, Content.npc_title(id, s)],
				"text": "공책에 적힌 대로 인사했다. 잠깐 놀란 얼굴이더니, 금세 웃었다.", "options": [{"id": "close", "label": "다행이다"}]}
		"drop":
			w.take_drop()
			return interaction("tree")
		"cook":
			cook()
			return {"speaker": name, "text": "빛버섯 수프를 끓였다. 털뭉치가 맛없다며 세 그릇 먹었다.", "options": [{"id": "close", "label": "맛없다면서…"}]}
		"water":
			w.water_pumpkin()
			gain("water")
			if not w.halmeoni_asked:
				w.halmeoni_asked = true
			var text := "물을 줬다. 호박 %d/%d." % [w.pumpkin_water, WorldState.PUMPKIN_WATER]
			if w.pumpkin_ready():
				text += " 이제 딸 수 있을 만큼 컸다."
			return {"speaker": name, "text": text, "options": ok}
		"harvest":
			w.harvest_pumpkin()
			_big("harvest")
			_bump("halmeoni", "act")
			return {"speaker": name, "text": "가장 큰 호박을 땄다. 할머니가 호박죽을 쑤며 처음 듣는 콧노래를 불렀다.", "options": ok}
	return {"action": "close"}


# ── 할 일 ─────────────────────────────────────────

## 공책 '오늘' 맨 위의 할 일
func todos() -> Array:
	var w := world
	var list := []
	if w.halmeoni_asked:
		if w.pumpkin_ready():
			list.append("다 큰 호박 따기")
		elif not w.pumpkin_watered_today:
			list.append("할머니 호박에 물 주기 (%d/%d)" % [w.pumpkin_water, WorldState.PUMPKIN_WATER])
	if w.moru_asked and not w.house_complete():
		list.append("모루에게 나무 조각 (%d/%d · 주머니 %d)" % [w.house_wood, WorldState.HOUSE_WOOD, w.items.wood])
	if w.house_complete() and not did_today("party") and relationships.stage("moru") >= 1:
		list.append("저녁에 모루네 잔치")
	var dark := w.lit_posts.count(false)
	if dark > 0:
		list.append("경계 등불 켜기 (%d/%d)" % [WorldState.POSTS - dark, WorldState.POSTS])
	if w.can_fish():
		list.append("연못에서 낚시 (%d번 남음)" % (WorldState.FISH_TRIES - w.fish_tries))
	if not w.moru_asked and not w.halmeoni_asked and relationships.points("moru") == 0:
		list.push_front("이웃들에게 인사하기")
	return list


## 아침에 털뭉치가 하는 한마디
func furball_hint() -> String:
	var w := world
	if last_night.get("wilted", false):
		return "할머니 호박, 어제 물 안 줘서 좀 시들었어."
	if w.halmeoni_asked and w.pumpkin_water > 0 and not w.pumpkin_ready():
		return "할머니 호박, 오늘 물 안 주면 시들어."
	if last_night.get("shrunk", 0.0) > 0.0:
		return "밤새 빛이 줄었어. 경계 등불, 꺼진 데가 있었잖아."
	if w.moru_asked and not w.house_complete():
		return "모루가 나무 조각 기다려."
	return "여기서 살려면 등불이 있어야 해. 나무 뿌리에서 빛 방울 받아."


# ── 하루 마감 ─────────────────────────────────────

## 밤에 선택지가 나오는가. 망각 규칙을 알기 전(1막)에는 선택 없이 바로 잠든다.
func night_choices_available() -> bool:
	return happiness.is_full() and notebook.knows("forget")


## 오늘의 한 줄 후보: 인사보다 활동 기록을, 이른 일보다 늦은 일을 먼저 (최대 2개)
func line_candidates() -> Array:
	var autos := notebook.entries_for(cycle, day, "auto")
	autos.reverse()
	var acts := autos.filter(func(e): return not e.text.contains("이야기했다"))
	var talks := autos.filter(func(e): return e.text.contains("이야기했다"))
	return (acts + talks).slice(0, 2).map(func(e): return e.text)


func choose_line(text: String) -> void:
	if notebook.chosen_line(cycle, day) == "":
		log_line(text, "chosen")


func write_note_to_self() -> void:
	log_line(Content.NOTE_TO_SELF, "note")


## choice: "sleep" | "walk". {forgot, learned_rule} 을 돌려준다.
func end_day(choice: String) -> Dictionary:
	if choice == "walk":
		happiness.calm(WALK_CALM)
		furball_light = maxf(5.0, furball_light - FURBALL_WALK_COST)
		log_line("밤 산책을 했다. 털뭉치가 말없이 따라왔다.")
	furball_light = maxf(5.0, furball_light - FURBALL_NIGHT_COST)

	var forgot := happiness.is_full()
	var learned := false
	if forgot and notebook.entries_for(cycle, day, "chosen").is_empty():
		log_line(Content.GOOD_DAY_MONOLOGUE, "chosen")
	last_night = world.end_night(forgot)
	if forgot:
		tallies.append(day)
		relationships.reset()
		cycle += 1
		day = 1
		learned = notebook.learn_rule("forget")
		morning_line = Content.MORNING_FIRST + "\n" + Content.MORNING_AFTER_RULE
	else:
		day += 1
		morning_line = Content.MORNING_NORMAL
	just_forgot = forgot
	happiness.new_day()
	clock.reset()
	world.new_day(cycle, day)
	player_position = Vector2.INF
	save_game()
	clear_suspend()
	return {"forgot": forgot, "learned_rule": learned}


# ── 저장 ──────────────────────────────────────────

func to_dict() -> Dictionary:
	return {
		"version": 2,
		"cycle": cycle, "day": day, "tallies": tallies.duplicate(),
		"furball_light": furball_light, "morning_line": morning_line, "just_forgot": just_forgot,
		"last_night": last_night.duplicate(),
		"happiness": happiness.to_dict(), "relationships": relationships.to_dict(),
		"notebook": notebook.to_dict(), "clock_elapsed": clock.elapsed, "world": world.to_dict(),
	}


func from_dict(d: Dictionary) -> void:
	cycle = int(d.get("cycle", 1))
	day = int(d.get("day", 1))
	tallies = Array(d.get("tallies", [])).map(func(x): return int(x))
	furball_light = float(d.get("furball_light", 100.0))
	morning_line = str(d.get("morning_line", Content.MORNING_FIRST))
	just_forgot = bool(d.get("just_forgot", false))
	last_night = d.get("last_night", {})
	happiness.from_dict(d.get("happiness", {}))
	relationships.from_dict(d.get("relationships", {}))
	notebook.from_dict(d.get("notebook", {}))
	clock.elapsed = float(d.get("clock_elapsed", 0.0))
	world = WorldState.new()
	if d.has("world"):
		world.from_dict(d.world)
	else:
		world.new_day(cycle, day)


func _write(path: String, data: Dictionary) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))


func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


## 잠들 때만 저장한다.
func save_game() -> void:
	var d := to_dict()
	d.clock_elapsed = 0.0
	_write(save_path, d)


## 앱이 백그라운드로 가거나 꺼질 때. 불러오면 지운다 (되돌리기 방지).
func save_suspend() -> void:
	var d := to_dict()
	if player_position != Vector2.INF:
		d.player = [player_position.x, player_position.y]
	_write(suspend_path, d)


func clear_suspend() -> void:
	if FileAccess.file_exists(suspend_path):
		DirAccess.remove_absolute(suspend_path)


## 이어 하기 > 저장 > 새 게임 순으로 불러온다. 어떤 것을 불러왔는지 돌려준다.
func load_or_new() -> String:
	var s := _read(suspend_path)
	if not s.is_empty():
		from_dict(s)
		if s.has("player"):
			player_position = Vector2(s.player[0], s.player[1])
		clear_suspend()
		return "suspend"
	var g := _read(save_path)
	if not g.is_empty():
		from_dict(g)
		return "save"
	new_game()
	return "new"


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST \
			or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if is_inside_tree() and get_tree().current_scene != null:
			save_suspend()
