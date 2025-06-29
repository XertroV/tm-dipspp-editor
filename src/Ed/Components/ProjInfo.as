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

            UI::SeparatorText(" F I N A L I Z A T I O N ");

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


        uint wTabIx_Prep, wTabIx_MapComment, wTabIx_Done, wTabIx_Adv1Conf, wTabIx_Adv2Urls;

        protected void SetUpWizardTabs() {
            if (finalizationWizard.nbTabs > 0) return; // already set up
            wTabIx_Prep = finalizationWizard.AddTab("Final Prep", CoroutineFunc(this.FinWiz_10_InitialPrep), Icons::ListOl);
            // - if yes -> go to Map Comment step
            // - otherwise -> go through all steps
            // Adv1: set min version -- must be at least 0.5.5 to support the new custom map aux spec. set name_id too
            wTabIx_Adv1Conf = finalizationWizard.AddTab("Advanced 1", CoroutineFunc(this.FinWiz_20_Advanced1), Icons::Cog);
            // Adv2: check asset URLs -- since assets are downloaded, all the URLs should work. (The user can move on if they know what they're doing).
            wTabIx_Adv2Urls = finalizationWizard.AddTab("URL Checks", CoroutineFunc(this.FinWiz_30_CheckUrls), Icons::Link);
            // todo: additional steps?

            // penultimate step
            wTabIx_MapComment = finalizationWizard.AddTab("Map Comment", CoroutineFunc(this.FinWiz_90_SetMapComment), Icons::Comment);
            // last step
            wTabIx_Done = finalizationWizard.AddTab("Done!", CoroutineFunc(this.FinWiz_99_Done), Icons::CheckCircle);
        }

        void FinWiz_10_InitialPrep() {
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
                return;
            }
            UI::SameLine();
            if (UI::ButtonColored("Use Advanced Workflow (JSON Upload)", 0.80)) {
                finalizationWizard.ResetToOrPushTab(finalizationWizard.currentTab + 1); // go to next step
            }
            finalizationWizard.SkipNextBackFwdButtons();

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

        void FinWiz_20_Advanced1() {
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
            if (changedNameId) set_NameId(newNameId);
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

        void FinWiz_90_SetMapComment() {
            UI::AlignTextToFramePadding();
            UI::Text("FinWiz_90_SetMapComment");
            // we have uploaded the json spec and have the URL for it.
            // now we need to set the map comment to final Dips Spec.
            // UI Idea: show two side-by-side text boxes: the generated dips spec and the current map comment.
            // -> then the user can refresh the generation or update the map comment, and can inspect it.
            string generatedDipsSpec = "";
            auto map = GetApp().RootMap;
            bool mapCommentSet = map.Comments.Contains(generatedDipsSpec);

            if (UI::Button("Regenerate Dips Spec") || generatedDipsSpec.Length == 0) {
                // todo: generate the Dips Spec from the project components
                // generatedDipsSpec = todo!()
            }
            UI::SameLine();
            if (UI::Button("Set Map Comment (Will Overwrite)")) {
                map.Comments = generatedDipsSpec;
            }
            UI::SameLine();
            UI::Text("Map Comment Set: " + BoolIcon(mapCommentSet));

            UI::SeparatorText("");
            // todo: LHS: generatedDipsSpec
            // todo: RHS: map.Comments
            // - use monospace, show line numbers, allow editing map comment

            // if the map comment is not set, disable the next button but still show it.
            if (!mapCommentSet) finalizationWizard.SetNextNavButtonDisabled();
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
