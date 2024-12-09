@group(1) @binding(1) var normalMap: texture_2d<f32>;
@group(1) @binding(2) var texSampler: sampler;

struct FragmentInput
{
    @builtin(position) fragPos: vec4f,
    @location(0) pos: vec3f,
    @location(1) texCoord: vec2f,
    @location(2) worldPosition: vec2f,
}

// Helper function generating a rotation matrix around the axis by the angle
fn createRotationMatrixAxisAngle(axis: vec3<f32>, angle: f32) -> mat3x3<f32> {
  let s = sin(angle);
  let c = cos(angle);
  let oc = 1.0 - c;
  return mat3x3(
    oc * axis.x * axis.x + c, oc * axis.x * axis.y - axis.z * s, oc * axis.z * axis.x + axis.y * s, 
    oc * axis.x * axis.y + axis.z * s, oc * axis.y * axis.y + c, oc * axis.y * axis.z - axis.x * s, 
    oc * axis.z * axis.x - axis.y * s, oc * axis.y * axis.z + axis.x * s, oc * axis.z * axis.z + c
  );
}

fn getRay(coord: vec2<f32>) -> vec3<f32> {
  
  let proj = normalize(vec3(coord.x, coord.y, 0.0));

  return createRotationMatrixAxisAngle(vec3(0.0, -1.0, 0.0), 3.0) 
    * createRotationMatrixAxisAngle(vec3(1.0, 0.0, 0.0), 0.5 + 1.5 * 2.0 - 1.0)
    * proj;
}

fn hash(p: vec2<f32>) -> f32 {
    // Simple hash function to generate pseudo-random noise
    let k = vec2<f32>(127.1, 311.7);
    return fract(sin(dot(p, k)) * 43758.5453123);
}

// Adjust this value to control how far the fog extends
const fogDistance: f32 = 550.0;
const fogColor: vec3f = vec3<f32>(0.0, 0.0, 0.0); // background (and thus fog) is currently black

@fragment
fn main(in: FragmentInput) -> @location(0) vec4f
{
    // not cursed texture sampling for ocean color :)
    let uv = vec2f(in.texCoord) / 1024;
    let normal = textureSample(normalMap, texSampler, uv);

    var sandColor = vec3<f32>(0.65, 0.65, 0.6);
    let stipple = hash(uv);           // Generate noise
    sandColor *= 0.9 + 0.1 * stipple; // Blend noise with sand color

    let lightDir = normalize(vec3<f32>(0.5, 1.0, 0.5)); // Adjust as needed
    let shading = max(dot(normal.xyz, lightDir), 0.0);
    sandColor *= mix(sandColor, vec3(1.f,1.f,1.f), pow(shading, 2));

    let color = totalIrradiance(
        cameraUniforms.cameraPos.xyz,
        in.pos,
        normal.xyz,
        sandColor,
        false
    );

    // ocean color with lighting considerations

    // var ray = getRay(in.fragPos.xy);

    // let fresnel = (0.04 + (1.0)*(pow(1.0 - max(0.0, dot(-normal.xyz, ray)), 50.0)));
    
    // var R = normalize(reflect(ray, normal.xyz));
    // R.y = abs(R.y);

    // let depth = 0.1;
    // let reflection = getSun(R); 
    // let scattering = vec3(0.0293, 0.0698, 0.1717) * 0.05 * (0.2 + (in.pos.y + depth) / depth);

    // // distance from the camera to the fragment
    // let distance = length(in.pos - vec3(cameraUniforms.cameraPos.xyz));

    // let fogFactor = clamp(pow(distance / fogDistance, 4.0), 0.0, 1.0);

    // // with adjustments
    // var C = fresnel * reflection + scattering;
    // C += 0.2;

    // let color = mix(oceanColor + C * 0.18, fogColor, fogFactor);


    return vec4f(color, 1.0);
}