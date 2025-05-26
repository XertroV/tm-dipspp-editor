namespace CM_Editor {

    // MARK: Floors Cmpnt

    // --- FloorEl and FloorsCollection ---
    class FloorEl {
        string name;
        float height;
        FloorEl() {}
        FloorEl(const Json::Value@ j) {
            name = j.Get("name", "");
            height = float(j.Get("height", 0.0));
        }
        Json::Value@ ToJson() const {
            auto j = Json::Object();
            j["name"] = name;
            j["height"] = height;
            return j;
        }
    }

    class FloorsCollection {
        array<FloorEl@> floors;
        FloorsCollection() {}
        FloorsCollection(const Json::Value@ j) { LoadFromJson(j); }
        void LoadFromJson(const Json::Value@ j) {
            floors.RemoveRange(0, floors.Length);
            if (j.GetType() == Json::Type::Array) {
                for (uint i = 0; i < j.Length; i++) {
                    floors.InsertLast(FloorEl(j[i]));
                }
            } else if (j.GetType() == Json::Type::Object) {
                floors.InsertLast(FloorEl(j));
            }
        }
        Json::Value@ ToJson() const {
            auto arr = Json::Array();
            for (uint i = 0; i < floors.Length; i++) {
                arr.Add(floors[i].ToJson());
            }
            return arr;
        }
        uint Length() const { return floors.Length; }
        FloorEl@ At(uint i) const { return floors[i]; }
        void Set(uint i, FloorEl@ f) { @floors[i] = f; }
        void Add(FloorEl@ f) { floors.InsertLast(f); }
        void RemoveAt(uint i) { floors.RemoveAt(i); }
        void Clear() { floors.RemoveRange(0, floors.Length); }
        void Sort() {
            for (uint i = 0; i + 1 < floors.Length; i++) {
                for (uint j = 0; j + 1 < floors.Length - i; j++) {
                    if (floors[j].height > floors[j+1].height) {
                        auto tmp = floors[j];
                        @floors[j] = floors[j+1];
                        @floors[j+1] = tmp;
                    }
                }
            }
        }
    }

    class ProjectFloorsComponent : ProjectComponent {
        FloorsCollection m_floors;
        ProjectFloorsComponent(const string &in jsonPath, ProjectMeta@ meta) {
            super(jsonPath, meta);
            name = "Floors";
            icon = Icons::BuildingO;
            type = EProjectComponent::Floors;
            canInitFromDipsSpecComment = true;
            thisTabClickRequiresTestPlaceMode = true;
        }

        // proxy methods for data access (px = proxy)
        bool get_px_lastFloorEnd() const { return ro_data.Get("lastFloorEnd", false); }
        void set_px_lastFloorEnd(bool v) { rw_data["lastFloorEnd"] = v; }
        uint get_nbFloors() const { return m_floors.Length(); }
        FloorEl@ getFloor(uint i) const { return m_floors.At(i); }
        void setFloor(uint i, FloorEl@ f) { m_floors.Set(i, f); }
        void pushFloor(FloorEl@ f) { m_floors.Add(f); }
        void removeFloor(uint i) { m_floors.RemoveAt(i); }
        void sortFloors() { m_floors.Sort(); }

        void TryLoadingJson(const string&in jFName) override {
            ProjectComponent::TryLoadingJson(jFName);
            m_floors.Clear();
            if (ro_data.HasKey("floors")) {
                m_floors.LoadFromJson(ro_data["floors"]);
            }
        }

        void CreateJsonDataFromComment(DipsSpec@ spec) override {
            CreateDefaultJsonObject();
            px_lastFloorEnd = spec.lastFloorEnd;
            for (uint i = 0; i < spec.floors.Length; i++) {
                m_floors.Add(FloorEl(spec.floors[i].ToJson()));
            }
        }

        void CreateDefaultJsonObject() override {
            auto j = Json::Object();
            j["floors"] = Json::Array();
            j["lastFloorEnd"] = false;
            rw_data = j;
            m_floors.Clear();
        }

        void SaveToFile() override {
            rw_data["floors"] = m_floors.ToJson();
            ProjectComponent::SaveToFile();
        }

        void DrawComponentInner(ProjectTab@ pTab) override {
            UI::AlignTextToFramePadding();
            UI::Text("# Floors: " + nbFloors);
            UI::SameLine();
            if (UI::Button(Icons::Plus + " Add Floor")) {
                OnCreateNewFloor();
            }
            UI::Separator();
            if (IsCreatingFloor) {
                DrawFloorCreation();
            } else {
                DrawFloorsList();
            }
        }

        void DrawFloorCreation() {
            UI::Text("Creating new floor...");
            DrawInstructionText("Place Car at Floor Start (or Height)", true);

            if (UI::Button(Icons::Times + " Cancel")) {
                @creatingFloor = null;
                OnSelfCancelAwaitMouseClick();
            }
        }

        int editIx = -1;

        void DrawFloorsList() {
            UI::AlignTextToFramePadding();
            UI::Text("Floors List");
            UI::SameLine();
            if (UI::Button(Icons::Sort + " Sort")) {
                sortFloors();
            }

            UI::TextWrapped("By default, floor names get cut off after 3-4 characters.\nLeave empty for default (the floor number).");

            int remIx = -1;

            UI::Separator();

            UI::BeginChild("fl");

            UI::BeginTable("Floors", 3, UI::TableFlags::SizingStretchProp);
            UI::TableSetupColumn("Name", UI::TableColumnFlags::WidthStretch);
            UI::TableSetupColumn("Height", UI::TableColumnFlags::WidthStretch);
            UI::TableSetupColumn("Actions", UI::TableColumnFlags::WidthFixed);

            for (uint i = 0; i < nbFloors; i++) {
                bool editing = int(i) == editIx;
                UI::PushID("flr" + i);
                UI::TableNextRow();
                auto floor = getFloor(i);
                float height = floor.height;
                string name = floor.name;
                if (name.Length == 0 && !editing) name = "\\$i\\$aaaFloor " + i;

                UI::TableNextColumn();
                bool iNamePressedEnter = false;
                if (editing) {
                    name = UI::InputText("##name" + i, name, iNamePressedEnter, UI::InputTextFlags::EnterReturnsTrue);
                    floor.name = name;
                } else {
                    UI::AlignTextToFramePadding();
                    UI::Text(name);
                }

                UI::TableNextColumn();
                if (editing) {
                    height = UI::InputFloat("##height" + i, height);
                    floor.height = height;
                } else {
                    UI::Text(tostring(height));
                }

                UI::TableNextColumn();
                if (editing) {
                    if (UI::Button(Icons::Check + " Done") || iNamePressedEnter) {
                        editIx = -1;
                    }
                } else {
                    if (UI::Button(Icons::Pencil + " Edit")) {
                        editIx = i;
                    }
                    UI::SameLine();
                    UI::BeginDisabled(!UI::IsKeyDown(UI::Key::LeftShift));
                    if (UI::Button(Icons::TrashO + " Delete")) {
                        remIx = i;
                    }
                    UI::EndDisabled();
                    UI::SameLine();
                    UI::AlignTextToFramePadding();
                    UI::Text("\\$8af"+Icons::InfoCircle);
                    AddSimpleTooltip("Hold Shift to delete");
                }
                UI::PopID();
            }

            UI::EndTable();
            UI::EndChild();

            if (remIx != -1) {
                removeFloor(remIx);
                SaveToFile();
            }
        }

        bool get_IsCreatingFloor() {
            return creatingFloor !is null;
        }

        FloorEl@ creatingFloor = null;
        void OnCreateNewFloor() {
            @creatingFloor = FloorEl();
            creatingFloor.height = 0.0;
            creatingFloor.name = "";
            OnSelfAwaitingMouseClick();
            startnew(SetEditorToTestMode);
        }

        void SetCreatingFloorHeight(float height) {
            creatingFloor.height = height;
            pushFloor(creatingFloor);
            sortFloors();
            @creatingFloor = null;
            SaveToFile();
        }


        void OnMouseClick(int x, int y, int button) override {
            if (creatingFloor is null) return;
            if (!EditorIsInTestPlaceMode() || button != 0) {
                // doing something else like moving camera. requeue intercept
                startnew(CoroutineFunc(OnSelfAwaitingMouseClick));
                return;
            }
            auto icPos = GetEditorItemCursorPos();
            // car is offset +0.5
            SetCreatingFloorHeight(icPos.y - 0.5);
        }
    }

}
