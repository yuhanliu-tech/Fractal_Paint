@group(0) @binding(0) var displacementMap: texture_storage_2d<r32float, write>;
@group(0) @binding(1) var normalMap: texture_storage_2d<rgba8unorm, write>;


@compute
@workgroup_size(16, 16)
fn main(@builtin(global_invocation_id) globalIdx: vec3u) {
    if (globalIdx.x >= 512 || globalIdx.y >= 512) {
        return;
    }
    let x = f32(globalIdx.x);
    textureStore(displacementMap, globalIdx.xy, vec4(sin(x), 0, 0, 0));
    textureStore(normalMap, globalIdx.xy, vec4f(sin(x), cos(x), 0, 1));
}

