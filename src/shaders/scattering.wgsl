const numWavelengths = 9; // TODO: Maybe non-constant? May affect performance

struct Wavelength {
    value: f32,
    weight: f32, // since the wavelengths are not evenly spaced
    padding: vec2f
};

struct WaterProperties {
    sigma_s: f32, // scattering
    sigma_t: f32, // extinction
    k_d: f32, // downwelling attenunation coefficient
    padding: f32
}

@group(0) @binding(0) var<uniform> cameraUniforms: CameraUniforms;
@group(0) @binding(2) var<uniform> wavelengths: array<Wavelength, numWavelengths>;
@group(0) @binding(3) var<uniform> waterProperties: array<WaterProperties, numWavelengths>;
@group(0) @binding(4) var<uniform> sensitivities: array<vec3f, numWavelengths>;

const lightDirection = normalize(vec3f(0.5, 1.0, 0.5));
const SUN_STRENGTH = 10.0;
const DIST_SCALE = 0.05;

fn totalIrradiance(
    origin: vec3f,
    pos: vec3f,
    nor: vec3f,
    albedo: vec3f
) -> vec3f {
    let depth = origin.y * DIST_SCALE;
    let vector = origin - pos;
    let direction = normalize(vector);
    let distance = length(vector) * DIST_SCALE;

    var irradiance = directSunIrradiance(depth, distance, nor, albedo);

    irradiance += multipleScatteringIrradiance(
        depth,
        direction,
        distance
    );

    return irradiance;
}

fn upsampleAlbedo(
    albedo: vec3f,
    wavelength: f32
) -> f32 {
    // We don't actually have spectral textures so we need to upsample somehow
    // Since it's dependent not just on wavelength but color as well, we can't precompute it
    if (wavelength < 480) {
        return albedo.b;
    } else if (wavelength < 560) {
        return albedo.g;
    } else {
        return albedo.r;
    }
}

fn directSunIrradiance(
    depth: f32,
    distance: f32,
    nor: vec3f, // normal
    albedo: vec3f,
) -> vec3f {
    // TODO: maybe do something a bit more physically motivated?
    // Maybe just a lambert term with a static sun direction?
    // let diffuse = sqrt(clamp(0.5 + 0.5 * nor.y, 0, 1));
    let diffuse = max(dot(nor, lightDirection), 0.3);

    // TODO: caustics known from surface radiance
    
    var totalIrradiance = vec3f();

    for (var i = 0u; i < numWavelengths; i++) {
        let wavelength = wavelengths[i].value;
        let props = waterProperties[i];

        let downwellingExtinction = exp(props.k_d * depth);
        let directExtinction = exp(-props.sigma_t * distance);

        let irradiance = (upsampleAlbedo(albedo, wavelength) * diffuse) * SUN_STRENGTH * downwellingExtinction * directExtinction;
        totalIrradiance += irradiance * wavelengths[i].weight * sensitivities[i];
    }

    return totalIrradiance / 300;
}

fn multipleScatteringIrradiance(
    depth: f32,
    direction: vec3f,
    distance: f32
) -> vec3f {
    let y_w = -direction.y;
    var totalIrradiance = vec3f();
    for (var i = 0u; i < numWavelengths; i++) {
        let props = waterProperties[i];

        let c = props.k_d * y_w - props.sigma_t;

        let irradiance = (props.sigma_s * SUN_STRENGTH) / (4 * PI * c)
            * (exp(distance * c) - 1)
            * exp(props.k_d * depth);

        totalIrradiance += irradiance * wavelengths[i].weight * sensitivities[i];
    }
    return totalIrradiance / 300;
}