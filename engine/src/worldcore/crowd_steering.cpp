#include "crowd_steering.h"

#include <godot_cpp/core/class_db.hpp>

#include "crowd_steering_core.h"

using namespace godot;
using worldcore_crowd::Vec2;

void CrowdSteering::_bind_methods() {
    ClassDB::bind_method(
            D_METHOD("set_separation_weight", "v"), &CrowdSteering::set_separation_weight);
    ClassDB::bind_method(D_METHOD("get_separation_weight"), &CrowdSteering::get_separation_weight);
    ClassDB::bind_method(D_METHOD("set_alignment_weight", "v"), &CrowdSteering::set_alignment_weight);
    ClassDB::bind_method(D_METHOD("get_alignment_weight"), &CrowdSteering::get_alignment_weight);
    ClassDB::bind_method(D_METHOD("set_cohesion_weight", "v"), &CrowdSteering::set_cohesion_weight);
    ClassDB::bind_method(D_METHOD("get_cohesion_weight"), &CrowdSteering::get_cohesion_weight);
    ClassDB::bind_method(D_METHOD("set_neighbor_radius", "v"), &CrowdSteering::set_neighbor_radius);
    ClassDB::bind_method(D_METHOD("get_neighbor_radius"), &CrowdSteering::get_neighbor_radius);
    ClassDB::bind_method(D_METHOD("set_max_force", "v"), &CrowdSteering::set_max_force);
    ClassDB::bind_method(D_METHOD("get_max_force"), &CrowdSteering::get_max_force);

    ClassDB::bind_method(D_METHOD("set_max_speed", "v"), &CrowdSteering::set_max_speed);
    ClassDB::bind_method(D_METHOD("get_max_speed"), &CrowdSteering::get_max_speed);

    ClassDB::bind_method(D_METHOD("steer", "self_pos", "self_vel", "neighbor_positions",
                                 "neighbor_velocities"),
            &CrowdSteering::steer);
    ClassDB::bind_method(D_METHOD("arrive", "self_pos", "self_vel", "target", "slow_radius"),
            &CrowdSteering::arrive);
    ClassDB::bind_method(
            D_METHOD("avoid", "self_pos", "obstacle_positions", "obstacle_radii", "margin"),
            &CrowdSteering::avoid);

    ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "separation_weight"), "set_separation_weight",
            "get_separation_weight");
    ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "alignment_weight"), "set_alignment_weight",
            "get_alignment_weight");
    ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "cohesion_weight"), "set_cohesion_weight",
            "get_cohesion_weight");
    ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "neighbor_radius"), "set_neighbor_radius",
            "get_neighbor_radius");
    ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "max_force"), "set_max_force", "get_max_force");
    ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "max_speed"), "set_max_speed", "get_max_speed");
}

void CrowdSteering::set_separation_weight(double p_v) {
    separation_weight = p_v;
}
double CrowdSteering::get_separation_weight() const {
    return separation_weight;
}
void CrowdSteering::set_alignment_weight(double p_v) {
    alignment_weight = p_v;
}
double CrowdSteering::get_alignment_weight() const {
    return alignment_weight;
}
void CrowdSteering::set_cohesion_weight(double p_v) {
    cohesion_weight = p_v;
}
double CrowdSteering::get_cohesion_weight() const {
    return cohesion_weight;
}
void CrowdSteering::set_neighbor_radius(double p_v) {
    neighbor_radius = p_v > 0.0 ? p_v : neighbor_radius;
}
double CrowdSteering::get_neighbor_radius() const {
    return neighbor_radius;
}
void CrowdSteering::set_max_force(double p_v) {
    max_force = p_v > 0.0 ? p_v : 0.0; // negative would flip the steering direction
}
double CrowdSteering::get_max_force() const {
    return max_force;
}
void CrowdSteering::set_max_speed(double p_v) {
    max_speed = p_v > 0.0 ? p_v : 0.0;
}
double CrowdSteering::get_max_speed() const {
    return max_speed;
}

Vector2 CrowdSteering::steer(const Vector2 &p_self_pos, const Vector2 &p_self_vel,
        const PackedVector2Array &p_neighbor_positions,
        const PackedVector2Array &p_neighbor_velocities) const {
    std::vector<Vec2> positions;
    positions.reserve(static_cast<size_t>(p_neighbor_positions.size()));
    for (int64_t i = 0; i < p_neighbor_positions.size(); ++i) {
        const Vector2 v = p_neighbor_positions[i];
        positions.push_back(Vec2{v.x, v.y});
    }
    // The arrays are parallel (velocity[i] belongs to position[i]). Only take
    // velocities that pair with an actual position so a malformed/short/long
    // velocity array can't feed alignment phantom headings (Codex review).
    std::vector<Vec2> velocities;
    const int64_t paired = p_neighbor_positions.size() < p_neighbor_velocities.size()
            ? p_neighbor_positions.size()
            : p_neighbor_velocities.size();
    velocities.reserve(static_cast<size_t>(paired));
    for (int64_t i = 0; i < paired; ++i) {
        const Vector2 v = p_neighbor_velocities[i];
        velocities.push_back(Vec2{v.x, v.y});
    }

    const Vec2 self_pos{p_self_pos.x, p_self_pos.y};
    const Vec2 sep = worldcore_crowd::separation(self_pos, positions, neighbor_radius);
    const Vec2 coh = worldcore_crowd::cohesion(self_pos, positions);
    const Vec2 ali = worldcore_crowd::alignment(velocities);
    const Vec2 f = worldcore_crowd::combine(
            sep, ali, coh, separation_weight, alignment_weight, cohesion_weight, max_force);
    return Vector2(f.x, f.z);
}

Vector2 CrowdSteering::arrive(const Vector2 &p_self_pos, const Vector2 &p_self_vel,
        const Vector2 &p_target, double p_slow_radius) const {
    const Vec2 f = worldcore_crowd::clamp_len(
            worldcore_crowd::arrive(Vec2{p_self_pos.x, p_self_pos.y},
                    Vec2{p_self_vel.x, p_self_vel.y}, Vec2{p_target.x, p_target.y}, p_slow_radius,
                    max_speed),
            max_force);
    return Vector2(f.x, f.z);
}

Vector2 CrowdSteering::avoid(const Vector2 &p_self_pos,
        const PackedVector2Array &p_obstacle_positions, const PackedFloat32Array &p_obstacle_radii,
        double p_margin) const {
    std::vector<Vec2> positions;
    std::vector<double> radii;
    const int64_t n = p_obstacle_positions.size() < p_obstacle_radii.size()
            ? p_obstacle_positions.size()
            : p_obstacle_radii.size();
    positions.reserve(static_cast<size_t>(n));
    radii.reserve(static_cast<size_t>(n));
    for (int64_t i = 0; i < n; ++i) {
        const Vector2 v = p_obstacle_positions[i];
        positions.push_back(Vec2{v.x, v.y});
        radii.push_back(static_cast<double>(p_obstacle_radii[i]));
    }
    const Vec2 f = worldcore_crowd::clamp_len(
            worldcore_crowd::avoid_obstacles(Vec2{p_self_pos.x, p_self_pos.y}, positions, radii,
                    p_margin),
            max_force);
    return Vector2(f.x, f.z);
}
