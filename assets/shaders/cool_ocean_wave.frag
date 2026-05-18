#include <flutter/runtime_effect.glsl>

uniform vec2 u_resolution;
uniform float u_time;
uniform float u_amplitude;
uniform vec4 u_color_1;
uniform vec4 u_color_2;
uniform vec4 u_color_3;
uniform vec4 u_color_4;
      // Audio reacting master amp
uniform float u_wave_speed;     // Custom index 4 (from JSON)
uniform float u_wave_height;    // Custom index 5 (from JSON)
uniform float u_glow_intensity; // Custom index 6 (from JSON)

out vec4 fragColor;

void main() {
    // Get fragment coordinate mapped to 0 -> 1 based on resolution
    vec2 fragCoord = FlutterFragCoord();
    vec2 uv = fragCoord.xy / u_resolution.xy;
    
    // Scale amplitude
    float ampBoost = u_amplitude * 2.0;

    // Use custom uniforms with fallbacks in case they are 0.0 (not provided in JSON)
    float speedConf = u_wave_speed == 0.0 ? 1.0 : u_wave_speed;
    float heightConf = u_wave_height == 0.0 ? 1.0 : u_wave_height;
    float glowConf = u_glow_intensity == 0.0 ? 1.0 : u_glow_intensity;

    // Calculate steady phase based purely on time and speed config.
    // Adding amplitude to the phase causes instant horizontal jumping (jitter) on beats.
    float wavePhaseFast = u_time * speedConf * 3.0;
    float wavePhaseSlow = -(u_time * speedConf * 1.5);
    
    // Apply amplitude ONLY to the vertical scale/height of the wave
    float waveFast = sin(uv.x * 15.0 + wavePhaseFast) * heightConf * (0.03 + (ampBoost * 0.1));
    float waveSlow = sin(uv.x * 5.0 + wavePhaseSlow) * heightConf * (0.08 + (ampBoost * 0.05));
    uv.y += waveFast + waveSlow;

    // Base color gradient mixing deep ocean blue and surface aqua
    vec3 oceanBottom = vec3(0.01, 0.05, 0.15);
    vec3 oceanTop = vec3(0.0, 0.5, 0.8) + (vec3(0.1, 0.3, 0.5) * ampBoost);
    vec3 color = mix(oceanTop, oceanBottom, uv.y);
    
    // Calculate a glowing ripple exactly at the surface line
    float surfaceGlow = smoothstep(0.45, 0.5, uv.y) * smoothstep(0.55, 0.5, uv.y);
    vec3 glowColor = vec3(0.4, 0.9, 1.0) * surfaceGlow * glowConf * (1.5 + ampBoost * 3.0);

    // Output final color mixed with glow
    fragColor = vec4(color + glowColor, max(0.4, 1.0 - uv.y) + (ampBoost * 0.2));
}
