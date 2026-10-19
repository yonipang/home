extends Node
## 마을 화면 전체를 묶는다: 마을, 카메라, 조이스틱, 대화창, 공책, 하루 마감, 아침.
##
## 개발용 실행 인자 (godot ... -- <인자>):
##   --smoke                  하루를 자동으로 돌려 보고 종료 (CI)
##   --shot=<장면> --out=<png>  스크린샷 저장 후 종료. 장면: village, dialogue, notebook, sleep, morning

const Village := preload("res://scripts/village/village.gd")
const Joystick := preload("res://scripts/ui/floating_joystick.gd")
const DialoguePanel := preload("res://scripts/ui/dialogue_panel.gd")
const NotebookPanel := preload("res://scripts/ui/notebook_panel.gd")
const SleepPanel := preload("res://scripts/ui/sleep_panel.gd")
const MorningOverlay := preload("res://scripts/ui/morning_overlay.gd")

var village: Node2D
var camera: Camera2D
var joystick: Control
var dialogue: Control
var notebook: PanelContainer
var sleep_panel: PanelContainer
var morning: PanelContainer
var notebook_button: Button
var toast: Label

var time_scale := 1.0
var _talking_to := ""
var _args := {}


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
	notebook_button.pressed.connect(_open_notebook)
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
	notebook = NotebookPanel.new()
	ui.add_child(notebook)
	notebook.fast_time_toggled.connect(func(on): time_scale = 10.0 if on else 1.0)
	sleep_panel = SleepPanel.new()
	ui.add_child(sleep_panel)
	sleep_panel.finished.connect(_on_sleep_finished)
	morning = MorningOverlay.new()
	ui.add_child(morning)
	morning.done.connect(func(): _toast(GameState.clock.segment_name()))


func _modal_open() -> bool:
	return dialogue.visible or notebook.visible or sleep_panel.visible or morning.visible


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
		_open_notebook()
	elif event.is_action_pressed("interact"):
		var best := ""
		var best_d := Village.INTERACT_RANGE * 1.4
		for id in Village.SPOTS.keys() + ["furball"]:
			var d: float = village.player_pos.distance_to(village.spot_pos(id))
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


func _open_notebook() -> void:
	notebook.open()


# ── 상호작용 ──────────────────────────────────────

func _interact(id: String) -> void:
	_talking_to = id
	var gs := GameState
	if Content.NPCS.has(id):
		var npc: Dictionary = Content.NPCS[id]
		var res: Dictionary = gs.talk(id)
		var opts := []
		if gs.activity_available(id):
			opts.append({"id": "activity", "label": npc.activity.label, "primary": true})
		elif npc.activity.get("evening_only", false) and gs.relationships.stage(id) >= int(npc.activity.get("min_stage", 0)) \
				and gs.happiness.times_done("act_" + npc.activity.id) == 0:
			res.line += "\n(저녁에 다시 오면 %s 할 수 있다.)" % npc.activity.label.trim_suffix("하기")
		if gs.can_greet_from_notebook(id):
			opts.append({"id": "greet", "label": "공책에 적힌 대로 인사하기"})
		opts.append({"id": "close", "label": "그럼 또 봬요"})
		var speaker: String = "%s · 나를 '%s'" % [npc.name, res.title] if res.title != "…" else npc.name
		dialogue.open(speaker, res.line, opts, res.hint)
	elif id == "furball":
		dialogue.open("털뭉치", gs.pet_furball(), [{"id": "close", "label": "알았어"}])
	elif id == "hearth":
		var done: bool = gs.happiness.times_done("cook") > 0
		dialogue.open("화덕", "오늘은 이미 수프를 끓였다." if done else "빛버섯이 조금 남아 있다.",
			[{"id": "cook", "label": Content.OBJECTS.hearth.label, "primary": true}, {"id": "close", "label": "그만두기"}])
	elif id == "home":
		dialogue.open("내 집", "창문이 나무 쪽으로 나 있다.",
			[{"id": "sleep", "label": Content.OBJECTS.home.label, "primary": true}, {"id": "close", "label": "아직 아니야"}])


