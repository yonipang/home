extends "res://tests/test_base.gd"

const GS := preload("res://scripts/core/game_state.gd")
const SAVE := "user://test_save.json"
const SUSPEND := "user://test_suspend.json"


func _fresh() -> Node:
	var gs: Node = GS.new()
	gs.save_path = SAVE
	gs.suspend_path = SUSPEND
	gs.clear_suspend()
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(SAVE)
	gs.new_game()
	return gs


## 평범한 일과 + 모루네 잔치
func _make_party_day(gs: Node) -> void:
	gs.world.items.wood = WorldState.HOUSE_WOOD
	gs.world.items.mushroom = 1
	gs.interaction("halmeoni")
	gs.choose("halmeoni", "help")
	gs.interaction("gussi")
	gs.choose("gussi", "sit")
	gs.interaction("moru")
	if gs.can_greet_from_notebook("moru"):
		gs.choose("moru", "greet")
	if not gs.world.house_complete():
		gs.choose("moru", "give")
	gs.interaction("hearth")
	gs.choose("hearth", "cook")
	gs.clock.skip_to_evening()
	var opts: Array = gs.npc_options("moru").map(func(o): return o.id)
	check(opts.has("party"), "party offered in the evening once the house is done")
	gs.choose("moru", "party")


func test_ordinary_day_cannot_fill_happiness() -> void:
	var gs := _fresh()
	gs.world.items.wood = 3
	gs.world.items.mushroom = 1
	gs.world.items.drop = 6
	for i in 4:
		for id in ["halmeoni", "moru", "gussi", "furball"]:
			gs.interaction(id)
	gs.choose("halmeoni", "help")
	gs.choose("gussi", "sit")
	gs.choose("moru", "give")
	gs.choose("hearth", "cook")
	gs.choose("field", "water")
	for i in WorldState.POSTS:
		gs.interaction("post_%d" % i)
	check(not gs.happiness.is_full(), "an ordinary busy day is not a very good day (%.0f)" % gs.happiness.value)
	gs.free()


func test_relationship_grows_once_per_day_per_kind() -> void:
	var gs := _fresh()
	for i in 5:
		gs.interaction("moru")
	eq(gs.relationships.points("moru"), 1, "talking many times counts once")
	gs.world.items.wood = 1
	gs.choose("moru", "give")
	eq(gs.relationships.points("moru"), 2, "doing something together counts once more")
	gs.free()


func test_party_day_forgets_but_world_and_notebook_stay() -> void:
	var gs := _fresh()
	_make_party_day(gs)
	check(gs.happiness.is_full(), "party day fills happiness")
	check(not gs.night_choices_available(), "act 1: no choice before the rule is known")
	var r: Dictionary = gs.end_day("sleep")
	check(r.forgot, "forgets after a very good day")
	check(r.learned_rule, "learns the forgetting rule")
	eq(gs.cycle, 2, "second self")
	eq(gs.day, 1, "day count restarts")
	eq(gs.relationships.stage("moru"), 0, "relationships reset")
	check(gs.world.house_complete(), "the house is still standing")
	check(not gs.world.moru_asked, "Moru forgot asking")
	check(gs.notebook.person_stage("moru") >= 1, "notebook remembers Moru")
	eq(gs.notebook.chosen_line(1, 1), Content.GOOD_DAY_MONOLOGUE, "the last line of the first self")
	gs.free()


func test_after_forgetting_greet_and_choices() -> void:
	var gs := _fresh()
	_make_party_day(gs)
	gs.end_day("sleep")
	var t: Dictionary = gs.interaction("moru")
	eq(t.hint, Content.NPCS.moru.forgot_hint, "habit hint after forgetting")
	check(gs.notebook.knows("hands"), "learns that made things remain")
	check(gs.can_greet_from_notebook("moru"), "can greet Moru from the notebook")
	_make_party_day(gs)
	check(gs.night_choices_available(), "choices appear once the rule is known")
	var r: Dictionary = gs.end_day("walk")
	check(not r.forgot, "a night walk calms the day down")
	gs.free()


func test_fishing_flow() -> void:
	var gs := _fresh()
	var opts: Array = gs.npc_options("gussi").map(func(o): return o.id)
	check(not opts.has("rod"), "no rod for strangers")
	gs.relationships.restore_stage("gussi", 2)
	gs.choose("gussi", "rod")
	eq(gs.interaction("pond").options[0].id, "fish", "fishing offered at the pond")
	var before: float = gs.happiness.value
	gs.fish_result(true)
	check(gs.happiness.value - before >= 59.0, "first fish is a big day")
	gs.free()


