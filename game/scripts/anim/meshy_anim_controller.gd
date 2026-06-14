class_name MeshyAnimController
extends Node
## Drives a Meshy-rigged character's own AnimationPlayer directly, with no
## retargeting: every Meshy biped shares one 24-bone skeleton, so the merged clip
## library on the MC plays unchanged on the MC and on every NPC built from the
## same rig. This replaces the old CC0 RetargetModifier path.
##
## The same controller serves the player and NPCs. The owner feeds it a planar
## speed and a grounded flag each frame for locomotion, and calls play_action()
## for one-shots (melee, reload, wave, talk, react). Clips the model does not yet
## carry resolve to no-ops, so the controller is safe before the full set exists.
##
## Canonical names (left column of CLIPS) are the stable game-facing API; the
## right column maps to whatever Meshy named the clip, so regenerating the
## library only touches this table.

signal action_finished(canonical: String)

enum Mode { GROUND, AIR, ACTION }

## Canonical action/state name -> clip name as it imports from the Meshy GLB.
## Add a row here when a new Meshy clip lands; callers only ever use the keys.
const CLIPS := {
	"idle": "Idle_4",
	"walk": "Walking",
	"run": "Running",
	"run_alt": "Run_02",
	"walk_back": "Walk_Backward",
	"turn_left": "Walk_Turn_Left",
	"turn_right": "Walk_Turn_Right",
	"jump": "Regular_Jump",
	"fall": "Fall2",
	"reload": "Standing_Reload",
	"run_and_gun": "Run_and_Shoot",
	"melee": "Punch_Combo",
	"melee_1": "Punch_Combo_1",
	"melee_3": "Punch_Combo_3",
	"melee_5": "Punch_Combo_5",
	"hit_melee": "Face_Punch_Reaction",
	"hit_gun": "Gunshot_Reaction",
	"get_up": "Stand_Up4",
	"wave": "Big_Wave_Hello",
	"wave_one": "Wave_One_Hand",
	"talk": "Talk_Passionately",
	"talk_open": "Talk_with_Hands_Open",
	"talk_raised": "Talk_with_Left_Hand_Raised",
	"look_around": "Look_Around_Dumbfounded",
	"phone": "Phone_Call_Gesture",
	"phone_talk": "Phone_Conversation",
	"phone_walk": "Walking_with_Phone",
	"texting_walk": "Texting_Walk",
	"idle_var": "Shrug",
}

## Looping states. Everything else plays once and returns to locomotion.
const LOOPING := ["idle", "walk", "run", "run_alt", "fall", "walk_back"]

## Planar speed (m/s) at or below which the character reads as standing.
@export var idle_speed: float = 0.2
## Planar speed (m/s) at which locomotion switches from walk to run. Set
## between the character's walk and sprint speeds (player walks 5.0, sprints 8.5).
@export var run_speed: float = 6.5
## Crossfade time (s) between locomotion states.
@export var locomotion_blend: float = 0.18
## Default crossfade time (s) into a one-shot action.
@export var action_blend: float = 0.12
## Optional explicit AnimationPlayer; auto-found from the owner when left empty.
@export var animation_player: AnimationPlayer = null

var _ap: AnimationPlayer = null
var _mode: int = Mode.GROUND
var _loco: String = ""  # canonical locomotion clip currently requested


func _ready() -> void:
	_ap = animation_player if animation_player != null else _find_player()
	if _ap == null:
		push_warning("MeshyAnimController: no AnimationPlayer found under owner")
		return
	_apply_loops()
	_ap.animation_finished.connect(_on_finished)
	_play("idle")
	_mode = Mode.GROUND


## Call every frame from the owner. speed is the planar (XZ) velocity length in
## m/s; grounded is false while airborne. While a one-shot action is playing this
## is ignored until the action finishes, so triggered moves are not cut off.
func update_locomotion(speed: float, grounded: bool) -> void:
	if _ap == null or _mode == Mode.ACTION:
		return
	if not grounded:
		if _mode != Mode.AIR:
			_mode = Mode.AIR
			if not _play("fall"):
				_play("jump")
		return
	if _mode == Mode.AIR:
		_mode = Mode.GROUND
		_loco = ""  # force a fresh locomotion pick now that we have landed
	_mode = Mode.GROUND
	_ground(speed)


## Play a one-shot action by canonical name (melee, reload, wave, talk, react...).
## Returns false if the model does not carry that clip yet, so callers can branch
## without guessing what the current library contains. Locomotion resumes
## automatically when the action ends.
func play_action(canonical: String, blend: float = -1.0) -> bool:
	if _ap == null or not has_clip(canonical):
		return false
	_mode = Mode.ACTION
	_play(canonical, blend if blend >= 0.0 else action_blend)
	return true


## Takeoff helper for a jumping player: plays the jump clip and enters the air
## state. NPCs that never jump simply never call this.
func jump() -> void:
	if _ap == null:
		return
	_mode = Mode.AIR
	if not _play("jump"):
		_play("fall")


## True when the loaded model actually carries the clip behind a canonical name.
func has_clip(canonical: String) -> bool:
	if not CLIPS.has(canonical):
		return false
	return _ap != null and _ap.has_animation(CLIPS[canonical])


func _ground(speed: float) -> void:
	var want := "idle"
	if speed > run_speed:
		want = "run"
	elif speed > idle_speed:
		want = "walk"
	if want != _loco:
		_loco = want
		_play(want, locomotion_blend)


func _play(canonical: String, blend: float = -1.0) -> bool:
	if not has_clip(canonical):
		return false
	_ap.play(CLIPS[canonical], blend)
	return true


func _on_finished(_anim: String) -> void:
	if _mode == Mode.ACTION:
		_mode = Mode.GROUND
		_loco = ""  # re-pick locomotion on the next update_locomotion call
		action_finished.emit(_canonical_of(_anim))


func _apply_loops() -> void:
	for canonical in CLIPS:
		var clip := _ap.get_animation(CLIPS[canonical])
		if clip == null:
			continue
		clip.loop_mode = Animation.LOOP_LINEAR if canonical in LOOPING else Animation.LOOP_NONE


func _canonical_of(clip_name: String) -> String:
	for canonical in CLIPS:
		if CLIPS[canonical] == clip_name:
			return canonical
	return clip_name


func _find_player() -> AnimationPlayer:
	var root := owner if owner != null else get_parent()
	if root == null:
		return null
	for node in root.find_children("*", "AnimationPlayer", true, false):
		return node as AnimationPlayer
	return null
