// Stickman avec articulations contrôlables
// Chaque partie du corps est une primitive différente

// Struct pour les primitives
struct Primitive {
    pos: vec4<f32>,      // xyz = position, w = type (0=sphere, 3=cylinder)
    color: vec4<f32>,    // rgb = couleur, a = padding
    params: vec4<f32>,   // x = radius, y = height/radius2, zw = padding
    rotation: vec4<f32>, // xyz = rotation en degrés (pitch, yaw, roll), w = padding
}

// Struct Stickman (14 parties)
struct Stickman {
    // Tête
    head: Primitive,
    
    // Tronc
    torso: Primitive,
    
    // Bras gauche
    left_upper_arm: Primitive,
    left_forearm: Primitive,
    
    // Bras droit
    right_upper_arm: Primitive,
    right_forearm: Primitive,
    
    // Jambe gauche
    left_thigh: Primitive,
    left_shin: Primitive,
    
    // Jambe droite
    right_thigh: Primitive,
    right_shin: Primitive,
    
    // Padding pour alignement
    _pad1: vec4<f32>,
    _pad2: vec4<f32>,
}

// Bind le Stickman à @binding(1)
@group(0) @binding(1)
var<uniform> stickman: Stickman;

// Constantes
const MAX_DIST: f32 = 100.0;
const SURF_DIST: f32 = 0.001;
const MAX_STEPS: i32 = 100;
const PI: f32 = 3.14159265359;

// Matrices de rotation
fn rotateX(angle: f32) -> mat3x3<f32> {
    let c = cos(angle);
    let s = sin(angle);
    return mat3x3<f32>(
        1.0, 0.0, 0.0,
        0.0, c, -s,
        0.0, s, c
    );
}

fn rotateY(angle: f32) -> mat3x3<f32> {
    let c = cos(angle);
    let s = sin(angle);
    return mat3x3<f32>(
        c, 0.0, s,
        0.0, 1.0, 0.0,
        -s, 0.0, c
    );
}

fn rotateZ(angle: f32) -> mat3x3<f32> {
    let c = cos(angle);
    let s = sin(angle);
    return mat3x3<f32>(
        c, -s, 0.0,
        s, c, 0.0,
        0.0, 0.0, 1.0
    );
}

// SDF Primitives
fn sd_sphere(p: vec3<f32>, center: vec3<f32>, radius: f32) -> f32 {
    return length(p - center) - radius;
}

// Cylindre orienté verticalement
fn sd_cylinder_y(p: vec3<f32>, center: vec3<f32>, radius: f32, height: f32) -> f32 {
    let p_local = p - center;
    let d = vec2<f32>(length(p_local.xz) - radius, abs(p_local.y) - height);
    return min(max(d.x, d.y), 0.0) + length(max(d, vec2<f32>(0.0)));
}

// Cylindre orienté horizontalement (axe X)
fn sd_cylinder_x(p: vec3<f32>, center: vec3<f32>, radius: f32, length: f32) -> f32 {
    let p_local = p - center;
    let d = vec2<f32>(length(p_local.yz) - radius, abs(p_local.x) - length);
    return min(max(d.x, d.y), 0.0) + length(max(d, vec2<f32>(0.0)));
}

fn sd_capsule(p: vec3<f32>, a: vec3<f32>, b: vec3<f32>, radius: f32) -> f32 {
    let pa = p - a;
    let ba = b - a;
    let h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h) - radius;
}

// Évaluer une primitive avec rotation
fn eval_primitive(p: vec3<f32>, prim: Primitive, is_arm: bool) -> f32 {
    let prim_type = i32(prim.pos.w);
    let prim_pos = prim.pos.xyz;
    
    // Convertir les rotations en radians
    let rotX = prim.rotation.x * PI / 180.0;
    let rotY = prim.rotation.y * PI / 180.0;
    let rotZ = prim.rotation.z * PI / 180.0;
    
    // Transformer le point dans l'espace local de la primitive
    var p_local = p - prim_pos;
    
    // Appliquer les rotations INVERSES (ordre: Z, Y, X)
    if abs(rotZ) > 0.01 {
        p_local = rotateZ(-rotZ) * p_local;
    }
    if abs(rotY) > 0.01 {
        p_local = rotateY(-rotY) * p_local;
    }
    if abs(rotX) > 0.01 {
        p_local = rotateX(-rotX) * p_local;
    }
    
    if prim_type == 0 {
        // Sphere - pas affectée par la rotation
        return length(p_local) - prim.params.x;
    } else if prim_type == 3 {
        // Cylinder - toujours vertical (axe Y) après rotation
        let d = vec2<f32>(length(p_local.xz) - prim.params.x, abs(p_local.y) - prim.params.y);
        return min(max(d.x, d.y), 0.0) + length(max(d, vec2<f32>(0.0)));
    }
    
    return 100000.0;
}

