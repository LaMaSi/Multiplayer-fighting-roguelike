extends Node
## Autoload "Inp": owns both players' input and polls it first each physics frame
## (autoloads sit above the scene in the tree, so their physics step runs first).
## Keeps polling while the game is paused so menus can be navigated.

var players: Array[PlayerInput] = []

func _init() -> void:
	players = [PlayerInput.new(0), PlayerInput.new(1)]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	ThemeDB.fallback_font = UiKit.body()  # no engine default font anywhere: every draw_string using the fallback gets Rajdhani


func _physics_process(_delta: float) -> void:
	for p in players:
		p.poll()
