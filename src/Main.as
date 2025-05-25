const string PluginName = Meta::ExecutingPlugin().Name;
const string MenuIconColor = "\\$f5d";
const string PluginIcon = Icons::Cogs;
const string MenuTitle = MenuIconColor + PluginIcon + "\\$z " + PluginName;

void RenderMenu() {
    CM_Editor::RenderMenu();
}

void Render() {
    CM_Editor::Render();
}

void Main() {
    startnew(LoadFonts);
    CM_Editor::OnPluginLoad();
    // CM_Editor::Main();
}

vec2 g_screen = vec2(Draw::GetWidth(), Draw::GetHeight());
vec2 g_lastMousePos = vec2(0, 0);

void RenderEarly() {
    g_screen = vec2(Draw::GetWidth(), Draw::GetHeight());
    g_lastMousePos = vec2(UI::GetMousePos());
}


bool g_InterceptOnMouseClick = false;
bool g_InterceptClickRequiresTestMode = false;
// x, y, button
int3 g_InterceptedMouseClickPosBtn = int3();
CM_Editor::ProjectComponent@ componentWaitingForMouseClick = null;

void OnInterceptedMouseClick(int x, int y, int button) {
    g_InterceptedMouseClickPosBtn.x = x;
    g_InterceptedMouseClickPosBtn.y = y;
    g_InterceptedMouseClickPosBtn.z = button;
    g_InterceptOnMouseClick = false;
    if (componentWaitingForMouseClick !is null) {
        try {
            componentWaitingForMouseClick.OnMouseClick(x, y, button);
        } catch {
            error("OnInterceptedMouseClick failed: " + getExceptionInfo());
        }
        @componentWaitingForMouseClick = null;
    }
}

/** Called whenever a mouse button is pressed. `x` and `y` are the viewport coordinates. */
UI::InputBlocking OnMouseButton(bool down, int button, int x, int y) {
    if (down && button == 0 && g_InterceptOnMouseClick && (!g_InterceptClickRequiresTestMode || EditorIsInTestPlaceMode())) {
        OnInterceptedMouseClick(x, y, button);
        return UI::InputBlocking::Block;
    }
    return UI::InputBlocking::DoNothing;
}
