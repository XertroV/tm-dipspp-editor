namespace CM_Editor {
    class MapInfoComponent : ProjectComponent {
        MapInfoComponent(ProjectMeta@ meta) {
            super("", meta);
            name = "Map Info";
            icon = Icons::MapO;
            type = EProjectComponent::MapInfo;
            // doesn't have a file; set to true to skip initializaiton and checks
            hasFile = true;
        }

        void SaveToFile() override {
            // MapInfo does nothing here
        }

        void DrawComponentInner(ProjectTab@ pTab) override {
            auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
            auto map = editor.Challenge;

            UI::Text("Map UID: " + map.Id.GetName());
            UI::Text("Map Name: " + map.MapName);
            UI::Text("Map Author: " + map.AuthorNickName);
            UI::Text("Map Comments:");
            UI::PushFont(UI::Font::DefaultMono);
            UI::TextWrapped(map.Comments);
            UI::PopFont();
            UI::Separator();
        }
    }
}
