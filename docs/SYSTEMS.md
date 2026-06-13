# Gameplay Systems Reference

A catalogue of the pure, unit-tested simulation systems that make up the GTA-style
gameplay layer, with their purpose, key API, and **how to wire each into a live
scene**. Every system here is a `class_name` you can `ClassName.new()` (stateful)
or call statically (pure helpers); all are headless unit-tested under
`game/tests/unit/test_*.gd`.

Most systems follow one of two repo patterns:

- **Pure model + thin node**: the math lives in a `RefCounted` model; a `Node`
  reads it and drives the engine (see `WantedTracker` wrapping `WantedSystem`).
- **Self-wiring coordinator**: a small `Node` that finds collaborators by group
  in `_ready`/`_process` and needs no per-scene plumbing (see `MissionReward`,
  `ProgressionTracker`, `StatsCoordinator`, `WantedEvasionController`,
  `PaySprayShop`). This is the lowest-friction way to wire a model into a scene.

Groups the live scene already publishes: `player`, `player_health`,
`player_stats`, `wanted`, `mission`, `police`, `stats`, `progression`, `world`,
`spawn_points`.

---

## Wanted / law enforcement

| System | Purpose | Key API | Wiring |
|---|---|---|---|
| `WantedSystem` | heat -> stars core | `add_crime`, `stars`, `is_wanted`, `tick` | wrapped by `WantedTracker` (group `wanted`) |
| `CrimeWitness` | a crime only raises heat if seen | `can_witness`, `count_witnesses`, `heat_for_crime`, report timer | gate `WantedTracker._on_crime` on `count_witnesses(crime_pos, peds)` before adding heat |
| `WantedEvasion` | "go cold" search timer | `update(seen, dt)`, `is_cold`, `search_progress` | wired live via `WantedEvasionController` (raycasts cop LOS) |
| `PaySpray` | respray/hideout instant clear | `cost_for`, `is_seen_entering`, instance respray timer | wired live via `PaySprayShop` Area3D (group `pay_spray`) |
| `Disguise` | change your look to lose the heat | `set_appearance`, `log_sighting`, `recognition`, `evasion_speedup`, `changed_slots` | wired live via `DisguiseController` (group `player_disguise`) which owns the player's one Disguise. `log_sighting` when the player is spotted. FULLY CLOSED: `WantedEvasionController._physics_process` now scales its unseen search-drain by `DisguiseController.evasion_speedup()` (1x..3x), so changing clothes after a sighting makes a search give up faster — verified in `disguise_evasion_probe`. The ClothingStore→Disguise→evasion loop is end-to-end |
| `Wardrobe` | buy/own/wear clothing that feeds `Disguise` | `buy`, `wear`, `worn_looks`, `worn_look`, `items_in_slot` | the player's ONE wardrobe lives on `DisguiseController` (so a piece bought at one store is free to wear at the next). Wired live via `ClothingStore` (Area3D, group `clothing_store`): walk into the zone → buys + wears any not-already-worn piece of its disguise outfit (charged via `PlayerStats`) → `controller.refresh_disguise()` re-skins the look so recognition drops. The "duck into a shop to shake the cops" loop, verified end-to-end in `clothing_store_probe` |
| `PoliceEscalation` | response tier per star | `response_units`, `has_swat/helicopter/military`, `aggression`, `weapon_tier` | feed `PoliceSpawner`: pick the scene + count per `response_units(stars)` |
| `PursuitTactics` | chase tactics | `intercept_point`, `should_ram`, `pit_side`, `choose_tactic` | drive `Police`/traffic-cop movement when chasing |
| `GangTerritory` | turf control | `add_influence`, `take_over`, `controlled_fraction` | owned live by `GangTerritoryController` (group `gang_territory`). Captured via `TurfZone` (Area3D, group `turf_zone`): stand in a rival district's zone and influence climbs `capture_rate`/sec; at full influence the turf flips to the player. The hold-the-ground takeover loop, verified in `turf_zone_probe`. `GangTerritoryController.turf_captured` is the hook to `provoke` the dispossessed gang (`RivalRetaliation`) |
| `RivalRetaliation` | gang VENDETTA: grudge → timed revenge strikes (vandalism → raid → hit squad) | `provoke`, `pacify`, `grudge_of`, `is_seeking_revenge`, `retaliation_kind_for`, `tick`, `serialize` | owned live by `RivalRetaliationController` (group `rival_retaliation`), which SELF-WIRES to the `gang_territory` node's `turf_captured` signal and `provoke`s the dispossessed gang — so taking a rival's turf earns their grudge. It runs the day clock and emits `retaliation_strike(faction, kind, severity)` for the scene to spawn ambushers/property raids; other systems (a hit, a heist) can also `provoke()`. The turf→vendetta loop, verified in `rival_retaliation_probe`. `pacify` for a truce. Faction ids align with `GangTerritory`/`FactionStanding` |
| `FactionStanding` | per-faction reputation (-100 hostile..+100 allied) | `adjust`, `tier_of`, `will_attack`, `will_assist`, `to_dict` | adjust on player actions (rivalry bleeds onto enemies); NPC AI reads `will_attack`/`will_assist`; faction ids align with `GangTerritory` |
| `CrimeNotoriety` | per-crime-type infamy "rap sheet" — persistent, day-decaying, ORTHOGONAL to wanted-heat and faction-rep (legendary bank-robber at 0 stars) | `record`, `infamy_of`, `tier_of`, `notoriety_score`, `reputation_label`, `fear_level`, `hiring_appeal`, `shop_price_multiplier`, `news_severity_for`, `decay` | `record(crime_type, amount)` on the same `wanted` hook `CrimeReactionDirector` uses; FEEDS `NewsBulletin.report()` (pass `news_severity_for(dominant_category())`), `ShopModel`/`ContrabandMarket` (× `shop_price_multiplier()`), `HeistCrew` (gate on `hiring_appeal()`), NPC AI/`CrowdPanic` (read `fear_level()`/`intimidates_civilians()`). Persist via `serialize`/`restore`. Pure |
| `PlayerBounty` | a placed cash reward on the PLAYER'S head that draws NPC hunters — distinct from `WantedSystem` (live police heat) and `CrimeNotoriety` (reputation) | `place_bounty`, `total_bounty`, `tier`, `hunter_count`, `threat_level`, `claim`, `pay`, `appease`, `decay` | owned live by `PlayerBountyController` (group `player_bounty`), which SELF-WIRES to the `rival_retaliation` node's `retaliation_strike` signal — so each gang revenge strike puts a severity-scaled price on the player's head, escalating the bounty tier and the NPC hunters it draws (`hunters_changed(count, threat)`). Decays over days; resolve via `pay` (at a fixer) / `appease` (truce) / `claim` (on death). The turf→grudge→strike→bounty→hunters chain, verified in `player_bounty_probe` |
| `NpcCompliance` | per-individual bribe / intimidate / persuade with favour + witness-silencing gates — transactional, distinct from `FactionStanding`'s per-faction rep | `bribe`, `intimidate`, `persuade`, `compliance_of`, `will_grant_favour`, `will_silence_witness`, `decay`, `register_npc` | `register_npc` on ped spawn; `intimidate(id, notoriety_from_stars(stars), weapon_menace)` feeds menace from `WantedSystem`/`CrimeNotoriety` + `WeaponLoadout`; `persuade` scales on `charisma_from_progression(PlayerProgression.level)`; `bribe` wallet result applied by caller. A `CrimeWitness` gate reads `will_silence_witness(id)` before counting a witness; `will_grant_favour` gates a `ContactServices` lead. Disposition caps keep it honest (a hardened thug resists fear; talking can't buy silence). Pure |
| `TrafficCitation` | CIVIL traffic-law ledger (speeding / red-light / reckless / hit-and-run fines) that escalates into criminal heat — the civil counterpart to `WantedSystem`/`CrimeWitness` | `record_speeding`, `record_red_light`, `record_collision`, `unpaid_balance`, `pay`, `tick`, `consume_star_severity` | on driving events call `record_*` (`cop_sees` from `CrimeWitness.can_witness`; collision `damage_hp` is the same value feeding `VehicleCondition.apply_crash`); each frame `WantedSystem.add_crime(consume_star_severity())` for live-witnessed heat and feed each `tick(delta_days)` escalation severity to `add_crime` (DISJOINT paths — no double-count); settle fines at a courthouse via `pay` against the wallet. Pure |

