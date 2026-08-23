namespace Tests {
    void Collectibles_AssertHasMessage(CM_Editor::SpecIssue@[]@ issues, const string &in want, const string &in label) {
        for (uint i = 0; i < issues.Length; i++) {
            if (issues[i].message == want) return;
        }
        throw(label + ": missing '" + want + "' (have " + issues.Length + ")");
    }

    void Collectibles_AssertNoMessage(CM_Editor::SpecIssue@[]@ issues, const string &in banned, const string &in label) {
        for (uint i = 0; i < issues.Length; i++) {
            if (issues[i].message == banned) throw(label + ": unexpected '" + banned + "'");
        }
    }

    CM_Editor::ProjectCollectiblesComponent@ Collectibles_EmptyComp() {
        auto meta = CM_Editor::ProjectMeta("collectibles-test");
        return CM_Editor::ProjectCollectiblesComponent("", meta);
    }

    CM_Editor::ProjectHatsComponent@ Hats_EmptyComp() {
        auto meta = CM_Editor::ProjectMeta("hats-test");
        return CM_Editor::ProjectHatsComponent("", meta);
    }

    [Test]
    void Collectibles_NewHasNoCollectPath(Tests::Context@ ctx) {
        auto @c = CM_Editor::Collectible("shard");
        c.slug = "Collectible-1";
        CM_Editor::SpecIssue@[] issues;
        c.CollectIssues(issues);
        Collectibles_AssertHasMessage(issues, "no collect path", "path");
        Collectibles_AssertNoMessage(issues, "item requires a zone", "no item");
    }

    [Test]
    void Collectibles_CollectOnUnlockIsAPath(Tests::Context@ ctx) {
        auto @c = CM_Editor::Collectible("shard");
        c.slug = "Collectible-1";
        c.collectOnUnlock = true;
        CM_Editor::SpecIssue@[] issues;
        c.CollectIssues(issues);
        Collectibles_AssertNoMessage(issues, "no collect path", "grant");
        if (issues.Length != 0) throw("expected none, got " + issues.Length + " first=" + issues[0].message);
    }

    [Test]
    void Collectibles_PlacedZoneIsAPath(Tests::Context@ ctx) {
        auto @c = CM_Editor::Collectible("shard");
        c.slug = "Collectible-1";
        c.useZone = true;
        c.zone.posBottomCenter = vec3(400, 20, 80);
        c.zone.size = vec3(8, 8, 8);
        CM_Editor::SpecIssue@[] issues;
        c.CollectIssues(issues);
        Collectibles_AssertNoMessage(issues, "no collect path", "zone");
        if (issues.Length != 0) throw("expected none, got " + issues.Length + " first=" + issues[0].message);
    }

    [Test]
    void Collectibles_ItemRequiresZone(Tests::Context@ ctx) {
        auto @c = CM_Editor::Collectible("shard");
        c.slug = "Collectible-1";
        c.collectOnUnlock = true;
        c.item.idName = "DipsCollectable.Item.Gbx";
        c.item.pos = vec3(10, 20, 30);
        c.item.bound = true;
        CM_Editor::SpecIssue@[] issues;
        c.CollectIssues(issues);
        Collectibles_AssertHasMessage(issues, "item requires a zone", "item");
    }

    [Test]
    void Collectibles_ItemWithZoneOk(Tests::Context@ ctx) {
        auto @c = CM_Editor::Collectible("shard");
        c.slug = "Collectible-1";
        c.useZone = true;
        c.zone.posBottomCenter = vec3(10, 20, 30);
        c.zone.size = vec3(8, 8, 8);
        c.item.idName = "DipsCollectable.Item.Gbx";
        c.item.pos = vec3(10, 20, 30);
        c.item.pyr = vec3(0, 1.57, 0);
        c.item.bound = true;
        CM_Editor::SpecIssue@[] issues;
        c.CollectIssues(issues);
        if (issues.Length != 0) throw("expected none, got " + issues.Length + " first=" + issues[0].message);
        auto j = c.ToJson();
        if (!j.HasKey("zone")) throw("zone missing");
        if (!j.HasKey("item")) throw("item missing");
        if (!j["item"].HasKey("idName")) throw("idName missing");
        if (!j["item"].HasKey("loc")) throw("loc missing");
        if (!j["item"]["loc"].HasKey("pos")) throw("loc.pos missing");
        if (!j["item"]["loc"].HasKey("pyr")) throw("loc.pyr missing");
        if (j.HasKey("description")) throw("empty description should be omitted");
        if (j.HasKey("gatedBy")) throw("empty gatedBy should be omitted");
    }

    [Test]
    void Collectibles_DefaultSlugAndDuplicate(Tests::Context@ ctx) {
        auto @comp = Collectibles_EmptyComp();
        auto @a = CM_Editor::Collectible("a");
        a.collectOnUnlock = true;
        auto @b = CM_Editor::Collectible("b");
        b.collectOnUnlock = true;
        comp.AddCollectible(a);
        comp.AddCollectible(b);
        if (a.slug != "Collectible-1") throw("want Collectible-1, got " + a.slug);
        if (b.slug != "Collectible-2") throw("want Collectible-2, got " + b.slug);
        b.slug = "Collectible-1";
        CM_Editor::SpecIssue@[] issues;
        comp.CollectIssues(issues);
        Collectibles_AssertHasMessage(issues, "duplicate slug", "dup");
    }

    [Test]
    void Collectibles_SharedItemBind(Tests::Context@ ctx) {
        auto @comp = Collectibles_EmptyComp();
        auto @a = CM_Editor::Collectible("a");
        a.useZone = true;
        a.zone.posBottomCenter = vec3(10, 20, 30);
        a.item.idName = "Same.Item.Gbx";
        a.item.pos = vec3(1, 2, 3);
        a.item.pyr = vec3(0, 0, 0);
        a.item.bound = true;
        auto @b = CM_Editor::Collectible("b");
        b.useZone = true;
        b.zone.posBottomCenter = vec3(40, 20, 30);
        b.item.idName = "Same.Item.Gbx";
        b.item.pos = vec3(1, 2, 3);
        b.item.pyr = vec3(0, 0, 0);
        b.item.bound = true;
        comp.AddCollectible(a);
        comp.AddCollectible(b);
        CM_Editor::SpecIssue@[] issues;
        comp.CollectIssues(issues);
        Collectibles_AssertHasMessage(issues, "shared item bind", "share");
    }

    [Test]
    void Collectibles_LoadOldCollectablesKey(Tests::Context@ ctx) {
        auto @comp = Collectibles_EmptyComp();
        auto root = Json::Object();
        auto arr = Json::Array();
        auto one = Json::Object();
        one["slug"] = "Collectible-1";
        one["name"] = "legacy";
        one["collectOnUnlock"] = true;
        arr.Add(one);
        root["collectables"] = arr;
        comp.LoadItemsFromJson(root);
        if (comp.collectibles.Length != 1) throw("want 1, got " + comp.collectibles.Length);
        if (comp.collectibles[0].name != "legacy") throw("name");
        auto written = comp.ToJson();
        if (!written.HasKey("collectibles")) throw("write collectibles");
        if (written.HasKey("collectables")) throw("must not write collectables");
        auto items = comp.ToItemsJson();
        if (items.GetType() != Json::Type::Array) throw("items must be array");
    }

    [Test]
    void Hats_DefaultSlugAndDuplicate(Tests::Context@ ctx) {
        auto @comp = Hats_EmptyComp();
        auto @a = CM_Editor::Hat("crown");
        a.itemIdName = "Crown.Item.Gbx";
        auto @b = CM_Editor::Hat("cap");
        b.itemIdName = "Cap.Item.Gbx";
        comp.AddHat(a);
        comp.AddHat(b);
        if (a.slug != "Hat-1") throw("want Hat-1, got " + a.slug);
        if (b.slug != "Hat-2") throw("want Hat-2, got " + b.slug);
        b.slug = "Hat-1";
        CM_Editor::SpecIssue@[] issues;
        comp.CollectIssues(issues);
        Collectibles_AssertHasMessage(issues, "duplicate slug", "dup");
    }

    [Test]
    void Hats_ToJsonShape(Tests::Context@ ctx) {
        auto @h = CM_Editor::Hat("crown");
        h.slug = "Hat-1";
        h.description = "A fancy crown.";
        h.itemIdName = "Crown.Item.Gbx";
        h.image = "hats/crown.png";
        h.audio = "hats/unlock.mp3";
        h.unlock.finishThisMap = true;
        h.unlock.recordUids.InsertLast("DeepDipUid1111111111111111");
        h.unlock.recordUids.InsertLast("DeepDipUid2222222222222222");
        auto j = h.ToJson();
        if (string(j["slug"]) != "Hat-1") throw("slug");
        if (!j.HasKey("item") || string(j["item"]["idName"]) != "Crown.Item.Gbx") throw("item.idName");
        if (j["item"].HasKey("loc")) throw("hat item must not list loc/copies");
        if (!j.HasKey("unlock")) throw("unlock");
        if (!bool(j["unlock"]["finishThisMap"])) throw("finishThisMap");
        if (j["unlock"]["recordUids"].Length != 2) throw("recordUids AND list");
        if (string(j["image"]) != "hats/crown.png") throw("image");
        if (string(j["audio"]) != "hats/unlock.mp3") throw("audio");
        CM_Editor::SpecIssue@[] issues;
        h.CollectIssues(issues);
        if (issues.Length != 0) throw("expected none, got " + issues[0].message);
    }

    [Test]
    void Hats_EmptyIdNameIsError(Tests::Context@ ctx) {
        auto @h = CM_Editor::Hat("crown");
        h.slug = "Hat-1";
        CM_Editor::SpecIssue@[] issues;
        h.CollectIssues(issues);
        Collectibles_AssertHasMessage(issues, "item idName is empty", "idName");
    }

    Json::Value@ Collectibles_Vec3(const vec3 &in v) {
        auto j = Json::Array();
        j.Add(v.x);
        j.Add(v.y);
        j.Add(v.z);
        return j;
    }

    [Test]
    void Hats_LoadJsonRoundtrip(Tests::Context@ ctx) {
        auto @comp = Hats_EmptyComp();
        auto root = Json::Object();
        auto arr = Json::Array();
        auto one = Json::Object();
        one["slug"] = "Hat-1";
        one["name"] = "crown";
        auto item = Json::Object();
        item["idName"] = "Crown.Item.Gbx";
        one["item"] = item;
        one["image"] = "hats/crown.png";
        one["audio"] = "hats/unlock.mp3";
        auto unlock = Json::Object();
        unlock["finishThisMap"] = true;
        auto uids = Json::Array();
        uids.Add("DeepDipUid1111111111111111");
        uids.Add("DeepDipUid2222222222222222");
        unlock["recordUids"] = uids;
        one["unlock"] = unlock;
        arr.Add(one);
        root["hats"] = arr;
        comp.LoadItemsFromJson(root);
        if (comp.hats.Length != 1) throw("want 1 hat, got " + comp.hats.Length);
        auto @h = comp.hats[0];
        if (h.slug != "Hat-1") throw("slug");
        if (h.itemIdName != "Crown.Item.Gbx") throw("itemIdName");
        if (!h.unlock.finishThisMap) throw("finishThisMap");
        if (h.unlock.recordUids.Length != 2) throw("recordUids");
        if (h.unlock.recordUids[0] != "DeepDipUid1111111111111111") throw("uid0");
        if (h.image != "hats/crown.png") throw("image");
        if (h.audio != "hats/unlock.mp3") throw("audio");
        auto written = comp.ToJson();
        if (!written.HasKey("hats")) throw("write hats");
        if (string(written["hats"][0]["item"]["idName"]) != "Crown.Item.Gbx") throw("write idName");
        if (!bool(written["hats"][0]["unlock"]["finishThisMap"])) throw("write finishThisMap");
        if (written["hats"][0]["unlock"]["recordUids"].Length != 2) throw("write recordUids");
    }

    [Test]
    void Collectibles_LoadNewKeyWithItemLocAndGatedBy(Tests::Context@ ctx) {
        auto @comp = Collectibles_EmptyComp();
        auto root = Json::Object();
        auto arr = Json::Array();
        auto one = Json::Object();
        one["slug"] = "Collectible-1";
        one["name"] = "shard";
        one["collectOnUnlock"] = false;
        auto zone = Json::Object();
        zone["pos"] = Collectibles_Vec3(vec3(10, 20, 30));
        zone["size"] = Collectibles_Vec3(vec3(8, 8, 8));
        one["zone"] = zone;
        auto item = Json::Object();
        item["idName"] = "DipsCollectable.Item.Gbx";
        auto loc = Json::Object();
        loc["pos"] = Collectibles_Vec3(vec3(10, 20, 30));
        loc["pyr"] = Collectibles_Vec3(vec3(0, 1.57, 0));
        item["loc"] = loc;
        one["item"] = item;
        one["gatedBy"] = "Collectible-0";
        one["unlockScore"] = 12345;
        arr.Add(one);
        root["collectibles"] = arr;
        comp.LoadItemsFromJson(root);
        if (comp.collectibles.Length != 1) throw("want 1, got " + comp.collectibles.Length);
        auto @c = comp.collectibles[0];
        if (c.slug != "Collectible-1") throw("slug");
        if (!c.useZone) throw("useZone");
        if (c.zone.posBottomCenter.x != 10 || c.zone.posBottomCenter.y != 20 || c.zone.posBottomCenter.z != 30) throw("zone pos");
        if (c.item.idName != "DipsCollectable.Item.Gbx") throw("item idName");
        if (c.item.pos.x != 10 || c.item.pyr.y < 1.5 || c.item.pyr.y > 1.6) throw("item loc");
        if (!c.item.bound) throw("item bound");
        if (c.gatedBy != "Collectible-0") throw("gatedBy");
        if (!c.hasUnlockScore || c.unlockScore != 12345) throw("unlockScore");
        auto written = comp.ToJson();
        if (!written.HasKey("collectibles")) throw("write collectibles");
        if (written.HasKey("collectables")) throw("must not write collectables");
        if (!written["collectibles"][0].HasKey("item")) throw("write item");
        if (!written["collectibles"][0]["item"].HasKey("loc")) throw("write loc");
        if (string(written["collectibles"][0]["gatedBy"]) != "Collectible-0") throw("write gatedBy");
    }
}
