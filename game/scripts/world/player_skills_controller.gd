class_name PlayerSkillsController
extends Node
## Owns the player's ONE PlayerSkills — the trainable proficiencies (driving,
## shooting, stamina, strength). Self-wires by group ("player_skills") so a
## TrainingZone (gym, gun range, track) raises them and other systems read the
## resulting bonus (the documented hook, e.g. recoil *= 1 - 0.5*bonus("shooting"),
## handling scaled by bonus("driving")). Drives the tested PlayerSkills model
## (tests/unit/test_player_skills.gd); verified in tests/training_zone_probe.gd.

signal skill_trained(id: String, level: float)

var _skills: PlayerSkills


func _ready() -> void:
	_skills = PlayerSkills.new()
	add_to_group("player_skills")


## Put in a training session on a skill; returns the level GAINED (0 if unknown or
## already maxed). Diminishing returns near mastery live in the model.
func train(id: String, effort: float) -> float:
	if _skills == null:
		return 0.0
	var gain := _skills.train(id, effort)
	if gain > 0.0:
		skill_trained.emit(id, _skills.level(id))
	return gain


## Whether a skill id exists (for a TrainingZone to validate its target).
func has_skill(id: String) -> bool:
	return _skills != null and _skills.has_skill(id)


## Current 0..1 level of a skill.
func level(id: String) -> float:
	return _skills.level(id) if _skills != null else 0.0


## Named tier of a skill ("" if unknown / not ready).
func tier(id: String) -> String:
	return _skills.tier(id) if _skills != null else ""


## 0..1 gameplay bonus a skill confers (what combat / handling reads).
func bonus(id: String) -> float:
	return _skills.bonus(id) if _skills != null else 0.0


## 0..1 average mastery across every skill, for a HUD readout.
func overall_mastery() -> float:
	return _skills.overall_mastery() if _skills != null else 0.0
