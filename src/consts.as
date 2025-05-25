const double TAU = 6.28318530717958647692;
const double PI = TAU / 2.;
const double HALF_PI = TAU / 4.;
const double NegPI = PI * -1.0;

const int TWO_BILLION = 2000000000;

const vec3 UP = vec3(0, 1, 0);
const vec3 DOWN = vec3(0, -1, 0);
const vec3 LEFT = vec3(-1, 0, 0);
const vec3 RIGHT = vec3(1, 0, 0);
const vec3 FORWARD = vec3(0, 0, -1);
const vec3 BACKWARD = vec3(0, 0, 1);

float g_scale = UI::GetScale();
