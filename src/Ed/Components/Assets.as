namespace CM_Editor {

    // MARK: Assets

    enum AssetTy {
        Image,
        Sound
    }

    string AssetTy_ToKey(AssetTy ty) {
        switch (ty) {
            case AssetTy::Image: return "images";
            case AssetTy::Sound: return "sounds";
        }
        throw("Invalid AssetTy: " + tostring(ty));
        return "";
    }

    void MarkAssetsDirty() {
        if (markAssetsDirty is null) {
            warn("markAssetsDirty is null, cannot mark assets dirty.");
            return;
        }
        markAssetsDirty();
    }
    CoroutineFunc@ markAssetsDirty = null;

    // holds individual files
    class AssetsList {
        string[] files;
        AssetsList() {}
        AssetsList(Json::Value@ j) {
            LoadFromJson(j);
        }

        void LoadFromJson(Json::Value@ j) {
            if (j.GetType() != Json::Type::Array) {
                warn("AssetsList: Expected array, got: " + j.GetType());
                return;
            }
            files.RemoveRange(0, files.Length);
            for (uint i = 0; i < j.Length; i++) {
                if (j[i].GetType() == Json::Type::String) {
                    files.InsertLast(string(j[i]));
                } else {
                    warn("AssetsList: Invalid type at index " + i + ": " + j[i].GetType());
                }
            }
        }

        Json::Value@ ToJson() {
            auto j = Json::Array();
            for (uint i = 0; i < files.Length; i++) {
                j.Add(files[i]);
            }
            return j;
        }

        void Draw() {
            UI::BeginChild("AssetsList", vec2(0, 200), true);
            UI::BeginTable("AssetsList", 2, UI::TableFlags::SizingStretchProp);
            UI::TableSetupColumn("Asset", UI::TableColumnFlags::WidthStretch);
            UI::TableSetupColumn("Actions", UI::TableColumnFlags::WidthFixed);
            // UI::TableHeadersRow();
            int remIx = -1;
            for (uint i = 0; i < files.Length; i++) {
                UI::PushID("Asset" + i);
                UI::TableNextRow();
                auto asset = files[i];
                UI::TableNextColumn();
                UI::AlignTextToFramePadding();
                UI::Text(asset);
                UI::SameLine();
                if (UI::Button(Icons::Download + " Test")) {
                    try {
                        OpenBrowserURL(asset);
                    } catch {
                        NotifyWarning("Invalid URL: " + asset);
                    }
                }
                AddSimpleTooltip("Full URL: " + asset);

                UI::TableNextColumn();
                if (UI::Button(Icons::TrashO + " Delete")) {
                    remIx = i;
                }
                UI::PopID();
            }
            UI::EndTable();
            UI::EndChild();

            if (remIx != -1) {
                files.RemoveAt(remIx);
                MarkAssetsDirty();
            }
        }
    }

    class AssetsCategory {
        string name;
        AssetsList@ assets;
        AssetsCategory(const string &in name) {
            this.name = name;
            @assets = AssetsList();
        }
        AssetsCategory(Json::Value@ j) {
            LoadFromJson(j);
        }
        void LoadFromJson(Json::Value@ j) {
            if (j.GetType() != Json::Type::Object) {
                warn("AssetsCategory: Expected object, got: " + j.GetType());
                return;
            }
            name = j.Get("name", "Unnamed Category");
            @assets = AssetsList(j["assets"]);
        }
        Json::Value@ ToJson() {
            auto j = Json::Object();
            j["name"] = name;
            j["assets"] = assets.ToJson();
            return j;
        }

        void AddAsset(const string &in asset) {
            if (assets.files.Find(asset) != -1) {
                warn("Asset already exists in category: " + asset);
                return;
            }
            assets.files.InsertLast(asset);
        }

        void AddAssetsCSV(const string &in csv) {
            auto assetList = csv.Split(",");
            for (uint i = 0; i < assetList.Length; i++) {
                string asset = assetList[i].Trim();
                if (asset.Length == 0) continue;
                AddAsset(asset);
            }
        }

        bool HasAsset(const string &in asset) {
            return assets.files.Find(asset) != -1;
        }

        string m_newAsset = "";

        void Draw() {
            UI::Text(name + " (" + assets.files.Length + ")");
            // UI::SameLine();
            bool changed;
            m_newAsset = UI::InputText("##" + name, m_newAsset, changed, UI::InputTextFlags::EnterReturnsTrue);
            AddSimpleTooltip("Separate with commas to add many.");
            UI::SameLine();
            if (UI::Button(Icons::Plus + " Add Asset") || changed) {
                if (m_newAsset.Length > 0) {
                    AddAssetsCSV(m_newAsset);
                    m_newAsset = "";
                }
            }
            UI::Separator();
            this.assets.Draw();

            if (this.assets.files.Length == 0) {
                UI::TextWrapped("No assets in: " + this.name);
            }
        }
    }

    // holds categories of assets, 1 collection per AssetTy
    class AssetsCollection {
        AssetsCategory@[] categories;

        AssetsCollection() {}

        AssetsCollection(Json::Value@ j) {
            LoadFromJson(j);
        }

        void LoadFromJson(Json::Value@ j) {
            if (j.GetType() != Json::Type::Object) {
                warn("AssetsCollection: Expected object, got: " + j.GetType());
                return;
            }
            categories.RemoveRange(0, categories.Length);
            for (uint i = 0; i < j.Length; i++) {
                categories.InsertLast(AssetsCategory(j[i]));
            }
        }

        Json::Value@ ToJson() {
            auto j = Json::Array();
            for (uint i = 0; i < categories.Length; i++) {
                j.Add(categories[i].ToJson());
            }
            return j;
        }

        AssetsCategory@ GetCategory(const string &in categoryName) {
            for (uint i = 0; i < categories.Length; i++) {
                if (categories[i].name == categoryName) {
                    return categories[i];
                }
            }
            return null;
        }

        AssetsCategory@ NewCategory(const string &in name) {
            auto cat = GetCategory(name);
            if (cat !is null) {
                warn("Category already exists: " + name);
                return cat;
            }
            @cat = AssetsCategory(name);
            categories.InsertLast(cat);
            return cat;
        }

        void AddTo(const string &in categoryName, const string &in asset) {
            auto cat = GetCategory(categoryName);
            if (cat !is null) {
                // found existing category, add asset
                cat.AddAsset(asset);
                return;
            }
            // not found, create new category
            @cat = AssetsCategory(categoryName);
            cat.AddAsset(asset);
            categories.InsertLast(cat);
        }

        bool HasAsset(const string &in asset) {
            for (uint i = 0; i < categories.Length; i++) {
                if (categories[i].HasAsset(asset)) {
                    return true;
                }
            }
            return false;
        }


        void Draw() {
            AssetsCategory@ active;
            UI::BeginTabBar("AssetsCategories", UI::TabBarFlags::None);
            for (uint i = 0; i < categories.Length; i++) {
                auto cat = categories[i];
                if (UI::BeginTabItem(cat.name)) {
                    @active = cat;
                    cat.Draw();
                    UI::EndTabItem();
                }
            }
            UI::EndTabBar();

            if (active is null) {
                UI::TextWrapped("Add or select a category.");
            }
        }
    }

    class ProjectAssetsComponent : ProjectComponent {
        UrlChecks@ imageUrlChecks = UrlChecks();
        UrlChecks@ soundUrlChecks = UrlChecks();

        AssetsCollection@ images;
        AssetsCollection@ sounds;

        ProjectAssetsComponent(const string &in jsonPath, ProjectMeta@ meta) {
            super(jsonPath, meta);
            name = "Assets";
            icon = Icons::FileImageO;
            type = EProjectComponent::Assets;
            @images = AssetsCollection();
            @sounds = AssetsCollection();
        }

        void SaveToFile() override {
            rw_data["images"] = images.ToJson();
            rw_data["sounds"] = sounds.ToJson();
            ProjectComponent::SaveToFile();
        }

        Json::Value@ getRwAssets(AssetTy ty) {
            auto key = AssetTy_ToKey(ty);
            if (!ro_data.HasKey(key) || ro_data[key].GetType() != Json::Type::Array) {
                rw_data[key] = Json::Array();
            }
            return rw_data[key];
        }

        void OnDirty() override {
            ProjectComponent::OnDirty();
            SetUrlChecksStale();
        }

        void SetUrlChecksStale() {
            imageUrlChecks.SetStale();
            soundUrlChecks.SetStale();
        }

        const Json::Value@ getRoAssets(AssetTy ty) {
            auto key = AssetTy_ToKey(ty);
            if (!ro_data.HasKey(key) || ro_data[key].GetType() != Json::Type::Array) {
                rw_data[key] = Json::Array();
            }
            return ro_data[key];
        }

        AssetsCollection@ GetAssets(AssetTy ty) {
            switch (ty) {
                case AssetTy::Image: return images;
                case AssetTy::Sound: return sounds;
            }
            throw("Invalid AssetTy: " + tostring(ty));
            return null;
        }

        void pushAsset(AssetTy ty, const string &in category, const string &in asset) {
            // auto @assets = getRwAssets(ty);
            // assets.Add(asset);
            OnDirty();
            GetAssets(ty).AddTo(category, asset);
        }

        void CreateDefaultJsonObject() override {
            auto j = Json::Object();
            j["images"] = Json::Array();
            j["sounds"] = Json::Array();
            rw_data = j;
        }

        void DrawComponentInner(ProjectTab@ pTab) override {
            UI::BeginTabBar("Assets", UI::TabBarFlags::None);
            if (UI::BeginTabItem("Images")) {
                DrawAssetTab(AssetTy::Image, pTab);
                UI::EndTabItem();
            }
            if (UI::BeginTabItem("Audio")) {
                DrawAssetTab(AssetTy::Sound, pTab);
                UI::EndTabItem();
            }
            UI::EndTabBar();
        }

        bool HasImageAsset(const string &in asset) {
            return HasAsset(AssetTy::Image, asset);
        }

        bool HasAsset(AssetTy ty, const string &in asset) {
            return GetAssets(ty).HasAsset(asset);
        }

        // void AddImageAsset(const string &in asset) {
        //     if (HasImageAsset(asset)) {
        //         NotifyWarning("Image asset already exists: " + asset);
        //         return;
        //     }
        //     pushAsset(AssetTy::Image, asset);
        // }

        UrlChecks@ GetUrlChecker(AssetTy ty) {
            switch (ty) {
                case AssetTy::Image: return imageUrlChecks;
                case AssetTy::Sound: return soundUrlChecks;
            }
            throw("Invalid AssetTy: " + tostring(ty));
            return null;
        }

        string m_NewCategory = "";
        string iAsset = "";
        AssetTy lastAssetTy = AssetTy::Image;

        void DrawAssetTab(AssetTy ty, ProjectTab@ pTab) {
            // more than one of these tabs could be live, so set this global reference before we draw
            @markAssetsDirty = CoroutineFunc(this.OnDirty);
            auto @assets = GetAssets(ty);

            UI::Text("Asset Type: " + AssetTy_ToKey(ty));
            UI::Separator();

            auto urlPrefix = pTab.GetUrlPrefix();
            if (lastAssetTy != ty) {
                lastAssetTy = ty;
                iAsset = "";
            }
            string assetType = AssetTy_ToKey(ty);
            auto urlChecker = GetUrlChecker(ty);
            bool changed = false;

            UI::AlignTextToFramePadding();
            UI::Text("Tested URLs: " + BoolIcon(DidUrlCheckerPass(ty)));
            UI::SameLine();
            UI::BeginDisabled(!urlChecker.IsStaleAndReady());
            if (UI::Button(Icons::Check + " Check URLs")) StartCheckUrls(ty, urlPrefix);
            UI::EndDisabled();
            if (!urlChecker.isStale) {
                UI::SameLine();
                UI::Text(urlChecker.StatusText());
            }

            if (urlChecker.isRunning) {
                urlChecker.DrawProgressBars();
                return;
            }

            UI::Separator();


            // iAsset = UI::InputText("Asset File(s)", iAsset, changed);
            // AddSimpleTooltip("Separate with commas to add many.");


            // categories
            m_NewCategory = UI::InputText("New Category", m_NewCategory, changed, UI::InputTextFlags::EnterReturnsTrue);
            UI::SameLine();
            UI::BeginDisabled(m_NewCategory.Length == 0);
            if (UI::Button(Icons::Plus + " Add##cat") || changed) {
                GetAssets(ty).NewCategory(m_NewCategory);
                m_NewCategory = "";
            }
            UI::EndDisabled();

            assets.Draw();


            // UI::BeginChild(assetType + "Assets");
            // UI::BeginTable(assetType + "Assets", 2, UI::TableFlags::SizingStretchProp);
            // UI::TableSetupColumn("Asset", UI::TableColumnFlags::WidthStretch);
            // UI::TableSetupColumn("Actions", UI::TableColumnFlags::WidthFixed);
            // // UI::TableHeadersRow();
            // auto @assets = getRoAssets(ty);
            // int remIx = -1;
            // for (uint i = 0; i < assets.Length; i++) {
            //     UI::PushID(assetType + i);
            //     UI::TableNextRow();
            //     auto asset = string(assets[i]);
            //     UI::TableNextColumn();
            //     UI::AlignTextToFramePadding();
            //     UI::Text(asset);
            //     UI::SameLine();
            //     if (UI::Button(Icons::Download + " Test")) {
            //         try {
            //             OpenBrowserURL(urlPrefix + asset);
            //         } catch {
            //             NotifyWarning("Invalid URL: " + urlPrefix + asset);
            //         }
            //     }
            //     AddSimpleTooltip("Full URL: " + urlPrefix + asset);

            //     UI::TableNextColumn();
            //     if (UI::Button(Icons::TrashO + " Delete")) {
            //         remIx = i;
            //     }
            //     UI::PopID();
            // }
            // UI::EndTable();
            // UI::EndChild();

            // if (remIx != -1) {
            //     getRwAssets(ty).Remove(remIx);
            //     SaveToFile();
            // }
        }

        void AddAssetsFromInput(AssetTy ty, const string &in input) {
            auto @assets = getRwAssets(ty);
            auto assetList = input.Split(",");
            int nbAdded = 0;
            for (uint i = 0; i < assetList.Length; i++) {
                string asset = assetList[i].Trim();
                if (asset.Length == 0) continue;
                if (HasAsset(ty, asset)) {
                    NotifyWarning("Asset already exists: " + asset);
                    continue;
                }
                assets.Add(asset);
                trace("Added asset: " + asset);
                nbAdded++;
            }
            SaveToFile();
            Notify("Added " + nbAdded + " assets.");
        }

        bool DidUrlCheckerPass(AssetTy ty) {
            auto urlChecker = GetUrlChecker(ty);
            if (urlChecker.isStale) return false;
            if (urlChecker.isRunning) return false;
            return urlChecker.Passes(getRoAssets(ty).Length);
        }

        void StartCheckUrls(AssetTy ty, const string &in urlPrefix) {
            auto urlChecker = GetUrlChecker(ty);
            if (urlChecker.isRunning) return;
            urlChecker.Reset();
            auto assets = getRoAssets(ty);
            for (uint i = 0; i < assets.Length; i++) {
                if (assets[i].GetType() != Json::Type::String) {
                    warn("Invalid asset type: " + tostring(assets[i].GetType()));
                    continue;
                }
                string asset = string(assets[i]);
                string url = urlPrefix + asset;
                urlChecker.AddUrlCheck(url);
            }
            urlChecker.StartRun();
        }



        string m_BrowserInput = "";

        /* Browse assets by type.
           Modes: new or find. New can add a new asset, and find will show existing assets via an autocomplete dropdown.

        */
        string Browser(const string &in label, const string &in value, AssetTy ty, bool allowAdd = true) {
            auto assets = getRoAssets(ty);
            UI::AlignTextToFramePadding();
            UI::Text(label);
            UI::SameLine();
            Draw_AssetBrowserModeButton();
            UI::SameLine();
            bool changed;
            string outV = value;
            if (assetBrowseModeAddNew) {
                outV = UI::InputText("##" + label + "New", value, changed, UI::InputTextFlags::EnterReturnsTrue);
            } else {
                // draw dropdown
            }

            return outV;
        }

        bool assetBrowseModeAddNew = false;
        void ToggleAssetBrowseMode() {
            assetBrowseModeAddNew = !assetBrowseModeAddNew;
        }

        void Draw_AssetBrowserModeButton() {
            bool clicked = false;
            if (assetBrowseModeAddNew) {
                clicked = UI::Button(Icons::Folder + " Find");
            } else {
                clicked = UI::Button(Icons::Plus + " New");
            }
            if (clicked) startnew(CoroutineFunc(ToggleAssetBrowseMode));
        }
    }
}
