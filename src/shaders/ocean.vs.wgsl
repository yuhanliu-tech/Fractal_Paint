struct VertexInput {
    @location(0) position: vec3<f32>;
    @location(1) normal: vec3<f32>;
    @location(2) uv: vec2<f32>;
};

struct VertexOutput {
    @builtin(position) position: vec4<f32>;
    @location(0) fragPosition: vec3<f32>;
    @location(1) fragNormal: vec3<f32>;
    @location(2) uv: vec2<f32>;
};

@group(0) @binding(0) var<uniform> cameraViewProj: mat4x4<f32>;
@group(1) @binding(0) var displacementTexture: texture_2d<f32>;
@group(1) @binding(1) var normalTexture: texture_2d<f32>;
@group(1) @binding(2) var samplerObj: sampler;

@vertex
fn main(input: VertexInput) -> VertexOutput {
    var output: VertexOutput;

    // Sample displacement from the texture
    let displacement = textureSample(displacementTexture, samplerObj, input.uv).r;
    let displacedPosition = input.position + input.normal * displacement;

    // Sample normals from the texture
    let normalSample = textureSample(normalTexture, samplerObj, input.uv).rgb;
    let finalNormal = normalize(normalSample * 2.0 - 1.0);

    // Transform the position to clip space
    output.position = cameraViewProj * vec4(displacedPosition, 1.0);
    output.fragPosition = displacedPosition;
    output.fragNormal = finalNormal;
    output.uv = input.uv;

    return output;
}
