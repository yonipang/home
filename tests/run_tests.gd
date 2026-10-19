extends SceneTree
## 헤드리스 테스트 실행기.
## godot --headless --script res://tests/run_tests.gd

const SUITES := ["res://tests/test_core.gd", "res://tests/test_game_state.gd"]


func _init() -> void:
	var total := 0
	var failed := 0
	for path in SUITES:
		var suite = load(path).new()
		for m in suite.get_method_list():
			var name: String = m.name
			if not name.begins_with("test_"):
				continue
			total += 1
			suite.failures.clear()
			suite.call(name)
			if suite.failures.is_empty():
				print("  ok   %s :: %s" % [path.get_file(), name])
			else:
				failed += 1
				for f in suite.failures:
					printerr("  FAIL %s :: %s — %s" % [path.get_file(), name, f])
		if suite.has_method("cleanup"):
			suite.cleanup()
	print("%d tests, %d failed" % [total, failed])
	quit(1 if failed > 0 else 0)
