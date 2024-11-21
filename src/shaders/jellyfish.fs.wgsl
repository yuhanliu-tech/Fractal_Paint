@group(${bindGroup_scene}) @binding(0) var<uniform> cameraUniforms: CameraUniforms;

@group(1) @binding(0) var<uniform> time: f32;
@group(1) @binding(1) var colorTexture : texture_2d<f32>;
@group(1) @binding(2) var depthTexture : texture_2d<f32>;

//@group(${bindGroup_scene}) @binding(1) var diffuseTex: texture_2d<f32>;
//@group(${bindGroup_scene}) @binding(2) var diffuseTexSampler: sampler;

// reference: https://www.shadertoy.com/view/McGcWW

struct FragmentInput {
    @builtin(position) fragPos: vec4f,
    @location(0) texCoord: vec2f,
};

// Constants
const lf: vec3<f32> = vec3<f32>(1.0, 0.0, 0.0);
const up: vec3<f32> = vec3<f32>(0.0, 1.0, 0.0);
const fw: vec3<f32> = vec3<f32>(0.0, 0.0, 1.0);

const halfpi: f32 = 1.570796326794896619;
const pi: f32 = 3.141592653589793238;
const twopi: f32 = 6.283185307179586;

const MAX_STEPS: f32 = 100.f;
const VOLUME_STEPS: f32 =  8.f;
const MIN_DISTANCE: f32 =  0.1;
const MAX_DISTANCE: f32 =  100.f;
const HIT_DISTANCE: f32 =  0.01;

// Colors
const accentColor1: vec3<f32> = vec3<f32>(1.0, 0.1, 0.5);
const secondColor1: vec3<f32> = vec3<f32>(0.1, 0.5, 1.0);

const accentColor2: vec3<f32> = vec3<f32>(1.0, 0.5, 0.1);
const secondColor2: vec3<f32> = vec3<f32>(0.1, 0.5, 0.6);

// Noise Functions
fn N1(x: f32) -> f32 {
    return fract(sin(x) * 5346.1764);
}

fn N2(x: f32, y: f32) -> f32 {
    return N1(x + y * 23414.324);
}

fn N3(p: vec3<f32>) -> f32 {
    var pNew = fract(p * 0.3183099 + 0.1);
    pNew *= 17.0;
    // Continue processing p as needed
    return pNew.x; // Example return, further processing can follow
}

// Structs

// Struct definition for camera
struct camera {
    p: vec3<f32>,       // the position of the camera
    forward: vec3<f32>, // the camera forward vector
    left: vec3<f32>,    // the camera left vector
    up: vec3<f32>,      // the camera up vector
    center: vec3<f32>,  // the center of the screen, in world coords
    i: vec3<f32>,       // where the current ray intersects the screen, in world coords
    ray: Ray,           // the current ray: from cam pos, through current uv projected on screen
    lookAt: vec3<f32>,  // the lookat point
    zoom: f32,          // the zoom factor
};

struct Ray {
    o: vec3<f32>, // Origin of the ray
    d: vec3<f32>, // Direction of the ray
};

struct DE {
    d: f32,      // Final distance to the field
    m: f32,      // Material type
    uv: vec3<f32>, // Texture coordinates (or any other UV-like data)
    pump: f32,   // A scalar value for "pump" (could represent some state or effect)

    id: vec3<f32>, // Object ID or a unique identifier
    pos: vec3<f32>, // World-space position of the fragment
};

struct RC {
    id: vec3<f32>, // Floor'd coordinate of the cell, used to identify the cell
    h: vec3<f32>,  // Half size of the cell
    p: vec3<f32>,  // Repeated coordinate within the cell
};

// Repeat function
fn Repeat(pos: vec3<f32>, size: vec3<f32>) -> RC {
    var o: RC;
    o.h = size * 0.5;
    o.id = floor(pos / size); // Used to give a unique id to each cell
    o.p = pos % size - o.h;   // Use the modulus operator (%) in WGSL
    return o;
}

// helper funcs -------------------------------------------------

// N31 function (noise generation)
fn N31(p: f32) -> vec3<f32> {
    var p3: vec3<f32> = fract(vec3<f32>(p) * vec3<f32>(0.1031, 0.11369, 0.13787));
    p3 += dot(p3, p3.yzx + 19.19);
    return fract(vec3<f32>((p3.x + p3.y) * p3.z, (p3.x + p3.z) * p3.y, (p3.y + p3.z) * p3.x));
}

