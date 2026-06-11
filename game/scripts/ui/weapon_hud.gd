class_name WeaponHud
extends CanvasLayer
## Crosshair + ammo readout for the equipped weapon.
##
## Observes a WeaponController found via the "weapon_controller" group and polls
## its hud_state() each frame — pure UI, never drives gameplay. Shows nothing
## while holstered. Works in any scene that contains both a player weapon
## controller and this HUD.

## Crosshair gap (px) at zero spread.
@export var base_gap: float = 5.0
## Converts the weapon's spread half-angle (rad) into extra crosshair gap (px).
@export var spread_to_px: float = 1500.0

var _controller: Node = null

@onready var _ammo: Label = $Ammo
@onready var _crosshair: Crosshair = $Crosshair


func _ready() -> void:
	# Defer so the player's WeaponController has registered its group first.
	_ammo.text = ""
	_crosshair.visible = false
	call_deferred("_bind")


func _bind() -> void:
	var found := get_tree().get_nodes_in_group("weapon_controller")
	if not found.is_empty():
		_controller = found[0]


func _process(_delta: float) -> void:
	if _controller == null:
		return
	var state: Dictionary = _controller.hud_state()
	var armed: bool = state.get("armed", false)
	_crosshair.visible = armed
	if not armed:
		_ammo.text = ""
		return
	_ammo.text = (
		"%s   %d / %d" % [state.get("name", ""), state.get("ammo", 0), state.get("reserve", 0)]
	)
	_crosshair.gap = base_gap + float(state.get("spread", 0.0)) * spread_to_px
	_crosshair.queue_redraw()
