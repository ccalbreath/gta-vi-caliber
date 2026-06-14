#include "native_bench.h"

#include <godot_cpp/core/class_db.hpp>

#include "bench_kernels.h"

using namespace godot;

void NativeBench::_bind_methods() {
    ClassDB::bind_method(D_METHOD("ping"), &NativeBench::ping);
    ClassDB::bind_method(D_METHOD("sum_of_squares", "n"), &NativeBench::sum_of_squares);
}

String NativeBench::ping() const {
    return "pong from C++";
}

int64_t NativeBench::sum_of_squares(int64_t n) const {
    return worldcore_kernels::sum_of_squares(n);
}
