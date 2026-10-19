extends "res://tests/test_base.gd"


func test_happiness_diminishes_for_repeats() -> void:
	var h := Happiness.new()
	eq(h.add("talk", 8.0), 8.0, "first talk")
	eq(h.add("talk", 8.0), 4.0, "second talk is halved")
	eq(h.add("talk", 8.0), 2.0, "third talk is quartered")
	check(not h.is_full(), "not full yet")


func test_happiness_caps_and_resets() -> void:
	var h := Happiness.new()
	h.add("party", 80.0)
	h.add("cook", 50.0)
	check(h.is_full(), "full at cap")
	eq(h.value, 100.0, "capped at 100")
	h.new_day()
	eq(h.value, 0.0, "new day resets")
	eq(h.times_done("party"), 0, "counts reset")


func test_relationship_stages() -> void:
	var r := Relationships.new()
	eq(r.stage("moru"), 0, "starts at 0")
	r.bump("moru")
	eq(r.stage("moru"), 0, "one bump stays 0")
	r.bump("moru")
	eq(r.stage("moru"), 1, "two bumps -> 1")
	for i in 10:
		r.bump("moru")
	eq(r.stage("moru"), 2, "capped at max stage")
	r.reset()
	eq(r.stage("moru"), 0, "reset clears")
	r.restore_stage("moru", 2)
	eq(r.stage("moru"), 2, "restore from notebook")


func test_notebook_records() -> void:
	var n := Notebook.new()
	n.add(1, 3, "지붕을 올렸다.")
	n.add(1, 3, "내 집이 생겼다.", "chosen")
	n.add(2, 1, "다시 깼다.")
	eq(n.entries_for(1, 3).size(), 2, "two entries on day 3")
	eq(n.chosen_line(1, 3), "내 집이 생겼다.", "chosen line")
	n.record_person("moru", 2)
	n.record_person("moru", 1)
	eq(n.person_stage("moru"), 2, "keeps deepest stage")
	check(n.learn_rule("forget"), "learns new rule")
	check(not n.learn_rule("forget"), "does not relearn")


func test_day_clock_segments() -> void:
	var c := DayClock.new()
	c.segment_seconds = 10.0
	eq(c.segment_name(), "아침", "starts in the morning")
	eq(c.advance(9.0), -1, "no change inside segment")
	eq(c.advance(2.0), 1, "moves to 낮")
	c.advance(100.0)
	check(c.is_over(), "day is over")
	eq(c.segment_name(), "저녁", "ends in the evening")
	check(c.breath() >= 0.55 and c.breath() <= 1.0, "breath in range")


func test_josa() -> void:
	eq(Content.josa("모루", "와", "과"), "모루와", "no final consonant")
	eq(Content.josa("할머니", "와", "과"), "할머니와", "no final consonant 2")
	eq(Content.josa("구 씨 아저씨", "와", "과"), "구 씨 아저씨와", "spaces")
	eq(Content.josa("이웃님", "라고", "이라고"), "이웃님이라고", "final consonant")
