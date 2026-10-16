extends Node2D
const State = preload("res://scripts/world_state.gd")
const Prop = preload("res://scripts/pixel_prop.gd")
const Ground = preload("res://scripts/ground.gd")
const SAVE_PATH := "user://mosslight-v1.json"
var save_path: String = SAVE_PATH
@export_range(50, 200) var move_speed: float = 115.0
@export_range(1, 3) var view_zoom: float = 1.8
@export var ambient_color := Color(0.55, 0.65, 0.62)
var state = State.new()
var ground: Node2D
var props: Node2D
var lights: Node2D
var avatar: Node2D
var camera: Camera2D
var ambient: CanvasModulate
var marker: Node2D
var selected: String = "mine"
var rotation_index: int = 0
var target := Vector2i(18,14)
var facing := Vector2(0,-1)
var touch_move := Vector2.ZERO
var mouse_aim: bool = false
var use_timer: float = 0
var clock: float = 0
var hud: Control
var info: Label
var notice: Label
var objective: Label
var toolbar: HBoxContainer
var status: Label
var tools_by_name: Dictionary = {}
var light_texture: GradientTexture2D
var walking: bool = false
var walk_distance: float = 0.0

func _ready() -> void:
	get_window().min_size = Vector2i(360,640)
	ground = Ground.new()
	ground.state = state
	add_child(ground)
	props = Node2D.new()
	props.y_sort_enabled = true
	add_child(props)
	lights = Node2D.new()
	add_child(lights)
	ambient = CanvasModulate.new()
	ambient.color = ambient_color
	add_child(ambient)
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color(1,1,1,1),Color(1,1,1,0)])
	light_texture = GradientTexture2D.new()
	light_texture.gradient = gradient
	light_texture.width = 256
	light_texture.height = 256
	light_texture.fill = GradientTexture2D.FILL_RADIAL
	light_texture.fill_from = Vector2(0.5,0.5)
	light_texture.fill_to = Vector2(1,0.5)
	camera = Camera2D.new()
	camera.zoom = Vector2.ONE * view_zoom
	camera.position = state.player
	add_child(camera)
	marker = Node2D.new()
	marker.z_index = 10
	marker.draw.connect(draw_target)
	add_child(marker)
	make_hud()
	rebuild()
	get_viewport().size_changed.connect(layout_hud)
	layout_hud()
	layout_hud.call_deferred()
	notify("이끼 동굴에 온 걸 환영해요 · 돌벽을 3번 캐 보세요")
	if "--smoke" in OS.get_cmdline_user_args(): smoke_test.call_deferred()
	if "--capture" in OS.get_cmdline_user_args(): capture.call_deferred()

func add_light(at: Vector2, color: Color, energy: float, scale_value: float) -> void:
	var light := PointLight2D.new()
	light.texture = light_texture
	light.position = at
	light.color = color
	light.energy = energy
	light.texture_scale = scale_value
	light.shadow_enabled = true
	light.shadow_color = Color(0.05,0.08,0.06,0.65)
	lights.add_child(light)

func rebuild() -> void:
	for node in props.get_children():
		props.remove_child(node)
		node.queue_free()
	for node in lights.get_children():
		lights.remove_child(node)
		node.queue_free()
	for p in state.walls:
		var item = make_prop(p,"wall",0)
		item.variant = p.x * 7 + p.y * 13
		item.front_exposed = not state.walls.has(p + Vector2i.DOWN)
		item.damaged = int(state.hits.get(p,0))
		var occluder := LightOccluder2D.new()
		var polygon := OccluderPolygon2D.new()
		polygon.polygon = PackedVector2Array([Vector2(-16,-18),Vector2(16,-18),Vector2(16,0),Vector2(-16,0)])
		occluder.occluder = polygon
		item.add_child(occluder)
	for p in state.objects:
		var object: Dictionary = state.objects[p]
		var item = make_prop(p,object.kind,object.rotation)
		if object.kind == "tree":
			add_light(item.position+Vector2(0,-30),Color("b8dba1"),0.85,1.5)
		elif state.definitions.get(object.kind,{}).get("light",false):
			add_light(item.position+Vector2(0,-24),Color("ffcf89"),1.1,1.0)
	avatar = Prop.new()
	avatar.kind = "player"
	avatar.position = state.player
	props.add_child(avatar)
	ground.queue_redraw()
	update_hud()

