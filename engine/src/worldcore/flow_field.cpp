#include "flow_field.h"

#include <cmath>

#include <godot_cpp/core/class_db.hpp>

using namespace godot;
using worldcore_flow::Grid;

void FlowField::_bind_methods() {
    ClassDB::bind_method(D_METHOD("set_cell_size", "v"), &FlowField::set_cell_size);
    ClassDB::bind_method(D_METHOD("get_cell_size"), &FlowField::get_cell_size);
    ClassDB::bind_method(D_METHOD("set_origin", "v"), &FlowField::set_origin);
    ClassDB::bind_method(D_METHOD("get_origin"), &FlowField::get_origin);
    ClassDB::bind_method(
            D_METHOD("build", "width", "height", "costs", "goal_world"), &FlowField::build);
    ClassDB::bind_method(D_METHOD("is_built"), &FlowField::is_built);
    ClassDB::bind_method(D_METHOD("direction_at", "world_xz"), &FlowField::direction_at);

    ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "cell_size"), "set_cell_size", "get_cell_size");
    ADD_PROPERTY(PropertyInfo(Variant::VECTOR2, "origin"), "set_origin", "get_origin");
}

void FlowField::set_cell_size(double p_v) {
    cell_size = p_v > 1e-6 ? p_v : cell_size;
}
double FlowField::get_cell_size() const {
    return cell_size;
}
void FlowField::set_origin(const Vector2 &p_v) {
    origin = p_v;
}
Vector2 FlowField::get_origin() const {
    return origin;
}

int FlowField::_cell_of(const Vector2 &p_world_xz) const {
    const int cx = static_cast<int>(std::floor((p_world_xz.x - origin.x) / cell_size));
    const int cz = static_cast<int>(std::floor((p_world_xz.y - origin.y) / cell_size));
    if (cx < 0 || cx >= grid_width || cz < 0 || cz >= grid_height) {
        return -1;
    }
    return cz * grid_width + cx;
}

void FlowField::build(int p_width, int p_height, const PackedFloat32Array &p_costs,
        const Vector2 &p_goal_world) {
    built = false;
    flow.clear();
    if (p_width <= 0 || p_height <= 0
            || p_costs.size() != static_cast<int64_t>(p_width) * static_cast<int64_t>(p_height)) {
        return;
    }
    grid_width = p_width;
    grid_height = p_height;

    std::vector<double> costs(static_cast<size_t>(p_costs.size()));
    for (int64_t i = 0; i < p_costs.size(); ++i) {
        costs[static_cast<size_t>(i)] = static_cast<double>(p_costs[i]);
    }

    const Grid g{grid_width, grid_height};
    const int goal_cell = _cell_of(p_goal_world);
    // A goal off-grid or on a wall yields no usable field — don't claim built.
    if (goal_cell < 0 || costs[static_cast<size_t>(goal_cell)] < 0.0) {
        return;
    }
    const std::vector<double> dist = worldcore_flow::integrate(g, costs, goal_cell);
    flow = worldcore_flow::flow_from(g, costs, dist);
    built = true;
}

bool FlowField::is_built() const {
    return built;
}

Vector2 FlowField::direction_at(const Vector2 &p_world_xz) const {
    if (!built) {
        return Vector2(0, 0);
    }
    const int c = _cell_of(p_world_xz);
    if (c < 0 || c >= static_cast<int>(flow.size())) {
        return Vector2(0, 0);
    }
    return Vector2(flow[static_cast<size_t>(c)].x, flow[static_cast<size_t>(c)].z);
}
