shader_type canvas_item;

uniform vec4  item_color  : source_color = vec4(1.0, 0.3, 0.3, 1.0);
uniform vec2  item_size   = vec2(72.0, 62.0);
uniform float corner_r    = 12.0;
uniform float approach    = 0.0;   // 0-1: brightens as item nears gate
uniform float flash       = 0.0;   // 0-1: white/red pulse on success/fail
uniform float flash_ok    = 1.0;   // 1=success white, 0=fail red
uniform float item_type   = 0.0;   // 0=normal 1=rush 2=bomb 3=drain
uniform float spawn_scale = 1.0;
uniform float type_pulse  = 0.0;   // 0-1: secondary animated ring for special types

// Signed distance: rounded box centered at origin
float sd_rbox(vec2 p, vec2 b, float r) {
    vec2 q = abs(p) - b + r;
    return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - r;
}

void fragment() {
    // Map UV to pixel space centered at origin
    vec2 px = (UV - 0.5) * item_size;
    vec2 half = item_size * 0.5;

    float d = sd_rbox(px, half, corner_r);

    // ---- Shape & base alpha ----
    float shape = smoothstep(1.5, -1.5, d);
    float outer_glow = exp(-max(d, 0.0) * 0.13) * (0.18 + approach * 0.55);

    // ---- Rim lighting ----
    float rim = (1.0 - smoothstep(0.0, 5.0, abs(d))) * shape;

    // ---- Inner highlight (top-left soft spot) ----
    vec2 hl = px + half * vec2(-0.35, -0.38);
    float highlight = exp(-dot(hl, hl) * 0.0028) * 0.35 * shape;

    // ---- Bottom edge shadow ----
    float shadow = smoothstep(-6.0, 6.0, px.y - half.y * 0.5) * shape * 0.3;

    // ---- Base color assembly ----
    vec3 col = item_color.rgb;
    col = mix(col, min(col * 2.2 + 0.15, vec3(1.0)), rim * 0.65);
    col += vec3(highlight);
    col -= vec3(shadow * 0.3);
    col  = mix(col, min(col * 1.5, vec3(1.0)), approach * 0.35);

    // ---- RUSH: animated diagonal speed stripes ----
    if (item_type > 0.5 && item_type < 1.5) {
        float stripe = step(0.5, fract((px.x - px.y * 0.6) * 0.065 + TIME * 1.4));
        col = mix(col, min(col + vec3(0.4), vec3(1.0)), stripe * 0.30 * shape);
        // Extra orange tint
        col = mix(col, vec3(1.0, 0.6, 0.1), 0.18 * shape);
        // Speed lines at top
        float speed_line = step(0.85, fract(px.y * 0.08 + TIME * 3.0)) *
                           step(abs(px.x), half.x * 0.5);
        col = mix(col, vec3(1.0), speed_line * 0.5 * shape);
    }

    // ---- BOMB: pulsing warning rings + dark tint ----
    if (item_type > 1.5 && item_type < 2.5) {
        float rings = sin(length(px) * 0.55 - TIME * 5.0) * 0.5 + 0.5;
        rings = pow(rings, 3.0);
        col = mix(col, vec3(1.0, 0.1, 0.05), rings * 0.35 * shape);
        col = mix(col, col * 0.75, 0.4 * shape);  // darken
        // Skull-ish X mark
        float cross1 = smoothstep(2.0, 0.0, abs(px.x - px.y * 0.7));
        float cross2 = smoothstep(2.0, 0.0, abs(px.x + px.y * 0.7));
        float cross  = max(cross1, cross2) * step(length(px), 14.0) * shape;
        col = mix(col, vec3(1.0), cross * 0.5);
    }

    // ---- DRAIN: downward arrow chevrons + cyan shimmer ----
    if (item_type > 2.5) {
        // Downward-moving chevron lines
        float chevron = step(0.5, fract(
            (px.y - abs(px.x) * 0.5) * 0.09 - TIME * 1.8
        )) * shape;
        col = mix(col, vec3(0.3, 1.0, 0.9), chevron * 0.45);
        col = mix(col, col * 1.2 + vec3(0.05, 0.15, 0.2), 0.3 * shape);
    }

    // ---- Flash overlay (success=white, fail=red) ----
    vec3 flash_col = mix(vec3(1.0, 0.1, 0.1), vec3(1.0), flash_ok);
    col = mix(col, flash_col, flash * 0.75);

    // ---- Type indicator ring (for RUSH/BOMB/DRAIN) ----
    if (item_type > 0.5) {
        float ring_r = length(px / (half * 1.1));
        float ring   = smoothstep(0.07, 0.0, abs(ring_r - 1.0));
        float pulse  = sin(TIME * 6.0 + item_type * 2.0) * 0.4 + 0.6;
        col = mix(col, vec3(1.0), ring * pulse * 0.4 * shape);
    }

    float a = clamp(shape + outer_glow, 0.0, 1.0);
    COLOR = vec4(col, a);
}
