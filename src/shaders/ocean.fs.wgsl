struct FragmentInput {
    @location(0) fragPosition: vec3<f32>;
    @location(1) fragNormal: vec3<f32>;
    @location(2) uv: vec2<f32>;
};

struct Light {
    position: vec3<f32>;
    color: vec3<f32>;
    intensity: f32;
};

@group(0) @binding(0) var<uniform> cameraPosition: vec3<f32>;
@group(0) @binding(1) var<uniform> light: Light;

const waterColor: vec3<f32> = vec3(0.0, 0.3, 0.6);
const specularColor: vec3<f32> = vec3(1.0, 1.0, 1.0);
const shininess: f32 = 32.0;

@fragment
fn main(input: FragmentInput) -> @location(0) vec4<f32> {
    let viewDir = normalize(cameraPosition - input.fragPosition);
    let lightDir = normalize(light.position - input.fragPosition);

    // Diffuse lighting
    let diffuse = max(dot(input.fragNormal, lightDir), 0.0);

    // Specular lighting (Blinn-Phong)
    let halfDir = normalize(viewDir + lightDir);
    let specular = pow(max(dot(input.fragNormal, halfDir), 0.0), shininess);

    let color = waterColor * diffuse * light.intensity + specularColor * specular * light.intensity;
    return vec4(color, 0.8);
}
