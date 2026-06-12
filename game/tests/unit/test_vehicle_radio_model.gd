extends RefCounted
## Unit tests for VehicleRadioModel (see tests/run_tests.gd for the runner
## contract: test_* methods return true to pass).


func _two_station_radio() -> VehicleRadioModel:
	# Deterministic fixture: short durations so rollover math is easy to read.
	var radio := VehicleRadioModel.new(false)
	radio.set_stations(
		[
			{
				"id": "a",
				"name": "Station A",
				"genre": "test",
				"tracks":
				[
					{"title": "A1", "artist": "Artist A", "duration_sec": 10.0},
					{"title": "A2", "artist": "Artist A", "duration_sec": 20.0}
				]
			},
			{
				"id": "b",
				"name": "Station B",
				"genre": "test",
				"tracks": [{"title": "B1", "artist": "Artist B", "duration_sec": 5.0}]
			}
		]
	)
	return radio


func test_default_seed_has_stations() -> bool:
	var radio := VehicleRadioModel.new()
	return radio.station_count() == 5


func test_default_starts_off_at_first_station() -> bool:
	var radio := VehicleRadioModel.new()
	return not radio.is_on() and radio.station_index() == 0


func test_power_on_off_toggles_state() -> bool:
	var radio := VehicleRadioModel.new()
	radio.power_on()
	var was_on := radio.is_on()
	radio.power_off()
	return was_on and not radio.is_on()


func test_toggle_power_returns_new_state() -> bool:
	var radio := VehicleRadioModel.new()
	var on_state := radio.toggle_power()
	var off_state := radio.toggle_power()
	return on_state and not off_state


func test_advance_does_nothing_when_off() -> bool:
	var radio := _two_station_radio()
	radio.advance(100.0)
	return is_equal_approx(radio.track_position(), 0.0) and radio.track_index() == 0


func test_advance_progresses_position_when_on() -> bool:
	var radio := _two_station_radio()
	radio.power_on()
	radio.advance(4.0)
	return is_equal_approx(radio.track_position(), 4.0) and radio.track_index() == 0


func test_track_rolls_over_after_duration() -> bool:
	var radio := _two_station_radio()
	radio.power_on()
	# A1 is 10s; 12s lands 2s into A2.
	radio.advance(12.0)
	return radio.track_index() == 1 and is_equal_approx(radio.track_position(), 2.0)


func test_advance_crosses_multiple_tracks() -> bool:
	var radio := _two_station_radio()
	radio.power_on()
	# A1 (10) + A2 (20) = 30; +5 wraps back to A1 at 5s.
	radio.advance(35.0)
	return radio.track_index() == 0 and is_equal_approx(radio.track_position(), 5.0)


func test_playlist_wraps_on_single_track_station() -> bool:
	var radio := _two_station_radio()
	radio.tune_to(1)  # Station B, single 5s track.
	radio.power_on()
	radio.advance(12.0)  # 12 mod 5 = 2.
	return radio.track_index() == 0 and is_equal_approx(radio.track_position(), 2.0)


func test_next_station_wraps_around() -> bool:
	var radio := _two_station_radio()
	radio.next_station()
	radio.next_station()  # 0 -> 1 -> wrap to 0.
	return radio.station_index() == 0


func test_previous_station_wraps_around() -> bool:
	var radio := _two_station_radio()
	radio.previous_station()  # 0 -> last (1).
	return radio.station_index() == 1


func test_tune_to_wraps_out_of_range() -> bool:
	var radio := _two_station_radio()
	radio.tune_to(5)  # 5 mod 2 = 1.
	var high := radio.station_index()
	radio.tune_to(-1)  # wraps to last.
	return high == 1 and radio.station_index() == 1


func test_switching_station_remembers_position() -> bool:
	var radio := _two_station_radio()
	radio.power_on()
	radio.advance(3.0)  # Station A, 3s in.
	radio.next_station()  # to B
	radio.advance(1.0)  # Station B, 1s in
	radio.previous_station()  # back to A
	return is_equal_approx(radio.track_position(), 3.0)


func test_seek_next_track_resets_position() -> bool:
	var radio := _two_station_radio()
	radio.power_on()
	radio.advance(4.0)
	radio.seek_next_track()
	return radio.track_index() == 1 and is_equal_approx(radio.track_position(), 0.0)


func test_seek_previous_track_wraps() -> bool:
	var radio := _two_station_radio()
	radio.seek_previous_track()  # from track 0 wraps to last (1).
	return radio.track_index() == 1


func test_current_station_and_track_dictionaries() -> bool:
	var radio := _two_station_radio()
	var station := radio.current_station()
	var track := radio.current_track()
	return station.get("name", "") == "Station A" and track.get("title", "") == "A1"


func test_now_playing_off_message() -> bool:
	var radio := _two_station_radio()
	return radio.now_playing_text() == "RADIO OFF"


func test_now_playing_non_empty_when_on() -> bool:
	var radio := _two_station_radio()
	radio.power_on()
	var text := radio.now_playing_text()
	return text.length() > 0 and text.contains("Station A") and text.contains("A1")


func test_empty_station_list_is_safe() -> bool:
	var radio := VehicleRadioModel.new(false)
	radio.set_stations([])
	radio.power_on()
	radio.advance(10.0)
	radio.next_station()
	# No crash, sensible empties.
	return (
		radio.station_count() == 0
		and radio.current_station().is_empty()
		and radio.current_track().is_empty()
		and radio.now_playing_text() == "NO SIGNAL"
	)
