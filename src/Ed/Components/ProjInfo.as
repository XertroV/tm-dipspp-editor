namespace CM_Editor {
    // MARK: Proj Info Cmpnt

    class ProjectInfoComponent : ProjectComponent {
        ProjectInfoComponent(const string &in jsonPath, ProjectMeta@ meta) {
            super(jsonPath, meta);
            name = "Project Info";
            icon = Icons::InfoCircle;
            type = EProjectComponent::Info;
            canInitFromDipsSpecComment = true;
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

        void CreateDefaultJsonObject() override {
            auto j = Json::Object();
            j["minClientVersion"] = "0.0.0";
            // j["url"] = "";
            rw_data = j;
        }

        void CreateJsonDataFromComment(DipsSpec@ spec) override {
            CreateDefaultJsonObject();
            px_minClientVersion = spec.minClientVersion;
            px_url = spec.url;
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

            UI::SeparatorText("Finalize & Upload");
            //

            bool changedMCV = false, changedURL = false;

            auto newMCV = UI::InputText("Min Client Version (optional)", px_minClientVersion, changedMCV);
            AddSimpleTooltip("Default: empty or '0.0.0'. This will prevent Dips++ clients with a lower version from working with this map.");
            if (changedMCV) px_minClientVersion = newMCV;
            if (newMCV.Length > 0 && newMCV != "0.0.0") {
                if (!MapCustomInfo::CheckMinClientVersion(newMCV)) {
                    UI::Text(BoolIcon(false) + " Version newer than plugin version!");
                }
            }

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

        void DrawAssetsEtcSection(ProjectTab@ pTab) {
            UI::SeparatorText("Assets and Voice Lines");

            bool changed = false;
            auto newUP = UI::InputText("Base URL (for VLs/Assets)", UrlPrefix, changed);
            AddSimpleTooltip("All assets should be hosted under this URL.\nMessage XertroV if you need things hosted.\nExample: \"https://assets.xk.io/custom/blah/\"");
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
                UI::Text("\\$i\\$ccc  · • —– ٠ Check VLs & Assets ٠ –— • ·  ");

                UI::Text("VLs: " + 0 + " / " + 0);
                UI::Text("Assets: " + 0 + " / " + 0);
                // todo: buttons and displays for checking that VL and Asset URLs are fine.
                // UI::Text("Todo: Checked Voice Lines Exist: x / N");
                // UI::Text("Todo: Checked Assets Exist: x / N");
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
    }

}
