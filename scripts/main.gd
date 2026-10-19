extends Node
## 마을 화면 전체를 묶는다: 마을, 카메라, 조이스틱, 대화창, 공책, 낚시, 하루 마감, 아침.
##
## 개발용 실행 인자 (godot ... -- <인자>):
##   --smoke                  며칠을 자동으로 돌려 보고 종료 (CI)
##   --shot=<장면> --out=<png>  스크린샷 저장 후 종료.
##                            장면: village, dialogue, notebook, fishing, sleep, morning, forgot

const Village := preload("res://scripts/village/village.gd")
const Joystick := preload("res://scripts/ui/floating_joystick.gd")
const DialoguePanel := preload("res://scripts/ui/dialogue_panel.gd")
const NotebookPanel := preload("res://scripts/ui/notebook_panel.gd")
const SleepPanel := preload("res://scripts/ui/sleep_panel.gd")
const MorningOverlay := preload("res://scripts/ui/morning_overlay.gd")
const FishingPanel := preload("res://scripts/ui/fishing_panel.gd")

var village: Node2D
var camera: Camera2D
var joystick: Control
var dialogue: Control
var notebook: PanelContainer
var fishing: Control
var sleep_panel: PanelContainer
var morning: PanelContainer
var notebook_button: Button
var toast: Label

var time_scale := 1.0
var _talking_to := ""
var _args := {}
var _toast_tween: Tween


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		_args[kv[0]] = kv[1] if kv.size() > 1 else true
	var dev := _args.has("smoke") or _args.has("shot")
	if dev:
		GameState.save_path = "user://dev_save.json"
		GameState.suspend_path = "user://dev_suspend.json"
		GameState.new_game()
	var loaded := "new" if dev else GameState.load_or_new()

	_build()

	if loaded == "suspend" and GameState.player_position != Vector2.INF:
		village.player_pos = GameState.player_position
		_toast("이어서 합니다")
	else:
		morning.open()

	if _args.has("smoke"):
		_run_smoke.call_deferred()
	elif _args.has("shot"):
		_take_shot.call_deferred(str(_args.shot), str(_args.get("out", "user://shot.png")))


func _build() -> void:
	village = Village.new()
	add_child(village)
	village.arrived.connect(_interact)
	village.blocked_by_border.connect(func(): _toast("털뭉치: 「아직 안 돼. 아무것도 없이 들어가면 길 잃어.」"))
	village.blocked_by_dark.connect(func(): _toast("어둠 속이라 갈 수 없다. 빛의 원이 줄어든 탓이다."))

	camera = Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 6.0
	add_child(camera)
	camera.make_current()

	var ui := CanvasLayer.new()
	add_child(ui)
	joystick = Joystick.new()
	ui.add_child(joystick)
	joystick.tapped.connect(_on_tap)

	notebook_button = UIKit.button("공책")
	notebook_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	notebook_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	notebook_button.offset_left = -164
	notebook_button.offset_top = 56
	notebook_button.offset_right = -24
	notebook_button.offset_bottom = 56 + UIKit.MIN_TOUCH
	for st in ["normal", "hover", "pressed", "focus"]:
		notebook_button.add_theme_stylebox_override(st, UIKit.box(Color(0.1, 0.09, 0.08, 0.7), Color(0.54, 0.53, 0.5), 16, 2, 12))
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		notebook_button.add_theme_color_override(c, UIKit.LIGHT_TEXT)
	notebook_button.pressed.connect(func(): notebook.open())
	ui.add_child(notebook_button)

	toast = UIKit.label("", 28, UIKit.LIGHT_TEXT)
	toast.set_anchors_preset(Control.PRESET_TOP_WIDE)
	toast.offset_top = 170
	toast.offset_left = 40
	toast.offset_right = -40
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.modulate.a = 0.0
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(toast)

	dialogue = DialoguePanel.new()
	ui.add_child(dialogue)
	dialogue.chosen.connect(_on_dialogue_choice)
	fishing = FishingPanel.new()
	ui.add_child(fishing)
	notebook = NotebookPanel.new()
	ui.add_child(notebook)
	notebook.fast_time_toggled.connect(func(on): time_scale = 10.0 if on else 1.0)
	sleep_panel = SleepPanel.new()
	ui.add_child(sleep_panel)
	sleep_panel.finished.connect(_on_sleep_finished)
	morning = MorningOverlay.new()
	ui.add_child(morning)
	morning.done.connect(_on_morning_done)


