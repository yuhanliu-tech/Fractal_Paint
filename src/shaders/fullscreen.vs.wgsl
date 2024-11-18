struct VertexOutput {
    @builtin(position) fragPos: vec4f,
    @location(0) texCoord: vec2f,
}

@vertex
fn main(@builtin(vertex_index) vertexIndex: u32) -> VertexOutput {

    
    // Define positions for a full-screen quad
    var positions = array<vec2f, 6>(
        vec2f(-1.0, -1.0), // Bottom-left
        vec2f(-1.0,  1.0), // Top-left
        vec2f( 1.0, -1.0), // Bottom-right
        vec2f(-1.0,  1.0), // Top-left
        vec2f( 1.0,  1.0), // Top-right
        vec2f( 1.0, -1.0)  // Bottom-right
    );

    // Calculate texture coordinates (0 to 1)
    var texCoords = array<vec2f, 6>(
        vec2f(0.0, 0.0), // Bottom-left
        vec2f(0.0, 1.0), // Top-left
        vec2f(1.0, 0.0), // Bottom-right
        vec2f(0.0, 1.0), // Top-left
        vec2f(1.0, 1.0), // Top-right
        vec2f(1.0, 0.0)  // Bottom-right
    );

    var out: VertexOutput;
    out.fragPos = vec4f(positions[vertexIndex], 0.0, 1.0); // Full-screen quad positions
    out.texCoord = texCoords[vertexIndex]; // Corresponding texture coordinates
    return out;


}