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


func _make_good_day(gs: Node) -> void:
	for id in ["halmeoni", "moru", "gussi"]:
		gs.talk(id)
		gs.talk(id)
	gs.cook()
	gs.clock.skip_to_evening()
	check(gs.activity_available("moru"), "party is available in the evening once Moru is a neighbour")
	gs.do_activity("moru")


func test_ordinary_day_keeps_memory() -> void:
	var gs := _fresh()
	gs.talk("moru")
	gs.talk("moru")
	var r: Dictionary = gs.end_day("sleep")
	check(not r.forgot, "ordinary day does not forget")
	eq(gs.day, 2, "day advances")
	eq(gs.relationships.stage("moru"), 1, "relationship kept")
	eq(gs.morning_line, Content.MORNING_NORMAL, "normal morning line")
	gs.free()


func test_very_good_day_forgets_but_notebook_stays() -> void:
	var gs := _fresh()
	_make_good_day(gs)
	check(gs.happiness.is_full(), "party day fills happiness")
	check(not gs.night_choices_available(), "act 1: no choice before the rule is known")
	var entries_before: int = gs.notebook.entries.size()
	var r: Dictionary = gs.end_day("sleep")
	check(r.forgot, "forgets after a very good day")
	check(r.learned_rule, "learns the forgetting rule")
	eq(gs.cycle, 2, "second self")
	eq(gs.day, 1, "day count restarts")
	eq(gs.tallies, [1], "tally of the first self kept")
	eq(gs.relationships.stage("moru"), 0, "relationships reset")
	check(gs.notebook.entries.size() > entries_before, "notebook kept and extended")
	eq(gs.notebook.person_stage("moru"), 1, "notebook remembers Moru")
	gs.free()


func test_after_rule_choices_and_walk_avoids_forgetting() -> void:
	var gs := _fresh()
	_make_good_day(gs)
	gs.end_day("sleep")
	_make_good_day(gs)
	check(gs.night_choices_available(), "choices appear once the rule is known")
	var r: Dictionary = gs.end_day("walk")
	check(not r.forgot, "a night walk calms the day down")
	check(gs.furball_light < 100.0, "the walk costs the furball some light")
	gs.free()


func test_greet_from_notebook_restores() -> void:
	var gs := _fresh()
	_make_good_day(gs)
	gs.end_day("sleep")
	check(gs.can_greet_from_notebook("moru"), "can greet Moru from the notebook")
	var s: int = gs.greet_from_notebook("moru")
	eq(s, 1, "restored to the recorded stage")
	eq(gs.relationships.stage("moru"), 1, "relationship restored")
	check(not gs.can_greet_from_notebook("moru"), "no second restore")
	var t: Dictionary = gs.talk("halmeoni")
	eq(t.hint, Content.NPCS.halmeoni.forgot_hint, "habit hint after forgetting")
	gs.free()


func test_save_and_suspend_round_trip() -> void:
	var gs := _fresh()
	gs.talk("gussi")
	gs.clock.elapsed = 123.0
	gs.player_position = Vector2(10, 20)
	gs.save_suspend()
	var other := _fresh_keep_files()
	eq(other.load_or_new(), "suspend", "suspend is loaded first")
	eq(other.clock.elapsed, 123.0, "mid-day time restored")
	eq(other.player_position, Vector2(10, 20), "position restored")
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
