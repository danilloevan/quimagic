extends SceneTree

const ChemistryDB = preload("res://scripts/core/chemistry_db.gd")

func _init() -> void:
	print("--- INICIANDO TESTES DA BANCADA QUÍMICA ---")

	# 1. Teste de síntese com calor insuficiente
	var test1 = ChemistryDB.evaluate({"H": 2, "O": 1}, 0)
	assert(test1["type"] == "needs_heat", "Esperava needs_heat sem fogo!")
	print("✔ Teste 1: Síntese de água sem fogo requer calor corretamente.")

	# 2. Teste de proporção incorreta (1 H + 1 O)
	var test2 = ChemistryDB.evaluate({"H": 1, "O": 1}, 1)
	assert(test2["type"] == "fail", "Esperava fail com proporção errada!")
	print("✔ Teste 2: Proporção errada (1 H : 1 O) falha com explicação didática.")

	# 3. Teste de síntese perfeita (2 H + 1 O com fogo baixo) -> H2O
	var test3 = ChemistryDB.evaluate({"H": 2, "O": 1}, 1)
	assert(test3["type"] == "success", "Esperava sucesso ao sintetizar água!")
	assert(test3["product"] == "H2O", "Produto deveria ser H2O")
	print("✔ Teste 3: 2H + O + Fogo Baixo gera H₂O com sucesso!")

	# 4. Teste de proporção múltipla (4 H + 2 O com fogo baixo) -> 2 H2O
	var test4 = ChemistryDB.evaluate({"H": 4, "O": 2}, 1)
	assert(test4["type"] == "success" and test4["amount"] == 2, "Deveria gerar 2 unidades de H2O")
	print("✔ Teste 4: Proporção dobrada (4H + 2O) gera 2x H₂O!")

	# 5. Teste de síntese de Sal (Na + Cl) -> NaCl
	var test5 = ChemistryDB.evaluate({"Na": 1, "Cl": 1}, 0)
	assert(test5["type"] == "success" and test5["product"] == "NaCl", "Deveria gerar NaCl")
	print("✔ Teste 5: Na + Cl sintetiza Sal (NaCl)!")

	# 6. Teste de Hazard do GDD: Sódio metálico + Água com calor alto
	var test6 = ChemistryDB.evaluate({"Na": 1, "H2O": 1}, 2)
	assert(test6["type"] == "explosion", "Na + H2O com fogo deveria explodir!")
	print("✔ Teste 6: Na + H₂O com fogo alto explode o caldeirão (Ur-Novem Duo)!")

	# 7. Teste de Resfriamento com Gelo: H2O solidificando em Gelo (< 0°C)
	var test7 = ChemistryDB.evaluate({"H2O": 1}, -2)
	assert(test7["type"] == "state_change" and test7["state"] == "solid", "H2O com gelo deveria solidificar!")
	print("✔ Teste 7: H₂O resfriado com gelo entra em Solidificação (Estado Sólido)!")

	# 8. Teste de Resfriamento de Reação Exotérmica (Na + H2O com Gelo evita explosão)
	var test8 = ChemistryDB.evaluate({"Na": 1, "H2O": 1}, -1)
	assert(test8["type"] == "fail", "Na + H2O resfriado com gelo não deve explodir!")
	print("✔ Teste 8: Na + H₂O resfriado com gelo contém a explosão exotérmica!")

	print("--- TODOS OS TESTES QUÍMICOS PASSARAM COM SUCESSO! ---")
	quit(0)
