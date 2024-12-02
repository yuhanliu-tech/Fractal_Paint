// CHECKITOUT: you can use this vertex shader for all of the renderers

@group(${bindGroup_scene}) @binding(0) var<uniform> cameraUniforms: CameraUniforms;
@group(${bindGroup_model}) @binding(0) var<uniform> modelMat: mat4x4f;

struct VertexInput
{
    @location(0) pos: vec3f,
    @location(1) nor: vec3f,
    @location(2) uv: vec2f
}

struct VertexOutput
{
    @builtin(position) fragPos: vec4f,
    @location(0) pos: vec3f,
    @location(1) nor: vec3f,
    @location(2) uv: vec2f
}

@vertex
fn main(in: VertexInput) -> VertexOutput
{
    var modelPos = modelMat * vec4(in.pos, 1);
    modelPos.y -= 20.0; // temp hack to put sponza underwater
    modelPos.w /= 3.0;

    var out: VertexOutput;
    out.fragPos = cameraUniforms.viewProj * modelPos;
    out.pos = modelPos.xyz / modelPos.w;
    out.nor = in.nor;
    out.uv = in.uv;
    return out;
}
