@group(0) @binding(0) var<uniform> world_position: vec2f;
@group(0) @binding(1) var displacementMap: texture_storage_2d<r32float, write>;
@group(0) @binding(2) var normalMap: texture_storage_2d<rgba8unorm, write>;

fn random2(p: vec2<f32>) -> vec2<f32> {
    return fract(sin(vec2(dot(p, vec2(127.1f, 311.7f)),
                 dot(p, vec2(269.5f,183.3f))))
                 * 43758.5453f);
}

fn surflet(P: vec2<f32>, gridPoint: vec2<f32>) -> f32 {
    // Compute falloff function by converting linear distance to a polynomial
    let distX = f32(abs(P.x - gridPoint.x));
    let distY = f32(abs(P.y - gridPoint.y));
    let tX = f32(f32(1) - f32(6) * pow(distX, f32(5)) + f32(15) * pow(distX, f32(4)) - f32(10) * pow(distX, f32(3)));
    let tY = f32(f32(1) - f32(6) * pow(distY, f32(5)) + f32(15) * pow(distY, f32(4)) - f32(10) * pow(distY, f32(3)));
    
    // Get the random vector for the grid point
    let gradient = vec2<f32>(normalize(f32(2) * random2(gridPoint) - vec2<f32>(f32(1), f32(1))));
    // Get the vector from the grid point to P
    let diff = vec2<f32>(P - gridPoint);
    // Get the value of our height field by dotting grid->P with our gradient
    let height = f32(dot(diff, gradient));
    // Scale our height field (i.e. reduce it) by our polynomial falloff function
    return height * tX * tY;
}

fn perlinNoise(uv: vec2<f32>) -> f32 {
    var surfletSum = f32(0);
    // Iterate over the four integer corners surrounding uv
    for(var dx = 0; dx <= 1; dx++) {
            for(var dy = 0; dy <= 1; dy++) {
                    surfletSum += surflet(uv, floor(uv) + vec2(f32(dx), f32(dy)));
            }
    }
    return surfletSum;
}

fn blugausnoise(c1: vec2<f32>) -> f32 {
    //c1 += 0.07* fract(iTime);
    
    //vec2 c0 = vec2(c1.x- 1.,c1.y);
    //vec2 c2 = vec2(c1.x+ 1.,c1.y);
    let cx = vec3<f32>(c1.x + vec3<f32>(-1,0,1));
    let f0 = fract(vec4<f32>(cx * 9.1031, c1.y * 8.1030));
    let f1 = fract(vec4<f32>(cx * 7.0973, c1.y * 6.0970));
	let t0 = vec4<f32>(f0.xw, f1.xw);//fract(c0.xyxy* vec4(.1031,.1030,.0973,.0970));
	let t1 = vec4<f32>(f0.yw, f1.yw);//fract(c1.xyxy* vec4(.1031,.1030,.0973,.0970));
	let t2 = vec4<f32>(f0.zw, f1.zw);//fract(c2.xyxy* vec4(.1031,.1030,.0973,.0970));
    let p0 = vec4<f32>(t0 + dot(t0, t0.wzxy + 19.19));
    let p1 = vec4<f32>(t1 + dot(t1, t1.wzxy + 19.19));
    let p2 = vec4<f32>(t2 + dot(t2, t2.wzxy + 19.19));
	let n0 = fract(vec4<f32>(p0.zywx * (p0.xxyz + p0.yzzw)));
	let n1 = fract(vec4<f32>(p1.zywx* (p1.xxyz+ p1.yzzw)));
	let n2 = fract(vec4<f32>(p2.zywx* (p2.xxyz+ p2.yzzw)));
    return dot(0.5 * n1 - 0.125 * (n0 + n2), vec4<f32>(1));
}

// COMPLEX OPERATIONS
fn conj(a: vec2<f32>) -> vec2<f32> {
    return vec2<f32>(a.x, -a.y);
}

const u_wind = vec2<f32>(1, 0);
const u_amplitude = f32(20.0);
const u_g = f32(9.81);
const PI = 3.14159265358979323846264; // Life of π
const l = 100.0;

fn philips(wave_vector: vec2<f32>) -> f32 {
    let k = sqrt(wave_vector.x * wave_vector.x + wave_vector.y * wave_vector.y);
    if (k == 0.0) {
        return 0.0;
    }
    
    // let V = length(u_wind);
    // let Lp = V*V/u_g;
    // var k = length(wave_vector);
    // k = max(k, 0.1);
    // return clamp(sqrt(
    //         u_amplitude
    //         *pow(dot(normalize(wave_vector), normalize(u_wind)), 2.0)
    //         *exp(-1.f/(pow(k*Lp,2.0)))
    //         // *exp(-1.f*pow(k*l,2.0))
    //     )/(k*k), -4000, 4000);

    let L2 = l * l;
    let k_dot_w = (wave_vector.x * u_wind.x + wave_vector.y * u_wind.y) / k;
    let P = u_amplitude * exp(-1.0 / (k * k * L2)) / (k * k * k * k) * pow(k_dot_w, 2);
    return P;

    // let p1 = u_amplitude / (k * k * k * k);
    // let p2 = dot(normalize(wave_vector), normalize(u_wind));
    // let p3 = exp(-1.0 / (k * Lp) * (k * Lp));
    // let p4 = exp(-1.0 * k * k * l * l);
    // return sqrt(p1 * p2 * p2 * p3);
    // return clamp(sqrt(
    //         u_amplitude
    //         *pow(, 2.0)
    //         *exp(-1.f/(pow(k*Lp,2.0)))
    //         *exp(-1.f*pow(k*l,2.0))
    //     )/(k*k), 0, 4000);  
}

@compute
@workgroup_size(16, 16)
fn main(@builtin(global_invocation_id) globalIdx: vec3u) {
    if (globalIdx.x >= 1024 || globalIdx.y >= 1024) {
        return;
    }

    let x = f32(globalIdx.x);
    let y = f32(globalIdx.y);

    let uv = vec2<f32>(x, y) + world_position;
    let noise = perlinNoise(uv / 50.0f);
    let noise2 = blugausnoise(vec2<f32>(x, y) + world_position);
    
    let wave_vector = vec2<f32>(2.0 * PI * fract(uv.x / 1024.0), 2.0 * PI * fract(uv.y / 1024.0));

    let vp = philips(wave_vector);
    let vn = philips(-wave_vector);

    let h = noise2 * sqrt(vp / 2.0);
    //let h = f32(noise2 * vp);
    //let h_est = conj(vec2<f32>(noise2 * vn));

    textureStore(displacementMap, globalIdx.xy, vec4(2 * noise, 0, 0, 0));
    textureStore(normalMap, globalIdx.xy, vec4f(2 * noise, 0, 1, 1));
}

