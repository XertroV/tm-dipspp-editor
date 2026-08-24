namespace Tests {
    CM_Editor::ProjectInfoComponent@ ProjInfo_EmptyComp() {
        auto meta = CM_Editor::ProjectMeta("listing-threshold-test");
        auto @info = CM_Editor::ProjectInfoComponent("", meta);
        info.CreateDefaultJsonObject();
        return info;
    }

    [Test]
    void ListingThreshold_DefaultOmitsKey(Tests::Context@ ctx) {
        auto @info = ProjInfo_EmptyComp();
        if (info.ListingThreshold != LISTING_THRESHOLD_DEFAULT) throw("default want 25, got " + info.ListingThreshold);
        if (info.ro_data.HasKey("listingThreshold")) throw("default project json should omit listingThreshold");
        auto spec = Json::Object();
        WriteListingThreshold(spec, info.ListingThreshold);
        if (spec.HasKey("listingThreshold")) throw("combined json should omit default 25");
    }

    [Test]
    void ListingThreshold_PersistAndWriteNonDefault(Tests::Context@ ctx) {
        auto @info = ProjInfo_EmptyComp();
        info.ListingThreshold = 40;
        if (info.ListingThreshold != 40) throw("persist want 40, got " + info.ListingThreshold);
        if (!info.ro_data.HasKey("listingThreshold")) throw("project json should keep 40");
        if (int(info.ro_data["listingThreshold"]) != 40) throw("project json value");
        auto spec = Json::Object();
        WriteListingThreshold(spec, info.ListingThreshold);
        if (!spec.HasKey("listingThreshold")) throw("combined json should write 40");
        if (int(spec["listingThreshold"]) != 40) throw("combined json value");
    }

    [Test]
    void ListingThreshold_FromJsonMissingIsDefault(Tests::Context@ ctx) {
        auto j = Json::Object();
        if (ListingThresholdFromJson(j) != LISTING_THRESHOLD_DEFAULT) throw("missing key");
        if (ListingThresholdFromJson(null) != LISTING_THRESHOLD_DEFAULT) throw("null json");
    }

    [Test]
    void ListingThreshold_ClampRange(Tests::Context@ ctx) {
        if (!ListingThresholdIsValid(5)) throw("5 valid");
        if (!ListingThresholdIsValid(25)) throw("25 valid");
        if (!ListingThresholdIsValid(100)) throw("100 valid");
        if (ListingThresholdIsValid(4)) throw("4 invalid");
        if (ListingThresholdIsValid(101)) throw("101 invalid");
        auto spec = Json::Object();
        WriteListingThreshold(spec, 4);
        if (spec.HasKey("listingThreshold")) throw("must not write below min");
        WriteListingThreshold(spec, 101);
        if (spec.HasKey("listingThreshold")) throw("must not write above max");
        WriteListingThreshold(spec, 5);
        if (!spec.HasKey("listingThreshold") || int(spec["listingThreshold"]) != 5) throw("write min");
    }
}
