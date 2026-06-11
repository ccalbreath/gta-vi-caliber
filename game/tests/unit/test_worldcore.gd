extends RefCounted
## Smoke test for the native WorldCore GDExtension (engine/src/worldcore/).
## The native library is an optional accelerator: when it isn't built
## (fresh clones, game-only CI) the test skips and stays green — that is
## the graceful-degradation rule from docs/ARCHITECTURE.md.


func test_worldcore_version_when_native_module_present() -> bool:
	if not ClassDB.class_exists("WorldCore"):
		print("SKIP test_worldcore: native module not built (expected without engine build)")
		return true
	var core: Object = ClassDB.instantiate("WorldCore")
	if core == null:
		return false
	var version: String = core.call("version")
	# Semver-ish: non-empty, three dot-separated numeric fields.
	var parts := version.split(".")
	if parts.size() != 3:
		return false
	for part in parts:
		if not part.is_valid_int():
			return false
	print("WorldCore %s loaded from native module" % version)
	return true