func _modal_open() -> bool:
	return dialogue.visible or notebook.visible or sleep_panel.visible or morning.visible or fishing.visible


func _process(delta: float) -> void:
	var modal := _modal_open()
	joystick.enabled = not modal
	notebook_button.visible = not modal
	if modal:
		joystick.release()
		village.move_input = Vector2.ZERO
		village.queue_redraw()
	else:
		var keys := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		village.move_input = joystick.vector if joystick.vector.length() > 0.05 else keys
		village.step(delta)
		var seg: int = GameState.clock.advance(delta * time_scale)
		if seg >= 0:
			_toast(DayClock.SEGMENT_NAMES[seg] + (" · 털뭉치: 「저녁이다. 너무 들뜨지 마.」" if seg == 2 else ""))
		if GameState.clock.is_over():
			_toast("털뭉치: 「자야지.」")
			_start_sleep()
	var view_h := get_viewport().get_visible_rect().size.y
	camera.position = village.player_pos + Vector2(0, view_h * 0.14)
	GameState.player_position = village.player_pos


func _unhandled_input(event: InputEvent) -> void:
	if _modal_open():
		return
	if event.is_action_pressed("notebook"):
		notebook.open()
	elif event.is_action_pressed("interact"):
		var best := ""
		var best_d := Village.INTERACT_RANGE * 1.4
		for id in village.target_ids():
			var d: float = village.player_pos.distance_to(village.spot_pos(id))
			if id == "tree":
				d -= 50.0
			if d < best_d:
				best_d = d
				best = id
		if best != "":
			_interact(best)
	elif event.is_action_pressed("debug_fast"):
		time_scale = 1.0 if time_scale > 1.0 else 10.0
		_toast("시간 ×%d" % int(time_scale))


func _on_tap(screen_pos: Vector2) -> void:
	if _modal_open() or notebook_button.get_global_rect().has_point(screen_pos):
		return
	var world_pos: Vector2 = village.get_canvas_transform().affine_inverse() * screen_pos
	var id: String = village.target_at(world_pos)
	if id != "":
		village.walk_to(id)


# ── 상호작용 ──────────────────────────────────────

func _interact(id: String) -> void:
	_talking_to = id
	_show(GameState.interaction(id))


func _show(r: Dictionary) -> void:
	if r.has("toast"):
		_toast(r.toast)
		dialogue.hide()
	elif r.has("text"):
		dialogue.open(r.get("speaker", ""), r.text, r.get("options", []), r.get("hint", ""))
	else:
		dialogue.hide()


func _on_dialogue_choice(option: String) -> void:
	var r: Dictionary = GameState.choose(_talking_to, option)
	match r.get("action", ""):
		"close":
			dialogue.hide()
		"sleep":
			_start_sleep()
		"fish":
			dialogue.hide()
			fishing.start()
		_:
			_show(r)


func _start_sleep() -> void:
	dialogue.hide()
	notebook.hide()
	fishing.hide()
	village.cancel_walk()
	sleep_panel.open()


func _on_sleep_finished(choice: String) -> void:
	var r: Dictionary = GameState.end_day(choice)
	village.player_pos = Vector2(0, 150)
	village.furball_pos = Vector2(-40, 170)
	camera.reset_smoothing()
	morning.open("forget" if r.learned_rule else "")


func _on_morning_done() -> void:
	if GameState.just_forgot:
		notebook.open(true)
	else:
		_toast(GameState.clock.segment_name())


func _toast(text: String) -> void:
	toast.text = text
	if _toast_tween:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_property(toast, "modulate:a", 1.0, 0.25)
	_toast_tween.tween_interval(2.4)
	_toast_tween.tween_property(toast, "modulate:a", 0.0, 0.6)


# ── 개발용 ────────────────────────────────────────

var _smoke_failed := false


func _check(cond: bool, msg: String) -> void:
	if not cond and not _smoke_failed:
		_smoke_failed = true
		printerr("SMOKE FAIL: " + msg)


