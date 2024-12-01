struct FragmentInput {
    @builtin(position) position: vec4f, // Clip-space position
    @location(0) normal: vec3f          // Normal vector
}

@fragment
fn main(in: FragmentInput) -> @location(0) vec4f
{
    // Normalize the normal vector to ensure its range is -1 to 1
    let normalizedNormal = normalize(in.normal);

    // Map the position to a [0, 1] range for coloring
    let positionColor = in.position.xyz / vec3f(10.0, 10.0, 10.0); // Assuming the world bounds are [-10, 10]

    // Combine normal and position for color
    let color = 0.5 * (normalizedNormal + vec3f(1.0)) + 0.5 * positionColor;

    // Ensure the color values are clamped to [0, 1]
    //return vec4f(clamp(color, vec3f(0.0), vec3f(1.0)), 1.0); // Alpha = 1.0
    return vec4f(1.0, 1.0, 1.0, 1.0);
}