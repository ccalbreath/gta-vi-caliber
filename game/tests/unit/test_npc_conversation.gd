extends RefCounted
## Unit tests for NpcConversation — the two-citizen exchange. Alternation,
## length, never-empty lines and determinism are the contract Citizen plays back.


func test_exchange_has_requested_length() -> bool:
	return NpcConversation.exchange("conspiracy", "yogi", 1, 6).size() == 6


func test_exchange_alternates_speakers() -> bool:
	var ex := NpcConversation.exchange("conspiracy", "yogi", 7, 4)
	return (
		ex[0]["speaker"] == 0
		and ex[1]["speaker"] == 1
		and ex[2]["speaker"] == 0
		and ex[3]["speaker"] == 1
	)


func test_exchange_lines_never_empty() -> bool:
	for entry in NpcConversation.exchange("mime", "weather", 3, 8):
		if String(entry["text"]) == "":
			return false
	return true


func test_exchange_is_deterministic() -> bool:
	var a := NpcConversation.exchange("philosopher", "food_critic", 42, 4)
	var b := NpcConversation.exchange("philosopher", "food_critic", 42, 4)
	for i in a.size():
		if a[i]["text"] != b[i]["text"]:
			return false
	return true


func test_exchange_minimum_one_turn() -> bool:
	return NpcConversation.exchange("yogi", "yogi", 0, 0).size() == 1


func test_greeting_is_nonempty_and_stable() -> bool:
	var g := NpcConversation.greeting("influencer", 5)
	return g != "" and g == NpcConversation.greeting("influencer", 5)
