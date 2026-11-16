class_name ChemistryDB
extends RefCounted

## Banco de dados químico do protótipo: substâncias, receitas de síntese e combinações perigosas.
## Toda a regra da Bancada de Mendeleev vive aqui (sem dependência de UI).

const HEAT_NAMES: Array[String] = ["Desligado", "Baixo", "Médio", "Alto"]

## Nomes descritivos para todos os níveis térmicos (incluindo resfriamento com gelo)
const THERMAL_LEVEL_NAMES: Dictionary = {
	-2: "Gelo Máximo (Congelante)",
	-1: "Esfriando com Gelo",
	0: "Fogo Apagado (Ambiente)",
	1: "Fogo Baixo",
	2: "Fogo Médio",
	3: "Fogo Alto",
}

## Elementos sempre exibidos na bancada (um reservatório por coletável do mapa)
const ELEMENT_ORDER: Array[String] = ["H", "O", "Na", "Cl", "C"]
## Compostos aparecem como reservatório depois de descobertos
const COMPOUND_ORDER: Array[String] = ["H2O", "NaCl", "CO2"]

static var SUBSTANCES: Dictionary = {
	"H": {
		"name": "Hidrogênio", "formula": "H", "kind": "element", "color": Color(0.56, 0.83, 1.0),
		"info": "Gás mais leve do universo. Coletado perto das fontes termais.",
	},
	"O": {
		"name": "Oxigênio", "formula": "O", "kind": "element", "color": Color(1.0, 0.45, 0.45),
		"info": "Gás essencial para a combustão e a respiração. Abundante nas áreas de ventania.",
	},
	"Na": {
		"name": "Sódio", "formula": "Na", "kind": "element", "color": Color(0.93, 0.82, 0.45),
		"info": "Metal alcalino macio e muito reativo. Nunca o misture com água em alta temperatura!",
	},
	"Cl": {
		"name": "Cloro", "formula": "Cl", "kind": "element", "color": Color(0.66, 0.91, 0.42),
		"info": "Ametal gasoso esverdeado e tóxico, da família dos halogênios.",
	},
	"C": {
		"name": "Carbono", "formula": "C", "kind": "element", "color": Color(0.45, 0.44, 0.52),
		"info": "Base da vida e do carvão. Queima com oxigênio quando aquecido.",
	},
	"H2O": {
		"name": "Água", "formula": "H₂O", "kind": "compound", "color": Color(0.25, 0.66, 1.0),
		"info": "O solvente universal. Dissolve as Barreiras de Sal e muda de estado com fogo ou gelo.",
	},
	"NaCl": {
		"name": "Cloreto de Sódio", "formula": "NaCl", "kind": "compound", "color": Color(0.96, 0.95, 0.92),
		"info": "O sal de cozinha. Material das barreiras de Ur-Novem Duo.",
	},
	"CO2": {
		"name": "Dióxido de Carbono", "formula": "CO₂", "kind": "compound", "color": Color(0.79, 0.76, 0.72),
		"info": "Gás produzido pela combustão do carbono em fogo médio ou alto.",
	},
}

## heat_min: nível mínimo de fogo (0 = Desligado ... 3 = Alto) para a reação acontecer.
static var RECIPES: Array[Dictionary] = [
	{
		"product": "H2O", "reagents": {"H": 2, "O": 1}, "heat_min": 1,
		"equation": "2 H + O → H₂O",
		"lesson": "Dois hidrogênios para cada oxigênio! A água é o solvente universal: suas moléculas polares cercam os íons de sódio e cloro e desmontam o sal. É a chave para abrir as Barreiras de Sal.",
	},
	{
		"product": "NaCl", "reagents": {"Na": 1, "Cl": 1}, "heat_min": 0,
		"equation": "Na + Cl → NaCl",
		"lesson": "O sódio (metal) doa um elétron ao cloro (ametal) e nasce uma ligação iônica. Dois elementos perigosos formam juntos o inofensivo sal de cozinha!",
	},
	{
		"product": "CO2", "reagents": {"C": 1, "O": 2}, "heat_min": 2,
		"equation": "C + 2 O → CO₂",
		"lesson": "A combustão do carbono precisa de bastante calor. Ela libera dióxido de carbono, o gás que as plantas usam na fotossíntese.",
	},
]

## Combinações instáveis. Com fogo >= heat_min a bancada explode (derrota no GDD).
static var HAZARDS: Array[Dictionary] = [
	{
		"reagents": ["Na", "H2O"], "heat_min": 2,
		"title": "O laboratório explodiu!",
		"message": "O sódio metálico reage violentamente com a água, liberando hidrogênio e muito calor. Com o fogo alto, o hidrogênio inflamou!\n\nAproveitando o caos, Ur-Novem Duo invadiu o laboratório e destruiu todos os seus reagentes.",
		"warning": "Faíscas e fumaça preta! O sódio reagiu violentamente com a água... por sorte o fogo estava baixo. Com mais calor, isso teria explodido!",
		"cooled_warning": "❄️ O gelo no forno absorveu o calor da reação exotérmica entre o Sódio e a Água, evitando uma explosão! Ainda assim, esses reagentes não formam um composto simples aqui.",
	},
]


