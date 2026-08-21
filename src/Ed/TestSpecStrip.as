// toolbar/button strip while map-editor Test/Validate is running.

namespace CM_Editor {
    bool g_TestSpecRemember = false;
    string g_TestSpecRememberedName = "";
    string g_TestSpecStripError = "";
    string g_TestSpecAppliedName = "";
    int g_TestSpecSelectedIx = 0;
    bool g_WasMapEditorPlayground = false;
    bool g_WasMapEditorFree = false;

    bool IsMapEditorFree() {
        return cast<CGameCtnEditorFree>(GetApp().Editor) !is null;
    }

    bool IsMapEditorPlayground() {
        return IsMapEditorFree() && GetApp().CurrentPlayground !is null;
    }

    void CollectOpenProjectTabs(ProjectTab@[]@ outTabs) {
        outTabs.RemoveRange(0, outTabs.Length);
        if (CM_Editor_TG is null) return;
        for (uint i = 0; i < CM_Editor_TG.tabs.Length; i++) {
            auto pt = cast<ProjectTab>(CM_Editor_TG.tabs[i]);
            if (pt is null) continue;
            outTabs.InsertLast(pt);
        }
    }

    int IndexOfProjectName(ProjectTab@[]@ tabs, const string &in name) {
        for (uint i = 0; i < tabs.Length; i++) {
            if (tabs[i].meta.name == name) return int(i);
        }
        return -1;
    }

    void ClearRemember() {
        g_TestSpecRemember = false;
        g_TestSpecRememberedName = "";
    }

    void ApplySelected(ProjectTab@[]@ tabs) {
        g_TestSpecStripError = "";
        if (tabs.Length == 0) return;
        if (g_TestSpecSelectedIx < 0 || g_TestSpecSelectedIx >= int(tabs.Length)) g_TestSpecSelectedIx = 0;
        auto pt = tabs[g_TestSpecSelectedIx];
        Json::Value@ j;
        try {
            @j = pt.ToCombinedJson();
        } catch {
            g_TestSpecStripError = getExceptionInfo();
            NotifyError(g_TestSpecStripError);
            return;
        }
        string err;
        try {
            err = TestSpec::LoadTestSpec(j);
        } catch {
            err = getExceptionInfo();
        }
        if (err.Length > 0) {
            g_TestSpecStripError = err;
            NotifyError(err);
            return;
        }
        g_TestSpecAppliedName = pt.meta.name;
        if (g_TestSpecRemember) g_TestSpecRememberedName = pt.meta.name;
    }

    void OnPlaygroundEnter(ProjectTab@[]@ tabs) {
        g_TestSpecStripError = "";
        g_TestSpecAppliedName = "";
        if (g_TestSpecRemember && g_TestSpecRememberedName.Length > 0) {
            int ix = IndexOfProjectName(tabs, g_TestSpecRememberedName);
            if (ix < 0) {
                ClearRemember();
            } else {
                g_TestSpecSelectedIx = ix;
                ApplySelected(tabs);
                return;
            }
        }
    }

    void OnPlaygroundLeave() {
        TestSpec::UnloadTestSpec();
        g_TestSpecAppliedName = "";
        g_TestSpecStripError = "";
    }

    void UpdateTestSpecStrip() {
        // are we in the map editor? did we leave it?
        bool isMapEditor = IsMapEditorFree();
        if (g_WasMapEditorFree && !isMapEditor) {
            ClearRemember();
            OnPlaygroundLeave();
        }
        g_WasMapEditorFree = isMapEditor;

        // are we in the map editor playground? enter/leave check
        bool pg = IsMapEditorPlayground();
        ProjectTab@[] tabs;
        if (pg && S_EditorWindowOpen) CollectOpenProjectTabs(tabs);

        if (pg && !g_WasMapEditorPlayground) {
            if (S_EditorWindowOpen && tabs.Length > 0) OnPlaygroundEnter(tabs);
        }
        if (!pg && g_WasMapEditorPlayground) {
            OnPlaygroundLeave();
        }
        g_WasMapEditorPlayground = pg;

        // do nothing if not in playground or editor window closed or no project tabs.
        if (!pg) return;
        if (!S_EditorWindowOpen || tabs.Length == 0) return;

        // if we're remembering, check if the remembered project is still open
        if (g_TestSpecRemember && g_TestSpecRememberedName.Length > 0) {
            if (IndexOfProjectName(tabs, g_TestSpecRememberedName) < 0) {
                ClearRemember();
            }
        }

        // render the test spec strip
        RenderTestSpecStrip(tabs);
    }

    void RenderTestSpecStrip(ProjectTab@[]@ tabs) {
        UI::SetNextWindowSize(520, 0, UI::Cond::FirstUseEver);
        if (UI::Begin("Dips++ Editor - Test spec", UI::WindowFlags::AlwaysAutoResize | UI::WindowFlags::NoCollapse)) {
            if (g_TestSpecSelectedIx >= int(tabs.Length)) g_TestSpecSelectedIx = 0;
            UI::SetNextItemWidth(220);
            if (UI::BeginCombo("##ts-proj", tabs[g_TestSpecSelectedIx].meta.name)) {
                for (uint i = 0; i < tabs.Length; i++) {
                    bool sel = int(i) == g_TestSpecSelectedIx;
                    if (UI::Selectable(tabs[i].meta.name, sel)) g_TestSpecSelectedIx = int(i);
                    if (sel) UI::SetItemDefaultFocus();
                }
                UI::EndCombo();
            }
            UI::SameLine();
            bool already = g_TestSpecAppliedName == tabs[g_TestSpecSelectedIx].meta.name && g_TestSpecAppliedName.Length > 0;
            if (UI::Button(already ? "Reload" : "Test")) {
                ApplySelected(tabs);
            }
            UI::SameLine();
            bool prevRem = g_TestSpecRemember;
            g_TestSpecRemember = UI::Checkbox("Remember until leaving editor", g_TestSpecRemember);
            if (g_TestSpecRemember != prevRem) {
                if (g_TestSpecRemember && g_TestSpecAppliedName.Length > 0) g_TestSpecRememberedName = g_TestSpecAppliedName;
                if (!g_TestSpecRemember) g_TestSpecRememberedName = "";
            }
            if (g_TestSpecAppliedName.Length > 0) {
                UI::Text("\\$8f8 Loaded: " + g_TestSpecAppliedName);
            } else {
                UI::Text("\\$888 No spec applied");
            }
            if (g_TestSpecStripError.Length > 0) {
                UI::Text("\\$f88" + g_TestSpecStripError);
            }
        }
        UI::End();
    }
}
