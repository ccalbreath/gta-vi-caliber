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
## How fast the hit-marker fades after a confirmed hit (1/s).
@export var hit_marker_decay: float = 3.0

var _controller: Node = null
var _player_health: Node = null
var _mission: Node = null

@onready var _ammo: Label = $Ammo
@onready var _crosshair: Crosshair = $Crosshair
@onready var _health: Label = $Health
@onready var _status: Label = $Status
@onready var _mission_label: Label = $Mission


func _ready() -> void:
	# Defer so the player's WeaponController has registered its group first.
	_ammo.text = ""
	_crosshair.visible = false
	call_deferred("_bind")


func _bind() -> void:
	var found := get_tree().get_nodes_in_group("weapon_controller")
	if not found.is_empty():
		_controller = found[0]
		_controller.hit_confirmed.connect(_on_hit_confirmed)
	var health := get_tree().get_nodes_in_group("player_health")
	if not health.is_empty():
		_player_health = health[0]
	var mission := get_tree().get_nodes_in_group("mission")
	if not mission.is_empty():
		_mission = mission[0]


func _on_hit_confirmed(killed: bool) -> void:
	_crosshair.hit_flash = 1.0
	_crosshair.hit_kill = killed


func _process(delta: float) -> void:
	_update_health()
	if _mission != null:
		_mission_label.text = _mission.hud_text()
	if _controller == null:
		return
	if _crosshair.hit_flash > 0.0:
		_crosshair.hit_flash = maxf(_crosshair.hit_flash - hit_marker_decay * delta, 0.0)
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


func _update_health() -> void:
	if _player_health == null:
		return
	var dead: bool = _player_health.is_dead()
	_status.text = "WASTED" if dead else ""
	_health.text = "HP %d" % int(round(_player_health.fraction() * 100.0))