func _on_dialogue_choice(option: String) -> void:
	var gs := GameState
	var id := _talking_to
	match option:
		"close":
			dialogue.hide()
		"activity":
			gs.do_activity(id)
			var a: Dictionary = Content.NPCS[id].activity
			dialogue.open(Content.NPCS[id].name, a.log, [{"id": "close", "label": "좋았다"}])
		"greet":
			var s: int = gs.greet_from_notebook(id)
			dialogue.open("%s · 나를 '%s'" % [Content.NPCS[id].name, Content.npc_title(id, s)],
				"공책에 적힌 대로 인사했다. 잠깐 놀란 얼굴이더니, 금세 웃었다.", [{"id": "close", "label": "다행이다"}])
		"cook":
			gs.cook()
			dialogue.open("화덕", Content.OBJECTS.hearth.log, [{"id": "close", "label": "맛없다면서…"}])
		"sleep":
			dialogue.hide()
			_start_sleep()


func _start_sleep() -> void:
	dialogue.hide()
	notebook.hide()
	village.cancel_walk()
	sleep_panel.open()


func _on_sleep_finished(choice: String) -> void:
	var r: Dictionary = GameState.end_day(choice)
	village.player_pos = Vector2(0, 150)
	village.furball_pos = Vector2(-40, 170)
	camera.reset_smoothing()
	morning.open("forget" if r.learned_rule else "")


func _toast(text: String) -> void:
	toast.text = text
	var t := create_tween()
	t.tween_property(toast, "modulate:a", 1.0, 0.25)
	t.tween_interval(2.2)
	t.tween_property(toast, "modulate:a", 0.0, 0.6)


# ── 개발용 ────────────────────────────────────────

func _check(cond: bool, msg: String) -> void:
	if not cond:
		printerr("SMOKE FAIL: " + msg)
		get_tree().quit(1)


func _run_smoke() -> void:
	await get_tree().process_frame
	_check(morning.visible, "morning overlay on start")
	morning.hide()
	for i in 30:
		village.move_input = Vector2(1, 0)
		await get_tree().process_frame
	for id in ["halmeoni", "moru", "gussi", "furball", "hearth"]:
		_interact(id)
		_check(dialogue.visible, "dialogue opens for " + id)
		if id == "hearth":
			_on_dialogue_choice("cook")
		_on_dialogue_choice("close")
	for id in ["halmeoni", "moru", "gussi"]:
		_interact(id)
		_on_dialogue_choice("close")
	GameState.clock.skip_to_evening()
	_interact("moru")
	_on_dialogue_choice("activity")
	_on_dialogue_choice("close")
	_check(GameState.happiness.is_full(), "party day is a very good day")
	notebook.open()
	await get_tree().process_frame
	notebook.hide()
	_start_sleep()
	_check(sleep_panel.visible, "sleep panel")
	sleep_panel._finish("sleep")
	_check(GameState.cycle == 2, "forgot after the party")
	_check(morning.visible, "morning after forgetting")
	print("SMOKE OK")
	get_tree().quit(0)


func _take_shot(scene: String, out: String) -> void:
	DisplayServer.window_set_size(Vector2i(720, 1280))
	await get_tree().process_frame
	morning.hide()
	var gs := GameState
	match scene:
		"village", "dialogue", "notebook":
			for id in ["halmeoni", "moru", "gussi"]:
				gs.talk(id)
				gs.talk(id)
			gs.cook()
			gs.clock.elapsed = gs.clock.segment_seconds * 1.4
			village.player_pos = Vector2(120, 210)
			if scene == "dialogue":
				gs.clock.skip_to_evening()
				_interact("moru")
			elif scene == "notebook":
				notebook.open()
		"sleep":
			_make_good_day_twice()
			_start_sleep()
			sleep_panel._show_decision()
		"morning":
			for id in ["halmeoni", "moru", "gussi"]:
				gs.talk(id)
				gs.talk(id)
			gs.clock.skip_to_evening()
			gs.do_activity("moru")
			gs.cook()
			var r: Dictionary = gs.end_day("sleep")
			morning.open("forget" if r.learned_rule else "")
	for i in 40:
		await get_tree().process_frame
	camera.reset_smoothing()
	await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.save_png(out)
	print("saved ", out)
	get_tree().quit(0)


func _make_good_day_twice() -> void:
	var gs := GameState
	for n in 2:
		for id in ["halmeoni", "moru", "gussi"]:
			gs.talk(id)
			gs.talk(id)
		gs.cook()
		gs.clock.skip_to_evening()
		gs.do_activity("moru")
		if n == 0:
			gs.end_day("sleep")