// Smooth minimum function (smin)
fn smin(a: f32, b: f32, k: f32) -> f32 {
    var h: f32 = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
    return mix(b, a, h) - k * h * (1.0 - h);
}

// Smooth maximum function (smax)
fn smax(a: f32, b: f32, k: f32) -> f32 {
    var h: f32 = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
    return mix(a, b, h) + k * h * (1.0 - h);
}

// Signed distance function for a sphere (sdSphere)
fn sdSphere(p: vec3<f32>, pos: vec3<f32>, s: f32) -> f32 {
    return length(p - pos) - s;
}

// Polar modulus function (pModPolar)
fn pModPolar(p: vec2<f32>, repetitions: f32, fix: f32) -> vec2<f32> {
    let angle: f32 = twopi / repetitions;
    var a: f32 = atan(p.y / p.x) + angle / 2.0;
    
    // Correct the quadrant manually based on the signs of x and y
    if (p.x < 0.0) {
        a += pi;
    }
    let r: f32 = length(p);
    var c: f32 = floor(a / angle);
    a = (a % angle) - (angle / 2.0) * fix;
    let pNew = vec2<f32>(cos(a), sin(a)) * r;
    return pNew;
}

// 2D point-line distance function
fn Dist(P: vec2<f32>, P0: vec2<f32>, P1: vec2<f32>) -> f32 {
    var v: vec2<f32> = P1 - P0;
    var w: vec2<f32> = P - P0;

    let c1: f32 = dot(w, v);
    let c2: f32 = dot(v, v);

    if (c1 <= 0.0) {
        return length(P - P0); // Before P0
    }

    let b: f32 = c1 / c2;
    var Pb: vec2<f32> = P0 + b * v;
    return length(P - Pb);
}

// Closest point on a ray to a point function
fn ClosestPoint(ro: vec3<f32>, rd: vec3<f32>, p: vec3<f32>) -> vec3<f32> {
    return ro + max(0.0, dot(p - ro, rd)) * rd;
}

// Ray-ray intersection function
fn RayRayTs(ro1: vec3<f32>, rd1: vec3<f32>, ro2: vec3<f32>, rd2: vec3<f32>) -> vec2<f32> {
    var dO: vec3<f32> = ro2 - ro1;
    var cD: vec3<f32> = cross(rd1, rd2);
    let v: f32 = dot(cD, cD);

    let t1: f32 = dot(cross(dO, rd2), cD) / v;
    let t2: f32 = dot(cross(dO, rd1), cD) / v;
    
    return vec2<f32>(t1, t2);
}

// Distance from ray to line segment
fn DistRaySegment(ro: vec3<f32>, rd: vec3<f32>, p1: vec3<f32>, p2: vec3<f32>) -> f32 {
    var rd2: vec3<f32> = p2 - p1;
    var t: vec2<f32> = RayRayTs(ro, rd, p1, rd2);
    
    t.x = max(t.x, 0.0);
    t.y = clamp(t.y, 0.0, length(rd2));
    
    var rp: vec3<f32> = ro + rd * t.x;
    var sp: vec3<f32> = p1 + rd2 * t.y;
    
    return length(rp - sp);
}

// Ray-sphere intersection function
fn sph(ro: vec3<f32>, rd: vec3<f32>, pos: vec3<f32>, radius: f32) -> vec2<f32> {
    var oc: vec3<f32> = pos - ro;
    var l: f32 = dot(rd, oc);
    var det: f32 = l * l - dot(oc, oc) + radius * radius;
    
    if (det < 0.0) {
        return vec2<f32>(MAX_DISTANCE, MAX_DISTANCE); // No intersection
    }
    
    var d: f32 = sqrt(det);
    var a: f32 = l - d;
    var b: f32 = l + d;
    
    return vec2<f32>(a, b);
}

// Remap function
fn remap(a: f32, b: f32, c: f32, d: f32, t: f32) -> f32 {
    return ((t - a) / (b - a)) * (d - c) + c;
}

