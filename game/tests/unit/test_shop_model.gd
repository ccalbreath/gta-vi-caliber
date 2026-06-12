extends RefCounted
## Unit tests for ShopModel (see tests/run_tests.gd for the runner contract:
## test_* methods return true to pass). Concrete numbers, deterministic.


func test_default_catalogue_non_empty() -> bool:
	var shop := ShopModel.new()
	return shop.item_count() > 0


func test_default_catalogue_static_matches() -> bool:
	var shop := ShopModel.new()
	return shop.item_count() == ShopModel.default_catalogue().size()


func test_has_item_known_and_unknown() -> bool:
	var shop := ShopModel.new()
	return shop.has_item("pistol") and not shop.has_item("nope")


func test_price_of_known() -> bool:
	var shop := ShopModel.new()
	return shop.price_of("pistol") == 500


func test_price_of_unknown_is_minus_one() -> bool:
	var shop := ShopModel.new()
	return shop.price_of("rocket_launcher") == -1


func test_can_afford_true_above_price() -> bool:
	var shop := ShopModel.new()
	return shop.can_afford("pistol", 1000)


func test_can_afford_true_at_exact_boundary() -> bool:
	var shop := ShopModel.new()
	return shop.can_afford("pistol", 500)


func test_can_afford_false_below_price() -> bool:
	var shop := ShopModel.new()
	return not shop.can_afford("pistol", 499)


func test_can_afford_unknown_is_false() -> bool:
	var shop := ShopModel.new()
	return not shop.can_afford("ghost", 999999)


func test_purchase_deducts_exactly() -> bool:
	var shop := ShopModel.new()
	var result := shop.purchase("smg", 3000)
	return result["success"] and result["cost"] == 2500 and result["new_balance"] == 500


func test_purchase_exact_balance_succeeds_to_zero() -> bool:
	var shop := ShopModel.new()
	var result := shop.purchase("body_armor", 1000)
	return result["success"] and result["new_balance"] == 0


func test_purchase_insufficient_funds_fails() -> bool:
	var shop := ShopModel.new()
	var result := shop.purchase("rifle", 100)
	return (
		not result["success"]
		and result["new_balance"] == 100
		and result["cost"] == 0
		and not result["reason"].is_empty()
	)


func test_purchase_unknown_id_fails_balance_unchanged() -> bool:
	var shop := ShopModel.new()
	var result := shop.purchase("flamethrower", 50000)
	return (
		not result["success"] and result["new_balance"] == 50000 and not result["reason"].is_empty()
	)


func test_items_in_category_filters_weapons() -> bool:
	var shop := ShopModel.new()
	var weapons := shop.items_in_category("weapon")
	return weapons.size() == 3


func test_items_in_category_filters_vehicles() -> bool:
	var shop := ShopModel.new()
	return shop.items_in_category("vehicle").size() == 2


func test_items_in_category_unknown_is_empty() -> bool:
	var shop := ShopModel.new()
	return shop.items_in_category("aircraft").is_empty()


func test_sell_value_default_half() -> bool:
	var shop := ShopModel.new()
	return shop.sell_value("smg") == 1250


func test_sell_value_custom_fraction() -> bool:
	var shop := ShopModel.new()
	return shop.sell_value("body_armor", 0.25) == 250


func test_sell_value_fraction_clamped() -> bool:
	var shop := ShopModel.new()
	return shop.sell_value("pistol", 2.0) == 500 and shop.sell_value("pistol", -1.0) == 0


func test_sell_value_unknown_is_zero() -> bool:
	var shop := ShopModel.new()
	return shop.sell_value("nope") == 0


func test_custom_catalogue_overrides_default() -> bool:
	var shop := ShopModel.new([{"id": "bat", "name": "Bat", "price": 75, "category": "melee"}])
	return shop.item_count() == 1 and shop.price_of("bat") == 75


func test_garbage_entries_dropped() -> bool:
	var catalogue := [
		{"id": "good", "price": 100, "category": "weapon"},
		{"id": "", "price": 50},
		{"price": 10},
		{"id": "negative", "price": -5},
		{"id": "notint", "price": "free"},
		"not_a_dict",
	]
	var shop := ShopModel.new(catalogue)
	return shop.item_count() == 1 and shop.has_item("good")
