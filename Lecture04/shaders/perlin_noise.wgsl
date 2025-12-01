// Perlin 2D Noise Shader
@fragment
fn fs_main(@builtin(position) fragCoord: vec4<f32>) -> @location(0) vec4<f32> {
  let uv = fragCoord.xy / uniforms.resolution;
  let anim_uv = uv * 10.0 + uniforms.time * 0.5;
  let noise = perlin2d(anim_uv) * 0.5 + 0.5;
  return vec4<f32>(vec3<f32>(noise), 1.0);
}

// 2D Perlin noise
fn perlin2d(p: vec2<f32>) -> f32 {
  // Grid cell coordinates
  let pi = floor(p);
  let pf = fract(p);

  // Fade curves for interpolation
  let u = fade(pf);

  // Corner coordinates
  let tli = pi + vec2<f32>(0.0, 0.0);
  let tlf = pf - vec2<f32>(0.0, 0.0);
  let tri = pi + vec2<f32>(0.0, 1.0);
  let trf = pf - vec2<f32>(0.0, 1.0);
  let bli = pi + vec2<f32>(1.0, 0.0);
  let blf = pf - vec2<f32>(1.0, 0.0);
  let bri = pi + vec2<f32>(1.0, 1.0);
  let brf = pf - vec2<f32>(1.0, 1.0);

  // Hash coordinates of the 4 square corners
  let n00 = dot(gradientHash22(tli), tlf);
  let n01 = dot(gradientHash22(tri), trf);
  let n10 = dot(gradientHash22(bli), blf);
  let n11 = dot(gradientHash22(bri), brf);

  // Bilinear interpolation
  let nx0 = mix(n00, n10, u.x);
  let nx1 = mix(n01, n11, u.x);
  let nxy = mix(nx0, nx1, u.y);

  return nxy;
}

// Fade function for smooth interpolation
fn fade(t: vec2<f32>) -> vec2<f32> {
  return t * t * t * (t * (t * 6.0 - 15.0) + 10.0);
}

// Generate pseudo-random gradient vector from integer coordinates
fn gradientHash22(p: vec2<f32>) -> vec2<f32> {
  let n = hash21(p);
  let angle = fract(n) * 6.28318530718; // 2 * PI
  return vec2<f32>(cos(angle), sin(angle));
}

// Hash function: pseudo-random number from 2D input
fn hash21(seed: vec2<f32>) -> f32 {
  return fract(sin(dot(seed, vec2<f32>(12.9898, 78.233))) * 43758.5453123);
}
