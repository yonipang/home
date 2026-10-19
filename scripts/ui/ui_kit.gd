class_name UIKit
extends RefCounted
## 공통 색·폰트·버튼 스타일. 와이어프레임의 회색조 + 주황 하나를 따른다.

const FONT := preload("res://assets/fonts/GowunDodum-Regular.ttf")
const PEN := preload("res://assets/fonts/NanumPenScript-Regular.ttf")

const INK := Color(0.169, 0.165, 0.153)
const PAPER := Color(0.949, 0.941, 0.922)
const PAPER_OLD := Color(0.902, 0.886, 0.847)
const MUTED := Color(0.541, 0.529, 0.498)
const LINE := Color(0.788, 0.773, 0.733)
const NIGHT := Color(0.078, 0.075, 0.063)
const AMBER := Color(0.914, 0.706, 0.353)
const LIGHT_TEXT := Color(0.949, 0.941, 0.922)

const MIN_TOUCH := 88.0  # 720 기준 88px ≈ 실기기 48dp


static func box(bg: Color, border := Color(0, 0, 0, 0), radius := 16, border_w := 0, pad := 24) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_w)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(pad)
	return s


static func label(text: String, size := 28, color := INK, pen := false) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if pen:
		l.add_theme_font_override("font", PEN)
	return l


## dark=true: 밤 화면용 (밝은 글씨, 밝은 테두리)
static func button(text: String, primary := false, dark := false, sub := "") -> Button:
	var b := Button.new()
	b.text = text if sub == "" else text + "\n" + sub
	b.custom_minimum_size = Vector2(0, MIN_TOUCH)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.add_theme_font_size_override("font_size", 28)
	var fg := LIGHT_TEXT if dark else INK
	var edge := (LIGHT_TEXT if dark else INK) if primary else (Color(0.43, 0.42, 0.38) if dark else LINE)
	var bg := Color(0, 0, 0, 0) if dark else (Color.WHITE if primary else Color(0, 0, 0, 0))
	for st in ["normal", "focus"]:
		b.add_theme_stylebox_override(st, box(bg, edge, 14, 3 if primary else 2, 22))
	b.add_theme_stylebox_override("hover", box(bg.lerp(fg, 0.06), edge, 14, 3 if primary else 2, 22))
	b.add_theme_stylebox_override("pressed", box(bg.lerp(fg, 0.15), edge, 14, 3 if primary else 2, 22))
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, fg)
	return b


## 1 → 첫째, 11 → 열하루째, 23 → 스무사흘째
static func day_name(n: int) -> String:
	var small := ["", "첫째", "둘째", "셋째", "넷째", "다섯째", "여섯째", "일곱째", "여덟째", "아홉째"]
	var units := ["", "하루", "이틀", "사흘", "나흘", "닷새", "엿새", "이레", "여드레", "아흐레"]
	var tens := ["", "열", "스무", "서른", "마흔", "쉰", "예순", "일흔", "여든", "아흔"]
	if n < 10:
		return small[maxi(1, n)]
	if n >= 100:
		return "%d째" % n
	var t := n / 10
	var u := n % 10
	if u == 0:
		return tens[t] + "째"
	return tens[t] + units[u] + "째"
