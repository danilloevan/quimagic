extends Node

## Estado global do jogo (autoload "GameState"): inventário de elementos/compostos e cartas descobertas.
## Os coletáveis do modo top-down devem chamar GameState.add("H") ao serem pegos.

signal inventory_changed
signal compound_discovered(id: String)

## Estoque inicial zerado: a jogadora coleta os elementos pelo mapa antes de sintetizar na bancada
const STARTING_INVENTORY: Dictionary = {"H": 0, "O": 0, "Na": 0, "Cl": 0, "C": 0}

var inventory: Dictionary = {}
var discovered: Array[String] = []


func _ready() -> void:
	reset_inventory()


func reset_inventory() -> void:
	inventory = STARTING_INVENTORY.duplicate()
	inventory_changed.emit()


func get_count(id: String) -> int:
	return int(inventory.get(id, 0))


func add(id: String, amount: int = 1) -> void:
	inventory[id] = get_count(id) + amount
	inventory_changed.emit()


func take(id: String, amount: int = 1) -> bool:
	if get_count(id) < amount:
		return false
	inventory[id] = get_count(id) - amount
	inventory_changed.emit()
	return true


func is_discovered(id: String) -> bool:
	return discovered.has(id)


## Retorna true se a carta é nova
func discover(id: String) -> bool:
	if discovered.has(id):
		return false
	discovered.append(id)
	compound_discovered.emit(id)
	return true
