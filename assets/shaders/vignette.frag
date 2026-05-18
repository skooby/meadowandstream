#include <flutter/runtime_effect.glsl>

uniform vec2 u_resolution;
uniform float u_time;
uniform float u_amplitude;
uniform vec4 u_color_1;
uniform vec4 u_color_2;
uniform vec4 u_color_3;
uniform vec4 u_color_4;
uniform float u_intensity; // Custom P1 mapped
uniform float u_spread;    // Custom P2 mapped
uniform float u_p3;

out vec4 fragColor;

void main() {
    // 1. Get current pixel coordinate and normalized UV (0.0 to 1.0)
    vec2 fragCoord = FlutterFragCoord();
    vec2 uv = fragCoord.xy / u_resolution.xy;
   
    // 2. Compute vignette distance curve 
    uv *= 1.0 - uv.yx;
    
    // 3. Optional fallbacks for variables (15.0 and 0.25 default)
    float intensity = u_intensity == 0.0 ? 15.0 : u_intensity;
    float spread = u_spread == 0.0 ? 0.25 : u_spread;

    // 4. Calculate Vignette brightness
    float vig = uv.x * uv.y * intensity;
    vig = pow(vig, spread);

    // 5. Convert to an Overlay (Transparent in center, solid at edges)
    float alpha = clamp(1.0 - vig, 0.0, 1.0);
    
    // 6. Inherit JSON base color (Defaults to black if not provided)
    vec3 vColor = u_color_1.a == 0.0 ? vec3(0.0, 0.0, 0.0) : u_color_1.rgb;

    // Output transparent center + darkened edges
    fragColor = vec4(vColor * alpha, alpha); // Premultiplied alpha required by Flutter
}