## Combat

| System | Purpose | Key API | Wiring |
|---|---|---|---|
| `WeaponBallistics` | falloff / hit-zones / spread / recoil bloom | `effective_damage`, `spread_direction`, `Bloom` | apply in `WeaponController` when resolving a shot |
| `ExplosionModel` | radial damage + knockback + chain | `damage_at`, `knockback`, `should_chain`, `apply_to_many` | on grenade/vehicle blast, query nearby hittables |
| `MeleeCombat` | combos / block / counter / stamina | `strike`, `block_reduction`, `counter_damage` | drive `MeleeController` strikes + a stamina HUD |
| `CombatCover` | cover-point eval | `provides_cover`, `best_cover`, `peek_position`, `is_exposed` | give `CombatAi`/`Police` cover-seeking behaviour |
| `StealthDetection` | awareness meter | `update(can_see, vis, dt)`, `is_alerted`, `detection_speed` | per-NPC perception atop `CrimeWitness` FOV |
| `SoundPropagation` | the world's "ear": who hears a gunshot/alarm/engine, masked by distance + ambient | `base_loudness`, `is_alarming`, `perceived_intensity`, `is_audible`, `audible_radius`, `reaction_for`, `emit`, `loudest_heard`, `ambient_for` | the auditory complement to `StealthDetection` (visual). On a noisy event call `emit(src, kind, npc_listeners, ambient_for(base, is_night, rain01))`; for each `heard` listener seed `StealthDetection`, and on `ALARMED` promote via `CrimeWitness` / raise `WantedSystem` / spike `CrowdPanic` / dispatch `EmergencyServices`. `loudest_heard` picks what an idle NPC turns toward. Pure — no scene access |
| `NpcVoice` | speak NPC lines aloud via OS text-to-speech instead of only a speech bubble | `params_for`, `speakable`, `should_speak` | `Citizen._say` routes each line through it: maps the archetype `_voice` to a stable OS-voice slot + pitch/rate, `speakable` drops mime gestures / wordless lines, `should_speak` gates on the single TTS channel (`tts_is_speaking` busy / per-NPC cooldown) and player distance (OS TTS is not spatial). Degrades to the text bubble where TTS is absent (headless / CI). Needs `audio/general/text_to_speech=true` |
| `FirePropagation` | spreading fire + fuel burnout | `ignite_intensity`, `update_fires`, `damage_per_second` | molotov/vehicle fire that spreads across flammables |
| `WeaponLoadout` | attachments (optic/muzzle/mag/grip) tune a weapon | `equip`, `mult_for`, `apply_mult`, `mag_size`, `is_suppressed` | a weapon-mod UI; apply `apply_mult(base, "spread"/"range"/"recoil")` around the `WeaponBallistics` calls, `mag_size` to ammo, `is_suppressed` to witness noise |

