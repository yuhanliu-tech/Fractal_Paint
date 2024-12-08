@group(1) @binding(0) var colorTexture : texture_2d<f32>;
@group(1) @binding(1) var depthTexture : texture_2d<f32>; // unused

// reference: https://www.shadertoy.com/view/McGcWW

struct FragmentInput {
    @builtin(position) fragPos: vec4f,
    @location(0) texCoord: vec2f,
};

// Constants
const lf: vec3<f32> = vec3<f32>(1.0, 0.0, 0.0); // left
const up: vec3<f32> = vec3<f32>(0.0, 1.0, 0.0); // up
const fw: vec3<f32> = vec3<f32>(0.0, 0.0, 1.0); // forward

const halfpi: f32 = 1.570796326794896619;
const twopi: f32 = 6.283185307179586;

// parameters to control ray marching 
const MAX_STEPS: f32 = 100.f;
const VOLUME_STEPS: f32 =  8.f;
const MIN_DISTANCE: f32 =  0.1;
const MAX_DISTANCE: f32 =  100.f;
const HIT_DISTANCE: f32 =  0.01;

// Colors
const accentColor1: vec3<f32> = vec3<f32>(0.2, 0.1, 0.8);
const accentColor2: vec3<f32> = vec3<f32>(0.2, 0.5, 0.8);
const baseColor: vec3<f32> = vec3<f32>(0.7, 0.7, 1.0);

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
    return pNew.x;
}

// Structs

struct Ray {
    o: vec3<f32>, // Origin of the ray
    d: vec3<f32>, // Direction of the ray
};

// Distance estimation (stores info about distance to nearest surface)
struct DE {
    d: f32,      // Final distance to the field
    m: f32,      // Material type
    uv: vec3<f32>,
    pump: f32,  

    id: vec3<f32>,
    pos: vec3<f32>, // World-space position of the fragment
};

// repeated cell (for jellyfish pattern)
struct RC {
    id: vec3<f32>, // Floor'd coordinate of the cell, used to identify the cell
    h: vec3<f32>,  // Half size of the cell
    p: vec3<f32>,  // Repeated coordinate within the cell
};

// helper funcs -------------------------------------------------


