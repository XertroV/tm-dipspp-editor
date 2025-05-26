namespace CM_Editor {

    // MARK: VoiceLines Cmpnt

    const vec3 DEFAULT_MT_SIZE = vec3(10.6666667, 8, 10.6666667);
    const vec3 DEFAULT_VL_POS = vec3(32, 8, 32) - vec3(10.6666667, 0, 10.6666667) * 0.5;

    // --- EditableTrigger class ---
    funcdef void EditableTriggerCallback(EditableTrigger@ trig);
    class EditableTrigger {
        vec3 posBottomCenter;
        vec3 size;
        bool isEditing = false;
        string label;
        EditableTriggerCallback@ onEditDone;

        EditableTrigger(const vec3 &in pos = DEFAULT_VL_POS, const vec3 &in size_ = DEFAULT_MT_SIZE, const string &in label_ = "Trigger") {
            posBottomCenter = pos;
            size = size_;
            label = label_;
        }
        EditableTrigger(const Json::Value@ j, const vec3 &in defaultPos = DEFAULT_VL_POS, const vec3 &in defaultSize = DEFAULT_MT_SIZE, const string &in label_ = "Trigger") {
            if (j is null) {
                posBottomCenter = defaultPos;
                size = defaultSize;
            } else {
                posBottomCenter = JsonToVec3(j.Get("pos", Json::Value()), defaultPos);
                size = JsonToVec3(j.Get("size", Json::Value()), defaultSize);
            }
            label = label_;
        }
        Json::Value@ ToJson() const {
            auto j = Json::Object();
            j["pos"] = Vec3ToJson(posBottomCenter);
            j["size"] = Vec3ToJson(size);
            return j;
        }
        vec3 get_posMin() const {
            return posBottomCenter - size * vec3(0.5, 0, 0.5);
        }
        string PosStr() const {
            return "< " + posBottomCenter.x + ", " + posBottomCenter.y + ", " + posBottomCenter.z + " >";
        }
        void DrawNvgBox(const vec4 &in color = cOrange) const {
            nvgDrawWorldBox(get_posMin(), size, color);
        }
        void DrawEditorUI() {
            if (isEditing) {
                posBottomCenter = GetEditorItemCursorPos() - vec3(0, 0.5, 0);
                UI::BeginDisabled();
                UI::InputFloat3("Position##pos", posBottomCenter, "%.3f", UI::InputTextFlags::ReadOnly);
                UI::EndDisabled();
                DrawInstructionText("Place Car at Trigger Location", true);
            } else {
                posBottomCenter = UI::InputFloat3("Position##pos", posBottomCenter);
            }
            UI::SameLine();
            if (UI::Button(Icons::PencilSquareO + " Set##" + label)) {
                StartTriggerEdit();
            }
            size = UI::InputFloat3("Size##size", size);
            if (UI::Button(Icons::Eye + " Show##" + label)) {
                SetEditorCameraToPos(posBottomCenter);
            }
        }
        void OnMouseClick() {
            NotifyWarning("EditableTrigger OnMouseClick");
            if (isEditing) {
                isEditing = false;
                startnew(RestoreEditorMode);
                if (onEditDone !is null) onEditDone(this);
            }
        }

        void StartTriggerEdit() {
            @g_CurrentEditableTrigger = this;
            g_InterceptOnMouseClick = true;
            g_InterceptClickRequiresTestMode = true;
            isEditing = true;
            startnew(SetEditorToTestMode);
        }
    }

    void HandleGlobalTriggerMouseClick() {
        if (g_CurrentEditableTrigger !is null && g_CurrentEditableTrigger.isEditing) {
            startnew(CoroutineFunc(g_CurrentEditableTrigger.OnMouseClick));
        }
        @g_CurrentEditableTrigger = null;
    }
}
