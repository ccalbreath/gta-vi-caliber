#pragma once

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/vector2i.hpp>
#include <godot_cpp/variant/vector3.hpp>

namespace godot {

// M3 distant-building impostor LOD helper. Decides when an object is small
// enough on screen to swap its mesh for a flat octahedral-impostor billboard,
// and which atlas cell matches the current view direction. The decidable math
// is the pure, unit-tested worldcore_impostor core; this bridges it to GDScript
// so the district LOD can drive a MultiMesh of impostors natively. The GPU bake
// of the atlas itself is a separate runtime step.
class Impostor : public RefCounted {
    GDCLASS(Impostor, RefCounted)

    int grid_size = 8;            // NxN baked view atlas
    double fov_y_degrees = 60.0;  // camera vertical FOV
    double viewport_height = 1080.0;
    double switch_threshold_px = 32.0; // below this on-screen radius -> impostor

protected:
    static void _bind_methods();

public:
    void set_grid_size(int p_v);
    int get_grid_size() const;
    void set_fov_y_degrees(double p_v);
    double get_fov_y_degrees() const;
    void set_viewport_height(double p_v);
    double get_viewport_height() const;
    void set_switch_threshold_px(double p_v);
    double get_switch_threshold_px() const;

    // Atlas cell (col,row) whose baked view best matches looking along view_dir.
    Vector2i atlas_cell_for_view(const Vector3 &p_view_dir) const;
    // Approximate on-screen radius (px) of a bound of `radius` at `distance`.
    double projected_radius_px(double p_radius, double p_distance) const;
    // Whether to render the impostor instead of the full mesh at this range.
    bool should_impostor(double p_radius, double p_distance) const;
};

} // namespace godot