## Vehicles

| System | Purpose | Key API | Wiring |
|---|---|---|---|
| `VehicleHandling` | arcade grip/drift | `apply_friction`, `slip_angle`, `drift_factor`, `DriftScorer` | layer onto `Car`/`Bike` velocity each physics frame |
| `VehicleHealth` | damage -> fire -> wreck | `apply_damage`, `tick`, `state`, `just_exploded` | on car damage; trigger `ExplosionModel` on wreck |
| `VehicleCondition` | persistent per-vehicle fuel + engine/tire wear (the gas/mechanic loop) | `drive`, `apply_crash`, `refuel`, `service`, `condition`, `fuel_fraction`, `top_speed_factor`, `grip_factor` | a `Car` node owns one per active vehicle: each frame `drive(id, dist, intensity)` burns fuel + wears; `VehicleHealth` impacts feed `apply_crash`. HUD reads `fuel_fraction`/`condition`; `top_speed_factor` caps max-speed and `grip_factor` multiplies into `VehicleHandling`. A gas-station calls `refuel`, a mechanic `service`. **Produces the `condition` float `ChopShop.value()` consumes** (the seam nothing fed before). Persists via `to_dict`/`load_dict`. Pure |
| `VehicleModShop` | tiered upgrades -> stat multipliers | `upgrade`, `top_speed_multiplier`, `grip_multiplier` | a mod-garage trigger; multipliers feed `VehicleHandling` |
| `Carjacking` | yank a driver out | `can_reach`, `door_side`, struggle timer, `heat_for_jack` | player enter-vehicle path + `WantedTracker.report_crime` |
| `GarageStorage` | store/retrieve/impound vehicles | `store`, `retrieve`, `impound`, `recover_from_impound` | a garage trigger + saved vehicle list |
| `VehicleInsurance` | DESTRUCTION cover ("Mors Mutual"): insure a vehicle for a one-off premium (5% of value); if it's written off, claim it back for a deductible (10%) — distinct from `GarageStorage`'s cop IMPOUND → release fee | `insure`, `cancel`, `is_insured`, `destroy`, `claim`, `coverage_value`, `claims_filed`, `to_dict`/`from_dict` | an insurance phone-app/menu `insure()`s (charge the premium); on a vehicle write-off call `destroy(id)`, then a "request your car" call resolves `claim(id)` (charge the deductible, respawn the car). Pure — wallet resolved by caller |
| `Safehouse` | the sanctuary you retreat to: a save/respawn anchor, REST to skip time (cool wanted heat + heal), and a cash STASH kept safe off your person (safe even from a `MoneyLaundering` audit) — distinct from `PropertyOwnership` (income), `GarageStorage` (vehicles), `WantedEvasion` (on-foot go-cold) | `acquire`, `set_active`, `active`, `rest`, `stash`, `withdraw`, `stash_balance`, `total_stashed`, `to_dict`/`from_dict` | a safehouse trigger `acquire()`s (charge the wallet); a "sleep/rest" UI calls `rest(hours)` and applies the returned `heat_cooled` to `WantedSystem` + `health_restored` to `PlayerHealth`; bank cash via `stash()` (park the clean money before a laundering push). Pure |
| `VehicleSupplier` | on-call vehicle DELIVERY (timer) + respawn-after-wreck cooldown — dynamic logistics atop GarageStorage's instant retrieve | `request`, `report_destroyed`, `tick`, `is_available`, `eta_of`, `available_count` | `request(id, PlayerStats.money)` pays a fee + starts the delivery timer; `report_destroyed(id)` on a wreck starts the respawn cooldown; each frame `for a in tick(dt): spawn a.vehicle_id at the waypoint` (delivered / respawned). Location-free — caller owns the waypoint. Persist via `serialize`/`restore`. Pure |
| `ChopShop` | fence a vehicle: class × condition × demand × heat | `value`, `deliver`, `set_requests`, `rotate_requests`, `total_earned` | a chop-shop trigger reads the car's class + `VehicleHealth.health_fraction()`, calls `deliver` and pays the wallet; rotate most-wanted orders for bonus pay |
| `Parachute` | freefall/deploy/land | `deploy`, `update_fall_speed`, `landing_impact` | player skydive state above a height threshold |

