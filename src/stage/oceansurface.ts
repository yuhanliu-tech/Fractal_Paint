import { vec3 } from "wgpu-matrix"
import * as shaders from '../shaders/shaders';
import * as renderer from '../renderer';
import { OceanSurfaceChunk } from "./oceansurfacechunk";

const quad_res = [1024, 1024];

export const vertexBufferLayout: GPUVertexBufferLayout = {
    arrayStride: 8,
    attributes: [
        { // pos
            format: "float32x2",
            offset: 0,
            shaderLocation: 0
        },
    ]
};

export class OceanSurface {
    // Bind group layouts containing the textures
    computeBindGroupLayout: GPUBindGroupLayout;
    renderBindGroupLayout: GPUBindGroupLayout;
    // Sampler to read from textures
    sampler: GPUSampler;

    // Compute pipeline stuff
    computePipeline: GPUComputePipeline;

    // Buffers for the actual quad
    vertexBuffer: GPUBuffer;
    indexBuffer: GPUBuffer;
    numIndices: number;

    constructor() {
        this.computeBindGroupLayout = renderer.device.createBindGroupLayout({
            label: "ocean surface compute layout",
            entries: [
                {   // world position
                    binding: 0,
                    visibility: GPUShaderStage.COMPUTE,
                    buffer: { type: "uniform" }
                },
                {   // displacement
                    binding: 1,
                    visibility: GPUShaderStage.COMPUTE,
                    storageTexture: {
                        access: "write-only",
                        format: "r32float"
                    }
                },
                {   // normal
                    binding: 2,
                    visibility: GPUShaderStage.COMPUTE,
                    storageTexture: {
                        access: "write-only",
                        format: "rgba8unorm"
                    }
                },
                {   // time
                    binding: 3,
                    visibility: GPUShaderStage.COMPUTE,
                    buffer: { type: "uniform" }
                },
            ]
        });

        this.renderBindGroupLayout = renderer.device.createBindGroupLayout({
            label: "ocean surface render layout",
            entries: [
                { // displacement
                    binding: 0,
                    visibility: GPUShaderStage.VERTEX | GPUShaderStage.FRAGMENT, // Fragment shader stage is only for debug
                    texture: { sampleType: "unfilterable-float" }
                },
                { // normals
                    binding: 1,
                    visibility: GPUShaderStage.FRAGMENT,
                    texture: { sampleType: "float" }
                },
                { // sampler
                    binding: 2,
                    visibility: GPUShaderStage.VERTEX | GPUShaderStage.FRAGMENT,
                    sampler: {}
                }
            ]
        })

        this.sampler = renderer.device.createSampler({
            magFilter: 'linear',
            minFilter: 'linear',
            mipmapFilter: 'linear',
            addressModeU: 'clamp-to-edge',
            addressModeV: 'clamp-to-edge',
            addressModeW: 'clamp-to-edge'
        })

        // The compute pipeline
        this.computePipeline = renderer.device.createComputePipeline({
            label: "ocean surface compute pipeline",
            layout: renderer.device.createPipelineLayout({
                label: "ocean surface compute pipeline layout",
                bindGroupLayouts: [this.computeBindGroupLayout]
            }),
            compute: {
                module: renderer.device.createShaderModule({
                    label: "ocean compute shader",
                    code: shaders.oceanSurfaceComputeSrc
                }),
                entryPoint: "main"
            }
        });

        // Initializing the buffers that actually hold the quad
        const verts = [];
        for (let x = 0; x < quad_res[0]; x++) {
            for (let y = 0; y < quad_res[1]; y++) {
                verts.push(x);
                verts.push(y);
            }
        }

        this.vertexBuffer = renderer.device.createBuffer({
            size: verts.length * 4, // 4 bytes per float32
            usage: GPUBufferUsage.VERTEX | GPUBufferUsage.COPY_DST,
            mappedAtCreation: true
        });

        new Float32Array(this.vertexBuffer.getMappedRange()).set(verts);
        this.vertexBuffer.unmap();

        const inds = [];
        for (let x = 0; x < quad_res[0] - 1; x++) {
            for (let y = 0; y < quad_res[1] - 1; y++) {
                const a = x + y * quad_res[0];
                const b = (x + 1) + y * quad_res[0];
                const c = x + (y + 1) * quad_res[0];
                const d = (x + 1) + (y + 1) * quad_res[0];
                inds.push(a, b, c, b, c, d);
            }
        }

        this.numIndices = inds.length;

        this.indexBuffer = renderer.device.createBuffer({
            size: inds.length * 4,
            usage: GPUBufferUsage.INDEX | GPUBufferUsage.COPY_DST,
            mappedAtCreation: true
        });

        new Uint32Array(this.indexBuffer.getMappedRange()).set(inds);
        this.indexBuffer.unmap();

    }

    // TODO: compute multiple chunks
    public computeTextures(encoder: GPUCommandEncoder, chunk: OceanSurfaceChunk) {
        const computePass = encoder.beginComputePass();
        computePass.setPipeline(this.computePipeline);
        computePass.setBindGroup(0, chunk.computeBindGroup);

        // TODO: don't hardcode this
        computePass.dispatchWorkgroups(64, 64, 1);
        computePass.end();
    }
}