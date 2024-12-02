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
@group(0) @binding(1) var<uniform> wavelengths: array<Wavelength, numWavelengths>;
@group(0) @binding(2) var<uniform> waterProperties: array<WaterProperties, numWavelengths>;
@group(0) @binding(3) var<uniform> sensitivities: array<vec3f, numWavelengths>;

@group(2) @binding(0) var diffuseTex: texture_2d<f32>;
@group(2) @binding(1) var diffuseTexSampler: sampler;

struct FragmentInput
{
    @location(0) pos: vec3f,
    @location(1) nor: vec3f,
    @location(2) uv: vec2f
}

const SUN_STRENGTH = 10.0;

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
    origin: vec3f, // camera position
    point: vec3f, // fragment position
    nor: vec3f, // normal
    albedo: vec3f,
) -> vec3f {
    let depth = -point.y;

    // TODO: maybe do something a bit more physically motivated?
    // Maybe just a lambert term with a static sun direction?
    let diffuse = sqrt(clamp(0.5 + 0.5 * nor.y, 0, 1));

    // TODO: caustics known from surface radiance
    
    var totalIrradiance = vec3f();

    for (var i = 0u; i < numWavelengths; i++) {
        let wavelength = wavelengths[i].value;
        let props = waterProperties[i];

        let downwellingExtinction = exp(-props.k_d * depth);
        let directExtinction = exp(-props.sigma_t * length(point - origin));

        let irradiance = (upsampleAlbedo(albedo, wavelength) * diffuse) * SUN_STRENGTH * downwellingExtinction * directExtinction;
        totalIrradiance += irradiance * wavelengths[i].weight * sensitivities[i];
    }

    return totalIrradiance / 300;
}

fn testDirectIrradiance(
    origin: vec3f, // camera position
    point: vec3f, // fragment position
    nor: vec3f, // normal
    albedo: vec3f,
) -> f32 {

    let depth = point.y;
    let diffuse = sqrt(clamp(0.5 + 0.5 * nor.y, 0, 1)); // TODO: maybe use a nicer surface model

    let wavelength = wavelengths[0].value;
    let props = waterProperties[0];
    let downwellingExtinction = exp(-props.k_d * depth);
    let directExtinction = exp(-props.sigma_t * length(point - origin));

    let upsampledAlbedo = upsampleAlbedo(albedo, wavelength);
    let irradiance = (upsampledAlbedo * diffuse) * SUN_STRENGTH * downwellingExtinction * directExtinction;

    let redchannel = irradiance * wavelengths[0].weight * sensitivities[0].x;

    return redchannel;
}

fn multipleScatteringIrradiance(
    depth: f32,
    direction: vec3f,
    distance: f32
) -> vec3f {
    let y_w = -direction.y;
    var totalIrradiance = vec3f();
    for (var i = 0u; i < numWavelengths; i++) {
        let wavelength = wavelengths[i].value;
        let props = waterProperties[i];

        let c = props.k_d * y_w - props.sigma_t;

        let irradiance = (props.sigma_s * SUN_STRENGTH) / (4 * PI * c)
            * (exp(distance * c) - 1)
            * exp(props.k_d * depth);

        totalIrradiance += irradiance * wavelengths[i].weight * sensitivities[i];
    }
    return totalIrradiance / 300;
}

@fragment
fn main(in: FragmentInput) -> @location(0) vec4f
{
    let diffuseColor = textureSample(diffuseTex, diffuseTexSampler, in.uv);
    if (diffuseColor.a < 0.5f) {
        discard;
    }

    let origin = cameraUniforms.cameraPos.xyz;
    let point = in.pos;
    var irradiance = directSunIrradiance(origin, point, in.nor, diffuseColor.rgb);
    
    let depth = origin.y;
    let vector = origin - point;
    let direction = normalize(vector);
    let distance = length(vector);

    irradiance += multipleScatteringIrradiance(
        depth,
        direction,
        distance
    );

    return vec4(irradiance.xyz, 1);
}