func test_todos_and_hint() -> void:
	var gs := _fresh()
	check(gs.todos().has("이웃들에게 인사하기"), "first todo is to meet people")
	gs.interaction("halmeoni")
	gs.choose("field", "water")
	gs.end_day("sleep")
	eq(gs.furball_hint(), "할머니 호박, 오늘 물 안 주면 시들어.", "furball reminds about the pumpkin")
	check(gs.todos().any(func(t): return t.begins_with("할머니 호박")), "pumpkin todo")
	gs.free()


func test_save_and_suspend_round_trip() -> void:
	var gs := _fresh()
	gs.interaction("gussi")
	gs.world.house_wood = 4
	gs.clock.elapsed = 123.0
	gs.player_position = Vector2(10, 20)
	gs.save_suspend()
	var other := _fresh_keep_files()
	eq(other.load_or_new(), "suspend", "suspend is loaded first")
	eq(other.clock.elapsed, 123.0, "mid-day time restored")
	eq(other.player_position, Vector2(10, 20), "position restored")
	eq(other.world.house_wood, 4, "world restored")
	check(not FileAccess.file_exists(SUSPEND), "suspend deleted after loading")
	other.end_day("sleep")
	var third := _fresh_keep_files()
	eq(third.load_or_new(), "save", "sleep save loads next")
	eq(third.day, 2, "saved day")
	eq(third.clock.elapsed, 0.0, "save always starts in the morning")
	gs.free()
	other.free()
	third.free()


func _fresh_keep_files() -> Node:
	var gs: Node = GS.new()
	gs.save_path = SAVE
	gs.suspend_path = SUSPEND
	return gs


func cleanup() -> void:
	for p in [SAVE, SUSPEND]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)


func test_rest_and_wait_until_evening() -> void:
	var gs := _fresh()
	var home: Array = gs.interaction("home").options.map(func(o): return o.id)
	check(home.has("rest"), "can rest at home in the morning")
	gs.choose("home", "rest")
	eq(gs.clock.segment_name(), "낮", "resting moves to the next part of the day")
	gs.world.house_wood = WorldState.HOUSE_WOOD
	gs.relationships.restore_stage("moru", 1)
	var opts: Array = gs.npc_options("moru").map(func(o): return o.id)
	check(opts.has("wait_evening"), "can wait with Moru for the party")
	var r: Dictionary = gs.choose("moru", "wait_evening")
	eq(gs.clock.segment_name(), "저녁", "waiting brings the evening")
	check(r.options.any(func(o): return o.id == "party"), "party offered right away")
	gs.free()


func test_todos_say_when_done() -> void:
	var gs := _fresh()
	gs.relationships.restore_stage("moru", 1)
	for i in WorldState.POSTS:
		gs.world.lit_posts[i] = true
	eq(gs.todos(), ["할 일을 다 했다. 집에서 쉬면 시간이 지나간다."], "rest hint when nothing is left")
	gs.free()


func test_explore_house_and_link_clues() -> void:
	var gs := _fresh()
	var spots: Array = gs.interaction("house_east").options.map(func(o): return o.id)
	check(not spots.has("e_box"), "the box needs other clues first")
	gs.choose("house_east", "e_tally")
	gs.choose("house_east", "e_pencil")
	spots = gs.interaction("house_east").options.map(func(o): return o.id)
	check(spots.has("e_box"), "the box appears after finding the tally and pencil")
	gs.choose("house_east", "e_box")
	eq(gs.notebook.clues.size(), 3, "three clues")
	eq(gs.linkable_count(), 1, "one link possible")
	check(not gs.link_clues(["e_tally", "e_box"]).ok, "wrong set does not link")
	var r: Dictionary = gs.link_clues(["e_box", "e_pencil", "e_tally"])
	check(r.ok, "right set links")
	check(gs.notebook.knows("selves"), "learns that this is not the first time")
	gs.end_day("sleep")
	check(gs.notebook.clues.has("e_box"), "clues survive the night")
	gs.free()


func test_clues_do_not_make_happy() -> void:
	var gs := _fresh()
	for id in Content.HOUSES:
		for sp in Content.HOUSES[id].spots:
			gs.choose(id, sp.id)
	eq(gs.notebook.clues.size(), Content.CLUES.size(), "all clues found")
	eq(gs.happiness.value, 0.0, "discovering the past is not a happy thing")
	gs.free()


func test_faint_costs_furball_and_time() -> void:
	var gs := _fresh()
	var light: float = gs.furball_light
	gs.faint()
	eq(gs.clock.segment_name(), "낮", "lose the rest of the morning")
	check(gs.furball_light < light, "the furball gets dimmer")
	gs.free()


func test_lantern_from_tree() -> void:
	var gs := _fresh()
	gs.choose("tree", "drop")
	var opts: Array = gs.interaction("tree").options.map(func(o): return o.id)
	check(opts.has("lantern"), "can light a lantern with a drop")
	gs.choose("tree", "lantern")
	check(gs.world.lantern_on(), "lantern lit")
	gs.free()
