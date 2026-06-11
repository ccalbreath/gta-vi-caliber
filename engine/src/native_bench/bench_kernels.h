#pragma once

#include <cstdint>

// Pure compute kernels — no Godot dependencies — so engine/tests/ can verify
// them headlessly. NativeBench is only the GDScript-facing wrapper.
namespace worldcore_kernels {

inline int64_t sum_of_squares(int64_t n) {
    int64_t total = 0;
    for (int64_t i = 0; i < n; ++i) {
        total += i * i;
    }
    return total;
}

} // namespace worldcore_kernels
