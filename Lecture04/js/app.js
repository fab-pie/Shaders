// WebGPU Shadertoy - Main Application Script

const shaders = {};
let fallbackShader = `// Fragment shader - runs once per pixel
@fragment
fn fs_main(@builtin(position) fragCoord: vec4<f32>) -> @location(0) vec4<f32> {
    // Simple gradient as fallback
    let uv = fragCoord.xy / uniforms.resolution;
    return vec4<f32>(uv, 0.5, 1.0);
}`;

// WGSL syntax highlighting mode
CodeMirror.defineSimpleMode("wgsl", {
  start: [
    { regex: /\b(fn|let|var|const|if|else|for|while|loop|return|break|continue|discard|switch|case|default|struct|type|alias)\b/, token: "keyword" },
    { regex: /\b(bool|i32|u32|f32|f16|vec2|vec3|vec4|mat2x2|mat3x3|mat4x4|array|sampler|texture_2d|texture_3d)\b/, token: "type" },
    { regex: /\b(vec2|vec3|vec4|mat2x2|mat3x3|mat4x4|array)<[^>]+>/, token: "type" },
    { regex: /\b(abs|acos|all|any|asin|atan|atan2|ceil|clamp|cos|cosh|cross|degrees|determinant|distance|dot|exp|exp2|faceforward|floor|fma|fract|frexp|inversesqrt|ldexp|length|log|log2|max|min|mix|modf|normalize|pow|radians|reflect|refract|round|sign|sin|sinh|smoothstep|sqrt|step|tan|tanh|transpose|trunc)\b/, token: "builtin" },
    { regex: /@(vertex|fragment|compute|builtin|location|binding|group|stage|workgroup_size|interpolate|invariant)/, token: "attribute" },
    { regex: /\b\d+\.?\d*[fu]?\b|0x[0-9a-fA-F]+[ul]?/, token: "number" },
    { regex: /\/\/.*/, token: "comment" },
    { regex: /\/\*/, token: "comment", next: "comment" },
    { regex: /[+\-*/%=<>!&|^~?:]/, token: "operator" },
    { regex: /[{}()\[\];,\.]/, token: "punctuation" },
  ],
  comment: [
    { regex: /.*?\*\//, token: "comment", next: "start" },
    { regex: /.*/, token: "comment" },
  ],
});

// Initialize CodeMirror editor
const editor = CodeMirror.fromTextArea(
  document.getElementById("code-editor"),
  {
    mode: "wgsl",
    theme: "gruvbox-dark-hard",
    lineNumbers: true,
    lineWrapping: true,
    value: fallbackShader,
    tabSize: 2,
    indentUnit: 2,
    viewportMargin: Infinity,
    scrollbarStyle: "native",
  },
);
editor.setValue(fallbackShader);

// Global state
let device;
let context;
let pipeline;
let uniformBuffer;
let sceneBuffer;
let bindGroup;
let startTime = performance.now();
let lastFrameTime = startTime;
let frameCount = 0;
let lastFpsUpdate = startTime;
let mouseX = 0;
let mouseY = 0;
let mouseDown = false;
let isPanelOpen = true;
let isFullscreen = false;

// Scene data (4 primitives)
const sceneData = {
  primitives: [
    { type: 0, x: -1.5, y: 0.0, z: 0.0, r: 1.0, g: 0.3, b: 0.3, param1: 0.5, param2: 0.0, param3: 0.0 }, // Sphere
    { type: 1, x: 0.0, y: 0.0, z: 0.0, r: 0.3, g: 1.0, b: 0.3, param1: 0.4, param2: 0.4, param3: 0.4 },   // Box
    { type: 2, x: 1.5, y: 0.0, z: 0.0, r: 0.3, g: 0.3, b: 1.0, param1: 0.5, param2: 0.15, param3: 0.0 },  // Torus
    { type: 3, x: 0.0, y: 0.0, z: 1.5, r: 1.0, g: 1.0, b: 0.3, param1: 0.3, param2: 0.5, param3: 0.0 },   // Cylinder
  ],
  activeIndex: 0
};

// Stickman data (10 body parts) - tous les cylindres sont verticaux (axe Y) par défaut
// Les rotations sont appliquées pour les orienter
const stickmanData = {
  head: { type: 0, x: 0.0, y: 0.85, z: 0.0, r: 0.95, g: 0.85, b: 0.7, param1: 0.15, param2: 0.0, rotX: 0, rotY: 0, rotZ: 0 },
  torso: { type: 3, x: 0.0, y: 0.2, z: 0.0, r: 0.2, g: 0.4, b: 0.8, param1: 0.12, param2: 0.45, rotX: 0, rotY: 0, rotZ: 0 },
  // Bras: position à l'épaule, rotation Z = 90° pour horizontal (T-pose)
  left_upper_arm: { type: 3, x: -0.22, y: 0.5, z: 0.0, r: 0.9, g: 0.6, b: 0.4, param1: 0.06, param2: 0.2, rotX: 0, rotY: 0, rotZ: 90 },
  left_forearm: { type: 3, x: -0.62, y: 0.5, z: 0.0, r: 0.95, g: 0.85, b: 0.7, param1: 0.05, param2: 0.2, rotX: 0, rotY: 0, rotZ: 90 },
  right_upper_arm: { type: 3, x: 0.22, y: 0.5, z: 0.0, r: 0.9, g: 0.6, b: 0.4, param1: 0.06, param2: 0.2, rotX: 0, rotY: 0, rotZ: 90 },
  right_forearm: { type: 3, x: 0.62, y: 0.5, z: 0.0, r: 0.95, g: 0.85, b: 0.7, param1: 0.05, param2: 0.2, rotX: 0, rotY: 0, rotZ: 90 },
  // Jambes: verticales par défaut
  left_thigh: { type: 3, x: -0.15, y: -0.35, z: 0.0, r: 0.2, g: 0.3, b: 0.7, param1: 0.08, param2: 0.3, rotX: 0, rotY: 0, rotZ: 0 },
  left_shin: { type: 3, x: -0.15, y: -0.95, z: 0.0, r: 0.95, g: 0.85, b: 0.7, param1: 0.06, param2: 0.3, rotX: 0, rotY: 0, rotZ: 0 },
  right_thigh: { type: 3, x: 0.15, y: -0.35, z: 0.0, r: 0.2, g: 0.3, b: 0.7, param1: 0.08, param2: 0.3, rotX: 0, rotY: 0, rotZ: 0 },
  right_shin: { type: 3, x: 0.15, y: -0.95, z: 0.0, r: 0.95, g: 0.85, b: 0.7, param1: 0.06, param2: 0.3, rotX: 0, rotY: 0, rotZ: 0 },
  activePart: 0
};

// Poses prédéfinies - utilisant rotations Z pour bras, X pour avant/arrière
const poses = {
  tpose: {
    name: 'T-Pose',
    data: {
      head: { x: 0.0, y: 0.85, z: 0.0, rotX: 0, rotY: 0, rotZ: 0 },
      torso: { x: 0.0, y: 0.2, z: 0.0, rotX: 0, rotY: 0, rotZ: 0 },
      left_upper_arm: { x: -0.22, y: 0.5, z: 0.0, rotX: 0, rotY: 0, rotZ: 90 },
      left_forearm: { x: -0.62, y: 0.5, z: 0.0, rotX: 0, rotY: 0, rotZ: 90 },
      right_upper_arm: { x: 0.22, y: 0.5, z: 0.0, rotX: 0, rotY: 0, rotZ: 90 },
      right_forearm: { x: 0.62, y: 0.5, z: 0.0, rotX: 0, rotY: 0, rotZ: 90 },
      left_thigh: { x: -0.15, y: -0.35, z: 0.0, rotX: 0, rotY: 0, rotZ: 0 },
      left_shin: { x: -0.15, y: -0.95, z: 0.0, rotX: 0, rotY: 0, rotZ: 0 },
      right_thigh: { x: 0.15, y: -0.35, z: 0.0, rotX: 0, rotY: 0, rotZ: 0 },
      right_shin: { x: 0.15, y: -0.95, z: 0.0, rotX: 0, rotY: 0, rotZ: 0 }
    }
  },
  relaxed: {
    name: 'Bras Baissés',
    data: {
      head: { x: 0.0, y: 0.85, z: 0.0, rotX: 0, rotY: 0, rotZ: 0 },
      torso: { x: 0.0, y: 0.2, z: 0.0, rotX: 0, rotY: 0, rotZ: 0 },
      left_upper_arm: { x: -0.22, y: 0.2, z: 0.0, rotX: 0, rotY: 0, rotZ: 0 },
      left_forearm: { x: -0.22, y: -0.2, z: 0.0, rotX: 0, rotY: 0, rotZ: 0 },
      right_upper_arm: { x: 0.22, y: 0.2, z: 0.0, rotX: 0, rotY: 0, rotZ: 0 },
      right_forearm: { x: 0.22, y: -0.2, z: 0.0, rotX: 0, rotY: 0, rotZ: 0 },
      left_thigh: { x: -0.15, y: -0.35, z: 0.0, rotX: 0, rotY: 0, rotZ: 0 },
      left_shin: { x: -0.15, y: -0.95, z: 0.0, rotX: 0, rotY: 0, rotZ: 0 },
      right_thigh: { x: 0.15, y: -0.35, z: 0.0, rotX: 0, rotY: 0, rotZ: 0 },
      right_shin: { x: 0.15, y: -0.95, z: 0.0, rotX: 0, rotY: 0, rotZ: 0 }
    }
  },
  apose: {
    name: 'A-Pose (45°)',
    data: {
      head: { x: 0.0, y: 0.85, z: 0.0, rotX: 0, rotY: 0, rotZ: 0 },
      torso: { x: 0.0, y: 0.2, z: 0.0, rotX: 0, rotY: 0, rotZ: 0 },
      left_upper_arm: { x: -0.22, y: 0.35, z: 0.0, rotX: 0, rotY: 0, rotZ: 45 },
      left_forearm: { x: -0.50, y: 0.07, z: 0.0, rotX: 0, rotY: 0, rotZ: 45 },
      right_upper_arm: { x: 0.22, y: 0.35, z: 0.0, rotX: 0, rotY: 0, rotZ: -45 },
      right_forearm: { x: 0.50, y: 0.07, z: 0.0, rotX: 0, rotY: 0, rotZ: -45 },
      left_thigh: { x: -0.15, y: -0.35, z: 0.0, rotX: 0, rotY: 0, rotZ: 0 },
      left_shin: { x: -0.15, y: -0.95, z: 0.0, rotX: 0, rotY: 0, rotZ: 0 },
      right_thigh: { x: 0.15, y: -0.35, z: 0.0, rotX: 0, rotY: 0, rotZ: 0 },
      right_shin: { x: 0.15, y: -0.95, z: 0.0, rotX: 0, rotY: 0, rotZ: 0 }
    }
  },
  armsup: {
    name: 'Bras en Haut',
    data: {
      head: { x: 0.0, y: 0.85, z: 0.0, rotX: 0, rotY: 0, rotZ: 0 },
      torso: { x: 0.0, y: 0.2, z: 0.0, rotX: 0, rotY: 0, rotZ: 0 },
      left_upper_arm: { x: -0.22, y: 0.85, z: 0.0, rotX: 0, rotY: 0, rotZ: 0 },
      left_forearm: { x: -0.22, y: 1.25, z: 0.0, rotX: 0, rotY: 0, rotZ: 0 },
      right_upper_arm: { x: 0.22, y: 0.85, z: 0.0, rotX: 0, rotY: 0, rotZ: 0 },
      right_forearm: { x: 0.22, y: 1.25, z: 0.0, rotX: 0, rotY: 0, rotZ: 0 },
      left_thigh: { x: -0.15, y: -0.35, z: 0.0, rotX: 0, rotY: 0, rotZ: 0 },
      left_shin: { x: -0.15, y: -0.95, z: 0.0, rotX: 0, rotY: 0, rotZ: 0 },
      right_thigh: { x: 0.15, y: -0.35, z: 0.0, rotX: 0, rotY: 0, rotZ: 0 },
      right_shin: { x: 0.15, y: -0.95, z: 0.0, rotX: 0, rotY: 0, rotZ: 0 }
    }
  }
};

// DOM elements
const $ = (id) => document.getElementById(id);
const canvas = $("canvas");
const errorMsg = $("error-message");
const compileBtn = $("compile-btn");
const fullscreenBtn = $("fullscreen-btn");
const fullscreenEnterIcon = $("fullscreen-enter-icon");
const fullscreenExitIcon = $("fullscreen-exit-icon");
const canvasContainer = $("canvas-container");
const editorContainer = $("editor-container");
const shaderSelector = $("shader-selector");

// Uniform values configuration
const uniforms = {
  resolution: {
    label: "resolution",
    initial: "0 × 0",
    update: (w, h) => `${w} × ${h}`,
  },
  time: {
    label: "time",
    initial: "0.00s",
    update: (t) => `${t.toFixed(2)}s`,
  },
  deltaTime: {
    label: "deltaTime",
    initial: "0.00ms",
    update: (dt) => `${(dt * 1000).toFixed(2)}ms`,
  },
  mousexy: {
    label: "mouse.xy",
    initial: "0, 0",
    update: (x, y) => `${Math.round(x)}, ${Math.round(y)}`,
  },
  mousez: {
    label: "mouse.z",
    initial: '<span class="inline-block w-2 h-2 rounded-full" id="mouse-ind" style="background:#928374"></span>',
    update: (down) => {
      $("mouse-ind").style.background = down ? "#b8bb26" : "#928374";
      return null;
    },
  },
  frame: {
    label: "frame",
    initial: "0",
    update: (f) => f.toString(),
  },
};

// WGSL shader code
const vertexShader = `@vertex
fn vs_main(@builtin(vertex_index) vertexIndex: u32) -> @builtin(position) vec4<f32> {
  var pos = array<vec2<f32>, 3>(vec2<f32>(-1.0, -1.0), vec2<f32>(3.0, -1.0), vec2<f32>(-1.0, 3.0));
  return vec4<f32>(pos[vertexIndex], 0.0, 1.0);
}`;

const uniformsStruct = `struct Uniforms {
  resolution: vec2<f32>, time: f32, deltaTime: f32, mouse: vec4<f32>, frame: u32,
  _padding: u32, _padding2: u32, _padding3: u32,
}

@group(0) @binding(0) var<uniform> uniforms: Uniforms;`;

// Initialize uniforms table
$("uniforms-table").innerHTML = Object.entries(uniforms)
  .map(
    ([key, u]) =>
      `<tr class="border-b" style="border-color:#3c3836"><td class="py-1.5 font-semibold" style="color:#fe8019">${u.label}</td><td class="py-1.5 text-right font-mono" id="u-${key}">${u.initial}</td></tr>`,
  )
  .join("");

// Initialize WebGPU
async function initWebGPU() {
  if (!navigator.gpu)
    return ((errorMsg.textContent = "WebGPU not supported"), false);
  const adapter = await navigator.gpu.requestAdapter();
  if (!adapter) return ((errorMsg.textContent = "No GPU adapter"), false);
  device = await adapter.requestDevice();
  context = canvas.getContext("webgpu");
  const format = navigator.gpu.getPreferredCanvasFormat();
  context.configure({ device, format });
  
  uniformBuffer = device.createBuffer({
    size: 64,
    usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST,
  });
  
  sceneBuffer = device.createBuffer({
    size: 768, // Augmenté pour supporter les rotations (4 vec4 par primitive)
    usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST,
  });
  
  await compileShader(fallbackShader);
  return true;
}

// Compile shader
async function compileShader(fragmentCode) {
  const start = performance.now();
  try {
    errorMsg.classList.add("hidden");
    const code = vertexShader + "\n" + uniformsStruct + "\n" + fragmentCode;
    const shaderModule = device.createShaderModule({ code });
    const info = await shaderModule.getCompilationInfo();
    const lineOffset = (vertexShader + "\n" + uniformsStruct).split("\n").length;
    const errors = info.messages
      .filter((m) => m.type === "error")
      .map((m) => {
        const fragmentLine = m.lineNum - lineOffset;
        return fragmentLine > 0
          ? `Line ${fragmentLine}: ${m.message}`
          : `Line ${m.lineNum}: ${m.message}`;
      })
      .join("\n");
    if (errors)
      return (
        (errorMsg.textContent = "Shader error:\n" + errors),
        errorMsg.classList.remove("hidden")
      );

    const format = navigator.gpu.getPreferredCanvasFormat();
    const bindGroupLayout = device.createBindGroupLayout({
      entries: [
        {
          binding: 0,
          visibility: GPUShaderStage.FRAGMENT,
          buffer: { type: "uniform" },
        },
        {
          binding: 1,
          visibility: GPUShaderStage.FRAGMENT,
          buffer: { type: "uniform" },
        },
      ],
    });
    
    pipeline = device.createRenderPipeline({
      layout: device.createPipelineLayout({
        bindGroupLayouts: [bindGroupLayout],
      }),
      vertex: { module: shaderModule, entryPoint: "vs_main" },
      fragment: {
        module: shaderModule,
        entryPoint: "fs_main",
        targets: [{ format }],
      },
      primitive: { topology: "triangle-list" },
    });
    
    bindGroup = device.createBindGroup({
      layout: bindGroupLayout,
      entries: [
        { binding: 0, resource: { buffer: uniformBuffer } },
        { binding: 1, resource: { buffer: sceneBuffer } },
      ],
    });
    
    $("compile-time").textContent = `${(performance.now() - start).toFixed(2)}ms`;
  } catch (e) {
    errorMsg.textContent = "Compile error: " + e.message;
    errorMsg.classList.remove("hidden");
  }
}

// Render loop
function render() {
  if (!pipeline) return;
  
  const currentTime = performance.now();
  const deltaTime = (currentTime - lastFrameTime) / 1000;
  const elapsedTime = (currentTime - startTime) / 1000;
  const data = [canvas.width, canvas.height, elapsedTime, deltaTime, mouseX, mouseY, mouseDown ? 1 : 0, 0, frameCount, 0, 0, 0];
  device.queue.writeBuffer(uniformBuffer, 0, new Float32Array(data));
  
  // Encode scene data based on active shader
  const activeShader = shaderSelector.value;
  
  if (activeShader === 'stickman.wgsl') {
    // Chaque primitive: 4 vec4 = 16 floats = 64 bytes
    // 10 primitives + 2 padding vec4 = 12 * 16 floats = 192 floats = 768 bytes
    const stickmanArrayBuffer = new ArrayBuffer(768);
    const f32 = new Float32Array(stickmanArrayBuffer);
    let offset = 0;
    
    const parts = ['head', 'torso', 'left_upper_arm', 'left_forearm', 'right_upper_arm', 
                   'right_forearm', 'left_thigh', 'left_shin', 'right_thigh', 'right_shin'];
    
    for (const partName of parts) {
      const part = stickmanData[partName];
      // vec4 pos (xyz = position, w = type)
      f32[offset++] = part.x;
      f32[offset++] = part.y;
      f32[offset++] = part.z;
      f32[offset++] = part.type;
      // vec4 color (rgb = color, a = padding)
      f32[offset++] = part.r;
      f32[offset++] = part.g;
      f32[offset++] = part.b;
      f32[offset++] = 1.0;
      // vec4 params (x = radius, y = height, zw = padding)
      f32[offset++] = part.param1;
      f32[offset++] = part.param2;
      f32[offset++] = 0.0;
      f32[offset++] = 0.0;
      // vec4 rotation (xyz = rotations en degrés, w = padding)
      f32[offset++] = part.rotX || 0.0;
      f32[offset++] = part.rotY || 0.0;
      f32[offset++] = part.rotZ || 0.0;
      f32[offset++] = 0.0;
    }
    
    // Padding pour alignement (2 vec4)
    while (offset < 192) {
      f32[offset++] = 0.0;
    }
    
    device.queue.writeBuffer(sceneBuffer, 0, stickmanArrayBuffer);
  } else {
    const sceneArrayBuffer = new ArrayBuffer(272);
    const f32 = new Float32Array(sceneArrayBuffer);
    let offset = 0;
    
    for (let i = 0; i < 4; i++) {
      const prim = sceneData.primitives[i];
      f32[offset++] = prim.x;
      f32[offset++] = prim.y;
      f32[offset++] = prim.z;
      f32[offset++] = prim.type;
      f32[offset++] = prim.r;
      f32[offset++] = prim.g;
      f32[offset++] = prim.b;
      f32[offset++] = 1.0;
      f32[offset++] = prim.param1;
      f32[offset++] = prim.param2;
      f32[offset++] = prim.param3;
      f32[offset++] = 0.0;
    }
    
    f32[offset++] = sceneData.activeIndex;
    f32[offset++] = 0.0;
    f32[offset++] = 0.0;
    f32[offset++] = 0.0;
    
    while (offset < 68) {
      f32[offset++] = 0.0;
    }
    
    device.queue.writeBuffer(sceneBuffer, 0, sceneArrayBuffer);
  }

  // Update uniforms display
  const val = uniforms.resolution.update(canvas.width, canvas.height);
  if (val) $("u-resolution").textContent = val;
  $("u-time").textContent = uniforms.time.update(elapsedTime);
  $("u-deltaTime").textContent = uniforms.deltaTime.update(deltaTime);
  $("u-mousexy").textContent = uniforms.mousexy.update(mouseX, mouseY);
  $("u-frame").textContent = uniforms.frame.update(frameCount);
  uniforms.mousez.update(mouseDown);

  lastFrameTime = currentTime;

  // Render to canvas
  const encoder = device.createCommandEncoder();
  const pass = encoder.beginRenderPass({
    colorAttachments: [
      {
        view: context.getCurrentTexture().createView(),
        loadOp: "clear",
        clearValue: { r: 0, g: 0, b: 0, a: 1 },
        storeOp: "store",
      },
    ],
  });
  pass.setPipeline(pipeline);
  pass.setBindGroup(0, bindGroup);
  pass.draw(3);
  pass.end();
  device.queue.submit([encoder.finish()]);

  // Update FPS
  if (++frameCount && currentTime - lastFpsUpdate > 100) {
    const fps = Math.round(frameCount / ((currentTime - lastFpsUpdate) / 1_000));
    $("fps").textContent = fps;
    $("frame-time").textContent = `${((currentTime - lastFpsUpdate) / frameCount).toFixed(1)}ms`;
    frameCount = 0;
    lastFpsUpdate = currentTime;
  }
  
  requestAnimationFrame(render);
}

// Utility functions
function resizeCanvas() {
  const container = $("canvas-container");
  const dpr = devicePixelRatio || 1;
  canvas.width = container.clientWidth * dpr;
  canvas.height = container.clientHeight * dpr;
  canvas.style.width = container.clientWidth + "px";
  canvas.style.height = container.clientHeight + "px";
}

function toggleFullscreen() {
  if (
    !document.fullscreenElement &&
    !document.webkitFullscreenElement &&
    !document.mozFullScreenElement &&
    !document.msFullscreenElement
  ) {
    const elem = canvasContainer;
    if (elem.requestFullscreen) {
      elem.requestFullscreen();
    } else if (elem.webkitRequestFullscreen) {
      elem.webkitRequestFullscreen();
    } else if (elem.mozRequestFullScreen) {
      elem.mozRequestFullScreen();
    } else if (elem.msRequestFullscreen) {
      elem.msRequestFullscreen();
    }
  } else {
    if (document.exitFullscreen) {
      document.exitFullscreen();
    } else if (document.webkitExitFullscreen) {
      document.webkitExitFullscreen();
    } else if (document.mozCancelFullScreen) {
      document.mozCancelFullScreen();
    } else if (document.msExitFullscreen) {
      document.msExitFullscreen();
    }
  }
}

function updateFullscreenUI() {
  const fullscreenElement =
    document.fullscreenElement ||
    document.webkitFullscreenElement ||
    document.mozFullScreenElement ||
    document.msFullscreenElement;

  isFullscreen = !!fullscreenElement;
  if (isFullscreen) {
    fullscreenEnterIcon.classList.add("hidden");
    fullscreenExitIcon.classList.remove("hidden");
    editorContainer.style.display = "none";
    canvasContainer.classList.remove("landscape:w-1/2", "portrait:h-1/2");
    canvasContainer.classList.add("w-full", "h-full");
  } else {
    fullscreenEnterIcon.classList.remove("hidden");
    fullscreenExitIcon.classList.add("hidden");
    editorContainer.style.display = "";
    canvasContainer.classList.remove("w-full", "h-full");
    canvasContainer.classList.add("landscape:w-1/2", "portrait:h-1/2");
  }

  setTimeout(resizeCanvas, 50);
}

// Load shaders from files
async function loadShaders() {
  let loadedCount = 0;
  let manifest = null;

  try {
    const manifestResponse = await fetch("./shaders/manifest.json");
    if (manifestResponse.ok) {
      manifest = await manifestResponse.json();
      console.log("Loaded shader manifest");
    }
  } catch (err) {
    console.log("No manifest found, will try loading mouse.wgsl directly");
  }

  const shaderList = manifest?.shaders || [
    { file: "mouse.wgsl", name: "Mouse Interaction" },
  ];

  for (const shaderInfo of shaderList) {
    try {
      const response = await fetch(`./shaders/${shaderInfo.file}`);
      if (response.ok) {
        const content = await response.text();
        shaders[shaderInfo.file] = {
          content: content,
          name: shaderInfo.name || shaderInfo.file.replace(".wgsl", ""),
          description: shaderInfo.description || "",
        };
        loadedCount++;
        console.log(`Loaded shader: ${shaderInfo.file}`);
      }
    } catch (err) {
      console.error(`Failed to load shader ${shaderInfo.file}:`, err);
    }
  }

  if (loadedCount > 0) {
    while (shaderSelector.options.length > 1) {
      shaderSelector.remove(1);
    }

    Object.keys(shaders).forEach((filename) => {
      const option = document.createElement("option");
      option.value = filename;
      option.textContent = shaders[filename].name;
      if (shaders[filename].description) {
        option.title = shaders[filename].description;
      }
      shaderSelector.appendChild(option);
    });

    const firstShader = Object.keys(shaders)[0];
    if (firstShader) {
      fallbackShader = shaders[firstShader].content;
      editor.setValue(fallbackShader);
      shaderSelector.value = firstShader;
    }
  } else {
    console.log("No shaders loaded, using fallback");
  }
}

// Update UI for stickman
// Apply a pose to the stickman
function applyPose(poseName) {
  if (!poses[poseName]) return;
  
  const poseData = poses[poseName].data;
  
  Object.keys(poseData).forEach(partName => {
    if (stickmanData[partName]) {
      const posePartData = poseData[partName];
      stickmanData[partName].x = posePartData.x;
      stickmanData[partName].y = posePartData.y;
      if (posePartData.z !== undefined) stickmanData[partName].z = posePartData.z || 0;
      stickmanData[partName].rotX = posePartData.rotX;
      stickmanData[partName].rotY = posePartData.rotY;
      stickmanData[partName].rotZ = posePartData.rotZ;
    }
  });
  
  updateUIForStickman();
}

function updateUIForStickman() {
  const partName = stickmanSelector.value;
  const part = stickmanData[partName];
  
  objXSlider.value = part.x;
  $("obj-x-value").textContent = part.x.toFixed(1);
  objYSlider.value = part.y;
  $("obj-y-value").textContent = part.y.toFixed(1);
  objZSlider.value = part.z;
  $("obj-z-value").textContent = part.z.toFixed(1);
  
  objParam1Slider.value = part.param1;
  $("obj-param1-value").textContent = part.param1.toFixed(2);
  objParam2Slider.value = part.param2;
  $("obj-param2-value").textContent = part.param2.toFixed(2);
  
  const hexColor = '#' + 
    Math.round(part.r * 255).toString(16).padStart(2, '0') +
    Math.round(part.g * 255).toString(16).padStart(2, '0') +
    Math.round(part.b * 255).toString(16).padStart(2, '0');
  objColorPicker.value = hexColor;
  
  if (partName === 'head') {
    $("param1-label").textContent = "Radius";
    $("param2-container").style.display = "none";
  } else {
    $("param1-label").textContent = "Radius";
    $("param2-label").textContent = "Height";
    $("param2-container").style.display = "block";
  }
}

// Update UI based on selected shape
function updateUIForShape() {
  const idx = sceneData.activeIndex;
  const prim = sceneData.primitives[idx];
  
  objXSlider.value = prim.x;
  $("obj-x-value").textContent = prim.x.toFixed(1);
  objYSlider.value = prim.y;
  $("obj-y-value").textContent = prim.y.toFixed(1);
  objZSlider.value = prim.z;
  $("obj-z-value").textContent = prim.z.toFixed(1);
  objParam1Slider.value = prim.param1;
  $("obj-param1-value").textContent = prim.param1.toFixed(2);
  objParam2Slider.value = prim.param2;
  $("obj-param2-value").textContent = prim.param2.toFixed(2);
  
  const hexColor = '#' + 
    Math.round(prim.r * 255).toString(16).padStart(2, '0') +
    Math.round(prim.g * 255).toString(16).padStart(2, '0') +
    Math.round(prim.b * 255).toString(16).padStart(2, '0');
  objColorPicker.value = hexColor;
  
  if (prim.type === 0) {
    $("param1-label").textContent = "Radius";
    $("param2-container").style.display = "none";
  } else if (prim.type === 1) {
    $("param1-label").textContent = "Size X/Y/Z";
    $("param2-container").style.display = "none";
  } else if (prim.type === 2) {
    $("param1-label").textContent = "Major Radius";
    $("param2-label").textContent = "Minor Radius";
    $("param2-container").style.display = "block";
  } else if (prim.type === 3) {
    $("param1-label").textContent = "Radius";
    $("param2-label").textContent = "Height";
    $("param2-container").style.display = "block";
  }
}

// Event listeners
canvas.addEventListener("mousemove", (e) => {
  const rect = canvas.getBoundingClientRect();
  const dpr = devicePixelRatio || 1;
  [mouseX, mouseY] = [
    (e.clientX - rect.left) * dpr,
    (e.clientY - rect.top) * dpr,
  ];
});

canvas.addEventListener("mousedown", () => (mouseDown = true));
canvas.addEventListener("mouseup", () => (mouseDown = false));
canvas.addEventListener("mouseleave", () => (mouseDown = false));

$("panel-toggle").onclick = () => {
  isPanelOpen = !isPanelOpen;
  $("uniforms-panel").style.width = isPanelOpen ? "250px" : "24px";
  $("panel-content").style.display = isPanelOpen ? "flex" : "none";
  $("toggle-arrow").textContent = isPanelOpen ? "▶" : "◀";
};

compileBtn.onclick = () => compileShader(editor.getValue());
fullscreenBtn.onclick = toggleFullscreen;

document.addEventListener("fullscreenchange", updateFullscreenUI);
document.addEventListener("webkitfullscreenchange", updateFullscreenUI);
document.addEventListener("mozfullscreenchange", updateFullscreenUI);
document.addEventListener("MSFullscreenChange", updateFullscreenUI);

document.addEventListener("keydown", (e) => {
  if ((e.ctrlKey || e.metaKey) && e.key === "Enter") {
    e.preventDefault();
    compileShader(editor.getValue());
  }
  if (
    e.key === "f" &&
    !e.ctrlKey &&
    !e.metaKey &&
    !e.altKey &&
    !e.shiftKey
  ) {
    if (document.activeElement !== editor.getInputField()) {
      e.preventDefault();
      toggleFullscreen();
    }
  }
});

window.addEventListener("resize", resizeCanvas);

// Scene controls
const shapeSelector = $("shape-selector");
const stickmanSelector = $("stickman-selector");
const poseSelector = $("pose-selector");
const objXSlider = $("obj-x");
const objYSlider = $("obj-y");
const objZSlider = $("obj-z");
const objParam1Slider = $("obj-param1");
const objParam2Slider = $("obj-param2");
const objColorPicker = $("obj-color");

shaderSelector.addEventListener('change', () => {
  const selectedShader = shaderSelector.value;
  
  if (selectedShader === 'stickman.wgsl') {
    $("shape-selector-container").style.display = "none";
    $("stickman-selector-container").style.display = "block";
    $("scene-controls").style.display = "block";
    updateUIForStickman();
  } else if (selectedShader === 'scene_minimal.wgsl') {
    $("shape-selector-container").style.display = "block";
    $("stickman-selector-container").style.display = "none";
    $("scene-controls").style.display = "block";
    updateUIForShape();
  } else {
    $("scene-controls").style.display = "none";
  }
  
  if (selectedShader && shaders[selectedShader]) {
    editor.setValue(shaders[selectedShader].content);
    compileShader(shaders[selectedShader].content);
  }
});

shapeSelector.onchange = (e) => {
  sceneData.activeIndex = parseInt(e.target.value);
  updateUIForShape();
};

stickmanSelector.onchange = () => {
  updateUIForStickman();
};

poseSelector.onchange = (e) => {
  if (e.target.value) {
    applyPose(e.target.value);
  }
};

objXSlider.oninput = (e) => {
  if (shaderSelector.value === 'stickman.wgsl') {
    const partName = stickmanSelector.value;
    stickmanData[partName].x = parseFloat(e.target.value);
    $("obj-x-value").textContent = stickmanData[partName].x.toFixed(1);
  } else {
    const idx = sceneData.activeIndex;
    sceneData.primitives[idx].x = parseFloat(e.target.value);
    $("obj-x-value").textContent = sceneData.primitives[idx].x.toFixed(1);
  }
};

objYSlider.oninput = (e) => {
  if (shaderSelector.value === 'stickman.wgsl') {
    const partName = stickmanSelector.value;
    stickmanData[partName].y = parseFloat(e.target.value);
    $("obj-y-value").textContent = stickmanData[partName].y.toFixed(1);
  } else {
    const idx = sceneData.activeIndex;
    sceneData.primitives[idx].y = parseFloat(e.target.value);
    $("obj-y-value").textContent = sceneData.primitives[idx].y.toFixed(1);
  }
};

objZSlider.oninput = (e) => {
  if (shaderSelector.value === 'stickman.wgsl') {
    const partName = stickmanSelector.value;
    stickmanData[partName].z = parseFloat(e.target.value);
    $("obj-z-value").textContent = stickmanData[partName].z.toFixed(1);
  } else {
    const idx = sceneData.activeIndex;
    sceneData.primitives[idx].z = parseFloat(e.target.value);
    $("obj-z-value").textContent = sceneData.primitives[idx].z.toFixed(1);
  }
};

objParam1Slider.oninput = (e) => {
  if (shaderSelector.value === 'stickman.wgsl') {
    const partName = stickmanSelector.value;
    stickmanData[partName].param1 = parseFloat(e.target.value);
    $("obj-param1-value").textContent = stickmanData[partName].param1.toFixed(2);
  } else {
    const idx = sceneData.activeIndex;
    const prim = sceneData.primitives[idx];
    prim.param1 = parseFloat(e.target.value);
    if (prim.type === 1) {
      prim.param2 = prim.param1;
      prim.param3 = prim.param1;
    }
    $("obj-param1-value").textContent = prim.param1.toFixed(2);
  }
};

objParam2Slider.oninput = (e) => {
  if (shaderSelector.value === 'stickman.wgsl') {
    const partName = stickmanSelector.value;
    stickmanData[partName].param2 = parseFloat(e.target.value);
    $("obj-param2-value").textContent = stickmanData[partName].param2.toFixed(2);
  } else {
    const idx = sceneData.activeIndex;
    sceneData.primitives[idx].param2 = parseFloat(e.target.value);
    $("obj-param2-value").textContent = sceneData.primitives[idx].param2.toFixed(2);
  }
};

objColorPicker.oninput = (e) => {
  const hex = e.target.value;
  const r = parseInt(hex.substr(1,2), 16) / 255;
  const g = parseInt(hex.substr(3,2), 16) / 255;
  const b = parseInt(hex.substr(5,2), 16) / 255;
  
  if (shaderSelector.value === 'stickman.wgsl') {
    const partName = stickmanSelector.value;
    stickmanData[partName].r = r;
    stickmanData[partName].g = g;
    stickmanData[partName].b = b;
  } else {
    const idx = sceneData.activeIndex;
    sceneData.primitives[idx].r = r;
    sceneData.primitives[idx].g = g;
    sceneData.primitives[idx].b = b;
  }
};

// Main initialization
const main = async () => {
  await loadShaders();
  resizeCanvas();
  updateUIForShape();
  if (await initWebGPU()) render();
};

main();
