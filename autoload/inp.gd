extends Node
## Autoload "Inp": owns both players' input and polls it first each physics frame
## (autoloads sit above the scene in the tree, so their physics step runs first).

var players: Array[PlayerInput] = []


func _init() -> void:
	players = [PlayerInput.new(0), PlayerInput.new(1)]


func _physics_process(_delta: float) -> void:
	for p in players:
		p.poll()
