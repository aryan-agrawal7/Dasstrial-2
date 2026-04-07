shader_type canvas_item;

// Corner radius in UV space (0.0 = sharp, ~0.15 = nicely rounded)
uniform float radius : hint_range(0.0, 0.5) = 0.12;

void fragment() {
    vec4 tex = texture(TEXTURE, UV);

    // Map UV to a centered coordinate system (-0.5 to 0.5)
    vec2 pos = abs(UV - 0.5);
    // Corner region starts at (0.5 - radius)
    vec2 corner = max(pos - (0.5 - radius), 0.0);
    // Distance from rounded corner center
    float dist = length(corner);

    // Smooth edge for anti-aliasing
    float aa = fwidth(dist) * 1.5;
    float alpha = 1.0 - smoothstep(radius - aa, radius, dist);

    COLOR = vec4(tex.rgb, tex.a * alpha);
}