func make_prop(p: Vector2i, kind: String, turn: int) -> Node2D:
	var item = Prop.new()
	item.kind = kind
	item.turn = turn
	item.position = Vector2(p)*32+Vector2(16,32 if kind == "wall" else 24)
	props.add_child(item)
	return item

func _process(dt: float) -> void:
	clock += dt
	use_timer = maxf(0,use_timer-dt)
	var movement := touch_move
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP): movement.y -= 1
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN): movement.y += 1
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT): movement.x -= 1
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT): movement.x += 1
	movement = movement.limit_length()
	walking = movement.length() > 0.01
	if walking:
		facing = movement
	var previous_position: Vector2 = state.player
	state.walk(movement * move_speed * minf(dt,0.05))
	var distance_walked: float = previous_position.distance_to(state.player)
	walk_distance += distance_walked
	walking = distance_walked > 0.01
	avatar.position = state.player.round()
	avatar.moving = walking
	avatar.clock = walk_distance / 60.0
	avatar.facing = facing
	avatar.queue_redraw()
	camera.position = state.player.round()
	if mouse_aim:
		target = state.cell(get_global_mouse_position())
	else:
		target = state.cell(state.player + facing * 36)
	marker.queue_redraw()
	ground.time = clock
	if Engine.get_process_frames() % 12 == 0: ground.queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and event.device != InputEvent.DEVICE_ID_EMULATION:
		mouse_aim = true
	if event is InputEventScreenTouch and event.pressed:
		mouse_aim = true
		target = state.cell(get_global_mouse_position())
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			mouse_aim = true
			target = state.cell(get_global_mouse_position())
			act()
		elif event.button_index == MOUSE_BUTTON_RIGHT: act(true)
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_1: choose("mine")
			KEY_2: choose("torch")
			KEY_3: choose("bench")
			KEY_4: choose("planter")
			KEY_R:
				rotation_index = (rotation_index+1)%4
				notify("배치 방향 %d" % (rotation_index+1))
			KEY_E, KEY_SPACE:
				mouse_aim = false
				target = state.cell(state.player+facing*36)
				act()
			KEY_Q: act(true)
			KEY_F5: save_world()
			KEY_F9: load_world()
			KEY_L: toggle_light()

func act(recover: bool = false) -> void:
	if use_timer > 0: return
	use_timer = 0.18
	var message: String
	if recover: message = state.retrieve(target)
	elif selected == "mine": message = state.mine(target)
	else: message = state.place(target,selected,rotation_index)
	notify(message)
	rebuild()

func draw_target() -> void:
	var valid: bool = state.reachable(target) and state.walls.has(target) and not state.border(target) if selected == "mine" else state.can_place(target,selected)
	var color := Color("d8d59e") if valid else Color("c07c69")
	var pos := Vector2(target)*32
	marker.draw_rect(Rect2(pos+Vector2(1,1),Vector2(30,30)),Color(color,0.12))
	marker.draw_rect(Rect2(pos+Vector2(1,1),Vector2(30,30)),color,false,1.0)
	if selected != "mine":
		marker.draw_line(pos+Vector2(16,16),pos+Vector2(16,16)+Vector2.UP.rotated(rotation_index*PI/2)*10,color,2)

func choose(kind: String) -> void:
	selected = kind
	update_hud()

func panel_style(color: Color, border_color: Color = Color("44645a")) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border_color
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style

func button(text_value: String, callback: Callable, parent: Node) -> Button:
	var b := Button.new()
	b.text = text_value
	b.custom_minimum_size = Vector2(64,46)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_stylebox_override("normal",panel_style(Color("203a34")))
	b.add_theme_stylebox_override("hover",panel_style(Color("36554a"),Color("c4bd8c")))
	b.add_theme_stylebox_override("pressed",panel_style(Color("506b51"),Color("e8d5a3")))
	b.pressed.connect(callback)
	parent.add_child(b)
	return b