## 플레이어처럼 하루를 보낸다: 채집, 등불, 이웃, 부탁
func _play_day(fish_success: bool) -> void:
	var gs := GameState
	for n in gs.world.nodes.duplicate():
		_interact(n.id)
	_interact("tree")
	while gs.world.drops_left() > 0:
		_on_dialogue_choice("drop")
	_on_dialogue_choice("close")
	for i in WorldState.POSTS:
		_interact("post_%d" % i)
	for id in ["halmeoni", "gussi", "moru", "furball"]:
		_interact(id)
		_check(dialogue.visible, "dialogue opens for " + id)
		var ids: Array = gs.npc_options(id).map(func(o): return o.id) if gs.NPC_IDS.has(id) else []
		for opt in ["help", "sit", "give", "rod"]:
			if ids.has(opt):
				_on_dialogue_choice(opt)
		_on_dialogue_choice("close")
	_interact("field")
	_on_dialogue_choice("harvest" if gs.world.pumpkin_ready() else "water")
	_on_dialogue_choice("close")
	_interact("hearth")
	_on_dialogue_choice("cook")
	_on_dialogue_choice("close")
	if gs.world.can_fish():
		_interact("pond")
		_on_dialogue_choice("fish")
		_check(fishing.visible, "fishing opens")
		fishing._state = "bite"
		fishing._finish(fish_success, "missed")
		fishing.hide()
	gs.clock.skip_to_evening()
	if gs.npc_options("moru").any(func(o): return o.id == "party"):
		_interact("moru")
		_on_dialogue_choice("party")
		_on_dialogue_choice("close")


func _sleep_now() -> Dictionary:
	_start_sleep()
	_check(sleep_panel.visible, "sleep panel")
	var before: int = GameState.cycle
	sleep_panel._finish("sleep")
	morning.hide()
	_on_morning_done()
	notebook.hide()
	return {"forgot": GameState.cycle != before}


func _run_smoke() -> void:
	await get_tree().process_frame
	_check(morning.visible, "morning overlay on start")
	morning.hide()
	for i in 20:
		village.move_input = Vector2(1, 0)
		await get_tree().process_frame
	var first_forget_day := -1
	for d in range(1, 8):
		_play_day(false)
		var day_was: int = GameState.day
		notebook.open()
		await get_tree().process_frame
		notebook.hide()
		var r := _sleep_now()
		if r.forgot:
			first_forget_day = day_was
			break
		await get_tree().process_frame
	print("first forgetting on day %d" % first_forget_day)
	_check(first_forget_day >= 3, "the first very good day should take a few days of work (was %d)" % first_forget_day)
	_check(GameState.world.house_complete(), "the house stays after forgetting")
	_interact("moru")
	_check(dialogue.visible, "talk after forgetting")
	print("SMOKE FAIL" if _smoke_failed else "SMOKE OK")
	get_tree().quit(1 if _smoke_failed else 0)


func _take_shot(scene: String, out: String) -> void:
	DisplayServer.window_set_size(Vector2i(720, 1280))
	await get_tree().process_frame
	morning.hide()
	var gs := GameState
	match scene:
		"village", "dialogue", "notebook", "fishing":
			_play_day(false)
			gs.end_day("sleep")
			for n in gs.world.nodes.slice(0, 2):
				gs.world.take_node(n.id)
			for i in 3:
				gs.world.items.drop += 1
				gs.world.light_post(i)
			gs.clock.elapsed = gs.clock.segment_seconds * 1.3
			village.player_pos = Vector2(110, 160)
			dialogue.hide()
			if scene == "dialogue":
				gs.world.items.wood = 2
				_interact("moru")
			elif scene == "notebook":
				notebook.open()
			elif scene == "fishing":
				gs.world.rod_borrowed = true
				fishing.start()
				fishing._t = fishing._bite_at + 0.1
		"sleep":
			gs.notebook.learn_rule("forget")
			gs.gain("party")
			gs.gain("talk_moru", 40.0)
			_start_sleep()
			sleep_panel._show_decision()
		"morning":
			_play_day(false)
			gs.end_day("sleep")
			morning.open()
		"forgot":
			for d in 6:
				_play_day(false)
				if gs.happiness.is_full():
					break
				gs.end_day("sleep")
			gs.end_day("sleep")
			notebook.open(true)
	for i in 40:
		await get_tree().process_frame
	camera.reset_smoothing()
	await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.save_png(out)
	print("saved ", out)
	get_tree().quit(0)
