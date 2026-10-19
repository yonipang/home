extends PanelContainer
## 공책 (메인 메뉴). 세로: 한 쪽짜리 수첩 + 하단 탭바.

signal closed
signal fast_time_toggled(on: bool)

const TABS := ["오늘", "사람들", "알아낸 것"]

var _header: Label
var _content: VBoxContainer
var _scroll: ScrollContainer
var _tab_buttons: Array = []
var _tab := 0
var _fast := false
var _fast_button: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_theme_stylebox_override("panel", UIKit.box(UIKit.PAPER, Color(0, 0, 0, 0), 0, 0, 0))
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 0)
	add_child(root)

	var top := HBoxContainer.new()
	var top_margin := MarginContainer.new()
	for side in ["left", "right"]:
		top_margin.add_theme_constant_override("margin_" + side, 24)
	top_margin.add_theme_constant_override("margin_top", 56)
	top_margin.add_theme_constant_override("margin_bottom", 12)
	top_margin.add_child(top)
	root.add_child(top_margin)
	var close := UIKit.button("닫기")
	close.custom_minimum_size = Vector2(120, UIKit.MIN_TOUCH)
	close.alignment = HORIZONTAL_ALIGNMENT_CENTER
	close.pressed.connect(func(): hide(); closed.emit())
	top.add_child(close)
	_header = UIKit.label("", 30)
	_header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top.add_child(_header)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var pad := MarginContainer.new()
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right"]:
		pad.add_theme_constant_override("margin_" + side, 40)
	pad.add_theme_constant_override("margin_bottom", 24)
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 10)
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad.add_child(_content)
	_scroll.add_child(pad)
	root.add_child(_scroll)

	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 0)
	var bar_box := PanelContainer.new()
	var bar_style := UIKit.box(UIKit.PAPER, UIKit.LINE, 0, 0, 0)
	bar_style.border_width_top = 3
	bar_style.content_margin_bottom = 36
	bar_box.add_theme_stylebox_override("panel", bar_style)
	bar_box.add_child(bar)
	root.add_child(bar_box)
	for i in TABS.size():
		var b := Button.new()
		b.text = TABS[i]
		b.flat = true
		b.custom_minimum_size = Vector2(0, 96)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 28)
		var idx := i
		b.pressed.connect(func(): _tab = idx; refresh())
		bar.add_child(b)
		_tab_buttons.append(b)
	hide()


func open() -> void:
	refresh()
	show()


func refresh() -> void:
	var gs := GameState
	_header.text = "%s · %s" % [UIKit.day_name(gs.day), gs.clock.segment_name()]
	for i in _tab_buttons.size():
		var c := UIKit.INK if i == _tab else UIKit.MUTED
		for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			_tab_buttons[i].add_theme_color_override(k, c)
	for c in _content.get_children():
		c.queue_free()
	match _tab:
		0: _fill_days()
		1: _fill_people()
		2: _fill_rules()
	_scroll.scroll_vertical = 0


func _section(text: String) -> void:
	var l := UIKit.label(text, 24, UIKit.MUTED)
	l.add_theme_constant_override("line_spacing", 4)
	_content.add_child(l)


func _fill_days() -> void:
	var gs := GameState
	var entries: Array = gs.notebook.entries.duplicate()
	if entries.is_empty():
		_section("아직 아무것도 적지 않았다.")
		_content.add_child(UIKit.label("오늘 있었던 일은 저절로 여기에 적힌다.", 40, UIKit.INK, true))
	entries.reverse()
	var last_key := ""
	for e in entries:
		var key := "%d-%d" % [e.cycle, e.day]
		var old: bool = e.cycle != gs.cycle
		if key != last_key:
			last_key = key
			var head := UIKit.day_name(e.day)
			if old:
				head += " · 이전의 나 (%d번째)" % e.cycle
			_section(head)
		var color := Color(0.43, 0.42, 0.38) if old else UIKit.INK
		var text: String = e.text
		if e.kind == "chosen":
			text = "▶ " + text
		_content.add_child(UIKit.label(text, 42 if e.kind == "chosen" else 38, color, true))
	_content.add_child(HSeparator.new())
	_fast_button = UIKit.button("테스트용: 시간 10배 빠르게 %s" % ("켜짐" if _fast else "꺼짐"))
	_fast_button.pressed.connect(_toggle_fast)
	_content.add_child(_fast_button)


func _toggle_fast() -> void:
	_fast = not _fast
	_fast_button.text = "테스트용: 시간 10배 빠르게 %s" % ("켜짐" if _fast else "꺼짐")
	fast_time_toggled.emit(_fast)


func _fill_people() -> void:
	var gs := GameState
	_section("공책에 적힌 사람들 · 지금 나를 부르는 말")
	var any := false
	for id in Content.NPCS:
		var recorded := gs.notebook.person_stage(id)
		var known := gs.notebook.people.has(id)
		if not known:
			continue
		any = true
		var now := gs.relationships.stage(id)
		var line := "%s — 공책에는 '%s'" % [Content.NPCS[id].name, Content.npc_title(id, recorded)]
		_content.add_child(UIKit.label(line, 40, UIKit.INK, true))
		if gs.relationships.points(id) == 0:
			_content.add_child(UIKit.label("    지금은 나를 모른다.", 26, UIKit.MUTED))
		elif now < recorded:
			_content.add_child(UIKit.label("    지금은 '%s'" % Content.npc_title(id, now), 26, UIKit.MUTED))
	if not any:
		_content.add_child(UIKit.label("아직 아무도 적혀 있지 않다.", 38, UIKit.MUTED, true))


func _fill_rules() -> void:
	var gs := GameState
	_section("알아낸 것")
	if gs.notebook.rules.is_empty():
		_content.add_child(UIKit.label("아직 모르는 게 많다.", 38, UIKit.MUTED, true))
	for r in gs.notebook.rules:
		_content.add_child(UIKit.label(Content.RULES.get(r, r), 40, UIKit.INK, true))
	if gs.tallies.size() > 0:
		_section("뿌리의 금")
		var rows := ""
		for i in gs.tallies.size():
			rows += "%d번째 줄: %d개\n" % [i + 1, gs.tallies[i]]
		rows += "%d번째 줄: %d개 (지금)" % [gs.tallies.size() + 1, gs.day]
		_content.add_child(UIKit.label(rows, 36, UIKit.INK, true))
