import { vec2, vec3 } from "wgpu-matrix"
import * as shaders from '../shaders/shaders';
import * as renderer from '../renderer';

const ocean_surface_texture_dims = [512, 512];

export class OceanSurfaceChunk {
    // Textures
    displacementTexture: GPUTexture;
    normalTexture: GPUTexture;
    
    worldPosition: Float32Array;

    computeBindGroup: GPUBindGroup;
    renderBindGroup: GPUBindGroup;

    constructor(
        worldPosition: Float32Array,
        computeBindGroupLayout : GPUBindGroupLayout,
        renderBindGroupLayout: GPUBindGroupLayout,
        sampler : GPUSampler
    ) {
        
        this.worldPosition = worldPosition;

        // Setting up textures and making a bind group for them
        this.displacementTexture = renderer.device.createTexture({
            size: ocean_surface_texture_dims,
            format: "r32float",
            usage: GPUTextureUsage.STORAGE_BINDING | GPUTextureUsage.TEXTURE_BINDING
        });

        this.normalTexture = renderer.device.createTexture({
            size: ocean_surface_texture_dims,
            format: "rgba8unorm",
            usage: GPUTextureUsage.STORAGE_BINDING | GPUTextureUsage.TEXTURE_BINDING
        });

        this.computeBindGroup = renderer.device.createBindGroup({
            layout: computeBindGroupLayout,
            entries: [
                { binding: 0, resource: this.displacementTexture.createView() },
                { binding: 1, resource: this.normalTexture.createView() }
            ]
        });

        this.renderBindGroup = renderer.device.createBindGroup({
            layout: renderBindGroupLayout,
            entries: [
                { binding: 0, resource: this.displacementTexture.createView() },
                { binding: 1, resource: this.normalTexture.createView() },
                { binding: 2, resource: sampler },
            ]
        });
    }
}