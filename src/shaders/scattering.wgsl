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
@group(0) @binding(4) var<uniform> time: f32;

const lightDirection = normalize(vec3(-0.2 , 0.6 + sin(20) * 0.15 , 1.0));

fn getSun(dir: vec3<f32>) -> f32 { 
  return pow(max(0.0, dot(dir, lightDirection)), 70.0) * 60.0;
}

fn aces_tonemap(color: vec3<f32>) -> vec3<f32> {  
  let m1 = mat3x3(
    0.59719, 0.07600, 0.02840,
    0.35458, 0.90834, 0.13383,
    0.04823, 0.01566, 0.83777
  );
  let m2 = mat3x3(
    1.60475, -0.10208, -0.00327,
    -0.53108,  1.10813, -0.07276,
    -0.07367, -0.00605,  1.07602
  );
  let v = m1 * color;  
  let a = v * (v + 0.0245786) - 0.000090537;
  let b = v * (0.983729 * v + 0.4329510) + 0.238081;

  var result = m2 * (a / b);
  result.x = pow(min(max(result.x, 0.f), 1.f), 1.0/2.2);
  result.y = pow(min(max(result.y, 0.f), 1.f), 1.0/2.2);
  result.z = pow(min(max(result.z, 0.f), 1.f), 1.0/2.2);

  return result;  
}

const SUN_STRENGTH = 4.0;
const DIST_SCALE = 0.03;

const CAMERA_POINT_LIGHT_STRENGTH = 0.2;

fn totalIrradiance(
    origin: vec3f,
    pos: vec3f,
    nor: vec3f,
    albedo: vec3f
) -> vec3f {
    // return albedo;
    var depth = origin.y;
    let vector = origin - pos;
    let direction = normalize(vector);
    var distance = length(vector);

    let surface_point = pos + lightDirection * depth / lightDirection.y;

    let intensity = tiledCaustic(surface_point.xz * 0.005, time);
    return vec3(intensity);
    depth *= DIST_SCALE;
    distance *= DIST_SCALE;

    var irradiance = vec3(0.f);

    irradiance += directSunIrradiance(depth, distance, nor, albedo);
    irradiance += cameraPointLightIrradiance(depth, distance, direction, nor, albedo);

    irradiance += multipleScatteringIrradiance(
        depth,
        direction,
        distance
    );

    return aces_tonemap(irradiance);
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

fn cameraPointLightIrradiance(
    depth: f32,
    distance: f32,
    direction: vec3f,
    nor: vec3f,
    albedo: vec3f
) -> vec3f {
    // TODO: maybe do something a bit more physically motivated?
    // Maybe just a lambert term with a static sun direction?
    // let diffuse = sqrt(clamp(0.5 + 0.5 * nor.y, 0, 1));
    let diffuse = max(dot(nor, lightDirection), 0.3);
    return CAMERA_POINT_LIGHT_STRENGTH * diffuse * albedo / distance / distance;
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

fn tiledCaustic(point : vec2f, time: f32) -> f32 {
    const MAX_ITER = 10;
    const TAU = 6.28318530718;

    var p = (point * TAU) % TAU - 250.0;
    var i = p;
    var c = 1.0;
    var inten = 0.005;

    for (var n = 0u; n < MAX_ITER; n++) {
        let t = time * (1.0 - (3.5 / f32(n + 1)));
        i = p + vec2f(cos(t - i.x) + sin(t + i.y), sin(t - i.y) + cos(t + i.x));
        c += 1.0 / length(vec2f(p.x / (sin(i.x + t) / inten), p.y / (cos(i.y + t) / inten)));
    }
    c /= f32(MAX_ITER);
    c = 1.17 - pow(c, 1.4);
    return (pow(abs(c), 8.0));
}