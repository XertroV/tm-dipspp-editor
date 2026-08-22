namespace CM_Editor {
    // MARK: Collectibles

    const float ITEM_POSE_POS_EPS2 = 1e-4; // ~1 cm
    const float ITEM_POSE_PYR_EPS2 = 1e-8;

    class SpecIssue {
        string slug;
        string message;

        SpecIssue(const string &in slug_, const string &in message_) {
            slug = slug_;
            message = message_;
        }
    }

    class PickedMapItem {
        string idName;
        vec3 pos;
        vec3 pyr;
        bool hasKinematic = false;
    }

    PickedMapItem@ TryReadPickedMapItem() {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        if (editor is null || editor.PickedObject is null) return null;
        auto po = editor.PickedObject;
        if (po.ItemModel is null) return null;
        auto picked = PickedMapItem();
        picked.idName = po.ItemModel.IdName;
        picked.pos = po.AbsolutePositionInMap;
        picked.pyr = vec3(po.Pitch, po.Yaw, po.Roll);
        picked.hasKinematic = ItemModelHasKinematic(po.ItemModel);
        if (picked.idName.Length == 0) return null;
        return picked;
    }

    bool ItemModelHasKinematic(CGameItemModel@ model) {
        if (model is null || model.EntityModel is null) return false;
        auto prefab = cast<CPlugPrefab>(model.EntityModel);
        if (prefab is null) return false;
        for (uint i = 0; i < prefab.Ents.Length; i++) {
            if (cast<NPlugDyna_SKinematicConstraint>(prefab.Ents[i].Model) !is null) return true;
        }
        return false;
    }

    bool SameItemPose(const vec3 &in posA, const vec3 &in pyrA, const vec3 &in posB, const vec3 &in pyrB) {
        return (posA - posB).LengthSquared() <= ITEM_POSE_POS_EPS2
            && (pyrA - pyrB).LengthSquared() <= ITEM_POSE_PYR_EPS2;
    }

    Json::Value@ ZoneToJson(EditableTrigger@ t) {
        auto j = Json::Object();
        j["pos"] = Vec3ToJson(t.posBottomCenter);
        j["size"] = Vec3ToJson(t.size);
        return j;
    }

    class CollectibleItemBind {
        string idName;
        vec3 pos;
        vec3 pyr;
        bool bound = false;

        CollectibleItemBind() {}

        CollectibleItemBind(const Json::Value@ j) {
            LoadFromJson(j);
        }

        void LoadFromJson(const Json::Value@ j) {
            bound = false;
            idName = "";
            pos = vec3();
            pyr = vec3();
            if (j is null || j.GetType() != Json::Type::Object) return;
            JsonX::SafeGetString(j, "idName", idName);
            auto locJ = j.Get("loc", Json::Value());
            if (locJ.GetType() == Json::Type::Object) {
                pos = JsonToVec3(locJ.Get("pos", Json::Value()), vec3());
                pyr = JsonToVec3(locJ.Get("pyr", Json::Value()), vec3());
            } else if (locJ.GetType() == Json::Type::Array) {
                pos = JsonToVec3(locJ, vec3());
            }
            bound = idName.Length > 0;
        }

        void BindFromPicked(PickedMapItem@ picked) {
            idName = picked.idName;
            pos = picked.pos;
            pyr = picked.pyr;
            bound = true;
        }

        void Clear() {
            idName = "";
            pos = vec3();
            pyr = vec3();
            bound = false;
        }

        Json::Value@ ToJson() const {
            auto j = Json::Object();
            j["idName"] = idName;
            auto loc = Json::Object();
            loc["pos"] = Vec3ToJson(pos);
            loc["pyr"] = Vec3ToJson(pyr);
            j["loc"] = loc;
            return j;
        }
    }

    class Collectible {
        string slug;
        string name;
        string description;
        bool collectOnUnlock = false;
        bool useZone = false;
        EditableTrigger@ zone;
        CollectibleItemBind@ item;
        string gatedBy;
        bool hasUnlockScore = false;
        int64 unlockScore = 0;

        Collectible(const string &in _name = "New Collectible") {
            name = _name;
            slug = "";
            @zone = EditableTrigger(DEFAULT_VL_POS, DEFAULT_MT_SIZE, "Collectible", _name);
            @item = CollectibleItemBind();
        }

        Collectible(const Json::Value@ j) {
            name = j.Get("name", "");
            slug = j.Get("slug", "");
            description = j.Get("description", "");
            collectOnUnlock = j.Get("collectOnUnlock", false);
            gatedBy = j.Get("gatedBy", "");
            @zone = EditableTrigger(DEFAULT_VL_POS, DEFAULT_MT_SIZE, "Collectible", name);
            @item = CollectibleItemBind();
            useZone = false;
            if (j.HasKey("zone") && j["zone"].GetType() == Json::Type::Object) {
                @zone = EditableTrigger(j["zone"], DEFAULT_VL_POS, DEFAULT_MT_SIZE, "Collectible", name);
                useZone = zone.hasBeenSet;
            }
            if (j.HasKey("item") && j["item"].GetType() == Json::Type::Object) {
                item.LoadFromJson(j["item"]);
            }
            int64 score = 0;
            if (JsonX::SafeGetInt64(j, "unlockScore", score)) {
                hasUnlockScore = true;
                unlockScore = score;
            }
        }

        bool HasPlacedZone() const {
            return useZone && !IsDefaultPlacement(zone);
        }

        bool HasCollectPath() const {
            return collectOnUnlock || HasPlacedZone();
        }

        Json::Value@ ToJson() const {
            auto j = Json::Object();
            j["slug"] = slug;
            j["name"] = name;
            if (description.Length > 0) j["description"] = description;
            j["collectOnUnlock"] = collectOnUnlock;
            if (HasPlacedZone()) {
                j["zone"] = ZoneToJson(zone);
            }
            if (item.bound && item.idName.Length > 0) {
                j["item"] = item.ToJson();
            }
            if (gatedBy.Length > 0) j["gatedBy"] = gatedBy;
            if (hasUnlockScore) j["unlockScore"] = unlockScore;
            return j;
        }

        void AddIssue(SpecIssue@[]@ issues, const string &in message) {
            issues.InsertLast(SpecIssue(slug.Length > 0 ? slug : name, message));
        }

        void CollectIssues(SpecIssue@[]@ issues) {
            if (slug.Length == 0) AddIssue(issues, "slug is empty");
            if (item.bound && item.idName.Length > 0 && !HasPlacedZone()) {
                AddIssue(issues, "item requires a zone");
            }
            if (!HasCollectPath()) AddIssue(issues, "no collect path");
        }

        bool HasIssues() {
            SpecIssue@[] issues;
            CollectIssues(issues);
            return issues.Length > 0;
        }

        void DrawIssueLine(const string &in message) {
            UI::PushStyleColor(UI::Col::Text, cOrange);
            UI::TextWrapped(Icons::ExclamationTriangle + " " + message);
            UI::PopStyleColor();
        }

        void DrawEditor(ProjectTab@ pTab) {
            slug = UI::InputText("Slug", slug);
            UI::TextWrapped("Identity. After publish, changing this is a new collectible.");
            description = UI::InputText("Description (optional)", description);
            UI::Separator();

            collectOnUnlock = UI::Checkbox("Collect on unlock", collectOnUnlock);
            AddSimpleTooltip("When this collectible unlocks, it is also collected (grant-as-collect). Without this, unlock only allows a later zone collect.");

            UI::Separator();
            UI::Text("Pickup zone");
            useZone = UI::Checkbox("Use zone", useZone);
            if (item.bound && item.idName.Length > 0) {
                useZone = true;
                UI::TextWrapped("\\$888 A bound item requires a zone.");
            }
            if (useZone) {
                if (IsDefaultPlacement(zone)) DrawIssueLine("Zone is still at the default. Place it on the map.");
                zone.name = name;
                zone.DrawEditorUI();
                zone.DrawNvgBox(IsDefaultPlacement(zone) ? cOrange : cCyan);
            }

            UI::Separator();
            UI::Text("3D item (optional animation)");
            if (item.bound && item.idName.Length > 0) {
                UI::Text("idName: " + item.idName);
                UI::Text("pos: " + item.pos.ToString());
                UI::Text("pyr: " + item.pyr.ToString());
                if (UI::Button(Icons::TrashO + " Clear item")) {
                    item.Clear();
                }
            } else {
                UI::TextWrapped("\\$888 No item bound. Pick an item in the map editor, then bind it.");
            }
            if (UI::Button(Icons::Crosshairs + " Bind picked item")) {
                auto picked = TryReadPickedMapItem();
                if (picked is null) {
                    NotifyWarning("Pick an item in the map editor first (PickedObject).");
                } else {
                    item.BindFromPicked(picked);
                    useZone = true;
                    if (!picked.hasKinematic) {
                        NotifyWarning("Picked item has no kinematic constraint; collect animation will not run. Zone pickup still works.");
                    } else {
                        NotifySuccess("Bound " + picked.idName);
                    }
                }
            }
            AddSimpleTooltip("Reads editor.PickedObject: idName + loc (pos, pyr). Copies are not listed; identity is model + pose.");

            UI::Separator();
            UI::Text("Gate (optional)");
            DrawGatedBy(pTab);
            hasUnlockScore = UI::Checkbox("Require unlock score", hasUnlockScore);
            AddSimpleTooltip("Optional score from the gating minigame. Unset means any finish. Inclusive. Units follow that minigame.");
            if (hasUnlockScore) {
                string scoreStr = tostring(unlockScore);
                scoreStr = UI::InputText("Unlock Score", scoreStr);
                int64 parsed = 0;
                if (scoreStr.Length > 0 && Text::TryParseInt64(scoreStr, parsed)) {
                    unlockScore = parsed;
                }
            }

            UI::Separator();
            if (!HasCollectPath()) DrawIssueLine("No collect path. Enable collect-on-unlock and/or place a zone.");
            if (item.bound && item.idName.Length > 0 && !HasPlacedZone()) DrawIssueLine("A bound item requires a placed zone.");
            if (slug.Length == 0) DrawIssueLine("Slug is empty.");
        }

        void DrawGatedBy(ProjectTab@ pTab) {
            string preview = gatedBy.Length > 0 ? gatedBy : "(none)";
            if (UI::BeginCombo("Gated by minigame", preview)) {
                if (UI::Selectable("(none)", gatedBy.Length == 0)) gatedBy = "";
                if (pTab !is null) {
                    auto mg = pTab.GetMinigamesComponent();
                    if (mg !is null) {
                        for (uint i = 0; i < mg.minigames.Length; i++) {
                            string s = mg.minigames[i].slug;
                            if (s.Length == 0) continue;
                            if (UI::Selectable(s, gatedBy == s)) gatedBy = s;
                        }
                    }
                }
                UI::EndCombo();
            }
            gatedBy = UI::InputText("Gated by slug", gatedBy);
            AddSimpleTooltip("Minigame slug that unlocks this collectible. Leave empty for always-unlocked (zone still required to collect unless collect-on-unlock).");
        }
    }

    class ProjectCollectiblesComponent : ProjectComponent {
        array<Collectible@> collectibles;
        int editingIx = -1;

        ProjectCollectiblesComponent(const string &in jsonPath, ProjectMeta@ meta) {
            super(jsonPath, meta);
            name = "Collectibles";
            icon = Icons::Gift;
            type = EProjectComponent::Collectibles;
        }

        string GetMinVersion() override {
            return "0.5.10";
        }

        void TryLoadingJson(const string &in jFile) override {
            string fname = jFile;
            if (!meta.ProjectFileExists(fname) && meta.ProjectFileExists(PROJ_FILE_COLLECTABLES_LEGACY)) {
                fname = PROJ_FILE_COLLECTABLES_LEGACY;
            }
            ProjectComponent::TryLoadingJson(fname);
            jsonPath = meta.ProjectFilePath(PROJ_FILE_COLLECTIBLES);
            LoadItemsFromJson(ro_data);
        }

        void LoadItemsFromJson(const Json::Value@ data) {
            collectibles.Resize(0);
            if (data is null || (!JsonX::IsObject(data) && !JsonX::IsArray(data))) {
                CreateDefaultJsonObject();
                return;
            }
            if (JsonX::IsArray(data)) {
                LoadItemsFromArray(data);
            } else if (data.HasKey("collectibles")) {
                LoadItemsFromArray(data["collectibles"]);
            } else if (data.HasKey("collectables")) {
                LoadItemsFromArray(data["collectables"]);
            }
        }

        void LoadItemsFromArray(const Json::Value@ arr) {
            if (arr is null || arr.GetType() != Json::Type::Array) return;
            for (uint i = 0; i < arr.Length; i++) {
                auto c = Collectible(arr[i]);
                EnsureSlug(c);
                collectibles.InsertLast(c);
            }
        }

        void SaveToFile() override {
            jsonPath = meta.ProjectFilePath(PROJ_FILE_COLLECTIBLES);
            rw_data = ToJson();
            ProjectComponent::SaveToFile();
        }

        Json::Value@ ToItemsJson() {
            auto arr = Json::Array();
            for (uint i = 0; i < collectibles.Length; i++) {
                arr.Add(collectibles[i].ToJson());
            }
            return arr;
        }

        Json::Value@ ToJson() {
            auto j = Json::Object();
            j["collectibles"] = ToItemsJson();
            return j;
        }

        void DrawComponentInner(ProjectTab@ pTab) override {
            DrawEditorUI(pTab);
        }

        void EnsureSlug(Collectible@ c) {
            if (c.slug.Length == 0) {
                c.slug = UniqueSlug("Collectible");
            }
        }

        void AddCollectible(Collectible@ c) {
            EnsureSlug(c);
            collectibles.InsertLast(c);
            OnDirty();
        }

        string UniqueSlug(const string &in prefix) {
            for (uint n = 1; n < 10000; n++) {
                string candidate = prefix + "-" + n;
                bool taken = false;
                for (uint i = 0; i < collectibles.Length; i++) {
                    if (collectibles[i].slug == candidate) {
                        taken = true;
                        break;
                    }
                }
                if (!taken) return candidate;
            }
            return prefix + "-x";
        }

        void CollectIssues(SpecIssue@[]@ issues) {
            dictionary seenSlugs;
            for (uint i = 0; i < collectibles.Length; i++) {
                collectibles[i].CollectIssues(issues);
                string s = collectibles[i].slug;
                if (s.Length == 0) continue;
                if (seenSlugs.Exists(s)) {
                    collectibles[i].AddIssue(issues, "duplicate slug");
                } else {
                    seenSlugs.Set(s, true);
                }
            }
            for (uint i = 0; i < collectibles.Length; i++) {
                auto a = collectibles[i];
                if (!a.item.bound || a.item.idName.Length == 0) continue;
                for (uint k = i + 1; k < collectibles.Length; k++) {
                    auto b = collectibles[k];
                    if (!b.item.bound || b.item.idName.Length == 0) continue;
                    if (a.item.idName != b.item.idName) continue;
                    if (SameItemPose(a.item.pos, a.item.pyr, b.item.pos, b.item.pyr)) {
                        b.AddIssue(issues, "shared item bind");
                    }
                }
            }
        }

        bool HasAnyIssues() {
            SpecIssue@[] issues;
            CollectIssues(issues);
            return issues.Length > 0;
        }

        void CreateDefaultJsonObject() override {
            rw_data = Json::Object();
            rw_data["collectibles"] = Json::Array();
            collectibles.Resize(0);
        }

        void DrawEditorUI(ProjectTab@ pTab) {
            if (editingIx != -1) {
                DrawEditingUI(pTab);
            } else {
                DrawListUI();
            }
        }

        void DrawEditingUI(ProjectTab@ pTab) {
            OnDirty();
            UI::PushID(tostring(editingIx));
            auto c = collectibles[editingIx];
            UI::Text("Editing Collectible: " + c.name);
            c.name = UI::InputText("Name", c.name);
            if (UI::Button("Done")) {
                editingIx = -1;
            }
            UI::Separator();
            if (editingIx >= 0) {
                c.DrawEditor(pTab);
            }
            UI::PopID();
        }

        void DrawListUI() {
            if (UI::Button(Icons::Plus + " Add Collectible")) {
                auto c = Collectible("New Collectible");
                AddCollectible(c);
                editingIx = int(collectibles.Length) - 1;
            }
            UI::Separator();

            SpecIssue@[] allIssues;
            CollectIssues(allIssues);

            for (uint i = 0; i < collectibles.Length; i++) {
                UI::PushID(tostring(i));
                UI::Text("Collectible " + (i + 1) + ": " + collectibles[i].name);
                UI::AlignTextToFramePadding();
                UI::Text("slug: " + collectibles[i].slug);
                if (ItemHasIssues(collectibles[i].slug, allIssues) || collectibles[i].HasIssues()) {
                    UI::SameLine();
                    UI::Text("\\$f80" + Icons::ExclamationTriangle + " needs attention");
                }
                UI::SameLine();
                if (UI::Button("Edit##" + i)) {
                    editingIx = int(i);
                    OnDirty();
                }
                UI::SameLine();
                if (UI::Button("Remove##" + i)) {
                    collectibles.RemoveAt(i);
                    i--;
                    OnDirty();
                }
                UI::Separator();
                UI::PopID();
            }
        }

        bool ItemHasIssues(const string &in slug, SpecIssue@[]@ issues) {
            for (uint i = 0; i < issues.Length; i++) {
                if (issues[i].slug == slug) return true;
            }
            return false;
        }
    }
}
