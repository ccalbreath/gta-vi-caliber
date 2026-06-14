#pragma once

// Pure, runtime-free boids steering for the M4 crowd/traffic sim. Given an
// agent and its neighbours (found cheaply via the native SpatialHash), produce a
// steering force from the three classic flocking behaviours — separation,
// alignment, cohesion — combined and clamped. Header-only and free of godot-cpp
// types so it unit-tests headless, same pattern as the other worldcore cores.
// This is the math the GDExtension CrowdSteering class bridges to GDScript.

#include <cmath>
#include <cstddef>
#include <vector>

namespace worldcore_crowd {

struct Vec2 {
    double x;
    double z;
};

inline Vec2 add(Vec2 a, Vec2 b) { return Vec2{a.x + b.x, a.z + b.z}; }
inline Vec2 sub(Vec2 a, Vec2 b) { return Vec2{a.x - b.x, a.z - b.z}; }
inline Vec2 scale(Vec2 a, double s) { return Vec2{a.x * s, a.z * s}; }
inline double length(Vec2 a) { return std::sqrt(a.x * a.x + a.z * a.z); }

inline Vec2 normalize(Vec2 a) {
    const double l = length(a);
    return l > 1e-9 ? Vec2{a.x / l, a.z / l} : Vec2{0.0, 0.0};
}

inline Vec2 clamp_len(Vec2 a, double max_len) {
    if (max_len <= 0.0) {
        return Vec2{0.0, 0.0}; // no force budget — never flip direction
    }
    const double l = length(a);
    if (l > max_len && l > 1e-9) {
        return Vec2{a.x * max_len / l, a.z * max_len / l};
    }
    return a;
}

// Steer away from neighbours within `radius`, weighted by 1/distance so closer
// agents push harder. Averaged over the contributing neighbours.
inline Vec2 separation(Vec2 self_pos, const std::vector<Vec2> &neighbors, double radius) {
    Vec2 force{0.0, 0.0};
    int n = 0;
    for (const Vec2 &p : neighbors) {
        const Vec2 d = sub(self_pos, p);
        const double dist = length(d);
        if (dist > 1e-6 && dist < radius) {
            force = add(force, scale(normalize(d), 1.0 / dist));
            ++n;
        }
    }
    if (n > 0) {
        force = scale(force, 1.0 / n);
    }
    return force;
}

// Steer toward the average position (centroid) of neighbours.
inline Vec2 cohesion(Vec2 self_pos, const std::vector<Vec2> &neighbors) {
    if (neighbors.empty()) {
        return Vec2{0.0, 0.0};
    }
    Vec2 center{0.0, 0.0};
    for (const Vec2 &p : neighbors) {
        center = add(center, p);
    }
    center = scale(center, 1.0 / static_cast<double>(neighbors.size()));
    return sub(center, self_pos);
}

// Steer to match the average heading (velocity) of neighbours.
inline Vec2 alignment(const std::vector<Vec2> &neighbor_vels) {
    if (neighbor_vels.empty()) {
        return Vec2{0.0, 0.0};
    }
    Vec2 avg{0.0, 0.0};
    for (const Vec2 &v : neighbor_vels) {
        avg = add(avg, v);
    }
    return scale(avg, 1.0 / static_cast<double>(neighbor_vels.size()));
}

// Weighted sum of the three behaviours, clamped to max_force.
inline Vec2 combine(Vec2 sep, Vec2 ali, Vec2 coh, double w_sep, double w_ali, double w_coh,
        double max_force) {
    const Vec2 f = add(add(scale(sep, w_sep), scale(ali, w_ali)), scale(coh, w_coh));
    return clamp_len(f, max_force);
}

// Seek: steer toward `target` at full speed (desired velocity minus current).
inline Vec2 seek(Vec2 self_pos, Vec2 self_vel, Vec2 target, double max_speed) {
    const Vec2 desired = scale(normalize(sub(target, self_pos)), max_speed);
    return sub(desired, self_vel);
}

// Arrive: like seek, but ramp speed down linearly inside `slow_radius` so the
// agent settles at the target instead of orbiting it. Brakes when on top of it.
inline Vec2 arrive(
        Vec2 self_pos, Vec2 self_vel, Vec2 target, double slow_radius, double max_speed) {
    const Vec2 to_target = sub(target, self_pos);
    const double dist = length(to_target);
    if (dist < 1e-6) {
        return scale(self_vel, -1.0); // already there — kill momentum
    }
    double speed = max_speed;
    if (slow_radius > 1e-6 && dist < slow_radius) {
        speed = max_speed * (dist / slow_radius);
    }
    const Vec2 desired = scale(normalize(to_target), speed);
    return sub(desired, self_vel);
}

// Avoid circular obstacles: outward push from each obstacle the agent is inside
// (radius + margin), weighted by penetration depth. `positions` and `radii` are
// parallel; the shorter length wins so a malformed pair can't read past the end.
inline Vec2 avoid_obstacles(Vec2 self_pos, const std::vector<Vec2> &positions,
        const std::vector<double> &radii, double margin) {
    Vec2 force{0.0, 0.0};
    const std::size_t n = positions.size() < radii.size() ? positions.size() : radii.size();
    for (std::size_t i = 0; i < n; ++i) {
        const double safe = radii[i] + margin;
        if (safe <= 1e-6) {
            continue; // obstacle has no positive avoidance range — ignore it
        }
        const Vec2 d = sub(self_pos, positions[i]);
        const double dist = length(d);
        if (dist <= 1e-6) {
            force = add(force, Vec2{1.0, 0.0}); // dead centre — push a fixed way out
        } else if (dist < safe) {
            const double penetration = (safe - dist) / safe; // 0..1, deeper = stronger
            force = add(force, scale(normalize(d), penetration));
        }
    }
    return force;
}

} // namespace worldcore_crowd
