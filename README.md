# WebGPU Interactive Ray Marching Scene Editor 🚀

![WebGPU](https://img.shields.io/badge/WebGPU-Enabled-blue)
![WGSL](https://img.shields.io/badge/WGSL-Shaders-purple)

## 🎮 [Live Demo](https://fab-pie.github.io/Shaders/Lecture04/)

An interactive 3D scene editor built with WebGPU and ray marching. Edit and manipulate 3D primitives in real-time directly in your browser.

## ✨ Features

- **Real-time Shader Editing** - Write and compile WGSL shaders on the fly with CodeMirror editor
- **Interactive Scene Controls** - Manipulate 3D objects (position, size, color) with intuitive sliders
- **Uniform Buffer System** - GPU-accelerated scene rendering with proper memory alignment
- **Rotating Camera** - Orbital camera with mouse control for exploring your scene
- **Ray Marching Renderer** - Real-time SDF-based rendering with lighting and shadows
- **Multiple Shader Examples** - Perlin noise, FBM, glass reflections, and more

## 🛠️ Tech Stack

- **WebGPU** - Modern GPU API for high-performance graphics
- **WGSL** - WebGPU Shading Language
- **JavaScript** - Scene management and UI interactions
- **CodeMirror** - In-browser code editor with syntax highlighting
- **Tailwind CSS** - Styling

## 📦 Project Structure

```
Lecture04/
├── index.html                    # Main HTML structure
├── css/
│   └── style.css                # CodeMirror Gruvbox theme styles
├── js/
│   └── app.js                   # Application logic and WebGPU setup
├── shaders/
│   ├── scene_minimal.wgsl       # ✨ Interactive scene with 4 primitives
│   ├── stickman.wgsl            # ✨ Articulated stickman with 10 body parts
│   ├── raymarch_basic.wgsl      # Basic ray marching
│   ├── raymarch_glass.wgsl      # Glass with reflections
│   ├── perlin_noise.wgsl        # Perlin noise example
│   ├── fbm_perlin_noise.wgsl    # Fractal Brownian Motion
│   ├── simple_noise.wgsl        # Simple noise
│   ├── mouse.wgsl               # Mouse interaction
│   └── manifest.json            # Shader catalog
```

## 🎯 Current Implementation (15/20 Good Goal)

### Section 1: Scene Uniforms & Shader Integration ✅
- **WGSL Structs**: `Primitive` struct supporting multiple shape types (Sphere, Box, Torus, Cylinder)
- **GPU Buffer**: 544-byte `sceneBuffer` supporting both scene_minimal and stickman shaders
- **Bind Group**: `@binding(1)` for scene uniform in shader
- **Dynamic Updates**: Buffer written every frame with `device.queue.writeBuffer()`
- **SDF Primitives**: 4 different Signed Distance Functions implemented
  - `sd_sphere`: Sphere with configurable radius
  - `sd_box`: Cubic box with XYZ dimensions
  - `sd_torus`: Torus with major/minor radius
  - `sd_cylinder`: Cylinder with radius and height
- **Stickman Shader**: Articulated character with 10 body parts
  - Head (sphere), Torso (cylinder)
  - 2 Upper Arms + 2 Forearms (cylinders)
  - 2 Thighs + 2 Shins (cylinders)
  - Each part independently controllable

### Section 2: Interactive Scene Editor UI ✅
- **Scene Controls Panel**: Complete primitive editor with shape selection
  - **Shape Selector**: Dropdown to switch between 4 primitives
  - Position sliders (X, Y, Z): -3 to 3 range
  - **Dynamic Parameters**: UI adapts based on selected shape type
    - Sphere: Radius control
    - Box: Size control (uniform XYZ)
    - Torus: Major/Minor radius controls
    - Cylinder: Radius and Height controls
  - Color picker: RGB color selection per primitive
- **Real-time Updates**: No recompile needed, instant viewport updates
- **Smart UI**: Controls automatically update when switching between primitives

### Section 3: Deployment & Documentation 🚧
- Repository hosted on GitHub ✅
- GitHub Pages deployment configured ✅
- Professional README (this file) ✅

## 🚀 Local Development

1. **Clone the repository**
   ```bash
   git clone https://github.com/fab-pie/Shaders.git
   cd Shaders
   ```

2. **Start a local server** (required for WebGPU CORS)
   ```bash
   python -m http.server
   ```

3. **Open your browser**
   ```
   http://localhost:8000/Lecture04/
   ```

4. **Select a shader** from the dropdown menu and start editing!

## 🎨 How to Use

1. **Select "Scene Minimal (Projet)"** from the shader dropdown
2. **Use the Scene Controls panel** on the right to manipulate the sphere:
   - Drag sliders to move the sphere in 3D space
   - Adjust the radius to change its size
   - Pick a color to change its appearance
3. **Move your mouse** to control the camera pitch
4. **Watch the camera orbit** automatically around your scene

## 📚 Technical Details

### Memory Alignment
The `Scene` struct follows WGSL alignment rules:
- `vec4<f32>` = 16 bytes (aligned)
- Total buffer size: 64 bytes (1 Sphere + padding)

### Shader Pipeline
```
JavaScript sceneData → ArrayBuffer encoding → GPU sceneBuffer → WGSL shader → Ray marching → Viewport
```

### Camera System
- **Orbital rotation**: Camera orbits around origin at 4 units distance
- **Yaw**: Automatic rotation based on time
- **Pitch**: Mouse Y position controls camera height

## 🎓 Credits

Project for Computer Graphics course - WebGPU Ray Marching Scene Editor

## 📖 Resources

- [WebGPU Fundamentals](https://webgpufundamentals.org/)
- [Inigo Quilez - SDF Functions](https://iquilezles.org/articles/)
- [WGSL Specification](https://www.w3.org/TR/WGSL/)

