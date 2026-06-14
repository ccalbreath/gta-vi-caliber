#pragma once

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/vector2.hpp>

#include "flow_field_core.h"

namespace godot {

// Native crowd flow-field for M4 navigation at scale. Build it once per goal
// from a width×height cost grid (cost < 0 = wall), then every agent calls
// direction_at(world_xz) to get a routing direction toward the goal around
// obstacles — far cheaper than per-agent A* when a whole crowd shares a
// destination. The Dijkstra + flow math is the pure, unit-tested
// worldcore_flow core; this bridges it to GDScript.
class FlowField : public RefCounted {
    GDCLASS(FlowField, RefCounted)

    int grid_width = 0;
    int grid_height = 0;
    double cell_size = 4.0;
    Vector2 origin = Vector2(0, 0); // world XZ of cell (0,0)'s corner

    std::vector<worldcore_flow::Vec2> flow;
    bool built = false;

protected:
    static void _bind_methods();

public:
    void set_cell_size(double p_v);
    double get_cell_size() const;
    void set_origin(const Vector2 &p_v);
    Vector2 get_origin() const;

    // Build the field. `costs` is a flat width*height grid (row-major, cz*w+cx);
    // a cell < 0 is impassable. `goal_world` is the destination in world XZ.
    void build(int p_width, int p_height, const PackedFloat32Array &p_costs,
            const Vector2 &p_goal_world);

    bool is_built() const;

    // Routing direction (unit, or zero) at a world XZ position. Agents add this
    // to their steering to flow toward the goal around obstacles.
    Vector2 direction_at(const Vector2 &p_world_xz) const;

private:
    int _cell_of(const Vector2 &p_world_xz) const;
};

} // namespace godot
