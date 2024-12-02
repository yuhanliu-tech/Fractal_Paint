// CHECKITOUT: code that you add here will be prepended to all shaders

struct Coral {
    pos: vec3f
}

struct CoralSet {
    numCoral: u32,
    coral: array<Coral>
}


// TODO-2: you may want to create a ClusterSet struct similar to LightSet

struct CameraUniforms {
    viewProj : mat4x4f,
    view: mat4x4f,
    invViewProj: mat4x4f,
    xscale: f32,
    yscale: f32,
    near: f32,
    logfarovernear: f32,
    cameraPos: vec4f,
    cameraLookPos: vec4f
}

// CHECKITOUT: this special attenuation function ensures lights don't affect geometry outside the maximum light radius
fn rangeAttenuation(distance: f32) -> f32 {
    return clamp(1.f - pow(distance / ${lightRadius}, 4.f), 0.f, 1.f) / (distance * distance);
}

fn clusterIdx1d(x: u32, y: u32, z: u32) -> u32 {
    return x + y * ${clusterX} + z * ${clusterX} * ${clusterY};
}

fn zViewToSlice(zView: f32, camera: ptr<uniform, CameraUniforms>) -> u32{
    return u32(log(-zView / camera.near) / camera.logfarovernear * ${clusterZ});
}