@group(1) @binding(1) var normalMap: texture_2d<f32>;
@group(1) @binding(2) var texSampler: sampler;
@group(${bindGroup_scene}) @binding(0) var<uniform> cameraUniforms: CameraUniforms;

struct FragmentInput
{
    @location(0) pos: vec3f,
    @location(1) texCoord: vec2f,
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
    let oceanColor = vec3<f32>(0, normal.x * 0.65, normal.z * 0.85);

    // distance from the camera to the fragment
    let distance = length(in.pos - vec3(cameraUniforms.cameraPos.xyz));

    let fogFactor = clamp(pow(distance / fogDistance, 4.0), 0.0, 1.0);

    let color = mix(oceanColor, fogColor, fogFactor);

    return vec4f(color, 1.0);
}