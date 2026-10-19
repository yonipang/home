extends Control
## 플로팅 조이스틱: 화면 아래쪽을 누르면 그 자리에 나타나고, 손을 떼면 사라진다.
## 짧게 누르고 떼면 '탭'으로 처리해 tapped 신호를 보낸다.

signal tapped(screen_pos: Vector2)

const RADIUS := 110.0
const KNOB := 46.0
const TAP_MOVE := 14.0
const TAP_TIME := 0.35
const ZONE_FROM := 0.5  ## 화면 높이의 이 비율 아래에서만 조이스틱이 생긴다

var vector := Vector2.ZERO
var enabled := true

var _index := -1
var _origin := Vector2.ZERO
var _knob := Vector2.ZERO
var _start_time := 0.0
var _moved := false
var _stick := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _unhandled_input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventScreenTouch:
		if event.pressed and _index == -1:
			_index = event.index
			_origin = event.position
			_knob = event.position
			_start_time = Time.get_ticks_msec() / 1000.0
			_moved = false
			_stick = event.position.y > get_viewport_rect().size.y * ZONE_FROM
			queue_redraw()
		elif not event.pressed and event.index == _index:
			var quick := Time.get_ticks_msec() / 1000.0 - _start_time < TAP_TIME
			if not _moved and quick:
				tapped.emit(event.position)
			release()
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and event.index == _index:
		if event.position.distance_to(_origin) > TAP_MOVE:
			_moved = true
		if _stick:
			var off: Vector2 = (event.position - _origin).limit_length(RADIUS)
			_knob = _origin + off
			vector = off / RADIUS
			queue_redraw()
		get_viewport().set_input_as_handled()


func release() -> void:
	_index = -1
	_stick = false
	vector = Vector2.ZERO
	queue_redraw()


func _draw() -> void:
	if not _stick:
		return
	draw_circle(_origin, RADIUS, Color(0.95, 0.94, 0.92, 0.08))
	draw_arc(_origin, RADIUS, 0, TAU, 48, Color(0.95, 0.94, 0.92, 0.35), 3.0)
	draw_circle(_knob, KNOB, Color(0.95, 0.94, 0.92, 0.45))
