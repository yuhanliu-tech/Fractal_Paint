@group(${bindGroup_scene}) @binding(0) var<uniform> cameraUniforms: CameraUniforms;

@group(${bindGroup_material}) @binding(0) var diffuseTex: texture_2d<f32>;
@group(${bindGroup_material}) @binding(1) var diffuseTexSampler: sampler;

struct FragmentInput
{
    @location(0) pos: vec3f,
    @location(1) nor: vec3f,
    @location(2) uv: vec2f
}

// Jerlov water index properties for a particular water type
struct WaterProperties {
    sigma_s: f32, // scattering
    sigma_t: f32, // extinction
    k_d: f32 // downwelling attenunation coefficient
}

// TODO: Make this a uniform buffer instead of a global?
// Could simulate different types of water
const g_waterProperties = array<WaterProperties, ${numWavelengths}>(
    WaterProperties(0.144,0.189,0.051),
    WaterProperties(0.141,0.184,0.045),
    WaterProperties(0.138,0.180,0.040),
    WaterProperties(0.135,0.176,0.037),
    WaterProperties(0.133,0.171,0.034),
    WaterProperties(0.130,0.167,0.034),
    WaterProperties(0.129,0.167,0.040),
    WaterProperties(0.127,0.173,0.047),
    WaterProperties(0.124,0.176,0.055),
    WaterProperties(0.123,0.182,0.066),
    WaterProperties(0.121,0.193,0.080),
    WaterProperties(0.120,0.208,0.098),
    WaterProperties(0.119,0.257,0.184),
    WaterProperties(0.117,0.369,0.260),
    WaterProperties(0.116,0.402,0.304),
    WaterProperties(0.115,0.425,0.343),
    WaterProperties(0.114,0.461,0.381),
    WaterProperties(0.113,0.525,0.419),
    WaterProperties(0.112,0.565,0.488),
    WaterProperties(0.111,0.684,0.580)
);

const JERLOV_WAVELENGTH_SPAN = vec2f(400.0, 700.0);

