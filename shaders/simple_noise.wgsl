// Simple 2D Noise Shader
@fragment
fn fs_main(@builtin(position) fragCoord: vec4<f32>) -> @location(0) vec4<f32> {
  let uv = fragCoord.xy / uniforms.resolution;
  let anim_uv = uv * 10.0 + uniforms.time * 0.5;
  let noise = hash21(anim_uv);
  return vec4<f32>(vec3<f32>(noise), 1.0);
}

// Hash function: pseudo-random number from 2D input
fn hash21(seed: vec2<f32>) -> f32 {
  return fract(sin(dot(seed, vec2f(12.9898, 78.233))) * 43758.5453123);
}
