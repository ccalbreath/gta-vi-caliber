# engine/ — custom C++ engine modules (GDExtension)

This is where we push Godot past its stock limits **without forking it**:
world streaming, impostor baking, crowd/traffic simulation, ocean. Modules
compile to shared libraries in `game/bin/` that a stock Godot editor loads
via `.gdextension` manifests.

Read [docs/ARCHITECTURE.md](../docs/ARCHITECTURE.md) first — native code
needs profile evidence, a working GDScript fallback story, and a narrow API.

## Build

```bash
pipx install scons                          # build system
git submodule update --init --recursive     # pulls godot-cpp (first time)

cd engine
scons platform=macos target=template_debug      # or platform=linux / windows
```

Then copy `gta_native.gdextension.example` to
`game/bin/gta_native.gdextension` (gitignored) and restart the editor. The
example `NativeBench` class becomes available from GDScript:

```gdscript
if ClassDB.class_exists("NativeBench"):
    print(NativeBench.new().ping())   # "pong from C++"
```

> **Note:** the godot-cpp submodule isn't vendored yet (roadmap: engine
> track). Until it is, add it yourself to experiment:
> `git submodule add -b 4.6 https://github.com/godotengine/godot-cpp engine/godot-cpp`

## Module checklist (PRs are reviewed against this)

1. One directory per module under `src/<module>/`, registered in
   `src/register_types.cpp`.
2. Game must run without the library present — guard usage with
   `ClassDB.class_exists()` and provide a GDScript fallback or a clear debug
   notice.
3. API surface: Godot types in, signals/typed data out. No game logic in C++.
4. Justification: link the profile in `docs/profiles/` that motivated the
   module.
5. C++17, 4-space indent (`.editorconfig`), no exceptions in hot paths,
   no allocations inside the per-frame path.

## Layout

```
engine/
├── SConstruct                    # builds everything under src/ → game/bin/
├── gta_native.gdextension.example
├── godot-cpp/                    # submodule (pinned per Godot release)
└── src/
    ├── register_types.{h,cpp}    # extension entry point
    └── native_bench/             # smallest possible example module
```
