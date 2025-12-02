// ============================================================================
// PROJET WebGPU : ÉDITEUR DE SCÈNE 3D INTERACTIF (Ray Marching)
// ============================================================================
//
// OBJECTIF GLOBAL:
// Créer un éditeur de scène 3D en temps réel où l'utilisateur peut définir et 
// modifier une scène composée de primitives (sphères, boîtes, etc.) via une 
// interface HTML. Les paramètres de scène seront stockés dans un uniform buffer
// et envoyés au shader pour un rendu en temps réel.
//
// ============================================================================
// PARTIE 1: UNIFORMES DE LA SCÈNE ET INTÉGRATION DU SHADER (35%)
// ============================================================================
//
// ÉTAPE 1.1: DÉFINIR LES STRUCTS WGSL
// ------------------------------------
// Créez des structs pour chaque type de primitive et un struct Scene principal.
// ⚠️ IMPORTANT: Respectez l'alignement mémoire WGSL!
//    - vec3<f32> est aligné sur 16 bytes (avec 4 bytes de padding)
//    - Utilisez vec4<f32> pour stocker vec3 afin d'éviter les erreurs d'alignement
//
// Exemple minimal (À COPIER DANS VOTRE SHADER):
//
// struct Sphere {
//     pos: vec4<f32>;           // xyz = position, w = padding
//     color: vec4<f32>;         // rgb = couleur, a = padding
//     radius_and_pad: vec4<f32>; // x = rayon, yzw = padding
// };
//
// struct Box {
//     center: vec4<f32>;         // xyz = centre, w = padding
//     halfExtents: vec4<f32>;    // xyz = demi-dimensions, w = padding
//     color: vec4<f32>;          // rgb = couleur, a = padding
// };
//
// struct Scene {
//     spheres: array<Sphere, 4>;  // Tableau de 4 sphères
//     boxes: array<Box, 2>;       // Tableau de 2 boîtes
//     numSpheres: u32;            // Nombre de sphères actives
//     numBoxes: u32;              // Nombre de boîtes actives
//     _pad: vec2<u32>;            // Padding pour alignement 16 bytes
// };
//
// @group(0) @binding(1)
// var<uniform> scene: Scene;
//
// ÉTAPE 1.2: MODIFIER LE SHADER POUR UTILISER LA SCENE
// ------------------------------------------------------
// Remplacez les valeurs hardcodées par les données du uniform:
//
// ❌ AVANT (hardcodé):
// let sphere_pos = vec3<f32>(sin(time) * 1.5, 0.0, 0.0);
// let sphere_radius = 0.5;
// let sphere_color = vec3<f32>(1.0, 0.3, 0.3);
//
// ✅ APRÈS (depuis uniform):
// let sphere_pos = scene.spheres[0].pos.xyz;
// let sphere_radius = scene.spheres[0].radius_and_pad.x;
// let sphere_color = scene.spheres[0].color.rgb;
//
// ÉTAPE 1.3: FONCTION SDF UTILISANT LA SCENE
// -------------------------------------------
// Exemple de fonction get_dist modifiée:
//
// fn get_dist(p: vec3<f32>) -> vec2<f32> {
//     var res = vec2<f32>(MAX_DIST, -1.0);
//     
//     // Parcourir les sphères actives
//     for (var i: u32 = 0u; i < scene.numSpheres; i++) {
//         let sphere = scene.spheres[i];
//         let dist = length(p - sphere.pos.xyz) - sphere.radius_and_pad.x;
//         if (dist < res.x) {
//             res = vec2<f32>(dist, f32(i));
//         }
//     }
//     
//     // Parcourir les boîtes actives
//     for (var i: u32 = 0u; i < scene.numBoxes; i++) {
//         let box = scene.boxes[i];
//         let q = abs(p - box.center.xyz) - box.halfExtents.xyz;
//         let dist = length(max(q, vec3<f32>(0.0))) + 
//                    min(max(q.x, max(q.y, q.z)), 0.0);
//         if (dist < res.x) {
//             res = vec2<f32>(dist, f32(i) + 10.0); // +10 pour différencier des sphères
//         }
//     }
//     
//     return res;
// }
//
// ============================================================================
// PARTIE 2: CODE JAVASCRIPT POUR LE GPUBuffer
// ============================================================================
//
// ÉTAPE 2.1: CALCULER LA TAILLE DU BUFFER
// ----------------------------------------
// Chaque Sphere = 3 vec4 = 3 × 16 = 48 bytes
// Chaque Box = 3 vec4 = 3 × 16 = 48 bytes
// Scene = 4 Spheres + 2 Boxes + 2 u32 + padding
//       = (4 × 48) + (2 × 48) + 16 = 192 + 96 + 16 = 304 bytes
//
// ÉTAPE 2.2: CRÉER LE BUFFER (dans initWebGPU)
// ---------------------------------------------
// const sceneSize = 304; // Ajustez selon votre struct
// const sceneBuffer = device.createBuffer({
//     size: sceneSize,
//     usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST
// });
//
// ÉTAPE 2.3: ENCODER LES DONNÉES
// -------------------------------
// Utilitaire pour écrire vec4:
//
// function encodeSceneData() {
//     const buffer = new ArrayBuffer(304);
//     const f32 = new Float32Array(buffer);
//     const u32 = new Uint32Array(buffer);
//     let offset = 0; // en float32 (4 bytes chacun)
//     
//     // Écrire 4 sphères
//     for (let i = 0; i < 4; i++) {
//         f32[offset++] = sceneData.spheres[i].x;      // pos.x
//         f32[offset++] = sceneData.spheres[i].y;      // pos.y
//         f32[offset++] = sceneData.spheres[i].z;      // pos.z
//         f32[offset++] = 0.0;                         // pos.w (padding)
//         f32[offset++] = sceneData.spheres[i].r;      // color.r
//         f32[offset++] = sceneData.spheres[i].g;      // color.g
//         f32[offset++] = sceneData.spheres[i].b;      // color.b
//         f32[offset++] = 1.0;                         // color.a
//         f32[offset++] = sceneData.spheres[i].radius; // radius
//         f32[offset++] = 0.0;                         // padding
//         f32[offset++] = 0.0;                         // padding
//         f32[offset++] = 0.0;                         // padding
//     }
//     
//     // Écrire 2 boîtes (similaire)
//     for (let i = 0; i < 2; i++) {
//         f32[offset++] = sceneData.boxes[i].cx;
//         f32[offset++] = sceneData.boxes[i].cy;
//         f32[offset++] = sceneData.boxes[i].cz;
//         f32[offset++] = 0.0;
//         f32[offset++] = sceneData.boxes[i].hx;
//         f32[offset++] = sceneData.boxes[i].hy;
//         f32[offset++] = sceneData.boxes[i].hz;
//         f32[offset++] = 0.0;
//         f32[offset++] = sceneData.boxes[i].r;
//         f32[offset++] = sceneData.boxes[i].g;
//         f32[offset++] = sceneData.boxes[i].b;
//         f32[offset++] = 1.0;
//     }
//     
//     // Écrire compteurs (offset en u32 = offset en f32)
//     u32[offset++] = sceneData.numSpheres;
//     u32[offset++] = sceneData.numBoxes;
//     u32[offset++] = 0; // padding
//     u32[offset++] = 0; // padding
//     
//     return buffer;
// }
//
// ÉTAPE 2.4: METTRE À JOUR LE BUFFER (dans render())
// ---------------------------------------------------
// function render() {
//     // ... code existant ...
//     
//     // Mettre à jour la scène sur le GPU
//     const sceneData = encodeSceneData();
//     device.queue.writeBuffer(sceneBuffer, 0, sceneData);
//     
//     // ... reste du code de rendu ...
// }
//
// ============================================================================
// PARTIE 3: BIND GROUP (dans compileShader)
// ============================================================================
//
// ÉTAPE 3.1: MODIFIER LE BIND GROUP LAYOUT
// -----------------------------------------
// const bindGroupLayout = device.createBindGroupLayout({
//     entries: [
//         {
//             binding: 0,
//             visibility: GPUShaderStage.FRAGMENT,
//             buffer: { type: "uniform" }  // uniformBuffer existant
//         },
//         {
//             binding: 1,
//             visibility: GPUShaderStage.FRAGMENT,
//             buffer: { type: "uniform" }  // NOUVEAU: sceneBuffer
//         }
//     ]
// });
//
// ÉTAPE 3.2: CRÉER LE BIND GROUP
// -------------------------------
// bindGroup = device.createBindGroup({
//     layout: bindGroupLayout,
//     entries: [
//         { binding: 0, resource: { buffer: uniformBuffer } },
//         { binding: 1, resource: { buffer: sceneBuffer } }  // NOUVEAU
//     ]
// });
//
// ============================================================================
// PARTIE 4: UI INTERACTIVE (30%)
// ============================================================================
//
// ÉTAPE 4.1: CRÉER L'INTERFACE HTML
// ----------------------------------
// Ajoutez dans index.html (remplacez ou étendez #uniforms-panel):
//
// <div id="scene-editor">
//     <h3>Sphère 1</h3>
//     <label>Position X: <input type="range" id="s1_x" min="-3" max="3" step="0.1" value="0"></label>
//     <label>Position Y: <input type="range" id="s1_y" min="-3" max="3" step="0.1" value="0"></label>
//     <label>Position Z: <input type="range" id="s1_z" min="-3" max="3" step="0.1" value="0"></label>
//     <label>Rayon: <input type="range" id="s1_r" min="0.1" max="2" step="0.1" value="0.5"></label>
//     <label>Couleur: <input type="color" id="s1_color" value="#ff4444"></label>
// </div>
//
// ÉTAPE 4.2: AJOUTER LES EVENT LISTENERS
// ---------------------------------------
// const sceneData = {
//     spheres: [
//         { x: 0, y: 0, z: 0, radius: 0.5, r: 1.0, g: 0.3, b: 0.3 },
//         // ... 3 autres sphères
//     ],
//     boxes: [
//         { cx: 0, cy: 0, cz: 0, hx: 0.5, hy: 0.5, hz: 0.5, r: 0.3, g: 1.0, b: 0.3 },
//         // ... 1 autre boîte
//     ],
//     numSpheres: 1,
//     numBoxes: 1
// };
//
// document.getElementById('s1_x').oninput = (e) => {
//     sceneData.spheres[0].x = parseFloat(e.target.value);
//     // Le buffer sera mis à jour dans render()
// };
//
// document.getElementById('s1_color').oninput = (e) => {
//     const hex = e.target.value;
//     sceneData.spheres[0].r = parseInt(hex.substr(1,2), 16) / 255;
//     sceneData.spheres[0].g = parseInt(hex.substr(3,2), 16) / 255;
//     sceneData.spheres[0].b = parseInt(hex.substr(5,2), 16) / 255;
// };
//
// ============================================================================
// CRITÈRES DE NOTATION
// ============================================================================
//
// Minimum (10/20):
// - Un uniform buffer 'Scene' créé et bindé
// - Le shader rend 1 primitive contrôlée par les uniformes
// - UI avec sliders fonctionnels pour cette primitive
//
// Bon (15/20):
// - Scene struct propre avec plusieurs primitives (spheres + boxes)
// - Shader rend tous les objets correctement
// - UI bien organisée avec contrôles pour tous les objets
//
// Excellent (20/20):
// - Utilisation d'arrays (array<Sphere, N>) avec boucles dans le shader
// - UI dynamique (ajout/suppression d'objets)
// - Code propre et extensible
//
// Bonus (jusqu'à +15%):
// - Click-to-select d'objets
// - Gizmo 3D pour manipulation visuelle
// - Synchronisation parfaite UI <-> viewport
//
// ============================================================================
// CONSEILS DE DEBUG
// ============================================================================
//
// 1. Vérifiez toujours que la taille du buffer est un multiple de 16 bytes
// 2. Loguez le WGSL complet avant compilation:
//    console.log('WGSL:', vertexShader + uniformsStruct + fragmentCode);
// 3. Utilisez les DevTools WebGPU (Chrome/Edge) pour inspecter les buffers
// 4. Commencez simple: 1 sphère, puis ajoutez progressivement
// 5. Testez l'alignement: écrivez des valeurs distinctes et vérifiez le rendu
//
// RESSOURCES:
// - WebGPU Fundamentals: https://webgpufundamentals.org/
// - WGSL Spec (alignement): https://www.w3.org/TR/WGSL/
// - Inigo Quilez (SDF): https://iquilezles.org/articles/
//
// ============================================================================


