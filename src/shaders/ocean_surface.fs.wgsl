@group(1) @binding(0) var displacementMap: texture_2d<f32>;
@group(1) @binding(1) var normalMap: texture_2d<f32>;
@group(1) @binding(2) var texSampler: sampler;

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
    // let displacement = textureLoad(displacementMap, vec2<i32>(in.texCoord), 0);
    let normal = textureSample(normalMap, texSampler, uv);
    return vec4f(normal.xyz, 1);
    // return vec4f(displacement.xy, 1, 1);
}