// N31 function (noise generation)
fn N31(p: f32) -> vec3<f32> {
    var p3: vec3<f32> = fract(vec3<f32>(p) * vec3<f32>(0.1031, 0.41369, 0.13787));
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
// creates polar symmetry by repeating space in angular segments 
fn pModPolar(p: vec2<f32>, repetitions: f32, fix: f32) -> vec2<f32> {
    let angle: f32 = twopi / repetitions;
    var a: f32 = atan2(p.y,p.x);
    
    // Correct the quadrant manually based on the signs of x and y
    if (p.x < 0.0) {
        a += PI;
    }

    let r: f32 = length(p);
    var c: f32 = floor(a / angle);
    a = (a % angle) - (angle / 2.0) * fix;

    return vec2<f32>(cos(a), sin(a)) * r;
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

// calculates normal vector at a point on the surface 
fn calcNormal(o: DE) -> vec3<f32> {
    var eps: vec3<f32> = vec3<f32>(0.01, 0.0, 0.0);
    var nor: vec3<f32> = vec3<f32>(
        map(o.pos + eps.xyy, o.id).d - map(o.pos - eps.xyy, o.id).d,
        map(o.pos + eps.yxy, o.id).d - map(o.pos - eps.yxy, o.id).d,
        map(o.pos + eps.yyx, o.id).d - map(o.pos - eps.yyx, o.id).d
    );
    return normalize(nor);
}

// Repeat function
// creates grid of repeated cells to place multiple jellyfish into the scene
fn Repeat(pos: vec3<f32>, size: vec3<f32>) -> RC {
    var o: RC;
    o.h = size * 0.5;
    o.id = floor(pos / size); // Used to give a unique id to each cell
    o.p = pos % size - o.h;  
    return o;
}

// Remap function
fn remap(a: f32, b: f32, c: f32, d: f32, t: f32) -> f32 {
    return ((t - a) / (b - a)) * (d - c) + c;
}

//============================================================================================

// Map function
// Defines distance to nearest surface at any given point (calculates signed dist)
fn map(p: vec3<f32>, id: vec3<f32>) -> DE {
    var pNew = p;

    var t: f32 = time * 2.0;
    
    var N: f32 = N3(id);
    
    var o: DE;
    o.m = 0.0;
    
    // var x used for animating and shaping jellyfish head
    var x: f32 = (pNew.y + N * twopi) * 1.0 + t;
    var r: f32 = 1.0; // radius of jelly head
    
    var pump: f32 = cos(x + cos(x)) + sin(2.0 * x) * 0.2 + sin(4.0 * x) * 0.02; // animation
    
    // jellyfish animation
    x = t + N * twopi;
    pNew.y -= (cos(x + cos(x)) + sin(2.0 * x) * 0.2) * 0.6;
    pNew.x *= 1.0 + pump * 0.2;
    pNew.z *= 1.0 + pump * 0.2;
    
    // signed dist to jellyfish head
    var d1: f32 = sdSphere(pNew, vec3<f32>(0.0, 0.0, 0.0), r);

    // signed dist to hollow out jellyfish head
    var d2: f32 = sdSphere(pNew, vec3<f32>(0.0, -0.5, 0.0), r);
    
    // combine dists to create head shape 
    o.d = smax(d1, -d2, 0.1);
    o.m = 1.0;
    
    // if point is below a certain height, add tentacles
    if (pNew.y < 0.5) {
        var sway: f32 = sin(t + pNew.y + N * twopi) * (1.0 - smoothstep(-2.5, 0.5, pNew.y)) * N * 0.001;
        pNew.x += sway * N;  // Add some sway to the tentacles
        pNew.z += sway * (1.0 - N) * 0.5;
        
        if (pNew.y > -2.0) {
            var mp: vec3<f32> = pNew;

            // polar repetition to create multiple tentacles around y-axis
            let mpxz = pModPolar(mp.xz, 3.0, 0.1); // internal
            mp.x = mpxz.x;
            mp.z = mpxz.y;
            
            // signed dist to cylinder representing tentacle
            var d3: f32 = length(mp.xz - vec2<f32>(0.2, 0.15)) - remap(0.5, -1.5, 0.1, 0.01, mp.y);

            // if dist closer, set material to inside tentacles
            if (d3 < o.d) {
                o.m = 1.0;
            }

            // wavy perturbations to tentacles
            d3 += (sin(mp.y * 30.0) * 0.02 + sin(mp.y * 60.0) * 0.015 + sin(mp.y * 90.0) * 0.01);
            
            // smaller cylinder for finer detail
            var d32: f32 = length(mp.xz - vec2<f32>(0.2, 0.1)) - remap(0.5, -3.5, 0.1, 0.01, mp.y) * 0.5;
            d3 = min(d3, d32);
            o.d = smin(o.d, d3, 0.5);
        }

        // outer tentacles
        if (pNew.y < 0.2 && pNew.y > -3.0) {
            var op: vec3<f32> = pNew;
            let opxz = pModPolar(op.xz, 13.0, 0.5);
            op.x = opxz.x;
            op.z = opxz.y;
            
            // add perturbations here as well
            var d4: f32 = length(op.xz - vec2<f32>(0.65, 0.1)) - remap(0.8, -3.0, 0.1, 0.0, op.y);
            d4 += (sin(op.y*15.)+sin(op.y*15.))*.02;

            if (d4 < o.d) {
                o.m = 3.0;
                o.d = d4;
            }
            o.d = smin(o.d, d4, 0.05);
        }

        // stringy tentacles
        if (pNew.y < 0.2 && pNew.y > -3.5) {
            var op: vec3<f32> = pNew;
            var opxz = pModPolar(op.xz, 15.0, 1.0);

            // more animated stringy tentacles
            opxz += sway * 0.2;
            opxz += pump * 0.05;

            op.x = opxz.x;
            op.z = opxz.y;
            var d4: f32 = length(op.xz - vec2<f32>(0.85, 0.01)) - remap(0.8, -3.0, 0.01, 0.0, op.y);

            if (d4 < o.d) {
                o.m = 1.0;
                o.d = d4;
            }
            o.d = smin(o.d, d4, 0.01);
        }
    }
    
    o.pump = pump;
    o.uv = pNew;
    
    o.d *= 0.8;
    return o;
}

// CastRay function
// performs ray marching to find object intersections
fn CastRay(r: Ray) -> DE {
    var d: f32 = 0.0; // total dist traveled along ray

    var o: DE; // output DE to hold intersection data
    var s: DE; // temporary DE for current distance estimation

    var dC: f32 = MAX_DISTANCE; // dist to next cell boundary
    var p: vec3<f32>; // current pos along ray
    var q: RC; // repetition cell data
    var t: f32 = time;
    var grid: vec3<f32> = vec3<f32>(5.0, 50.0, 50.0); // grid size for repeating jellies in scene
    //var grid: vec3<f32> = vec3<f32>(5.0, 180.0, 180.0); 
    
    // ray marching loop
    for (var i: f32 = 0.0; i < MAX_STEPS; i+=1) {
        p = r.o + r.d * d; // current pos along ray
        p += 1025.; // offset pos to avoid neg coords

        p.y -= 0.5 * t;  // Make the move up
        p.x += t;  // Make jellyfish fly forward

        //s = map(p, vec3(0.)); // single jelly

        q = Repeat(p, grid); // repetition cell for current pos

        // compute dist to cell boundaries along reach axis
        var rCx = ((2.0 * step(0.0, r.d.x) - 1.0) * q.h.x - q.p.x) / r.d.x;
        var rCy = ((2.0 * step(0.0, r.d.y) - 1.0) * q.h.y - q.p.y) / r.d.y;
        var rCz = ((2.0 * step(0.0, r.d.z) - 1.0) * q.h.z - q.p.z) / r.d.z;

        dC = min(min(rCx, rCy), rCz) + 0.01; // Distance to cell just past boundary

        var N: f32 = N3(q.id); // generate noise based on cell ID
        var offset: vec3<f32> = (N31(N) - 0.5) * grid * vec3<f32>(0.5, 0.7, 0.5); // random offset
        q.p += offset; // Apply the random offset to the position

        // check if ray is close enough to need detailed dist estimation
        if (Dist(q.p.xz, r.d.xz, vec2<f32>(0.0, 0.0)) < 1.1) {
            s = map(q.p, q.id); // detailed dist estimation
        } else {
            s.d = dC;
        }

        // check if ray hit object or exceeded max dist
        if (s.d < HIT_DISTANCE || d > MAX_DISTANCE) { 
            break;
        }

        // advance the ray by min of estimated dist and dist to next cell boundary
        d += min(s.d, dC); 
    }

    // if intersection found, populate DE struct
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
fn VolTex(uv: vec3<f32>, // surface pos
        p: vec3<f32>, // volume shell pos
        scale: f32, 
        pump: f32) -> f32 {
    
    var p_scaled: vec3<f32> = p;
    p_scaled.y *= scale; // scale y components to stretch/compress pattern vertically

    // compute repeating value along x-axis to create horizontal segments
    var s2: f32 = 5.0 * p_scaled.x / twopi;
    var id: f32 = floor(s2);
    s2 = fract(s2);

    // create 2D point centered within segment for radial computations
    var ep: vec2<f32> = vec2<f32>(s2 - 0.5, p_scaled.y - 0.6);
    var ed: f32 = length(ep);
    var e: f32 = B(0.35, 0.45, 0.05, ed);

    // generate high-freq sine wave along segment
    var s: f32 = sin(s2 * twopi * 15.0) * 0.5 + 0.5;
    s = s * s;
    s = s * s;
    s *= smoothstep(-0.3, 1.4, uv.y - cos(s2 * twopi) * 0.2 + 0.3) * smoothstep(-0.6, -0.3, uv.y);
    
    // stripes on jelly head
    var mask: f32 = sin(p_scaled.x * twopi * 2.0) * 0.5 + 0.5;
    s *= mask * mask * 2.0;
    
    return s + e * pump * 2.0;
}

// Jelly texture function
fn JellyTex(p: vec3<f32>) -> vec4<f32> { 
    var pNew = p;

    // convert to spherical coords
    var s: vec3<f32> = vec3<f32>(atan2(pNew.x,pNew.z), length(pNew.xz), pNew.y);
    
    // base color 
    var b: f32 = 0.75 + sin(s.x * 6.0) * 0.25; // sine wave that repeats around jelly
    b = mix(1.0, b, s.y * s.y);
    
    pNew.x += sin(s.z * 10.0) * 0.1; // vertical ripples 
    var b2: f32 = cos(s.x * 26.0) - s.z - 0.7; 
   
    b2 = smoothstep(0.1, 0.6, b2); // secondary color component
    return vec4<f32>(b + b2, 0.0, 0.0, 0.0);  // ripples in red channel only 
}

// calculates final color for a given pixel
fn render(uv: vec2<f32>, camRay: Ray, bg: vec3<f32>, accent: vec3<f32>) -> vec3<f32> {

    var col: vec3<f32> = mix(baseColor, bg, 0.1);

    // cast ray into scene
    var o: DE = CastRay(camRay);
    
    var t: f32 = time;
    var L: vec3<f32> = up;

    //if ray hits object
    if (o.m > 0.0) {
        
        // normal at the intersection point
        var n: vec3<f32> = calcNormal(o);

        // lambertian shading term
        var lambert: f32 = clamp(dot(n, L), 0, 1);

        // reflection vect
        var R: vec3<f32> = reflect(camRay.d, n);

        // fresnel for reflection intensity
        var fresnel: f32 = clamp(1.0 + dot(camRay.d, n), 0, 1);
        
        // reflected bg color
        var refl: vec3<f32> = bg;

        // distance fog (background blend)
        var fade: f32 = 0.0;
        
        // material-specific shading
        if (o.m == 1.0) { 
            // jellyfish head

            // accum volutmetric density
            var density: f32 = 0.0;
            for (var i: f32 = 0.0; i < VOLUME_STEPS; i+=1) {

                // sample positions inside the head
                var radius =  0.8 + i * 0.015;
                var sd: f32 = sph(o.uv, camRay.d, vec3<f32>(0.0), radius).x;
                if (sd != MAX_DISTANCE) {

                    // UV coords for volumetric texture 
                    var intersect: vec2<f32> = o.uv.xz + camRay.d.xz * sd;
                    var uv: vec3<f32> = vec3<f32>(atan2(intersect.x,intersect.y), length(intersect.xy), o.uv.z);

                    // accum density from volumetric texture
                    density += VolTex(o.uv, uv, 1.4 + i * 0.03, o.pump);
                }
            }

            // avg density
            var volTex: vec4<f32> = vec4<f32>(accent, density / VOLUME_STEPS);

            // base color from jellyfish texture
            var dif: vec3<f32> = JellyTex(o.uv).rgb;
            dif *= max(0.2, lambert);

            // blend volumetric and base color 
            col = mix(col, volTex.rgb, volTex.a);
            col = mix(col, dif, 0.25);

            // add reflections
            col += fresnel * refl * clamp(dot(up, n), 0, 1);

            // Fade
            fade = max(fade, smoothstep(0.0, 1.0, fresnel));

        } else if (o.m == 2.0) { 
            // Inside tentacles
            
            // base color
            var dif: vec3<f32> = accent;
            col = mix(col, dif, fresnel); // mix with bg

            col *= mix(0.6, 1.0, smoothstep(-1.5, 0.0, o.uv.y)); // brightness based on vertical pos

            // glow effect 
            var prop: f32 = o.pump + 0.25;
            prop *= prop * prop;
            col += pow(1.0 - fresnel, 20.0) * dif * prop;

            fade = fresnel; // update fade

        } else if (o.m == 3.0) { 
            // Outside tentacles
            var dif: vec3<f32> = accent; // base color 
            var d: f32 = smoothstep(13.0, 100.0, o.d); 
            col = mix(bg, dif, pow(1.0 - fresnel, 5.0)); 
        }

        fade = max(fade, smoothstep(0.0, 100.0, o.d));
        col = mix(col, bg, fade);

    } else {
        col = bg;
    }

    return col;
} 

@fragment
fn main(in: FragmentInput) -> @location(0) vec4f {
    var uv: vec2<f32> = in.texCoord;
    uv -= 0.5;

    // camera setup ----------------------
    let camPos = cameraUniforms.cameraPos.xyz;
    let camForward = normalize(cameraUniforms.cameraLookPos.xyz - camPos);
    let camLeft = -normalize(cross(up, camForward));
    let camUp = -normalize(cross(camForward, camLeft)); 
    let cami = (camPos + camForward) + camLeft * uv.x + camUp * uv.y;

    var camRay: Ray; 
    camRay.o = camPos;                      // ray origin = camera position
    camRay.d = normalize(cami - camPos);   // ray direction is the vector from the cam pos through the point on the imaginary screen
    // end camera setup -------------------
    
    // setup UVs
    let index = vec2u(in.fragPos.xy);
    let depth = camPos.y * DIST_SCALE;
    
    var bg = select(
        textureLoad(colorTexture, index, 0).xyz,
        aces_tonemap(multipleScatteringIrradiance(depth, -camRay.d, 1024)),
        textureLoad(depthTexture, index, 0).x == 1.0); // background is previous pass
    //bg = vec3<f32>(0.5, 0.6, 0.6); // solid background

    //var t = 0.4f * time;
    var accent = mix(accentColor1, accentColor2, sin(15.456));

    var col: vec3<f32> = render(uv, camRay, bg, accent); // entry-point into jellyfish rendering
    
    if (camPos.y >= 7.f) { // FIXME: don't hardcode this
        return vec4<f32>(bg, 1.0); // don't make jellies if camera is above ocean surface
    }
    return vec4<f32>(col, 1.0);

}