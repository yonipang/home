extends Control
## 화면 아래쪽 대화창. 선택지는 엄지가 닿는 아래쪽에 쌓인다.

signal chosen(option_id: String)

var _name: Label
var _body: Label
var _hint: Label
var _options: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var outer := VBoxContainer.new()
	outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	outer.offset_left = 20
	outer.offset_right = -20
	outer.offset_bottom = -36
	outer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(outer)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outer.add_child(spacer)

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UIKit.box(UIKit.PAPER, UIKit.INK, 20, 3, 28))
	outer.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	card.add_child(v)
	_name = UIKit.label("", 26, UIKit.MUTED)
	_body = UIKit.label("", 32)
	_hint = UIKit.label("", 26, UIKit.MUTED)
	_options = VBoxContainer.new()
	_options.add_theme_constant_override("separation", 12)
	for n in [_name, _body, _hint]:
		v.add_child(n)
	v.add_child(_options)
	hide()


## options: [{id, label, primary?}]
func open(speaker: String, text: String, options: Array, hint := "") -> void:
	_name.text = speaker
	_name.visible = speaker != ""
	_body.text = text
	_hint.text = hint
	_hint.visible = hint != ""
	for c in _options.get_children():
		_options.remove_child(c)
		c.queue_free()
	for o in options:
		var b := UIKit.button(o.label, o.get("primary", false))
		var id: String = o.id
		b.pressed.connect(func(): chosen.emit(id))
		_options.add_child(b)
	show()
