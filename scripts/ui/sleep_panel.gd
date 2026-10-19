extends PanelContainer
## 하루 마감. 털뭉치가 뿌리에 금을 긋고, 오늘의 한 줄을 고르고, 아주 좋은 날이면 선택지가 나온다.

signal finished(choice: String)

var _tally: RichTextLabel
var _title: Label
var _mono: Label
var _options: VBoxContainer
var _note_written := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_theme_stylebox_override("panel", UIKit.box(UIKit.NIGHT, Color(0, 0, 0, 0), 0, 0, 0))
	var m := MarginContainer.new()
	for side in ["left", "right"]:
		m.add_theme_constant_override("margin_" + side, 40)
	m.add_theme_constant_override("margin_top", 140)
	m.add_theme_constant_override("margin_bottom", 72)
	add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 24)
	m.add_child(v)

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UIKit.box(Color(0, 0, 0, 0), Color(0.29, 0.27, 0.25), 20, 3, 32))
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 12)
	card.add_child(cv)
	_tally = RichTextLabel.new()
	_tally.bbcode_enabled = true
	_tally.fit_content = true
	_tally.scroll_active = false
	_tally.add_theme_font_override("normal_font", UIKit.PEN)
	_tally.add_theme_font_size_override("normal_font_size", 64)
	cv.add_child(_tally)
	_title = UIKit.label("", 28, UIKit.MUTED)
	cv.add_child(_title)
	v.add_child(card)

	_mono = UIKit.label("", 64, UIKit.AMBER, true)
	v.add_child(_mono)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(spacer)
	_options = VBoxContainer.new()
	_options.add_theme_constant_override("separation", 16)
	v.add_child(_options)
	hide()


func open() -> void:
	_note_written = false
	var gs := GameState
	var marks := ""
	for i in gs.day:
		if i == gs.day - 1:
			marks += "[color=#e9b45a]|[/color]"
		else:
			marks += "| "
	_tally.text = "[center]" + marks + "[/center]"
	_title.text = "털뭉치가 뿌리에 %s 금을 그었다. 「삐뚤어.」" % UIKit.day_name(gs.day)
	_mono.text = ""
	show()
	if gs.line_candidates().is_empty():
		_show_decision()
	else:
		_show_line_pick()


func _clear() -> void:
	for c in _options.get_children():
		c.queue_free()


func _show_line_pick() -> void:
	_clear()
	_options.add_child(UIKit.label("오늘의 한 줄 고르기", 26, UIKit.MUTED))
	for text in GameState.line_candidates():
		var b := UIKit.button(text, false, true)
		b.add_theme_font_override("font", UIKit.PEN)
		b.add_theme_font_size_override("font_size", 40)
		var t: String = text
		b.pressed.connect(func(): GameState.choose_line(t); _show_decision())
		_options.add_child(b)
	var skip := UIKit.button("고르지 않기", false, true)
	skip.pressed.connect(_show_decision)
	_options.add_child(skip)


func _show_decision() -> void:
	_clear()
	var gs := GameState
	if gs.night_choices_available():
		_mono.text = Content.GOOD_DAY_MONOLOGUE
		var sleep := UIKit.button("그대로 잠들기", true, true, "내일 아침, 잊을 수도 있다")
		sleep.pressed.connect(func(): _finish("sleep"))
		_options.add_child(sleep)
		var walk := UIKit.button("밤 산책하기", false, true, "들뜬 마음을 가라앉힌다 · 털뭉치의 빛이 조금 준다")
		walk.pressed.connect(func(): _finish("walk"))
		_options.add_child(walk)
		if not _note_written:
			var note := UIKit.button("내일의 나에게 쪽지 쓰기", false, true, "「%s」" % Content.NOTE_TO_SELF)
			note.pressed.connect(func():
				GameState.write_note_to_self()
				_note_written = true
				_title.text = "베개 밑에 쪽지를 넣었다."
				_show_decision())
			_options.add_child(note)
	else:
		var sleep := UIKit.button("잠들기", true, true)
		sleep.pressed.connect(func(): _finish("sleep"))
		_options.add_child(sleep)


func _finish(choice: String) -> void:
	hide()
	finished.emit(choice)
