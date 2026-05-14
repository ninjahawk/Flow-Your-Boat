shader_type canvas_item;

uniform float direction   = -1.0;
uniform float is_active   = 0.0;
uniform float flip_t      = 0.0;
uniform vec2  gate_size   = vec2(158.0, 60.0);
uniform float corner_r    = 14.0;

float sd_rbox(vec2 p, vec2 b, float r) {
    vec2 q = abs(p) - b + r;
    return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - r;
}

// Signed distance to a line segment
float sd_segment(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a;
    vec2 ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h);
}

void fragment() {
    vec2 px   = (UV - 0.5) * gate_size;
    vec2 half = gate_size * 0.5;
    float d   = sd_rbox(px, half, corner_r);
    float shape = smoothstep(1.5, -1.5, d);

    // Background
    float pulse = sin(TIME * 5.5) * 0.5 + 0.5;
    vec3 bg = vec3(0.20, 0.22, 0.34);
    bg = mix(bg, bg * 1.6, is_active * pulse * 0.5);

    // Subtle horizontal scan shimmer
    float scan = step(0.75, fract(px.y * 0.16 + TIME * 0.35)) * 0.05 * is_active;
    bg += vec3(scan);

    // Arrow: flip based on direction and flip animation
    float fd  = direction * (1.0 - flip_t * 2.0);
    vec2  ap  = vec2(px.x * fd, px.y);

    // Chevron as two thick line segments meeting at a tip
    float aw  = gate_size.x * 0.22;   // half-width of chevron arm
    float ah  = gate_size.y * 0.36;   // half-height
    vec2 tip  = vec2(aw, 0.0);
    vec2 wt   = vec2(-aw * 0.6,  ah);
    vec2 wb   = vec2(-aw * 0.6, -ah);

    float thick = 3.5;
    float dt    = sd_segment(ap, tip, wt) - thick;
    float db    = sd_segment(ap, tip, wb) - thick;
    float arrow = smoothstep(1.5, -1.5, min(dt, db));

    float ab   = is_active > 0.5 ? (0.80 + pulse * 0.20) : 0.78;
    bg = mix(bg, vec3(ab), arrow * shape);

    // Active energy border
    float border = (1.0 - smoothstep(0.0, 4.5, abs(d))) * is_active * pulse * 0.7;
    bg = mix(bg, vec3(0.55, 0.68, 1.0), border);

    float outer = exp(-max(d, 0.0) * 0.16) * is_active * pulse * 0.28;
    float a     = clamp(shape + outer, 0.0, 1.0);
    COLOR = vec4(bg, a);
}
