#pragma once

#include <godot_cpp/classes/ref_counted.hpp>

namespace godot {

// Native car-following (Intelligent Driver Model) for M4 traffic. Hold one per
// vehicle profile (car, bus, …); each frame call acceleration(speed, gap,
// leader_speed) to get the longitudinal accel that cruises to desired_speed and
// keeps a safe gap to the car ahead. Pair with the navigation/lane logic in
// GDScript. The math is the pure, unit-tested worldcore_traffic core.
class TrafficModel : public RefCounted {
    GDCLASS(TrafficModel, RefCounted)

    double desired_speed = 16.0; // ~58 km/h
    double max_accel = 1.5;
    double comfort_decel = 2.0;
    double min_gap = 2.0;
    double time_headway = 1.5;

protected:
    static void _bind_methods();

public:
    void set_desired_speed(double p_v);
    double get_desired_speed() const;
    void set_max_accel(double p_v);
    double get_max_accel() const;
    void set_comfort_decel(double p_v);
    double get_comfort_decel() const;
    void set_min_gap(double p_v);
    double get_min_gap() const;
    void set_time_headway(double p_v);
    double get_time_headway() const;

    // Longitudinal acceleration (m/s^2) given current speed, gap to the leader,
    // and the leader's speed. Use a very large gap for a clear road.
    double acceleration(double p_speed, double p_gap, double p_leader_speed) const;
};

} // namespace godot
