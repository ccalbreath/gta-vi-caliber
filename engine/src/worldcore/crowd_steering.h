#pragma once

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>
#include <godot_cpp/variant/vector2.hpp>

namespace godot {

// Native boids steering for the M4 crowd/traffic sim. Pair it with SpatialHash:
// query_radius() finds each agent's neighbours, gather their XZ positions and
// velocities, then steer() returns the combined separation/alignment/cohesion
// force (clamped to max_force). Doing this natively is what lets hundreds of
// agents flock per frame. The math is the pure, unit-tested worldcore_crowd
// core; this bridges it to GDScript. Absent the module, GDScript keeps its path.
class CrowdSteering : public RefCounted {
    GDCLASS(CrowdSteering, RefCounted)

    double separation_weight = 1.5;
    double alignment_weight = 1.0;
    double cohesion_weight = 1.0;
    double neighbor_radius = 4.0;
    double max_force = 8.0;

protected:
    static void _bind_methods();

public:
    void set_separation_weight(double p_v);
    double get_separation_weight() const;
    void set_alignment_weight(double p_v);
    double get_alignment_weight() const;
    void set_cohesion_weight(double p_v);
    double get_cohesion_weight() const;
    void set_neighbor_radius(double p_v);
    double get_neighbor_radius() const;
    void set_max_force(double p_v);
    double get_max_force() const;

    // Combined steering force for an agent given its neighbours' XZ positions and
    // velocities (parallel arrays). Returns the clamped force to apply.
    Vector2 steer(const Vector2 &p_self_pos, const Vector2 &p_self_vel,
            const PackedVector2Array &p_neighbor_positions,
            const PackedVector2Array &p_neighbor_velocities) const;
};

} // namespace godot
