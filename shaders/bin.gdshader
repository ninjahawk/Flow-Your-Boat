shader_type canvas_item;

uniform vec4  bin_color   : source_color = vec4(1.0, 0.3, 0.3, 1.0);
uniform vec2  bin_size    = vec2(110.0, 90.0);
uniform float corner_r    = 16.0;
uniform float pressure    = 0.0;
uniform float pulse_flash = 0.0;
uniform float flash_ok    = 1.0;
uniform float disabled_t  = 0.0;

float sd_rbox(vec2 p, vec2 b, float r) {
    vec2 q = abs(p) - b + r;
    return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - r;
}

void fragment() {
    vec2  px    = (UV - 0.5) * bin_size;
    vec2  half  = bin_size * 0.5;
    float d     = sd_rbox(px, half, corner_r);
    float shape = smoothstep(1.5, -1.5, d);

    // ---- Background ----
    vec3 bg = vec3(0.22, 0.23, 0.36);

    // ---- Color tint on background (always present, makes each bin identifiable) ----
    bg = mix(bg, bg + bin_color.rgb * 0.12, shape);

    // ---- Pressure fill (wavy liquid from bottom) ----
    float wave    = sin(px.x * 0.14 + TIME * 2.8) * 3.0 * pressure;
    float fill_y  = UV.y;                         // 0=top 1=bottom
    float fill_edge = 1.0 - pressure;
    float in_fill = smoothstep(fill_edge + 0.04, fill_edge - 0.04,
                               fill_y + wave / bin_size.y) * shape;

    vec3 fill_col = bin_color.rgb * 0.5;
    if (pressure > 0.65) {
        float danger = (pressure - 0.65) / 0.35;
        fill_col = mix(fill_col, vec3(1.0, 0.15, 0.05), danger);
        fill_col *= (0.75 + sin(TIME * 9.0) * 0.25);
    }
    bg = mix(bg, fill_col, in_fill * 0.7);

    // ---- Color swatch circle ----
    float cr = min(bin_size.x, bin_size.y) * 0.25;   // bigger swatch
    float cd = length(px + vec2(0.0, bin_size.y * 0.06)) - cr;
    float circle = smoothstep(1.5, -1.5, cd);
    // Swatch highlight
    float shl = smoothstep(cr * 0.5, 0.0,
        length(px + vec2(-cr * 0.28, -cr * 0.32 + bin_size.y * 0.06)));
    vec3 swatch = mix(bin_color.rgb, min(bin_color.rgb * 2.0, vec3(1.0)), shl * 0.55);
    bg = mix(bg, swatch, circle * shape);

    // ---- Border — always visible, colored ----
    float bw = pressure > 0.65 ?
        (4.5 + sin(TIME * 9.0) * 1.5) : 3.5;
    float border = (1.0 - smoothstep(0.0, bw, abs(d))) * shape;
    vec3 bc = pressure > 0.65 ?
        mix(bin_color.rgb, vec3(1.0, 0.1, 0.05),
            (pressure - 0.65) / 0.35 * (sin(TIME * 9.0) * 0.5 + 0.5)) :
        bin_color.rgb;
    float ba = 0.90 + pulse_flash * 0.10;
    bg = mix(bg, bc * ba, border);

    // ---- Outer glow (always on, color-matched) ----
    float outer_glow = exp(-max(d, 0.0) * 0.14) * 0.30;

    // ---- Receive flash ----
    vec3 fc = mix(vec3(0.9, 0.1, 0.1), vec3(1.0), flash_ok);
    bg = mix(bg, fc, pulse_flash * 0.30 * shape);

    // ---- Disabled tint ----
    bg = mix(bg, bg * 0.3 + vec3(0.04), disabled_t);

    float a = clamp(shape + outer_glow, 0.0, 1.0);
    COLOR = vec4(bg, a);
}
