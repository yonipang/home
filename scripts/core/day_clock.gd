class_name DayClock
extends RefCounted
## 하루 = 나무의 숨 한 번. 아침·낮·저녁 세 구간. 모든 플랫폼 동일하게 8~12분.

const SEGMENT_NAMES := ["아침", "낮", "저녁"]
const DEFAULT_SEGMENT_SECONDS := 200.0  # 3구간 × 200초 = 10분

var segment_seconds := DEFAULT_SEGMENT_SECONDS
var elapsed := 0.0


func total_seconds() -> float:
	return segment_seconds * SEGMENT_NAMES.size()


## 구간이 바뀌면 새 구간 번호를, 아니면 -1을 돌려준다.
func advance(delta: float) -> int:
	var before := segment()
	elapsed = minf(total_seconds(), elapsed + delta)
	var after := segment()
	return after if after != before else -1


func segment() -> int:
	return mini(SEGMENT_NAMES.size() - 1, int(elapsed / segment_seconds))


func segment_name() -> String:
	return SEGMENT_NAMES[segment()]


func progress() -> float:
	return elapsed / total_seconds()


func is_over() -> bool:
	return elapsed >= total_seconds()


## 나무가 숨 쉬는 밝기. 아침에 밝아져 낮에 가장 밝고 저녁에 가라앉는다. 0.55~1.0
func breath() -> float:
	return 0.55 + 0.45 * sin(progress() * PI)


## 저녁 구간으로 바로 넘긴다 (잔치 등)
func skip_to_evening() -> void:
	elapsed = maxf(elapsed, segment_seconds * 2.0)


## 다음 구간 시작으로 넘긴다 (저녁에서는 넘기지 않음). 넘겼으면 true
func skip_to_next_segment() -> bool:
	if segment() >= SEGMENT_NAMES.size() - 1:
		return false
	elapsed = segment_seconds * float(segment() + 1)
	return true


func reset() -> void:
	elapsed = 0.0
