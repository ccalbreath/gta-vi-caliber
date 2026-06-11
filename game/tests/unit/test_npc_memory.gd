extends RefCounted
## Unit tests for NpcMemory — witnessed-crime recall. Decay, the category
## thresholds, and the recognise gate are what make the city remember you.


func test_decay_reduces_and_clamps() -> bool:
	var m := NpcMemory.decay(1.0, 2.0, 0.1)  # 1.0 - 0.2
	return absf(m - 0.8) < 0.001 and NpcMemory.decay(0.05, 10.0, 0.1) == 0.0


func test_category_thresholds() -> bool:
	return (
		NpcMemory.category(0.9) == "alarmed"
		and NpcMemory.category(0.4) == "uneasy"
		and NpcMemory.category(0.1) == "none"
	)


func test_recognizes_when_remembered_and_near() -> bool:
	return NpcMemory.recognizes(0.8, 5.0, 12.0)


func test_does_not_recognize_when_forgotten() -> bool:
	return not NpcMemory.recognizes(0.1, 2.0, 12.0)


func test_does_not_recognize_when_far() -> bool:
	return not NpcMemory.recognizes(0.9, 40.0, 12.0)
