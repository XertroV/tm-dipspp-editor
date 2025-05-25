namespace CM_Editor {

    // MARK: Floors Cmpnt

    class ProjectFloorsComponent : ProjectComponent {
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
        uint get_nbFloors() const { return ro_data.HasKey("floors") ? ro_data["floors"].Length : 0; }
        Json::Value getFloor(uint i) const { return ro_data["floors"][i]; }
        Json::Value@ getRwFloor(uint i) { return rw_data["floors"][i]; }
        void pushFloor(Json::Value@ floor) { rw_data["floors"].Add(floor); }
        void setFloor(uint i, Json::Value@ floor) { rw_data["floors"][i] = floor; }
        void removeFloor(uint i) {
            if (i >= nbFloors) return;
            rw_data["floors"].Remove(i);
        }

        void sortFloors() {
            // simple sorting; should not be too inefficient if we keep floors in sorted order
            auto @floors = rw_data["floors"];
            if (floors.Length == 0) return;
            // subtract 1 for the last floor
            int nb = nbFloors - 1;
            for (int i = 0; i < nb; i++) {
                if (float(floors[i]["height"]) > float(floors[i + 1]["height"])) {
                    SwapFloors(i, i + 1);
                    i = -1; // restart
                }
            }
        }

        void SwapFloors(uint i, uint j) {
            auto @floors = rw_data["floors"];
            if ((i > j ? i : j) >= nbFloors) return;
            string tName = floors[i]["name"];
            float tHeight = floors[i]["height"];
            floors[i]["name"] = floors[j]["name"];
            floors[i]["height"] = floors[j]["height"];
            floors[j]["name"] = tName;
            floors[j]["height"] = tHeight;
        }

        void CreateJsonDataFromComment(DipsSpec@ spec) override {
            CreateDefaultJsonObject();
            px_lastFloorEnd = spec.lastFloorEnd;
            auto nbFloors = spec.floors.Length;
            for (uint i = 0; i < nbFloors; i++) {
                rw_data["floors"].Add(spec.floors[i].ToJson());
            }
        }

        void CreateDefaultJsonObject() override {
            auto j = Json::Object();
            j["floors"] = Json::Array();
            j["lastFloorEnd"] = false;
            rw_data = j;
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
                float height = floor["height"];
                string name = floor["name"];
                if (name.Length == 0 && !editing) name = "\\$i\\$aaaFloor " + i;

                UI::TableNextColumn();
                if (editing) {
                    name = UI::InputText("##name" + i, name);
                    floor["name"] = name;
                    // if (name.Length == 0) name = "\\$i\\$aaaFloor " + i;
                } else {
                    UI::AlignTextToFramePadding();
                    UI::Text(name);
                }

                UI::TableNextColumn();
                if (editing) {
                    height = UI::InputFloat("##height" + i, height);
                    floor["height"] = height;
                } else {
                    UI::Text(tostring(height));
                }

                UI::TableNextColumn();
                if (editing) {
                    if (UI::Button(Icons::Check + " Done")) {
                        editIx = -1;
                    }
                } else {
                    if (UI::Button(Icons::Pencil + " Edit")) {
                        editIx = i;
                        // UI::SetKeyboardFocusHere(-1); // -2 = assert fail
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

        Json::Value@ creatingFloor = null;
        void OnCreateNewFloor() {
            auto floor = Json::Object();
            floor["height"] = 0.0;
            floor["name"] = "";
            @creatingFloor = floor;
            OnSelfAwaitingMouseClick();
            startnew(SetEditorToTestMode);
        }

        void SetCreatingFloorHeight(float height) {
            creatingFloor["height"] = height;
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
