#pragma once

// Pure, runtime-free crowd flow-field for M4 navigation at scale. A flow field
// is computed ONCE per goal (Dijkstra from the goal over a cost grid → an
// integration/distance field → a per-cell "downhill" direction), then hundreds
// of agents sample it for free to route around obstacles toward the shared goal.
// This is the scale-right complement to per-agent steering: steering handles
// local avoidance/neighbours, the flow field handles global routing. Header-only
// and free of godot-cpp types, so it unit-tests headless like the other cores.

#include <cmath>
#include <cstddef>
#include <functional>
#include <limits>
#include <queue>
#include <utility>
#include <vector>

namespace worldcore_flow {

struct Vec2 {
    double x;
    double z;
};

struct Grid {
    int width = 0;
    int height = 0;
    int index(int cx, int cz) const { return cz * width + cx; }
    bool in_bounds(int cx, int cz) const {
        return cx >= 0 && cx < width && cz >= 0 && cz < height;
    }
};

// 8-connected neighbour offsets and their step lengths (diagonals cost √2).
inline const int *neighbour_dx() {
    static const int dx[8] = {1, -1, 0, 0, 1, 1, -1, -1};
    return dx;
}
inline const int *neighbour_dz() {
    static const int dz[8] = {0, 0, 1, -1, 1, -1, 1, -1};
    return dz;
}
inline const double *neighbour_step() {
    static const double s[8] = {1.0, 1.0, 1.0, 1.0, 1.4142135624, 1.4142135624, 1.4142135624,
            1.4142135624};
    return s;
}

// A diagonal step (k >= 4) "cuts a corner" if either of the two orthogonal cells
// it passes between is a wall. Forbidding it stops agents clipping through wall
// corners. Returns true when the diagonal from (cx,cz) in direction k is blocked.
inline bool diagonal_cuts_corner(
        const Grid &g, const std::vector<double> &costs, int cx, int cz, int k) {
    if (k < 4) {
        return false;
    }
    const int *dx = neighbour_dx();
    const int *dz = neighbour_dz();
    const int ax = cx + dx[k];
    const int bz = cz + dz[k];
    if (!g.in_bounds(ax, cz) || costs[g.index(ax, cz)] < 0.0) {
        return true;
    }
    if (!g.in_bounds(cx, bz) || costs[g.index(cx, bz)] < 0.0) {
        return true;
    }
    return false;
}

// Dijkstra integration field from `goal_cell`. `costs[i] < 0` marks an
// impassable cell (wall); otherwise costs[i] is the per-cell movement cost
// (>=1 typical), charged for the cell being ENTERED toward the goal. Returns
// per-cell distance-to-goal; unreachable cells are +inf.
inline std::vector<double> integrate(
        const Grid &g, const std::vector<double> &costs, int goal_cell) {
    const double inf = std::numeric_limits<double>::infinity();
    std::vector<double> dist(static_cast<size_t>(g.width) * static_cast<size_t>(g.height), inf);
    if (goal_cell < 0 || goal_cell >= static_cast<int>(dist.size()) || costs[goal_cell] < 0.0) {
        return dist;
    }
    using Item = std::pair<double, int>;
    std::priority_queue<Item, std::vector<Item>, std::greater<Item>> pq;
    dist[goal_cell] = 0.0;
    pq.push(std::make_pair(0.0, goal_cell));
    const int *dx = neighbour_dx();
    const int *dz = neighbour_dz();
    const double *step = neighbour_step();
    while (!pq.empty()) {
        const double d = pq.top().first;
        const int c = pq.top().second;
        pq.pop();
        if (d > dist[c]) {
            continue;
        }
        const int cx = c % g.width;
        const int cz = c / g.width;
        for (int k = 0; k < 8; ++k) {
            const int nx = cx + dx[k];
            const int nz = cz + dz[k];
            if (!g.in_bounds(nx, nz)) {
                continue;
            }
            const int nc = g.index(nx, nz);
            if (costs[nc] < 0.0) {
                continue; // wall
            }
            if (diagonal_cuts_corner(g, costs, cx, cz, k)) {
                continue; // don't let the field flow diagonally through a corner
            }
            // Charge the cost of the cell entered on the forward move (nc -> c
            // heads toward the goal, so the agent enters c).
            const double nd = dist[c] + step[k] * costs[c];
            if (nd < dist[nc]) {
                dist[nc] = nd;
                pq.push(std::make_pair(nd, nc));
            }
        }
    }
    return dist;
}

// Per-cell flow direction: a unit vector toward the 8-neighbour with the lowest
// integration distance (downhill toward the goal), skipping diagonals that cut a
// wall corner. Zero at the goal and on unreachable cells. Needs `costs` to apply
// the same corner rule the integration used.
inline std::vector<Vec2> flow_from(
        const Grid &g, const std::vector<double> &costs, const std::vector<double> &dist) {
    std::vector<Vec2> flow(
            static_cast<size_t>(g.width) * static_cast<size_t>(g.height), Vec2{0.0, 0.0});
    const int *dx = neighbour_dx();
    const int *dz = neighbour_dz();
    for (int cz = 0; cz < g.height; ++cz) {
        for (int cx = 0; cx < g.width; ++cx) {
            const int c = g.index(cx, cz);
            if (!std::isfinite(dist[c])) {
                continue;
            }
            double best = dist[c];
            int best_k = -1;
            for (int k = 0; k < 8; ++k) {
                const int nx = cx + dx[k];
                const int nz = cz + dz[k];
                if (!g.in_bounds(nx, nz)) {
                    continue;
                }
                if (diagonal_cuts_corner(g, costs, cx, cz, k)) {
                    continue;
                }
                const double nd = dist[g.index(nx, nz)];
                if (nd < best) {
                    best = nd;
                    best_k = k;
                }
            }
            if (best_k >= 0) {
                const double len = std::sqrt(static_cast<double>(
                        dx[best_k] * dx[best_k] + dz[best_k] * dz[best_k]));
                flow[c] = Vec2{dx[best_k] / len, dz[best_k] / len};
            }
        }
    }
    return flow;
}

} // namespace worldcore_flow
