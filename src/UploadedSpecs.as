[Setting hidden]
bool S_Window_ViewUploadedSpecs = false;

void RenderUploadedSpecsWindow() {
    if (!S_Window_ViewUploadedSpecs) return;

    UI::SetNextWindowSize(600, 400, UI::Cond::FirstUseEver);
    if (UI::Begin("D++ Editor: Uploaded Specs", S_Window_ViewUploadedSpecs)) {
        UploadedSpecsWindow::DrawInner();
    }
    UI::End();
}

namespace UploadedSpecsWindow {
    UploadedAuxSpec_Base@[] specs;

    int NbCachedSpecs() {
        return specs.Length;
    }


    void DrawInner() {
        // make sure we're connected to the server
        if (!DipsPPConnection::IsConnected()) {
            UI::Text("Dips++ is not connected to the server. :(");
            return;
        }
        // check if we need to do initial load
        StartLoadIfInit();

        // buttons
        UI::BeginDisabled(_loading);
        if (UI::Button("Refresh Specs")) {
            startnew(RefreshList);
        }
        UI::EndDisabled();

        UI::SameLine();
        if (_loading) UI::Text("\\$i\\$888  Loading specs... " + LoadingDuration() + " ms");
        else UI::Text("\\$i\\$888  Last load duration: " + LoadingDuration() + " ms");

        UI::Separator();

        // status and list
        UI::Text("Total Uploaded Specs: " + NbCachedSpecs());

        UI::Separator();

        // list specs
        if (UI::BeginTable("SpecsTable", 2)) {
            UI::ListClipper clip(specs.Length);
            while (clip.Step()) {
                for (int i = clip.DisplayStart; i < clip.DisplayEnd; i++) {
                    auto spec = specs[i];
                    UI::PushID("s-" + i);

                    UI::TableNextRow();
                    UI::TableNextColumn();
                    UI::Text("# " + (i + 1));
                    UI::TableNextColumn();
                    UI::Text("col 2");

                    UI::PopID();
                }
            }
            UI::EndTable();
        }
    }

    bool _hasDoneInitLoad = false;
    void StartLoadIfInit() {
        if (_hasDoneInitLoad) return;
        if (!DipsPPConnection::IsConnected()) return;
        _hasDoneInitLoad = true;
        startnew(RefreshList);
    }

    bool _loading = false;
    int64 _loadingStart = 0, _loadingEnd = 0;
    void _StartLoading() {
        if (_loading) return;
        _loading = true;
        _loadingStart = Time::Now;
        _loadingEnd = 0;
    }
    void _EndLoading() {
        if (!_loading) return;
        _loading = false;
        _loadingEnd = Time::Now;
    }

    void RefreshList() {
        if (_loading) {
            trace("RefreshList: Already loading specs, skipping refresh.");
            return;
        }
        _StartLoading();
        auto w = MyAuxSpecs::List_Async();
        print("Waiter done: " + w.IsDone());
        print("Waiter success: " + w.IsSuccess());
        print("Waiter error: " + w.GetError());
        print("Waiter extra: " + Json::Write(w.GetExtra()));
        auto @_specs = MyAuxSpecs::JsonArrToAuxSpecs(w.GetExtra());
        specs.RemoveRange(0, specs.Length);
        if (_specs is null) {
            warn("RefreshList: No specs returned (should at least be an empty list)");
            _EndLoading();
            return;
        }
        for (uint i = 0; i < _specs.Length; i++) {
            specs.InsertLast(_specs[i]);
        }
        _EndLoading();
    }

    int64 LoadingDuration() {
        if (!_loading) return _loadingEnd - _loadingStart;
        return Time::Now - _loadingStart;
    }
}
