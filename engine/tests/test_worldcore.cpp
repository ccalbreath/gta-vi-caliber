// Plain-C++ unit tests for engine logic that doesn't need a Godot runtime.
// Build & run: scons tests (see engine/SConstruct), or let CI do it.
// Keep this dependency-free (no test framework) until the suite outgrows it.
#include <cstdio>
#include <cstring>

#include "../src/native_bench/bench_kernels.h"
#include "../src/worldcore/worldcore_version.h"

static int failures = 0;

#define CHECK(cond)                                                          \
    do {                                                                     \
        if (!(cond)) {                                                       \
            ++failures;                                                      \
            std::fprintf(stderr, "FAIL %s:%d: %s\n", __FILE__, __LINE__, #cond); \
        }                                                                    \
    } while (0)

static void test_version_is_consistent() {
    char expected[32];
    std::snprintf(expected, sizeof(expected), "%d.%d.%d", WORLDCORE_VERSION_MAJOR,
            WORLDCORE_VERSION_MINOR, WORLDCORE_VERSION_PATCH);
    CHECK(std::strcmp(expected, WORLDCORE_VERSION_STRING) == 0);
    CHECK(std::strlen(WORLDCORE_VERSION_STRING) > 0);
}

static void test_sum_of_squares() {
    CHECK(worldcore_kernels::sum_of_squares(0) == 0);
    CHECK(worldcore_kernels::sum_of_squares(1) == 0); // sums i in [0, n)
    CHECK(worldcore_kernels::sum_of_squares(4) == 0 + 1 + 4 + 9);
    CHECK(worldcore_kernels::sum_of_squares(100) == 328350);
}

int main() {
    test_version_is_consistent();
    test_sum_of_squares();
    if (failures > 0) {
        std::fprintf(stderr, "engine tests: %d failure(s)\n", failures);
        return 1;
    }
    std::printf("engine tests: all passed\n");
    return 0;
}
