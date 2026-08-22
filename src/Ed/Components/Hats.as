namespace CM_Editor {
    // MARK: Hats

    class HatUnlock {
        bool finishThisMap = false;
        array<string> recordUids;

        HatUnlock() {}

        HatUnlock(const Json::Value@ j) {
            LoadFromJson(j);
        }

        void LoadFromJson(const Json::Value@ j) {
            finishThisMap = false;
            recordUids.Resize(0);
            if (j is null || j.GetType() != Json::Type::Object) return;
            finishThisMap = j.Get("finishThisMap", false);
            auto uids = j.Get("recordUids", Json::Value());
            if (uids.GetType() == Json::Type::Array) {
                for (uint i = 0; i < uids.Length; i++) {
                    if (uids[i].GetType() == Json::Type::String) {
                        string uid = uids[i];
                        if (uid.Length > 0) recordUids.InsertLast(uid);
                    }
                }
            }
        }

        bool IsEmpty() const {
            return !finishThisMap && recordUids.Length == 0;
        }

        Json::Value@ ToJson() const {
            auto j = Json::Object();
            if (finishThisMap) j["finishThisMap"] = true;
            if (recordUids.Length > 0) {
                auto arr = Json::Array();
                for (uint i = 0; i < recordUids.Length; i++) {
                    arr.Add(recordUids[i]);
                }
                j["recordUids"] = arr;
            }
            return j;
        }
    }

    class Hat {
        string slug;
        string name;
        string description;
        string itemIdName;
        string image;
        string audio;
        HatUnlock@ unlock;

        Hat(const string &in _name = "New Hat") {
            name = _name;
            slug = "";
            @unlock = HatUnlock();
        }

        Hat(const Json::Value@ j) {
            name = j.Get("name", "");
            slug = j.Get("slug", "");
            description = j.Get("description", "");
            image = j.Get("image", "");
            audio = j.Get("audio", "");
            itemIdName = "";
            @unlock = HatUnlock();
            if (j.HasKey("item") && j["item"].GetType() == Json::Type::Object) {
                JsonX::SafeGetString(j["item"], "idName", itemIdName);
            }
            if (j.HasKey("unlock") && j["unlock"].GetType() == Json::Type::Object) {
                unlock.LoadFromJson(j["unlock"]);
            }
        }

        Json::Value@ ToJson() const {
            auto j = Json::Object();
            j["slug"] = slug;
            j["name"] = name;
            if (description.Length > 0) j["description"] = description;
            if (itemIdName.Length > 0) {
                auto item = Json::Object();
                item["idName"] = itemIdName;
                j["item"] = item;
            }
            if (image.Length > 0) j["image"] = image;
            if (!unlock.IsEmpty()) j["unlock"] = unlock.ToJson();
            if (audio.Length > 0) j["audio"] = audio;
            return j;
        }

        void AddIssue(SpecIssue@[]@ issues, const string &in message) {
            issues.InsertLast(SpecIssue(slug.Length > 0 ? slug : name, message));
        }

        void CollectIssues(SpecIssue@[]@ issues) {
            if (slug.Length == 0) AddIssue(issues, "slug is empty");
            if (itemIdName.Length == 0) AddIssue(issues, "item idName is empty");
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
            UI::TextWrapped("Identity. After publish, changing this is a new hat.");
            description = UI::InputText("Description (optional)", description);

            UI::Separator();
            UI::Text("Item model");
            UI::TextWrapped("Copies are scanned on load; do not list placements. Bind the model from a picked item.");
            if (itemIdName.Length > 0) {
                UI::Text("idName: " + itemIdName);
            } else {
                DrawIssueLine("No item bound. Pick a hat item in the map, then bind it.");
            }
            if (UI::Button(Icons::Crosshairs + " Bind picked item")) {
                auto picked = TryReadPickedMapItem();
                if (picked is null) {
                    NotifyWarning("Pick an item in the map editor first (PickedObject).");
                } else {
                    itemIdName = picked.idName;
                    if (!picked.hasKinematic) {
                        NotifyWarning("Picked item has no kinematic constraint; hats will not follow heads.");
                    } else {
                        NotifySuccess("Bound " + picked.idName);
                    }
                }
            }
            itemIdName = UI::InputText("idName", itemIdName);
            AddSimpleTooltip("ItemModel.IdName. All copies of this model in the map are scanned on load.");

            UI::Separator();
            UI::Text("List image / unlock audio (optional map assets)");
            image = pTab.AssetBrowser("Image", image, AssetTy::Image);
            audio = pTab.AssetBrowser("Audio", audio, AssetTy::Audio);
            AddSimpleTooltip("Shared unlock sound is used when audio is empty.");

            UI::Separator();
            UI::Text("Unlock (UIDs are AND)");
            unlock.finishThisMap = UI::Checkbox("Finish this map", unlock.finishThisMap);
            AddSimpleTooltip("Unlock when the player finishes this map (UISequence::Finish, same rising edge as DD2).");
            UI::Text("Record on map UID(s)");
            UI::TextWrapped("\\$888 Official leaderboard time must exist on every listed UID.");
            int remIx = -1;
            for (uint i = 0; i < unlock.recordUids.Length; i++) {
                UI::PushID(int(i));
                unlock.recordUids[i] = UI::InputText("UID##" + i, unlock.recordUids[i]);
                UI::SameLine();
                if (UI::Button(Icons::TrashO + "##uid" + i)) remIx = int(i);
                UI::PopID();
            }
            if (remIx >= 0) unlock.recordUids.RemoveAt(remIx);
            if (UI::Button(Icons::Plus + " Add map UID")) {
                unlock.recordUids.InsertLast("");
            }

            UI::Separator();
            if (slug.Length == 0) DrawIssueLine("Slug is empty.");
            if (itemIdName.Length == 0) DrawIssueLine("item idName is empty.");
        }
    }

    class ProjectHatsComponent : ProjectComponent {
        array<Hat@> hats;
        int editingIx = -1;

        ProjectHatsComponent(const string &in jsonPath, ProjectMeta@ meta) {
            super(jsonPath, meta);
            name = "Hats";
            icon = Icons::Magic;
            type = EProjectComponent::Hats;
        }

        string GetMinVersion() override {
            return "0.5.10";
        }

        void TryLoadingJson(const string &in jFile) override {
            ProjectComponent::TryLoadingJson(jFile);
            LoadItemsFromJson(ro_data);
        }

        void LoadItemsFromJson(const Json::Value@ data) {
            hats.Resize(0);
            if (data is null || (!JsonX::IsObject(data) && !JsonX::IsArray(data))) {
                CreateDefaultJsonObject();
                return;
            }
            if (JsonX::IsArray(data)) {
                LoadItemsFromArray(data);
            } else if (data.HasKey("hats")) {
                LoadItemsFromArray(data["hats"]);
            }
        }

        void LoadItemsFromArray(const Json::Value@ arr) {
            if (arr is null || arr.GetType() != Json::Type::Array) return;
            for (uint i = 0; i < arr.Length; i++) {
                auto h = Hat(arr[i]);
                EnsureSlug(h);
                hats.InsertLast(h);
            }
        }

        void SaveToFile() override {
            rw_data = ToJson();
            ProjectComponent::SaveToFile();
        }

        Json::Value@ ToItemsJson() {
            auto arr = Json::Array();
            for (uint i = 0; i < hats.Length; i++) {
                arr.Add(hats[i].ToJson());
            }
            return arr;
        }

        Json::Value@ ToJson() {
            auto j = Json::Object();
            j["hats"] = ToItemsJson();
            return j;
        }

        void DrawComponentInner(ProjectTab@ pTab) override {
            DrawEditorUI(pTab);
        }

        void EnsureSlug(Hat@ h) {
            if (h.slug.Length == 0) {
                h.slug = UniqueSlug("Hat");
            }
        }

        void AddHat(Hat@ h) {
            EnsureSlug(h);
            hats.InsertLast(h);
            OnDirty();
        }

        string UniqueSlug(const string &in prefix) {
            for (uint n = 1; n < 10000; n++) {
                string candidate = prefix + "-" + n;
                bool taken = false;
                for (uint i = 0; i < hats.Length; i++) {
                    if (hats[i].slug == candidate) {
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
            for (uint i = 0; i < hats.Length; i++) {
                hats[i].CollectIssues(issues);
                string s = hats[i].slug;
                if (s.Length == 0) continue;
                if (seenSlugs.Exists(s)) {
                    hats[i].AddIssue(issues, "duplicate slug");
                } else {
                    seenSlugs.Set(s, true);
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
            rw_data["hats"] = Json::Array();
            hats.Resize(0);
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
            auto h = hats[editingIx];
            UI::Text("Editing Hat: " + h.name);
            h.name = UI::InputText("Name", h.name);
            if (UI::Button("Done")) {
                editingIx = -1;
            }
            UI::Separator();
            if (editingIx >= 0) {
                h.DrawEditor(pTab);
            }
            UI::PopID();
        }

        void DrawListUI() {
            if (UI::Button(Icons::Plus + " Add Hat")) {
                auto h = Hat("New Hat");
                AddHat(h);
                editingIx = int(hats.Length) - 1;
            }
            UI::Separator();

            SpecIssue@[] allIssues;
            CollectIssues(allIssues);

            for (uint i = 0; i < hats.Length; i++) {
                UI::PushID(tostring(i));
                UI::Text("Hat " + (i + 1) + ": " + hats[i].name);
                UI::AlignTextToFramePadding();
                UI::Text("slug: " + hats[i].slug + "  item: " + hats[i].itemIdName);
                if (HatRowHasIssues(hats[i].slug, allIssues) || hats[i].HasIssues()) {
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
                    hats.RemoveAt(i);
                    i--;
                    OnDirty();
                }
                UI::Separator();
                UI::PopID();
            }
        }

        bool HatRowHasIssues(const string &in slug, SpecIssue@[]@ issues) {
            for (uint i = 0; i < issues.Length; i++) {
                if (issues[i].slug == slug) return true;
            }
            return false;
        }
    }
}
