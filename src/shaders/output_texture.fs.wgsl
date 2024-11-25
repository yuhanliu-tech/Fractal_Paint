@group(0) @binding(0) var tex: texture_2d<f32>;

struct FragmentInput
{
    @location(0) uv: vec2f
}


@fragment
fn main(in: FragmentInput) -> @location(0) vec4f {
    let index = vec2u((in.uv + 1) * 128);
    let value = textureLoad(tex, index, 0).x;
    

    let finalColor = vec3f(value, 0, 0);
    // let finalColor = vec3f(value, 0, 0);
    return vec4f(finalColor, 1);
}