import { vec3 } from "wgpu-matrix"
import * as shaders from '../shaders/shaders';
import * as renderer from '../renderer';

// Vertex buffer layout for a fullscreen quad
export const vertexBufferLayout: GPUVertexBufferLayout = {
    arrayStride: 8, // Two floats (2 * 4 bytes)
    attributes: [
        {
            // Position attribute
            format: "float32x2",
            offset: 0,
            shaderLocation: 0, // Matches @location(0) in vertex shader
        },
    ],
};

export class Jellyfish {

    renderBindGroupLayout: GPUBindGroupLayout;
    sampler: GPUSampler;
    renderPipeline: GPURenderPipeline;
    renderBindGroup: GPUBindGroup;

    constructor() {

        this.renderBindGroupLayout = renderer.device.createBindGroupLayout({
            label: "jellyfish render layout",
            entries: [
                { // displacement
                    binding: 0,
                    visibility: GPUShaderStage.VERTEX,
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

        // Set up the render pipeline for the jellyfish shader
        this.renderPipeline = renderer.device.createRenderPipeline({
            label: "jellyfish render pipeline",
            layout: renderer.device.createPipelineLayout({
                label: "jellyfish pipeline layout",
                bindGroupLayouts: [this.renderBindGroupLayout],
            }),
            vertex: {
                module: renderer.device.createShaderModule({
                    label: "fullscreen quad vertex shader",
                    code: shaders.fullscreenVertSrc, // Fullscreen quad vertex shader
                }),
                entryPoint: "main",
                buffers: [], // No vertex buffer required for a fullscreen quad
            },
            fragment: {
                module: renderer.device.createShaderModule({
                    label: "jellyfish fragment shader",
                    code: shaders.jellyfishFragSrc, // Jellyfish fragment shader
                }),
                entryPoint: "main",
                targets: [
                    {
                        format: renderer.canvasFormat,
                    },
                ],
            },
            primitive: {
                topology: "triangle-list",
            },
            depthStencil: {
                depthWriteEnabled: false,
                depthCompare: "always",
                format: "depth24plus",
            },
        });

    }
}