const NUM_CIE_SAMPLES = 89;
const CIE_WAVELENGTH_SPAN = vec2(380.0, 830.0);
const CIE_SENSITIVITY = array<vec3f, NUM_CIE_SAMPLES>(
    vec3(3.769647E-03,4.146161E-04,1.847260E-02),
    vec3(9.382967E-03,1.059646E-03,4.609784E-02),
    vec3(2.214302E-02,2.452194E-03,1.096090E-01),
    vec3(4.742986E-02,4.971717E-03,2.369246E-01),
    vec3(8.953803E-02,9.079860E-03,4.508369E-01),
    vec3(1.446214E-01,1.429377E-02,7.378822E-01),
    vec3(2.035729E-01,2.027369E-02,1.051821E+00),
    vec3(2.488523E-01,2.612106E-02,1.305008E+00),
    vec3(2.918246E-01,3.319038E-02,1.552826E+00),
    vec3(3.227087E-01,4.157940E-02,1.748280E+00),
    vec3(3.482554E-01,5.033657E-02,1.917479E+00),
    vec3(3.418483E-01,5.743393E-02,1.918437E+00),
    vec3(3.224637E-01,6.472352E-02,1.848545E+00),
    vec3(2.826646E-01,7.238339E-02,1.664439E+00),
    vec3(2.485254E-01,8.514816E-02,1.522157E+00),
    vec3(2.219781E-01,1.060145E-01,1.428440E+00),
    vec3(1.806905E-01,1.298957E-01,1.250610E+00),
    vec3(1.291920E-01,1.535066E-01,9.991789E-01),
    vec3(8.182895E-02,1.788048E-01,7.552379E-01),
    vec3(4.600865E-02,2.064828E-01,5.617313E-01),
    vec3(2.083981E-02,2.379160E-01,4.099313E-01),
    vec3(7.097731E-03,2.850680E-01,3.105939E-01),
    vec3(2.461588E-03,3.483536E-01,2.376753E-01),
    vec3(3.649178E-03,4.277595E-01,1.720018E-01),
    vec3(1.556989E-02,5.204972E-01,1.176796E-01),
    vec3(4.315171E-02,6.206256E-01,8.283548E-02),
    vec3(7.962917E-02,7.180890E-01,5.650407E-02),
    vec3(1.268468E-01,7.946448E-01,3.751912E-02),
    vec3(1.818026E-01,8.575799E-01,2.438164E-02),
    vec3(2.405015E-01,9.071347E-01,1.566174E-02),
    vec3(3.098117E-01,9.544675E-01,9.846470E-03),
    vec3(3.804244E-01,9.814106E-01,6.131421E-03),
    vec3(4.494206E-01,9.890228E-01,3.790291E-03),
    vec3(5.280233E-01,9.994608E-01,2.327186E-03),
    vec3(6.133784E-01,9.967737E-01,1.432128E-03),
    vec3(7.016774E-01,9.902549E-01,8.822531E-04),
    vec3(7.967750E-01,9.732611E-01,5.452416E-04),
    vec3(8.853376E-01,9.424569E-01,3.386739E-04),
    vec3(9.638388E-01,8.963613E-01,2.117772E-04),
    vec3(1.051011E+00,8.587203E-01,1.335031E-04),
    vec3(1.109767E+00,8.115868E-01,8.494468E-05),
    vec3(1.143620E+00,7.544785E-01,5.460706E-05),
    vec3(1.151033E+00,6.918553E-01,3.549661E-05),
    vec3(1.134757E+00,6.270066E-01,2.334738E-05),
    vec3(1.083928E+00,5.583746E-01,1.554631E-05),
    vec3(1.007344E+00,4.895950E-01,1.048387E-05),
    vec3(9.142877E-01,4.229897E-01,0.000000E+00),
    vec3(8.135565E-01,3.609245E-01,0.000000E+00),
    vec3(6.924717E-01,2.980865E-01,0.000000E+00),
    vec3(5.755410E-01,2.416902E-01,0.000000E+00),
    vec3(4.731224E-01,1.943124E-01,0.000000E+00),
    vec3(3.844986E-01,1.547397E-01,0.000000E+00),
    vec3(2.997374E-01,1.193120E-01,0.000000E+00),
    vec3(2.277792E-01,8.979594E-02,0.000000E+00),
    vec3(1.707914E-01,6.671045E-02,0.000000E+00),
    vec3(1.263808E-01,4.899699E-02,0.000000E+00),
    vec3(9.224597E-02,3.559982E-02,0.000000E+00),
    vec3(6.639960E-02,2.554223E-02,0.000000E+00),
    vec3(4.710606E-02,1.807939E-02,0.000000E+00),
    vec3(3.292138E-02,1.261573E-02,0.000000E+00),
    vec3(2.262306E-02,8.661284E-03,0.000000E+00),
    vec3(1.575417E-02,6.027677E-03,0.000000E+00),
    vec3(1.096778E-02,4.195941E-03,0.000000E+00),
    vec3(7.608750E-03,2.910864E-03,0.000000E+00),
    vec3(5.214608E-03,1.995557E-03,0.000000E+00),
    vec3(3.569452E-03,1.367022E-03,0.000000E+00),
    vec3(2.464821E-03,9.447269E-04,0.000000E+00),
    vec3(1.703876E-03,6.537050E-04,0.000000E+00),
    vec3(1.186238E-03,4.555970E-04,0.000000E+00),
    vec3(8.269535E-04,3.179738E-04,0.000000E+00),
    vec3(5.758303E-04,2.217445E-04,0.000000E+00),
    vec3(4.058303E-04,1.565566E-04,0.000000E+00),
    vec3(2.856577E-04,1.103928E-04,0.000000E+00),
    vec3(2.021853E-04,7.827442E-05,0.000000E+00),
    vec3(1.438270E-04,5.578862E-05,0.000000E+00),
    vec3(1.024685E-04,3.981884E-05,0.000000E+00),
    vec3(7.347551E-05,2.860175E-05,0.000000E+00),
    vec3(5.259870E-05,2.051259E-05,0.000000E+00),
    vec3(3.806114E-05,1.487243E-05,0.000000E+00),
    vec3(2.758222E-05,1.080001E-05,0.000000E+00),
    vec3(2.004122E-05,7.863920E-06,0.000000E+00),
    vec3(1.458792E-05,5.736935E-06,0.000000E+00),
    vec3(1.068141E-05,4.211597E-06,0.000000E+00),
    vec3(7.857521E-06,3.106561E-06,0.000000E+00),
    vec3(5.768284E-06,2.286786E-06,0.000000E+00),
    vec3(4.259166E-06,1.693147E-06,0.000000E+00),
    vec3(3.167765E-06,1.262556E-06,0.000000E+00),
    vec3(2.358723E-06,9.422514E-07,0.000000E+00),
    vec3(1.762465E-06,7.053860E-07,0.000000E+00)
);

