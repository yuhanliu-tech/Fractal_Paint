@group(0) @binding(0) var<uniform> cameraUniforms: CameraUniforms;
@group(0) @binding(1) var<storage, read> coralSet: CoralSet;
@group(1) @binding(0) var displacementMap: texture_2d<f32>;

struct VertexInput {
    @location(0) position: vec3f,
    @location(1) normal: vec3f,
    @location(2) uv: vec2f
}

struct VertexOutput {
    @builtin(position) position: vec4f, // Clip-space position
    @location(0) normal: vec3f,          // Normal vector
    @location(1) color: vec3f        // Color  
}

// Helper function to create a rotation matrix from Euler angles
fn rotationMatrix(rotation: vec3f) -> mat3x3f {
    let sinX = sin(rotation.x);
    let cosX = cos(rotation.x);
    let sinY = sin(rotation.y);
    let cosY = cos(rotation.y);
    let sinZ = sin(rotation.z);
    let cosZ = cos(rotation.z);

    let rotX = mat3x3f(
        vec3f(1.0, 0.0, 0.0),
        vec3f(0.0, cosX, -sinX),
        vec3f(0.0, sinX, cosX)
    );
    let rotY = mat3x3f(
        vec3f(cosY, 0.0, sinY),
        vec3f(0.0, 1.0, 0.0),
        vec3f(-sinY, 0.0, cosY)
    );
    let rotZ = mat3x3f(
        vec3f(cosZ, -sinZ, 0.0),
        vec3f(sinZ, cosZ, 0.0),
        vec3f(0.0, 0.0, 1.0)
    );

    return rotZ * rotY * rotX; // ZYX order
}

@vertex
fn main(input: VertexInput, @builtin(instance_index) instanceIndex: u32) -> VertexOutput {
    var output: VertexOutput;
    
    // Fetch the instance position from the storage buffer
    var instancePosition = coralSet.coral[instanceIndex].pos;
    var instanceRotation = coralSet.coral[instanceIndex].rotation;
    var instanceScale = coralSet.coral[instanceIndex].scale;
    var instanceColor = coralSet.coral[instanceIndex].color;

    // Displacement map size
    let mapSize: f32 = 1024.0;

    // Transform the box's world-space position into the displacement map's local space
    let localSampleX = ((instancePosition.x - cameraUniforms.cameraPos.x) + mapSize) % mapSize;
    let localSampleZ = ((instancePosition.z - cameraUniforms.cameraPos.z) + mapSize) % mapSize;

    let displacement = textureLoad(displacementMap, vec2<i32>(i32(localSampleX), i32(localSampleZ)), 0).x;

    instancePosition.x = instancePosition.x - 512;
    instancePosition.y = f32(displacement) * 10 - 110;
    instancePosition.z = instancePosition.z - 512;

    let scaledPosition = input.position * instanceScale;
    let rotationMat = rotationMatrix(instanceRotation);
    let rotatedPosition = rotationMat * scaledPosition;

    // Compute the world position of the vertex
    let worldPosition = rotatedPosition + instancePosition;

    // Project to clip space
    output.position = cameraUniforms.viewProj * vec4f(worldPosition, 1.0);
    output.position.y += 6;

    output.normal = input.normal;
    output.color = instanceColor;

    return output;
}
