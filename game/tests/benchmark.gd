extends SceneTree
## Deterministic rendering benchmark (M3): flies a fixed camera path over the
## downtown district and captures frame statistics. Needs a renderer — run
## WITHOUT --headless:
##   godot --path game --script res://tests/benchmark.gd
## Results: printed + written to /tmp/gta6_benchmark.md for docs/profiles/.

const SCENE := "res://scenes/world/districts/downtown_la.tscn"
const OUT_PATH := "/tmp/gta6_benchmark.md"
const WARMUP_FRAMES := 120
const MEASURE_FRAMES := 900
## Two laps: a high orbit taking in the whole district, then a low street pass.
const HIGH_RADIUS := 350.0
const HIGH_ALTITUDE := 150.0
const LOW_RADIUS := 120.0
const LOW_ALTITUDE := 12.0

var _frame := 0
var _warmed := false
var _camera: Camera3D
var _frame_times: PackedFloat32Array = []
var _render_cpu_ms: PackedFloat32Array = []
var _render_gpu_ms: PackedFloat32Array = []
var _draw_calls_peak := 0.0


func _initialize() -> void:
	change_scene_to_file(SCENE)


func _process(delta: float) -> bool:
	_frame += 1
	if not _warmed:
		if _frame == 2:
			_mount_camera()
		if _frame >= WARMUP_FRAMES:
			_warmed = true
			_frame = 0
		return false

	_fly(_frame)
	_frame_times.append(delta)
	var vp := root.get_viewport_rid()
	_render_cpu_ms.append(RenderingServer.viewport_get_measured_render_time_cpu(vp))
	_render_gpu_ms.append(RenderingServer.viewport_get_measured_render_time_gpu(vp))
	_draw_calls_peak = maxf(
		_draw_calls_peak, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	)
	if _frame >= MEASURE_FRAMES:
		_report()
		quit(0)
		return true
	return false


func _mount_camera() -> void:
	# macOS Metal presents vsynced regardless of VSYNC_DISABLED, so wall-clock
	# deltas read as the refresh interval; the render server's measured CPU/GPU
	# times below are the honest cost numbers.
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	_camera = Camera3D.new()
	_camera.far = 4000.0
	current_scene.add_child(_camera)
	_camera.current = true


func _fly(frame: int) -> void:
	var half := MEASURE_FRAMES / 2
	var low_pass := frame > half
	var t := TAU * float(frame % half) / float(half)
	var radius := LOW_RADIUS if low_pass else HIGH_RADIUS
	var altitude := LOW_ALTITUDE if low_pass else HIGH_ALTITUDE
	_camera.global_position = Vector3(cos(t) * radius, altitude, sin(t) * radius)
	_camera.look_at(Vector3(0.0, altitude * 0.3, 0.0))


func _report() -> void:
	var sorted := _frame_times.duplicate()
	sorted.sort()
	var total := 0.0
	for ft in sorted:
		total += ft
	var avg := total / sorted.size()
	var p50 := sorted[int(sorted.size() * 0.50)]
	var p95 := sorted[int(sorted.size() * 0.95)]
	var p99 := sorted[int(sorted.size() * 0.99)]
	var worst: float = sorted[sorted.size() - 1]
	var cpu := _percentiles(_render_cpu_ms)
	var gpu := _percentiles(_render_gpu_ms)

	var lines := PackedStringArray(
		[
			"| Metric | Value |",
			"| --- | --- |",
			"| Frames measured | %d |" % sorted.size(),
			"| Average | %.2f ms (%.0f FPS) |" % [avg * 1000.0, 1.0 / avg],
			"| Median | %.2f ms (%.0f FPS) |" % [p50 * 1000.0, 1.0 / p50],
			"| 95th percentile | %.2f ms (%.0f FPS) |" % [p95 * 1000.0, 1.0 / p95],
			"| 99th percentile | %.2f ms (%.0f FPS) |" % [p99 * 1000.0, 1.0 / p99],
			"| Worst frame | %.2f ms (%.0f FPS) |" % [worst * 1000.0, 1.0 / worst],
			"| Render CPU p50 / p95 / worst | %.2f / %.2f / %.2f ms |" % [cpu[0], cpu[1], cpu[2]],
			"| Render GPU p50 / p95 / worst | %.2f / %.2f / %.2f ms |" % [gpu[0], gpu[1], gpu[2]],
			"| Peak draw calls/frame | %d |" % int(_draw_calls_peak),
			(
				"| Video memory | %.0f MB |"
				% (Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0)
			),
			(
				"| Objects in frame (last) | %d |"
				% int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
			),
		]
	)
	var body := "\n".join(lines)
	_write(body)


## [p50, p95, worst] of a series, in the series' own units.
func _percentiles(series: PackedFloat32Array) -> PackedFloat32Array:
	var sorted := series.duplicate()
	sorted.sort()
	return PackedFloat32Array(
		[
			sorted[int(sorted.size() * 0.50)],
			sorted[int(sorted.size() * 0.95)],
			sorted[sorted.size() - 1],
		]
	)


func _write(body: String) -> void:
	print(body)
	var f := FileAccess.open(OUT_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(body + "\n")
		f.close()
		print("benchmark: wrote %s" % OUT_PATH)
