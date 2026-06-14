#include "traffic_model.h"

#include <godot_cpp/core/class_db.hpp>

#include "traffic_core.h"

using namespace godot;

void TrafficModel::_bind_methods() {
    ClassDB::bind_method(D_METHOD("set_desired_speed", "v"), &TrafficModel::set_desired_speed);
    ClassDB::bind_method(D_METHOD("get_desired_speed"), &TrafficModel::get_desired_speed);
    ClassDB::bind_method(D_METHOD("set_max_accel", "v"), &TrafficModel::set_max_accel);
    ClassDB::bind_method(D_METHOD("get_max_accel"), &TrafficModel::get_max_accel);
    ClassDB::bind_method(D_METHOD("set_comfort_decel", "v"), &TrafficModel::set_comfort_decel);
    ClassDB::bind_method(D_METHOD("get_comfort_decel"), &TrafficModel::get_comfort_decel);
    ClassDB::bind_method(D_METHOD("set_min_gap", "v"), &TrafficModel::set_min_gap);
    ClassDB::bind_method(D_METHOD("get_min_gap"), &TrafficModel::get_min_gap);
    ClassDB::bind_method(D_METHOD("set_time_headway", "v"), &TrafficModel::set_time_headway);
    ClassDB::bind_method(D_METHOD("get_time_headway"), &TrafficModel::get_time_headway);

    ClassDB::bind_method(
            D_METHOD("acceleration", "speed", "gap", "leader_speed"), &TrafficModel::acceleration);

    ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "desired_speed"), "set_desired_speed",
            "get_desired_speed");
    ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "max_accel"), "set_max_accel", "get_max_accel");
    ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "comfort_decel"), "set_comfort_decel",
            "get_comfort_decel");
    ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "min_gap"), "set_min_gap", "get_min_gap");
    ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "time_headway"), "set_time_headway",
            "get_time_headway");
}

void TrafficModel::set_desired_speed(double p_v) {
    desired_speed = p_v > 0.0 ? p_v : desired_speed;
}
double TrafficModel::get_desired_speed() const {
    return desired_speed;
}
void TrafficModel::set_max_accel(double p_v) {
    max_accel = p_v > 0.0 ? p_v : max_accel;
}
double TrafficModel::get_max_accel() const {
    return max_accel;
}
void TrafficModel::set_comfort_decel(double p_v) {
    comfort_decel = p_v > 0.0 ? p_v : comfort_decel;
}
double TrafficModel::get_comfort_decel() const {
    return comfort_decel;
}
void TrafficModel::set_min_gap(double p_v) {
    min_gap = p_v >= 0.0 ? p_v : min_gap;
}
double TrafficModel::get_min_gap() const {
    return min_gap;
}
void TrafficModel::set_time_headway(double p_v) {
    time_headway = p_v >= 0.0 ? p_v : time_headway;
}
double TrafficModel::get_time_headway() const {
    return time_headway;
}

double TrafficModel::acceleration(double p_speed, double p_gap, double p_leader_speed) const {
    return worldcore_traffic::car_following_accel(p_speed, p_gap, p_leader_speed, desired_speed,
            max_accel, comfort_decel, min_gap, time_headway);
}
