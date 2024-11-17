struct FragmentInput {
    @builtin(position) fragPos: vec4f,
    @location(0) texCoord: vec2f,
};

@fragment
fn main(in: FragmentInput) -> @location(0) vec4f {
    // Sample the normal map using the provided sampler and texture coordinates
    return vec4(1.f,0.f,0.f,1.f);
}