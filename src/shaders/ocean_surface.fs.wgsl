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
    let uv = vec2f(in.texCoord) / 1024;
    let normal = textureSample(normalMap, texSampler, uv);
    // let nor = vec3<f32>(normal.x, normal.y, normal.z);

    // let viewDir = normalize(vec3<f32>(cameraUniforms.cameraPos.x, cameraUniforms.cameraPos.y, cameraUniforms.cameraPos.z) - in.pos);
    // let lightDir = normalize(vec3<f32>(0,10,0) - in.pos);

    // // Calculate diffuse lighting
    // let diffuse = max(dot(nor, lightDir), 0.0);

    // // Calculate specular lighting
    // let halfDir = normalize(viewDir + lightDir);
    // let specular = pow(max(dot(nor, halfDir), 0.0), 32);

    // let color = vec3<f32>(1, 0, 0) * diffuse * 10 + specularColor * specular * 10;
    // return vec4(color, 0.8);
    let color =  vec3<f32>(0, normal.x * 0.45, normal.z * 0.65);
    return vec4f(color, 1);
}
