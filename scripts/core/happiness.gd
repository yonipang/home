class_name Happiness
extends RefCounted
## 행복 게이지. 플레이어에게 수치로 보이지 않고, 나무 열매·털뭉치 표정으로만 드러난다.
## 같은 행동을 하루에 반복하면 효과가 절반씩 줄어든다.

const MAX := 100.0

var value := 0.0
var _counts: Dictionary = {}


func add(source: String, amount: float) -> float:
	var n: int = _counts.get(source, 0)
	var gained := amount * pow(0.5, n)
	_counts[source] = n + 1
	var before := value
	value = minf(MAX, value + gained)
	return value - before


## 밤 산책 등으로 들뜬 마음을 가라앉힌다.
func calm(amount: float) -> void:
	value = maxf(0.0, value - amount)


func is_full() -> bool:
	return value >= MAX - 0.001


func ratio() -> float:
	return value / MAX


func times_done(source: String) -> int:
	return _counts.get(source, 0)


func new_day() -> void:
	value = 0.0
	_counts.clear()


func to_dict() -> Dictionary:
	return {"value": value, "counts": _counts.duplicate()}


func from_dict(d: Dictionary) -> void:
	value = float(d.get("value", 0.0))
	_counts = d.get("counts", {}).duplicate()
