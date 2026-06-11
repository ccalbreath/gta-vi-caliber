#pragma once

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/vector2.hpp>

#include "spatial_hash_core.h"

namespace godot {

// Native uniform spatial hash for fast 2D radius queries — the neighbour-lookup
// backbone for crowd/traffic steering (separation/cohesion over hundreds of
// agents per frame, where GDScript all-pairs search would choke). Rebuild it
// each frame: clear(), insert() every agent's id+XZ, then query_radius() per
// agent. The grid math is the pure, unit-tested worldcore_spatial core; this
// bridges it to GDScript. Absent the native module, GDScript keeps its own path.
class SpatialHash : public RefCounted {
    GDCLASS(SpatialHash, RefCounted)

    worldcore_spatial::SpatialHash2D hash{8.0};

protected:
    static void _bind_methods();

public:
    // Setting the cell size clears the grid (existing buckets become invalid).
    void set_cell_size(double p_v);
    double get_cell_size() const;

    void clear();
    void insert(int p_id, const Vector2 &p_xz);
    int size() const;
    // Ids within `radius` of `xz` (true-distance refined).
    PackedInt32Array query_radius(const Vector2 &p_xz, double p_radius) const;
};

} // namespace godot