## Driving the world alive

| System | Purpose | Key API | Wiring |
|---|---|---|---|
| `PedestrianTraffic` | peds dodge cars / cross safely | `nearest_threat`, `dodge_velocity`, `safe_to_cross` | blend `dodge_velocity` into `Pedestrian` steering near traffic |
| `CrowdPanic` | gunfire panic ripples through a crowd | `initial_fear`, `update_crowd`, `flee_direction` | drive `CrowdDirector` peds on a scare event |
| `TrafficSignal` | junction light cycle + right-of-way | `tick`, `light_for`, `should_stop`, `yields_to` | place at intersections; gate `TrafficCar` at the stop line |
| `EmergencyServices` | ambulance/fire dispatch | `service_for`, `nearest_responder`, response timer | spawn a responder on a wreck/fire/injury incident |
| `WeatherEffects` | rain/fog gameplay impact | `grip_multiplier`, `visibility_range`, `ai_sight_multiplier` | feed `WeatherController` level into handling + detection |
| `StormEvent` | a discrete severe TROPICAL STORM set-piece (calm→watch→warning→landfall→aftermath→clearing) atop the continuous `WeatherState` — the Florida hurricane moment | `trigger`, `advance`, `intensity`, `phase`, `is_dangerous`, `visibility`, `road_grip`, `power_outage_chance`, `flood_risk`, `looting_opportunity`, `evacuation_pressure`, `to_dict`/`from_dict` | a world director `trigger()`s a storm and `advance(dt)`s it; drive `WeatherController` rain from `intensity()`; feed `road_grip()` into vehicle handling and `visibility()` into `StealthDetection`/AI sight; roll `power_outage_chance()` to kill neon/`TrafficSignal`s; scale a `ContrabandMarket`/crime payout by `looting_opportunity()` (cops swamped); push `evacuation_pressure()` into `CrowdDirector`; `flood_risk(elevation)` floods low ground. Pure — consequences applied by callers |
| `EnvironmentalHazard` | spatial damage zones (toxic / radiation / fire / electrical) — static + transient | `damage_at`, `is_in_hazard`, `dominant_hazard_at`, `add_transient`, `tick`, `remove_zone` | each frame apply `damage_at(player_pos, dt, armor)` to `PlayerHealth`; `is_in_hazard`/`dominant_hazard_at` drive a HUD warning and steer `CrowdPanic`/NPC routing away; `add_transient` spawns a gas-grenade/fuel-fire cloud that `tick(dt)` ages out. XZ circles, location-aware, damage applied by caller. Pure |
| `AmbientEvents` | weighted freeroam encounters (mugging/race/heist) | `trigger_next`, `eligible_ids`, `can_fire`, `trigger` | a world director calls `trigger_next(rng, now, {stars, district})` on a timer and spawns the returned encounter; per-event cooldowns + a global gap prevent spam |

## Missions / activities

