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

        // --- Start/Finish properties and user flags ---
        private float _userStart = 0.0f;
        private float _userFinish = 0.0f;
        private bool _useUserStart = false;
        private bool _useUserFinish = false;

        // Proxy accessors for UI and serialization
        float get_px_start() const { return _userStart; }
        void set_px_start(float v) { rw_data["start"] = _userStart = v; }
        float get_px_finish() const { return _userFinish; }
        void set_px_finish(float v) { rw_data["finish"] = _userFinish = v; }
        bool get_px_useStart() const { return _useUserStart; }
        void set_px_useStart(bool v) { rw_data["useStart"] = _useUserStart = v; }
        bool get_px_useFinish() const { return _useUserFinish; }
        void set_px_useFinish(bool v) { rw_data["useFinish"] = _useUserFinish = v; }

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
            // Load start/finish and flags
            _userStart = ro_data.Get("start", 0.0f);
            _userFinish = ro_data.Get("finish", 0.0f);
            _useUserStart = ro_data.Get("useStart", false);
            _useUserFinish = ro_data.Get("useFinish", false);
        }

        void CreateJsonDataFromComment(DipsSpec@ spec) override {
            CreateDefaultJsonObject();
            px_lastFloorEnd = spec.lastFloorEnd;
            for (uint i = 0; i < spec.floors.Length; i++) {
                m_floors.Add(FloorEl(spec.floors[i].ToJson()));
            }
            // Optionally set start/finish from spec if needed
        }

        void CreateDefaultJsonObject() override {
            auto j = Json::Object();
            j["floors"] = Json::Array();
            j["lastFloorEnd"] = false;
            j["start"] = 0.0f;
            j["finish"] = 0.0f;
            j["useStart"] = false;
            j["useFinish"] = false;
            rw_data = j;
            m_floors.Clear();
        }

        void SaveToFile() override {
            rw_data["floors"] = m_floors.ToJson();
            rw_data["lastFloorEnd"] = px_lastFloorEnd;
            rw_data["start"] = _userStart;
            rw_data["finish"] = _userFinish;
            rw_data["useStart"] = _useUserStart;
            rw_data["useFinish"] = _userFinish;
            ProjectComponent::SaveToFile();
        }

        void DrawComponentInner(ProjectTab@ pTab) override {
            UI::AlignTextToFramePadding();
            UI::Text("# Floors: " + nbFloors);
            UI::SameLine();
            if (UI::Button(Icons::Plus + " Add Floor")) {
                OnCreateNewFloor();
            }

            // --- Start/Finish UI ---
            UI::SeparatorText("Start/Finish Heights");
            UI::AlignTextToFramePadding();
            UI::TextWrapped("It's safe to leave these unchecked. The start and finish heights will be autodetected in that case.\n"
                            "Setting the finish is recommended if 16-32m of inaccuracy would bother you.");
            bool changedStart = false, changedFinish = false, changedUseStart = false, changedUseFinish = false;
            bool useStart = px_useStart;
            bool useFinish = px_useFinish;
            float startVal = px_start;
            float finishVal = px_finish;

            bool prevUseStart = useStart;
            useStart = UI::Checkbox("Set custom Start height", useStart);
            changedUseStart = (useStart != prevUseStart);
            UI::SameLine();
            UI::BeginDisabled(!useStart);
            float prevStartVal = startVal;
            startVal = UI::InputFloat("Start Height", startVal);
            changedStart = (startVal != prevStartVal);
            UI::EndDisabled();
            if (changedUseStart) px_useStart = useStart;
            if (changedStart) px_start = startVal;

            bool prevUseFinish = useFinish;
            useFinish = UI::Checkbox("Set custom Finish height", useFinish);
            changedUseFinish = (useFinish != prevUseFinish);
            UI::SameLine();
            UI::BeginDisabled(!useFinish);
            float prevFinishVal = finishVal;
            finishVal = UI::InputFloat("Finish Height", finishVal);
            changedFinish = (finishVal != prevFinishVal);
            UI::EndDisabled();
            if (changedUseFinish) px_useFinish = useFinish;
            if (changedFinish) px_finish = finishVal;

            UI::SeparatorText("Floors");
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
            UI::SameLine();
            UI::Dummy(vec2(4, 0));
            UI::SameLine();
            auto _lastFloorEnd = px_lastFloorEnd;
            _lastFloorEnd = UI::Checkbox("Last Floor Named 'End'", _lastFloorEnd);
            AddSimpleTooltip("Note, setting a name for the last floor will override this.");
            if (_lastFloorEnd != px_lastFloorEnd) px_lastFloorEnd = _lastFloorEnd;

            UI::TextWrapped("By default, floor names get cut off after 3-4 characters.\nLeave empty for default (the floor number).");

            int remIx = -1;

            // leave this as thin separator
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

        // return null if no floor exists for that position
        // cols = number of columns in the table
        // maxPerCol = maximum number of floors per column
        // row = current row of table
        // col = current column of table
        // Note: we want to fill out columns first, then rows. (As though were were going top to bottom, left to right)
        FloorEl@ GetFloorForTablePos(uint cols, uint maxPerCol, uint row, uint col, uint &out floorIx) {
            floorIx = uint(-1);
            if (col >= cols || row >= maxPerCol) return null;
            uint ix = col * maxPerCol + row;
            floorIx = ix;
            if (ix >= m_floors.Length()) return null;
            return m_floors.At(ix);
        }
    }

}
