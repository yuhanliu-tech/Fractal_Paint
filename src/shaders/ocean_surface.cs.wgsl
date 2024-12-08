@group(0) @binding(0) var<uniform> world_position: vec2f;
@group(0) @binding(1) var displacementMap: texture_storage_2d<r32float, write>;
@group(0) @binding(2) var normalMap: texture_storage_2d<rgba8unorm, write>;
@group(0) @binding(3) var<uniform> time: f32;

// helpful reference: https://www.shadertoy.com/view/MdXyzX

const u_wind = vec2<f32>(1, 0);
const u_amplitude = f32(20.0);
const u_g = f32(9.81);
const l = 100.0;

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
    var timeMultiplier = 1.f;
    var weight = 1.f;
    let DRAG_MULT = 0.48;
    let wave_phase = length(pos) * 0.1;

    // iterate through octaves
    for(var i=0; i < iterations; i++) {

        let p = vec2f(sin(iter), cos(iter));

        var res = wavedx(position, p, wave_frequency, time * timeMultiplier + wave_phase);

        pos += p * res.y * weight * DRAG_MULT;

        let actual_weight = min(weight, 0.1);

        sumOfValues += res.x * actual_weight;
        sumOfWeights += actual_weight;

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
fn exemplar_sample(pos: vec2<f32>, triVerts: vec2<f32>) -> f32 {
    let offset = random2(triVerts) * 100; // Add randomness per tile
    return getwaves(pos + offset, 38); // Reuse getwaves function for content
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
    
    let triangle = get_triangle_vertices(position);
    let a = triangle[0];
    let b = triangle[1];
    let c = triangle[2];

    let weights = barycentric_weights(position, a, b, c);
    // let areaABC = SQRT3 * HEX_SIZE * HEX_SIZE / 2.f;
    // let areaPBC = double_triangle_area(position, b, c);
    // let areaPCA = double_triangle_area(position, c, a);
    // let areaPAB = double_triangle_area(position, a, b);

    // var w1 = areaPBC / areaABC;
    // var w2 = areaPCA / areaABC;
    // var w3 = areaPAB / areaABC;

    // let weight_norm = w1 * w1 + w2 * w2 + w3 * w3;
    // w1 /= weight_norm;
    // w2 /= weight_norm;
    // w3 /= weight_norm;

    let samples = vec3f(
        exemplar_sample(position, a),
        exemplar_sample(position, b),
        exemplar_sample(position, c)
    );

    var final_wave_height = dot(weights, samples);

    // let sample0 = exemplar_sample(position, a);
    // let sample1 = exemplar_sample(position, b);
    // let sample2 = exemplar_sample(position, c);

    // var final_wave_height = sample0 * w1 + sample1 * w2 + sample2 * w3;
    textureStore(displacementMap, globalIdx.xy, vec4(final_wave_height, 0, 0, 1));

    // Store the computed normal in the normal map
    let normal = normal(position, 0.01, depth, final_wave_height);
    textureStore(normalMap, globalIdx.xy, vec4f(normal + 0.5, 1.0));  // Map from [-1, 1] to [0, 1]

}