# engine/ — custom C++ engine modules (GDExtension)

This is where we push Godot past its stock limits **without forking it**:
world streaming, impostor baking, crowd/traffic simulation, ocean. Modules
compile to shared libraries in `game/bin/` that a stock Godot editor loads
via `.gdextension` manifests.

Read [docs/ARCHITECTURE.md](../docs/ARCHITECTURE.md) first — native code
needs profile evidence, a working GDScript fallback story, and a narrow API.

## Build

```bash
pipx install scons                          # build system (or: pip install scons)
git submodule update --init --recursive     # pulls godot-cpp (first time)

cd engine
scons platform=macos target=template_debug      # or platform=linux / windows
```

This compiles `libworldcore.*` into `game/bin/` and copies
`worldcore.gdextension.example` to `game/bin/worldcore.gdextension`
(both gitignored). Restart the editor and the native classes appear:

```gdscript
if ClassDB.class_exists("WorldCore"):
    print(ClassDB.instantiate("WorldCore").version())   # "0.1.0"
```

Plain C++ unit tests (no Godot runtime needed):

```bash
scons tests && ./bin/test_worldcore
```

## godot-cpp version pin

`godot-cpp/` is a submodule pinned to **`master` @ `3a7edf0`**, which
bundles the extension API of **Godot 4.6 stable** (check
`godot-cpp/gdextension/extension_api.json` → `header.version_*`). Upstream
has not cut a `4.6` branch or `godot-4.6-stable` tag yet; the newest tag,
`godot-4.5-stable`, builds fine but its extension docs crash the 4.6.3
editor's doc generator on first import — hence the master pin. When
`godot-4.6-stable` lands, bump:

```bash
cd engine/godot-cpp
git fetch --tags && git checkout godot-4.6-stable
cd .. && git add godot-cpp   # commit the new pin + update this section
```

## Known issue: first `--import` after building crashes at exit

The **first** `godot --headless --path game --import` after the native
library appears finishes importing, then segfaults during exit while the
editor generates documentation for the extension classes
(`EditorHelp::_gen_extensions_docs` → `DocTools::generate`, Godot 4.6.3,
same family as [godotengine/godot#97937](https://github.com/godotengine/godot/issues/97937)).
The import itself completes; simply run it (or `tools/check.sh`) once more —
every subsequent import is clean. CI does exactly that (see
`.github/workflows/engine.yml`).

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
6. Pure logic goes in dependency-free headers (see
   `src/native_bench/bench_kernels.h`) with a test in `tests/`.

## Layout

```
engine/
├── SConstruct                    # builds everything under src/ → game/bin/
├── worldcore.gdextension.example # manifest template, copied by the build
├── godot-cpp/                    # submodule (pinned, see above)
├── tests/                        # plain C++ tests (`scons tests`)
└── src/
    ├── register_types.{h,cpp}    # extension entry point
    ├── worldcore/                # toolchain proof: WorldCore.version()
    └── native_bench/             # native baseline for benchmarks
```