func make_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var theme := Theme.new()
	var font := FontVariation.new()
	font.base_font = load("res://assets/fonts/NotoSansKR.ttf")
	font.variation_opentype = {"wght":500}
	theme.default_font = font
	theme.default_font_size = 15
	hud.theme = theme
	layer.add_child(hud)
	var header := PanelContainer.new()
	header.name = "Header"
	header.add_theme_stylebox_override("panel",panel_style(Color("122b27")))
	hud.add_child(header)
	var column := VBoxContainer.new()
	header.add_child(column)
	var eyebrow := Label.new()
	eyebrow.text = "L A N T E R N   T R E E   /   0 1"
	eyebrow.add_theme_font_size_override("font_size",12)
	eyebrow.modulate = Color("a9c5ad")
	column.add_child(eyebrow)
	var title := Label.new()
	title.text = "이끼빛 쉼터"
	title.add_theme_font_size_override("font_size",26)
	column.add_child(title)
	objective = Label.new()
	objective.custom_minimum_size.x = 280
	objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(objective)
	var actions := HBoxContainer.new()
	actions.name = "Actions"
	hud.add_child(actions)
	button("저장",save_world,actions)
	button("불러오기",load_world,actions)
	button("조명",toggle_light,actions)
	status = Label.new()
	status.name = "Status"
	status.text = "GODOT 2.5D · 시제품"
	status.add_theme_font_size_override("font_size",12)
	status.modulate = Color("b1c9b6")
	hud.add_child(status)
	var bottom := PanelContainer.new()
	bottom.name = "Bottom"
	bottom.add_theme_stylebox_override("panel",panel_style(Color("122b27")))
	hud.add_child(bottom)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation",8)
	bottom.add_child(stack)
	notice = Label.new()
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notice.custom_minimum_size.y = 40
	notice.modulate = Color("e1d9ae")
	stack.add_child(notice)
	info = Label.new()
	stack.add_child(info)
	toolbar = HBoxContainer.new()
	toolbar.add_theme_constant_override("separation",6)
	stack.add_child(toolbar)
	for pair in [["mine","1  곡괭이"],["torch","2  횃불"],["bench","3  작업대"],["planter","4  화분"]]:
		var key: String = pair[0]
		var b := button(pair[1],func(): choose(key),toolbar)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tools_by_name[key] = b
	var hint := Label.new()
	hint.name = "Hint"
	hint.text = "WASD 이동   ·   클릭 채굴/배치   ·   Q 회수   ·   R 회전   ·   F5 저장 / F9 불러오기"
	hint.add_theme_font_size_override("font_size",12)
	hint.modulate = Color("a1b3a2")
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(hint)
	var pad := GridContainer.new()
	pad.name = "Pad"
	pad.columns = 3
	hud.add_child(pad)
	for direction in [Vector2(-1,-1),Vector2.UP,Vector2(1,-1),Vector2.LEFT,Vector2.ZERO,Vector2.RIGHT,Vector2(-1,1),Vector2.DOWN,Vector2(1,1)]:
		if direction == Vector2.ZERO or (direction.x != 0 and direction.y != 0):
			var blank := Control.new()
			blank.custom_minimum_size = Vector2(48,48)
			blank.mouse_filter = Control.MOUSE_FILTER_IGNORE
			pad.add_child(blank)
		else:
			var label: String = "↑" if direction == Vector2.UP else "↓" if direction == Vector2.DOWN else "←" if direction == Vector2.LEFT else "→"
			var b := button(label,func(): pass,pad)
			b.custom_minimum_size = Vector2(48,48)
			b.button_down.connect(func(): touch_move = direction; mouse_aim = false)
			b.button_up.connect(func(): touch_move = Vector2.ZERO)
	var touch_actions := VBoxContainer.new()
	touch_actions.name = "TouchActions"
	hud.add_child(touch_actions)
	button("사용",func(): mouse_aim = false; target = state.cell(state.player+facing*36); act(),touch_actions)
	button("회수",func(): mouse_aim = false; target = state.cell(state.player+facing*36); act(true),touch_actions)
	button("회전",func(): rotation_index = (rotation_index+1)%4,touch_actions)

