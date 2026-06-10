#include "native_bench.h"

#include <godot_cpp/core/class_db.hpp>

using namespace godot;

void NativeBench::_bind_methods() {
    ClassDB::bind_method(D_METHOD("ping"), &NativeBench::ping);
    ClassDB::bind_method(D_METHOD("sum_of_squares", "n"), &NativeBench::sum_of_squares);
}

String NativeBench::ping() const {
    return "pong from C++";
}

int64_t NativeBench::sum_of_squares(int64_t n) const {
    int64_t total = 0;
    for (int64_t i = 0; i < n; ++i) {
        total += i * i;
    }
    return total;
}
