@group(0) @binding(0) var<uniform> cameraUniforms: CameraUniforms;
@group(0) @binding(1) var<storage, read> instancePositions: array<vec3f>;

struct VertexInput {
    @location(0) position: vec3f,
    @location(1) normal: vec3f,
    @location(2) uv: vec2f
}

struct VertexOutput {
    @builtin(position) position: vec4f, // Clip-space position
    @location(0) normal: vec3f          // Normal vector
}

@vertex
fn main(input: VertexInput, @builtin(instance_index) instanceIndex: u32) -> VertexOutput {
    var output: VertexOutput;
    
    // Fetch the instance position from the storage buffer
    let instancePosition = instancePositions[instanceIndex];

    // Compute the world position of the vertex
    let worldPosition = input.position; //+ instancePosition;

    // Project to clip space
    output.position = cameraUniforms.viewProj * vec4f(worldPosition, 1.0);
    output.normal = input.normal;

    return output;
}