| System | Purpose | Key API | Wiring |
|---|---|---|---|
| `MissionChain` | campaign sequencing | `current`, `complete_current`, `is_campaign_complete` | wired live via `MissionCampaign` (5-mission arc in miami) |
| `MissionObjectiveTypes` | reach/collect/eliminate/escort/survive/defend | `*_satisfied`, `Counter` | use in `MissionController` for varied objectives |
| `SideJob` | taxi/delivery/vigilante contracts | `fare`, `payout`, active-job lifecycle | wired live via `SideJobBoard` (pickup/dropoff Area3Ds) |
| `StreetRace` | checkpoint laps + placement | `reached`, `progress`, `placement`, `reward` | checkpoint Area3Ds + rival progress feeds |
| `HeistCrew` | crew skill/cut -> odds + take | `add_member`, `success_chance`, `attempt`, `payout` | a heist-planning UI + a mission finale |
| `HeistPlan` | the APPROACH + PREP planning board atop `HeistCrew`: pick LOUD/STEALTH/SMART (trading base risk for take + prep requirements) and run prep tasks that each shave risk and pad the take | `set_approach`, `add_prep`, `complete_prep`, `prep_progress`, `risk`, `success_chance`, `expected_take`, `is_ready`, `to_dict`/`from_dict` | a planning UI sets the approach + drives prep tasks; the mission resolver gates launch on `is_ready()`, then reads `success_chance(HeistCrew skill)` + `expected_take(base)` at go-time and pays out through `HeistCrew.payout`. Pure, deterministic |
| `HeistComplication` | the THINGS-GO-WRONG layer — the third leg of the heist trio (`HeistPlan` plans, `HeistCrew` rolls, this resolves the mess): the riskier the plan, the more of the complication table fires (nosy guard → silent alarm → hostage → crew hit → blocked getaway), each cutting the take and piling on heat/casualties | `count_for`, `complications_for`, `apply` | at the heist finale call `apply(expected_take, base_heat, HeistPlan.risk(crew_skill))`; apply the returned `take` to the wallet, `heat` to `WantedSystem`, and `casualties` to the crew. Stateless + deterministic (no RNG) |
| `HeistJob` | the FACADE that runs a heist end-to-end — owns a `HeistPlan` + `HeistCrew` + `HeistComplication` and resolves the score in one call (crew skill folds into plan risk, complications eat the take, the crew takes its cut) | `plan`, `crew`, `success_chance`, `roll`, `resolve` | a heist-mission node owns one: drive `plan()`/`crew()` setup, gamble with `roll(rng)`, then `resolve(success, base_take, base_heat)` → bank `take` to the wallet + `heat` to `WantedSystem`. The roll is separated from the deterministic payout maths so it tests cleanly. Pure |
| `StoreRobbery` | the STICK-UP — robbing a store register, the opportunistic crime between big heists. Take scales with how hard you lean on the clerk; lean too softly and they trip the silent alarm (faster cops, more heat). The till refills over time | `rob`, `refill`, `register_balance`, `till_capacity`, `to_dict`/`from_dict` | wired live via `StoreCounter` (Area3D, group `store_counter`): step up to the register and rob it — `rob(intimidation)` returns `{took, heat, alarm}`, `took` to `PlayerStats`, the robbery reported as a crime to the `wanted` tracker (a tripped silent alarm reports a second), and the till refills over days so the store is robbable again. Verified in `store_counter_probe`. (intimidation can be driven from `NpcCompliance`/`WeaponLoadout` menace.) Distinct from `HeistJob` (planned) + `AmbientEvents` (random mugging). Pure, deterministic |
| `MissionModifier` | optional per-mission challenges (time limit / no-damage / extra enemies / stay-undetected) that raise difficulty AND payout | `roll`, `activate`, `is_active`, `combined_difficulty`, `combined_payout_mult`, `apply_to_payout` | on mission start `roll(seed, n)` (deterministic) or let the player `activate` modifiers; read `combined_difficulty()` to scale enemy counts/timers (lowers `HeistCrew.success_chance`), gate each rule on `is_active(id)`, and size the cash reward via `apply_to_payout(base)` (paid out like `MissionReward`). Pure |
| `StuntScore` | freeform trick-combo scorer (air/near-miss) | `add_trick`, `multiplier`, `pending_score`, `bank`, `wipe` | a stunt controller calls `add_trick` on detected tricks, `bank` on a clean land / `wipe` on crash; apply `cash_for`/`respect_for` to wallet + `PlayerProgression` |
| `HitContract` | assassination board that moves the stock market | `available`, `accept`, `market_effect_of`, `complete`, `total_earned` | wired live via `HitContractBoard` (Node3D, group `hit_contract_board`, two Area3D zones Board+Target like `SideJobBoard`): step into Board → accept the next contract; reach Target → `complete()` banks the reward (`PlayerStats`) and fires the `market_effect` at the live market node (group `stock_market` = `MarketEventCoordinator`) via `apply_rivalry_shock` — the invest-then-hit loop, now fully closed. Verified in `hit_contract_probe` |

## Economy / progression

