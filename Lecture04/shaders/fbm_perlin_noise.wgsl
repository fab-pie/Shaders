// FBM (Fractal Brownian Motion) Perlin 2D Noise Shader
@fragment
fn fs_main(@builtin(position) fragCoord: vec4<f32>) -> @location(0) vec4<f32> {
  let uv = fragCoord.xy / uniforms.resolution;
  let anim_uv = uv * 4.0 + uniforms.time * 0.05;
  let noise = fbm(anim_uv, 6) * 0.5 + 0.5;
  return vec4<f32>(vec3<f32>(noise), 1.0);
}

// Fractal Brownian Motion
fn fbm(p: vec2<f32>, octaves: i32) -> f32 {
  var value = 0.0;
  var amp = 0.5;
  var freq = 1.0;
  var max_value = 0.0;
  var pos = p;

  for (var i = 0; i < octaves; i++) {
    value += perlin2d(pos * freq) * amp;
    max_value += amp;
    amp *= 0.5;
    freq *= 2.0;

    // Rotate to reduce artifacts
    pos = vec2f(
      pos.x * 0.866 - pos.y * 0.5 + 1.618,
      pos.x * 0.5 + pos.y * 0.866 + 3.141
    );
  }

  return value / max_value;
}

// 2D Perlin noise
fn perlin2d(p: vec2<f32>) -> f32 {
  let pi = floor(p);
  let pf = fract(p);
  let u = fade(pf);

  // Corner coordinates
  let tli = pi + vec2f(0.0, 0.0);
  let tlf = pf - vec2f(0.0, 0.0);
  let tri = pi + vec2f(0.0, 1.0);
  let trf = pf - vec2f(0.0, 1.0);
  let bli = pi + vec2f(1.0, 0.0);
  let blf = pf - vec2f(1.0, 0.0);
  let bri = pi + vec2f(1.0, 1.0);
  let brf = pf - vec2f(1.0, 1.0);

  // Corner gradients
  let n00 = dot(gradientHash22(tli), tlf);
  let n01 = dot(gradientHash22(tri), trf);
  let n10 = dot(gradientHash22(bli), blf);
  let n11 = dot(gradientHash22(bri), brf);

  // Bilinear interpolation
  let nx0 = mix(n00, n10, u.x);
  let nx1 = mix(n01, n11, u.x);

  return mix(nx0, nx1, u.y);
}

// Fade function
fn fade(t: vec2<f32>) -> vec2<f32> {
  return t * t * t * (t * (t * 6.0 - 15.0) + 10.0);
}

// Gradient hash
fn gradientHash22(p: vec2<f32>) -> vec2<f32> {
  let n = hash21(p);
  let angle = n * 6.28318530718;
  return vec2<f32>(cos(angle), sin(angle));
}

// Hash function
fn hash21(seed: vec2<f32>) -> f32 {
  return fract(sin(dot(seed, vec2f(12.9898, 78.233))) * 43758.5453123);
}
