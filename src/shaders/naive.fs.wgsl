@group(2) @binding(0) var diffuseTex: texture_2d<f32>;
@group(2) @binding(1) var diffuseTexSampler: sampler;

struct FragmentInput
{
    @location(0) pos: vec3f,
    @location(1) nor: vec3f,
    @location(2) uv: vec2f
}



@fragment
fn main(in: FragmentInput) -> @location(0) vec4f
{
    let diffuseColor = textureSample(diffuseTex, diffuseTexSampler, in.uv);
    if (diffuseColor.a < 0.5f) {
        discard;
    }

    let nor = normalize(in.nor);

    let irradiance = totalIrradiance(
        cameraUniforms.cameraPos.xyz,
        in.pos,
        nor,
        diffuseColor.rgb,
        false
    );

    return vec4(irradiance.xyz, 1);
}

