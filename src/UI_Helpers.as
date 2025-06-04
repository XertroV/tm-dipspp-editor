UI::Font@ g_MonoFont;
UI::Font@ g_BoldFont;
UI::Font@ g_BigFont;
UI::Font@ g_MidFont;
UI::Font@ g_NormFont;
void LoadFonts() {
    @g_BoldFont = UI::Font::DefaultBold;
    @g_MonoFont = UI::Font::DefaultMono;
    @g_BigFont = UI::Font::Default26;
    @g_MidFont = UI::Font::Default20;
    @g_NormFont = UI::Font::Default;
}

void AddSimpleTooltip(const string &in msg, bool pushFont = false) {
    if (UI::IsItemHovered()) {
        if (pushFont) UI::PushFont(g_NormFont);
        UI::SetNextWindowSize(400, 0, UI::Cond::Appearing);
        UI::BeginTooltip();
        UI::TextWrapped(msg);
        UI::EndTooltip();
        if (pushFont) UI::PopFont();
    }
}

void AddIndentedTooltip(const string &in msg, bool pushFont = false, float w = -1.0) {
    if (UI::IsItemHovered()) {
        if (pushFont) UI::PushFont(g_NormFont);
        UI::SetNextWindowSize(400, 0, UI::Cond::Appearing);
        UI::BeginTooltip();
        UI::Indent(w);
        UI::TextWrapped(msg);
        UI::Unindent(w);
        UI::EndTooltip();
        if (pushFont) UI::PopFont();
    }
}



void Notify(const string &in msg) {
    UI::ShowNotification(Meta::ExecutingPlugin().Name, msg);
    trace("Notified: " + msg);
}

void NotifySuccess(const string &in msg) {
    UI::ShowNotification(Meta::ExecutingPlugin().Name, msg, vec4(.4, .7, .1, .3), 10000);
    trace("Notified: " + msg);
}

shared void NotifyError(const string &in msg) {
    warn(msg);
    UI::ShowNotification(Meta::ExecutingPlugin().Name + ": Error", msg, vec4(.9, .3, .1, .3), 15000);
}

void NotifyWarning(const string &in msg) {
    warn(msg);
    UI::ShowNotification(Meta::ExecutingPlugin().Name + ": Warning", msg, vec4(.9, .6, .2, .3), 15000);
}

void Dev_NotifyWarning(const string &in msg) {
#if DEV
    warn(msg);
    UI::ShowNotification("Dev: Warning", msg, vec4(.9, .6, .2, .3), 15000);
#endif
}



namespace UX {
    void LayoutLeftRight(const string &in id, CoroutineFunc@ left, CoroutineFunc@ right) {
        if (UI::BeginTable(id, 3, UI::TableFlags::SizingFixedFit)) {
            UI::TableSetupColumn("lhs", UI::TableColumnFlags::WidthFixed);
            UI::TableSetupColumn("mid", UI::TableColumnFlags::WidthStretch);
            UI::TableSetupColumn("rhs", UI::TableColumnFlags::WidthFixed);
            UI::TableNextRow();
            UI::TableNextColumn();
            left();
            UI::TableNextColumn();
            // blank
            UI::TableNextColumn();
            right();
            UI::EndTable();
        }
    }

    bool Toggler(const string &in id, bool state) {
        return UI::Button((state ? Icons::ToggleOn : Icons::ToggleOff) + "##" + id);
    }

    void CopyableText(const string &in msg) {
        UI::Text(msg);
        if (UI::IsItemClicked()) {
            IO::SetClipboard(msg);
            Notify("Copied to clipboard: " + msg);
        }
        if (UI::IsItemHovered()) {
            UI::SetMouseCursor(UI::MouseCursor::Hand);
        }
    }
}
