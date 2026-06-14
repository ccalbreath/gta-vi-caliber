#include "spatial_hash.h"

#include <godot_cpp/core/class_db.hpp>

using namespace godot;

void SpatialHash::_bind_methods() {
    ClassDB::bind_method(D_METHOD("set_cell_size", "v"), &SpatialHash::set_cell_size);
    ClassDB::bind_method(D_METHOD("get_cell_size"), &SpatialHash::get_cell_size);
    ClassDB::bind_method(D_METHOD("clear"), &SpatialHash::clear);
    ClassDB::bind_method(D_METHOD("insert", "id", "xz"), &SpatialHash::insert);
    ClassDB::bind_method(D_METHOD("size"), &SpatialHash::size);
    ClassDB::bind_method(D_METHOD("query_radius", "xz", "radius"), &SpatialHash::query_radius);

    ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "cell_size"), "set_cell_size", "get_cell_size");
}

void SpatialHash::set_cell_size(double p_v) {
    hash.clear();
    hash.cell_size = p_v > 1e-6 ? p_v : 1.0;
}

double SpatialHash::get_cell_size() const {
    return hash.cell_size;
}

void SpatialHash::clear() {
    hash.clear();
}

void SpatialHash::insert(int p_id, const Vector2 &p_xz) {
    hash.insert(p_id, p_xz.x, p_xz.y);
}

int SpatialHash::size() const {
    return hash.size();
}

PackedInt32Array SpatialHash::query_radius(const Vector2 &p_xz, double p_radius) const {
    const std::vector<int> ids = hash.query_radius(p_xz.x, p_xz.y, p_radius);
    PackedInt32Array out;
    out.resize(static_cast<int64_t>(ids.size()));
    for (int64_t i = 0; i < static_cast<int64_t>(ids.size()); ++i) {
        out[i] = ids[static_cast<size_t>(i)];
    }
    return out;
}