// Constants
const MAX_DIST: f32 = 100.0;
const SURF_DIST: f32 = 0.001;
const MAX_STEPS: i32 = 256;

// Material Types
const MAT_PLANE: f32 = 0;
const MAT_SPHERE: f32 = 1;
const MAT_BOX: f32 = 2;
const MAT_TORUS: f32 = 3;

// Material Colors
const MAT_SKY_COLOR: vec3<f32> = vec3<f32>(0.7, 0.8, 0.9);
const MAT_PLANE_COLOR: vec3<f32> = vec3<f32>(0.8, 0.8, 0.8);
const MAT_SPHERE_COLOR: vec3<f32> = vec3<f32>(1.0, 0.3, 0.3);
const MAT_BOX_COLOR: vec3<f32> = vec3<f32>(0.3, 1.0, 0.3);
const MAT_TORUS_COLOR: vec3<f32> = vec3<f32>(0.3, 0.3, 1.0);

fn get_material_color(mat_id: f32, p: vec3<f32>) -> vec3<f32> {
  if mat_id == MAT_PLANE {
    let checker = floor(p.x) + floor(p.z);
    let col1 = vec3<f32>(0.9, 0.9, 0.9);
    let col2 = vec3<f32>(0.2, 0.2, 0.2);
    return select(col2, col1, i32(checker) % 2 == 0);
  } else if mat_id == MAT_SPHERE {
    return MAT_SPHERE_COLOR;
  } else if mat_id == MAT_BOX {
    return MAT_BOX_COLOR;
  } else if mat_id == MAT_TORUS {
    return MAT_TORUS_COLOR;
  }
  return vec3<f32>(0.5, 0.5, 0.5);
}

