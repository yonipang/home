extends RefCounted

var failures: Array = []


func check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func eq(a, b, msg: String) -> void:
	if a != b:
		failures.append("%s (expected %s, got %s)" % [msg, str(b), str(a)])
