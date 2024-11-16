@group(0) @binding(0) var<uniform> world_position: vec2f;
@group(0) @binding(1) var displacementMap: texture_storage_2d<r32float, write>;
@group(0) @binding(2) var normalMap: texture_storage_2d<rgba8unorm, write>;
@group(0) @binding(3) var<uniform> time: f32;

// helpful reference: https://www.shadertoy.com/view/MdXyzX

const PI = 3.14159265358979323846264; // Life of π

const TILE_SIZE = 100.0; // Size of the hexagonal tiles
const NUM_TILES = 3;     // Number of overlapping tiles
const ITERATIONS = 39;

// functions for publication implementation 
//(http://arnaud-schoentgen.com/publication/2024_orientable_ocean/2024_orientable_ocean.pdf)

// resources: 
// https://www.shadertoy.com/view/McycDh
// https://www.shadertoy.com/view/McycW1
fn HexagonalLength(uv: vec2<f32>) -> f32
{
    let uvNew = abs(uv);
    var dist = dot(uvNew, normalize(vec2(1.0, sqrt(3.0))));
    dist = max(dist, uvNew.x);
    return dist;
}

fn DistanceToHexEdge(uv: vec2<f32>) -> f32
{
    return -HexagonalLength(uv) + 0.5;
}

// Hexagonal grid function
fn hex_grid(p: vec2<f32>) -> vec2<f32> {
    var pNew = abs(p);
    let q = vec2<f32>(sqrt(3.0) * 0.5, 1.5) * p;
    return floor(q + vec2(0.5, 0.5));
    //return max(dot(pNew, vec2(1.7320508, 1) * 0.5), pNew.y);
}

fn barycentric_weight(center: vec2<f32>, pos: vec2<f32>) -> f32 {
    let dist = length(pos - center) / (TILE_SIZE * 0.5); // Use half the tile size for a smoother falloff
    return max(1.0 - dist, 0.0); // Wider blending range
}

// Sample from an exemplar texture with a random offset
fn exemplar_sample(pos: vec2<f32>, tile_idx: vec2<f32>) -> f32 {
    let offset = random2(tile_idx) * TILE_SIZE * 0.5; // Increase randomness for h(k_i(x)): Random offset
    return getwaves(pos + offset); // E(x + h(k_i(x))): Content of the exemplar
}

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

fn getwaves(position: vec2<f32>) -> f32 {

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
    for(var i=0; i < ITERATIONS; i++) {

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
  
    let ex = vec2(e, 0);
    let height = getwaves(pos.xy) * depth;
    let a = vec3(pos.x, height, pos.y);
    return normalize(
    cross(
        a - vec3(pos.x - e, getwaves(pos.xy - ex.xy) * depth, pos.y), 
        a - vec3(pos.x, getwaves(pos.xy + ex.yx) * depth, pos.y + e)
    )
    );
}

@compute
@workgroup_size(16, 16)
fn main(@builtin(global_invocation_id) globalIdx: vec3u) {

    let x = f32(globalIdx.x);
    let y = f32(globalIdx.y);
    let depth = 1.f;

    // Calculate the wave phase
    var position = vec2f(x, y) + world_position;
    let wave_amplitude = 0.5 * perlinNoise(position / 50); // need a better way of adding perlin noise for randomness maybe??
    var wave_height = getwaves(position) * depth - depth + wave_amplitude;

    // Hexagonal tiling ------------------------------------------------------------------
    var final_wave_height = wave_height; 
    var total_weight = 0.0;
    var exemplar_mean = 0.5;
    var tile_idx = hex_grid(position / TILE_SIZE + vec2(f32(0)));
    var tile_sample = exemplar_sample(position, tile_idx); 
    

    for (var i = 0; i < NUM_TILES; i++) {
        // Hexagonal grid and random offset
        tile_idx = hex_grid(position / TILE_SIZE + vec2(f32(i)));
        let center = tile_idx * TILE_SIZE + vec2(TILE_SIZE / 2.0); // Offset by half a tile
        let weight = barycentric_weight(center, position); // w_i(x)
        tile_sample = exemplar_sample(position, tile_idx); // E_i(x)

        // sample and blend
        final_wave_height += weight * (tile_sample - exemplar_mean); // w_i(x) * (E_i(x) - μ)
        total_weight += weight;
    }

    textureStore(displacementMap, globalIdx.xy, vec4(final_wave_height, 0, 0, 1));

    // -----------------------------------------------------------------------------------

    let normal = normal(position, 0.01, depth, wave_amplitude);
    
    // Store the computed normal in the normal map
    textureStore(normalMap, globalIdx.xy, vec4f(normal + 0.5, 1.0));  // Map from [-1, 1] to [0, 1]

}