// SDF Primitives
fn sd_sphere(p: vec3<f32>, r: f32) -> f32 {
  return length(p) - r;
}

fn sd_box(p: vec3<f32>, b: vec3<f32>) -> f32 {
  let q = abs(p) - b;
  return length(max(q, vec3<f32>(0.0))) + min(max(q.x, max(q.y, q.z)), 0.0);
}

fn sd_torus(p: vec3<f32>, t: vec2<f32>) -> f32 {
  let q = vec2<f32>(length(p.xz) - t.x, p.y);
  return length(q) - t.y;
}

fn sd_plane(p: vec3<f32>, n: vec3<f32>, h: f32) -> f32 {
  return dot(p, n) + h;
}

// SDF Operations
fn op_union(d1: f32, d2: f32) -> f32 {
  return min(d1, d2);
}

fn op_subtract(d1: f32, d2: f32) -> f32 {
  return max(-d1, d2);
}

fn op_intersect(d1: f32, d2: f32) -> f32 {
  return max(d1, d2);
}

fn op_smooth_union(d1: f32, d2: f32, k: f32) -> f32 {
  let h = clamp(0.5 + 0.5 * (d2 - d1) / k, 0.0, 1.0);
  return mix(d2, d1, h) - k * h * (1.0 - h);
}

