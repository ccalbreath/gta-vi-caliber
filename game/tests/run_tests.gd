extends SceneTree
## Compatibility entry point for gdUnit4's command-line runner.
## Run via:
##   godot --headless --path game --script res://tests/run_tests.gd

var _cli_runner: GdUnitTestCIRunner


func _initialize() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
	_cli_runner = GdUnitTestCIRunner.new()
	_cli_runner._debug_cmd_args = _gdunit_args()
	root.add_child(_cli_runner)


func _finalize() -> void:
	queue_delete(_cli_runner)


func _gdunit_args() -> PackedStringArray:
	return PackedStringArray(
		[
			"res://addons/gdUnit4/bin/GdUnitCmdTool.gd",
			"--ignoreHeadlessMode",
			"-a",
			"res://tests/unit",
			"-c",
			"-rd",
			"res://reports",
			"-rc",
			"1",
		]
	)