// Map function
fn map(p: vec3<f32>, id: vec3<f32>) -> DE {
    var pNew = p;
    var t: f32 = time * 2.0;
    
    var N: f32 = N3(id);
    
    var o: DE;
    o.m = 0.0;
    
    var x: f32 = (pNew.y + N * twopi) * 1.0 + t;
    var r: f32 = 1.0;
    
    var pump: f32 = cos(x + cos(x)) + sin(2.0 * x) * 0.2 + sin(4.0 * x) * 0.02;
    
    x = t + N * twopi;
    pNew.y -= (cos(x + cos(x)) + sin(2.0 * x) * 0.2) * 0.6;
    pNew.x *= 1.0 + pump * 0.2;
    pNew.z *= 1.0 + pump * 0.2;
    
    var d1: f32 = sdSphere(pNew, vec3<f32>(0.0, 0.0, 0.0), r);
    var d2: f32 = sdSphere(pNew, vec3<f32>(0.0, -0.5, 0.0), r);
    
    o.d = smax(d1, -d2, 0.1);
    o.m = 1.0;
    
    if (pNew.y < 0.5) {
        var sway: f32 = 0.f; //sin(/*t +*/ pNew.y + N * twopi) * smoothstep(-3.0, 0.5, pNew.y) * N * 0.3;
        pNew.x += sway * N;  // Add some sway to the tentacles
        pNew.z += sway * (1.0 - N);
        
        var mp: vec3<f32> = pNew;
        let mpxz = pModPolar(mp.xz, 6.0, 0.0);
        mp.x = mpxz.x;
        mp.z = mpxz.y;
        
        var d3: f32 = length(mp.xz - vec2<f32>(0.2, 0.1)) - remap(0.5, -3.5, 0.1, 0.01, mp.y);
        if (d3 < o.d) {
            o.m = 2.0;
        }
        d3 += (sin(mp.y * 10.0) + sin(mp.y * 23.0)) * 0.03;
        
        var d32: f32 = length(mp.xz - vec2<f32>(0.2, 0.1)) - remap(0.5, -3.5, 0.1, 0.04, mp.y) * 0.5;
        d3 = min(d3, d32);
        o.d = smin(o.d, d3, 0.5);
        
        if (pNew.y < 0.2) {
            var op: vec3<f32> = pNew;
            let opxz = pModPolar(op.xz, 13.0, 1.0);
            op.x = opxz.x;
            op.z = opxz.y;
            
            var d4: f32 = length(op.xz - vec2<f32>(0.85, 0.0)) - remap(0.5, -3.0, 0.04, 0.0, op.y);
            if (d4 < o.d) {
                o.m = 3.0;
            }
            o.d = smin(o.d, d4, 0.15);
        }
    }
    
    o.pump = pump;
    o.uv = pNew;
    
    o.d *= 0.8;
    return o;
}

fn calcNormal(o: DE) -> vec3<f32> {
    var eps: vec3<f32> = vec3<f32>(0.01, 0.0, 0.0);
    var nor: vec3<f32> = vec3<f32>(
        map(o.pos + eps.xyy, o.id).d - map(o.pos - eps.xyy, o.id).d,
        map(o.pos + eps.yxy, o.id).d - map(o.pos - eps.yxy, o.id).d,
        map(o.pos + eps.yyx, o.id).d - map(o.pos - eps.yyx, o.id).d
    );
    return normalize(nor);
}

// CastRay function
fn CastRay(r: Ray) -> DE {
    var d: f32 = 0.0;
    var dS: f32 = MAX_DISTANCE;

    var pos: vec3<f32> = vec3<f32>(0.0, 0.0, 0.0);
    var n: vec3<f32> = vec3<f32>(0.0, 0.0, 0.0);
    var o: DE;
    var s: DE;

    var dC: f32 = MAX_DISTANCE;
    var p: vec3<f32>;
    var q: RC;
    var t: f32 = time;
    var grid: vec3<f32> = vec3<f32>(6.0, 30.0, 6.0);
    
    for (var i: f32 = 0.0; i < MAX_STEPS; i+=1) {
        p = r.o + r.d * d;

        //p.y -= t;  // Make the move up
        //p.x += t;  // Make the camera fly forward

        q = Repeat(p, grid);

        // Apply step component-wise for vec3<f32>
        var rC = vec3<f32>(0.f);
        rC.x = ((2.0 * step(0.0, r.d.x) - 1.0) * q.h.x - q.p.x) / r.d.x;
        rC.y = ((2.0 * step(0.0, r.d.y) - 1.0) * q.h.y - q.p.y) / r.d.y;
        rC.z = ((2.0 * step(0.0, r.d.z) - 1.0) * q.h.z - q.p.z) / r.d.z;

        dC = min(min(rC.x, rC.y), rC.z) + 0.01; // Distance to cell just past boundary

        var N: f32 = N3(q.id);
        q.p += (N31(N) - 0.5) * grid * vec3<f32>(0.5, 0.7, 0.5);

        if (Dist(q.p.xz, r.d.xz, vec2<f32>(0.0, 0.0)) < 1.1) {
            s = map(q.p, q.id);
        } else {
            s.d = dC;
        }

        if (s.d < HIT_DISTANCE || d > MAX_DISTANCE) {
            break;
        }
        d += min(s.d, dC); // Move to the distance to next cell or surface, whichever is closest
    }

    if (s.d < HIT_DISTANCE) {
        o.m = s.m;
        o.d = d;
        o.id = q.id;
        o.uv = s.uv;
        o.pump = s.pump;

        o.pos = q.p;
    }

    return o;
}

