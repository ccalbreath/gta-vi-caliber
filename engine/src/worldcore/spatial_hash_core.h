#pragma once

// Pure, runtime-free uniform spatial hash for fast 2D (XZ ground-plane) radius
// queries — the foundation for crowd/traffic steering at scale (separation,
// cohesion, "who's near me" lookups for hundreds of agents per frame). Naive
// all-pairs neighbour search is O(n^2); the grid makes each query ~O(local
// density). Header-only and free of godot-cpp types so it unit-tests in the
// plain-C++ harness, same pattern as tile_streamer_core.h.

#include <cmath>
#include <cstdint>
#include <unordered_map>
#include <utility>
#include <vector>

namespace worldcore_spatial {

// Pack a 2D integer cell coordinate into one 64-bit key. Build it in unsigned
// space — left-shifting a negative *signed* value is undefined behavior, and
// world cells are routinely negative. cx -> high 32 bits, cz -> low 32 bits, so
// the mapping stays collision-free across the full int32 range.
inline int64_t cell_key(int cx, int cz) {
    const uint64_t ux = static_cast<uint32_t>(cx);
    const uint64_t uz = static_cast<uint32_t>(cz);
    return static_cast<int64_t>((ux << 32) | uz);
}

struct SpatialHash2D {
    double cell_size = 8.0;
    std::unordered_map<int64_t, std::vector<int>> cells;
    std::unordered_map<int, std::pair<double, double>> positions;

    explicit SpatialHash2D(double cs = 8.0) { cell_size = cs > 1e-6 ? cs : 1.0; }

    void clear() {
        cells.clear();
        positions.clear();
    }

    void cell_of(double x, double z, int &cx, int &cz) const {
        cx = static_cast<int>(std::floor(x / cell_size));
        cz = static_cast<int>(std::floor(z / cell_size));
    }

    // Upsert: insert the id at (x,z), or move it there if already present.
    // Re-inserting an existing id first drops its stale bucket entry, so the same
    // id can never appear twice in a query and an agent can be re-placed each
    // frame without clear(). (clear()+rebuild is still the common usage.)
    void insert(int id, double x, double z) {
        const auto existing = positions.find(id);
        if (existing != positions.end()) {
            int ocx, ocz;
            cell_of(existing->second.first, existing->second.second, ocx, ocz);
            std::vector<int> &old_bucket = cells[cell_key(ocx, ocz)];
            for (size_t i = 0; i < old_bucket.size(); ++i) {
                if (old_bucket[i] == id) {
                    old_bucket[i] = old_bucket.back();
                    old_bucket.pop_back();
                    break;
                }
            }
        }
        int cx, cz;
        cell_of(x, z, cx, cz);
        cells[cell_key(cx, cz)].push_back(id);
        positions[id] = std::make_pair(x, z);
    }

    // Ids within `radius` of (x,z). Scans the cells overlapping the query
    // circle's bounding box, then refines each candidate by true distance so the
    // result is a circle, not a square.
    std::vector<int> query_radius(double x, double z, double radius) const {
        std::vector<int> out;
        if (radius < 0.0) {
            return out;
        }
        const int min_cx = static_cast<int>(std::floor((x - radius) / cell_size));
        const int max_cx = static_cast<int>(std::floor((x + radius) / cell_size));
        const int min_cz = static_cast<int>(std::floor((z - radius) / cell_size));
        const int max_cz = static_cast<int>(std::floor((z + radius) / cell_size));
        const double r2 = radius * radius;
        for (int cz = min_cz; cz <= max_cz; ++cz) {
            for (int cx = min_cx; cx <= max_cx; ++cx) {
                const auto it = cells.find(cell_key(cx, cz));
                if (it == cells.end()) {
                    continue;
                }
                for (const int id : it->second) {
                    const auto pit = positions.find(id);
                    if (pit == positions.end()) {
                        continue;
                    }
                    const double dx = pit->second.first - x;
                    const double dz = pit->second.second - z;
                    if (dx * dx + dz * dz <= r2) {
                        out.push_back(id);
                    }
                }
            }
        }
        return out;
    }

    int size() const { return static_cast<int>(positions.size()); }
};

} // namespace worldcore_spatial
