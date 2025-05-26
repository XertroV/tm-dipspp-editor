namespace CM_Editor {

    // MARK: Assets

    enum AssetTy {
        Image,
        Audio
    }

    const string IMAGES_K = "images";
    const string AUDIOS_K = "audios";

    string AssetTy_ToKey(AssetTy ty) {
        switch (ty) {
            case AssetTy::Image: return IMAGES_K;
            case AssetTy::Audio: return AUDIOS_K;
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
#if FALSE
    void markAssetsDirty() {} // for language server
#endif

    // holds individual files
    class AssetsList {
        string[] files;
        AssetsList() {}
        AssetsList(const Json::Value@ j) {
            LoadFromJson(j);
        }

        void LoadFromJson(const Json::Value@ j) {
            if (j.GetType() != Json::Type::Array) {
                warn("AssetsList: Expected array, got: " + tostring(j.GetType()));
                return;
            }
            files.RemoveRange(0, files.Length);
            for (uint i = 0; i < j.Length; i++) {
                if (j[i].GetType() == Json::Type::String) {
                    files.InsertLast(string(j[i]));
                } else {
                    warn("AssetsList: Invalid type at index " + i + ": " + tostring(j[i].GetType()));
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
        AssetsCategory(const Json::Value@ j) {
            LoadFromJson(j);
        }
        void LoadFromJson(const Json::Value@ j) {
            if (j.GetType() != Json::Type::Object) {
                warn("AssetsCategory: Expected object, got: " + tostring(j.GetType()));
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
            MarkAssetsDirty();
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

        string DrawMenu(const string &in value) {
            string ret = value;
            if (UI::BeginMenu(name)) {
                for (uint i = 0; i < assets.files.Length; i++) {
                    auto asset = assets.files[i];
                    if (UI::MenuItem(asset, "", value == asset)) {
                        ret = asset;
                    }
                }
                UI::Separator();
                bool e;
                m_newAsset = UI::InputText("New Asset", m_newAsset, e, UI::InputTextFlags::EnterReturnsTrue);
                if ((UI::Button(Icons::Plus + " Add") || e) && m_newAsset.Length > 0) {
                    AddAssetsCSV(m_newAsset);
                    ret = m_newAsset;
                    m_newAsset = "";
                }
                UI::EndMenu();
            }
            return ret;
        }
    }

    // holds categories of assets, 1 collection per AssetTy
    class AssetsCollection {
        AssetsCategory@[] categories;

        AssetsCollection() {}

        AssetsCollection(const Json::Value@ j) {
            LoadFromJson(j);
        }

        void LoadFromJson(const Json::Value@ j) {
            if (j.GetType() != Json::Type::Array) {
                warn("AssetsCollection: Expected array, got: " + tostring(j.GetType()));
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
            MarkAssetsDirty();
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
            categories.InsertLast(cat);
            cat.AddAsset(asset);
        }

        bool HasAsset(const string &in asset) {
            for (uint i = 0; i < categories.Length; i++) {
                if (categories[i].HasAsset(asset)) {
                    return true;
                }
            }
            return false;
        }

        void AddAllAssetUrlsToChecker(const string &in urlPrefix, UrlChecks@ urlChecker) const {
            for (uint i = 0; i < categories.Length; i++) {
                auto cat = categories[i];
                for (uint j = 0; j < cat.assets.files.Length; j++) {
                    urlChecker.AddUrlCheck(urlPrefix + cat.assets.files[j]);
                }
            }
        }

        uint Count() const {
            uint count = 0;
            for (uint i = 0; i < categories.Length; i++) {
                count += categories[i].assets.files.Length;
            }
            return count;
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

        string newCatName;
        string DrawMenu(const string &in value) {
            string ret = value;
            for (uint i = 0; i < categories.Length; i++) {
                auto cat = categories[i];
                ret = cat.DrawMenu(ret);
            }
            if (UI::BeginMenu("Add New Category")) {
                bool e = false;
                newCatName = UI::InputText("##newCat", newCatName, e, UI::InputTextFlags::EnterReturnsTrue);
                if ((UI::Button(Icons::Plus + " Add") || e) && newCatName.Length > 0) {
                    NewCategory(newCatName);
                    newCatName = "";
                }
                UI::EndMenu();
            }
            return ret;
        }
    }

    class ProjectAssetsComponent : ProjectComponent {
        UrlChecks@ imageUrlChecks = UrlChecks();
        UrlChecks@ soundUrlChecks = UrlChecks();

        AssetsCollection@ images;
        AssetsCollection@ audios;

        ProjectAssetsComponent(const string &in jsonPath, ProjectMeta@ meta) {
            super(jsonPath, meta);
            name = "Assets";
            icon = Icons::FileImageO;
            type = EProjectComponent::Assets;
            @images = AssetsCollection();
            @audios = AssetsCollection();
        }

        void TryLoadingJson(const string&in jFName) override {
            ProjectComponent::TryLoadingJson(jFName);
            if (ro_data.HasKey(IMAGES_K)) {
                @images = AssetsCollection(ro_data[IMAGES_K]);
            }
            if (ro_data.HasKey(AUDIOS_K)) {
                @audios = AssetsCollection(ro_data[AUDIOS_K]);
            }
        }

        void SaveToFile() override {
            rw_data[IMAGES_K] = images.ToJson();
            rw_data[AUDIOS_K] = audios.ToJson();
            ProjectComponent::SaveToFile();
        }

        void OnDirty() override {
            ProjectComponent::OnDirty();
            SetUrlChecksStale();
        }

        void SetUrlChecksStale() {
            imageUrlChecks.SetStale();
            soundUrlChecks.SetStale();
        }

        AssetsCollection@ GetAssets(AssetTy ty) {
            switch (ty) {
                case AssetTy::Image: return images;
                case AssetTy::Audio: return audios;
            }
            throw("Invalid AssetTy: " + tostring(ty));
            return null;
        }

        void pushAsset(AssetTy ty, const string &in category, const string &in asset) {
            GetAssets(ty).AddTo(category, asset);
            OnDirty();
        }

        void CreateDefaultJsonObject() override {
            auto j = Json::Object();
            j[IMAGES_K] = Json::Array();
            j[AUDIOS_K] = Json::Array();
            rw_data = j;
        }

        void DrawComponentInner(ProjectTab@ pTab) override {
            UI::BeginTabBar("Assets", UI::TabBarFlags::None);
            if (UI::BeginTabItem(IMAGES_K)) {
                DrawAssetTab(AssetTy::Image, pTab);
                UI::EndTabItem();
            }
            if (UI::BeginTabItem("Audio")) {
                DrawAssetTab(AssetTy::Audio, pTab);
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
                case AssetTy::Audio: return soundUrlChecks;
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
        }

        bool DidUrlCheckerPass(AssetTy ty) {
            auto urlChecker = GetUrlChecker(ty);
            if (urlChecker.isStale) return false;
            if (urlChecker.isRunning) return false;
            auto assets = GetAssets(ty);
            return urlChecker.Passes(assets.Count());
        }

        void StartCheckUrls(AssetTy ty, const string &in urlPrefix) {
            auto urlChecker = GetUrlChecker(ty);
            if (urlChecker.isRunning) return;
            urlChecker.Reset();
            auto assets = GetAssets(ty);
            for (uint i = 0; i < assets.categories.Length; i++) {
                assets.AddAllAssetUrlsToChecker(urlPrefix, urlChecker);
            }
            urlChecker.StartRun();
        }



        string m_BrowserInput = "";
        int browserOpenTy = -1;

        /* Browse assets by type.
           Modes: new or find. New can add a new asset, and find will show existing assets via an autocomplete dropdown.

        */
        string Browser(const string &in label, const string &in value, AssetTy ty) {
            auto assets = GetAssets(ty);
            UI::AlignTextToFramePadding();
            string outV = value;
            UI::AlignTextToFramePadding();
            UI::BeginChild("##" + label, vec2(120, UI::GetFrameHeight()));
            UI::AlignTextToFramePadding();
            if (browserOpenTy == ty) {
                if (UI::BeginMenu(label)) {
                    outV = assets.DrawMenu(value);
                    UI::EndMenu();
                } else {
                    browserOpenTy = -1;
                }
            } else if (UI::Button(Icons::Crosshairs + " " + label)) {
                browserOpenTy = ty;
            }
            if (outV.Length == 0) {
                outV = value;
            }
            UI::EndChild();
            UI::SameLine();
            UI::Text(outV);
            return outV;
        }

        // bool assetBrowseModeAddNew = false;
        // void ToggleAssetBrowseMode() {
        //     assetBrowseModeAddNew = !assetBrowseModeAddNew;
        // }

        // void Draw_AssetBrowserModeButton() {
        //     if (UX::Toggler("##mode", assetBrowseModeAddNew)) ToggleAssetBrowseMode();
        //     UI::SameLine();
        //     if (assetBrowseModeAddNew) {
        //         UI::Text("<Add New>");
        //     } else {
        //         UI::Text("<Select>");
        //     }
        // }
    }
}
