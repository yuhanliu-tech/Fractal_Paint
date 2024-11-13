@group(1) @binding(1) var normalMap: texture_2d<f32>;
@group(1) @binding(2) var texSampler: sampler;
@group(${bindGroup_scene}) @binding(0) var<uniform> cameraUniforms: CameraUniforms;

struct FragmentInput
{
    @location(0) pos: vec3f,
    @location(1) texCoord: vec2f,
}

@fragment
fn main(in: FragmentInput) -> @location(0) vec4f
{
    // TODO: uvs that aren't cursed
    let uv = vec2f(in.texCoord) / 512;
    let normal = textureSample(normalMap, texSampler, uv);
    return vec4f(normal.xyz, 1);
}
