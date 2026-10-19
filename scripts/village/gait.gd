class_name Gait
extends RefCounted
## 그림 한 장을 걷는 것처럼 보이게 하는 움직임 (화면 전용, 규칙 아님).
## 걸으면 걸음마다 통통 튀고 좌우로 기우뚱하며, 발이 닿을 때 살짝 납작해진다.
## 서 있으면 숨 쉬듯 아주 조금 부풀었다 가라앉는다.

var hop := 5.0          ## 한 걸음에 떠오르는 높이(px)
var stride := 40.0      ## 한 걸음의 길이(px)
var sway := 0.07        ## 좌우 기우뚱 (라디안)
var squash_amount := 0.08

var phase := 0.0
var moving := 0.0       ## 0 = 서 있음, 1 = 걷는 중 (부드럽게 바뀜)
var _squash := 0.0
var _t := 0.0
var _last_step := 0


func update(delta: float, moved: float) -> bool:
	_t += delta
	var speed := moved / maxf(delta, 0.0001)
	moving = move_toward(moving, 1.0 if speed > 20.0 else 0.0, delta * 6.0)
	phase += moved / stride * PI
	if moving < 0.05:
		# 멈추면 다음 걸음이 땅에서 시작하도록 위상을 정리한다
		phase = round(phase / PI) * PI
	_squash = move_toward(_squash, 0.0, delta * 5.0)
	var step := int(floor(phase / PI))
	var landed := step != _last_step and moving > 0.3
	if landed:
		_squash = 1.0
	_last_step = step
	return landed


## 몸이 떠오르는 높이 (그림자는 그대로 두고 몸만 올린다)
func lift() -> float:
	return absf(sin(phase)) * hop * moving


func tilt() -> float:
	return sin(phase) * sway * moving


func scale() -> Vector2:
	var breath := sin(_t * 2.3) * 0.025 * (1.0 - moving)
	var sq := _squash * squash_amount
	return Vector2(1.0 + sq - breath * 0.5, 1.0 - sq + breath)
