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

const HEX_SIZE = 15.f; // size of hexagonal tiles
const SQRT3 = 1.73205080757;

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

// Sample from an exemplar texture with a random offset
fn exemplar_sample(pos: vec2<f32>, tile_idx: vec2<f32>) -> f32 {
    let offset = HEX_SIZE; // Add randomness per tile
    return getwaves(pos + offset, 38); // Reuse getwaves function for content
}

// Compute the center of a hexagon given grid coordinates
fn hexCenter(gridCoords: vec2<f32>) -> vec2<f32> {
    let x = gridCoords.x * 1.5 * HEX_SIZE;
    let y = gridCoords.y * SQRT3 * HEX_SIZE + (gridCoords.x % 2.0) * SQRT3 * HEX_SIZE * 0.5;
    return vec2(x, y);
}

fn calcCenter(offset: vec2<f32>, position: vec2<f32>) -> vec2<f32> {
    let gridIndex = floor(vec2((position.x + offset.x) / (1.5 * HEX_SIZE), (position.y + offset.y) / (SQRT3 * HEX_SIZE)));
    return hexCenter(gridIndex);
}

@compute
@workgroup_size(16, 16)
fn main(@builtin(global_invocation_id) globalIdx: vec3u) {

    let x = f32(globalIdx.x);
    let y = f32(globalIdx.y);

    let iterations = 38;
    let depth = 1.f;

    // Tessendorf approx with perlin blend ----------------------
    var position = vec2f(x, y) + world_position;
    let wave_amplitude = 0.5 * perlinNoise(position / 50); // need a better way of adding perlin noise for randomness maybe??
    var wave_height = getwaves(position, iterations) * depth - depth + wave_amplitude; 

    // hexagonal tiling & blending: redTexture(x) * bary(p1) + greenTexture(x) * bary(p2) + blueTexture(x) * bary(p3)
    // ---------------------------------------------------------

    // overlapped triangle vertices
    let a = calcCenter(vec2(0.f,0.f), position);
    let b = calcCenter(vec2( HEX_SIZE / 2.f ,  -HEX_SIZE * SQRT3 / 2.f), position);
    let c = calcCenter(vec2( -HEX_SIZE / 2.f ,  -HEX_SIZE * SQRT3 / 2.f), position);

    // Barycentric computation-----------------------------

    // Compute the areas of the sub-triangles
    let areaABC = (b.x - a.x) * (c.y - a.y) - (c.x - a.x) * (b.y - a.y);
    let areaPBC = (b.x - position.x) * (c.y - position.y) - (c.x - position.x) * (b.y - position.y);
    let areaPCA = (c.x - position.x) * (a.y - position.y) - (a.x - position.x) * (c.y - position.y);
    let areaPAB = (a.x - position.x) * (b.y - position.y) - (b.x - position.x) * (a.y - position.y);


    // Compute the barycentric weights
    var w1 = abs(areaPBC / areaABC);
    var w2 = abs(areaPCA / areaABC);
    var w3 = abs(areaPAB / areaABC);

    // Compute the sum of squared weights
    let weight_norm = sqrt(w1 * w1 + w2 * w2 + w3 * w3);

    // Normalize the weights
    w1 /= weight_norm;
    w2 /= weight_norm;
    w3 /= weight_norm;

    // Assume exemplar_mean is precomputed or estimated
    //let exemplar_mean = /* compute or estimate the mean of the exemplar */;

    // Subtract mean from each sample
    let sample0 = exemplar_sample(position, a);// - exemplar_mean;
    let sample1 = exemplar_sample(position, b * 2);// - exemplar_mean;
    let sample2 = exemplar_sample(position, c * 3);// - exemplar_mean;

    // Compute the blended value
    var final_wave_height = sample0 * w1 + sample1 * w2 + sample2 * w3;
    // Add the mean back
    //final_wave_height += exemplar_mean;

    textureStore(displacementMap, globalIdx.xy, vec4(final_wave_height, 0, 0, 1));

    // Store the computed normal in the normal map
    let normal = normal(position, 0.01, depth, wave_amplitude);
    textureStore(normalMap, globalIdx.xy, vec4f(normal + 0.5, 1.0));  // Map from [-1, 1] to [0, 1]

}
