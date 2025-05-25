
Json::Value@ Nat2ToJson(const nat2 &in v) {
    auto @j = Json::Array();
    j.Add(v.x);
    j.Add(v.y);
    return j;
}

vec3 JsonToVec3(const Json::Value@ j, const vec3 &in defaultValue = vec3(0, 0, 0)) {
    if (j.GetType() != Json::Type::Array) {
        warn("non-array value passed to JsonToVec3");
        return defaultValue;
    }
    if (j.Length < 3) {
        warn("array value passed to JsonToVec3 is too short");
        return defaultValue;
    }
    return vec3(float(j[0]), float(j[1]), float(j[2]));
}