const SUN_STRENGTH = 40.0;

fn getWaterProperties(t: f32) -> WaterProperties {
    let indexRational = t * ${numWavelengths};
    let props1 = g_waterProperties[u32(floor(indexRational))];
    let props2 = g_waterProperties[u32(ceil(indexRational))];
    let mixFactor = fract(indexRational);
    return WaterProperties(
        mix(props1.sigma_s, props2.sigma_s, mixFactor),
        mix(props1.sigma_t, props2.sigma_t, mixFactor),
        mix(props1.k_d, props2.k_d, mixFactor)
    );
}

fn wavelengthToRGB(wavelength: f32) -> vec3f {
    let t = (wavelength - CIE_WAVELENGTH_SPAN.x) / (CIE_WAVELENGTH_SPAN.y - CIE_WAVELENGTH_SPAN.x) * f32(NUM_CIE_SAMPLES);
    let rgb1 = CIE_SENSITIVITY[u32(floor(t))];
    let rgb2 = CIE_SENSITIVITY[u32(ceil(t))];
    let mixFactor = fract(t);
    return mix(rgb1, rgb2, mixFactor);
}

fn multipleScatteringIrradiance(
    numSamples: u32,
    irradianceIn: f32,
    rayOrigin: vec3f,
    rayDirection: vec3f,
    distance: f32
) -> vec3f {
    let depth = -rayOrigin.y;
    let y_w = -rayDirection.y;

    var rgbIrradianceOut = vec3f(0);
    for (var sample = 0u; sample < numSamples; sample++) {
        let t = (f32(sample) + 0.5f) / f32(numSamples);
        let wavelength = mix(400.0, 700.0, t);
        let props = getWaterProperties(t);

        let c = props.k_d * y_w - props.sigma_t;

        // TODO: Floor reflectance?        
        let irradianceOut =
            (props.sigma_s * irradianceIn) / (4 * PI * c)
            * (exp(distance * c) - 1)
            * exp(props.k_d * depth);

        rgbIrradianceOut += irradianceOut * wavelengthToRGB(wavelength);
    }
    rgbIrradianceOut /= f32(numSamples);
    return rgbIrradianceOut;
}

@fragment
fn main(in: FragmentInput) -> @location(0) vec4f
{
    let diffuseColor = textureSample(diffuseTex, diffuseTexSampler, in.uv);
    if (diffuseColor.a < 0.5f) {
        discard;
    }

    let rayOrigin = cameraUniforms.cameraPos.xyz;
    let rayVector = rayOrigin - in.pos;

    let lightPower = multipleScatteringIrradiance(
        16,
        SUN_STRENGTH,
        rayOrigin,
        normalize(rayVector),
        length(rayVector)
    );

    let finalColor = diffuseColor.rgb * lightPower;
    return vec4(finalColor, 1);
}
