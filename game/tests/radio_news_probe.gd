extends SceneTree
## Scene-free probe for RadioNewsDirector.
##
## A wanted spike should file a CrimeReactionDirector headline, the radio director
## should self-wire to that headline queue, and the first scheduled NEWS slot should
## air and drain that exact line.
## Run headless:
##   godot --headless --path game --script res://tests/radio_news_probe.gd

const SETTLE_FRAMES: int = 3
const MAX_ADVANCES: int = 200
const RADIO_NEWS_SCRIPT := preload("res://scripts/systems/radio_news_director.gd")

var _crime: CrimeReactionDirector = null
var _radio: Node = null
var _mock: MockWanted = null
var _frames: int = 0
var _aired_news: String = ""


class MockWanted:
	extends Node
	signal stars_changed(stars: int)
	var _stars: int = 0

	func _ready() -> void:
		add_to_group("wanted")

	func stars() -> int:
		return _stars

	func escalate(to_stars: int) -> void:
		_stars = to_stars
		stars_changed.emit(to_stars)


func _initialize() -> void:
	_mock = MockWanted.new()
	root.add_child(_mock)
	_crime = CrimeReactionDirector.new()
	root.add_child(_crime)
	_radio = RADIO_NEWS_SCRIPT.new()
	root.add_child(_radio)
	_radio.configure_program([], [], "VCX News")
	_radio.set_seed(23)
	_radio.connect("news_bulletin_aired", _on_news)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < SETTLE_FRAMES:
		return false
	return _run()


func _on_news(text: String) -> void:
	_aired_news = text


func _run() -> bool:
	if not _radio.has_news_source():
		return _fail("radio did not self-wire to CrimeReactionDirector.news")
	_mock.escalate(4)
	var headline := _crime.news.peek_latest()
	if headline.is_empty():
		return _fail("crime did not file a headline")
	for _i in range(MAX_ADVANCES):
		var line: Dictionary = _radio.advance_program()
		if String(line.get("segment", "")) == "NEWS":
			return _check_news_line(headline, String(line.get("text", "")))
	return _fail("scheduler did not yield a NEWS slot within %d advances" % MAX_ADVANCES)


func _check_news_line(headline: String, text: String) -> bool:
	if text != headline:
		return _fail("NEWS slot aired '%s' instead of '%s'" % [text, headline])
	if _aired_news != headline:
		return _fail("news_bulletin_aired did not emit the headline")
	if _crime.news.has_pending():
		return _fail("headline queue was not drained")
	return _pass(headline)


func _pass(headline: String) -> bool:
	print("radio news probe: OK (aired '%s')" % headline)
	quit(0)
	return true


func _fail(reason: String) -> bool:
	push_error("radio news probe FAIL: %s" % reason)
	quit(1)
	return true