// Distance de la scène complète
fn get_dist(p: vec3<f32>) -> f32 {
    var min_dist = 100000.0;
    
    // Tête
    min_dist = min(min_dist, eval_primitive(p, stickman.head, false));
    
    // Tronc
    min_dist = min(min_dist, eval_primitive(p, stickman.torso, false));
    
    // Bras gauche (horizontal)
    min_dist = min(min_dist, eval_primitive(p, stickman.left_upper_arm, true));
    min_dist = min(min_dist, eval_primitive(p, stickman.left_forearm, true));
    
    // Bras droit (horizontal)
    min_dist = min(min_dist, eval_primitive(p, stickman.right_upper_arm, true));
    min_dist = min(min_dist, eval_primitive(p, stickman.right_forearm, true));
    
    // Jambe gauche (vertical)
    min_dist = min(min_dist, eval_primitive(p, stickman.left_thigh, false));
    min_dist = min(min_dist, eval_primitive(p, stickman.left_shin, false));
    
    // Jambe droite (vertical)
    min_dist = min(min_dist, eval_primitive(p, stickman.right_thigh, false));
    min_dist = min(min_dist, eval_primitive(p, stickman.right_shin, false));
    
    // Sol
    let plane_dist = p.y + 2.0;
    
    return min(min_dist, plane_dist);
}

// Récupérer la couleur de la partie touchée
fn get_body_part_color(hit_pos: vec3<f32>) -> vec3<f32> {
    var min_dist = 100000.0;
    var hit_color = vec3<f32>(0.5);
    
    let parts = array<Primitive, 10>(
        stickman.head,
        stickman.torso,
        stickman.left_upper_arm,
        stickman.left_forearm,
        stickman.right_upper_arm,
        stickman.right_forearm,
        stickman.left_thigh,
        stickman.left_shin,
        stickman.right_thigh,
        stickman.right_shin
    );
    
    for (var i = 0; i < 10; i++) {
        // Bras sont à l'index 2,3,4,5 (horizontal)
        let is_arm = (i >= 2 && i <= 5);
        let dist = eval_primitive(hit_pos, parts[i], is_arm);
        if abs(dist) < abs(min_dist) {
            min_dist = dist;
            hit_color = parts[i].color.rgb;
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
    
    // Caméra qui tourne
    let pitch = clamp((1.0 - uniforms.mouse.y / uniforms.resolution.y), 0.05, 1.5);
    let yaw = uniforms.time * 0.3;
    
    let cam_dist = 8.0;
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
        
        // Vérifier si on a touché le stickman ou le sol
        if hit_pos.y > -1.99 {
            // C'est le stickman
            color = get_body_part_color(hit_pos);
        } else {
            // C'est le sol - damier
            let checker = (floor(hit_pos.x) + floor(hit_pos.z));
            color = select(vec3<f32>(0.2), vec3<f32>(0.7), i32(checker) % 2 == 0);
        }
        
        // Éclairage
        let light_dir = normalize(vec3<f32>(1.0, 1.5, -1.0));
        let diffuse = max(dot(normal, light_dir), 0.0);
        let ambient = 0.4;
        
        color = color * (ambient + diffuse * 0.6);
        
        return vec4<f32>(pow(color, vec3<f32>(1.0 / 2.2)), 1.0);
    }
    
    // Ciel
    let sky = mix(vec3<f32>(0.5, 0.7, 0.9), vec3<f32>(0.3, 0.5, 0.8), uv.y * 0.5 + 0.5);
    return vec4<f32>(sky, 1.0);
}
