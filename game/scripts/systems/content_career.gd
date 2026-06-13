class_name ContentCareer
extends RefCounted
## The Snapmatic → fame loop, packaged: a `PhotoMode` camera feeding a
## `SocialClout` following. Post a photo and its reach (which scales with the
## shot's quality AND your existing following) converts into new followers — so a
## banger grows your audience, and a bigger audience makes the next post reach
## further. The influencer flywheel that runs parallel to the crime-virality side
## of `SocialClout`.
##
## Pure + deterministic — owns the two models and ties them in one call, so it
## unit-tests headless (tests/unit/test_content_career.gd). A photo-mode UI calls
## post(shot); the returned likes/followers drive the feed + profile. Persisted via
## to_dict/from_dict (nests both models).

## Followers earned per unit of a post's reach.
const FOLLOWERS_PER_REACH: int = 5

var _photos: PhotoMode
var _clout: SocialClout


func _init() -> void:
	_photos = PhotoMode.new()
	_clout = SocialClout.new()


func photos() -> PhotoMode:
	return _photos


func clout() -> SocialClout:
	return _clout


func followers() -> int:
	return _clout.followers()


## Post a framed shot: score + publish it (reach amplified by the current
## following), then convert that reach into new followers. Returns
## {quality, reach, likes, followers_gained, followers}.
func post(shot: Dictionary) -> Dictionary:
	var p := _photos.post(shot, _clout.followers())
	var reach: float = p["reach"]
	var gained := int(floor(reach * float(FOLLOWERS_PER_REACH)))
	_clout.add_followers(gained)
	return {
		"quality": p["quality"],
		"reach": p["reach"],
		"likes": p["likes"],
		"followers_gained": gained,
		"followers": _clout.followers(),
	}


# --- Persistence -------------------------------------------------------------


func to_dict() -> Dictionary:
	return {"photos": _photos.to_dict(), "clout": _clout.to_dict()}


func from_dict(data: Dictionary) -> void:
	_photos.from_dict(data.get("photos", {}))
	_clout.from_dict(data.get("clout", {}))
