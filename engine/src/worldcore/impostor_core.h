#pragma once

// Pure, runtime-free impostor math for the M3 distant-building LOD. Header-only
// and free of godot-cpp Variant types so it unit-tests in the plain-C++ harness
// (engine/tests/test_worldcore.cpp), same pattern as tile_streamer_core.h.
//
// Two jobs:
//  1. LOD decision — at what screen size a mesh is small enough to replace with
//     a flat camera-facing impostor billboard (the cheap distant proxy).
//  2. Atlas addressing — for an octahedral impostor (a small NxN atlas of the
//     object pre-rendered from many directions), which cell matches the current
//     view direction, so the billboard shows the right baked angle.
//
// The actual GPU bake (rendering each view into the atlas) is a runtime step the
// GDExtension class drives; this is the decidable math under it.

#include <cmath>

namespace worldcore_impostor {

// Octahedral encode: map a unit direction (y-up) to atlas UV in [0,1]^2. Up/down
// fold to the square's center/corners; azimuth wraps around the edges. This is
// the standard area-efficient sphere->square packing used for octahedral
// impostors. `dx,dy,dz` need not be normalized.
inline void octa_encode(double dx, double dy, double dz, double &u, double &v) {
    const double l1 = std::fabs(dx) + std::fabs(dy) + std::fabs(dz);
    if (l1 < 1e-12) {
        u = 0.5;
        v = 0.5;
        return;
    }
    double x = dx / l1;
    const double y = dy / l1;
    double z = dz / l1;
    if (y < 0.0) {
        const double ox = (1.0 - std::fabs(z)) * (x >= 0.0 ? 1.0 : -1.0);
        const double oz = (1.0 - std::fabs(x)) * (z >= 0.0 ? 1.0 : -1.0);
        x = ox;
        z = oz;
    }
    u = x * 0.5 + 0.5;
    v = z * 0.5 + 0.5;
}

// Atlas UV -> integer cell (col,row) in an NxN grid, clamped to the grid.
inline void atlas_cell(double u, double v, int grid_n, int &col, int &row) {
    if (grid_n < 1) {
        grid_n = 1;
    }
    int c = static_cast<int>(std::floor(u * grid_n));
    int r = static_cast<int>(std::floor(v * grid_n));
    col = c < 0 ? 0 : (c >= grid_n ? grid_n - 1 : c);
    row = r < 0 ? 0 : (r >= grid_n ? grid_n - 1 : r);
}

// Approximate on-screen radius of a bounding sphere, in pixels: how big the
// object appears. Shrinks with distance; used to decide mesh-vs-impostor.
inline double projected_radius_px(
        double radius, double distance, double fov_y_rad, double viewport_h) {
    if (distance <= 1e-6) {
        return viewport_h; // camera essentially inside the bound
    }
    const double half_extent = distance * std::tan(fov_y_rad * 0.5);
    if (half_extent <= 1e-9) {
        // Degenerate / near-zero FOV (extreme zoom) makes objects appear huge,
        // not tiny — return a large radius so should_impostor keeps the full
        // mesh rather than wrongly swapping in the low-detail impostor.
        return viewport_h;
    }
    return (radius / half_extent) * (viewport_h * 0.5);
}

// True when the object is small enough on screen (< threshold px) to swap the
// full mesh for its impostor billboard.
inline bool should_impostor(double radius, double distance, double fov_y_rad,
        double viewport_h, double threshold_px) {
    return projected_radius_px(radius, distance, fov_y_rad, viewport_h) < threshold_px;
}

} // namespace worldcore_impostor
