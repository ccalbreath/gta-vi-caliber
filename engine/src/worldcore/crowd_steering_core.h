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

} // namespace worldcore_crowd
