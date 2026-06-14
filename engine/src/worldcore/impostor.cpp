#include "impostor.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/math.hpp>

#include "impostor_core.h"

using namespace godot;

void Impostor::_bind_methods() {
    ClassDB::bind_method(D_METHOD("set_grid_size", "v"), &Impostor::set_grid_size);
    ClassDB::bind_method(D_METHOD("get_grid_size"), &Impostor::get_grid_size);
    ClassDB::bind_method(D_METHOD("set_fov_y_degrees", "v"), &Impostor::set_fov_y_degrees);
    ClassDB::bind_method(D_METHOD("get_fov_y_degrees"), &Impostor::get_fov_y_degrees);
    ClassDB::bind_method(D_METHOD("set_viewport_height", "v"), &Impostor::set_viewport_height);
    ClassDB::bind_method(D_METHOD("get_viewport_height"), &Impostor::get_viewport_height);
    ClassDB::bind_method(
            D_METHOD("set_switch_threshold_px", "v"), &Impostor::set_switch_threshold_px);
    ClassDB::bind_method(D_METHOD("get_switch_threshold_px"), &Impostor::get_switch_threshold_px);

    ClassDB::bind_method(D_METHOD("atlas_cell_for_view", "view_dir"), &Impostor::atlas_cell_for_view);
    ClassDB::bind_method(
            D_METHOD("projected_radius_px", "radius", "distance"), &Impostor::projected_radius_px);
    ClassDB::bind_method(
            D_METHOD("should_impostor", "radius", "distance"), &Impostor::should_impostor);

    ADD_PROPERTY(PropertyInfo(Variant::INT, "grid_size"), "set_grid_size", "get_grid_size");
    ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "fov_y_degrees"), "set_fov_y_degrees",
            "get_fov_y_degrees");
    ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "viewport_height"), "set_viewport_height",
            "get_viewport_height");
    ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "switch_threshold_px"), "set_switch_threshold_px",
            "get_switch_threshold_px");
}

void Impostor::set_grid_size(int p_v) {
    grid_size = p_v >= 1 ? p_v : 1;
}

int Impostor::get_grid_size() const {
    return grid_size;
}

void Impostor::set_fov_y_degrees(double p_v) {
    fov_y_degrees = p_v;
}

double Impostor::get_fov_y_degrees() const {
    return fov_y_degrees;
}

void Impostor::set_viewport_height(double p_v) {
    viewport_height = p_v;
}

double Impostor::get_viewport_height() const {
    return viewport_height;
}

void Impostor::set_switch_threshold_px(double p_v) {
    switch_threshold_px = p_v;
}

double Impostor::get_switch_threshold_px() const {
    return switch_threshold_px;
}

Vector2i Impostor::atlas_cell_for_view(const Vector3 &p_view_dir) const {
    double u, v;
    worldcore_impostor::octa_encode(p_view_dir.x, p_view_dir.y, p_view_dir.z, u, v);
    int col, row;
    worldcore_impostor::atlas_cell(u, v, grid_size, col, row);
    return Vector2i(col, row);
}

double Impostor::projected_radius_px(double p_radius, double p_distance) const {
    return worldcore_impostor::projected_radius_px(
            p_radius, p_distance, Math::deg_to_rad(fov_y_degrees), viewport_height);
}

bool Impostor::should_impostor(double p_radius, double p_distance) const {
    return worldcore_impostor::should_impostor(
            p_radius, p_distance, Math::deg_to_rad(fov_y_degrees), viewport_height,
            switch_threshold_px);
}
