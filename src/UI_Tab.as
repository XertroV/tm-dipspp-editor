
class Tab {
    string idNonce = "tab-" + Math::Rand(0, TWO_BILLION);

    // bool canCloseTab = false;
    TabGroup@ Parent = null;
    TabGroup@ Children = null;
    TabGroup@ WindowChildren = null;

    string tabName;
    string fullName;
    uint windowExtraId = 0;
    bool addRandWindowExtraId = true;
    string tabIcon;
    string tabIconAndName;

    bool removable = false;
    bool canPopOut = true;
    bool tabOpen = true;
    bool get_windowOpen() { return !tabOpen; }
    void set_windowOpen(bool value) { tabOpen = !value; }
    bool expandWindowNextFrame = false;
    bool windowExpanded = false;
    bool closeWindowOnEscape = false;
    // don't draw the tab name and pop out button
    bool noContentWrap = false;

    bool tabInWarningState = false;

    Tab(TabGroup@ parent, const string &in tabName, const string &in icon) {
        this.tabName = tabName;
        // .Parent set here
        parent.AddTab(this);
        fullName = parent.fullName + " > " + tabName;
        tabIcon = " " + icon;
        tabIconAndName = tabIcon + " " + tabName;
        @Children = TabGroup(tabName, this);
        @WindowChildren = TabGroup(tabName, this);

        if (addRandWindowExtraId) {
            windowExtraId = Math::Rand(0, TWO_BILLION);
        }
    }

    const string get_DisplayIconAndName() {
        if (tabInWarningState) {
            return "\\$f80" + tabIconAndName + "  " + Icons::ExclamationTriangle;
        }
        return tabIconAndName;
    }

    const string get_DisplayIcon() {
        return tabIcon;
    }

    const string get_DisplayIconWithId() {
        return tabIcon + "###" + tabName;
    }

    protected bool _ShouldSelectNext = false;

    void SetSelectedTab() {
        _ShouldSelectNext = true;
        Parent.SetChildSelected(this);
    }

    int get_TabFlags() {
        return UI::TabItemFlags::NoCloseWithMiddleMouseButton
            | UI::TabItemFlags::NoReorder
            | TabFlagSelected
            ;
    }

    int get_TabFlagSelected() {
        if (_ShouldSelectNext) {
            _ShouldSelectNext = false;
            return UI::TabItemFlags::SetSelected;
        }
        return UI::TabItemFlags::None;
    }

    int get_WindowFlags() {
        return UI::WindowFlags::AlwaysAutoResize
            // | UI::WindowFlags::NoCollapse
            ;
    }

    void DrawTogglePop() {
        if (UI::Button((tabOpen ? Icons::Expand : Icons::Compress) + "##" + fullName)) {
            windowOpen = !windowOpen;
        }
        if (removable) {
            UI::SameLine();
            UI::SetCursorPos(UI::GetCursorPos() + vec2(20, 0));
            if (UI::Button(Icons::Trash + "##" + fullName)) {
                Parent.RemoveTab(this);
            }
        }
    }

    void DrawMenuItem() {
        if (UI::MenuItem(DisplayIconAndName, "", windowOpen)) {
            windowOpen = !windowOpen;
        }
    }

    void DrawTab(bool withItem = true) {
        if (!withItem) {
            DrawTabWrapInner();
            return;
        }
        if (_BeginTabItem(tabName, TabFlags)) {
            if (UI::BeginChild(fullName))
                DrawTabWrapInner();
            UI::EndChild();
            UI::EndTabItem();
        }
        _AfterDrawTab();
    }

    // for overriding
    void _AfterDrawTab() {}

    // overload me if tabs are closeable
    bool _BeginTabItem(const string &in l, int flags) {
        return UI::BeginTabItem(l, flags);
    }

    void DrawTabWrapInner() {
        if (noContentWrap) {
            DrawInnerWrapID();
            return;
        }
        UX::LayoutLeftRight("tabHeader|"+fullName,
            CoroutineFunc(_HeadingLeft),
            CoroutineFunc(_HeadingRight)
        );
        UI::Indent();
        if (!tabOpen) {
            UI::Text("Currently popped out.");
        } else {
            DrawInnerWrapID();
        }
        UI::Unindent();
    }

    void _HeadingLeft() {
        UI::AlignTextToFramePadding();
        UI::Text(tabName + ": ");
    }

    void _HeadingRight() {
        if (!tabOpen) {
            if (!windowExpanded) {
                if (UI::Button("Expand Window##"+fullName)) {
                    expandWindowNextFrame = true;
                }
                UI::SameLine();
            }
            if (UI::Button("Return to Tab##"+fullName)) {
                windowOpen = !windowOpen;
            }
        } else {
            if (canPopOut) {
                DrawTogglePop();
            }
        }
    }

    void DrawInner() {
        UI::Text("Tab Inner: " + tabName);
        UI::Text("Overload `DrawInner()`");
    }

    void DrawInnerWrapID() {
        UI::PushID(idNonce);
        DrawInner();
        UI::PopID();
    }

    vec2 lastWindowPos;
    bool DrawWindow() {
        if (windowOpen) {
            if (expandWindowNextFrame && windowOpen && addRandWindowExtraId) {
                UI::SetNextWindowPos(int(lastWindowPos.x), int(lastWindowPos.y));
                windowExtraId = Math::Rand(0, TWO_BILLION);
            }
            expandWindowNextFrame = false;
            windowExpanded = false;
            _BeforeBeginWindow();
            if (UI::Begin(fullName + "##" + windowExtraId, windowOpen, WindowFlags)) {
                windowExpanded = true;
                // DrawTogglePop();
                DrawInnerWrapID();
                if (closeWindowOnEscape && UI::IsKeyPressed(UI::Key::Escape) && UI::IsWindowFocused(UI::FocusedFlags::RootAndChildWindows)) {
                    windowOpen = false;
                }
            }
            lastWindowPos = UI::GetWindowPos();
            UI::End();
        }

        Children.DrawWindows();
        WindowChildren.DrawWindowsAndRemoveTabsWhenClosed();

        return windowOpen;
    }

    void _BeforeBeginWindow() {
        // override
    }
}
