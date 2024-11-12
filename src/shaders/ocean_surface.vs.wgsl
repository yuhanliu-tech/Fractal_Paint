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
}

@vertex
fn main(in: VertexInput) -> VertexOutput
{
    let modelPos = vec4(in.pos.x, 0, in.pos.y, 1);

    var out: VertexOutput;
    out.fragPos = cameraUniforms.viewProj * modelPos;
    out.pos = modelPos.xyz / modelPos.w;
    return out;
}