func layout_hud() -> void:
	var size_value := get_viewport_rect().size
	var narrow := size_value.x < 700
	var header: Control = hud.get_node("Header")
	header.position = Vector2(16,16)
	header.size = Vector2(minf(size_value.x-32,360),126)
	var actions: Control = hud.get_node("Actions")
	actions.position = Vector2(16,152) if narrow else Vector2(size_value.x-262,20)
	hud.get_node("Status").position = Vector2(18,210) if narrow else Vector2(size_value.x-255,75)
	var bottom: Control = hud.get_node("Bottom")
	bottom.position = Vector2(16,size_value.y-194)
	bottom.size = Vector2(minf(size_value.x-32,740),178)
	hud.get_node("Pad").position = Vector2(16,size_value.y-360)
	hud.get_node("TouchActions").position = Vector2(size_value.x-90,size_value.y-354)
	# Keep touch controls available on desktops for emulator testing too.
	camera.zoom = Vector2.ONE * (1.35 if narrow else view_zoom)
	var short_names := {"mine":"곡괭이", "torch":"횃불", "bench":"작업대", "planter":"화분"}
	var index: int = 1
	for key in tools_by_name:
		var b: Button = tools_by_name[key]
		b.text = short_names[key] if narrow else "%d  %s" % [index,short_names[key]]
		index += 1
		b.add_theme_font_size_override("font_size",12 if narrow else 15)
		b.custom_minimum_size.x = 50 if narrow else 110
	# Reapply after the toolbar's minimum width shrinks on a portrait resize.
	bottom.set_deferred("size",Vector2(minf(size_value.x-32,740),178))
	var hint: Label = bottom.get_child(0).get_node("Hint")
	hint.text = "이동 · 사용 · 회수 · 회전" if narrow else "WASD 이동   ·   클릭 채굴/배치   ·   Q 회수   ·   R 회전   ·   F5 저장 / F9 불러오기"

func update_hud() -> void:
	if info == null: return
	var item_name: String = "곡괭이" if selected == "mine" else state.definitions[selected].name
	info.text = "돌 %d   /   %s%s" % [state.stone,item_name,"" if selected == "mine" else " · 돌 %d개" % state.definitions[selected].cost]
	objective.text = "돌벽 캐기 %d / 3   ·   나만의 가구 놓기 %d / 2" % [mini(state.mined,3),mini(state.placed,2)]
	if state.mined >= 3 and state.placed >= 2: objective.text = "작은 쉼터 완성! 더 넓히고 꾸며 보세요."
	for key in tools_by_name:
		tools_by_name[key].modulate = Color("f3d796") if selected == key else Color.WHITE

func notify(message: String) -> void:
	notice.text = message

func toggle_light() -> void:
	ambient.visible = not ambient.visible
	lights.visible = ambient.visible
	notify("조명 켜짐 · 횃불 주변을 비교해 보세요" if ambient.visible else "조명 꺼짐 · 기본 그림 비교")

func save_world() -> void:
	var temp := save_path + ".tmp"
	var file := FileAccess.open(temp,FileAccess.WRITE)
	if file == null:
		notify("저장 실패 · 기기 저장 공간을 확인해 주세요")
		return
	file.store_string(JSON.stringify(state.snapshot()))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK:
		notify("저장 실패 · 이전 저장은 유지돼요")
		return
	var result := DirAccess.rename_absolute(temp,save_path)
	notify("저장했어요 · 위치와 배치한 가구도 기억해요" if result == OK else "저장 파일 교체 실패")

func load_world() -> void:
	if not FileAccess.file_exists(save_path):
		notify("아직 저장한 쉼터가 없어요")
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if not state.restore(data):
		notify("저장을 읽을 수 없어요 · 현재 세계는 유지돼요")
		return
	rebuild()
	notify("저장한 쉼터로 돌아왔어요")

func smoke_test() -> void:
	await get_tree().process_frame
	choose("torch")
	target = Vector2i(19,15)
	act()
	assert(state.objects.has(target))
	assert(lights.get_child_count() == 4)
	toggle_light()
	assert(not ambient.visible)
	toggle_light()
	save_path = "user://test-mosslight-%s.json" % Time.get_ticks_usec()
	var expected: Dictionary = state.snapshot()
	save_world()
	assert(FileAccess.file_exists(save_path))
	state.stone = 0
	load_world()
	assert(state.snapshot() == expected)
	state.stone += 2
	save_world()
	state.stone = 0
	load_world()
	assert(state.stone == int(expected.stone) + 2)
	DirAccess.remove_absolute(save_path)
	print("SCENE SMOKE PASS: HUD, placement, rebuilding, lights, file save/load/overwrite")
	get_tree().quit()

func capture() -> void:
	if "--portrait" in OS.get_cmdline_user_args():
		get_window().size = Vector2i(390,844)
	await get_tree().create_timer(1.5).timeout
	get_viewport().get_texture().get_image().save_png("/tmp/mosslight-capture.png")
	get_tree().quit()
