
Json::Value@ Nat2ToJson(const nat2 &in v) {
    auto @j = Json::Array();
    j.Add(v.x);
    j.Add(v.y);
    return j;
}

Json::Value@ Vec3ToJson(const vec3 &in v) {
    auto @j = Json::Array();
    j.Add(v.x);
    j.Add(v.y);
    j.Add(v.z);
    return j;
}

bool ListingThresholdIsValid(int v) {
    return v >= LISTING_THRESHOLD_MIN && v <= LISTING_THRESHOLD_MAX;
}

int ListingThresholdFromJson(const Json::Value@ j) {
    int v = LISTING_THRESHOLD_DEFAULT;
    if (j is null) return v;
    JsonX::SafeGetInt(j, "listingThreshold", v);
    return v;
}

void WriteListingThreshold(Json::Value@ j, int v) {
    if (j is null) return;
    if (v == LISTING_THRESHOLD_DEFAULT) return;
    if (!ListingThresholdIsValid(v)) return;
    j["listingThreshold"] = v;
}

vec3 JsonToVec3(const Json::Value@ j, const vec3 &in defaultValue = vec3(0, 0, 0)) {
    if (j.GetType() != Json::Type::Array) {
#if DEV
        warn("non-array value passed to JsonToVec3");
        PrintActiveContextStack(false);
#endif
        return defaultValue;
    }
    if (j.Length < 3) {
        warn("array value passed to JsonToVec3 is too short");
        return defaultValue;
    }
    return vec3(float(j[0]), float(j[1]), float(j[2]));
}
