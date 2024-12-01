@group(0) @binding(0) var<uniform> cameraUniforms: CameraUniforms;
@group(0) @binding(1) var<storage, read> instancePositions: array<vec3f>;
@group(1) @binding(0) var displacementMap: texture_2d<f32>;

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
    var instancePosition = instancePositions[instanceIndex];

    // Displacement map size
    let mapSize: f32 = 1024.0;

    // Transform the box's world-space position into the displacement map's local space
    let localSampleX = ((instancePosition.x - cameraUniforms.cameraPos.x) + mapSize) % mapSize;
    let localSampleZ = ((instancePosition.z - cameraUniforms.cameraPos.z) + mapSize) % mapSize;

    let displacement = textureLoad(displacementMap, vec2<i32>(i32(localSampleX), i32(localSampleZ)), 0).x;

    instancePosition.x = instancePosition.x - 512;
    instancePosition.y = f32(displacement) * 10 - 60;
    instancePosition.z = instancePosition.z - 512;

    // Compute the world position of the vertex
    let worldPosition = input.position + instancePosition;

    // Project to clip space
    output.position = cameraUniforms.viewProj * vec4f(worldPosition, 1.0);
    output.normal = input.normal;

    return output;
}
