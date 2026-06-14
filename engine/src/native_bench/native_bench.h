#pragma once

#include <godot_cpp/classes/ref_counted.hpp>

namespace godot {

// Smallest possible example module: proves the C++ → GDScript pipeline works
// and gives benchmarks a native baseline to compare GDScript against.
// Real modules (streaming, crowds, ocean) follow this file layout.
class NativeBench : public RefCounted {
    GDCLASS(NativeBench, RefCounted)

protected:
    static void _bind_methods();

public:
    String ping() const;
    // Reference workload for GDScript-vs-native comparisons in benchmarks.
    int64_t sum_of_squares(int64_t n) const;
};

} // namespace godot