static func get_substance(id: String) -> Dictionary:
	return SUBSTANCES.get(id, {"name": id, "formula": id, "kind": "element", "color": Color.WHITE, "info": ""})


static func color_of(id: String) -> Color:
	return get_substance(id)["color"]


static func formula_of(id: String) -> String:
	return get_substance(id)["formula"]


static func name_of(id: String) -> String:
	return get_substance(id)["name"]


static func thermal_name_of(level: int) -> String:
	return String(THERMAL_LEVEL_NAMES.get(clampi(level, -2, 3), "Ambiente"))


## Avalia o conteúdo do caldeirão ({id: quantidade}) com o nível térmico atual (-2..3).
## Retorna {type: "empty" | "explosion" | "needs_heat" | "state_change" | "success" | "fail", ...}
static func evaluate(contents: Dictionary, heat: int) -> Dictionary:
	if contents.is_empty():
		return {"type": "empty"}

	for hazard: Dictionary in HAZARDS:
		if _contains_all(contents, hazard["reagents"]) and heat >= int(hazard["heat_min"]):
			return {"type": "explosion", "title": hazard["title"], "message": hazard["message"]}

	for recipe: Dictionary in RECIPES:
		var k := _multiple_of(contents, recipe["reagents"])
		if k <= 0:
			continue
		if heat < int(recipe["heat_min"]):
			var msg := "A mistura borbulha, mas nada acontece... Parece que falta energia: suba a alavanca para aumentar o fogo."
			if heat < 0:
				msg = "❄️ A mistura está resfriada com gelo! As moléculas têm pouca agitação térmica. Suba a alavanca para aquecer o caldeirão."
			return {
				"type": "needs_heat", "recipe": recipe,
				"message": msg,
			}
		return {"type": "success", "product": recipe["product"], "amount": k, "recipe": recipe}

	# Experimento didático de estados físicos da Água (H2O puro no caldeirão)
	if contents.size() == 1 and int(contents.get("H2O", 0)) > 0:
		if heat < 0:
			return {
				"type": "state_change",
				"state": "solid",
				"message": "❄️ Solidificação! Com o gelo no forno (< 0 °C), a água (H₂O) perde calor e cristaliza no estado SÓLIDO!",
			}
		elif heat >= 2:
			return {
				"type": "state_change",
				"state": "gas",
				"message": "💨 Vaporização! Com o fogo forte (> 100 °C), as moléculas de H₂O se agitam intensamente e passam ao estado GASOSO (vapor)!",
			}
		else:
			return {
				"type": "state_change",
				"state": "liquid",
				"message": "💧 A água (H₂O) está no estado LÍQUIDO. Use a alavanca para Esfriar com Gelo (Sólido) ou Aquecer forte (Vapor)!",
			}

	for recipe: Dictionary in RECIPES:
		if _same_keys(contents, recipe["reagents"]):
			return {
				"type": "fail",
				"message": "Fumaça preta! Os elementos estão certos, mas a proporção %s não fecha. Conte os átomos de cada elemento na fórmula de %s."
					% [ratio_text(contents), name_of(recipe["product"])],
			}

	for hazard: Dictionary in HAZARDS:
		if _contains_all(contents, hazard["reagents"]):
			if heat < 0 and hazard.has("cooled_warning"):
				return {"type": "fail", "message": hazard["cooled_warning"]}
			return {"type": "fail", "message": hazard["warning"]}

	return {"type": "fail", "message": "Fumaça preta! Essa combinação não forma um composto estável."}


## "2 H : 1 O"
static func ratio_text(contents: Dictionary) -> String:
	var parts: PackedStringArray = []
	for id: String in contents:
		parts.append("%d %s" % [contents[id], formula_of(id)])
	return " : ".join(parts)


static func _contains_all(contents: Dictionary, ids: Array) -> bool:
	for id in ids:
		if int(contents.get(id, 0)) <= 0:
			return false
	return true


static func _same_keys(contents: Dictionary, reagents: Dictionary) -> bool:
	if contents.size() != reagents.size():
		return false
	for id in reagents:
		if not contents.has(id):
			return false
	return true


## Retorna k se contents == k * reagents (ex.: 4H + 2O = 2 × H2O); senão 0.
static func _multiple_of(contents: Dictionary, reagents: Dictionary) -> int:
	if not _same_keys(contents, reagents):
		return 0
	var k := -1
	for id in reagents:
		var have := int(contents[id])
		var need := int(reagents[id])
		if have % need != 0:
			return 0
		var factor := have / need
		if k == -1:
			k = factor
		elif k != factor:
			return 0
	return maxi(k, 0)
