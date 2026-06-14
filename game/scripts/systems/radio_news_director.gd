class_name RadioNewsDirector
extends Node
## Self-wiring bridge between the station programmer and reactive city news.
##
## CrimeReactionDirector already files headlines into NewsBulletin when wanted heat
## rises. RadioScheduler already creates song/DJ/ad/ID/NEWS slots. This node joins
## those two pieces: it finds the live CrimeReactionDirector by group, advances a
## station clock, and whenever the scheduler yields NEWS it drains the next headline
## for the anchor line. No audio assets required; a HUD, debug overlay, or future
## VehicleRadio integration can subscribe to program_line_aired().

signal program_line_aired(text: String, segment: String)
signal news_bulletin_aired(text: String)

const DEFAULT_SONGS: Array[String] = [
	"neon_mirage",
	"chrome_sunset",
	"midnight_drive",
	"causeway_flow",
	"saltwater_pulse",
]
const DEFAULT_ADS: Array[String] = ["sunshine_burger", "coral_bail_bonds"]
const DEFAULT_STATION_ID: String = "WAVE 87.4"

## Seconds between program slots.
@export var tick_interval: float = 12.0
## Station id/readout used for station ID breaks.
@export var station_id: String = DEFAULT_STATION_ID

## Public so tests/future UI can inspect or replace the programming model.
var scheduler: RadioScheduler

var song_ids: Array[String] = DEFAULT_SONGS.duplicate()
var advert_ids: Array[String] = DEFAULT_ADS.duplicate()

var _news_source: NewsBulletin = null
var _rng: RandomNumberGenerator
var _elapsed: float = 0.0
var _last_line: Dictionary = {}


func _init() -> void:
	_rng = RandomNumberGenerator.new()
	_rebuild_scheduler()


func _ready() -> void:
	_rebuild_scheduler()
	add_to_group("radio_news")
	_rng.randomize()
	call_deferred("_connect_news_source")


func _process(delta: float) -> void:
	if delta <= 0.0:
		return
	if _news_source == null:
		_connect_news_source()
	_elapsed += delta
	if _elapsed >= tick_interval:
		_elapsed = 0.0
		advance_program()


## Deterministic seed for probes/replays.
func set_seed(seed_value: int) -> void:
	_rng.seed = seed_value


## Replace the program lineup without touching audio assets.
func configure_program(
	songs: Array, ads: Array, new_station_id: String = DEFAULT_STATION_ID
) -> void:
	song_ids.clear()
	for song in songs:
		song_ids.append(String(song))
	advert_ids.clear()
	for ad in ads:
		advert_ids.append(String(ad))
	station_id = new_station_id
	_rebuild_scheduler()


## Explicit injection point for tests or a future scene that owns a separate queue.
func set_news_source(source: NewsBulletin) -> void:
	_news_source = source


func has_news_source() -> bool:
	return _news_source != null


func pending_news_count() -> int:
	if _news_source == null:
		return 0
	return _news_source.pending_count()


func last_line() -> Dictionary:
	return _last_line.duplicate()


## Advance one scheduled slot and emit/read back the line that should air.
func advance_program() -> Dictionary:
	if scheduler == null:
		_rebuild_scheduler()
	var step := scheduler.advance(_rng)
	var segment := int(step.get("segment", RadioScheduler.Segment.ID))
	var segment_name := scheduler.segment_name(segment)
	var text := _line_for(step)
	_last_line = {"segment": segment_name, "text": text, "id": String(step.get("id", ""))}
	program_line_aired.emit(text, segment_name)
	if segment == RadioScheduler.Segment.NEWS:
		news_bulletin_aired.emit(text)
	return last_line()


func _connect_news_source() -> void:
	var reactor := get_tree().get_first_node_in_group("crime_reaction") as CrimeReactionDirector
	if reactor == null or reactor.news == null:
		return
	set_news_source(reactor.news)


func _rebuild_scheduler() -> void:
	scheduler = RadioScheduler.new(song_ids, advert_ids, station_id)


func _line_for(step: Dictionary) -> String:
	var segment := int(step.get("segment", RadioScheduler.Segment.ID))
	var id := String(step.get("id", ""))
	match segment:
		RadioScheduler.Segment.SONG:
			return "Now playing: %s." % _humanize(id)
		RadioScheduler.Segment.DJ:
			return "DJ break: the city is moving and the phones are lit."
		RadioScheduler.Segment.AD:
			return _ad_line(id)
		RadioScheduler.Segment.NEWS:
			return _news_line()
		RadioScheduler.Segment.ID:
			return "%s. Heat, water, nightlife." % _humanize(id)
		_:
			return "Dead air."


func _news_line() -> String:
	if _news_source == null:
		return NewsBulletin.FILLER
	return _news_source.next_bulletin()


func _ad_line(id: String) -> String:
	if id.is_empty():
		return "Commercial break: a word from our sponsors."
	return "Commercial break: %s." % _humanize(id)


func _humanize(id: String) -> String:
	if id.is_empty():
		return "Radio"
	return id.replace("_", " ").capitalize()