| System | Purpose | Key API | Wiring |
|---|---|---|---|
| `ShopModel` | priced catalogue + purchase | `purchase`, `can_afford`, `sell_value` | a shop trigger + `PlayerStats.spend_money` |
| `PropertyOwnership` | buy properties + passive income | `buy`, `accrue`, `collect`, `daily_income` | property triggers + a daily income tick |
| `BusinessVenture` | own + OPERATE production businesses (supply→product→sell) — the active layer atop PropertyOwnership's passive income | `acquire`, `buy_supplies`, `accrue`, `hire`, `upgrade`, `production_rate`, `sale_price`, `sell`, `total_product` | a business-property trigger `acquire()`s against `PlayerStats.money`; a daily/world tick calls `accrue(delta_days)`; a "manage" UI calls `buy_supplies`/`hire`/`upgrade`; at cash-out pass `DistrictEconomy.desirability(district)` as `demand` and a `WantedSystem`/`FactionStanding`-derived 0..1 `heat` into `sale_price`/`sell`, then credit `proceeds`. Pure — wallet resolved by caller |
| `DistrictEconomy` | living real-estate: turf/crime move desirability | `desirability`, `property_value`, `income_multiplier`, `set_control`, `add_heat`, `invest` | feed `GangTerritory.influence_in` into `set_control` and crimes into `add_heat`; scale `PropertyOwnership` price/income by `desirability` |
| `ContrabandMarket` | buy-low/sell-high arbitrage | `price_in`, `buy`, `sell`, `best_market`, `bust_risk` | wired live via `BlackMarketStall` (Area3D, group `black_market`) trading into the shared `ContrabandController` inventory (group `contraband`): walk into a stall empty → buy a parcel at that district's price (via `PlayerStats`); carry it to a stall in a pricier district → walk in → sell the stash dear. The arbitrage loop, verified in `black_market_probe`. BUST-RISK CLOSED: `ContrabandController` now runs a risk clock — while you carry contraband, suspicion accrues at `bust_risk()` (faster the heavier the load) and crossing the threshold reports a crime to the `wanted` tracker; ditch/sell the stash and it clears. So running a loaded mule draws police. Verified in `contraband_heat_probe` |
| `SmugglingRun` | the run-the-gauntlet TRIP — a bulk cargo run down a ROUTE of legs (open water → patrol box → port), each leg interdicting a slice of what's left, shrunk by your evasion. Distinct from `ContrabandMarket` (carried-parcel arbitrage) and `DealerNetwork` (street network) | `add_leg`, `leg_count`, `cargo_value`, `run`, `to_dict`/`from_dict` | a smuggling mission builds the route (`add_leg(risk)` per checkpoint), runs it with the player's evasion (fast boat / quiet route / greased official), then banks `value_delivered` to the wallet and applies `heat` to `WantedSystem`. Pure, deterministic |
| `Fence` | where stolen VALUABLES become cash — closes the loot→money loop (`StoreRobbery`/`HeistJob`/`LootTable` drop goods; this sells them). Pays a fraction of value, docked for HOT (recently-stolen) goods; let them cool a few days for a better quote. The dump-now-or-sell-clean choice | `add_loot`, `fence_quote`, `cool`, `sell`, `sell_all`, `item_heat`, `inventory_value`, `to_dict`/`from_dict` | a fence trigger takes `add_loot(id, category, value)` from a robbery/heist drop; a world day-tick `cool()`s the stash; a sell UI shows `fence_quote()` and banks `sell()`/`sell_all()` proceeds. Distinct from `ShopModel` (buying), `ChopShop` (vehicles), `ContrabandMarket` (drugs). Pure |
| `DealerNetwork` | the drug-EMPIRE management layer above personal arbitrage: recruit dealers onto district corners, supply them, and run a selling cycle for passive revenue scaled by demand — while busts claim a designed fraction of the network scaled by police heat vs turf control | `recruit`, `fire`, `supply`, `throughput_total`, `bust_rate`, `run_cycle`, `to_dict`/`from_dict` | recruit dealers (charge the wallet); feed `supply()` from `BusinessVenture`/`ContrabandMarket` product; on a day tick call `run_cycle(district_demand, unit_price, WantedSystem heat 0..1, GangTerritory control 0..1)`, credit the returned `revenue` and apply `heat_added` to `WantedSystem`. Pure, deterministic |
| `DrugLab` | the manufacturing SOURCE of the drug vertical (`DrugLab` cooks → `DealerNetwork` distributes → `MoneyLaundering` washes): cook batches over time at a PURITY set by equipment tier + batch size, with raid risk while cooking; collect units into inventory | `start_batch`, `cook`, `is_batch_done`, `collect`, `purity_for`, `raid_risk`, `street_value_per_unit`, `inventory`, `withdraw`, `to_dict`/`from_dict` | a lab trigger `start_batch()`s (charge precursors); a world tick `cook(dt)`s; a raid director rolls `raid_risk(WantedSystem heat)` while cooking; `collect()` banks product, then `withdraw()` feeds `DealerNetwork.supply()`. Distinct from `BusinessVenture` (sells for cash) — the lab outputs PRODUCT + purity. Pure |
| `DrugEmpireCoordinator` | **self-wiring coordinator** that packages the whole drug vertical (`DrugLab`→`DealerNetwork`→`MoneyLaundering`→wallet) into ONE drop-in `Node` — the bridge from three pure models to playable | `run_day` (pure core), `lab`, `dealer`, `laundering` | add ONE node to `miami.tscn` with `auto = true`: it ticks a "business day" on a timer, reads live heat from the `wanted` group, and banks the laundered clean money to `player_stats` (mirrors `CharacterSwitcher`). `run_day(demand, price, heat, turf)` is the tree-free orchestration core (cook → supply → sell → wash → return clean), unit-tested end-to-end |
| `MoneyLaundering` | wash DIRTY crime cash → CLEAN spendable money through front businesses (per-front cut + per-cycle throughput cap) with audit/seizure risk — the criminal-economy counterpart to the clean wallet | `add_dirty`, `launder`, `capacity_remaining`, `tick`, `suspicion_level`, `is_flagged`, `audit`, `to_dict`/`from_dict` | crime systems (`ContrabandMarket.sell`, `HeistCrew` cuts, robberies) credit `add_dirty()` instead of the wallet; a laundering UI routes `launder(front, amount)` and the caller adds the returned `clean` to `PlayerStats`; a daily/world tick calls `tick()` (resets front capacity, cools suspicion); when `is_flagged()`, a timer roll fires `audit()` and the caller applies the `seized` loss + a `WantedSystem`/`CrimeNotoriety` bump. Pure — wallet + heat resolved by caller |
| `CasinoGames` | roulette/slots/blackjack | `roulette_payout`, `slot_payout`, `blackjack_settle`, bankroll | slots wired live via `SlotMachine` (Area3D, group `slot_machine`): walk into the zone → one pull stakes from `PlayerStats` and banks the win (`slot_spin`/`slot_payout`, seeded-RNG-injectable). Verified end-to-end in `slot_machine_probe`. Roulette/blackjack still want a table node + UI |
| `PlayerProgression` | respect/XP + unlocks | `add_xp`, `level`, `unlocks_at`, `is_unlocked` | wired live via `ProgressionTracker` (missions grant XP) |
| `PlayerSkills` | activity-based proficiency (drive/shoot/stamina...) | `train`, `level`, `tier`, `bonus`, `overall_mastery`, `to_dict` | call `train` from the matching activity (distance driven, shots landed); read `bonus(id)` to scale recoil/grip/sprint; persist via the save system |
| `StatTracker` | lifetime stats + 100% | `add`, `is_achieved`, `completion_percent`, serialize | wired live via `StatsCoordinator` |
| `StockMarket` | event-driven equities + tracked portfolio | `apply_rivalry_shock`, `apply_sector_event`, `price`, `buy`, `sell`, `unrealized_gain` | owned live by `MarketEventCoordinator` (group `stock_market`). Traded via `StockTerminal` (Area3D, group `stock_terminal`): walk into a terminal flat → buy `shares` of its company (charged via `PlayerStats`); price moves on events (a `HitContractBoard` hit, a wanted-rally); walk in holding → sell the position at the new price. The invest-then-hit swing, verified in `stock_terminal_probe` |

