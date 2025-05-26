// Editor for Custom Maps

namespace CM_Editor {
    const string PluginStorageRoot = IO::FromStorageFolder("");
    const string ProjectsDir = IO::FromStorageFolder("CM_Editor/Projects");
    bool checkedDir = false;

    [Setting hidden]
    bool S_EditorWindowOpen = true;

    void OnPluginLoad() {
        checkedDir = _RunCheckProjDir();
    }

    bool _RunCheckProjDir() {
        if (checkedDir) return true;
        if (!IO::FolderExists(ProjectsDir)) {
            IO::CreateFolder(ProjectsDir, true);
        }
        return true;
    }

    void Main() {
        // if (!IO::FolderExists(ProjectsDir)) IO::CreateFolder(ProjectsDir, true);
        // auto projs = ListProjects();
        // if (projs.Length == 0) IO::CreateFolder(ProjectsDir + "/Test", false);
        // if (projs.Length < 2) IO::CreateFolder(ProjectsDir + "/Test2_ASDF", false);
        // @projs = ListProjects();
        // // trace("Projects: " + Json::Write(projs.ToJson()));
        // Dev::InterceptProc("CGameCtnEditorFree", "SwitchToTestWithMapTypeFromScript_OnOk", Dev::ProcIntercept(_SwitchToTestWithMapTypeFromScript_OnOk));
    }

    // bool _SwitchToTestWithMapTypeFromScript_OnOk(CMwStack &in stack) {
    //     NotifyWarning("SwitchToTestWithMapTypeFromScript_OnOk");
    //     return true;
    // }

    void Render() {
        if (!S_EditorWindowOpen) return;
        UI::SetNextWindowSize(500, 370, UI::Cond::FirstUseEver);
        if (UI::Begin("Dips++ CustomMap Editor", S_EditorWindowOpen)) {
            Draw_CMEditor_WindowMain();
        }
        UI::End();
    }

    void RenderMenu() {
        if (UI::MenuItem("Dips++ CustomMap Editor", "", S_EditorWindowOpen)) {
            S_EditorWindowOpen = !S_EditorWindowOpen;
        }
    }

    // MARK: Project Management

    string[]@ ListProjects() {
        auto folders = IO::IndexFolder(ProjectsDir, false);
        for (int i = int(folders.Length) - 1; i >= 0; i--) {
            if (!folders[i].EndsWith("/")) {
                trace('removing non-folder: ' + folders[i]);
                folders.RemoveAt(i);
            } else {
                folders[i] = folders[i].Replace(ProjectsDir, "");
                // remove leading and trailing slashes
                folders[i] = folders[i].SubStr(1, folders[i].Length - 2);
            }
        }
        return folders;
    }

    // MARK: Render/UI

    void Draw_CMEditor_WindowMain() {
        CM_Editor_TG.DrawTabs();
        CM_Editor_TG.DrawWindows();
    }

    TabGroup@ CM_Editor_TG = Init_CM_Editor_TG();
    TabGroup@ Init_CM_Editor_TG() {
        auto tg = TabGroup("CM_Editor_TG", null);
        auto lpTab = LoadProjTab(tg);
#if DEV
        lpTab.RefreshProjects();
        lpTab.OpenFirstProject();
#endif
        return tg;
    }


}


// MARK: Icons

string BoolIcon(bool f) {
    return f
        ? "\\$<\\$4f4" + Icons::Check + "\\$>"
        : "\\$<\\$f44" + Icons::Times + "\\$>";
}


// MARK: Misc


void SetEditorCameraToPos(vec3 pos, float dist = -1.0) {
    auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
    auto pmt = editor.PluginMapType;
    pmt.CameraTargetPosition = pos;
    if (dist > 0.0) pmt.CameraToTargetDistance = dist;
}

CGameEditorPluginMap::EPlaceMode beforeTM_PlaceMode = CGameEditorPluginMap::EPlaceMode::Block;
CGameEditorPluginMap::EditMode beforeTM_EditMode = CGameEditorPluginMap::EditMode::Place;

void SetEditorToTestMode() {
    auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
    beforeTM_EditMode = editor.PluginMapType.EditMode;
    beforeTM_PlaceMode = editor.PluginMapType.PlaceMode;
    editor.PluginMapType.PlaceMode = CGameEditorPluginMap::EPlaceMode::Test;
    editor.PluginMapType.EditMode = CGameEditorPluginMap::EditMode::Place;
}

void RestoreEditorMode() {
    auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
    editor.PluginMapType.PlaceMode = beforeTM_PlaceMode;
    editor.PluginMapType.EditMode = beforeTM_EditMode;
}

vec3 GetEditorItemCursorPos() {
    auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
    if (editor is null || editor.ItemCursor is null) {
        return vec3(-1.0);
    }
    return editor.ItemCursor.CurrentPos;
}

// edit mode = place and place mode = test
bool EditorIsInTestPlaceMode() {
    auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
    auto pmt = editor.PluginMapType;
    return pmt.EditMode == CGameEditorPluginMap::EditMode::Place && pmt.PlaceMode == CGameEditorPluginMap::EPlaceMode::Test;
}


void nvgDrawWorldBox(vec3 pos, vec3 size, vec4 color, float strokeWidth = 2.0) {
    vec3[] corners = array<vec3>(8);
    // Bottom face
    corners[0] = pos;
    corners[1] = pos + vec3(size.x, 0, 0);
    corners[2] = pos + vec3(size.x, 0, size.z);
    corners[3] = pos + vec3(0, 0, size.z);
    // Top face
    corners[4] = pos + vec3(0, size.y, 0);
    corners[5] = pos + vec3(size.x, size.y, 0);
    corners[6] = pos + vec3(size.x, size.y, size.z);
    corners[7] = pos + vec3(0, size.y, size.z);

    nvg::BeginPath();
    nvg::StrokeColor(color);
    nvg::StrokeWidth(strokeWidth);
    nvg::LineCap(nvg::LineCapType::Round);
    nvg::LineJoin(nvg::LineCapType::Round);

    // Bottom face loop (0→1→2→3→0)
    nvgMoveToWorldPos(corners[0]);
    nvgLineToWorldPos(corners[1]);
    nvgLineToWorldPos(corners[2]);
    nvgLineToWorldPos(corners[3]);
    nvgLineToWorldPos(corners[0]);

    // Top face loop (4→5→6→7→4)
    nvgMoveToWorldPos(corners[4]);
    nvgLineToWorldPos(corners[5]);
    nvgLineToWorldPos(corners[6]);
    nvgLineToWorldPos(corners[7]);
    nvgLineToWorldPos(corners[4]);

    // Vertical edges (0→4, 1→5, 2→6, 3→7)
    nvgMoveToWorldPos(corners[0]); nvgLineToWorldPos(corners[4]);
    nvgMoveToWorldPos(corners[1]); nvgLineToWorldPos(corners[5]);
    nvgMoveToWorldPos(corners[2]); nvgLineToWorldPos(corners[6]);
    nvgMoveToWorldPos(corners[3]); nvgLineToWorldPos(corners[7]);

    nvg::Stroke();
    nvg::ClosePath();
}




// MARK: Stub

class DipsSpec {
    string minClientVersion;
    string url;
    bool lastFloorEnd;
    FloorSpec[] floors;

    DipsSpec(const string &in comment) {
        warn("DipsSpec stub");
    }
}

class FloorSpec {
    float height;
    string name;
    Json::Value ToJson() {
        auto j = Json::Object();
        j["height"] = height;
        j["name"] = name;
        return j;
    }
}
