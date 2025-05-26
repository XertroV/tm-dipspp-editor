namespace CM_Editor {
    // MARK: TextTriggerComponent

    class TextTrigger {
        EditableTrigger@ trigger;

        TextTrigger() {
            @trigger = EditableTrigger(DEFAULT_VL_POS, DEFAULT_MT_SIZE, "TextTrigger");
        }
        TextTrigger(const Json::Value@ j) {
            @trigger = EditableTrigger(j.Get("trigger", Json::Value()), DEFAULT_VL_POS, DEFAULT_MT_SIZE, "TextTrigger");
        }
        Json::Value@ ToJson() const {
            auto j = Json::Object();
            j["trigger"] = trigger.ToJson();
            // No separate 'text' field; name is used
            return j;
        }
        void DrawEditor(TextTriggersComponent@ cmp) {
            string oldName = trigger.name;
            trigger.name = UI::InputText("Text   \\$888Delimiter: |", trigger.name);
            AddSimpleTooltip("Use '|' to separate different options for the text. One will be chosen at random.");
            if (trigger.name != oldName && cmp !is null) cmp.OnDirty();
            trigger.DrawEditorUI();
        }
        void DrawNvgBox() {
            trigger.DrawNvgBox();
        }
        // Helper to get lines as array
        array<string> GetLines() const {
            return trigger.name.Split("|");
        }
    }

    class TextTriggersComponent : ProjectComponent {
        array<TextTrigger@> m_triggers;
        int editingIx = -1;
        TextTrigger@ triggerToDraw = null;

        TextTriggersComponent(const string &in jsonPath, ProjectMeta@ meta) {
            super(jsonPath, meta);
            name = "Text Triggers";
            icon = Icons::Comment;
            type = EProjectComponent::TextTriggers;
            thisTabClickRequiresTestPlaceMode = true;
        }

        uint get_nbTriggers() const { return m_triggers.Length; }
        TextTrigger@ getTrigger(uint i) const { return m_triggers[i]; }
        void setTrigger(uint i, TextTrigger@ t) { @m_triggers[i] = t; OnDirty(); }

        void TryLoadingJson(const string&in jFName) override {
            ProjectComponent::TryLoadingJson(jFName);
            m_triggers.RemoveRange(0, m_triggers.Length);
            if (ro_data.HasKey("triggers") && ro_data["triggers"].GetType() == Json::Type::Array) {
                auto arr = ro_data["triggers"];
                for (uint i = 0; i < arr.Length; i++) {
                    m_triggers.InsertLast(TextTrigger(arr[i]));
                }
            }
        }

        void CreateDefaultJsonObject() override {
            auto j = Json::Object();
            j["triggers"] = Json::Array();
            rw_data = j;
            m_triggers.RemoveRange(0, m_triggers.Length);
        }

        void SaveToFile() override {
            auto arr = Json::Array();
            for (uint i = 0; i < m_triggers.Length; i++) {
                arr.Add(m_triggers[i].ToJson());
            }
            rw_data["triggers"] = arr;
            ProjectComponent::SaveToFile();
            editingIx = -1;
        }

        int PushTrigger(TextTrigger@ t) {
            m_triggers.InsertLast(t);
            OnDirty();
            return int(m_triggers.Length - 1);
        }

        void DrawComponentInner(ProjectTab@ pTab) override {
            if (editingIx >= int(nbTriggers)) {
                NotifyWarning("Invalid text trigger index: " + editingIx);
                editingIx = -1;
            }
            DrawSelectedTriggerBox();
            if (editingIx == -1) {
                DrawHeader();
                if (editingIx == -1) {
                    UI::Separator();
                    DrawTriggersList();
                }
            } else {
                DrawEditTrigger();
            }
        }

        void DrawHeader() {
            if (UI::Button(Icons::Plus + " Add Text Trigger")) {
                OnCreateNewTrigger();
            }
        }

        void DrawEditTrigger() {
            bool clickedEnd = false;
            UI::PushID("ttEdit" + editingIx);
            auto t = getTrigger(editingIx);
            UI::AlignTextToFramePadding();
            UI::Text("Editing Text Trigger: " + editingIx);
            UI::SameLine();
            auto pos1 = UI::GetCursorPos();
            if (UI::Button(Icons::Check + " Done")) {
                clickedEnd = true;
            }
            UI::SameLine();
            auto saveWidth = UI::GetCursorPos().x - pos1.x;
            auto avail = UI::GetContentRegionAvail();
            UI::Dummy(vec2(Math::Max(0.0, avail.x - saveWidth - 12 * g_scale), 0));
            UI::SameLine();
            if (UI::Button(Icons::TrashO + " Delete")) {
                startnew(CoroutineFuncUserdataInt64(OnDeleteTrigger), editingIx);
            }
            UI::Separator();
            t.DrawEditor(this);
            setTrigger(editingIx, t);
            OnDirty(); // Mark dirty after editing
            UI::PopID();
            if (clickedEnd) {
                editingIx = -1;
            }
        }

        void DrawTriggersList() {
            UI::Text("# Text Triggers: " + nbTriggers);
            UI::Separator();
            UI::BeginChild("ttlist");
            UI::BeginTable("TextTriggers", 3, UI::TableFlags::SizingStretchProp);
            UI::TableSetupColumn("Text", UI::TableColumnFlags::WidthStretch);
            UI::TableSetupColumn("Position", UI::TableColumnFlags::WidthStretch);
            UI::TableSetupColumn("Actions", UI::TableColumnFlags::WidthFixed);
            UI::TableHeadersRow();
            for (uint i = 0; i < nbTriggers; i++) {
                UI::PushID("tt" + i);
                auto t = getTrigger(i);
                UI::TableNextRow();
                UI::TableNextColumn();
                UI::AlignTextToFramePadding();
                UI::TextWrapped(t.trigger.name);
                UI::TableNextColumn();
                UI::Text(t.trigger.PosStr());
                UI::SameLine();
                if (UI::Button(Icons::Crosshairs + " Show")) {
                    OnSetTriggerToDraw(t);
                }
                UI::TableNextColumn();
                if (UI::Button(Icons::Pencil + " Edit")) {
                    editingIx = i;
                    OnSetTriggerToDraw(t);
                }
                UI::PopID();
            }
            UI::EndTable();
            UI::EndChild();
        }

        void DrawSelectedTriggerBox() {
            if (editingIx != -1) @triggerToDraw = getTrigger(editingIx);
            if (triggerToDraw is null) return;
            triggerToDraw.DrawNvgBox();
        }

        void OnSetTriggerToDraw(TextTrigger@ t, bool focusCamera = true) {
            @triggerToDraw = t;
            if (focusCamera) {
                SetEditorCameraToPos(t.trigger.posBottomCenter, t.trigger.size.Length() * 4.0);
            }
        }

        void OnDeleteTrigger(int64 i) {
            if (i >= int64(nbTriggers)) return;
            m_triggers.RemoveAt(i);
            editingIx = -1;
            OnDirty();
            SaveToFile();
        }

        void OnCreateNewTrigger() {
            auto t = TextTrigger();
            editingIx = PushTrigger(t);
            OnSetTriggerToDraw(t, false);
            OnDirty();
        }

        void OnMouseClick(int x, int y, int button) override {
            HandleGlobalTriggerMouseClick();
        }
    }
}