// Scene description - returns (distance, material_id)
fn get_dist(p: vec3<f32>) -> vec2<f32> {
  let time = uniforms.time;
  var res = vec2<f32>(MAX_DIST, -1.0);

  // Ground plane
  let plane_dist = sd_plane(p, vec3<f32>(0.0, 1.0, 0.0), 0.5);
  if plane_dist < res.x {
    res = vec2<f32>(plane_dist, MAT_PLANE);
  }

  // Animated sphere
  let sphere_pos = vec3<f32>(sin(time) * 1.5, 0.0, 0.0);
  let sphere_dist = sd_sphere(p - sphere_pos, 0.5);

  // Rotating box
  var box_p = p - vec3<f32>(0.0, 0.0, 0.0);
  let rot_y = mat2x2f(cos(time), -sin(time), sin(time), cos(time));
  let rotated_xz = rot_y * vec2<f32>(box_p.x, box_p.z);
  box_p = vec3<f32>(rotated_xz.x, box_p.y, rotated_xz.y);
  let box_dist = sd_box(box_p, vec3<f32>(0.3, 0.4, 0.3));

  // Smooth union the sphere and box
  let smooth_blend = 0.4; // Adjust for desired blend amount
  let combined_dist = op_smooth_union(sphere_dist, box_dist, smooth_blend);

  // Assign material ID for the combined object based on which primitive is closer
  var combined_mat_id = 0.0;
  if sphere_dist < box_dist {
      combined_mat_id = MAT_SPHERE; // Sphere material
  } else {
      combined_mat_id = MAT_BOX; // Box material
  }

  if combined_dist < res.x {
    res = vec2<f32>(combined_dist, combined_mat_id);
  }

  // Torus
  let torus_dist = sd_torus(p - vec3<f32>(-1.5, 0.5, 1.0), vec2<f32>(0.4, 0.15));
  if torus_dist < res.x {
    res = vec2<f32>(torus_dist, MAT_TORUS);
  }

  return res;
}

// Ray marching function - returns (distance, material_id)
fn ray_march(ro: vec3<f32>, rd: vec3<f32>) -> vec2<f32> {
  var d = 0.0;
  var mat_id = -1.0;

  for (var i = 0; i < MAX_STEPS; i++) {
    let p = ro + rd * d;
    let dist_mat = get_dist(p);
    d += dist_mat.x;
    mat_id = dist_mat.y;

    if dist_mat.x < SURF_DIST || d > MAX_DIST {
      break;
    }
  }

  return vec2<f32>(d, mat_id);
}

// Calculate normal using gradient
fn get_normal(p: vec3<f32>) -> vec3<f32> {
  let e = vec2<f32>(0.001, 0.0);
  let n = vec3<f32>(
    get_dist(p + e.xyy).x - get_dist(p - e.xyy).x,
    get_dist(p + e.yxy).x - get_dist(p - e.yxy).x,
    get_dist(p + e.yyx).x - get_dist(p - e.yyx).x
  );
  return normalize(n);
}
