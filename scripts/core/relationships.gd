class_name Relationships
extends RefCounted
## 이웃과의 관계. 호감도 숫자는 보여 주지 않고, 이웃이 나를 부르는 말(단계)로만 드러난다.
## 망각하면 전부 처음으로 돌아간다.

const POINTS_PER_STAGE := 2
const MAX_STAGE := 2

var _points: Dictionary = {}


func points(id: String) -> int:
	return _points.get(id, 0)


func stage(id: String) -> int:
	return mini(MAX_STAGE, points(id) / POINTS_PER_STAGE)


## 한 번 교류할 때마다 1점. 바뀐 단계를 돌려준다.
func bump(id: String) -> int:
	_points[id] = points(id) + 1
	return stage(id)


## 공책 기록으로 관계를 되살릴 때 쓴다. 이미 더 높으면 낮추지 않는다.
func restore_stage(id: String, s: int) -> void:
	_points[id] = maxi(points(id), clampi(s, 0, MAX_STAGE) * POINTS_PER_STAGE)


func reset() -> void:
	_points.clear()


func to_dict() -> Dictionary:
	return _points.duplicate()


func from_dict(d: Dictionary) -> void:
	_points.clear()
	for k in d:
		_points[k] = int(d[k])
