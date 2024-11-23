@group(1) @binding(1) var normalMap: texture_2d<f32>;
@group(1) @binding(2) var texSampler: sampler;
@group(${bindGroup_scene}) @binding(0) var<uniform> cameraUniforms: CameraUniforms;

struct FragmentInput
{
    @builtin(position) fragPos: vec4f,
    @location(0) pos: vec3f,
    @location(1) texCoord: vec2f,
    @location(2) worldPosition: vec2f,
}

struct GBufferOutput {
    @location(0) albedo : vec4f,
    @location(1) distance : vec4f
}

fn getSunDirection() -> vec3<f32> {
  return normalize(vec3(-0.2 , 0.6 + sin(20) * 0.15 , 1.0));
}

fn getSun(dir: vec3<f32>) -> f32 { 
  return pow(max(0.0, dot(dir, getSunDirection())), 70.0) * 60.0;
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


// Adjust this value to control how far the fog extends
const fogDistance: f32 = 550.0;
const fogColor: vec3f = vec3<f32>(0.0, 0.0, 0.0); // background (and thus fog) is currently black

@fragment
fn main(in: FragmentInput) -> GBufferOutput
{
    // not cursed texture sampling for ocean color :)
    let uv = vec2f(in.texCoord) / 1024;
    let normal = textureSample(normalMap, texSampler, uv);
    let oceanColor = vec3<f32>(0, normal.x * 0.25, normal.z * 0.70); // ocean albedo with calculated normals from compute shader

    // ocean color with lighting considerations

    var ray = getRay(in.fragPos.xy);

    let fresnel = (0.04 + (1.0)*(pow(1.0 - max(0.0, dot(-normal.xyz, ray)), 50.0)));
    
    var R = normalize(reflect(ray, normal.xyz));
    R.y = abs(R.y);

    let depth = 0.1;
    let reflection = getSun(R); 
    let scattering = vec3(0.0293, 0.0698, 0.1717) * 0.05 * (0.2 + (in.pos.y + depth) / depth);

    // distance from the camera to the fragment
    let distance = length(in.pos - vec3(cameraUniforms.cameraPos.xyz));

    let fogFactor = clamp(pow(distance / fogDistance, 4.0), 0.0, 1.0);

    // with adjustments
    var C = fresnel * reflection + scattering;
    C += 0.2;

    let color = mix(oceanColor + C * 0.1, fogColor, fogFactor);

    // combine lighting results
    return GBufferOutput(vec4f(color, 1.0), normal);
}