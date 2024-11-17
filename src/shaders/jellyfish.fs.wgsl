@group(0) @binding(1) var normalMap: texture_2d<f32>;
@group(0) @binding(2) var texSampler: sampler;

struct FragmentInput {
    @builtin(position) fragPos: vec4f,
    @location(0) texCoord: vec2f,
};

@fragment
fn main(in: FragmentInput) -> @location(0) vec4f {
    // Sample the normal map using the provided sampler and texture coordinates
    let color = textureSample(normalMap, texSampler, in.texCoord);
    return color;
}