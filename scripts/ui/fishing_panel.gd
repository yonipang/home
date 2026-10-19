extends Control
## 낚시 미니게임. 찌가 쑥 가라앉는 순간에 낚아챈다.
## 너무 일찍 누르면 달아나고, 늦으면 놓친다. (서두르면 흩어진다)

signal closed

const WINDOW := 0.75
const WAIT_MIN := 1.6
const WAIT_MAX := 4.5

var _state := ""
var _t := 0.0
var _bite_at := 0.0
var _status: Label
var _pond: Control
var _hook: Button
var _again: Button
var _quit: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.45)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var outer := VBoxContainer.new()
	outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	outer.offset_left = 20
	outer.offset_right = -20
	outer.offset_bottom = -36
	add_child(outer)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outer.add_child(spacer)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UIKit.box(UIKit.PAPER, UIKit.INK, 20, 3, 28))
	outer.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	card.add_child(v)
	v.add_child(UIKit.label("연못 · 구 씨 아저씨의 낚싯대", 26, UIKit.MUTED))
	_pond = Control.new()
	_pond.custom_minimum_size = Vector2(0, 260)
	_pond.draw.connect(_draw_pond)
	v.add_child(_pond)
	_status = UIKit.label("", 32)
	v.add_child(_status)
	_hook = UIKit.button("낚아채기", true)
	_hook.custom_minimum_size = Vector2(0, 140)
	_hook.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hook.add_theme_font_size_override("font_size", 36)
	_hook.button_down.connect(_on_hook)
	v.add_child(_hook)
	_again = UIKit.button("한 번 더", true)
	_again.pressed.connect(start)
	v.add_child(_again)
	_quit = UIKit.button("그만두기")
	_quit.pressed.connect(func(): hide(); closed.emit())
	v.add_child(_quit)
	hide()


func start() -> void:
	_state = "wait"
	_t = 0.0
	_bite_at = randf_range(WAIT_MIN, WAIT_MAX)
	_status.text = "찌를 보고 있다… 서두르면 놓친다."
	_hook.show()
	_again.hide()
	_quit.hide()
	show()


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	if _state == "wait" and _t >= _bite_at:
		_state = "bite"
		_status.text = "지금!"
		Input.vibrate_handheld(120)
	elif _state == "bite" and _t > _bite_at + WINDOW:
		_finish(false, "놓쳤다. 찌가 다시 떠올랐다.")
	_pond.queue_redraw()


func _on_hook() -> void:
	if _state == "wait":
		_finish(false, "너무 일렀다. 물고기가 달아났다.")
	elif _state == "bite":
		_finish(true, "")


func _finish(success: bool, miss_text: String) -> void:
	_state = "done"
	var text: String = GameState.fish_result(success)
	_status.text = text if success else miss_text
	_hook.hide()
	_again.visible = GameState.world.can_fish()
	_quit.show()


func _draw_pond() -> void:
	var s := _pond.size
	var c := s / 2.0
	var pts: PackedVector2Array = []
	for i in 32:
		var a := TAU * i / 32.0
		pts.append(c + Vector2(cos(a) * s.x * 0.46, sin(a) * s.y * 0.42))
	_pond.draw_colored_polygon(pts, Color(0.16, 0.27, 0.32))
	var dip := 0.0
	var wobble := sin(_t * 2.5) * 3.0
	if _state == "bite":
		dip = 18.0
		for k in 3:
			var rr := 20.0 + fmod((_t - _bite_at) * 90.0 + k * 22.0, 70.0)
			_pond.draw_arc(c, rr, 0, TAU, 32, Color(0.85, 0.9, 0.92, 0.5), 2.0)
	elif _state == "wait" and _bite_at - _t < 0.6:
		wobble = sin(_t * 30.0) * 3.0  # 입질 직전 떨림
	var bob := c + Vector2(0, wobble + dip)
	_pond.draw_line(c + Vector2(0, -120), bob + Vector2(0, -14), Color(0.9, 0.9, 0.88, 0.6), 2.0)
	_pond.draw_circle(bob, 12, Color(0.9, 0.35, 0.25) if dip == 0.0 else Color(0.9, 0.35, 0.25, 0.35))
	_pond.draw_circle(bob + Vector2(0, -8), 6, Color(0.95, 0.94, 0.92))
