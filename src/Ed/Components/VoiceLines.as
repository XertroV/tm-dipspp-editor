namespace CM_Editor {

    // MARK: VoiceLines Cmpnt

    class VoiceLineEl {
        string file;
        string subtitles;
        string imageAsset;
        int subtitleParts = 0;
        EditableTrigger@ trigger;

        VoiceLineEl() {
            @trigger = EditableTrigger(DEFAULT_VL_POS, DEFAULT_MT_SIZE, "VL");
        }
        VoiceLineEl(const Json::Value@ j) {
            file = j.Get("file", "");
            subtitles = j.Get("subtitles", "");
            imageAsset = j.Get("imageAsset", "");
            @trigger = EditableTrigger(j.Get("trigger", Json::Value()), DEFAULT_VL_POS, DEFAULT_MT_SIZE, "VL");
            subtitleParts = subtitles.Split("\n").Length;
        }
        vec3 get_posMin() const { return trigger.get_posMin(); }
        Json::Value ToJson() {
            auto j = Json::Object();
            j["file"] = file;
            j["subtitles"] = subtitles;
            j["imageAsset"] = imageAsset;
            j["trigger"] = trigger.ToJson();
            return j;
        }
        string PosStr() const { return trigger.PosStr(); }
        void DrawEditor(ProjectVoiceLinesComponent@ cmp, ProjectTab@ pTab) {
            bool changedFile = false, changedSubtitles = false;
            string fullUrl = pTab.GetUrlPrefix() + file;

            file = pTab.AssetBrowser("Audio File", file, AssetTy::Audio);
            // file = UI::InputText("File", file, changedFile);
            UI::SameLine();
            if (UI::Button(Icons::Download + " Test")) {
                OpenBrowserURL(fullUrl);
            }
            AddSimpleTooltip("Full URL: " + fullUrl);

            if (file.EndsWith(".mp3") && file.Length > 4) {
                UI::Text(BoolIcon(true) + " file name looks good.");
            } else {
                UI::Text(BoolIcon(false) + " file name should be an .mp3 file. (It is appended to UrlPrefix)");
            }

            UI::Separator();

            UI::Text("Subtitles:");
            subtitles = UI::InputTextMultiline("##subtitles", subtitles, changedSubtitles, vec2(300, 100));
            DrawSameLineSubtitlesHelper();
            UI::Text("Subtitle Parts: " + subtitleParts);

            if (subtitles.Length > 0) {
                if (!subtitles.StartsWith("0:")) UI::Text(BoolIcon(false) + " Subtitles should start at t = 0. (First line should start with \"0:\")");
            }

            imageAsset = pTab.AssetBrowser("Speaker Image", imageAsset, AssetTy::Image);
            // imageAsset = UI::InputText("Speaker Image", imageAsset);
            // auto assetsComp = pTab.GetAssetsComponent();
            // UI::AlignTextToFramePadding();
            // if (assetsComp.HasImageAsset(imageAsset)) {
            //     UI::Text(BoolIcon(true) + " Image asset found.");
            // } else if (imageAsset.Length > 0) {
            //     UI::Text(BoolIcon(false) + " Image asset not found.");
            //     UI::SameLine();
            //     if (UI::Button(Icons::Plus + " Add Image Asset")) {
            //         assetsComp.AddImageAsset(imageAsset);
            //         assetsComp.SaveToFile();
            //     }
            // }

            UI::Separator();

            trigger.DrawEditorUI();

            UI::Separator();
            UI::Text("Hints:");
            UI::TextWrapped("- Make sure the bottom of the trigger is on the ground (or slightly below it).");
            UI::TextWrapped("- The mediatracker trigger size is 10.667 x 8 x 10.667");
        }

        void OnClickSetPos(ProjectVoiceLinesComponent@ cmp) {
            startnew(SetEditorToTestMode);
            cmp.OnSelfAwaitingMouseClick();
        }

        void DrawSameLineSubtitlesHelper() {
            UI::SameLine();
            UI::AlignTextToFramePadding();
            UI::Text(Icons::InfoCircle);
            bool circleClicked = UI::IsItemClicked(UI::MouseButton::Left);
            AddSimpleTooltip(SUBTITLES_HELP);
            if (circleClicked) OpenBrowserURL("https://github.com/XertroV/tm-dips-plus-plus/blob/0d481094ef9fabb2095f93f853d841604ffaf35f/remote_assets/secret/subs-3948765.txt");
        }
    }

    const string SUBTITLES_HELP = "# Subtitles Help\n\n"
        "Line format: `<startTime_ms>: <text>`\n"
        "Example: `500: Before you continue,`\n"
        "- Starts at 0.5 seconds\n"
        "- Text shown: \"Before you continue,\"\n\n"
        + Icons::ExclamationCircle + " Also: put an empty subtitle line at the end to better control fade out timing.\n\n"
        "Click to open an example subtitles file in the browser.\n";

    class ProjectVoiceLinesComponent : ProjectComponent {
        array<VoiceLineEl@> m_voiceLines;

        ProjectVoiceLinesComponent(const string &in jsonPath, ProjectMeta@ meta) {
            super(jsonPath, meta);
            name = "Voice Lines";
            icon = Icons::CommentO;
            type = EProjectComponent::VoiceLines;
            thisTabClickRequiresTestPlaceMode = true;
        }

        // proxy methods for data access (px = proxy)
        uint get_nbLines() const { return m_voiceLines.Length; }
        VoiceLineEl@ getLine(uint i) const { return m_voiceLines[i]; }
        void setLine(uint i, VoiceLineEl@ vl) { @m_voiceLines[i] = vl; }

        void TryLoadingJson(const string&in jFName) override {
            ProjectComponent::TryLoadingJson(jFName);
            m_voiceLines.RemoveRange(0, m_voiceLines.Length);
            if (ro_data.HasKey("lines") && ro_data["lines"].GetType() == Json::Type::Array) {
                auto arr = ro_data["lines"];
                for (uint i = 0; i < arr.Length; i++) {
                    m_voiceLines.InsertLast(VoiceLineEl(arr[i]));
                }
            }
        }

        int PushVoiceLine(VoiceLineEl@ vl) {
            m_voiceLines.InsertLast(vl);
            return int(m_voiceLines.Length - 1);
        }

        void CreateDefaultJsonObject() override {
            auto j = Json::Object();
            j["lines"] = Json::Array();
            j["urlPrefix"] = "";
            rw_data = j;
            m_voiceLines.RemoveRange(0, m_voiceLines.Length);
        }

        void SaveToFile() override {
            // Serialize m_voiceLines to json
            auto arr = Json::Array();
            for (uint i = 0; i < m_voiceLines.Length; i++) {
                arr.Add(m_voiceLines[i].ToJson());
            }
            rw_data["lines"] = arr;
            ProjectComponent::SaveToFile();
            editingVL = -1;
        }

        void DrawComponentInner(ProjectTab@ pTab) override {
            if (editingVL >= int(nbLines)) {
                NotifyWarning("Invalid voice line index: " + editingVL);
                editingVL = -1;
            }
            DrawSelectedVLBox();
            // if not editing, show header
            if (editingVL == -1) {
                DrawHeader();
                // if still not editing, draw VLs
                if (editingVL == -1) {
                    UI::Separator();
                    DrawVoiceLines(pTab.GetUrlPrefix());
                }
            } else {
                // only draw editing if it was not set this frame to avoid flicker
                DrawEditVoiceLine(pTab);
            }
        }

        void DrawSelectedVLBox() {
            if (editingVL != -1) @vlToDraw = getLine(editingVL);
            if (vlToDraw is null) return;
            vlToDraw.trigger.DrawNvgBox();
        }

        int editingVL = -1;
        VoiceLineEl@ vlToDraw = null;

        void DrawHeader() {
            if (UI::Button(Icons::Plus + " Add Voice Line")) {
                OnCreateNewVoiceLine();
            }
        }

        void DrawEditVoiceLine(ProjectTab@ pTab) {
            bool clickedEnd = false;
            UI::PushID("vlEdit" + editingVL);
            auto vl = getLine(editingVL);

            UI::AlignTextToFramePadding();
            UI::Text("Editing VL: " + editingVL);

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
            // UI::BeginDisabled(!UI::IsKeyDown(UI::Key::LeftShift));
            if (UI::Button(Icons::TrashO + " Delete")) {
                startnew(CoroutineFuncUserdataInt64(OnDeleteVoiceLine), editingVL);
            }
            // UI::EndDisabled();

            UI::Separator();

            vl.DrawEditor(this, pTab);
            setLine(editingVL, vl);

            UI::PopID();

            if (clickedEnd) {
                editingVL = -1;
            }
        }

        void OnDeleteVoiceLine(int64 i) {
            if (i >= int64(nbLines)) return;
            m_voiceLines.RemoveAt(i);
            editingVL = -1;
            SaveToFile();
        }

        void OnCreateNewVoiceLine() {
            auto vl = VoiceLineEl();
            editingVL = PushVoiceLine(vl);
            OnSetVoiceLineToDraw(vl, false);
        }

        void DrawVoiceLines(const string &in urlPrefix) {
            UI::Text("# Voice Lines: " + nbLines);
            UI::Separator();
            UI::BeginChild("vl");

            UI::BeginTable("Voice Lines", 4, UI::TableFlags::SizingStretchProp);
            UI::TableSetupColumn("File", UI::TableColumnFlags::WidthStretch);
            UI::TableSetupColumn("Has Subtitles", UI::TableColumnFlags::WidthStretch);
            UI::TableSetupColumn("Position", UI::TableColumnFlags::WidthStretch);
            UI::TableSetupColumn("Actions", UI::TableColumnFlags::WidthFixed);
            UI::TableHeadersRow();

            for (uint i = 0; i < nbLines; i++) {
                UI::PushID("vl" + i);
                auto vl = getLine(i);
                string fullUrl = urlPrefix + vl.file;
                UI::TableNextRow();
                UI::TableNextColumn();
                UI::AlignTextToFramePadding();
                UI::Text(vl.file.Length > 0 ? vl.file : "\\$i\\$aaaNo file name");
                UI::SameLine();
                if (UI::Button(Icons::Download + " Test URL")) {
                    OpenBrowserURL(fullUrl);
                }
                AddSimpleTooltip(fullUrl);

                UI::TableNextColumn();
                UI::Text(BoolIcon(vl.subtitles.Length > 0) + " / parts: " + vl.subtitleParts);
                AddSimpleTooltip("Subtitles:\n" + vl.subtitles);

                UI::TableNextColumn();
                UI::Text(vl.PosStr());
                UI::SameLine();
                if (UI::Button(Icons::Crosshairs + " Show")) {
                    OnSetVoiceLineToDraw(vl);
                }

                UI::TableNextColumn();
                if (UI::Button(Icons::Pencil + " Edit")) {
                    editingVL = i;
                    OnSetVoiceLineToDraw(vl);
                }
                UI::PopID();
            }

            UI::EndTable();
            UI::EndChild();
        }


        void OnSetVoiceLineToDraw(VoiceLineEl@ vl, bool focusCamera = true) {
            @vlToDraw = vl;
            if (focusCamera) {
                SetEditorCameraToPos(vl.trigger.posBottomCenter, vl.trigger.size.Length() * 4.0);
            }
        }

        void OnMouseClick(int x, int y, int button) override {
            HandleGlobalTriggerMouseClick();
        }
    }

}
