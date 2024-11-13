import { vec2, vec3 } from "wgpu-matrix"
import * as shaders from '../shaders/shaders';
import * as renderer from '../renderer';

const ocean_surface_texture_dims = [32, 32];

export class OceanSurfaceChunk {
    // Textures
    displacementTexture: GPUTexture;
    normalTexture: GPUTexture;

    positionBuffer: GPUBuffer;
   
    computeBindGroup: GPUBindGroup;
    renderBindGroup: GPUBindGroup;

    constructor(
        computeBindGroupLayout : GPUBindGroupLayout,
        renderBindGroupLayout: GPUBindGroupLayout,
        sampler : GPUSampler
    ) {

        // Buffer to hold the positions
        this.positionBuffer = renderer.device.createBuffer({
            label: "chunk position",
            size: 2 * 4,
            usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST
        });

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
                { binding: 0, resource: {buffer: this.positionBuffer}},
                { binding: 1, resource: this.displacementTexture.createView() },
                { binding: 2, resource: this.normalTexture.createView() }
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

    public updatePosition(x: number, y: number) {
        renderer.device.queue.writeBuffer(this.positionBuffer, 0, new Float32Array([x, y]))
    }
}