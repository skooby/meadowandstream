#include <flutter/runtime_effect.glsl>

uniform vec2 u_resolution;
uniform float u_time;
uniform float u_amplitude;
uniform vec4 u_color_1;
uniform vec4 u_color_2;
uniform vec4 u_color_3;
uniform vec4 u_color_4;

uniform float u_speed; // P1
uniform float u_complexity; // P2
uniform float u_zoom;  // P3
uniform float u_strands; // P4

out vec4 fragColor;

// Cosine based palette, see Inigo Quilez
vec3 palette( in float t ) {
    vec3 a = length(u_color_1.rgb) > 0.0 ? u_color_1.rgb : vec3(0.5, 0.5, 0.5);
    vec3 b = vec3(0.5, 0.5, 0.5);
    vec3 c = vec3(1.0, 1.0, 1.0);
    vec3 d = length(u_color_2.rgb) > 0.0 ? u_color_2.rgb : vec3(0.263, 0.416, 0.557);
    return a + b * cos( 6.28318 * (c * t + d) );
}

void main() {
    float speed = u_speed == 0.0 ? 1.0 : u_speed;
    float zoom = u_zoom == 0.0 ? 1.0 : u_zoom;
    float strands = u_strands == 0.0 ? 8.0 : u_strands;
    float complexity = u_complexity == 0.0 ? 3.0 : max(1.0, u_complexity);
    
    // Wire Audio amplitude directly into the visual structural scale natively
    zoom -= (u_amplitude * 0.25);
    speed += (u_amplitude * 0.5);
    
    // Center UV horizontally and vertically
    vec2 fragCoord = FlutterFragCoord();
    vec2 uv = (fragCoord * 2.0 - u_resolution.xy) / u_resolution.y;
    uv *= zoom;
    
    vec2 uv0 = uv;
    vec3 finalColor = vec3(0.0);
    
    for (float i = 0.0; i < 10.0; i++) {
        if (i >= complexity) break;
        uv = fract(uv * 1.5) - 0.5;
        float d = length(uv) * exp(-length(uv0));
        
        vec3 col = palette(length(uv0) + u_time * 0.4 * speed + i * .4);
        
        // Connect strands constraint dynamically natively to math wrapper
        d = sin(d * strands + u_time * speed) / strands;
        d = abs(d);
        
        // Intensity glow
        d = pow(0.01 / d, 1.2);
        
        // Multiply intensity bounce locally mapped to Audio Reactive track constraint uniformly
        finalColor += col * d * (1.0 + u_amplitude * 1.5);
    }
    
    // Apply final base opacity (alpha 1.0 for background layer)
    fragColor = vec4(finalColor, 1.0);
}
