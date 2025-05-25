namespace CM_Editor {
    class CompactTab : Tab {
        CompactTab(TabGroup@ parent, const string &in tabName, const string &in icon) {
            super(parent, tabName, icon);
            noContentWrap = true;
        }
    }

    class LoadProjTab : CompactTab {
        string[]@ projects;
        ProjectMeta@[] projectMetas;

        LoadProjTab(TabGroup@ parent) {
            super(parent, "Your Projects", Icons::FolderOpenO);
        }

        void DrawInner() override {
            if (projects is null) RefreshProjects();
            UI::SeparatorText("Your Projects (" + projects.Length + ")");

            if (UI::Button(Icons::FileO + " New")) {
                OnClickCreateNew();
            }
            UI::SameLine();
            if (UI::Button(Icons::FolderOpenO + " Browse All")) {
                OpenExplorerPath(ProjectsDir);
            }
            UI::SameLine();
            if (UI::Button(Icons::Refresh + Icons::FolderOpenO + " Refresh")) {
                RefreshProjects();
            }

            UI::Separator();
            DrawProjectSelector();
        }

        void ResetSelectedProj() {
            selectedProject = "";
            selectedProjectIx = -1;
        }

        void SelectProjectNamed(const string &in name) {
            auto ix = projects.Find(name);
            if (ix < 0) {
                NotifyWarning("Project not found: " + name);
                return;
            }
            selectedProject = name;
            selectedProjectIx = ix;
        }

        void RefreshProjects() {
            ResetSelectedProj();
            @projects = ListProjects();
            projectMetas.RemoveRange(0, projectMetas.Length);
            for (uint i = 0; i < projects.Length; i++) {
                auto proj = ProjectMeta(projects[i]);
                projectMetas.InsertLast(proj);
            }
        }

        // MARK: Proj Selct

        void DrawProjectSelector() {
            auto childFlags = UI::ChildFlags::Border | UI::ChildFlags::AlwaysAutoResize | UI::ChildFlags::AutoResizeX | UI::ChildFlags::AutoResizeY;
            auto avail = UI::GetContentRegionAvail();
            auto fp = UI::GetStyleVarVec2(UI::StyleVar::FramePadding);

            auto left = avail * vec2(0.25, 1);
            if (left.x > 300) left.x = 300;
            auto tl = UI::GetCursorPos();
            auto tl2 = tl + vec2(left.x, 0);

            auto right = avail - vec2(left.x, 0) - fp * 2;
            left -= fp * 2.0;
            // UI::SetCursorPos(tl);
            if (UI::BeginChild("##projSelList", left, childFlags)) {
                // auto pos = UI::GetCursorPos();
                // UI::Dummy(left);
                // UI::SetCursorPos(pos);
                DrawProjectSelectables();
            }
            UI::EndChild();
            // UI::SetCursorPos(tl2);
            // UI::Text("Right");
            UI::SetCursorPos(tl2);
            if (UI::BeginChild("##projMetaRight", right, childFlags)) {
                // auto pos = UI::GetCursorPos();
                // UI::Dummy(right);
                // UI::SetCursorPos(pos);
                if (isCreatingNew) {
                    DrawCreateNewProject();
                } else {
                    DrawSelectedProjectMeta();
                }
            }
            UI::EndChild();
            // UI::Separator();
        }

        bool isCreatingNew = false;
        string m_newName = "Untitled";
        void OnClickCreateNew() {
            isCreatingNew = true;
            ResetSelectedProj();
        }

        int selectedProjectIx = -1;
        string selectedProject = "";
        void DrawProjectSelectables() {
            if (projects.Length == 0) {
                UI::Text("No projects found.");
                return;
            }
            for (uint i = 0; i < projects.Length; i++) {
                auto proj = projects[i];
                auto projMeta = projectMetas[i];
                if (UI::Selectable(proj, proj == selectedProject)) {
                    OpenProject(i, projMeta);
                }
                if (UI::IsItemHovered()) {
                    UI::SetMouseCursor(UI::MouseCursor::Hand);
                    UI::SetTooltip("Open project: " + proj);
                }
            }
        }

        void OpenProject(uint ix, ProjectMeta@ meta) {
            selectedProject = meta.name;
            selectedProjectIx = ix;
            isCreatingNew = false;
        }

        void OpenFirstProject() {
            if (projects.Length == 0) {
                NotifyWarning("No projects found.");
                return;
            }
            OpenProject(0, projectMetas[0]);
        }


        void DrawSelectedProjectMeta() {
            if (selectedProjectIx < 0) {
                UI::Text("No project selected.");
                return;
            }
            auto meta = projectMetas[selectedProjectIx];
            UI::Text("Selected Project: " + meta.name);
            UI::Text("Path: " + meta.path);
            UI::Separator();
            if (UI::Button(Icons::Pencil + " Edit Project")) {
                AddProjectTab(meta);
            }
            UI::SameLine();
            if (UI::Button(Icons::FolderOpenO + " Browse")) {
                OpenExplorerPath(meta.path);
            }
            UI::SameLine();
            UI::BeginDisabled(!UI::IsKeyDown(UI::Key::LeftShift));
            if (UI::Button(Icons::Trash + " Delete")) {
                startnew(CoroutineFuncUserdata(DeleteProject), meta);
            }
            UI::EndDisabled();
            UI::SameLine();
            UI::AlignTextToFramePadding();
            UI::Text(Icons::InfoCircle);
            AddSimpleTooltip("Hold Left Shift to enable delete button.");
        }

        string newProjectErrMsg = "";
        void DrawCreateNewProject() {
            UI::SeparatorText("Create New Project");
            bool changed;
            m_newName = UI::InputText("##newProjName", m_newName, changed, UI::InputTextFlags::EnterReturnsTrue);

            if (UI::Button(Icons::Plus + " Create") || changed) {
                newProjectErrMsg = "";
                CreateNewProject(m_newName);
            }

            if (newProjectErrMsg.Length > 0) {
                UI::TextWrapped(newProjectErrMsg);
            }
        }

        void CreateNewProject(const string &in pName) {
            string errPre = Time::FormatString("[%H:%M:%S] ");
            if (IO::FolderExists(ProjectsDir + "/" + pName)) {
                newProjectErrMsg = errPre + "Project already exists: " + pName;
                return;
            }
            if (pName.Contains("/") || pName.Contains("\\")) {
                newProjectErrMsg = errPre + "Project name cannot contain slashes: " + pName;
                return;
            }
            if (pName.Length < 3) {
                newProjectErrMsg = errPre + "Project name must be at least 3 characters: " + pName;
                return;
            }
            if (pName.Length > 50) {
                newProjectErrMsg = errPre + "Project name must be at most 50 characters: " + pName;
                return;
            }
            IO::CreateFolder(ProjectsDir + "/" + pName, false);
            if (!IO::FolderExists(ProjectsDir + "/" + pName)) {
                newProjectErrMsg = errPre + "Failed to create project folder: " + pName;
                return;
            }
            RefreshProjects();
            SelectProjectNamed(pName);
            ResetCreateNewProject();
        }

        void ResetCreateNewProject() {
            newProjectErrMsg = "";
            isCreatingNew = false;
            m_newName = "Untitled";
        }

        void DeleteProject(ref@ meta) {
            auto pm = cast<ProjectMeta>(meta);
            if (pm is null) {
                Notify("Failed to delete project (null ref)");
                return;
            }
            Notify("Deleting project: " + pm.name);
            IO::DeleteFolder(pm.GetPathEnsureSubdir(), true);
            RefreshProjects();
        }

        void AddProjectTab(ProjectMeta@ meta) {
            if (Parent.HasTabNamed(meta.name)) {
                Parent.FocusTab(meta.name);
                return;
            }
            Tab@ tab = meta.CreateTab(Parent);
            if (tab is null) {
                Notify("Failed to add project tab: " + meta.name);
                return;
            }
            tab.SetSelectedTab();
        }
    }
}
