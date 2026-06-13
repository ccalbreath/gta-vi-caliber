class_name PhotoMode
extends RefCounted
## The phone camera / "Instasnap" photo loop — the player-driven content side of
## the social world (the complement to SocialClout, where the world films YOU).
## A framed shot is scored on composition (subject rarity, framing, lighting,
## action, an iconic-landmark bonus); good shots auto-curate into an album, and
## posting one computes a reach + likes that scales with the shot's quality and
## the player's existing following — so a stunning supercar-at-golden-hour shot
## can blow up while a blurry trash-can pic flops.
##
## Pure + deterministic (the UI supplies the composition metrics; this only does
## the scoring math), so it unit-tests headless (tests/unit/test_photo_mode.gd).
## A photo-mode UI calls quality()/capture() while framing, post() to publish; the
## returned reach can seed SocialClout follower growth (post a banger → gain fans),
## making the two systems one content economy. Persisted via to_dict/from_dict.
##
## Shot dict keys (all optional, default 0/false): rarity, framing, lighting,
## action (0..1 floats) and landmark (bool).

## Composition weights (sum to 1.0 before the landmark bonus).
const W_RARITY: float = 0.35
const W_FRAMING: float = 0.25
const W_LIGHTING: float = 0.20
const W_ACTION: float = 0.20
## Iconic-landmark composition bonus (added to the 0..1 base before scaling).
const LANDMARK_BONUS: float = 0.10
## Quality at/above which a shot is worth keeping in the album.
const KEEP_THRESHOLD: int = 40
## Followers that double a post's reach (fame amplifies, like SocialClout).
const FOLLOWER_AMP: float = 10000.0
## Likes earned per unit of reach.
const LIKES_PER_REACH: int = 10

var _album: Array[int] = []
var _total_likes: int = 0

# --- Scoring (pure) ----------------------------------------------------------


## Composition score 0..100 for a framed shot.
func quality(shot: Dictionary) -> int:
	var base := (
		W_RARITY * _f(shot, "rarity")
		+ W_FRAMING * _f(shot, "framing")
		+ W_LIGHTING * _f(shot, "lighting")
		+ W_ACTION * _f(shot, "action")
	)
	if bool(shot.get("landmark", false)):
		base += LANDMARK_BONUS
	return int(round(clampf(base, 0.0, 1.0) * 100.0))


# --- Album -------------------------------------------------------------------


## Snap a shot; it joins the album only if it clears the keep threshold (the phone
## auto-curates the junk). Returns {quality, kept}.
func capture(shot: Dictionary) -> Dictionary:
	var q := quality(shot)
	var kept := q >= KEEP_THRESHOLD
	if kept:
		_album.append(q)
	return {"quality": q, "kept": kept}


func album_size() -> int:
	return _album.size()


func best_quality() -> int:
	var best := 0
	for q in _album:
		best = maxi(best, q)
	return best


# --- Publishing --------------------------------------------------------------


## Post a shot. Reach scales the quality by the player's following; likes follow
## reach. Returns {quality, reach, likes}; accumulates lifetime likes.
func post(shot: Dictionary, followers: int = 0) -> Dictionary:
	var q := quality(shot)
	var amp := 1.0 + float(maxi(followers, 0)) / FOLLOWER_AMP
	var reach := float(q) * amp
	var likes := int(floor(reach * float(LIKES_PER_REACH)))
	_total_likes += likes
	return {"quality": q, "reach": reach, "likes": likes}


func total_likes() -> int:
	return _total_likes


# --- Persistence -------------------------------------------------------------


func to_dict() -> Dictionary:
	return {"album": _album.duplicate(), "total_likes": _total_likes}


func from_dict(data: Dictionary) -> void:
	_album.clear()
	for q in data.get("album", []):
		_album.append(int(q))
	_total_likes = maxi(int(data.get("total_likes", 0)), 0)


func _f(shot: Dictionary, key: String) -> float:
	return clampf(float(shot.get(key, 0.0)), 0.0, 1.0)
