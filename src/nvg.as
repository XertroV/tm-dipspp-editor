
void nvgDrawRect(vec2 pos, vec2 size) {
    nvg::BeginPath();
    nvg::FillColor(cLimeGreen50);
    nvg::StrokeColor(cMagenta);
    nvg::Rect(pos, size);
    nvg::Fill();
    nvg::Stroke();
    nvg::ClosePath();
}

void nvgDrawCircle(vec2 pos) {
    nvg::BeginPath();
    nvg::FillColor(cGreen);
    nvg::StrokeColor(cMagenta);
    nvg::Circle(pos, 10);
    nvg::Fill();
    nvg::Stroke();
    nvg::ClosePath();
}


// this does not seem to be expensive
const float nTextStrokeCopies = 12;

vec2 nvgDrawTextWithStroke(const vec2 &in pos, const string &in text, vec4 textColor = vec4(1), float strokeWidth = 2., vec4 strokeColor = cBlack75) {
    nvg::FontBlur(1.0);
    if (strokeWidth > 0.1) {
        nvg::FillColor(strokeColor);
        for (float i = 0; i < nTextStrokeCopies; i++) {
            float angle = TAU * float(i) / nTextStrokeCopies;
            vec2 offs = vec2(Math::Sin(angle), Math::Cos(angle)) * strokeWidth;
            nvg::Text(pos + offs, text);
        }
    }
    nvg::FontBlur(0.0);
    nvg::FillColor(textColor);
    nvg::Text(pos, text);
    // don't return with +strokeWidth b/c it means we can't turn stroke on/off without causing readjustments in the UI
    return nvg::TextBounds(text);
}
