@group(1) @binding(0) var displacementMap: texture_2d<f32>;
@group(${bindGroup_scene}) @binding(0) var<uniform> cameraUniforms: CameraUniforms;

// @group(${bindGroup_model}) @binding(0) var<uniform> modelMat: mat4x4f;

struct VertexInput
{
    @location(0) pos: vec2f,
}

struct VertexOutput
{
    @builtin(position) fragPos: vec4f,
    @location(0) pos: vec3f,
    @location(1) texCoord: vec2f,
}

@vertex
fn main(in: VertexInput) -> VertexOutput
{
    let displacement = textureLoad(displacementMap, vec2<i32>(in.pos), 0).x;

    var out: VertexOutput;
    out.texCoord = in.pos;

    let modelPos = vec4f(
        in.pos.x - 256 + cameraUniforms.cameraPos.x,
        // 0,
        f32(displacement) * 10,
        in.pos.y - 256 + cameraUniforms.cameraPos.z,
        1
    );

    out.fragPos = cameraUniforms.viewProj * modelPos;
    out.pos = modelPos.xyz / modelPos.w;
    return out;
}