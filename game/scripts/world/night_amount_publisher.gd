class_name NightAmountPublisher
extends Node
## Publishes a fixed `world_night_amount` to the shader globals for scenes that
## have no live day/night clock (SkyController/DayNight) of their own.
##
## The facade, streetlight and window-emission shaders all read the
## `world_night_amount` global to decide how lit the city is. On a static-sky
## map like miami.tscn nothing sets it, so it stays 0 and the entire neon /
## lit-window identity never appears. Dropping this node in with a dusk value
## (~0.5-0.65) brings the Vice City glow up while the sky still reads warm — the
## iconic magic-hour look — without pulling in a full time-of-day system.
##
## A real SkyController, if later added, publishes the same global every frame
## and (being continuously updated) wins; this is the static stand-in.

## 0 = full daylight, 1 = deep night. Dusk magic hour sits around 0.55.
@export_range(0.0, 1.0) var night_amount: float = 0.55
## Re-publish every frame so it holds even if another one-shot writer clears it.
@export var hold: bool = true


func _ready() -> void:
	_publish()


func _process(_delta: float) -> void:
	if hold:
		_publish()


func _publish() -> void:
	RenderingServer.global_shader_parameter_set("world_night_amount", night_amount)
