
namespace UrlCache {
    dictionary cache;
    bool IsKnownGood(const string &in url) {
        return cache.Exists(url);
    }
    void AddKnownGood(const string &in url) {
        cache.Set(url, true);
    }

    bool RunCheckUrl(const string &in url) {
        if (RequestHead_Exists(url)) {
            cache.Set(url, true);
            return true;
        }
        return false;
    }
}

class UrlChecks {
    // 0 = not started, 1 = in progress, 2 = failed, 3 = passed
    int8[] urlChecks;
    bool isStale = false;
    uint nbTotal = 0;
    uint nbInProgress = 0;
    uint nbStarted = 0;
    uint nbPassed = 0;
    uint nbFailed = 0;
    // keys used for queue + dedup
    dictionary urlQueue;
    string[] FailedUrls;

    UrlChecks() {}

    bool Passes(uint nbChecks) {
        if (isStale) return false;
        if (nbChecks != urlChecks.Length) {
            isStale = true;
            return false;
        }
        return nbFailed == 0 && nbInProgress == 0
            && nbPassed == nbChecks && nbTotal == nbChecks
            && FailedUrls.Length == 0 && urlQueue.GetSize() == 0;
    }

    void SetStale() {
        isStale = true;
    }

    bool IsStaleAndReady() {
        return isStale && !isRunning;
    }

    void Reset() {
        urlChecks.Resize(0);
        FailedUrls.Resize(0);
        urlQueue.DeleteAll();
        nbStarted = 0;
        nbTotal = 0;
        nbInProgress = 0;
        nbPassed = 0;
        nbFailed = 0;
        isStale = false;
    }

    void AddUrlCheck(const string &in url) {
        if (UrlCache::IsKnownGood(url)) {
            nbTotal++;
            nbPassed++;
            nbStarted++;
            urlChecks.InsertLast(3);
            return;
        } else {
            if (urlQueue.Exists(url)) {
                return;
            }
            urlQueue.Set(url, true);
            nbTotal++;
        }
    }

    void StartRun() {
        if (isRunning) return;
        startnew(CoroutineFunc(this.Run));
    }

    bool isRunning = false;
    void Run() {
        if (isRunning) return;
        isRunning = true;
        isStale = false;
        auto urls = urlQueue.GetKeys();
        urlQueue.DeleteAll();
        Meta::PluginCoroutine@[]@ coros = {};
        print("Starting URL checks: " + urls.Length);
        for (uint i = 0; i < urls.Length; i++) {
            coros.InsertLast(startnew(CoroutineFuncUserdataString(this.RunUrlHeadCheck), urls[i]));
            sleep(50);
            // check if we got invalidated
            if (isStale) {
                warn("URL check invalidated, aborting.");
                return;
            }
        }
        await(coros);
        isRunning = false;
    }

    void RunUrlHeadCheck(const string &in url) {
        // make sure we didn't get invalidated
        if (isStale) return;

        auto ix = urlChecks.Length;
        urlChecks.InsertLast(1);
        nbInProgress++;
        nbStarted++;

        auto isGood = UrlCache::RunCheckUrl(url);
        // check if these results are going to be invalidated.
        if (isStale) return;

        nbInProgress--;
        if (isGood) {
            nbPassed++;
            urlChecks[ix] = 3;
        } else {
            nbFailed++;
            urlChecks[ix] = 2;
            FailedUrls.InsertLast(url);
        }
    }

    void DrawProgressBars() {
        float rStarted = float(nbStarted) / float(nbTotal);
        float rInProgress = float(nbInProgress) / float(nbTotal);
        float rPassed = float(nbPassed) / float(nbTotal);
        float rFailed = float(nbFailed) / float(nbTotal);
        UI::PushStyleColor(UI::Col::PlotHistogram, vec4(.3, .5, .6, 1));
        UI::ProgressBar(rStarted, vec2(-1, 0), "Started");
        UI::PopStyleColor();
        UI::PushStyleColor(UI::Col::PlotHistogram, vec4(.25, .55, 1, 1));
        UI::ProgressBar(rInProgress, vec2(-1, 0), "In Prog: " + nbInProgress + " / " + nbTotal);
        UI::PopStyleColor();
        UI::PushStyleColor(UI::Col::PlotHistogram, vec4(.25, 1, .55, 1));
        UI::ProgressBar(rPassed, vec2(-1, 0), "Passed: " + nbPassed + " / " + nbTotal);
        UI::PopStyleColor();
        UI::PushStyleColor(UI::Col::PlotHistogram, vec4(1, .35, .25, 1));
        UI::ProgressBar(rFailed, vec2(-1, 0), "Failed: " + nbFailed + " / " + nbTotal);
        UI::PopStyleColor();
    }

    string StatusText() {
        return "" + nbTotal + " / " + nbStarted + " // " + nbInProgress
             + " / \\$<\\$f44" + nbFailed + "\\$> / \\$4f8" + nbPassed;
    }
}



bool RequestHead_Exists(const string &in url) {
    Net::HttpRequest@ req = RequestHead(url, true);
    while (!req.Finished()) yield();
    auto status = req.ResponseCode();
    trace("Response code: " + status);
    return (status - (status % 100)) == 200
        && req.ResponseHeader("content-length").Length > 1 // no files less than 10 bytes
    ;
}

Net::HttpRequest@ RequestHead(const string &in url, bool autostart = true) {
    Net::HttpRequest@ req = Net::HttpRequest();
    req.Url = url;
    req.Method = Net::HttpMethod::Head;
    if (autostart) req.Start();
    return req;
}