fn B(x: f32, y: f32, w: f32, z:f32) -> f32 {
    return smoothstep(x - z, x + z, w) * smoothstep(y + z, y - z, w);
}

// Volume texture function
fn VolTex(uv: vec3<f32>, p: vec3<f32>, scale: f32, pump: f32) -> f32 {
    // uv = the surface position
    // p = the volume shell position
    
    var p_scaled: vec3<f32> = p;
    p_scaled.y *= scale;

    var s2: f32 = 5.0 * p_scaled.x / twopi;
    var id: f32 = floor(s2);
    s2 = fract(s2);
    var ep: vec2<f32> = vec2<f32>(s2 - 0.5, p_scaled.y - 0.6);
    var ed: f32 = length(ep);
    var e: f32 = B(0.35, 0.45, 0.05, ed);

    var s: f32 = sin(s2 * twopi * 15.0) * 0.5 + 0.5;
    s = s * s;
    s = s * s;
    s *= smoothstep(-0.3, 1.4, uv.y - cos(s2 * twopi) * 0.2 + 0.3) * smoothstep(-0.6, -0.3, uv.y);
    
    var t: f32 = time* 5.0;
    var mask: f32 = sin(p_scaled.x * twopi * 2.0 + t) * 0.5 + 0.5;
    s *= mask * mask * 2.0;
    
    return s + e * pump * 2.0;
}

// Jelly texture function
fn JellyTex(p: vec3<f32>) -> vec4<f32> { 
    var pNew = p;
    var s: vec3<f32> = vec3<f32>(atan(pNew.x / pNew.z), length(pNew.xz), pNew.y);
    
    var b: f32 = 0.75 + sin(s.x * 6.0) * 0.25;
    b = mix(1.0, b, s.y * s.y);
    
    pNew.x += sin(s.z * 10.0) * 0.1;
    var b2: f32 = cos(s.x * 26.0) - s.z - 0.7;
   
    b2 = smoothstep(0.1, 0.6, b2);
    return vec4<f32>(b + b2, 0.0, 0.0, 0.0);  // Assuming the other channels are zero for this case.
}

fn background(r: vec3<f32>, bg: vec3<f32>) -> vec3<f32> {
    var x: f32 = atan(r.x / r.z);      // From -pi to pi
    var y: f32 = pi * 0.5 - acos(r.y);  // From -1/2pi to 1/2pi
    
    var col: vec3<f32> = bg * (1.0 + y);
    
    var t: f32 = time;  // Add god rays
    
    var a: f32 = sin(r.x);
    
    var beam: f32 = clamp(sin(10.0 * x + a * y * 5.0), 0, 1);// + t
    beam *= clamp(sin(7.0 * x + a * y * 3.5), 0, 1); //-t
    
    var beam2: f32 = clamp(sin(42.0 * x + a * y * 21.0), 0, 1); // -t
    beam2 *= clamp(sin(34.0 * x + a * y * 17.0 ), 0, 1); // +t
    
    beam += beam2;
    col *= 1.0 + beam * 0.05;

    return col;
}