## Support

| System | Purpose | Key API | Wiring |
|---|---|---|---|
| `GpsNavigation` | route progress/ETA/next-turn | `distance_remaining`, `progress`, `next_turn`, `has_arrived` | feed a NavGrid route into the minimap GPS line |
| `RadioScheduler` | song/DJ/ad/news programming | `next_segment`, `pick_song`, `advance` | program a `VehicleRadio` station |
| `NewsBulletin` | player deeds -> reactive radio/TV headlines | `report`, `next_bulletin`, `has_pending`, `recent` | `report` on crimes/heists/escapes (severity-tiered); when `RadioScheduler` yields a NEWS segment, read `next_bulletin()` for the anchor line |
| `ContactServices` | call a contact for a favour (lower-wanted/mechanic/backup) | `request`, `can_use`, `cooldown_remaining`, `is_ready` | the phone UI gates `request` with `PhoneContacts.will_answer`, charges the wallet, and triggers the effect by `kind`; cost + cooldown per service |
| `FriendCircle` | named-NPC FRIENDSHIPS (the "hang out with Roman/Lamar" circle): earned rapport (acquaintance→friend→close→best) that unlocks each friend's standing FREE perk — distinct from `ContactServices` (paid, per-call) and `ProtagonistBond` (the two leads) | `befriend`, `hang_out`, `slight`, `rapport_of`, `tier_of`, `perk_unlocked`, `perk_of`, `best_friend`, `decay`, `to_dict`/`from_dict` | a hangout activity calls `hang_out(id, quality)`; a "call a friend" phone UI offers the favour when `perk_unlocked(id)` (read `perk_of(id)` for the kind — free wheels/muscle/guns/intel); `slight` on betrayal; `decay(days)` on a day tick so neglected friends drift. Pure |
| `MusicDirector` | dynamic score intensity (calm→tension→combat→chase) | `update`, `current_tier`, `current_stem`, `is_intense` | an audio node calls `update({stars, in_combat, in_chase}, dt)` each frame and crossfades to `current_stem()`; escalates instantly, de-escalates on a hold |
| `SwimStamina` | oxygen/stamina/drowning | `update`, `is_drowning`, `swim_speed`, `drown_damage` | the meter layer above the swim motion node |
| `LootTable` | weighted seeded drops | `roll`, `roll_many`, `drop_chance_satisfied` | on enemy death / crate smash -> pickups |
| `CharacterRoster` | dual-protagonist switching + per-lead state | `switch_to`, `can_switch`, `active`, `money_of`, `position_of`, `to_dict` | load the active lead's wallet/wanted/position into PlayerStats + world on `switch_to`; write it back before switching away |
| `ProtagonistBond` | the Lucia+Jason RELATIONSHIP layer atop the roster — a persistent bond meter (estranged→wary→partners→ride_or_die) that scales co-op payouts, backup, and switch feel | `record_coop`, `record_rescue`, `record_conflict`, `record_betrayal`, `bond`, `tier`, `backup_available`, `payout_multiplier`, `switch_cooldown_scale`, `drift`, `to_dict`/`from_dict` | feed `record_*` from mission/combat events (a co-op heist clear → `record_coop`; saving the other lead → `record_rescue`; abandoning them under fire → `record_betrayal`); multiply a co-op `HeistCrew` cut by `payout_multiplier()`; gate a "call your partner" backup spawn on `backup_available()`; scale `CharacterSwitcher`'s cooldown by `switch_cooldown_scale()`; `drift(days)` on a world-day tick. Pure — persisted by the save system |
| `SocialClout` | PUBLIC social-media fame — GTA VI's everyone-is-filming world. A witnessed flashy act gets filmed; reach scales with severity × witnesses × flashiness × existing fame (snowballs) and past a threshold goes VIRAL: followers jump and the clip is evidence. Distinct from `CrimeNotoriety`'s underworld fear | `record_act`, `followers`, `fame_tier`, `sponsorship_income`, `recognizability`, `decay`, `to_dict`/`from_dict` | call `record_act(severity, witnesses, flashiness)` off the same witnessed-crime hook as `CrimeWitness`/`CrimeNotoriety`; apply the returned `heat_tip` to `WantedSystem`; credit `sponsorship_income()` on a day tick; feed `recognizability()` into `WantedEvasion`/`Disguise` (famous = harder to lie low). Pure |
| `PhotoMode` | the phone-camera / "Instasnap" loop — the player-driven content side of `SocialClout`. Scores a framed shot on composition (rarity/framing/lighting/action + landmark bonus), auto-curates good ones into an album, and posting computes reach + likes | `quality`, `capture`, `album_size`, `best_quality`, `post`, `total_likes`, `to_dict`/`from_dict` | a photo-mode UI supplies the composition metrics and calls `quality`/`capture` while framing and `post(shot, SocialClout.followers())` to publish; the returned `reach` can seed `SocialClout` follower growth — post a banger → gain fans. Pure |
| `ContentCareer` | the FACADE that closes the Snapmatic→fame flywheel: owns a `PhotoMode` + `SocialClout` and converts a post's reach into followers (reach scales with quality AND existing following, so a bigger audience reaches further next time). `SocialClout.add_followers()` feeds this non-crime growth | `photos`, `clout`, `followers`, `post`, `to_dict`/`from_dict` | a photo-mode UI calls `post(shot)`; the returned likes/followers drive the feed + profile. The influencer flywheel that runs parallel to `SocialClout`'s crime-virality side. Pure |

