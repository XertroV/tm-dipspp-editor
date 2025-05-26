namespace CM_Editor {
    // MARK: Minigames Component

    enum MinigameType {
        Unknown,
        TimeTrial,
        JumpHigh,
        JumpAccuracy,
        MaxAvgSpeed,
        TimeOffGround,
        PuzzleLocations
    }

    MinigameType StrToMinigameType(const string &in str) {
        if (str == "TimeTrial") return MinigameType::TimeTrial;
        if (str == "JumpHigh") return MinigameType::JumpHigh;
        if (str == "JumpAccuracy") return MinigameType::JumpAccuracy;
        if (str == "MaxAvgSpeed") return MinigameType::MaxAvgSpeed;
        if (str == "TimeOffGround") return MinigameType::TimeOffGround;
        if (str == "PuzzleLocations") return MinigameType::PuzzleLocations;
        throw("Unknown MinigameType: " + str);
        return MinigameType::Unknown;
    }

    class MinigameParams {
        Json::Value@ data;

        MinigameParams() {
            @data = Json::Object();
        }

        MinigameParams(Json::Value@ json) {
            @data = json;
        }

        // Int
        int GetInt(const string &in key) {
            return data.Get(key, 0);
        }
        int GetInt(const string &in key, int defaultValue) {
            return data.Get(key, defaultValue);
        }
        void SetInt(const string &in key, int value) {
            data[key] = value;
        }
        // Bool
        bool GetBool(const string &in key) {
            return data.Get(key, false);
        }
        bool GetBool(const string &in key, bool defaultValue) {
            return data.Get(key, defaultValue);
        }
        void SetBool(const string &in key, bool value) {
            data[key] = value;
        }
        // Float
        float GetFloat(const string &in key) {
            return float(data.Get(key, 0.0f));
        }
        float GetFloat(const string &in key, float defaultValue) {
            return float(data.Get(key, defaultValue));
        }
        void SetFloat(const string &in key, float value) {
            data[key] = value;
        }
        // String
        string GetString(const string &in key) {
            return data.Get(key, "");
        }
        string GetString(const string &in key, const string &in defaultValue) {
            return data.Get(key, defaultValue);
        }
        void SetString(const string &in key, const string &in value) {
            data[key] = value;
        }

        Json::Value@ ToJson() {
            return data;
        }
    }

    // --- TimeTrialMinigameParams ---
    class TimeTrialMinigameParams : MinigameParams {
        EditableTrigger@ startTrigger;
        EditableTrigger@ endTrigger;
        array<EditableTrigger@> checkpoints;
        bool anyOrder;

        TimeTrialMinigameParams() {
            super();
            @startTrigger = EditableTrigger(DEFAULT_VL_POS, DEFAULT_MT_SIZE, "Start", "Start");
            @endTrigger = EditableTrigger(DEFAULT_VL_POS, DEFAULT_MT_SIZE, "End", "End");
            anyOrder = false;
        }
        TimeTrialMinigameParams(Json::Value@ json) {
            super(json);
            @startTrigger = EditableTrigger(json.Get("startTrigger", Json::Value()), DEFAULT_VL_POS, DEFAULT_MT_SIZE, "Start");
            startTrigger.name = "Start";
            @endTrigger = EditableTrigger(json.Get("endTrigger", Json::Value()), DEFAULT_VL_POS, DEFAULT_MT_SIZE, "End");
            endTrigger.name = "End";
            anyOrder = json.Get("anyOrder", false);
            // Load checkpoints
            checkpoints.Resize(0);
            auto arr = json.Get("checkpoints", Json::Array());
            for (uint i = 0; i < arr.Length; i++) {
                auto cp = EditableTrigger(arr[i], DEFAULT_VL_POS, DEFAULT_MT_SIZE, "Checkpoint");
                cp.name = "Checkpoint " + (i+1);
                checkpoints.InsertLast(cp);
            }
        }
        Json::Value@ ToJson() override {
            auto j = MinigameParams::ToJson();
            j["startTrigger"] = startTrigger.ToJson();
            j["endTrigger"] = endTrigger.ToJson();
            j["anyOrder"] = anyOrder;
            auto arr = Json::Array();
            for (uint i = 0; i < checkpoints.Length; i++) {
                arr.Add(checkpoints[i].ToJson());
            }
            j["checkpoints"] = arr;
            return j;
        }
        void DrawEditorUI() {
            UI::Text("Start Trigger");
            startTrigger.DrawEditorUI();
            UI::Text("End Trigger");
            endTrigger.DrawEditorUI();
            anyOrder = UI::Checkbox("Checkpoints Any Order", anyOrder);
            UI::Text("Checkpoints: " + checkpoints.Length);
            for (uint i = 0; i < checkpoints.Length; i++) {
                UI::PushID(tostring(i));
                checkpoints[i].DrawEditorUI();
                if (UI::Button(Icons::Trash + " Remove##cp" + i)) {
                    checkpoints.RemoveAt(i);
                    i--;
                }
                UI::PopID();
            }
            if (UI::Button(Icons::Plus + " Add Checkpoint")) {
                auto cp = EditableTrigger(DEFAULT_VL_POS, DEFAULT_MT_SIZE, "Checkpoint", "Checkpoint " + (checkpoints.Length+1));
                checkpoints.InsertLast(cp);
            }
        }
    }

    // --- JumpHighMinigameParams ---
    class JumpHighMinigameParams : MinigameParams {
        EditableTrigger@ startTrigger;

        JumpHighMinigameParams() {
            super();
            @startTrigger = EditableTrigger(DEFAULT_VL_POS, DEFAULT_MT_SIZE, "Start", "Start");
        }

        JumpHighMinigameParams(Json::Value@ json) {
            super(json);
            @startTrigger = EditableTrigger(json.Get("startTrigger", Json::Value()), DEFAULT_VL_POS, DEFAULT_MT_SIZE, "Start");
            startTrigger.name = "Start";
        }

        Json::Value@ ToJson() override {
            auto j = MinigameParams::ToJson();
            j["startTrigger"] = startTrigger.ToJson();
            return j;
        }

        void DrawEditorUI() {
            UI::Text("Start Trigger");
            startTrigger.DrawEditorUI();
        }
    }

    // --- MaxAvgSpeedMinigameParams ---
    class MaxAvgSpeedMinigameParams : MinigameParams {
        EditableTrigger@ startTrigger;
        EditableTrigger@ endTrigger;

        MaxAvgSpeedMinigameParams() {
            super();
            @startTrigger = EditableTrigger(DEFAULT_VL_POS, DEFAULT_MT_SIZE, "Start", "Start");
            @endTrigger = EditableTrigger(DEFAULT_VL_POS, DEFAULT_MT_SIZE, "End", "End");
        }

        MaxAvgSpeedMinigameParams(Json::Value@ json) {
            super(json);
            @startTrigger = EditableTrigger(json.Get("startTrigger", Json::Value()), DEFAULT_VL_POS, DEFAULT_MT_SIZE, "Start");
            startTrigger.name = "Start";
            @endTrigger = EditableTrigger(json.Get("endTrigger", Json::Value()), DEFAULT_VL_POS, DEFAULT_MT_SIZE, "End");
            endTrigger.name = "End";
        }

        Json::Value@ ToJson() override {
            auto j = MinigameParams::ToJson();
            j["startTrigger"] = startTrigger.ToJson();
            j["endTrigger"] = endTrigger.ToJson();
            return j;
        }

        void DrawEditorUI() {
            UI::Text("Start Trigger");
            startTrigger.DrawEditorUI();
            UI::Text("End Trigger");
            endTrigger.DrawEditorUI();
        }
    }

    // --- Minigame base and TimeTrialMinigame ---
    class Minigame {
        string name;
        MinigameType type;
        MinigameParams@ params;

        Minigame(Json::Value@ json) {
            name = json.Get("name", "");
            type = MinigameType(int(json.Get("type", 0)));
            // Detect type and instantiate correct params subclass
            auto paramsJson = json["params"];
            if (type == MinigameType::TimeTrial) @params = TimeTrialMinigameParams(paramsJson);
            else @params = MinigameParams(paramsJson);
        }

        Minigame(const string &in _name, MinigameType _type) {
            name = _name;
            type = _type;
            if (type == MinigameType::TimeTrial) {
                @params = TimeTrialMinigameParams();
            } else {
                @params = MinigameParams();
            }
        }
        Json::Value@ ToJson() {
            auto j = Json::Object();
            j["name"] = name;
            j["type"] = int(type);
            j["params"] = params.ToJson();
            return j;
        }
        void DrawEditor() {
            UI::Text("Name: " + name);
            UI::Text("Type: " + tostring(type));
            // Optionally allow renaming/type change here
            if (type == MinigameType::TimeTrial) {
                TimeTrialMinigameParams@ ttParams = cast<TimeTrialMinigameParams@>(params);
                if (ttParams !is null) ttParams.DrawEditorUI();
            } else {
                // fallback
            }
        }
        void DrawNvgBoxes() {}
    }

    class TimeTrialMinigame : Minigame {
        TimeTrialMinigame(Json::Value@ json) {
            super(json);
        }
        TimeTrialMinigame(const string &in _name) {
            super(_name, MinigameType::TimeTrial);
        }
        void DrawEditor() override {
            UI::Text("Name: " + name);
            TimeTrialMinigameParams@ ttParams = cast<TimeTrialMinigameParams@>(params);
            if (ttParams !is null) ttParams.DrawEditorUI();
        }
        void DrawNvgBoxes() override {
            TimeTrialMinigameParams@ params = cast<TimeTrialMinigameParams@>(this.params);
            if (params !is null) {
                params.startTrigger.DrawNvgBox();
                params.endTrigger.DrawNvgBox();
                for (uint i = 0; i < params.checkpoints.Length; i++) {
                    params.checkpoints[i].DrawNvgBox();
                }
            }
        }
    }

    class JumpHighMinigame : Minigame {
        JumpHighMinigame(Json::Value@ json) {
            super(json);
            @params = JumpHighMinigameParams(json["params"]);
        }

        JumpHighMinigame(const string &in _name) {
            super(_name, MinigameType::JumpHigh);
            @params = JumpHighMinigameParams();
        }

        void DrawEditor() override {
            UI::Text("Name: " + name);
            JumpHighMinigameParams@ jhParams = cast<JumpHighMinigameParams@>(params);
            if (jhParams !is null) jhParams.DrawEditorUI();
        }
        void DrawNvgBoxes() override {
            JumpHighMinigameParams@ params = cast<JumpHighMinigameParams@>(this.params);
            if (params !is null) {
                params.startTrigger.DrawNvgBox();
            }
        }
    }

    class MaxAvgSpeedMinigame : Minigame {
        MaxAvgSpeedMinigame(Json::Value@ json) {
            super(json);
            @params = MaxAvgSpeedMinigameParams(json["params"]);
        }

        MaxAvgSpeedMinigame(const string &in _name) {
            super(_name, MinigameType::MaxAvgSpeed);
            @params = MaxAvgSpeedMinigameParams();
        }

        void DrawEditor() override {
            UI::Text("Name: " + name);
            MaxAvgSpeedMinigameParams@ masParams = cast<MaxAvgSpeedMinigameParams@>(params);
            if (masParams !is null) masParams.DrawEditorUI();
        }
        void DrawNvgBoxes() override {
            MaxAvgSpeedMinigameParams@ params = cast<MaxAvgSpeedMinigameParams@>(this.params);
            if (params !is null) {
                params.startTrigger.DrawNvgBox();
                params.endTrigger.DrawNvgBox();
            }
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

        void TryLoadingJson(const string &in jFile) override {
            ProjectComponent::TryLoadingJson(jFile);
            minigames.Resize(0);
            if (ro_data.GetType() != Json::Type::Object) {
                rw_data = Json::Object(); // reset if not an object
            }
            if (ro_data.HasKey("games") && ro_data["games"].GetType() == Json::Type::Array) {
                auto arr = rw_data["games"];
                for (uint i = 0; i < arr.Length; i++) {
                    Json::Value@ gameJson = arr[i];
                    MinigameType type = MinigameType(int(gameJson.Get("type", 0)));
                    print("Loading Minigame Type: " + tostring(type));
                    Minigame@ minigame;
                    if (type == MinigameType::TimeTrial) {
                        @minigame = TimeTrialMinigame(gameJson);
                    } else if (type == MinigameType::JumpHigh) {
                        @minigame = JumpHighMinigame(gameJson);
                    } else if (type == MinigameType::MaxAvgSpeed) {
                        @minigame = MaxAvgSpeedMinigame(gameJson);
                    } else {
                        // Handle other types or unknown
                        warn("Unknown MinigameType: " + tostring(type));
                        continue;
                    }
                    minigames.InsertLast(minigame);
                }
            }
        }

        void SaveToFile() override {
            Json::Value@ arr = Json::Array();
            for (uint i = 0; i < minigames.Length; i++) {
                arr.Add(minigames[i].ToJson());
            }
            rw_data["games"] = arr;
            ProjectComponent::SaveToFile();
        }

        void DrawComponentInner(ProjectTab@ pTab) override {
            DrawEditorUI();
        }

        void AddMinigame(Minigame@ minigame) {
            minigames.InsertLast(minigame);
        }

        void CreateDefaultJsonObject() override {
            rw_data = Json::Array();
            minigames.Resize(0);
        }
        void DrawEditorUI() {
            if (editingIx != -1) {
                DrawEditingMinigameUI();
            } else {
                DrawMinigameListUI();
            }
        }

        void DrawEditingMinigameUI() {
            UI::PushID(tostring(editingIx));
            auto minigame = minigames[editingIx];
            UI::Text("Editing Minigame: " + minigame.name);
            // Allow editing the minigame name
            minigame.name = UI::InputText("Name", minigame.name);
            if (UI::Button("Done")) {
                editingIx = -1; // Exit editing mode
            }
            UI::Separator();
            if (editingIx >= 0) {
                minigame.DrawEditor();
                minigame.DrawNvgBoxes();
            }
            UI::PopID();
        }

        void DrawMinigameListUI() {
            DrawAddMinigameButton();
            for (uint i = 0; i < minigames.Length; i++) {
                UI::PushID(tostring(i));
                UI::Text("Minigame " + (i + 1) + ": " + minigames[i].name);
                if (UI::Button("Edit##" + i)) {
                    editingIx = int(i); // Enter editing mode
                }
                if (UI::Button("Remove##" + i)) {
                    minigames.RemoveAt(i);
                    i--;
                }
                UI::Separator();
                UI::PopID();
            }

        }

        void DrawAddMinigameButton() {
            if (UI::BeginCombo("Add New Minigame", "Select Type")) {
                if (UI::Selectable("Time Trial", false)) {
                    AddMinigame(TimeTrialMinigame("New TimeTrial Minigame"));
                }
                if (UI::Selectable("Jump High", false)) {
                    AddMinigame(JumpHighMinigame("New JumpHigh Minigame"));
                }
                if (UI::Selectable("Max Avg Speed", false)) {
                    AddMinigame(MaxAvgSpeedMinigame("New MaxAvgSpeed Minigame"));
                }
                UI::EndCombo();
            }
        }
    }
}
