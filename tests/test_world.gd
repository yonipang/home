extends "res://tests/test_base.gd"


func test_dark_posts_shrink_the_light() -> void:
	var w := WorldState.new()
	w.new_day(1, 1)
	var r: Dictionary = w.end_night(false)
	eq(r.shrunk, WorldState.POSTS * WorldState.SHRINK_PER_DARK_POST, "all posts dark shrinks the most")
	w.new_day(1, 2)
	for i in WorldState.POSTS:
		w.items.drop += 1
		w.light_post(i)
	r = w.end_night(false)
	eq(r.shrunk, 0.0, "all posts lit keeps the light")
	eq(w.lit_posts.count(true), 0, "posts go out every night")


func test_drops_limited_per_day() -> void:
	var w := WorldState.new()
	w.new_day(1, 1)
	for i in 10:
		w.take_drop()
	eq(w.items.drop, WorldState.DROPS_PER_DAY, "only a few drops a day")
	check(w.light_post(0), "lighting uses a drop")
	check(not w.light_post(0), "cannot light twice")


func test_nodes_and_house() -> void:
	var w := WorldState.new()
	w.new_day(1, 1)
	eq(w.take_node("wood_0"), "wood", "picks up wood")
	eq(w.take_node("wood_0"), "", "cannot pick twice")
	w.items.wood = 20
	eq(w.give_wood(), WorldState.HOUSE_WOOD, "gives only what the house needs")
	check(w.house_complete(), "house complete")
	eq(w.items.wood, 20 - WorldState.HOUSE_WOOD, "keeps the rest")
	check(w.node_pos(w.find_node("mush_0")).length() < w.radius, "mushrooms grow inside the light")


func test_pumpkin_wilts_if_skipped() -> void:
	var w := WorldState.new()
	w.halmeoni_asked = true
	w.new_day(1, 1)
	check(w.water_pumpkin(), "water day 1")
	check(not w.water_pumpkin(), "once a day")
	w.end_night(false)
	w.new_day(1, 2)
	var r: Dictionary = w.end_night(false)
	check(r.wilted, "skipping a day wilts")
	eq(w.pumpkin_water, 0, "progress lost")


func test_forgetting_keeps_things_but_not_promises() -> void:
	var w := WorldState.new()
	w.new_day(1, 1)
	w.moru_asked = true
	w.house_wood = 5
	w.rod_borrowed = true
	w.items.wood = 2
	w.end_night(true)
	check(not w.moru_asked, "Moru forgets asking")
	check(not w.rod_borrowed, "Gussi forgets lending the rod")
	eq(w.house_wood, 5, "the half-built house stays")
	eq(w.items.wood, 2, "pockets stay")


func test_first_fish_once_per_cycle() -> void:
	var w := WorldState.new()
	w.rod_borrowed = true
	check(not w.record_fish(false), "miss")
	check(w.record_fish(true), "first catch is big")
	check(not w.record_fish(true), "second catch is small")
	check(not w.can_fish(), "three tries a day")


func test_world_round_trip() -> void:
	var w := WorldState.new()
	w.new_day(2, 3)
	w.take_node("wood_1")
	w.house_wood = 4
	w.lit_posts[2] = true
	var w2 := WorldState.new()
	w2.from_dict(JSON.parse_string(JSON.stringify(w.to_dict())))
	eq(w2.house_wood, 4, "house")
	eq(w2.items.wood, 1, "items")
	check(w2.lit_posts[2], "posts")
	check(w2.find_node("wood_1").taken, "taken nodes")
