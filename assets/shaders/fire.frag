#include <flutter/runtime_effect.glsl>

uniform vec2 u_resolution;
uniform float u_time;
uniform float u_amplitude;
uniform vec4 u_color_1;
uniform vec4 u_color_2;
uniform vec4 u_color_3;
uniform vec4 u_color_4;

uniform float u_fire_speed;    // P1
uniform float u_fire_intensity;// P2
uniform float u_heat_scale;    // P3

out vec4 fragColor;

float rand(vec2 n) { 
    return fract(sin(dot(n, vec2(12.9898, 4.1414))) * 43758.5453);
}

float noise(vec2 n) {
    const vec2 d = vec2(0.0, 1.0);
    vec2 b = floor(n), f = smoothstep(vec2(0.0), vec2(1.0), fract(n));
    return mix(mix(rand(b), rand(b + d.yx), f.x), mix(rand(b + d.xy), rand(b + d.yy), f.x), f.y);
}

float fbm(vec2 n) {
    float total = 0.0, amp = 1.0;
    for (int i = 0; i < 4; i++) {
        total += noise(n) * amp;
        n += n;
        amp *= 0.5;
    }
    return total;
}

void main() {
    float speed = u_fire_speed == 0.0 ? 1.0 : u_fire_speed;
    float intensity = u_fire_intensity == 0.0 ? 1.0 : u_fire_intensity;
    float heat = u_heat_scale == 0.0 ? 1.0 : u_heat_scale;

    vec2 fragCoord = FlutterFragCoord();
    vec2 uv = fragCoord.xy / u_resolution.xy;
    
    // Reverse Y so flame goes UP
    float q = uv.y;
    
    // Add x-axis turbulence and audio scaling
    // Modulate horizontal push with amplitude so the fire dances on bass hits
    float ampBoost = u_amplitude * 0.3 * heat;
    vec2 p = vec2(uv.x * 3.0, q * 3.0 - (u_time * speed * 2.0));
    
    float n = fbm(p);
    
    // Shape the flame based on height, making the bottom solid and top wispy
    float c = 1.0 - 16.0 * pow(max(0.0, length(vec2(uv.x - 0.5, uv.y)) - 0.25 - ampBoost), 2.0);
    
    // Core fire intensity mask
    float c1 = n * c * (1.5 - pow(q, 3.0));
    c1 = clamp(c1, 0.0, 1.0);

    // Color gradient mappings
    // Generates a rich black -> red -> orange -> yellow -> white burn scaling
    vec3 col = vec3(1.5 * c1, 1.5 * c1 * c1 * c1, c1 * c1 * c1 * c1 * c1 * c1);
    
    // Add a small injection of pure white core when bass hits the absolute max peak
    col += vec3(1.0, 1.0, 1.0) * max(0.0, (u_amplitude - 0.8) * 5.0) * c1;

    // Output transparent correctly for stacking
    fragColor = vec4(col * intensity, c1 * intensity);
}