fn render(uv: vec2<f32>, camRay: Ray, depth: f32, bg: vec3<f32>, accent: vec3<f32>) -> vec3<f32> {
    // Outputs a color

    var col: vec3<f32> = background(camRay.d, bg);
    var o: DE = CastRay(camRay);
    
    var t: f32 = time;
    var L: vec3<f32> = up;

    if (o.m > 0.0) {
        var n: vec3<f32> = calcNormal(o);
        var lambert: f32 = clamp(dot(n, L), 0, 1);
        var R: vec3<f32> = reflect(camRay.d, n);
        var fresnel: f32 = clamp(1.0 + dot(camRay.d, n), 0, 1);
        var trans: f32 = (1.0 - fresnel) * 0.5;
        var refl: vec3<f32> = background(R, bg);
        var fade: f32 = 0.0;
        
        if (o.m == 1.0) {  // Hood color
            var density: f32 = 0.0;
            for (var i: f32 = 0.0; i < VOLUME_STEPS; i+=1) {
                var sd: f32 = sph(o.uv, camRay.d, vec3<f32>(0.0), 0.8 + i * 0.015).x;
                if (sd != MAX_DISTANCE) {
                    var intersect: vec2<f32> = o.uv.xz + camRay.d.xz * sd;

                    var uv: vec3<f32> = vec3<f32>(atan(intersect.x / intersect.y), length(intersect.xy), o.uv.z);
                    density += VolTex(o.uv, uv, 1.4 + i * 0.03, o.pump);
                }
            }
            var volTex: vec4<f32> = vec4<f32>(accent, density / VOLUME_STEPS);

            var dif: vec3<f32> = JellyTex(o.uv).rgb;
            dif *= max(0.2, lambert);

            col = mix(col, volTex.rgb, volTex.a);
            col = mix(col, dif, 0.25);

            col += fresnel * refl * clamp(dot(up, n), 0, 1);

            // Fade
            fade = max(fade, smoothstep(0.0, 1.0, fresnel));
        } else if (o.m == 2.0) {  // Inside tentacles
            var dif: vec3<f32> = accent;
            col = mix(bg, dif, fresnel);

            col *= mix(0.6, 1.0, smoothstep(-1.5, 0.0, o.uv.y));

            var prop: f32 = o.pump + 0.25;
            prop *= prop * prop;
            col += pow(1.0 - fresnel, 20.0) * dif * prop;

            fade = fresnel;
        } else if (o.m == 3.0) {  // Outside tentacles
            var dif: vec3<f32> = accent;
            var d: f32 = smoothstep(13.0, 100.0, o.d);
            col = mix(bg, dif, pow(1.0 - fresnel, 5.0)); // col = mix(bg, dif, pow(1.-fresnel, 5.)*d);
        }

        fade = max(fade, smoothstep(0.0, 100.0, o.d));
        col = mix(col, bg, fade);

        if (o.m == 4.0) {
            col = vec3<f32>(1.0, 0.0, 0.0);
        }
    } else {
        col = bg;
    }

    return col;
} 

@fragment
fn main(in: FragmentInput) -> @location(0) vec4f {

    let index = vec2u(in.fragPos.xy);
    let diffuseColor = textureLoad(colorTexture, index, 0);

    var t = 4.f ;//* time;

    var uv: vec2<f32> = in.texCoord;
    uv -= 0.5;

    // background and jelly colors
    var accent = mix(accentColor1, accentColor2, sin(t * 15.456));
    var bg = diffuseColor.xyz;
    bg = mix(secondColor1, secondColor2, sin(t*7.345231));

    // camera setup ----------------------

    var cam: camera;

    cam.lookAt = cameraUniforms.cameraLookPos.xyz;

    cam.p = cameraUniforms.cameraPos.xyz ;

    cam.forward = normalize(cam.lookAt - cam.p);

    cam.left = -cross(up, cam.forward);

    cam.up = -cross(cam.forward, cam.left);

    cam.center = cam.p + cam.forward;

    cam.i = cam.center + cam.left * uv.x + cam.up * uv.y;

    cam.ray.o = cam.p;                      // ray origin = camera position
    cam.ray.d = normalize(cam.i - cam.p);   // ray direction is the vector from the cam pos through the point on the imaginary screen
    
    // end camera setup -------------------
    
    var col: vec3<f32> = render(uv, cam.ray, 0.0, bg, accent);
    
    //col = pow(col, vec3<f32>(mix(1.5, 2.6, sin(t + pi))));  // Post-processing
    //var d: f32 = 1.0 - dot(uv, uv);  // Vignette
    //col *= (d * d * d) + 0.1;
    
    return vec4<f32>(col, 1.0);
}