namespace CM_Editor {

    const vec3 DEFAULT_MT_SIZE = vec3(10.6666667, 8, 10.6666667);
    const vec3 DEFAULT_VL_POS = vec3(32, 8, 32) - vec3(10.6666667, 0, 10.6666667) * 0.5;

    // MARK EditableTrigger
    funcdef void EditableTriggerCallback(EditableTrigger@ trig);
    class EditableTrigger {
        vec3 posBottomCenter;
        vec3 size;
        bool isEditing = false;
        string label;
        string name;
        EditableTriggerCallback@ onEditDone;

        EditableTrigger(const vec3 &in pos = DEFAULT_VL_POS, const vec3 &in size_ = DEFAULT_MT_SIZE, const string &in label_ = "Trigger", const string &in name_ = "") {
            posBottomCenter = pos;
            size = size_;
            label = label_;
            name = name_;
        }
        EditableTrigger(const Json::Value@ j, const vec3 &in defaultPos = DEFAULT_VL_POS, const vec3 &in defaultSize = DEFAULT_MT_SIZE, const string &in label_ = "Trigger") {
            if (j is null) {
                posBottomCenter = defaultPos;
                size = defaultSize;
                name = "";
            } else {
                posBottomCenter = JsonToVec3(j.Get("pos", Json::Value()), defaultPos);
                size = JsonToVec3(j.Get("size", Json::Value()), defaultSize);
                name = j.Get("name", "");
            }
            label = label_;
        }
        Json::Value@ ToJson() const {
            auto j = Json::Object();
            j["pos"] = Vec3ToJson(posBottomCenter);
            j["size"] = Vec3ToJson(size);
            j["name"] = name;
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
            // Draw the trigger's name above the box
            vec3 textPos = posBottomCenter + vec3(0, size.y * .5, 0); // middle
            vec3 screenPos = Camera::ToScreen(textPos);
            if (screenPos.z < 0) {
                nvg::TextAlign(nvg::Align::Center | nvg::Align::Middle);
                nvg::FontSize(32. * g_screen.y / 1440.0);
                nvgDrawTextWithStroke(screenPos.xy, name.Length > 0 ? name : label, cOrange);
            }
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
