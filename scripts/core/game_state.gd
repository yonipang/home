extends Node
## 게임 전체 상태 (autoload: GameState).
## 화면과 무관한 규칙은 모두 여기에 있고, tests/에서 직접 검사한다.

signal happiness_changed(ratio: float)
signal notebook_changed

const FURBALL_NIGHT_COST := 1.5
const FURBALL_WALK_COST := 3.0
const WALK_CALM := 30.0

var save_path := "user://save.json"
var suspend_path := "user://suspend.json"

var cycle := 1            ## 몇 번째 '나'인지
var day := 1              ## 이번 회차의 며칠째 (털뭉치가 뿌리에 긋는 금)
var tallies: Array = []   ## 지난 회차마다 그은 금의 수
var furball_light := 100.0
var morning_line := Content.MORNING_FIRST
var just_forgot := false
var player_position := Vector2.INF  ## 이어 하기용

var happiness := Happiness.new()
var relationships := Relationships.new()
var notebook := Notebook.new()
var clock := DayClock.new()


func new_game() -> void:
	cycle = 1
	day = 1
	tallies = []
	furball_light = 100.0
	morning_line = Content.MORNING_FIRST
	just_forgot = false
	player_position = Vector2.INF
	happiness = Happiness.new()
	relationships = Relationships.new()
	notebook = Notebook.new()
	clock.reset()


# ── 하루 동안의 행동 ──────────────────────────────

func log_line(text: String, kind := "auto") -> void:
	notebook.add(cycle, day, text, kind)
	notebook_changed.emit()


func gain(source: String, amount: float) -> float:
	var g := happiness.add(source, amount)
	happiness_changed.emit(happiness.ratio())
	return g


## 이웃과 이야기한다. {stage, line, title, hint} 를 돌려준다.
func talk(npc_id: String) -> Dictionary:
	var before := relationships.stage(npc_id)
	var hint := ""
	if before == 0 and relationships.points(npc_id) == 0 and cycle > 1:
		hint = Content.NPCS[npc_id].forgot_hint
	var after := relationships.bump(npc_id)
	notebook.record_person(npc_id, after)
	gain("talk_" + npc_id, Content.TALK_AMOUNT)
	if happiness.times_done("talk_" + npc_id) == 1:
		var name: String = Content.NPCS[npc_id].name
		var title := Content.npc_title(npc_id, after)
		if title == "…":
			log_line("%s 이야기했다. 나를 부르지는 않았다." % Content.josa(name, "와", "과"))
		else:
			var particle := Content.josa(title, "라고", "이라고").substr(title.length())
			log_line("%s 이야기했다. 나를 '%s'%s 불렀다." % [Content.josa(name, "와", "과"), title, particle])
	return {"stage": after, "line": Content.npc_line(npc_id, before), "title": Content.npc_title(npc_id, after), "hint": hint}


## 공책에 적힌 관계를 읽고 인사한다. 되살아난 단계를 돌려준다 (없으면 -1).
func greet_from_notebook(npc_id: String) -> int:
	var s := notebook.person_stage(npc_id)
	if s <= relationships.stage(npc_id):
		return -1
	relationships.restore_stage(npc_id, s)
	log_line("공책에 적힌 대로 %s께 인사했다." % Content.NPCS[npc_id].name)
	return s


func can_greet_from_notebook(npc_id: String) -> bool:
	return notebook.person_stage(npc_id) > relationships.stage(npc_id)


func activity_available(npc_id: String) -> bool:
	var a: Dictionary = Content.NPCS[npc_id].activity
	if a.get("evening_only", false) and clock.segment() < 2:
		return false
	if relationships.stage(npc_id) < int(a.get("min_stage", 0)):
		return false
	return happiness.times_done("act_" + a.id) == 0


func do_activity(npc_id: String) -> float:
	var a: Dictionary = Content.NPCS[npc_id].activity
	relationships.bump(npc_id)
	notebook.record_person(npc_id, relationships.stage(npc_id))
	log_line(a.log)
	return gain("act_" + a.id, a.amount)


func cook() -> float:
	var o: Dictionary = Content.OBJECTS.hearth
	if happiness.times_done("cook") == 0:
		log_line(o.log)
	furball_light = minf(100.0, furball_light + o.furball_light)
	return gain("cook", o.amount)


func pet_furball() -> String:
	gain("furball", 4.0)
	if furball_light < 70.0:
		return Content.FURBALL_TIRED_LINE
	return Content.FURBALL_LINES[(day + happiness.times_done("furball")) % Content.FURBALL_LINES.size()]


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
	if forgot:
		if notebook.entries_for(cycle, day, "chosen").is_empty():
			log_line(Content.GOOD_DAY_MONOLOGUE, "chosen")
		tallies.append(day)
		relationships.reset()
		cycle += 1
		day = 1
		learned = notebook.learn_rule("forget")
		morning_line = Content.MORNING_FIRST
	else:
		day += 1
		morning_line = Content.MORNING_NORMAL

	if forgot and notebook.knows("forget"):
		morning_line = Content.MORNING_FIRST + "\n" + Content.MORNING_AFTER_RULE
	just_forgot = forgot
	happiness.new_day()
	clock.reset()
	player_position = Vector2.INF
	save_game()
	clear_suspend()
	return {"forgot": forgot, "learned_rule": learned}


# ── 저장 ──────────────────────────────────────────

func to_dict() -> Dictionary:
	return {
		"version": 1,
		"cycle": cycle, "day": day, "tallies": tallies.duplicate(),
		"furball_light": furball_light, "morning_line": morning_line, "just_forgot": just_forgot,
		"happiness": happiness.to_dict(), "relationships": relationships.to_dict(),
		"notebook": notebook.to_dict(), "clock_elapsed": clock.elapsed,
	}


func from_dict(d: Dictionary) -> void:
	cycle = int(d.get("cycle", 1))
	day = int(d.get("day", 1))
	tallies = Array(d.get("tallies", [])).map(func(x): return int(x))
	furball_light = float(d.get("furball_light", 100.0))
	morning_line = str(d.get("morning_line", Content.MORNING_FIRST))
	just_forgot = bool(d.get("just_forgot", false))
	happiness.from_dict(d.get("happiness", {}))
	relationships.from_dict(d.get("relationships", {}))
	notebook.from_dict(d.get("notebook", {}))
	clock.elapsed = float(d.get("clock_elapsed", 0.0))


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
