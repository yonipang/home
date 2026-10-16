extends SceneTree
const State = preload("res://scripts/world_state.gd")
var checks: int = 0

func check(value: bool, description: String) -> void:
	checks += 1
	if not value:
		push_error("FAIL: " + description)
		quit(1)
		assert(value,description)

func _init() -> void:
	var world = State.new()
	check(world.can_stand(world.player),"spawn has room")
	var wall := Vector2i(18,12)
	var before: int = world.stone
	world.mine(wall)
	check(world.stone == before and world.walls.has(wall),"remote mining rejected")
	world.player = Vector2(18.5,13.5)*32
	world.mine(wall)
	world.mine(wall)
	check(world.walls.has(wall),"wall needs three hits")
	world.mine(wall)
	check(not world.walls.has(wall) and world.stone == before+2,"third hit opens wall and rewards once")
	world.mine(wall)
	check(world.stone == before+2,"empty mining cannot duplicate rewards")
	check(not world.can_place(world.cell(world.player),"bench"),"cannot trap player")
	check(not world.can_place(Vector2i(25,16),"torch"),"cannot place in water")
	check(not world.can_place(wall,"unknown"),"unknown content rejected")
	world.place(wall,"bench",3)
	check(world.objects.has(wall) and world.blocked(wall),"solid furniture blocks movement")
	var paid: int = world.stone
	world.place(wall,"bench",0)
	check(world.stone == paid,"occupied placement is transactional")
	var position_before: Vector2 = world.player
	world.walk(Vector2(0,-32))
	check(world.player == position_before,"collision blocks walking into furniture")
	world.retrieve(wall)
	check(not world.objects.has(wall) and world.stone == before+2,"retrieval refunds exact cost")
	world.place(wall,"torch",1)
	check(not world.blocked(wall),"torch remains passable")
	var loaded = State.new()
	check(loaded.restore(JSON.parse_string(JSON.stringify(world.snapshot()))),"JSON round trip")
	check(loaded.snapshot() == world.snapshot(),"save preserves location, walls, furniture, inventory and goals")
	var valid: Dictionary = loaded.snapshot()
	for broken in [null,{}, {"version":999}, {"version":1,"walls":[],"objects":[],"player":["bad",0]}]:
		check(not loaded.restore(broken),"malformed save rejected")
		check(loaded.snapshot() == valid,"failed load never changes world")
	var blocked_save: Dictionary = world.snapshot()
	blocked_save.player = [1,1]
	check(not loaded.restore(blocked_save),"player inside wall rejected")
	world.stone = 0
	check(not world.can_place(Vector2i(19,13),"bench"),"cost checked before placement")
	print("WORLD TESTS PASS: %d checks" % checks)
	quit()
