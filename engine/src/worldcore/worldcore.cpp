#include "worldcore.h"

#include <godot_cpp/core/class_db.hpp>

#include "worldcore_version.h"

using namespace godot;

void WorldCore::_bind_methods() {
    ClassDB::bind_method(D_METHOD("version"), &WorldCore::version);
}

String WorldCore::version() const {
    return WORLDCORE_VERSION_STRING;
}
