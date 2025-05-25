namespace CM_Editor {

    // MARK: Proj Meta

    class ProjectMeta {
        string name;
        string path;

        ProjectMeta(const string &in name) {
            this.name = name;
            this.path = ProjectsDir + "/" + name;
        }

        bool ProjectFileExists(const string &in file) {
            return IO::FileExists(ProjectFilePath(file));
        }

        string ProjectFilePath(const string &in file) {
            return path + "/" + file;
        }

        // returns absolute path or throws
        string GetPathEnsureSubdir() {
            if (!path.StartsWith(ProjectsDir)) throw("Path does not start with ProjectsDir: " + path);
            // - 1 for the slash after projects dir
            if (int(path.Length) - int(ProjectsDir.Length) - 1 < 2) throw("Path is too short: " + path);
            return path;
        }

        Tab@ CreateTab(TabGroup@ parent) {
            if (name.Length == 0) throw("Name is empty");
            if (path.Length == 0) throw("Path is empty");
            return ProjectTab(parent, this);
        }

        bool CheckStillExists() {
            if (path.Length == 0) return false;
            return IO::FolderExists(path);
        }

        void LoadIndex() {
            if (LoadedIndex) return;
            LoadedIndex = true;
        }

        bool LoadedIndex = false;
    }

    const string PROJ_FILE_INFO = "info.json.txt";
    const string PROJ_FILE_FLOORS = "floors.json.txt";
    const string PROJ_FILE_VOICELINES = "voicelines.json.txt";
    const string PROJ_FILE_TRIGGERS = "triggers.json.txt";
    const string PROJ_FILE_MINIGAMES = "minigames.json.txt";
    const string PROJ_FILE_ASSETS = "assets.json.txt";
    const string PROJ_FILE_COLLECTABLES = "collectables.json.txt";

    // MARK: Project Tab

    class ProjectTab : CompactTab {
        ProjectMeta@ meta;
        ProjectComponentGroup@[] componentGroups;

        ProjectTab(TabGroup@ parent, ProjectMeta@ meta) {
            super(parent, meta.name, "");
            @this.meta = meta;
            meta.LoadIndex();

            auto grp1 = AddComponentGroup("Project");
            auto grp2 = AddComponentGroup("Components");
            grp1.AddComponent(ProjectInfoComponent(PROJ_FILE_INFO, meta));
            grp1.AddComponent(MapInfoComponent(meta));
            grp1.AddComponent(ProjectFloorsComponent(PROJ_FILE_FLOORS, meta));
            grp2.AddComponent(ProjectVoiceLinesComponent(PROJ_FILE_VOICELINES, meta));
            grp2.AddComponent(ProjectAssetsComponent(PROJ_FILE_ASSETS, meta));
            // grp2.AddComponent(ProjectTriggersComponent());
            // grp2.AddComponent(ProjectMinigamesComponent());
            // grp2.AddComponent(ProjectCollectablesComponent());
        }

        ProjectComponentGroup@ AddComponentGroup(const string &in name) {
            auto grp = ProjectComponentGroup(name, meta);
            componentGroups.InsertLast(grp);
            return grp;
        }

        ProjectFloorsComponent@ GetFloorsComponent() {
            ProjectFloorsComponent@ r;
            for (uint i = 0; i < componentGroups.Length; i++) {
                @r = componentGroups[i].GetFloorsComponent();
                if (r !is null) {
                    return r;
                }
            }
            return null;
        }

        ProjectAssetsComponent@ GetAssetsComponent() {
            return cast<ProjectAssetsComponent>(GetComponentByType(EProjectComponent::Assets));
        }

        ProjectInfoComponent@ GetInfoComponent() {
            return cast<ProjectInfoComponent>(GetComponentByType(EProjectComponent::Info));
        }

        string GetUrlPrefix() {
            return GetInfoComponent().UrlPrefix;
        }

        ProjectComponent@ GetComponentByType(EProjectComponent type) {
            for (uint i = 0; i < componentGroups.Length; i++) {
                auto cmp = componentGroups[i].GetComponentByType(type);
                if (cmp !is null) {
                    return cmp;
                }
            }
            return null;
        }

        void _AfterDrawTab() override {
            if (!keepProjectOpen) startnew(CoroutineFunc(CheckCloseProject));
        }

        bool keepProjectOpen;
        bool _BeginTabItem(const string&in l, int flags) override {
            return UI::BeginTabItem(l, keepProjectOpen, flags);
        }

        int get_TabFlags() override property {
            auto flags = TabFlagSelected;
            if (HasAnyUnsaved()) {
                return flags | UI::TabItemFlags::UnsavedDocument;
            }
            return flags;
        }

        bool HasAnyUnsaved() {
            for (uint i = 0; i < componentGroups.Length; i++) {
                if (componentGroups[i].HasUnsavedChanges()) {
                    return true;
                }
            }
            return false;
        }

        void CheckCloseProject() {
            if (keepProjectOpen) return;
            // otherwise, prompt to save or discard changes
            // otherwise, remove from parent
            Parent.RemoveTab(this);
        }

        void DrawInner() override {
            if (!meta.LoadedIndex) {
                UI::Text("Loading project...");
                meta.LoadIndex();
                return;
            }

            int cFlags = UI::ChildFlags::Border | UI::ChildFlags::AlwaysAutoResize | UI::ChildFlags::AutoResizeX | UI::ChildFlags::AutoResizeY;
            auto avail = UI::GetContentRegionAvail();
            auto fp = UI::GetStyleVarVec2(UI::StyleVar::FramePadding);
            auto left = avail * vec2(0.25, 1);
            if (left.x > 300) left.x = 300;
            auto tlRight = UI::GetCursorPos() + vec2(left.x, 0);
            auto right = avail - vec2(left.x, 0) - fp * 2;
            left -= fp * 2.0;

            auto maxH = UI::GetContentRegionAvail().y;
            if (UI::BeginChild("##projMetaLeft", left, cFlags)) {
                // buttons: save / save all
                if (UI::Button(Icons::FloppyO + " Save")) {
                    SaveActiveComponent();
                }
                UI::SameLine();
                if (UI::Button(Icons::FloppyO + " Save All")) {
                    for (uint i = 0; i < componentGroups.Length; i++) {
                        componentGroups[i].SaveAll();
                    }
                }
                // the components
                DrawProjComponentSelector();
            }
            UI::EndChild();
            UI::SetCursorPos(tlRight);
            if (UI::BeginChild("##projMetaRight", right, cFlags)) {
                DrawProjComponent();
            }
            UI::EndChild();
        }

        int selectedComponent = EProjectComponent::Info;
        void DrawProjComponentSelector() {
            if (UI::BeginChild("##projMetaSelector")) {
                for (uint i = 0; i < componentGroups.Length; i++) {
                    selectedComponent = componentGroups[i].DrawSelector(selectedComponent);
                }
            }
            UI::EndChild();
        }

        void DrawProjComponent() {
            for (uint i = 0; i < componentGroups.Length; i++) {
                auto grp = componentGroups[i];
                if (grp.DrawProjComponent(selectedComponent, this)) {
                    break;
                }
            }
        }

        void SaveActiveComponent() {
            for (uint i = 0; i < componentGroups.Length; i++) {
                if (componentGroups[i].SaveActiveComponent(selectedComponent)) {
                    return;
                }
            }
        }

        string AssetBrowser(const string &in label, const string &in value, AssetTy ty, bool allowAdd = true) {
            return GetAssetsComponent().Browser(label, value, ty, allowAdd);
        }
    }
}
