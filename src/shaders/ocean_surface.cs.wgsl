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

const g_offsets = array<vec2<f32>, 3>(
    vec2<f32>(0.1039284, 0.20344234),
    vec2<f32>(0.9458, 0.86602540378),
    vec2<f32>(0.34578, 0.9023423)
);

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
fn exemplar_sample(pos: vec2<f32>, tile_idx: u32) -> f32 {
    let offset = g_offsets[tile_idx]; // Add randomness per tile
    return getwaves(pos + offset, 38); // Reuse getwaves function for content
}

fn get_triangle_vertices(uv: vec2<f32>, hex_size: f32) -> array<vec2<f32>, 3> {
    let triangle_scale = 0.86602540378; // sqrt(3)/2, for equilateral triangles
    let scaled_uv = uv / hex_size;      // Scale UV coordinates by hex size
    var triangle_coords = floor(scaled_uv); // Base integer coordinates
    var mod_y = floor(triangle_coords.y % 2.0);
    
    // Adjust x coordinate for staggered rows
    triangle_coords.x = triangle_coords.x * 2.0 + mod_y;
    
    let local = vec2<f32>(
        fract(scaled_uv.x + mod_y * 0.5) - 0.5,
        fract(scaled_uv.y)
    );
    
    // Determine if the point is in the upper or lower triangle
    if (local.y > abs(local.x) * 2.0) {
        if (local.x < 0.0) {
            triangle_coords.x += 1.0;
        } else {
            triangle_coords.x -= 1.0;
        }
    }
    if (local.x >= 0.0 && mod_y == 0.0) {
        triangle_coords.x += 2.0;
    }
    
    // Convert triangle_coords back to grid coordinates for vertex calculation
    let base_x = triangle_coords.x * 0.5 * hex_size;  // X position
    let base_y = triangle_coords.y * triangle_scale * hex_size; // Y position
    
    // Calculate the three vertices of the triangle
    let v0 = vec2<f32>(base_x, base_y);                                // Bottom-left vertex
    let v1 = vec2<f32>(base_x + hex_size * 0.5, base_y + hex_size * triangle_scale); // Top vertex
    let v2 = vec2<f32>(base_x + hex_size, base_y);                    // Bottom-right vertex
    
    return array<vec2<f32>, 3>(v0, v1, v2);
}

fn is_upper_triangle(uv: vec2<f32>, hex_size: f32) -> i32 {
    let triangle_scale = 0.86602540378; // sqrt(3)/2, for equilateral triangles
    let scaled_uv = uv / hex_size;      // Scale UV coordinates by hex size
    let mod_y = floor(scaled_uv.y % 2.0); // Determine row parity (odd/even)
    
    // Local position within the cell
    let local_x = fract(scaled_uv.x + mod_y * 0.5) - 0.5; // Shifted x-coordinate
    let local_y = fract(scaled_uv.y);                    // y-coordinate within the cell

    // Check if the point is in the upper or lower triangle
    if local_y > abs(local_x) * 2.0 {
        return 1; // Upper triangle
    }
    return 0; // Lower triangle
}

fn get_hex_index(pos: vec2<f32>) -> u32 {
    let x_steps = pos.x / HEX_SIZE;
    let y_steps = pos.y / (HEX_SIZE * SQRT3) * 2;
    return u32(round(x_steps) + round(y_steps)) % 3;
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
    //---------------------------------------------------------

    // overlapped triangle vertices
    let triangle = get_triangle_vertices(position, HEX_SIZE);
    let a = triangle[0];
    let b = triangle[1];
    let c = triangle[2];

    // Barycentric computation-----------------------------

    // Compute the areas of the sub-triangles
    let areaABC = SQRT3 * HEX_SIZE * HEX_SIZE / 4.f;
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
    // let exemplar_mean = /* compute or estimate the mean of the exemplar */;

    // Subtract mean from each sample
    let sample0 = exemplar_sample(position, get_hex_index(a));// - exemplar_mean;
    let sample1 = exemplar_sample(position, get_hex_index(b));// - exemplar_mean;
    let sample2 = exemplar_sample(position, get_hex_index(c));// - exemplar_mean;

    // Compute the blended value
    var final_wave_height = sample0 * w1 + sample1 * w2 + sample2 * w3;
    //final_wave_height = f32(is_upper_triangle(position, HEX_SIZE));
    
    // Add the mean back
    //final_wave_height += exemplar_mean;

    textureStore(displacementMap, globalIdx.xy, vec4(final_wave_height, 0, 0, 1));

    // Store the computed normal in the normal map
    let normal = normal(position, 0.01, depth, wave_amplitude);
    textureStore(normalMap, globalIdx.xy, vec4f(normal + 0.5, 1.0));  // Map from [-1, 1] to [0, 1]

}
