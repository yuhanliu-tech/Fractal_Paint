@group(0) @binding(0) var<uniform> world_position: vec2f;
@group(0) @binding(1) var displacementMap: texture_storage_2d<r32float, write>;
@group(0) @binding(2) var normalMap: texture_storage_2d<rgba8unorm, write>;
@group(0) @binding(3) var<uniform> time: f32;

// helpful reference: https://www.shadertoy.com/view/MdXyzX

const u_wind = vec2<f32>(1, 0);
const u_amplitude = f32(20.0);
const u_g = f32(9.81);
const PI = 3.14159265358979323846264; // Life of π
const l = 100.0;

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

fn getwaves(position: vec2<f32>, iterations: i32) -> f32 {

    var pos = position;

    // copied this all because am lazy
    var wave_frequency = 0.1; 
    var iter = 0.f; 
    var sumOfValues = 0.f;
    var sumOfWeights = 0.f;
    var timeMultiplier = 2.f;
    var weight = 1.f;
    let DRAG_MULT = 0.48;
    let wave_phase = length(pos) * 0.1;

    // iterate through octaves
    for(var i=0; i < iterations; i++) {

        let p = vec2f(sin(iter), cos(iter));

        var res = wavedx(position, p, wave_frequency, time * timeMultiplier + wave_phase);

        pos += p * res.y * weight * DRAG_MULT;

        sumOfValues += res.x * weight;
        sumOfWeights += weight;

        // next octave
        weight = mix(weight, 0.0, 0.2);
        wave_frequency *= 1.18;
        timeMultiplier *= 1.07;

        iter += 123283.963;
    }
    return sumOfValues / sumOfWeights;
}

fn wavedx(position: vec2<f32>, 
direction: vec2<f32>, 
frequency: f32,
timeshift: f32) -> vec2<f32> {
    let x = dot(direction, position) * frequency + timeshift;
    let wave = exp(sin(x) - 1.0);
    let dx = wave * cos(x);
    return vec2(wave, -dx);
}

fn normal(pos: vec2<f32>, e: f32, depth: f32, wave_amplitude: f32) -> vec3<f32> {
  
    let ITERATIONS_NORMAL = 18;
    let ex = vec2(e, 0);
    let height = getwaves(pos.xy, ITERATIONS_NORMAL) * depth;
    let a = vec3(pos.x, height, pos.y);
    return normalize(
    cross(
        a - vec3(pos.x - e, getwaves(pos.xy - ex.xy, ITERATIONS_NORMAL) * depth, pos.y), 
        a - vec3(pos.x, getwaves(pos.xy + ex.yx, ITERATIONS_NORMAL) * depth, pos.y + e)
    )
    );
}

fn blugausnoise(c1: vec2<f32>) -> f32 {

    let cx = vec3<f32>(c1.x + vec3<f32>(-1,0,1));
    let f0 = fract(vec4<f32>(cx * 9.1031, c1.y * 8.1030));
    let f1 = fract(vec4<f32>(cx * 7.0973, c1.y * 6.0970));
	let t0 = vec4<f32>(f0.xw, f1.xw);
	let t1 = vec4<f32>(f0.yw, f1.yw);
	let t2 = vec4<f32>(f0.zw, f1.zw);
    let p0 = vec4<f32>(t0 + dot(t0, t0.wzxy + 19.19));
    let p1 = vec4<f32>(t1 + dot(t1, t1.wzxy + 19.19));
    let p2 = vec4<f32>(t2 + dot(t2, t2.wzxy + 19.19));
	let n0 = fract(vec4<f32>(p0.zywx * (p0.xxyz + p0.yzzw)));
	let n1 = fract(vec4<f32>(p1.zywx* (p1.xxyz+ p1.yzzw)));
	let n2 = fract(vec4<f32>(p2.zywx* (p2.xxyz+ p2.yzzw)));
    return dot(0.5 * n1 - 0.125 * (n0 + n2), vec4<f32>(1));
}

@compute
@workgroup_size(16, 16)
fn main(@builtin(global_invocation_id) globalIdx: vec3u) {

    let x = f32(globalIdx.x);
    let y = f32(globalIdx.y);

    let iterations = 38;
    let depth = 1.f;

    // Calculate the wave phase
    var position = vec2f(x, y) + world_position;
    let wave_amplitude = perlinNoise(position / 50); // need a better way of adding perlin noise for randomness maybe??

    var wave_height = 0.6 * getwaves(position, iterations) * depth - depth + wave_amplitude;

    textureStore(displacementMap, globalIdx.xy, vec4(wave_height, 0, 0, 1));

    let normal = normal(position, 0.01, depth, wave_amplitude);
    
    // Store the computed normal in the normal map
    textureStore(normalMap, globalIdx.xy, vec4f(normal + 0.5, 1.0));  // Map from [-1, 1] to [0, 1]

}
