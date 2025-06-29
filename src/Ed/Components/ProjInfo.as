namespace CM_Editor {
    // MARK: Proj Info Cmpnt

    class ProjectInfoComponent : ProjectComponent {
        UrlChecks@ allUrlChecks = UrlChecks();
        WizardTabs@ finalizationWizard = WizardTabs();

        ProjectInfoComponent(const string &in jsonPath, ProjectMeta@ meta) {
            super(jsonPath, meta);
            name = "Project Info";
            icon = Icons::InfoCircle;
            type = EProjectComponent::Info;
            canInitFromDipsSpecComment = true;
            allUrlChecks.SetStale();
            SetUpWizardTabs();
        }

        string get_ComponentTitleName() override property {
            return name + ": " + meta.name;
        }

        // proxy methods for data access
        string get_px_minClientVersion() { return ro_data.Get("minClientVersion", ""); }
        void set_px_minClientVersion(const string &in v) { rw_data["minClientVersion"] = v; }
        string get_px_url() { return ro_data.Get("url", ""); }
        void set_px_url(const string &in v) { rw_data["url"] = v; }
        string get_UrlPrefix() const { return ro_data.Get("urlPrefix", ""); }
        void set_UrlPrefix(const string &in v) { rw_data["urlPrefix"] = v; }
        string get_NameId() const { return ro_data.Get("nameId", ""); }
        void set_NameId(const string &in v) { rw_data["nameId"] = v; }

        void CreateDefaultJsonObject() override {
            auto j = Json::Object();
            j["minClientVersion"] = "0.0.0";
            j["nameId"] = "my-first-custom-map";
            // j["url"] = "";
            rw_data = j;
        }

        void CreateJsonDataFromComment(DipsSpec@ spec) override {
            CreateDefaultJsonObject();
            px_minClientVersion = spec.minClientVersion;
            px_url = spec.url;
        }

        void OnDirty() override {
            ProjectComponent::OnDirty();
            SetUrlChecksStale();
            _wiz_generatedDipsSpec = "";
        }

        void SetUrlChecksStale() {
            allUrlChecks.SetStale();
        }

        void DrawComponentInner(ProjectTab@ pTab) override {
            auto fc = pTab.GetFloorsComponent();
            UI::Text("Tower Floors: " + fc.nbFloors);
            UI::Columns(3, "", false);
            for (uint i = uint(EProjectComponent::Info) + 1; i < uint(EProjectComponent::_LAST); i++) {
                DrawHasComponent(EProjectComponent(i), pTab);
                UI::NextColumn();
            }
            UI::Columns(1);


            DrawAssetsEtcSection(pTab);

            UI::PushFont(UI::Font::Default20);
            UI::SeparatorText(" F I N A L I Z A T I O N ");
            UI::PopFont();

            DrawFinalizationWizard(pTab);
            return;

            UI::SeparatorText("Finalize & Upload");
            //

            bool changedMCV = false, changedURL = false;

            auto newMCV = UI::InputText("Min Client Version (optional)", px_minClientVersion, changedMCV);
            AddSimpleTooltip("Default: empty or '0.0.0'. This field can prevent Dips++ clients with a lower version from automatically working with the map.");
            if (changedMCV) px_minClientVersion = newMCV;
            if (newMCV.Length > 0 && newMCV != "0.0.0") {
                if (!MapCustomInfo::CheckMinClientVersion(newMCV)) {
                    UI::Text(BoolIcon(false) + " Version newer than plugin version!");
                }
            }



            UI::Text("\\$f80 TODO: the below is not implemented yet.");

            if (UI::Button(Icons::Upload + " Upload Spec")) {
                px_url = "Loading...";
                // run request and populate URL
            }
            string newUrl = UI::InputText("JSON URL (Final Step)", px_url, changedURL);
            if (newUrl.Length > 0) DrawValidationMsgsJsonUrl(newUrl);
            if (changedURL) px_url = newUrl;

            // if (UI::CollapsingHeader("Advanced")) {
            //     auto newUrl = UI::InputText("URL (optional)", px_url, changedURL);
            //     AddSimpleTooltip("Default: empty. Reserved for future use.");
            //     if (changedURL) px_url = newUrl;
            // }

            // UI::Separator();

        }

        // TEMPORARY reference (we don't want to keep it around to avoid GC failing)
        private ProjectTab@ pTabForWiz;

        void DrawFinalizationWizard(ProjectTab@ pTab) {
            // must unset this after use.
            @pTabForWiz = pTab;
            finalizationWizard.Draw();
            @pTabForWiz = null;
        }

        void DrawAssetsEtcSection(ProjectTab@ pTab) {
            UI::SeparatorText("Assets and Voice Lines");

            if (UI::CollapsingHeader("Base URL Help")) {
                UI::TextWrapped("The Base URL is the root web address where all your project's assets (audio, images, etc.) and voice lines will be loaded from. This should be a stable, public HTTPS URL, ending with a slash ('/'). All asset file names you specify elsewhere will be appended to this base URL.\n\nFor example, if your Base URL is 'https://assets.xk.io/custom/blah/', and you set a voice line file to 'intro.mp3', the full URL will be 'https://assets.xk.io/custom/blah/intro.mp3'.\n\nIf you need hosting, contact XertroV or use the Dashmap option below.\n\nTip: Make sure your assets are uploaded to this location before finalizing your project.");
            }

            bool changed = false;
            auto newUP = UI::InputText("Base URL (for VLs/Assets)", UrlPrefix, changed);
            AddSimpleTooltip("All assets should be hosted under this URL.\nMessage XertroV if you need things hosted.\nExample: 'https://assets.xk.io/custom/blah/'\n\n- Must start with 'https://'.\n- Must end with '/'.\n- All asset and voice line file names are appended to this base URL.");
            if (changed) UrlPrefix = newUP;

            if (newUP.Contains("https://download.dashmap.live")) {
                UI::SameLine();
                UI::TextLinkOpenURL("https://dashmap.live", "https://dashmap.live/");
            }

            if (newUP.Length == 0) {
                UI::Text(BoolIcon(false) + " Base URL is empty!");
                if (UI::Button("Use Dashmap?")) {
                    newUP = "https://download.dashmap.live/" + LocalUserWSID() + "/";
                    UrlPrefix = newUP;
                }
                UI::SameLine();
                UI::Text("\\$i(Recommended)");
            } else if (!newUP.EndsWith("/")) {
                UI::Text(BoolIcon(false) + " Base URL must end with a slash ('/')");
            } else if (!newUP.StartsWith("https://")) {
                UI::Text(BoolIcon(false) + " Base URL must start with 'https://'");
            } else {
                // UI::SeparatorText("\\$i\\$afc  · • —– ٠ Check VLs & Assets ٠ –— • ·  ");
                UI::TextWrapped("Base URL looks good! " + BoolIcon(true));
                // DrawUrlCheckSection(pTab);
            }

        }

        void DrawHasComponent(EProjectComponent ty, ProjectTab@ pTab) {
            if (ty == EProjectComponent::Minigames) return;
            auto comp = pTab.GetComponentByType(ty);
            UI::Text(BoolIcon(comp is null ? false : comp.hasFile) + " " + ProjectComponentToString(ty));
        }

        void DrawValidationMsgsJsonUrl(const string &in url) {
            auto cross = BoolIcon(false);
            if (!url.StartsWith("https://")) UI::Text(cross + " URL must start with 'https://'");
            if (!url.EndsWith(".json")) UI::Text(cross + " URL must end with '.json'");
            if (url.Length < 10) UI::Text(cross + " URL must be at least 10 characters");
        }

        void DrawUrlCheckSection(ProjectTab@ pTab) {
            UI::AlignTextToFramePadding();
            UI::Text("All URLs: " + BoolIcon(DidAllUrlChecksPass()));
            UI::SameLine();
            UI::BeginDisabled(allUrlChecks.isRunning);
            if (UI::Button(Icons::Check + " Check All URLs")) StartCheckAllUrls(pTab);
            UI::SameLine();
            if (UI::Button(Icons::Refresh + " Clear Cached Good URLs")) UrlCache::ClearAll();
            UI::EndDisabled();
            if (allUrlChecks.isRunning && allUrlChecks.isStale) {
                UI::SameLine();
                if (UI::ButtonColored(Icons::Stop + " Stop Checking", 0.08, .5, .5)) {
                    allUrlChecks.StopRun();
                }
            }
            if (!allUrlChecks.isStale) {
                UI::SameLine();
                UI::Text(allUrlChecks.StatusText());
            }

            if (allUrlChecks.isRunning) {
                allUrlChecks.DrawProgressBars();
            }

            if (allUrlChecks.FailedUrls.Length > 0) {
                if (UI::CollapsingHeader("Failed URLs##")) {
                    uint baseUrlLen = UrlPrefix.Length;
                    UI::BeginChild("FailedAllUrls", vec2(0, 200), true);
                    for (uint i = 0; i < allUrlChecks.FailedUrls.Length; i++) {
                        UX::CopyableText(Text::Format("%3d. ", i + 1) + "\\$<\\$888<BaseURL>/\\$>" + allUrlChecks.FailedUrls[i].SubStr(baseUrlLen));
                    }
                    UI::EndChild();
                }
            }
        }

        bool DidAllUrlChecksPass() {
            if (allUrlChecks.isStale) return false;
            if (allUrlChecks.isRunning) return false;
            return allUrlChecks.Passes(allUrlChecks.nbTotal);
        }

        void StartCheckAllUrls(ProjectTab@ pTab) {
            if (allUrlChecks.isRunning) return;
            allUrlChecks.Reset();
            auto urlPrefix = pTab.GetUrlPrefix();

            // Add voice line URLs
            auto vlComp = pTab.GetVoiceLinesComponent();
            if (vlComp !is null) {
                for (uint i = 0; i < vlComp.m_voiceLines.Length; i++) {
                    auto vl = vlComp.m_voiceLines[i];
                    allUrlChecks.AddUrlCheck(urlPrefix + vl.file);
                }
            }

            // Add asset URLs
            auto assetsComp = pTab.GetAssetsComponent();
            if (assetsComp !is null) {
                for (uint i = 0; i < assetsComp.images.categories.Length; i++) {
                    auto cat = assetsComp.images.categories[i];
                    for (uint j = 0; j < cat.assets.files.Length; j++) {
                        allUrlChecks.AddUrlCheck(urlPrefix + cat.assets.files[j]);
                    }
                }
                for (uint i = 0; i < assetsComp.audios.categories.Length; i++) {
                    auto cat = assetsComp.audios.categories[i];
                    for (uint j = 0; j < cat.assets.files.Length; j++) {
                        allUrlChecks.AddUrlCheck(urlPrefix + cat.assets.files[j]);
                    }
                }
            }
            allUrlChecks.StartRun();
        }


        uint wTabIx_Prep, wTabIx_MapComment, wTabIx_Done, wTabIx_Adv1Conf, wTabIx_Adv2Url,
            wTabIx_PreUpload, wTabIx_ConfirmUpload;

        protected void SetUpWizardTabs() {
            if (finalizationWizard.nbTabs > 0) return; // already set up
            wTabIx_Prep = finalizationWizard.AddTab("Final Prep", CoroutineFunc(this.FinWiz_10_InitialPrep), Icons::ListOl);
            // - if yes -> go to Map Comment step
            // - otherwise -> go through all steps
            // Adv1: set min version -- must be at least 0.5.5 to support the new custom map aux spec. set name_id too
            wTabIx_Adv1Conf = finalizationWizard.AddTab("Advanced 1", CoroutineFunc(this.FinWiz_20_Advanced1), Icons::Cog);
            // Adv2: check asset URLs -- since assets are downloaded, all the URLs should work. (The user can move on if they know what they're doing).
            wTabIx_Adv2Url = finalizationWizard.AddTab("URL Checks", CoroutineFunc(this.FinWiz_30_CheckUrls), Icons::Link);
            wTabIx_PreUpload = finalizationWizard.AddTab("Upload JSON", CoroutineFunc(this.FinWiz_40_PreUpload), Icons::Upload);
            wTabIx_ConfirmUpload = finalizationWizard.AddTab("Confirm Upload", CoroutineFunc(this.FinWiz_50_ConfirmUpload), Icons::CloudUpload);


            // penultimate step
            wTabIx_MapComment = finalizationWizard.AddTab("Map Comment", CoroutineFunc(this.FinWiz_90_SetMapComment), Icons::Comment);
            // last step
            wTabIx_Done = finalizationWizard.AddTab("Done!", CoroutineFunc(this.FinWiz_99_Done), Icons::CheckCircle);
        }

        void FinWiz_10_InitialPrep() {
            _wiz_generatedDipsSpec = ""; // on any tab before map comment tab, we reset this
            @_wiz_generatedJsonObject = null;
            _wiz_generatedJsonString = "";

            UI::AlignTextToFramePadding();
            UI::Text("Finalization: Preparation");
            UI::SeparatorText("");

            UI::AlignTextToFramePadding();
            UI::TextWrapped("Choose how you want to finalize your map for Dips++:");

            UX::BulletText("Simple: Only use the map comment (no JSON upload, just heights/labels). Best for basic towers.");
            UX::BulletText("Advanced: Upload a full JSON spec (supports voice lines, triggers, and other features).");

            UI::SeparatorText("\\$i\\$afc  · • —– ٠ Choose Workflow ٠ –— • ·  ");
            // Choice buttons
            if (UI::ButtonColored("Use Simple Workflow (Map Comment Only)", 0.4, .5, .4)) {
                finalizationWizard.JumpToTab(wTabIx_MapComment);
                SaveAllProjectTabs();
            }
            UI::SameLine();
            if (UI::ButtonColored("Use Advanced Workflow (JSON Upload)", 0.80)) {
                finalizationWizard.ResetToOrPushTab(finalizationWizard.currentTab + 1); // go to next step
                SaveAllProjectTabs();
            }
            finalizationWizard.SkipNextBackFwdButtons();

            // invalidate json url
            if (px_url.Length > 0) px_url = ""; // reset URL if choosing workflow

            UI::SeparatorText("Review Floors");

            // Show summary of project floors
            auto fc = pTabForWiz.GetFloorsComponent();

            if (fc !is null && fc.nbFloors > 0) {
                UI::AlignTextToFramePadding();
                auto avail = UI::GetContentRegionAvail();
                uint colWidth = 160;
                uint cols = Math::Min(int(avail.x) / colWidth, 5);
                cols = cols < 1 ? 1 : cols; // at least 1 column
                auto maxPerCol = fc.nbFloors / cols + 1;
                uint max_rows = (fc.nbFloors + cols - 1) / cols; // ceil division
                UI::Text("> Project Floors: " + fc.nbFloors + " total  \\$888\\$i  (over " + cols + " columns, with " + maxPerCol + " max per column, and " + max_rows + " rows)");

                if (UI::BeginTable("floors", cols, UI::TableFlags::SizingFixedSame | UI::TableFlags::BordersV)) {
                    // setup widths
                    for (uint c = 0; c < cols; c++) {
                        UI::TableSetupColumn("col" + c, UI::TableColumnFlags::WidthFixed, colWidth);
                    }
                    // rows
                    for (uint row = 0; row < max_rows; row++) {
                        // UI::TableNextRow();
                        for (uint col = 0; col < cols; col++) {
                            UI::TableNextColumn();
                            if (max_rows * col + row >= fc.nbFloors) continue; // no more floors
                            uint floorIx;
                            auto f = fc.GetFloorForTablePos(cols, maxPerCol, row, col, floorIx);
                            if (f is null) {
                                UI::Text("\\$i\\$888" + floorIx);
                                continue; // no floor for this position
                            }
                            UI::Text("F."+ Text::Format("%02d", floorIx));
                            if (floorIx == 0) AddSimpleTooltip("Ground Floor aka. Floor Gang");
                            UI::SameLine();
                            UI::Text(Text::Format("@ %.2f m", f.height));
                            UI::SameLine();
                            UI::Text(f.name);
                        }
                    }
                    UI::EndTable();
                } else {
                    UI::Text("Failed to create floors table.");
                }
            } else {
                UI::Text(BoolIcon(false) + " No floors found.");
            }
        }

        void SaveAllProjectTabs() {
            pTabForWiz.SaveAll();
        }

        void FinWiz_20_Advanced1() {
            _wiz_generatedDipsSpec = "";
            @_wiz_generatedJsonObject = null;
            _wiz_generatedJsonString = "";

            UI::Text("Finalization: Confirm Advanced Config");
            UI::SeparatorText("");
            UI::AlignTextToFramePadding();
            UI::TextWrapped("To use advanced features, you must:");
            UX::BulletText("set the minimum client version to at least 0.5.5; and");
            UX::BulletText("set a unique Name ID for the hosted json file.");

            UI::Indent();
            UI::AlignTextToFramePadding();
            UI::TextWrapped("\\$888\\$iNote: Trying silly things with the name is a good way to get banned from Dips++.");
            UI::Unindent();

            UI::SeparatorText("");

            // Min Client Version
            string minClientVersion = get_px_minClientVersion();
            bool changedMCV = false;
            string newMCV = UI::InputText("Min Client Version (required: 0.5.5 or higher)", minClientVersion, changedMCV);
            AddSimpleTooltip("Set this to at least 0.5.5 to enable advanced features and JSON upload.");
            if (changedMCV) set_px_minClientVersion(newMCV);

            UI::AlignTextToFramePadding();
            bool mcvOk = false;
            if (newMCV.Length > 0) {
                mcvOk = MapCustomInfo::CheckMinClientVersion("0.5.5", newMCV);
                if (!mcvOk) {
                    UI::AlignTextToFramePadding();
                    UI::Text(BoolIcon(false) + " Min Client Version must be at least 0.5.5");
                    UI::SameLine();
                    if (UI::Button("Set to 0.5.5")) {
                        set_px_minClientVersion("0.5.5");
                        newMCV = "0.5.5"; // update input
                    }
                }
                else UI::Text(BoolIcon(true) + " Min Client Version looks good!");
            }

            UI::Dummy(vec2(0, 4));

            // Name ID
            string nameId = get_NameId();
            bool changedNameId = false;
            string newNameId = UI::InputText("Name ID (descriptive, no spaces)", nameId, changedNameId);
            AddSimpleTooltip("This is a unique identifier for your map. It should be short, lowercase, and contain only a-z, 0-9, -, and _. Example: 'my-first_custom-map1'");
            if (changedNameId) NameId = newNameId;
            bool nameRegexMatch = Regex::IsMatch(newNameId, "^[a-z0-9_-]+$");
            bool nameIdOk = nameRegexMatch && newNameId.Length > 0 && newNameId.Length < 32;
            // show error if bad
            UI::AlignTextToFramePadding();
            if (!nameIdOk) {
                if (newNameId.Length == 0) {
                    UI::Text(BoolIcon(false) + " Name ID cannot be empty");
                } else if (newNameId.Length > 32) {
                    UI::Text(BoolIcon(false) + " Name ID must be at most 32 characters");
                } else {
                    UI::Text(BoolIcon(false) + " Name ID must contain only a-z, 0-9, -, and _");
                }
            } else {
                UI::Text(BoolIcon(true) + " Name ID looks good! Filename will be: " + newNameId + ".json");
            }

            if (!mcvOk || !nameIdOk) {
                finalizationWizard.SetNextNavButtonDisabled();
            }
        }

        void FinWiz_30_CheckUrls() {
            _wiz_generatedDipsSpec = "";
            @_wiz_generatedJsonObject = null;
            _wiz_generatedJsonString = "";

            UI::AlignTextToFramePadding();
            UI::Text("Finalization: URL Checks");
            UI::SeparatorText("");

            bool checksPass = !allUrlChecks.isStale
                && !allUrlChecks.isRunning
                && allUrlChecks.Passes(allUrlChecks.nbTotal);

            DrawUrlCheckSection(pTabForWiz);

            UI::SeparatorText("");

            m_AllowSkippingUrlChecks = UI::Checkbox("\\$f80" + Icons::ExclamationTriangle + " \\$z Allow skipping URL checks", m_AllowSkippingUrlChecks);
            AddSimpleTooltip("Do NOT check this if you don't know what you are doing. It can mean broken assets for users.");

            // if all URLs are good, allow to continue
            if (!checksPass || !DidAllUrlChecksPass()) {
                finalizationWizard.SetNextNavButtonDisabled(!m_AllowSkippingUrlChecks);
            }
        }
        bool m_AllowSkippingUrlChecks = false;

        private Json::Value@ _wiz_generatedJsonObject = null;
        private string _wiz_generatedJsonString = "";

        void FinWiz_40_PreUpload() {
            UI::Text("Finalization: Upload JSON");
            UI::SeparatorText("");

            if (_wiz_generatedJsonObject is null) {
                @_wiz_generatedJsonObject = pTabForWiz.ToCombinedJson();
                _wiz_generatedJsonString = Json::Write(_wiz_generatedJsonObject, true);
            }

            UI::TextWrapped("The following JSON will be uploaded. You can inspect it here before uploading.");
            if (UI::Button(Icons::FilesO + " Copy to Clipboard")) {
                IO::SetClipboard(_wiz_generatedJsonString);
                Notify("Copied JSON to clipboard!");
            }
            UI::SameLine();
            if (UI::Button(Icons::Refresh + " Regenerate")) {
                @_wiz_generatedJsonObject = null;
                _wiz_generatedJsonString = "";
            }

            UI::InputTextMultiline("##json", _wiz_generatedJsonString, false, vec2(-1, 200), UI::InputTextFlags::ReadOnly);

            UI::SeparatorText("Upload");
            UI::AlignTextToFramePadding();
            UI::TextWrapped("Click the button below to upload the JSON to the Dips++ server. This will give you the URL to use in the next step.");
            UI::AlignTextToFramePadding();
            UI::TextWrapped("\\$ddd\\$iNote: you can update or delete this JSON (with this Name ID) for 24 hours after uploading it, but it becomes locked after that. You can always upload a new JSON with a different Name ID if you need to change it later.");

            UI::Dummy(vec2(0, 4));

            // Placeholder for your upload logic
            if (!_isUploadingJson && UI::Button("Upload JSON")) {
                // todo: check this is sufficient and captures everything we need
                startnew(CoroutineFunc(UploadJsonToDppServer));
            } else if (_isUploadingJson) {
                UI::Text("Uploading JSON to Dips++ server... " + UploadingJsonDuration() + " ms");
            }

            finalizationWizard.SetNextNavButtonDisabled(true);
        }

        bool _isUploadingJson = false;
        int64 _uploadStartTime = 0;
        void UploadJsonToDppServer() {
            auto @j = _wiz_generatedJsonObject;
            if (j is null) {
                NotifyError("No JSON to upload!");
                return;
            }
            string name_id = NameId;
            if (name_id.Length == 0) {
                NotifyError("Name ID is empty! Please set it in the Advanced 1 step.");
                return;
            }
            _isUploadingJson = true;
            _uploadStartTime = Time::Now;
            Notify("Uploading JSON to Dips++ server...");
            auto w = MyAuxSpecs::Report_Async(name_id, j);
            if (!w.IsSuccess()) {
                NotifyError("Failed to upload JSON: " + w.GetError());
                _ResetUploadState();
                return;
            }
            string uploaded_url = "https://dips-plus-plus.xk.io/aux_spec/" + LocalUserWSID() + "/" + name_id + ".json";
            px_url = uploaded_url; // set the URL in the project info
            NotifySuccess("JSON uploaded successfully! URL: " + uploaded_url);
            _ResetUploadState();
            // Move to the next step
            finalizationWizard.ResetToOrPushTab(wTabIx_ConfirmUpload);
        }

        void _ResetUploadState() {
            _isUploadingJson = false;
            _uploadStartTime = 0;
        }

        int64 UploadingJsonDuration() {
            if (_uploadStartTime == 0) return 0;
            return Time::Now - _uploadStartTime;
        }

        void FinWiz_50_ConfirmUpload() {
            UI::Text("Finalization: Confirm Upload");
            UI::SeparatorText("");

            UI::TextWrapped("Your JSON has been uploaded. Please copy the URL below and paste it into the field.");

            auto url = px_url;
            UI::PushFont(UI::Font::DefaultMono);
            UI::AlignTextToFramePadding();
            UI::Text("JSON URL: ");

            UI::AlignTextToFramePadding();
            UI::Text(url);
            UI::PopFont();

            if (UI::Button(Icons::InternetExplorer + " Open in Browser")) {
                OpenBrowserURL(url);
            }

            if (url.Length > 0) {
                DrawValidationMsgsJsonUrl(px_url);
            }
        }

        // --- UI state for map comment wizard step ---
        // We should reset _wiz_generatedDipsSpec to "" on any tab before the map comment tab
        private string _wiz_generatedDipsSpec = "";
        private string _wiz_editableMapComment = "";
        private string _wiz_lastMapHash = "-";

        void FinWiz_90_SetMapComment() {
            UI::AlignTextToFramePadding();
            UI::Text("Finalize: Set Map Comment");

            auto map = GetApp().RootMap;

            // Keep editableMapComment in sync with map.Comments unless user edits
            if (_wiz_editableMapComment.Length == 0 || _wiz_lastMapHash != Crypto::MD5(map.Comments)) {
                _wiz_editableMapComment = map.Comments;
                _wiz_lastMapHash = Crypto::MD5(_wiz_editableMapComment);
            }

            if (UI::Button("Regenerate Dips Spec") || _wiz_generatedDipsSpec.Length == 0) {
                auto spec = DipsSpec(pTabForWiz);
                _wiz_generatedDipsSpec = spec.GenerateComment();
            }

            bool mapCommentSet = map.Comments == _wiz_generatedDipsSpec;

            if (UI::Button("Set Map Comment (Will Overwrite)")) {
                map.Comments = _wiz_generatedDipsSpec;
                _wiz_editableMapComment = _wiz_generatedDipsSpec;
                _wiz_lastMapHash = Crypto::MD5(_wiz_editableMapComment);
            }
            UI::SameLine();
            UI::Text("Map Comment Set: " + BoolIcon(mapCommentSet));

            UI::SeparatorText("");
            UI::Columns(2, "dips-mapcomment-cols");
            // LHS: Generated Dips Spec (read-only)
            UI::Text("Generated Dips Spec");
            UI::BeginChild("dips-spec-child", vec2(0, 220), true);
            DrawLineNumberedText(_wiz_generatedDipsSpec);
            UI::EndChild();
            UI::NextColumn();
            // RHS: Editable Map Comment with line numbers
            UI::Text("Current Map Comment (editable)");
            bool changed = false;
            _wiz_editableMapComment = DrawLineNumberedInput("##mapcomment", _wiz_editableMapComment, changed, vec2(-1, 220));
            if (changed) {
                map.Comments = _wiz_editableMapComment;
                _wiz_lastMapHash = Crypto::MD5(_wiz_editableMapComment);
            }
            UI::Columns(1);

            // Show diff status
            UI::AlignTextToFramePadding();
            bool commentsMatch = _wiz_editableMapComment == _wiz_generatedDipsSpec;
            if (!commentsMatch) {
                UI::Text(BoolIcon(false) + " Map comment does not match generated Dips Spec.");
                UI::SameLine();
                if (UI::Button("Copy Generated to Map Comment")) {
                    _wiz_editableMapComment = _wiz_generatedDipsSpec;
                    map.Comments = _wiz_generatedDipsSpec;
                    _wiz_lastMapHash = Crypto::MD5(_wiz_editableMapComment);
                }
            } else {
                UI::Text(BoolIcon(true) + " Map comment matches generated Dips Spec.");
            }

            // Disable next if not matching
            if (!commentsMatch) finalizationWizard.SetNextNavButtonDisabled();
        }

        // Helper: Draw line-numbered, monospace text (read-only)
        void DrawLineNumberedText(const string &in text) {
            UI::PushFont(UI::Font::DefaultMono);
            auto lines = text.Split("\n");
            for (uint i = 0; i < lines.Length; i++) {
                UI::Text(Text::Format("%2d | ", i + 1) + lines[i]);
            }
            UI::PopFont();
        }

        // Helper: Draw line-numbered multiline input (editable)
        string DrawLineNumberedInput(const string &in id, const string &in text, bool &out changed, vec2 size = vec2(-1, 180)) {
            UI::PushFont(UI::Font::DefaultMono);
            string newText = UI::InputTextMultiline(id, text, changed, size, UI::InputTextFlags::AllowTabInput);
            UI::PopFont();
            return newText;
        }

        void FinWiz_99_Done() {
            UI::AlignTextToFramePadding();
            UI::TextWrapped("Congratulations! You have set everything up.");
            UI::PushFont(UI::Font::Default20);
            UI::AlignTextToFramePadding();
            UI::Text("\\$8fcPlease save your map now!");

            UI::PopFont();
            UI::SeparatorText("Nothing more to do");
            if (UI::Button("Reset Wizard")) {
                finalizationWizard.ResetToOrPushTab(0);
            }
        }
    }

}
