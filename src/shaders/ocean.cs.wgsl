struct GlobalUniform {
    time: f32;
    windDirection: vec2<f32>;
    windSpeed: f32;
    amplitude: f32;
};

@group(0) @binding(0) var<uniform> globalUniform: GlobalUniform;
@group(0) @binding(1) var<storage, read_write> displacementMap: array<f32>;
@group(0) @binding(2) var<storage, read_write> normalMap: array<f32>;

const N: u32 = 512u;
const L: f32 = 1000.0; // Size of the simulation area

// The Phillips spectrum for wave generation
fn phillipsSpectrum(k: vec2<f32>) -> f32 {
    let kLength = length(k);
    if (kLength == 0.0) {
        return 0.0;
    }

    let kNorm = normalize(k);
    let windDir = normalize(globalUniform.windDirection);
    let kDotWind = dot(kNorm, windDir);

    // Phillips spectrum formula
    let L = pow(globalUniform.windSpeed, 2.0) / 9.81;
    let phillips = globalUniform.amplitude * exp(-1.0 / (kLength * L) * (kLength * L)) 
        / (kLength * kLength * kLength * kLength);
    return phillips * kDotWind * kDotWind;
}

// Generate wave heights using the Phillips spectrum
fn generateHeight(k: vec2<f32>, time: f32) -> f32 {
    let omega = sqrt(9.81 * length(k));
    let phase = time * omega;
    let h0 = phillipsSpectrum(k);
    return h0 * cos(phase) + h0 * sin(phase);
}

@compute @workgroup_size(8, 8)
fn main(@builtin(global_invocation_id) id: vec3<u32>) {
    let x = f32(id.x);
    let y = f32(id.y);

    // Map from spatial coordinates to frequency domain
    let kx = (x - f32(N) / 2.0) * (2.0 * 3.14159265359 / L);
    let ky = (y - f32(N) / 2.0) * (2.0 * 3.14159265359 / L);
    let k = vec2<f32>(kx, ky);

    // Generate the wave displacement
    let height = generateHeight(k, globalUniform.time);

    // Store the displacement and normal
    let index = id.x + id.y * N;
    displacementMap[index] = height;

    // Calculate the normal based on partial derivatives
    let normalX = -kx * height;
    let normalY = -ky * height;
    normalMap[index] = normalX * normalX + normalY * normalY;
}
