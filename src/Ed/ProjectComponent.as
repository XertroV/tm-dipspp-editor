namespace CM_Editor {

    enum EProjectComponent {
        Unknown,
        Info,
        Floors,
        VoiceLines,
        TextTriggers,
        Assets,
        Collectables,
        Minigames,
        _LAST,
        MapInfo,
    }

    string ProjectComponentToString(EProjectComponent c) {
        switch (c) {
            case EProjectComponent::Unknown: return "Unknown";
            case EProjectComponent::Info: return "Project Info";
            case EProjectComponent::MapInfo: return "Map Info";
            case EProjectComponent::Floors: return "Floors";
            case EProjectComponent::VoiceLines: return "Voice Lines";
            case EProjectComponent::TextTriggers: return "Text Triggers";
            case EProjectComponent::Assets: return "Assets";
            case EProjectComponent::Collectables: return "Collectables";
            case EProjectComponent::Minigames: return "Minigames";
        }
        return "? Unknown ?";
    }

    // MARK: Proj Cmpnt Group

    class ProjectComponentGroup {
        string name;
        ProjectMeta@ meta;
        ProjectComponent@[] components;
        EProjectComponent[] componentTypes;

        ProjectComponentGroup(const string &in name, ProjectMeta@ meta) {
            this.name = name;
            @this.meta = meta;
        }

        ProjectComponent@ AddComponent(ProjectComponent@ component) {
            components.InsertLast(component);
            componentTypes.InsertLast(component.type);
            return component;
        }

        ProjectFloorsComponent@ GetFloorsComponent() {
            return cast<ProjectFloorsComponent>(GetComponentByType(EProjectComponent::Floors));
        }

        ProjectAssetsComponent@ GetAssetsComponent() {
            return cast<ProjectAssetsComponent>(GetComponentByType(EProjectComponent::Assets));
        }

        ProjectComponent@ GetComponentByType(EProjectComponent type) {
            for (uint i = 0; i < components.Length; i++) {
                if (components[i].type == type) {
                    return components[i];
                }
            }
            return null;
        }

        bool HasUnsavedChanges() {
            for (uint i = 0; i < components.Length; i++) {
                if (components[i].isDirty) {
                    return true;
                }
            }
            return false;
        }

        int DrawSelector(int selected) {
            UI::SeparatorText("\\$i\\$bbb" + name);
            for (uint i = 0; i < components.Length; i++) {
                auto comp = components[i];
                if (UI::Selectable(comp.icon + " " + comp.name, selected == int(comp.type))) {
                    selected = comp.type;
                }
            }
            return selected;
        }

        bool DrawProjComponent(int selectedType, ProjectTab@ pTab) {
            for (uint i = 0; i < components.Length; i++) {
                if (componentTypes[i] == selectedType) {
                    // draw
                    components[i].DrawComponent(pTab);
                    return true;
                }
            }
            return false;
        }

        bool SaveActiveComponent(int selectedType) {
            for (uint i = 0; i < components.Length; i++) {
                if (componentTypes[i] == selectedType) {
                    components[i].SaveToFile();
                    return true;
                }
            }
            // NotifyError("No component of type " + ProjectComponentToString(EProjectComponent(selectedType)) + " found to save.");
            return false;
        }

        void SaveAll() {
            for (uint i = 0; i < components.Length; i++) {
                components[i].SaveToFile();
            }
        }
    }

    class ProjectComponent {
        string name;
        string icon;
        ProjectMeta@ meta;
        private Json::Value@ data = Json::Value();
        string jsonPath;
        EProjectComponent type;
        bool isDirty = false;
        bool hasFile = false;
        bool canInitFromDipsSpecComment = false;
        bool thisTabClickRequiresTestPlaceMode = false;

        ProjectComponent(const string &in _jsonFName, ProjectMeta@ meta) {
            // default values
            name = "! New Component";
            icon = Icons::ExclamationTriangle;
            type = EProjectComponent::Unknown;
            @data = Json::Object();
            @this.meta = meta;
            if (_jsonFName.Length > 0) {
                startnew(CoroutineFuncUserdataString(TryLoadingJson), _jsonFName);
            }
        }

        void TryLoadingJson(const string &in jFName) {
            jsonPath = meta.ProjectFilePath(jFName);
            if (!meta.ProjectFileExists(jFName)) {
                hasFile = false;
                return;
            }
            hasFile = true;
            @data = Json::FromFile(jsonPath);
        }

        const Json::Value@ get_ro_data() const {
            return data;
        }

        Json::Value@ get_rw_data() {
            OnDirty();
            return data;
        }

        // can be overridden to hook
        void OnDirty() {
            isDirty = true;
        }

        int DrawSelector(int selected) {
            if (UI::Selectable(icon + " " + name, selected == int(type))) {
                selected = type;
            }
            return selected;
        }

        string get_ComponentTitleName() {
            return name;
        }

        void DrawComponent(ProjectTab@ pTab) {
            UI::Text(ComponentTitleName);
            UI::Separator();
            if (!hasFile) {
                UI::TextWrapped("Component not found: " + name);
                UI::TextWrapped("Create?");
                if (canInitFromDipsSpecComment) {
                    DrawInitializeFromDipsSpecComment();
                }
                DrawInitializeButton();
            } else {
                DrawComponentInner(pTab);
            }
        }

        void DrawInitializeFromDipsSpecComment() {
            if (UI::Button("" + Icons::Plus + " Create " + name + " from Map Comment")) {
                CreateComponentFromComment();
            }
        }

        void DrawInitializeButton() {
            if (UI::Button("" + Icons::Plus + " Add " + name)) {
                CreateComponentFile();
            }
        }

        void DrawComponentInner(ProjectTab@ pTab) {
            UI::TextWrapped("This is the " + name + " component. Override DrawComponentInner.");
        }

        void CreateComponentFromComment() {
            CreateJsonDataFromComment(DipsSpec(GetApp().RootMap.Comments));
            SaveToFile();
        }

        // creates the components data file and initializes the json object
        void CreateComponentFile() {
            CreateDefaultJsonObject();
            SaveToFile();
        }

        void CreateDefaultJsonObject() {
            throw("Override me: CreateDefaultJsonObject");
        }

        void CreateJsonDataFromComment(DipsSpec@ spec) {
            throw("Override me (only necessary if canInitFromDipsSpecComment == true)");
        }

        void SaveToFile() {
            if (data is null) {
                NotifyError("Failed to save " + name + ": data is null");
                return;
            }
            if (jsonPath == "") {
                NotifyError("Failed to save " + name + ": path is empty");
                return;
            }
            Json::ToFile(jsonPath, data, true);
            trace("Saved " + name + " to " + jsonPath);
            hasFile = true;
            isDirty = false;
        }

        void OnMouseClick(int x, int y, int button) {
            // do nothing, for overrides
        }

        void OnSelfAwaitingMouseClick() {
            @componentWaitingForMouseClick = this;
            g_InterceptOnMouseClick = true;
            g_InterceptClickRequiresTestMode = thisTabClickRequiresTestPlaceMode;
        }

        bool get_IAmAwaitingMouseClick() {
            return componentWaitingForMouseClick is this;
        }

        void OnSelfCancelAwaitMouseClick() {
            if (componentWaitingForMouseClick is this) {
                @componentWaitingForMouseClick = null;
                g_InterceptOnMouseClick = false;
                if (thisTabClickRequiresTestPlaceMode) startnew(RestoreEditorMode);
            } else if (componentWaitingForMouseClick !is null) {
                NotifyWarning("Some other component is waiting for a mouse click: " + componentWaitingForMouseClick.name);
            }
        }
    }

    // utility for drawing nvg instruction text easily.
    void DrawInstructionText(const string &in text, bool alsoUI) {
        if (alsoUI) UI::Text(text);
        nvg::Reset();
        auto fontSize = 64.0 * g_screen.y / 1440.0;
        nvg::FontSize(fontSize);
        auto bounds = nvg::TextBounds(text) + vec2(fontSize * 0.25);
        auto midPoint = g_screen * vec2(.5, .2);
        auto bgRect = vec4(midPoint - bounds * 0.5, bounds);

        nvg::BeginPath();
        nvg::FillColor(cBlack);
        nvg::RoundedRect(bgRect.xy, bgRect.zw, 8);
        nvg::Fill();
        nvg::ClosePath();

        nvg::TextAlign(nvg::Align::Center | nvg::Align::Middle);
        nvgDrawTextWithStroke(midPoint, text, cOrange);
    }

}
