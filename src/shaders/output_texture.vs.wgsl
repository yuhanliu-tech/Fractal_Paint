struct VertexOutput
{
    @builtin(position) fragPos: vec4f,
    @location(0) uv: vec2f
}

@vertex
fn main(@builtin(vertex_index) idx : u32) -> VertexOutput
{
    const pos = array(
        vec2f(-1, -1), vec2f(1, -1), vec2f(-1, 1),
        vec2f(-1, 1), vec2f(1, -1), vec2f(1, 1)
    );
    var output : VertexOutput;
    output.fragPos = vec4f(pos[idx], 0, 1);
    output.uv = pos[idx];
    return output;
}