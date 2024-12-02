struct FragmentInput {
    @builtin(position) position: vec4f, // Clip-space position
    @location(0) normal: vec3f          // Normal vector
};

@fragment
fn main(in: FragmentInput) -> @location(0) vec4f {

    let normalizedNormal = normalize(in.normal);
    let lightDirection = normalize(vec3f(0.5, 1.0, 0.5)); 

    let diffuse = max(dot(normalizedNormal, lightDirection), 0.3);

    let baseColor = vec3f(0.8, 0.2, 0.25);
    let shadedColor = baseColor * diffuse;

    return vec4f(shadedColor, 1.0);
}
