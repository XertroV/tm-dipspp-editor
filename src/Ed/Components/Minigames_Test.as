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

    void Minigames_Place(CM_Editor::EditableTrigger@ t, const vec3 &in pos, const vec3 &in size) {
        t.posBottomCenter = pos;
        t.size = size;
        t.hasBeenSet = true;
    }

    Json::Value@ Minigames_Vec3(const vec3 &in v) {
        auto j = Json::Array();
        j.Add(v.x);
        j.Add(v.y);
        j.Add(v.z);
        return j;
    }

    CM_Editor::ProjectMinigamesComponent@ Minigames_EmptyComp() {
        auto meta = CM_Editor::ProjectMeta("minigames-test");
        return CM_Editor::ProjectMinigamesComponent("", meta);
    }

    CM_Editor::Minigame@ Minigames_PlacedSprint() {
        auto @mg = CM_Editor::Minigame("tt", CM_Editor::MinigameKind::Sprint);
        mg.slug = "Sprint-1";
        mg.useCustomBounds = true;
        Minigames_Place(mg.bounds, vec3(200, 0, 0), vec3(400, 200, 400));
        Minigames_Place(mg.start, vec3(50, 8, 0), vec3(10, 8, 10));
        Minigames_Place(mg.end, vec3(300, 8, 0), vec3(10, 8, 10));
        return mg;
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
    void Minigames_NewSprintNeedsStartEnd(Tests::Context@ ctx) {
        auto @mg = CM_Editor::Minigame("New Sprint", CM_Editor::MinigameKind::Sprint);
        mg.slug = "Sprint-1";
        CM_Editor::MinigameIssue@[] issues;
        mg.CollectIssues(issues);
        Minigames_AssertNoMessage(issues, "bounds not set", "bounds optional");
        Minigames_AssertHasMessage(issues, "start not set", "start");
        Minigames_AssertHasMessage(issues, "end not set", "end");
        Minigames_AssertNoMessage(issues, "start is outside bounds", "start inside default cube");
    }

    [Test]
    void Minigames_StartEndOutsideDefaultBounds(Tests::Context@ ctx) {
        auto @mg = CM_Editor::Minigame("tt", CM_Editor::MinigameKind::Sprint);
        mg.slug = "Sprint-1";
        Minigames_Place(mg.start, vec3(1000, 80, 1000), vec3(8, 8, 8));
        Minigames_Place(mg.end, vec3(1400, 80, 1000), vec3(8, 8, 8));
        CM_Editor::MinigameIssue@[] issues;
        mg.CollectIssues(issues);
        Minigames_AssertNoMessage(issues, "bounds not set", "omit default");
        Minigames_AssertHasMessage(issues, "start is outside bounds", "start");
        Minigames_AssertHasMessage(issues, "end is outside bounds", "end");
    }

    [Test]
    void Minigames_ValidSprintHasNoIssues(Tests::Context@ ctx) {
        auto @mg = Minigames_PlacedSprint();
        CM_Editor::MinigameIssue@[] issues;
        mg.CollectIssues(issues);
        if (issues.Length != 0) throw("expected none, got " + issues.Length + " first=" + issues[0].message);
    }

    [Test]
    void Minigames_SprintToJsonShape(Tests::Context@ ctx) {
        auto @mg = Minigames_PlacedSprint();
        auto j = mg.ToJson();
        if (string(j["kind"]) != "Sprint") throw("kind");
        if (j.HasKey("type")) throw("must not write type int");
        if (j.HasKey("puzzle")) throw("omit false puzzle");
        if (!j.HasKey("start")) throw("start on game");
        if (!j.HasKey("bounds")) throw("custom bounds written");
        if (j["start"].HasKey("name")) throw("start zone is pos/size only");
        if (!j["params"].HasKey("end")) throw("end in params");
        if (j["params"].HasKey("startTrigger")) throw("start must not be in params");
        if (j["params"].HasKey("endTrigger")) throw("endTrigger retired");
        if (j["params"]["checkpoints"].Length != 0) throw("empty cps");
        if (float(j["start"]["pos"][0]) != 50) throw("start pos");
        if (float(j["params"]["end"]["pos"][0]) != 300) throw("end pos");
    }

    [Test]
    void Minigames_DefaultBoundsOmitted(Tests::Context@ ctx) {
        auto @mg = CM_Editor::Minigame("s", CM_Editor::MinigameKind::Sprint);
        mg.slug = "Sprint-1";
        Minigames_Place(mg.start, vec3(50, 8, 0), vec3(10, 8, 10));
        Minigames_Place(mg.end, vec3(80, 8, 0), vec3(10, 8, 10));
        auto j = mg.ToJson();
        if (j.HasKey("bounds")) throw("default bounds must be omitted");
    }

    [Test]
    void Minigames_DefaultSlugAndDuplicate(Tests::Context@ ctx) {
        auto @comp = Minigames_EmptyComp();
        auto @a = CM_Editor::Minigame("a", CM_Editor::MinigameKind::Sprint);
        auto @b = CM_Editor::Minigame("b", CM_Editor::MinigameKind::Sprint);
        auto @c = CM_Editor::Minigame("c", CM_Editor::MinigameKind::Survival);
        Minigames_Place(a.start, vec3(50, 8, 0), vec3(10, 8, 10));
        Minigames_Place(a.end, vec3(80, 8, 0), vec3(10, 8, 10));
        Minigames_Place(b.start, vec3(50, 8, 0), vec3(10, 8, 10));
        Minigames_Place(b.end, vec3(80, 8, 0), vec3(10, 8, 10));
        Minigames_Place(c.start, vec3(50, 8, 0), vec3(10, 8, 10));
        comp.AddMinigame(a);
        comp.AddMinigame(b);
        comp.AddMinigame(c);
        if (a.slug != "Sprint-1") throw("want Sprint-1, got " + a.slug);
        if (b.slug != "Sprint-2") throw("want Sprint-2, got " + b.slug);
        if (c.slug != "Survival-1") throw("want Survival-1, got " + c.slug);
        b.slug = "Sprint-1";
        CM_Editor::MinigameIssue@[] issues;
        comp.CollectIssues(issues);
        Minigames_AssertHasMessage(issues, "duplicate slug", "dup");
    }

    [Test]
    void Minigames_LoadOldIntKinds(Tests::Context@ ctx) {
        auto @comp = Minigames_EmptyComp();
        auto root = Json::Object();
        auto games = Json::Array();

        auto tt = Json::Object();
        tt["name"] = "legacy tt";
        tt["type"] = 1;
        auto ttParams = Json::Object();
        auto start = Json::Object();
        start["pos"] = Minigames_Vec3(vec3(50, 8, 0));
        start["size"] = Minigames_Vec3(vec3(10, 8, 10));
        auto end = Json::Object();
        end["pos"] = Minigames_Vec3(vec3(80, 8, 0));
        end["size"] = Minigames_Vec3(vec3(10, 8, 10));
        ttParams["startTrigger"] = start;
        ttParams["endTrigger"] = end;
        tt["params"] = ttParams;
        games.Add(tt);

        auto ja = Json::Object();
        ja["name"] = "legacy darts";
        ja["type"] = 3;
        games.Add(ja);

        auto tog = Json::Object();
        tog["name"] = "legacy tog";
        tog["type"] = 5;
        games.Add(tog);

        auto puzzle = Json::Object();
        puzzle["name"] = "legacy puzzle";
        puzzle["type"] = 6;
        auto steps = Json::Array();
        auto step = Json::Object();
        step["nextHint"] = "look up";
        step["hintImage"] = "clues/one.png";
        auto stepTrig = Json::Object();
        stepTrig["pos"] = Minigames_Vec3(vec3(60, 8, 0));
        stepTrig["size"] = Minigames_Vec3(vec3(8, 8, 8));
        step["trigger"] = stepTrig;
        steps.Add(step);
        auto pParams = Json::Object();
        pParams["steps"] = steps;
        puzzle["params"] = pParams;
        games.Add(puzzle);

        root["games"] = games;
        comp.LoadGamesFromJson(root);
        if (comp.minigames.Length != 4) throw("want 4, got " + comp.minigames.Length);

        auto @s = comp.minigames[0];
        if (s.kind != CM_Editor::MinigameKind::Sprint) throw("tt kind");
        if (s.puzzle) throw("tt not puzzle");
        if (s.start.posBottomCenter.x != 50) throw("tt start from startTrigger");
        if (s.end.posBottomCenter.x != 80) throw("tt end from endTrigger");
        auto sj = s.ToJson();
        if (string(sj["kind"]) != "Sprint") throw("tt publish Sprint");
        if (sj.HasKey("type")) throw("tt must not rewrite type");

        auto @d = comp.minigames[1];
        if (d.kind != CM_Editor::MinigameKind::Darts) throw("JumpAccuracy -> Darts");

        auto @surv = comp.minigames[2];
        if (surv.kind != CM_Editor::MinigameKind::Survival) throw("TimeOffGround -> Survival");
        if (!surv.airborne) throw("TimeOffGround sets airborne");
        auto survJ = surv.ToJson();
        if (!bool(survJ["airborne"])) throw("airborne flag published");

        auto @pz = comp.minigames[3];
        if (pz.kind != CM_Editor::MinigameKind::Sprint) throw("PuzzleLocations -> Sprint");
        if (!pz.puzzle) throw("PuzzleLocations sets puzzle");
        if (pz.checkpoints.Length != 1) throw("steps -> checkpoints");
        if (pz.checkpoints[0].text != "look up") throw("nextHint -> text");
        if (pz.checkpoints[0].image != "clues/one.png") throw("hintImage -> image");
        auto pzJ = pz.ToJson();
        if (!bool(pzJ["puzzle"])) throw("puzzle flag published");
        if (string(pzJ["params"]["checkpoints"][0]["text"]) != "look up") throw("clue text");
    }

    [Test]
    void Minigames_PuzzleCheckpointClues(Tests::Context@ ctx) {
        auto @mg = Minigames_PlacedSprint();
        mg.puzzle = true;
        auto @cp = CM_Editor::MinigameCheckpoint();
        Minigames_Place(cp.trigger, vec3(100, 8, 0), vec3(8, 8, 8));
        cp.trigger.name = "Clue A";
        cp.text = "read me";
        cp.image = "clues/a.png";
        cp.audio = "clues/a.ogg";
        mg.checkpoints.InsertLast(cp);
        auto j = mg.ToJson();
        if (!bool(j["puzzle"])) throw("puzzle");
        auto cj = j["params"]["checkpoints"][0];
        if (string(cj["name"]) != "Clue A") throw("cp name");
        if (string(cj["text"]) != "read me") throw("text");
        if (string(cj["image"]) != "clues/a.png") throw("image");
        if (string(cj["audio"]) != "clues/a.ogg") throw("audio");
        mg.puzzle = false;
        auto j2 = mg.ToJson();
        if (j2.HasKey("puzzle")) throw("omit false puzzle");
        if (j2["params"]["checkpoints"][0].HasKey("text")) throw("clues only when puzzle");
    }

    [Test]
    void Minigames_SurvivalStartMustSitInsideBounds(Tests::Context@ ctx) {
        auto @mg = CM_Editor::Minigame("hill", CM_Editor::MinigameKind::Survival);
        mg.slug = "Survival-1";
        mg.useCustomBounds = true;
        Minigames_Place(mg.bounds, vec3(200, 0, 0), vec3(400, 200, 400));
        Minigames_Place(mg.start, vec3(1000, 80, 1000), vec3(8, 8, 8));
        CM_Editor::MinigameIssue@[] issues;
        mg.CollectIssues(issues);
        Minigames_AssertHasMessage(issues, "start is outside bounds", "survival start");
        auto j = mg.ToJson();
        if (string(j["kind"]) != "Survival") throw("kind");
        if (j["params"].HasKey("end")) throw("Survival params empty");
        if (j.HasKey("airborne")) throw("omit false airborne");
    }

    [Test]
    void Minigames_SurvivalInsideBoundsOk(Tests::Context@ ctx) {
        auto @mg = CM_Editor::Minigame("hill", CM_Editor::MinigameKind::Survival);
        mg.slug = "Survival-1";
        Minigames_Place(mg.start, vec3(50, 8, 0), vec3(10, 8, 10));
        CM_Editor::MinigameIssue@[] issues;
        mg.CollectIssues(issues);
        if (issues.Length != 0) throw("omitted bounds centred on start, got " + issues.Length + " first=" + issues[0].message);
        auto j = mg.ToJson();
        if (j.HasKey("bounds")) throw("omit default");
        if (j["params"].HasKey("end")) throw("empty params");
        if (j["params"].HasKey("checkpoints")) throw("empty params");
    }

    [Test]
    void Minigames_HighJumpLongJumpEmptyParams(Tests::Context@ ctx) {
        auto @hj = CM_Editor::Minigame("hj", CM_Editor::MinigameKind::HighJump);
        hj.slug = "HighJump-1";
        Minigames_Place(hj.start, vec3(50, 8, 0), vec3(10, 8, 10));
        auto hjJ = hj.ToJson();
        if (string(hjJ["kind"]) != "HighJump") throw("hj kind");
        if (hjJ["params"].HasKey("end")) throw("hj empty");
        if (!hjJ.HasKey("start")) throw("hj start");

        auto @lj = CM_Editor::Minigame("lj", CM_Editor::MinigameKind::LongJump);
        lj.slug = "LongJump-1";
        Minigames_Place(lj.start, vec3(50, 8, 0), vec3(10, 8, 10));
        auto ljJ = lj.ToJson();
        if (string(ljJ["kind"]) != "LongJump") throw("lj kind");
        if (ljJ["params"].HasKey("end")) throw("lj empty");
        CM_Editor::MinigameIssue@[] issues;
        hj.CollectIssues(issues);
        if (issues.Length != 0) throw("hj issues " + issues[0].message);
    }

    [Test]
    void Minigames_DartsParams(Tests::Context@ ctx) {
        auto @mg = CM_Editor::Minigame("board", CM_Editor::MinigameKind::Darts);
        mg.slug = "Darts-1";
        Minigames_Place(mg.start, vec3(50, 8, 0), vec3(10, 8, 10));
        Minigames_Place(mg.bullseye, vec3(80, 12, 40), vec3(1, 1, 1));
        Minigames_Place(mg.plane, vec3(80, 12, 32), vec3(1, 1, 1));
        mg.planeNormal = vec3(0, 0, 1);
        CM_Editor::MinigameIssue@[] issues;
        mg.CollectIssues(issues);
        if (issues.Length != 0) throw("darts issues " + issues[0].message);
        auto j = mg.ToJson();
        if (string(j["kind"]) != "Darts") throw("kind");
        if (float(j["params"]["bullseye"]["pos"][0]) != 80) throw("bullseye");
        if (!j["params"]["plane"].HasKey("normal")) throw("plane.normal");
        if (float(j["params"]["plane"]["normal"][2]) != 1) throw("normal z");
        if (j["params"].HasKey("end")) throw("no end");
    }

    [Test]
    void Minigames_DartsNeedsBullseyeAndPlane(Tests::Context@ ctx) {
        auto @mg = CM_Editor::Minigame("board", CM_Editor::MinigameKind::Darts);
        mg.slug = "Darts-1";
        Minigames_Place(mg.start, vec3(50, 8, 0), vec3(10, 8, 10));
        CM_Editor::MinigameIssue@[] issues;
        mg.CollectIssues(issues);
        Minigames_AssertHasMessage(issues, "bullseye not set", "bullseye");
        Minigames_AssertHasMessage(issues, "plane not set", "plane");
    }

    [Test]
    void Minigames_MaxAvgSpeedEnd(Tests::Context@ ctx) {
        auto @mg = CM_Editor::Minigame("mas", CM_Editor::MinigameKind::MaxAvgSpeed);
        mg.slug = "MaxAvgSpeed-1";
        Minigames_Place(mg.start, vec3(50, 8, 0), vec3(10, 8, 10));
        Minigames_Place(mg.end, vec3(80, 8, 0), vec3(10, 8, 10));
        auto j = mg.ToJson();
        if (string(j["kind"]) != "MaxAvgSpeed") throw("kind");
        if (!j["params"].HasKey("end")) throw("end");
        if (j["params"].HasKey("checkpoints")) throw("no cps");
        CM_Editor::MinigameIssue@[] issues;
        mg.CollectIssues(issues);
        if (issues.Length != 0) throw("mas issues " + issues[0].message);
    }

    [Test]
    void Minigames_LoadKindStrings(Tests::Context@ ctx) {
        auto j = Json::Object();
        j["name"] = "s";
        j["kind"] = "Sprint";
        j["puzzle"] = true;
        auto start = Json::Object();
        start["pos"] = Minigames_Vec3(vec3(10, 8, 10));
        start["size"] = Minigames_Vec3(vec3(8, 8, 8));
        j["start"] = start;
        auto params = Json::Object();
        params["end"] = start;
        params["checkpoints"] = Json::Array();
        j["params"] = params;
        auto @mg = CM_Editor::Minigame(j);
        if (mg.kind != CM_Editor::MinigameKind::Sprint) throw("kind");
        if (!mg.puzzle) throw("puzzle flag");
        if (mg.start.posBottomCenter.x != 10) throw("shared start");
        if (string(mg.ToJson()["kind"]) != "Sprint") throw("roundtrip");
    }
}
