namespace Tests {
    void Minigames_AssertHasMessage(CM_Editor::MinigameIssue@[]@ issues, const string &in want, const string &in label) {
        for (uint i = 0; i < issues.Length; i++) {
            if (issues[i].message == want) return;
        }
        throw(label + ": missing '" + want + "' (have " + issues.Length + ")");
    }

    void Minigames_AssertNoMessage(CM_Editor::MinigameIssue@[]@ issues, const string &in banned, const string &in label) {
        for (uint i = 0; i < issues.Length; i++) {
            if (issues[i].message == banned) throw(label + ": unexpected '" + banned + "'");
        }
    }

    [Test]
    void Minigames_TriggerFullyInside(Tests::Context@ ctx) {
        auto @outer = CM_Editor::EditableTrigger(vec3(0, 0, 0), vec3(100, 100, 100), "o", "o");
        auto @inside = CM_Editor::EditableTrigger(vec3(0, 10, 0), vec3(10, 10, 10), "i", "i");
        if (!CM_Editor::TriggerFullyInside(outer, inside)) throw("expected inside");
        auto @outside = CM_Editor::EditableTrigger(vec3(80, 10, 0), vec3(10, 10, 10), "x", "x");
        if (CM_Editor::TriggerFullyInside(outer, outside)) throw("expected outside");
    }

    [Test]
    void Minigames_DefaultPlacement(Tests::Context@ ctx) {
        auto @t = CM_Editor::EditableTrigger();
        if (!CM_Editor::IsDefaultPlacement(t)) throw("new trigger is default");
        t.posBottomCenter = vec3(400, 20, 80);
        if (CM_Editor::IsDefaultPlacement(t)) throw("moved trigger is not default");
    }

    [Test]
    void Minigames_NewTimeTrialNeedsInit(Tests::Context@ ctx) {
        auto @tt = CM_Editor::TimeTrialMinigame("New TimeTrial Minigame");
        tt.slug = "TimeTrial-1";
        CM_Editor::MinigameIssue@[] issues;
        tt.CollectIssues(issues);
        Minigames_AssertHasMessage(issues, "bounds not set", "bounds");
        Minigames_AssertHasMessage(issues, "start not set", "start");
        Minigames_AssertHasMessage(issues, "end not set", "end");
        Minigames_AssertNoMessage(issues, "start is outside bounds", "start inside default cube");
    }

    [Test]
    void Minigames_StartEndOutsideDefaultBounds(Tests::Context@ ctx) {
        auto @tt = CM_Editor::TimeTrialMinigame("tt");
        tt.slug = "TimeTrial-1";
        auto @p = cast<CM_Editor::TimeTrialMinigameParams@>(tt.params);
        p.startTrigger.posBottomCenter = vec3(1000, 80, 1000);
        p.startTrigger.size = vec3(8, 8, 8);
        p.endTrigger.posBottomCenter = vec3(1400, 80, 1000);
        p.endTrigger.size = vec3(8, 8, 8);
        CM_Editor::MinigameIssue@[] issues;
        tt.CollectIssues(issues);
        Minigames_AssertHasMessage(issues, "bounds not set", "bounds");
        Minigames_AssertHasMessage(issues, "start is outside bounds", "start");
        Minigames_AssertHasMessage(issues, "end is outside bounds", "end");
    }

    [Test]
    void Minigames_ValidLayoutHasNoIssues(Tests::Context@ ctx) {
        auto @tt = CM_Editor::TimeTrialMinigame("tt");
        tt.slug = "TimeTrial-1";
        tt.bounds.posBottomCenter = vec3(200, 0, 0);
        tt.bounds.size = vec3(400, 200, 400);
        auto @p = cast<CM_Editor::TimeTrialMinigameParams@>(tt.params);
        p.startTrigger.posBottomCenter = vec3(50, 8, 0);
        p.startTrigger.size = vec3(10, 8, 10);
        p.endTrigger.posBottomCenter = vec3(300, 8, 0);
        p.endTrigger.size = vec3(10, 8, 10);
        CM_Editor::MinigameIssue@[] issues;
        tt.CollectIssues(issues);
        if (issues.Length != 0) throw("expected none, got " + issues.Length + " first=" + issues[0].message);
    }
}
