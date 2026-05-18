#include <flutter/runtime_effect.glsl>

uniform vec2 u_resolution;
uniform float u_time;
uniform float u_amplitude;
uniform vec4 u_color_1;
uniform vec4 u_color_2;
uniform vec4 u_color_3;
uniform vec4 u_color_4;

uniform float u_speed; // P1
uniform float u_zoom;  // P2

out vec4 fragColor;

// SRGB transforms from John Novak / NVIDIA
#define SRGB_TO_LINEAR(c) pow((c), vec3(2.2))
#define LINEAR_TO_SRGB(c) pow((c), vec3(1.0 / 2.2))

// Gradient noise from Jorge Jimenez's presentation
float gradientNoise(in vec2 uv) {
    const vec3 magic = vec3(0.06711056, 0.00583715, 52.9829189);
    return fract(magic.z * fract(dot(uv, magic.xy)));
}

void main() {
    float speedConf = u_speed == 0.0 ? 1.0 : u_speed;

    vec2 fragCoord = FlutterFragCoord();
    
    float t_anim = u_time * 0.5 * speedConf;

    // Use custom colors or default to the Shadertoy defaults
    vec3 color1 = u_color_1.a == 0.0 ? vec3(1.0, 0.0, 114.0/255.0) : u_color_1.rgb;
    vec3 color2 = u_color_2.a == 0.0 ? vec3(197.0/255.0, 1.0, 80.0/255.0) : u_color_2.rgb;

    // Linearize for accurate mathematical blending
    vec3 linearCol1 = SRGB_TO_LINEAR(color1);
    vec3 linearCol2 = SRGB_TO_LINEAR(color2);

    // Make the gradient line slowly spin natively to make it dynamic
    vec2 center = u_resolution.xy * 0.5;
    float spread = max(u_resolution.x, u_resolution.y) * 0.6;
    
    vec2 a = center + vec2(cos(t_anim), sin(t_anim)) * spread;
    vec2 b = center - vec2(cos(t_anim), sin(t_anim)) * spread;

    // Calculate interpolation factor with vector projection.
    vec2 ba = b - a;
    float t = dot(fragCoord - a, ba) / dot(ba, ba);
    
    // Add audio modulation: warp the gradient plane physically when bass hits!
    t += sin(fragCoord.x * 0.01 + t_anim) * (u_amplitude * 0.2);

    // Saturate and apply smoothstep to the factor.
    t = smoothstep(0.0, 1.0, clamp(t, 0.0, 1.0));
    
    // Interpolate in Linear Space.
    vec3 color = mix(linearCol1, linearCol2, t);

    // Convert color from linear to sRGB color space (=gamma encode).
    color = LINEAR_TO_SRGB(color);

    // Add gradient noise to reduce banding.
    color += (1.0/255.0) * gradientNoise(fragCoord) - (0.5/255.0);
    
    // Subtle overall beat brightness surge
    color += u_amplitude * 0.05;

    fragColor = vec4(color, 1.0);
}
