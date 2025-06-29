/* * WizardTabs
 *
 * A simple class to manage a wizard managed via tabs.
 * Clicking to a previous tab will reset the wizard to that step.
 * Each tab has a 'next' button until it's the last tab. (And each after the first tab has a 'back' button.)
 * Now supports skipping steps by maintaining a stack of active tab indices.
 */
class WizardTabs {
    CoroutineFunc@[] tabInnerRenders;
    string[] tabNames;
    int[] tabStack = {0}; // stack of active tab indices

    uint AddTab(const string &in name, CoroutineFunc@ renderFunc, const string &in icon = "") {
        if (icon.Length > 0) {
            tabNames.InsertLast(icon + "  " + name);
        } else {
            tabNames.InsertLast(name);
        }
        tabInnerRenders.InsertLast(renderFunc);
        return tabInnerRenders.Length - 1;
    }

    int get_nbTabs() const { return tabNames.Length; }
    int get_currentTab() const { return tabStack[tabStack.Length-1]; }
    bool get_IsFirstTab() const { return tabStack.Length == 1; }
    bool get_IsLastTab() const { return currentTab == int(tabNames.Length) - 1; }

    void ResetToOrPushTab(int tabIx) {
        int found = tabStack.Find(tabIx);
        if (found >= 0) {
            // Truncate stack to this tab
            tabStack.Resize(found + 1);
            trace("Truncated tab stack to length: " + (found + 1));
        } else {
            // Jumping to a new tab, push it
            tabStack.InsertLast(tabIx);
            trace("Pushed new tab to stack: " + tabIx + "; new length: " + tabStack.Length);
        }
    }

    void JumpToTab(int tabIx) {
        if (tabIx < 0 || tabIx >= int(tabNames.Length)) {
            warn("JumpToTab: Invalid tab index: " + tabIx + ". Valid range is 0 to " + (tabNames.Length - 1));
            return;
        }
        ResetToOrPushTab(tabIx);
    }

    protected bool _skipNextBackFwdButtons = false;
    void SkipNextBackFwdButtons() {
        _skipNextBackFwdButtons = true;
    }

    bool nextNavButtonDisabled = false;
    void SetNextNavButtonDisabled(bool disabled = true) {
        nextNavButtonDisabled = disabled;
    }

    void Draw() {
        if (tabNames.Length == 0) {
            UI::Text("\\f80 No Tabs! This is a bug. D:");
            return;
        }
        // Draw tab bar for only the active stack
        UI::BeginTabBar("WizardTabs");
        for (int i = 0; i < int(tabStack.Length); i++) {
            int tabIx = tabStack[i];
            bool isActive = (i == int(tabStack.Length) - 1);
            UI::BeginDisabled(!isActive);
            if (UI::BeginTabItem(tabNames[tabIx], UI::TabItemFlags::NoCloseWithMiddleMouseButton | (isActive ? UI::TabItemFlags::SetSelected : UI::TabItemFlags::None))) {
                // if (i < int(tabStack.Length - 1)) {
                //     // Going back resets wizard to this step
                //     trace("Active tab stack ix " + i + " < " + (tabStack.Length - 1) + ". Truncated tab stack to length: " + (i + 1));
                //     tabStack.Resize(i + 1);
                // }
                UI::EndTabItem();
            }
            UI::EndDisabled();
        }
        UI::EndTabBar();

        // Draw current tab content
        if (tabInnerRenders[currentTab] !is null) tabInnerRenders[currentTab]();

        if (_skipNextBackFwdButtons) {
            _skipNextBackFwdButtons = false;
            return; // Skip the next back/forward buttons
        }

        UI::Separator();

        if (!IsFirstTab) {
            if (UI::Button(Icons::ArrowLeft + " Back")) {
                tabStack.Resize(tabStack.Length - 1);
            }
            UI::SameLine();
        }
        if (!IsLastTab) {
            UI::BeginDisabled(nextNavButtonDisabled);
            if (UI::Button("Next " + Icons::ArrowRight)) {
                ResetToOrPushTab(currentTab + 1);
            }
            UI::EndDisabled();
        }
        nextNavButtonDisabled = false; // reset always
    }
}
