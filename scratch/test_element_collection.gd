extends SceneTree

func _init() -> void:
	print("--- INICIANDO TESTE DE COLETA DE ELEMENTOS NO MAPA ---")
	call_deferred("_run_test")


func _run_test() -> void:
	var gs := root.get_node("GameState")
	gs.reset_inventory()

	for id: String in ["H", "O", "Na", "Cl", "C"]:
		assert(gs.get_count(id) == 0, "Estoque inicial de %s deveria ser 0" % id)
	print("✔ Estoque inicial zerado corretamente.")

	var world_scene := load("res://scenes/world/world.tscn") as PackedScene
	var world := world_scene.instantiate()
	root.add_child(world)

	# Aguarda um frame para _ready() de todos os nós (MapGenerator, World, etc.)
	await process_frame

	var pickups := get_nodes_in_group("element_pickups")
	var counts: Dictionary = {"H": 0, "O": 0, "Na": 0, "Cl": 0, "C": 0}
	for p in pickups:
		assert(p != null and p.has_method("setup"), "Nó no grupo element_pickups deve ser ElementPickup")
		assert(world.map_generator.is_world_pos_walkable(p.global_position),
			"Coletável %s em %s não está em terreno caminhável!" % [p.element_id, str(p.global_position)])
		counts[p.element_id] = int(counts.get(p.element_id, 0)) + 1

	assert(counts["H"] == 8, "Esperava 8 H, obteve %d" % counts["H"])
	assert(counts["O"] == 8, "Esperava 8 O, obteve %d" % counts["O"])
	assert(counts["Na"] == 5, "Esperava 5 Na, obteve %d" % counts["Na"])
	assert(counts["Cl"] == 5, "Esperava 5 Cl, obteve %d" % counts["Cl"])
	assert(counts["C"] == 5, "Esperava 5 C, obteve %d" % counts["C"])
	print("✔ Todos os 31 coletáveis (H:8, O:8, Na:5, Cl:5, C:5) gerados em terreno caminhável.")

	# Simula a coleta pela jogadora (2 H + 1 O -> suficiente para H2O)
	var player: Node2D = world.player
	assert(player != null, "Player não encontrado em World")

	var collected_h := 0
	var collected_o := 0
	for p in pickups:
		if p.element_id == "H" and collected_h < 2:
			p._on_body_entered(player)
			collected_h += 1
		elif p.element_id == "O" and collected_o < 1:
			p._on_body_entered(player)
			collected_o += 1

	assert(gs.get_count("H") == 2, "Esperava 2 H após coleta")
	assert(gs.get_count("O") == 1, "Esperava 1 O após coleta")
	assert(world._has_craftable_recipe(), "HUD deveria detectar receita pronta para sintetizar!")
	assert(world._bench_hud_btn.text == "⚗ Bancada Pronta! [B]", "Texto do botão da bancada não atualizou")
	print("✔ Coleta atualizou GameState (2 H, 1 O) e notificou HUD da Bancada!")

	# Verifica síntese na bancada com os itens coletados
	world._open_bench()
	await process_frame
	assert(world.bench_view.visible, "Bancada deveria abrir")
	world.bench_view._on_reservoir_quick_add("H")
	world.bench_view._on_reservoir_quick_add("H")
	world.bench_view._on_reservoir_quick_add("O")
	world.bench_view._set_heat(1)
	world.bench_view._on_synthesize_pressed()

	assert(gs.get_count("H2O") == 1, "Deveria ter sintetizado 1 H2O a partir dos itens coletados!")
	assert(gs.get_count("H") == 0 and gs.get_count("O") == 0, "Reagentes deveriam ter sido consumidos")
	print("✔ Integração completa: Coleta no Mapa -> Bancada -> Síntese de H₂O validada!")

	quit(0)
