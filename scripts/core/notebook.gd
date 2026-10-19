class_name Notebook
extends RefCounted
## 공책. 망각해도 사라지지 않는 유일한 기록이며, 게임의 진행 수단이다.

## entries: { cycle, day, text, kind }  kind = "auto" | "chosen" | "note"
var entries: Array = []
## 사람마다 공책에 적힌 가장 깊은 관계 단계
var people: Dictionary = {}
## 알아낸 규칙 id 목록
var rules: Array = []


func add(cycle: int, day: int, text: String, kind := "auto") -> void:
	entries.append({"cycle": cycle, "day": day, "text": text, "kind": kind})


func entries_for(cycle: int, day: int, kind := "") -> Array:
	return entries.filter(func(e): return e.cycle == cycle and e.day == day and (kind == "" or e.kind == kind))


func chosen_line(cycle: int, day: int) -> String:
	var found := entries_for(cycle, day, "chosen")
	return found[0].text if not found.is_empty() else ""


func record_person(id: String, stage: int) -> void:
	people[id] = maxi(int(people.get(id, 0)), stage)


func person_stage(id: String) -> int:
	return int(people.get(id, 0))


## 새로 알게 됐으면 true
func learn_rule(id: String) -> bool:
	if rules.has(id):
		return false
	rules.append(id)
	return true


func knows(id: String) -> bool:
	return rules.has(id)


func to_dict() -> Dictionary:
	return {"entries": entries.duplicate(true), "people": people.duplicate(), "rules": rules.duplicate()}


func from_dict(d: Dictionary) -> void:
	entries = []
	for e in d.get("entries", []):
		entries.append({"cycle": int(e.cycle), "day": int(e.day), "text": str(e.text), "kind": str(e.kind)})
	people = {}
	var p: Dictionary = d.get("people", {})
	for k in p:
		people[k] = int(p[k])
	rules = Array(d.get("rules", []))
