#pragma once

#include <godot_cpp/classes/ref_counted.hpp>

namespace godot {

// Toolchain proof for the engine track: the smallest class that crosses the
// C++ → GDScript boundary. GDScript feature-detects it with
// `ClassDB.class_exists("WorldCore")` and must keep working when it's absent.
class WorldCore : public RefCounted {
    GDCLASS(WorldCore, RefCounted)

protected:
    static void _bind_methods();

public:
    // Semver of the native module set, e.g. "0.1.0".
    String version() const;
};

} // namespace godot
