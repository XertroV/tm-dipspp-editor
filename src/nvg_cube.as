const vec3[] cubeVertices = {
    vec3(0, 0, 0),
    vec3(1, 0, 0),
    vec3(1, 1, 0),
    vec3(0, 1, 0),
    vec3(0, 0, 1),
    vec3(1, 0, 1),
    vec3(1, 1, 1),
    vec3(0, 1, 1)
};

const int2[] cubeEdges = {
    int2(0, 1),
    int2(1, 2),
    int2(2, 3),
    int2(3, 0),
    int2(4, 5),
    int2(5, 6),
    int2(6, 7),
    int2(7, 4),
    int2(0, 4),
    int2(1, 5),
    int2(2, 6),
    int2(3, 7)
};

const uint[][] cubeFaces = {
    {0, 1, 2, 3},
    {4, 5, 6, 7},
    {0, 1, 5, 4},
    {2, 3, 7, 6},
    {1, 2, 6, 5},
    {0, 3, 7, 4}
};

const vec3[] cubeNormals = {
    vec3(0, 0, -1),
    vec3(0, 0, 1),
    vec3(0, -1, 0),
    vec3(0, 1, 0),
    vec3(1, 0, 0),
    vec3(-1, 0, 0)
};

void drawCubeFace(const mat4 &in m, uint faceIx, const vec4 &in col = cSkyBlue50) {
    vec3 p0 = (m * cubeVertices[cubeFaces[faceIx][0]]).xyz;
    auto camPos = Camera::GetCurrentPosition();
    vec3 dirToCam = (camPos - p0).Normalized();
    auto camDot = Math::Dot((cubeNormals[faceIx]), dirToCam);
    bool facingCam = camDot >= 0;

    nvg::Reset();
    nvg::LineCap(nvg::LineCapType::Round);
    nvg::LineJoin(nvg::LineCapType::Round);
    nvg::BeginPath();
    nvg::StrokeWidth(facingCam ? 2.0 : 1.0);
    nvg::StrokeColor(facingCam ? cWhite : cBlack25);
    if (facingCam) nvg::FillColor(Math::Lerp(cLimeGreen50, cSkyBlue50, camDot * .5 + .5));
    else nvg::FillColor(vec4(0));
    // trace("camDot: " + camDot);
    nvgMoveToWorldPos(p0);
    for (uint i = 1; i < 4; i++) {
        vec3 p = (m * cubeVertices[cubeFaces[faceIx][i]]).xyz;
        nvgLineToWorldPos(p);
    }
    nvgLineToWorldPos(p0);
    // if (facingCam)
    nvg::Fill();
    nvg::Stroke();
    nvg::ClosePath();

    return;

    // nvg::BeginPath();
    // nvg::StrokeWidth(facingCam ? 2.0 : 0.0);
    // auto midpoint = (m * getFaceMidpoint(faceIx)).xyz;
    // nvgMoveToWorldPos(midpoint);
    // nvgLineToWorldPos(midpoint + cubeNormals[faceIx] * 8.);
    // nvg::Stroke();
    // nvg::ClosePath();
}


uint[]@ getCubeFaceBackToFront(const mat4 &in m) {
    uint[] faceOrder = {0, 1, 2, 3, 4, 5};
    vec3 camPos = Camera::GetCurrentPosition();
    vec3 dirToCam = (camPos - (m * cubeVertices[0]).xyz).Normalized();

    float[] faceDists = {
        Math::Dot(dirToCam, cubeNormals[0]),
        Math::Dot(dirToCam, cubeNormals[1]),
        Math::Dot(dirToCam, cubeNormals[2]),
        Math::Dot(dirToCam, cubeNormals[3]),
        Math::Dot(dirToCam, cubeNormals[4]),
        Math::Dot(dirToCam, cubeNormals[5])
    };

    float tf;
    uint tu;
    for (uint i = 0; i < 6; i++) {
        for (uint j = i + 1; j < 6; j++) {
            if (faceDists[i] > faceDists[j]) {
                tf = faceDists[i];
                faceDists[i] = faceDists[j];
                faceDists[j] = tf;
                tu = faceOrder[i];
                faceOrder[i] = faceOrder[j];
                faceOrder[j] = tu;
            }
        }
    }

    return faceOrder;
}


vec3 getFaceMidpoint(uint faceIx) {
    vec3 sum = vec3();
    for (uint i = 0; i < 4; i++) {
        sum += cubeVertices[cubeFaces[faceIx][i]];
    }
    return sum / 4.;
}

void nvgDrawRect3d(vec3 pos, vec3 size, const vec4 &in col = cSkyBlue50) {
    mat4 m = mat4::Translate(pos) * mat4::Scale(size);
    auto faceOrder = getCubeFaceBackToFront(m);
    for (uint i = 0; i < 6; i++) {
        drawCubeFace(m, faceOrder[i], col);
    }
}











bool nvgWorldPosLastVisible = false;
vec3 nvgLastWorldPos = vec3();
vec3 nvgLastUv = vec3();

void nvgWorldPosReset() {
    nvgWorldPosLastVisible = false;
}

void nvgToWorldPos(vec3 &in pos, vec4 &in col = vec4(1)) {
    nvgLastWorldPos = pos;
    nvgLastUv = Camera::ToScreen(pos);
    if (nvgLastUv.z > 0) {
        nvgWorldPosLastVisible = false;
        return;
    }
    if (nvgWorldPosLastVisible)
        nvg::LineTo(nvgLastUv.xy);
    else
        nvg::MoveTo(nvgLastUv.xy);
    nvgWorldPosLastVisible = true;
    nvg::StrokeColor(col);
    nvg::Stroke();
    nvg::ClosePath();
    nvg::BeginPath();
    nvg::MoveTo(nvgLastUv.xy);
}

void nvgMoveToWorldPos(vec3 pos) {
    nvgLastWorldPos = pos;
    nvgLastUv = Camera::ToScreen(pos);
    if (nvgLastUv.z > 0) {
        nvgWorldPosLastVisible = false;
        return;
    }
    nvg::MoveTo(nvgLastUv.xy);
    nvgWorldPosLastVisible = true;
}

void nvgLineToWorldPos(vec3 pos) {
    nvgLastWorldPos = pos;
    nvgLastUv = Camera::ToScreen(pos);
    if (nvgLastUv.z > 0) {
        nvgWorldPosLastVisible = false;
        return;
    }
    nvg::LineTo(nvgLastUv.xy);
    nvgWorldPosLastVisible = true;
}
