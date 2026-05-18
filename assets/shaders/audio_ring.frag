#include <flutter/runtime_effect.glsl>

uniform vec2 u_resolution;
uniform float u_time;
uniform float u_amplitude;
uniform vec4 u_color_1;
uniform vec4 u_color_2;
uniform vec4 u_color_3;
uniform vec4 u_color_4;

uniform float u_ring_radius; // P1
uniform float u_ring_thickness; // P2
uniform float u_rotation_speed; // P3

out vec4 fragColor;

void main() {
    float rad = u_ring_radius == 0.0 ? 0.3 : u_ring_radius;
    float thick = u_ring_thickness == 0.0 ? 0.02 : u_ring_thickness;
    float speed = u_rotation_speed == 0.0 ? 5.0 : u_rotation_speed;

    vec2 fragCoord = FlutterFragCoord();
    vec2 uv = (fragCoord - 0.5 * u_resolution.xy) / u_resolution.y;

    float dist = length(uv);
    float angle = atan(uv.y, uv.x);
    
    // Distort circle mathematically to sound
    // Outer ripple
    float distortion = sin(angle * 10.0 + u_time * speed) * 0.02 * u_amplitude;
    // Inner slower ripple
    distortion += sin(angle * 4.0 - u_time * (speed * 0.5)) * 0.05 * u_amplitude;
    
    // Beat pushes radius out physically
    float radiusTarget = rad + distortion + (u_amplitude * 0.15);
    
    // Standard ring distance 
    float ringMask = smoothstep(thick, 0.0, abs(dist - radiusTarget));
    
    // Vibrant audio glow falloff
    float glowMask = 0.01 / max(0.001, abs(dist - radiusTarget));
    
    // Base and glow colors
    vec3 baseCol = u_color_1.a == 0.0 ? vec3(0.5, 0.8, 1.0) : u_color_1.rgb;
    vec3 glowCol = u_color_2.a == 0.0 ? vec3(0.1, 0.5, 1.0) : u_color_2.rgb;

    // Color mapping
    vec3 color = vec3(ringMask) * baseCol;
    vec3 glowColor = glowCol * glowMask * (0.2 + u_amplitude * 0.8);

    // Alpha channel scales out cleanly for transparency
    fragColor = vec4(color + glowColor, ringMask + (glowMask * 0.5));
}
