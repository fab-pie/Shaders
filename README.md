# WebGPU Interactive Ray Marching Scene Editor

## Live Demo

**[https://fab-pie.github.io/Shaders/Lecture04/](https://fab-pie.github.io/Shaders/Lecture04/)**

## Overview

An interactive 3D scene editor built with WebGPU and ray marching techniques. Edit and manipulate 3D primitives in real-time directly in your browser with live shader compilation and GPU-accelerated rendering.

## Features

- Real-time shader editing with syntax highlighting
- Interactive scene controls for manipulating 3D objects (position, size, color)
- GPU uniform buffer system for dynamic scene updates
- Orbital camera with mouse control
- Ray marching renderer with SDF-based primitives
- Multiple shader examples (Perlin noise, FBM, glass reflections)
- Articulated stickman character with pose presets

## Tech Stack

- **WebGPU** - Modern GPU API for high-performance graphics
- **WGSL** - WebGPU Shading Language for shader programming
- **JavaScript** - Application logic and scene management
- **CodeMirror** - In-browser code editor
- **HTML/CSS** - User interface

## Local Development

### Requirements

- Python 3.x (for local server)
- A browser with WebGPU support (Chrome 113+, Edge 113+)

### Setup Instructions

1. Clone the repository:
   ```bash
   git clone https://github.com/fab-pie/Shaders.git
   cd Shaders
   ```

2. Start a local web server (required for WebGPU security policies):
   ```bash
   python -m http.server
   ```

3. Open your browser and navigate to:
   ```
   http://localhost:8000/Lecture04/
   ```

4. Select a shader from the dropdown menu and start experimenting.

## Project Structure

```
Lecture04/
├── index.html              # Main application structure
├── css/
│   └── style.css          # CodeMirror theme styles
├── js/
│   └── app.js             # Application logic and WebGPU setup
└── shaders/
    ├── scene_minimal.wgsl  # Interactive scene with 4 primitives
    ├── stickman.wgsl       # Articulated character with pose presets
    ├── raymarch_basic.wgsl # Basic ray marching example
    ├── raymarch_glass.wgsl # Glass material with reflections
    ├── perlin_noise.wgsl   # Perlin noise visualization
    ├── fbm_perlin_noise.wgsl # Fractal Brownian Motion
    ├── simple_noise.wgsl   # Simple noise example
    ├── mouse.wgsl          # Mouse interaction demo
    └── manifest.json       # Shader catalog
```

## Resources

- [WebGPU Fundamentals](https://webgpufundamentals.org/)
- [Inigo Quilez - SDF Functions](https://iquilezles.org/articles/)
- [WGSL Specification](https://www.w3.org/TR/WGSL/)
