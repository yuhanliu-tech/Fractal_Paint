struct FragmentInput {
    @builtin(position) position: vec4f, // Clip-space position
    @location(0) pos: vec3f,          // Position vector
    @location(1) normal: vec3f,          // Normal vector
    @location(2) color: vec3f        // Color
};

@fragment
fn main(in: FragmentInput) -> @location(0) vec4f
{
    let diffuseColor = in.color;
    let nor = normalize(in.normal);

    let origin = cameraUniforms.cameraPos.xyz;
    let point = in.pos;
    
    let irradiance = totalIrradiance(
        origin,
        point,
        nor,
        diffuseColor,
        false
    );

    return vec4(irradiance.xyz, 1);
}