---

## Already wired & CI-guarded in `miami.tscn`

The playable map runs the full loop, each gated by a runtime probe in
`tools/check.sh`: player health/stats/wanted/mission/bark + crowd/traffic/police
directors (`miami_wiring_probe`), crime -> wanted -> police dispatch
(`miami_loop_probe`), the 5-mission campaign paying money/respect/stats
(`miami_mission_probe`), pay-n-spray wanted-clear (`miami_payspray_probe`), and
the busted/arrest fail-loop (`miami_arrest_probe`). `WantedEvasionController`,
`MissionReward`, `ProgressionTracker`, `StatsCoordinator`, `MissionCampaign`,
`PaySprayShop`, and `SideJobBoard` are the self-wiring coordinators already in the
scene — copy their shape to wire the rest.

`MarketEventCoordinator` is a ready-to-drop self-wiring node (cf. PaySprayShop):
it owns the one `StockMarket`, publishes itself in group `stock_market`,
subscribes to the `wanted` group's `stars_changed` to rally defense stocks on a
crime spree, and applies `HitContract` effects (via `apply_hit_effect` /
`apply_rivalry_shock`). A `StockTerminal` trades its `.market` and a
`HitContractBoard` shocks it — both find it by group. Its node-level wiring is
CI-gated headless by `tests/market_event_probe.gd` and `tests/stock_terminal_probe.gd`.
Adding it to `miami.tscn` is the remaining step to make the stock-market loop live.

`CrimeReactionDirector` is its sibling on the same `wanted` hook: it owns a
`NewsBulletin` + `DistrictEconomy` and, on a wanted spike, files a severity-scaled
headline and heats the active district (which cools over time via `_process`). The
two directors split the signal cleanly — market vs news+real-estate — so both can
sit in the scene. CI-gated headless by `tests/crime_reaction_probe.gd`.

`CharacterSwitcher` owns a `CharacterRoster` and syncs each lead's wallet through
the live `player_stats` node on `request_switch()` (write the current wallet back,
load the incoming lead's), so per-character money persists across switches. CI-gated
headless by `tests/character_switch_probe.gd`.

`AmbientEventDirector` drives `AmbientEvents` on a timer: each tick it builds
`{stars (from the wanted group), district}`, rolls `trigger_next`, and emits
`encounter_triggered(id, kind)` for the scene to spawn. CI-gated headless by
`tests/ambient_event_probe.gd`.

## One-node deployment: `InteractionDistrict`

`InteractionDistrict` (group `interaction_district`) drops the WHOLE walk-up
interaction layer into a scene as a single node. In `_ready` it builds, on a ring
of radius `spread`, the six activities — `ClothingStore`, `SlotMachine`,
`BlackMarketStall`, `StockTerminal`, `TurfZone`, and a `HitContractBoard` (with its
Board/Target zones) — each as an Area3D with a box trigger so the player can enter
it. It then spawns the four shared-state controllers (`DisguiseController`,
`ContrabandController`, `GangTerritoryController`, `MarketEventCoordinator`) **only
if their group isn't already present**, so it composes with anything a scene already
wired and never creates a duplicate owner — two districts added the same frame still
yield one controller per group. So the integrator's whole job to make the services
playable is: add one `InteractionDistrict` where the plaza should sit (set a unique
`turf_district` per plaza). Structurally CI-gated headless by
`tests/interaction_district_probe.gd`.
