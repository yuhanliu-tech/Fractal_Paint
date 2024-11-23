@vertex
fn main(@builtin(vertex_index) idx : u32) -> @builtin(position) vec4f
{
    const pos = array(
        vec2f(-1, -1), vec2f(1, -1), vec2f(-1, 1),
        vec2f(-1, 1), vec2f(1, -1), vec2f(1, 1)
    );
    return vec4f(pos[idx], 0, 1);
}