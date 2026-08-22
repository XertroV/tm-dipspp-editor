namespace CM_Editor {
    // MARK: Minigames Component

    enum MinigameKind {
        Unknown,
        Sprint,
        Survival,
        Darts,
        HighJump,
        LongJump,
        MaxAvgSpeed
    }

    string KindSlugPrefix(MinigameKind k) {
        return tostring(k);
    }

    string KindLabel(MinigameKind k) {
        if (k == MinigameKind::HighJump) return "High Jump";
        if (k == MinigameKind::LongJump) return "Long Jump";
        if (k == MinigameKind::MaxAvgSpeed) return "Max Avg Speed";
        return tostring(k);
    }

    bool KindHasEnd(MinigameKind k) {
        return k == MinigameKind::Sprint || k == MinigameKind::MaxAvgSpeed;
    }

    bool KindHasCheckpoints(MinigameKind k) {
        return k == MinigameKind::Sprint;
    }

    bool KindHasDarts(MinigameKind k) {
        return k == MinigameKind::Darts;
    }

    Json::Value@ ObjectField(const Json::Value@ j, const string &in key) {
        if (j is null || j.GetType() != Json::Type::Object || !j.HasKey(key)) return Json::Object();
        auto v = j.Get(key, Json::Value());
        if (v.GetType() != Json::Type::Object) return Json::Object();
        return v;
    }

    Json::Value@ PointToJson(const vec3 &in pos) {
        auto j = Json::Object();
        j["pos"] = Vec3ToJson(pos);
        return j;
    }

    // Parse published string kinds and old editor names. Sets puzzle/airborne for legacy presets.
    void ApplyKindString(const string &in str, MinigameKind &out kind, bool &out puzzle, bool &out airborne) {
        puzzle = false;
        airborne = false;
        if (str == "Sprint") { kind = MinigameKind::Sprint; return; }
        if (str == "Survival") { kind = MinigameKind::Survival; return; }
        if (str == "Darts") { kind = MinigameKind::Darts; return; }
        if (str == "HighJump") { kind = MinigameKind::HighJump; return; }
        if (str == "LongJump") { kind = MinigameKind::LongJump; return; }
        if (str == "MaxAvgSpeed") { kind = MinigameKind::MaxAvgSpeed; return; }
        if (str == "TimeTrial") { kind = MinigameKind::Sprint; return; }
        if (str == "JumpHigh") { kind = MinigameKind::HighJump; return; }
        if (str == "JumpAccuracy") { kind = MinigameKind::Darts; return; }
        if (str == "TimeOffGround") { kind = MinigameKind::Survival; airborne = true; return; }
        if (str == "PuzzleLocations") { kind = MinigameKind::Sprint; puzzle = true; return; }
        kind = MinigameKind::Unknown;
    }

    // Old MinigameType ints: TimeTrial/1, JumpHigh/2, JumpAccuracy/3, MaxAvgSpeed/4, TimeOffGround/5, PuzzleLocations/6.
    void ApplyKindInt(int t, MinigameKind &out kind, bool &out puzzle, bool &out airborne) {
        puzzle = false;
        airborne = false;
        if (t == 1) { kind = MinigameKind::Sprint; return; }
        if (t == 2) { kind = MinigameKind::HighJump; return; }
        if (t == 3) { kind = MinigameKind::Darts; return; }
        if (t == 4) { kind = MinigameKind::MaxAvgSpeed; return; }
        if (t == 5) { kind = MinigameKind::Survival; airborne = true; return; }
        if (t == 6) { kind = MinigameKind::Sprint; puzzle = true; return; }
        kind = MinigameKind::Unknown;
    }

    void ParseMinigameKind(const Json::Value@ j, MinigameKind &out kind, bool &out puzzle, bool &out airborne) {
        kind = MinigameKind::Unknown;
        puzzle = false;
        airborne = false;
        if (j is null || j.GetType() != Json::Type::Object) return;
        if (j.HasKey("kind") && j["kind"].GetType() == Json::Type::String) {
            ApplyKindString(string(j["kind"]), kind, puzzle, airborne);
        } else if (j.HasKey("type")) {
            ApplyKindInt(int(j["type"]), kind, puzzle, airborne);
        }
        if (j.HasKey("puzzle")) puzzle = bool(j.Get("puzzle", false));
        if (j.HasKey("airborne")) airborne = bool(j.Get("airborne", false));
    }

    class MinigameCheckpoint {
        EditableTrigger@ trigger;
        string text;
        string image;
        string audio;

        MinigameCheckpoint() {
            @trigger = EditableTrigger(DEFAULT_VL_POS, DEFAULT_MT_SIZE, "Checkpoint", "Checkpoint");
        }

        MinigameCheckpoint(const Json::Value@ json) {
            @trigger = EditableTrigger(json, DEFAULT_VL_POS, DEFAULT_MT_SIZE, "Checkpoint", "Checkpoint");
            text = json.Get("text", "");
            image = json.Get("image", "");
            audio = json.Get("audio", "");
            if (text.Length == 0) text = json.Get("nextHint", "");
            if (image.Length == 0) image = json.Get("hintImage", "");
        }

        Json::Value@ ToJson(bool includeClues) const {
            auto j = ZoneToJson(trigger);
            if (trigger.name.Length > 0) j["name"] = trigger.name;
            if (includeClues) {
                if (text.Length > 0) j["text"] = text;
                if (image.Length > 0) j["image"] = image;
                if (audio.Length > 0) j["audio"] = audio;
            }
            return j;
        }

        void DrawEditorUI(ProjectTab@ pTab, bool puzzle) {
            trigger.name = UI::InputText("Name (optional)", trigger.name);
            UI::Text("Trigger");
            trigger.DrawEditorUI();
            if (puzzle && pTab !is null) {
                text = UI::InputText("Clue text", text);
                image = pTab.AssetBrowser("Clue image", image, AssetTy::Image);
                audio = pTab.AssetBrowser("Clue audio", audio, AssetTy::Audio);
                UI::TextWrapped("Any mix of text / image / audio. Empty = silent checkpoint.");
            }
        }
    }

    const vec3 DEFAULT_MG_BOUNDS_SIZE = vec3(200, 200, 200);
    const vec3 DEFAULT_PLANE_NORMAL = vec3(0, 0, 1);

    bool IsDefaultPlacement(EditableTrigger@ t) {
        if (t is null) return true;
        return (t.posBottomCenter - DEFAULT_VL_POS).LengthSquared() < 0.01;
    }

    bool TriggerFullyInside(EditableTrigger@ outer, EditableTrigger@ inner) {
        if (outer is null || inner is null) return false;
        vec3 oMin = outer.posMin;
        vec3 iMin = inner.posMin;
        vec3 oMax = oMin + outer.size;
        vec3 iMax = iMin + inner.size;
        return iMin.x >= oMin.x && iMin.y >= oMin.y && iMin.z >= oMin.z
            && iMax.x <= oMax.x && iMax.y <= oMax.y && iMax.z <= oMax.z;
    }

    class MinigameIssue {
        string slug;
        string message;

        MinigameIssue(const string &in slug_, const string &in message_) {
            slug = slug_;
            message = message_;
        }
    }

    class Minigame {
        string name;
        string slug;
        MinigameKind kind;
        bool puzzle = false;
        bool airborne = false;
        bool useCustomBounds = false;
        EditableTrigger@ start;
        EditableTrigger@ end;
        EditableTrigger@ bounds;
        array<MinigameCheckpoint@> checkpoints;
        EditableTrigger@ bullseye;
        EditableTrigger@ plane;
        vec3 planeNormal = DEFAULT_PLANE_NORMAL;

        Minigame(const string &in _name, MinigameKind _kind) {
            name = _name;
            kind = _kind;
            slug = "";
            @start = EditableTrigger(DEFAULT_VL_POS, DEFAULT_MT_SIZE, "Start", "Start");
            @end = EditableTrigger(DEFAULT_VL_POS, DEFAULT_MT_SIZE, "End", "End");
            @bounds = EditableTrigger(DEFAULT_VL_POS, DEFAULT_MG_BOUNDS_SIZE, "Bounds", _name);
            @bullseye = EditableTrigger(DEFAULT_VL_POS, DEFAULT_MT_SIZE, "Bullseye", "Bullseye");
            @plane = EditableTrigger(DEFAULT_VL_POS, DEFAULT_MT_SIZE, "Plane", "Plane");
            planeNormal = DEFAULT_PLANE_NORMAL;
        }

        Minigame(const Json::Value@ json) {
            name = json.Get("name", "");
            slug = json.Get("slug", "");
            ParseMinigameKind(json, kind, puzzle, airborne);
            @start = EditableTrigger(DEFAULT_VL_POS, DEFAULT_MT_SIZE, "Start", "Start");
            @end = EditableTrigger(DEFAULT_VL_POS, DEFAULT_MT_SIZE, "End", "End");
            @bounds = EditableTrigger(DEFAULT_VL_POS, DEFAULT_MG_BOUNDS_SIZE, "Bounds", name);
            @bullseye = EditableTrigger(DEFAULT_VL_POS, DEFAULT_MT_SIZE, "Bullseye", "Bullseye");
            @plane = EditableTrigger(DEFAULT_VL_POS, DEFAULT_MT_SIZE, "Plane", "Plane");
            planeNormal = DEFAULT_PLANE_NORMAL;
            useCustomBounds = false;
            LoadSharedFromJson(json);
            LoadParamsFromJson(ObjectField(json, "params"));
        }

        void LoadSharedFromJson(const Json::Value@ json) {
            Json::Value@ startJ;
            if (json.HasKey("start") && json["start"].GetType() == Json::Type::Object) {
                @startJ = json["start"];
            } else {
                auto params = ObjectField(json, "params");
                if (params.HasKey("startTrigger") && params["startTrigger"].GetType() == Json::Type::Object) {
                    @startJ = params["startTrigger"];
                }
            }
            if (startJ !is null) {
                @start = EditableTrigger(startJ, DEFAULT_VL_POS, DEFAULT_MT_SIZE, "Start", "Start");
            }
            if (json.HasKey("bounds") && json["bounds"].GetType() == Json::Type::Object) {
                @bounds = EditableTrigger(json["bounds"], DEFAULT_VL_POS, DEFAULT_MG_BOUNDS_SIZE, "Bounds", name);
                useCustomBounds = !IsDefaultPlacement(bounds);
            }
        }

        void LoadParamsFromJson(const Json::Value@ params) {
            Json::Value@ endJ;
            if (params.HasKey("end") && params["end"].GetType() == Json::Type::Object) {
                @endJ = params["end"];
            } else if (params.HasKey("endTrigger") && params["endTrigger"].GetType() == Json::Type::Object) {
                @endJ = params["endTrigger"];
            }
            if (endJ !is null) {
                @end = EditableTrigger(endJ, DEFAULT_VL_POS, DEFAULT_MT_SIZE, "End", "End");
            }
            checkpoints.Resize(0);
            if (params.HasKey("checkpoints") && params["checkpoints"].GetType() == Json::Type::Array) {
                auto cps = params["checkpoints"];
                for (uint i = 0; i < cps.Length; i++) {
                    checkpoints.InsertLast(MinigameCheckpoint(cps[i]));
                }
            } else if (params.HasKey("steps") && params["steps"].GetType() == Json::Type::Array) {
                auto steps = params["steps"];
                for (uint i = 0; i < steps.Length; i++) {
                    auto step = steps[i];
                    MinigameCheckpoint@ cp;
                    if (step.HasKey("trigger") && step["trigger"].GetType() == Json::Type::Object) {
                        @cp = MinigameCheckpoint(step["trigger"]);
                    } else {
                        @cp = MinigameCheckpoint();
                    }
                    if (cp.text.Length == 0) cp.text = step.Get("nextHint", "");
                    if (cp.image.Length == 0) cp.image = step.Get("hintImage", "");
                    checkpoints.InsertLast(cp);
                }
            }
            if (params.HasKey("bullseye") && params["bullseye"].GetType() == Json::Type::Object && params["bullseye"].HasKey("pos")) {
                bullseye.posBottomCenter = JsonToVec3(params["bullseye"]["pos"], DEFAULT_VL_POS);
                bullseye.hasBeenSet = true;
            }
            if (params.HasKey("plane") && params["plane"].GetType() == Json::Type::Object) {
                auto pl = params["plane"];
                if (pl.HasKey("pos")) {
                    plane.posBottomCenter = JsonToVec3(pl["pos"], DEFAULT_VL_POS);
                    plane.hasBeenSet = true;
                }
                if (pl.HasKey("normal")) {
                    planeNormal = JsonToVec3(pl["normal"], DEFAULT_PLANE_NORMAL);
                }
            }
        }

        bool HasCustomBounds() const {
            return useCustomBounds && !IsDefaultPlacement(bounds);
        }

        vec3 DefaultBoundsCenter() const {
            vec3 sum = vec3();
            uint n = 0;
            if (!IsDefaultPlacement(start)) {
                sum += start.posBottomCenter;
                n++;
            }
            if (KindHasEnd(kind) && !IsDefaultPlacement(end)) {
                sum += end.posBottomCenter;
                n++;
            }
            if (n == 0) return DEFAULT_VL_POS;
            return sum / float(n);
        }

        EditableTrigger@ EffectiveBoundsBox() const {
            if (HasCustomBounds()) return bounds;
            return EditableTrigger(DefaultBoundsCenter(), DEFAULT_MG_BOUNDS_SIZE, "Bounds", name);
        }

        Json::Value@ ToJson() const {
            auto j = Json::Object();
            j["name"] = name;
            j["slug"] = slug;
            j["kind"] = tostring(kind);
            if (kind == MinigameKind::Sprint && puzzle) j["puzzle"] = true;
            if (kind == MinigameKind::Survival && airborne) j["airborne"] = true;
            j["start"] = ZoneToJson(start);
            if (HasCustomBounds()) j["bounds"] = ZoneToJson(bounds);
            j["params"] = ParamsToJson();
            return j;
        }

        Json::Value@ ParamsToJson() const {
            auto p = Json::Object();
            if (KindHasEnd(kind)) {
                p["end"] = ZoneToJson(end);
            }
            if (KindHasCheckpoints(kind)) {
                auto arr = Json::Array();
                for (uint i = 0; i < checkpoints.Length; i++) {
                    arr.Add(checkpoints[i].ToJson(puzzle));
                }
                p["checkpoints"] = arr;
            }
            if (KindHasDarts(kind)) {
                p["bullseye"] = PointToJson(bullseye.posBottomCenter);
                auto pl = PointToJson(plane.posBottomCenter);
                pl["normal"] = Vec3ToJson(planeNormal);
                p["plane"] = pl;
            }
            return p;
        }

        void AddIssue(MinigameIssue@[]@ issues, const string &in message) {
            issues.InsertLast(MinigameIssue(slug.Length > 0 ? slug : name, message));
        }

        void CollectTriggerIssues(MinigameIssue@[]@ issues, EditableTrigger@ t, const string &in label, EditableTrigger@ outer) {
            if (IsDefaultPlacement(t)) {
                AddIssue(issues, label + " not set");
            } else if (!TriggerFullyInside(outer, t)) {
                AddIssue(issues, label + " is outside bounds");
            }
        }

        void CollectIssues(MinigameIssue@[]@ issues) {
            if (slug.Length == 0) AddIssue(issues, "slug is empty");
            if (kind == MinigameKind::Unknown) AddIssue(issues, "kind is unknown");
            auto outer = EffectiveBoundsBox();
            CollectTriggerIssues(issues, start, "start", outer);
            if (KindHasEnd(kind)) {
                CollectTriggerIssues(issues, end, "end", outer);
            }
            if (KindHasCheckpoints(kind)) {
                for (uint i = 0; i < checkpoints.Length; i++) {
                    CollectTriggerIssues(issues, checkpoints[i].trigger, "checkpoint " + (i + 1), outer);
                }
            }
            if (KindHasDarts(kind)) {
                if (IsDefaultPlacement(bullseye)) AddIssue(issues, "bullseye not set");
                if (IsDefaultPlacement(plane)) AddIssue(issues, "plane not set");
                if (planeNormal.LengthSquared() < 1e-8) AddIssue(issues, "plane normal is zero");
            }
        }

        bool HasIssues() {
            MinigameIssue@[] issues;
            CollectIssues(issues);
            return issues.Length > 0;
        }

        void DrawIssueLine(const string &in message) {
            UI::PushStyleColor(UI::Col::Text, cOrange);
            UI::TextWrapped(Icons::ExclamationTriangle + " " + message);
            UI::PopStyleColor();
        }

        string FlagsLabel() const {
            if (kind == MinigameKind::Sprint && puzzle) return " (puzzle)";
            if (kind == MinigameKind::Survival && airborne) return " (airborne)";
            return "";
        }

        void DrawSharedEditor() {
            slug = UI::InputText("Slug", slug);
            UI::TextWrapped("Identity. After publish, changing this is a new minigame. Default is " + KindSlugPrefix(kind) + "-1.");
            UI::Text("Kind: " + KindLabel(kind) + FlagsLabel());
            if (kind == MinigameKind::Sprint) {
                puzzle = UI::Checkbox("Puzzle (clues on checkpoints)", puzzle);
                AddSimpleTooltip("Sprint preset. Checkpoints may carry text, image, and/or audio. Journal is this attempt only.");
            }
            if (kind == MinigameKind::Survival) {
                airborne = UI::Checkbox("Airborne (Time Off Ground)", airborne);
                AddSimpleTooltip("Hold also requires all wheels off. One wheel down ends the streak.");
            }
            if (slug.Length == 0) DrawIssueLine("Slug is empty.");

            UI::Separator();
            UI::Text("Start zone");
            UI::TextWrapped("Activates the minigame. Typical size is about 32×16×32.");
            if (IsDefaultPlacement(start)) DrawIssueLine("Start is still at the default. Place it on the course.");
            else if (!TriggerFullyInside(EffectiveBoundsBox(), start)) {
                if (kind == MinigameKind::Survival) DrawIssueLine("Start is outside minigame bounds. Survival start must sit inside bounds.");
                else DrawIssueLine("Start is outside minigame bounds. Attempts will cancel immediately.");
            }
            start.DrawEditorUI();
            start.DrawNvgBox(TriggerZoneColor(start));

            UI::Separator();
            UI::Text("Minigame bounds");
            UI::TextWrapped("Leaving bounds cancels the attempt. Unchecked = omit from spec (default 200 m square centred on the zones).");
            bool prevCustom = useCustomBounds;
            useCustomBounds = UI::Checkbox("Custom bounds", useCustomBounds);
            if (useCustomBounds && !prevCustom && !IsDefaultPlacement(start)) {
                bounds.posBottomCenter = DefaultBoundsCenter();
                bounds.size = DEFAULT_MG_BOUNDS_SIZE;
                bounds.hasBeenSet = true;
            }
            if (!useCustomBounds && prevCustom) {
                bounds.posBottomCenter = DEFAULT_VL_POS;
                bounds.size = DEFAULT_MG_BOUNDS_SIZE;
                bounds.hasBeenSet = false;
            }
            if (useCustomBounds) {
                bounds.DrawEditorUI();
                bounds.DrawNvgBox(IsDefaultPlacement(bounds) ? cOrange : cCyan);
            } else if (!IsDefaultPlacement(start)) {
                auto preview = EffectiveBoundsBox();
                preview.name = "default bounds";
                preview.DrawNvgBox(cGray50);
            }
        }

        void DrawEditor(ProjectTab@ pTab) {
            if (KindHasEnd(kind)) {
                UI::Text("End zone");
                if (IsDefaultPlacement(end)) DrawIssueLine("End is still at the default. Place it on the course.");
                else if (!TriggerFullyInside(EffectiveBoundsBox(), end)) DrawIssueLine("End is outside minigame bounds. The finish will be unreachable.");
                end.DrawEditorUI();
            }
            if (kind == MinigameKind::Sprint) {
                UI::TextWrapped("If any checkpoints are authored, all are required this attempt, any order. Enter is enough.");
                UI::Text("Checkpoints: " + checkpoints.Length);
                auto outer = EffectiveBoundsBox();
                for (uint i = 0; i < checkpoints.Length; i++) {
                    UI::PushID(tostring(i));
                    UI::Separator();
                    UI::Text("Checkpoint " + (i + 1));
                    if (IsDefaultPlacement(checkpoints[i].trigger)) DrawIssueLine("Checkpoint " + (i + 1) + " is still at the default.");
                    else if (!TriggerFullyInside(outer, checkpoints[i].trigger)) DrawIssueLine("Checkpoint " + (i + 1) + " is outside minigame bounds.");
                    checkpoints[i].DrawEditorUI(pTab, puzzle);
                    if (UI::Button(Icons::Trash + " Remove##cp" + i)) {
                        checkpoints.RemoveAt(i);
                        i--;
                    }
                    UI::PopID();
                }
                if (UI::Button(Icons::Plus + " Add Checkpoint")) {
                    auto cp = MinigameCheckpoint();
                    cp.trigger.name = "Checkpoint " + (checkpoints.Length + 1);
                    checkpoints.InsertLast(cp);
                }
            }
            if (kind == MinigameKind::MaxAvgSpeed) {
                UI::TextWrapped("Average is path length over elapsed time from leave-start to end-enter. Idle counts.");
            }
            if (kind == MinigameKind::Survival) {
                UI::TextWrapped("Hold is minigame bounds after leaving start. One streak per attempt. Leave hold after a non-zero hold to finish.");
            }
            if (kind == MinigameKind::HighJump) {
                UI::TextWrapped("Score is peak Y minus the start trigger's low point. Arms when leaving start airborne.");
            }
            if (kind == MinigameKind::LongJump) {
                UI::TextWrapped("Score is XZ from first intersect of start to landing. Arms when leaving start airborne.");
            }
            if (KindHasDarts(kind)) {
                UI::TextWrapped("Bullseye is a point. Soft-end is a plane (point + normal). Score is in-plane distance. Arms when leaving start airborne.");
                UI::Separator();
                UI::Text("Bullseye");
                if (IsDefaultPlacement(bullseye)) DrawIssueLine("Bullseye is still at the default.");
                bullseye.DrawEditorUI();
                UI::Text("Plane");
                if (IsDefaultPlacement(plane)) DrawIssueLine("Plane is still at the default.");
                plane.DrawEditorUI();
                planeNormal = UI::InputFloat3("Plane normal", planeNormal);
                if (planeNormal.LengthSquared() < 1e-8) DrawIssueLine("Plane normal is zero.");
            }
            if (kind == MinigameKind::HighJump || kind == MinigameKind::LongJump || kind == MinigameKind::Survival) {
                UI::TextWrapped("\\$888 This kind has no extra params.");
            }
        }

        void DrawNvgBoxes() {
            if (KindHasEnd(kind)) {
                end.DrawNvgBox(TriggerZoneColor(end));
            }
            if (KindHasCheckpoints(kind)) {
                for (uint i = 0; i < checkpoints.Length; i++) {
                    checkpoints[i].trigger.DrawNvgBox(TriggerZoneColor(checkpoints[i].trigger));
                }
            }
            if (KindHasDarts(kind)) {
                bullseye.DrawNvgBox(IsDefaultPlacement(bullseye) ? cRed : cOrange);
                plane.DrawNvgBox(IsDefaultPlacement(plane) ? cRed : cOrange);
            }
        }

        vec4 TriggerZoneColor(EditableTrigger@ t) const {
            if (IsDefaultPlacement(t) || !TriggerFullyInside(EffectiveBoundsBox(), t)) return cRed;
            return cOrange;
        }
    }

    class ProjectMinigamesComponent : ProjectComponent {
        array<Minigame@> minigames;
        int editingIx = -1;

        ProjectMinigamesComponent(const string &in jsonPath, ProjectMeta@ meta) {
            super(jsonPath, meta);
            name = "Minigames";
            icon = Icons::Gamepad;
            type = EProjectComponent::Minigames;
        }

        string GetMinVersion() override {
            return "0.5.10";
        }

        void TryLoadingJson(const string &in jFile) override {
            ProjectComponent::TryLoadingJson(jFile);
            LoadGamesFromJson(ro_data);
        }

        void LoadGamesFromJson(const Json::Value@ data) {
            minigames.Resize(0);
            if (data is null || data.GetType() != Json::Type::Object) return;
            auto arr = data.Get("games", Json::Value());
            if (arr.GetType() != Json::Type::Array) return;
            for (uint i = 0; i < arr.Length; i++) {
                auto gameJson = arr[i];
                if (gameJson.GetType() != Json::Type::Object) continue;
                auto minigame = Minigame(gameJson);
                if (minigame.kind == MinigameKind::Unknown) {
                    warn("Unknown minigame kind; skipped");
                    continue;
                }
                EnsureSlug(minigame);
                minigames.InsertLast(minigame);
            }
        }

        void SaveToFile() override {
            rw_data = ToJson();
            ProjectComponent::SaveToFile();
        }

        Json::Value@ ToJson() {
            Json::Value@ arr = Json::Array();
            for (uint i = 0; i < minigames.Length; i++) {
                arr.Add(minigames[i].ToJson());
            }
            auto j = Json::Object();
            j["games"] = arr;
            return j;
        }

        void DrawComponentInner(ProjectTab@ pTab) override {
            DrawEditorUI(pTab);
        }

        void EnsureSlug(Minigame@ minigame) {
            if (minigame.slug.Length == 0) {
                minigame.slug = UniqueSlug(KindSlugPrefix(minigame.kind));
            }
        }

        void AddMinigame(Minigame@ minigame) {
            this.EnsureSlug(minigame);
            minigames.InsertLast(minigame);
            this.OnDirty();
        }

        void CollectIssues(MinigameIssue@[]@ issues) {
            dictionary seenSlugs;
            for (uint i = 0; i < minigames.Length; i++) {
                minigames[i].CollectIssues(issues);
                string s = minigames[i].slug;
                if (s.Length == 0) continue;
                if (seenSlugs.Exists(s)) {
                    minigames[i].AddIssue(issues, "duplicate slug");
                } else {
                    seenSlugs.Set(s, true);
                }
            }
        }

        bool HasAnyIssues() {
            MinigameIssue@[] issues;
            CollectIssues(issues);
            return issues.Length > 0;
        }

        string UniqueSlug(const string &in prefix) {
            for (uint n = 1; n < 10000; n++) {
                string candidate = prefix + "-" + n;
                bool taken = false;
                for (uint i = 0; i < minigames.Length; i++) {
                    if (minigames[i].slug == candidate) {
                        taken = true;
                        break;
                    }
                }
                if (!taken) return candidate;
            }
            return prefix + "-x";
        }

        void CreateDefaultJsonObject() override {
            rw_data = Json::Object();
            rw_data["games"] = Json::Array();
            minigames.Resize(0);
        }

        void DrawEditorUI(ProjectTab@ pTab) {
            if (editingIx != -1) {
                DrawEditingMinigameUI(pTab);
            } else {
                DrawMinigameListUI();
            }
        }

        void DrawEditingMinigameUI(ProjectTab@ pTab) {
            this.OnDirty();
            UI::PushID(tostring(editingIx));
            auto minigame = minigames[editingIx];
            UI::Text("Editing Minigame: " + minigame.name);
            minigame.name = UI::InputText("Name", minigame.name);
            minigame.DrawSharedEditor();
            if (UI::Button("Done")) {
                editingIx = -1;
            }
            UI::Separator();
            if (editingIx >= 0) {
                minigame.DrawEditor(pTab);
                minigame.DrawNvgBoxes();
            }
            UI::PopID();
        }

        void DrawMinigameListUI() {
            DrawAddMinigameButton();
            UI::Separator();

            MinigameIssue@[] allIssues;
            CollectIssues(allIssues);

            for (uint i = 0; i < minigames.Length; i++) {
                UI::PushID(tostring(i));
                UI::Text("Minigame " + (i + 1) + ": " + minigames[i].name);
                auto p1 = UI::GetCursorPos();
                UI::AlignTextToFramePadding();
                UI::Text("Kind: " + KindLabel(minigames[i].kind) + minigames[i].FlagsLabel() + "  slug: " + minigames[i].slug);
                if (RowHasIssues(minigames[i].slug, minigames[i].name, allIssues) || minigames[i].HasIssues()) {
                    UI::SameLine();
                    UI::Text("\\$f80" + Icons::ExclamationTriangle + " needs attention");
                }
                UI::SameLine();
                if (UI::Button("Edit##" + i)) {
                    editingIx = int(i);
                    this.OnDirty();
                }
                UI::SameLine();
                auto p2 = UI::GetCursorPos();
                UI::Dummy(vec2(300 - (p2.x - p1.x), 0));
                UI::SameLine();
                if (UI::Button("Remove##" + i)) {
                    minigames.RemoveAt(i);
                    i--;
                    this.OnDirty();
                }
                UI::Separator();
                UI::PopID();
            }
        }

        bool RowHasIssues(const string &in slug, const string &in name, MinigameIssue@[]@ issues) {
            for (uint i = 0; i < issues.Length; i++) {
                if (issues[i].slug == slug || issues[i].slug == name) return true;
            }
            return false;
        }

        void DrawAddMinigameButton() {
            UI::AlignTextToFramePadding();
            UI::Text(Icons::Plus);
            UI::SameLine();
            if (UI::BeginCombo("Add New Minigame", "Select Type")) {
                if (UI::Selectable("Sprint", false)) {
                    AddMinigame(Minigame("New Sprint", MinigameKind::Sprint));
                }
                if (UI::Selectable("Puzzle (Sprint)", false)) {
                    auto mg = Minigame("New Puzzle", MinigameKind::Sprint);
                    mg.puzzle = true;
                    AddMinigame(mg);
                }
                if (UI::Selectable("Survival", false)) {
                    AddMinigame(Minigame("New Survival", MinigameKind::Survival));
                }
                if (UI::Selectable("Time Off Ground (Survival)", false)) {
                    auto mg = Minigame("New Time Off Ground", MinigameKind::Survival);
                    mg.airborne = true;
                    AddMinigame(mg);
                }
                if (UI::Selectable("Darts", false)) {
                    AddMinigame(Minigame("New Darts", MinigameKind::Darts));
                }
                if (UI::Selectable("High Jump", false)) {
                    AddMinigame(Minigame("New High Jump", MinigameKind::HighJump));
                }
                if (UI::Selectable("Long Jump", false)) {
                    AddMinigame(Minigame("New Long Jump", MinigameKind::LongJump));
                }
                if (UI::Selectable("Max Avg Speed", false)) {
                    AddMinigame(Minigame("New Max Avg Speed", MinigameKind::MaxAvgSpeed));
                }
                UI::EndCombo();
            }
        }
    }
}
