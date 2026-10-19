extends PanelContainer
## 아침에 깨어나는 화면. 망각한 아침이면 「어, 깼네.」, 아니면 「늦잠 잤잖아.」

signal done

var _day: Label
var _line: Label
var _extra: Label
var _rule: PanelContainer
var _rule_text: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_theme_stylebox_override("panel", UIKit.box(Color(0.02, 0.02, 0.018), Color(0, 0, 0, 0), 0, 0, 0))
	var m := MarginContainer.new()
	for side in ["left", "right"]:
		m.add_theme_constant_override("margin_" + side, 48)
	m.add_theme_constant_override("margin_top", 220)
	m.add_theme_constant_override("margin_bottom", 72)
	add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 28)
	m.add_child(v)
	_day = UIKit.label("", 30, UIKit.MUTED)
	_line = UIKit.label("", 48, UIKit.LIGHT_TEXT)
	_extra = UIKit.label("", 28, UIKit.MUTED)
	v.add_child(_day)
	v.add_child(_line)
	v.add_child(_extra)
	_rule = PanelContainer.new()
	_rule.add_theme_stylebox_override("panel", UIKit.box(UIKit.PAPER, Color(0, 0, 0, 0), 16, 0, 28))
	var rv := VBoxContainer.new()
	rv.add_child(UIKit.label("공책 · 알아낸 것", 24, UIKit.MUTED))
	_rule_text = UIKit.label("", 40, UIKit.INK, true)
	rv.add_child(_rule_text)
	_rule.add_child(rv)
	v.add_child(_rule)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(spacer)
	var go := UIKit.button("일어나기", true, true)
	go.alignment = HORIZONTAL_ALIGNMENT_CENTER
	go.pressed.connect(func(): hide(); done.emit())
	v.add_child(go)
	hide()


## learned_rule: 이번에 새로 알게 된 규칙 id ("" 이면 없음)
func open(learned_rule := "") -> void:
	var gs := GameState
	_day.text = UIKit.day_name(gs.day) + " 아침"
	_line.text = "「" + gs.morning_line.replace("\n", "」\n「") + "」"
	if gs.just_forgot:
		_extra.text = "털뭉치가 나를 보고 있다. 여기가 어디인지, 어제 무엇을 했는지 떠오르지 않는다.\n주머니에 몽당연필과 공책이 있다."
	elif gs.day == 1 and gs.cycle == 1:
		_extra.text = "커다란 나무 아래에서 눈을 떴다. 아무것도 기억나지 않는다.\n옆에서 털뭉치가 주먹밥을 먹고 있다."
	else:
		_extra.text = ""
	_rule.visible = learned_rule != ""
	_rule_text.text = Content.RULES.get(learned_rule, "")
	show()
