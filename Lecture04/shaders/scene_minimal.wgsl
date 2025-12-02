// Shader avec multiple primitives : Sphere, Box, Torus, Cylinder
// Contrôlé par uniform buffer avec sélection de forme

// Struct pour les primitives
struct Primitive {
    pos: vec4<f32>,      // xyz = position, w = type (0=sphere, 1=box, 2=torus, 3=cylinder)
    color: vec4<f32>,    // rgb = couleur, a = padding
    params: vec4<f32>,   // Paramètres selon le type (radius, dimensions, etc.)
}

// Struct Scene avec 4 primitives
struct Scene {
    primitives: array<Primitive, 4>,  // 4 objets
    active_index: vec4<f32>,          // x = index actif (0-3), yzw = padding
}

// Bind la Scene à @binding(1)
@group(0) @binding(1)
var<uniform> scene: Scene;

// Constantes
const MAX_DIST: f32 = 100.0;
const SURF_DIST: f32 = 0.001;
const MAX_STEPS: i32 = 100;

// SDF Primitives
fn sd_sphere(p: vec3<f32>, center: vec3<f32>, radius: f32) -> f32 {
    return length(p - center) - radius;
}

fn sd_box(p: vec3<f32>, center: vec3<f32>, size: vec3<f32>) -> f32 {
    let q = abs(p - center) - size;
    return length(max(q, vec3<f32>(0.0))) + min(max(q.x, max(q.y, q.z)), 0.0);
}

fn sd_torus(p: vec3<f32>, center: vec3<f32>, radius_major: f32, radius_minor: f32) -> f32 {
    let p_local = p - center;
    let q = vec2<f32>(length(p_local.xz) - radius_major, p_local.y);
    return length(q) - radius_minor;
}

fn sd_cylinder(p: vec3<f32>, center: vec3<f32>, radius: f32, height: f32) -> f32 {
    let p_local = p - center;
    let d = vec2<f32>(length(p_local.xz) - radius, abs(p_local.y) - height);
    return min(max(d.x, d.y), 0.0) + length(max(d, vec2<f32>(0.0)));
}

// Distance de la scène
fn get_dist(p: vec3<f32>) -> f32 {
    var min_dist = 100000.0;
    
    // Calculer la distance pour chaque primitive
    for (var i = 0; i < 4; i++) {
        let prim = scene.primitives[i];
        let prim_pos = prim.pos.xyz;
        let prim_type = i32(prim.pos.w);
        
        var dist = 100000.0;
        
        if prim_type == 0 {
            // Sphere
            let radius = prim.params.x;
            dist = sd_sphere(p, prim_pos, radius);
        } else if prim_type == 1 {
            // Box
            let size = prim.params.xyz;
            dist = sd_box(p, prim_pos, size);
        } else if prim_type == 2 {
            // Torus
            let radius_major = prim.params.x;
            let radius_minor = prim.params.y;
            dist = sd_torus(p, prim_pos, radius_major, radius_minor);
        } else if prim_type == 3 {
            // Cylinder
            let radius = prim.params.x;
            let height = prim.params.y;
            dist = sd_cylinder(p, prim_pos, radius, height);
        }
        
        min_dist = min(min_dist, dist);
    }
    
    // Distance au plan (sol)
    let plane_dist = p.y + 1.0;
    
    return min(min_dist, plane_dist);
}

// Récupérer la couleur de l'objet touché
fn get_object_color(hit_pos: vec3<f32>) -> vec3<f32> {
    var min_dist = 100000.0;
    var hit_color = vec3<f32>(0.5);
    
    for (var i = 0; i < 4; i++) {
        let prim = scene.primitives[i];
        let prim_pos = prim.pos.xyz;
        let prim_type = i32(prim.pos.w);
        
        var dist = 100000.0;
        
        if prim_type == 0 {
            dist = sd_sphere(hit_pos, prim_pos, prim.params.x);
        } else if prim_type == 1 {
            dist = sd_box(hit_pos, prim_pos, prim.params.xyz);
        } else if prim_type == 2 {
            dist = sd_torus(hit_pos, prim_pos, prim.params.x, prim.params.y);
        } else if prim_type == 3 {
            dist = sd_cylinder(hit_pos, prim_pos, prim.params.x, prim.params.y);
        }
        
        if abs(dist) < abs(min_dist) {
            min_dist = dist;
            hit_color = prim.color.rgb;
        }
    }
    
    return hit_color;
}

// Ray marching
fn ray_march(ro: vec3<f32>, rd: vec3<f32>) -> f32 {
    var d = 0.0;
    
    for (var i = 0; i < MAX_STEPS; i++) {
        let p = ro + rd * d;
        let dist = get_dist(p);
        d += dist;
        
        if dist < SURF_DIST || d > MAX_DIST {
            break;
        }
    }
    
    return d;
}

// Calcul de la normale
fn get_normal(p: vec3<f32>) -> vec3<f32> {
    let e = vec2<f32>(0.001, 0.0);
    let n = vec3<f32>(
        get_dist(p + e.xyy) - get_dist(p - e.xyy),
        get_dist(p + e.yxy) - get_dist(p - e.yxy),
        get_dist(p + e.yyx) - get_dist(p - e.yyx)
    );
    return normalize(n);
}

@fragment
fn fs_main(@builtin(position) fragCoord: vec4<f32>) -> @location(0) vec4<f32> {
    let uv = (fragCoord.xy - uniforms.resolution * 0.5) / min(uniforms.resolution.x, uniforms.resolution.y);
    
    // Caméra qui tourne (comme raymarch_glass)
    let pitch = clamp((1.0 - uniforms.mouse.y / uniforms.resolution.y), 0.05, 1.5);
    let yaw = uniforms.time * 0.5;
    
    let cam_dist = 4.0;
    let cam_target = vec3<f32>(0.0, 0.0, 0.0);
    let cam_pos = vec3<f32>(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * cam_dist;
    
    let cam_forward = normalize(cam_target - cam_pos);
    let cam_right = normalize(cross(cam_forward, vec3<f32>(0.0, 1.0, 0.0)));
    let cam_up = cross(cam_right, cam_forward);
    
    let focal_length = 1.5;
    let rd = normalize(cam_right * uv.x - cam_up * uv.y + cam_forward * focal_length);
    
    // Ray march
    let d = ray_march(cam_pos, rd);
    
    if d < MAX_DIST {
        let hit_pos = cam_pos + rd * d;
        let normal = get_normal(hit_pos);
        
        var color: vec3<f32>;
        
        // Vérifier si on a touché un objet ou le sol
        if hit_pos.y > -0.99 {
            // C'est un objet - récupérer sa couleur
            color = get_object_color(hit_pos);
        } else {
            // C'est le sol - damier
            let checker = (floor(hit_pos.x) + floor(hit_pos.z));
            color = select(vec3<f32>(0.3), vec3<f32>(0.8), i32(checker) % 2 == 0);
        }
        
        // Éclairage simple
        let light_dir = normalize(vec3<f32>(1.0, 1.0, -1.0));
        let diffuse = max(dot(normal, light_dir), 0.0);
        let ambient = 0.3;
        
        color = color * (ambient + diffuse * 0.7);
        
        return vec4<f32>(pow(color, vec3<f32>(1.0 / 2.2)), 1.0);
    }
    
    // Ciel
    let sky = mix(vec3<f32>(0.5, 0.7, 0.9), vec3<f32>(0.3, 0.5, 0.8), uv.y * 0.5 + 0.5);
    return vec4<f32>(sky, 1.0);
}
