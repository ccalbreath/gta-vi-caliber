class_name SocialClout
extends RefCounted
## The player's PUBLIC social-media fame — GTA VI's everyone-is-filming, go-viral
## living world. When the player pulls off something (a flashy crime, a stunt) in
## front of bystanders, they film it; the clip's REACH scales with the act's
## severity, how many witnesses caught it, its flashiness, and the player's
## existing following (fame snowballs). Past a threshold the clip goes VIRAL:
## followers jump — but the clip is also EVIDENCE, so it returns a heat tip the
## caller feeds to WantedSystem. Followers unlock sponsorship income and make the
## player more recognizable (harder to lie low).
##
## Distinct from CrimeNotoriety (underworld FEAR/rep that gates hiring + shop
## prices): SocialClout is mainstream PUBLIC fame (followers, viral reach,
## sponsorships, recognizability). Pure, deterministic, unit-tested headless
## (tests/unit/test_social_clout.gd). A controller calls record_act() off the same
## witnessed-crime hook CrimeWitness/CrimeNotoriety use, applies the returned
## heat_tip to WantedSystem, credits sponsorship_income() on a day tick, and feeds
## recognizability() into WantedEvasion/Disguise. Persisted via to_dict/from_dict.

## Reach at/above which a clip goes viral.
const VIRAL_THRESHOLD: float = 80.0
## Existing followers that double a clip's reach (fame snowballs): amp = 1 + f/AMP.
const FOLLOWER_AMP: float = 10000.0
## Followers gained per unit of reach on a viral clip.
const GAIN_PER_REACH: float = 3.0
## WantedSystem heat the viral clip tips off (evidence), per unit reach, capped.
const HEAT_TIP_PER_REACH: float = 0.02
const HEAT_TIP_MAX: int = 10
## Sponsorship deals only start once the player is at least "local" famous.
const SPONSOR_MIN_FOLLOWERS: int = 1000
const SPONSOR_PER_1K: int = 10
## Followers at which the player is fully recognizable (recognizability == 1).
const RECOG_FULL_AT: float = 200000.0
## Daily follower attrition when not feeding the algorithm (audiences move on).
const BLEED_PER_DAY: float = 0.01

# Fame-tier follower thresholds (lower bound).
const TIER_LOCAL: int = 1000
const TIER_TRENDING: int = 10000
const TIER_STAR: int = 100000
const TIER_ICON: int = 1000000

var _followers: int = 0


func _init(followers: int = 0) -> void:
	_followers = maxi(followers, 0)


# --- Queries -----------------------------------------------------------------


func followers() -> int:
	return _followers


func fame_tier() -> String:
	if _followers >= TIER_ICON:
		return "icon"
	if _followers >= TIER_STAR:
		return "star"
	if _followers >= TIER_TRENDING:
		return "trending"
	if _followers >= TIER_LOCAL:
		return "local"
	return "unknown"


## Daily passive income from sponsorship deals — zero until "local" fame.
func sponsorship_income() -> int:
	if _followers < SPONSOR_MIN_FOLLOWERS:
		return 0
	return (_followers / 1000) * SPONSOR_PER_1K


## 0..1 — how easily cops/NPCs recognize the player on sight (scales lying low).
func recognizability() -> float:
	return clampf(float(_followers) / RECOG_FULL_AT, 0.0, 1.0)


# --- Mutations ---------------------------------------------------------------


## Someone filmed the player doing something. Returns
## {reach, viral, followers_gained, heat_tip}. A viral clip grows the following
## and tips off WantedSystem heat (it's evidence); a flop does neither.
func record_act(severity: float, witnesses: int, flashiness: float = 1.0) -> Dictionary:
	var amp := 1.0 + float(_followers) / FOLLOWER_AMP
	var reach := maxf(severity, 0.0) * float(maxi(witnesses, 0) + 1) * maxf(flashiness, 0.0) * amp
	var viral := reach >= VIRAL_THRESHOLD
	var gained: int = int(floor(reach * GAIN_PER_REACH)) if viral else 0
	var heat: int = mini(int(floor(reach * HEAT_TIP_PER_REACH)), HEAT_TIP_MAX) if viral else 0
	_followers += gained
	return {"reach": reach, "viral": viral, "followers_gained": gained, "heat_tip": heat}


## Grow the following from a non-crime source (a banger Snapmatic post, a
## sponsorship shout-out). Returns the new follower count.
func add_followers(amount: int) -> int:
	if amount > 0:
		_followers += amount
	return _followers


## Audiences drift when you go quiet: shed a small fraction of followers per day.
func decay(days: float = 1.0) -> int:
	if days <= 0.0 or _followers <= 0:
		return _followers
	var lost := int(floor(float(_followers) * BLEED_PER_DAY * days))
	_followers = maxi(_followers - lost, 0)
	return _followers


# --- Persistence -------------------------------------------------------------


func to_dict() -> Dictionary:
	return {"followers": _followers}


func from_dict(data: Dictionary) -> void:
	_followers = maxi(int(data.get("followers", 0)), 0)
