import * as renderer from '../renderer';
import * as shaders from '../shaders/shaders';
import { OceanSurface } from '../stage/oceansurface';
import * as oceansurface from "../stage/oceansurface"
import { OceanSurfaceChunk } from '../stage/oceansurfacechunk';
import { OceanFloor } from '../stage/oceanfloor';
import * as oceanfloor from "../stage/oceanfloor"
import { OceanFloorChunk } from '../stage/oceanfloorchunk';
import { Stage } from '../stage/stage';
import { Jellyfish } from '../stage/jellyfish';

export class NaiveRenderer extends renderer.Renderer {
    oceanSurface: OceanSurface;
    chunk: OceanSurfaceChunk;

    oceanFloor: OceanFloor;
    oceanFloorChunk: OceanFloorChunk;

    sceneUniformsBindGroupLayout: GPUBindGroupLayout;
    sceneUniformsBindGroup: GPUBindGroup;

    depthTexture: GPUTexture;
    depthTextureView: GPUTextureView;

    renderTexture: GPUTexture;
    renderTextureView: GPUTextureView;

    pipeline: GPURenderPipeline;
    coralPipeline: GPURenderPipeline;

    oceanSurfaceRenderPipeline: GPURenderPipeline;
    oceanFloorRenderPipeline: GPURenderPipeline;

    jellyfish: Jellyfish;
    jellyfishBindGroup: GPUBindGroup;
    jellyfishPipeline: GPURenderPipeline;

    constructor(stage: Stage) {
        super(stage);
        this.oceanSurface = new OceanSurface();
        this.chunk = new OceanSurfaceChunk(
            this.oceanSurface.computeBindGroupLayout,
            this.oceanSurface.renderBindGroupLayout,
            this.oceanSurface.sampler
        );

        this.oceanFloor = new OceanFloor();
        this.oceanFloorChunk = new OceanFloorChunk(
            this.oceanFloor.computeBindGroupLayout,
            this.oceanFloor.renderBindGroupLayout,
            this.oceanFloor.sampler
        );

        this.sceneUniformsBindGroupLayout = renderer.device.createBindGroupLayout({
            label: "scene uniforms bind group layout",
            entries: [
                { // camera   // camera
                    binding: 0,
                    visibility: GPUShaderStage.VERTEX | GPUShaderStage.FRAGMENT,
                    buffer: { type: "uniform" }
                },
                {   // wavelengths
                    binding: 1,
                    visibility: GPUShaderStage.FRAGMENT,
                    buffer: { type: "uniform" }
                },
                {   // water properties
                    binding: 2,
                    visibility: GPUShaderStage.FRAGMENT,
                    buffer: { type: "uniform" }
                },
                {   // wavelength sensitivities
                    binding: 3,
                    visibility: GPUShaderStage.FRAGMENT,
                    buffer: { type: "uniform" }
                }
            ]
        });

        this.sceneUniformsBindGroup = renderer.device.createBindGroup({
            label: "scene uniforms bind group",
            layout: this.sceneUniformsBindGroupLayout,
            entries: [
                { // camera
                    binding: 0,
                    resource: { buffer: this.camera.uniformsBuffer }
                },
                {
                    binding: 1,
                    resource: { buffer: stage.spectralUniforms.wavelengthGPUBuffer }
                },
                {
                    binding: 2,
                    resource: { buffer: stage.spectralUniforms.waterPropsGPUBuffer }
                },
                {
                    binding: 3,
                    resource: { buffer: stage.spectralUniforms.sensitivitiesGPUBuffer }
                }
            ]
        });

        this.renderTexture = renderer.device.createTexture({
            size: [renderer.canvas.width, renderer.canvas.height],
            format: renderer.canvasFormat,
            usage: GPUTextureUsage.RENDER_ATTACHMENT | GPUTextureUsage.TEXTURE_BINDING
        });

        this.renderTextureView = this.renderTexture.createView();

        this.depthTexture = renderer.device.createTexture({
            size: [renderer.canvas.width, renderer.canvas.height],
            format: "depth24plus",
            usage: GPUTextureUsage.RENDER_ATTACHMENT | GPUTextureUsage.TEXTURE_BINDING
        });
        this.depthTextureView = this.depthTexture.createView();

        this.pipeline = renderer.device.createRenderPipeline({
            layout: renderer.device.createPipelineLayout({
                label: "naive pipeline layout",
                bindGroupLayouts: [
                    this.sceneUniformsBindGroupLayout,
                    renderer.modelBindGroupLayout,
                    renderer.materialBindGroupLayout
                ]
            }),
            depthStencil: {
                depthWriteEnabled: true,
                depthCompare: "less",
                format: "depth24plus"
            },
            vertex: {
                module: renderer.device.createShaderModule({
                    label: "naive vert shader",
                    code: shaders.naiveVertSrc
                }),
                buffers: [renderer.vertexBufferLayout]
            },
            fragment: {
                module: renderer.device.createShaderModule({
                    label: "naive frag shader",
                    code: shaders.naiveFragSrc,
                }),
                targets: [
                    {
                        format: renderer.canvasFormat,
                    }
                ]
            }
        });

        this.coralPipeline = renderer.device.createRenderPipeline({
            layout: renderer.device.createPipelineLayout({
                label: "naive pipeline layout",
                bindGroupLayouts: [
                    this.sceneUniformsBindGroupLayout,
                    this.oceanFloor.renderBindGroupLayout,
                    this.coral.renderBindGroupLayout
                ]
            }),
            depthStencil: {
                depthWriteEnabled: true,
                depthCompare: "less",
                format: "depth24plus"
            },
            vertex: {
                module: renderer.device.createShaderModule({
                    label: "coral vert shader",
                    code: shaders.coralVertSrc
                }),
                buffers: [renderer.vertexBufferLayout]
            },
            fragment: {
                module: renderer.device.createShaderModule({
                    label: "coral frag shader",
                    code: shaders.coralFragSrc,
                }),
                targets: [
                    {
                        format: renderer.canvasFormat,
                    }
                ]
            }
        });

        this.jellyfish = new Jellyfish();

        this.jellyfishBindGroup = renderer.device.createBindGroup({
            label: "jellyfish textures bind group",
            layout: this.jellyfish.bindGroupLayout,
            entries: [
                {
                    binding: 0,
                    resource: { buffer: this.chunk.timeBuffer }
                },
                {
                    binding: 1,
                    resource: this.renderTextureView
                },
                {
                    binding: 2,
                    resource: this.depthTextureView
                }
            ]
        });

        this.jellyfishPipeline = renderer.device.createRenderPipeline({
            layout: renderer.device.createPipelineLayout({
                label: "jellyfish pipeline layout",
                bindGroupLayouts: [
                    this.sceneUniformsBindGroupLayout,
                    this.jellyfish.bindGroupLayout
                    //renderer.modelBindGroupLayout,
                    //renderer.materialBindGroupLayout
                ]
            }),
            vertex: {
                module: renderer.device.createShaderModule({
                    label: "jellyfish vertex shader",
                    code: shaders.fullscreenVertSrc, // Use a fullscreen quad vertex shader
                }),
                buffers: [], // No vertex buffers for fullscreen quad
            },
            fragment: {
                module: renderer.device.createShaderModule({
                    label: "jellyfish fragment shader",
                    code: shaders.jellyfishFragSrc,
                }),
                targets: [
                    {
                        format: renderer.canvasFormat,
                    },
                ],
            },
            // depthStencil: {
            //     depthWriteEnabled: false,
            //     depthCompare: "always",
            //     format: "depth24plus",
            // },
        });

        this.oceanSurfaceRenderPipeline = renderer.device.createRenderPipeline({
            layout: renderer.device.createPipelineLayout({
                label: "ocean surface pipeline layout",
                bindGroupLayouts: [
                    this.sceneUniformsBindGroupLayout,
                    this.oceanSurface.renderBindGroupLayout
                ]
            }),
            depthStencil: {
                depthWriteEnabled: true,
                depthCompare: "less",
                format: "depth24plus"
            },
            vertex: {
                module: renderer.device.createShaderModule({
                    label: "ocean surface vertex shader",
                    code: shaders.oceanSurfaceVertSrc
                }),
                buffers: [oceansurface.vertexBufferLayout]
            },
            fragment: {
                module: renderer.device.createShaderModule({
                    label: "ocean surface frag shader",
                    code: shaders.oceanSurfaceFragSrc,
                }),
                targets: [
                    {
                        format: renderer.canvasFormat,
                    }
                ]
            }
        })

        this.oceanFloorRenderPipeline = renderer.device.createRenderPipeline({
            layout: renderer.device.createPipelineLayout({
                label: "ocean floor pipeline layout",
                bindGroupLayouts: [
                    this.sceneUniformsBindGroupLayout,
                    this.oceanFloor.renderBindGroupLayout
                ]
            }),
            depthStencil: {
                depthWriteEnabled: true,
                depthCompare: "less",
                format: "depth24plus"
            },
            vertex: {
                module: renderer.device.createShaderModule({
                    label: "ocean floor vertex shader",
                    code: shaders.oceanFloorVertSrc
                }),
                buffers: [oceanfloor.vertexBufferLayout]
            },
            fragment: {
                module: renderer.device.createShaderModule({
                    label: "ocean floor frag shader",
                    code: shaders.oceanFloorFragSrc,
                }),
                targets: [
                    {
                        format: renderer.canvasFormat,
                    }
                ]
            }
        })
    }

    override draw() {

        this.chunk.updatePosition(this.camera.cameraPos[0], this.camera.cameraPos[2]);
        this.oceanFloorChunk.updatePosition(this.camera.cameraPos[0], this.camera.cameraPos[2]);

        const currentTime = performance.now() * 0.001; // Convert to seconds
        this.chunk.updateTime(currentTime);
        this.oceanFloorChunk.updateTime(currentTime);

        const encoder = renderer.device.createCommandEncoder();
        this.oceanSurface.computeTextures(encoder, this.chunk);
        this.oceanFloor.computeTextures(encoder, this.oceanFloorChunk);
        const canvasTextureView = renderer.context.getCurrentTexture().createView();

        const renderPass = encoder.beginRenderPass({
            label: "naive render pass",
            colorAttachments: [
                {
                    view: this.renderTextureView,
                    clearValue: [0, 0, 0, 0],
                    loadOp: "clear",
                    storeOp: "store"
                }
            ],
            depthStencilAttachment: {
                view: this.depthTextureView,
                depthClearValue: 1.0,
                depthLoadOp: "clear",
                depthStoreOp: "store"
            }
        });
        renderPass.setPipeline(this.pipeline);

        renderPass.setBindGroup(shaders.constants.bindGroup_scene, this.sceneUniformsBindGroup);
        this.scene.iterate(node => {
            renderPass.setBindGroup(shaders.constants.bindGroup_model, node.modelBindGroup);
        }, material => {
            renderPass.setBindGroup(shaders.constants.bindGroup_material, material.materialBindGroup);
        }, primitive => {
            renderPass.setVertexBuffer(0, primitive.vertexBuffer);
            renderPass.setIndexBuffer(primitive.indexBuffer, 'uint32');
            renderPass.drawIndexed(primitive.numIndices);
        });

        renderPass.end();

        const coralRenderPass = encoder.beginRenderPass({
            label: "coral render pass",
            colorAttachments: [
                {
                    view: this.renderTextureView,
                    clearValue: [0, 0, 0, 0],
                    loadOp: "load",
                    storeOp: "store"
                }
            ],
            depthStencilAttachment: {
                view: this.depthTextureView,
                depthClearValue: 1.0,
                depthLoadOp: "load",
                depthStoreOp: "store"
            }
        });
        coralRenderPass.setPipeline(this.coralPipeline);
        coralRenderPass.setBindGroup(shaders.constants.bindGroup_scene, this.sceneUniformsBindGroup);
        coralRenderPass.setBindGroup(1, this.oceanFloorChunk.renderBindGroup);

        // Loop through each coral type
        // FIXME: for loop through a list of coral chunks
        this.coralChunkManager.draw(coralRenderPass);

        coralRenderPass.end();

        const oceanSurfaceRenderPass = encoder.beginRenderPass({
            label: "ocean surface render pass",
            colorAttachments: [
                {
                    view: this.renderTextureView,
                    clearValue: [0, 0, 0, 0],
                    loadOp: "load", // load
                    storeOp: "store"
                },
            ],
            depthStencilAttachment: {
                view: this.depthTextureView,
                depthClearValue: 1.0,
                depthLoadOp: "load", // load 
                depthStoreOp: "store"
            }
        });
        oceanSurfaceRenderPass.setPipeline(this.oceanSurfaceRenderPipeline);
        oceanSurfaceRenderPass.setBindGroup(0, this.sceneUniformsBindGroup);
        oceanSurfaceRenderPass.setBindGroup(1, this.chunk.renderBindGroup);

        oceanSurfaceRenderPass.setVertexBuffer(0, this.oceanSurface.vertexBuffer);
        oceanSurfaceRenderPass.setIndexBuffer(this.oceanSurface.indexBuffer, 'uint32');
        oceanSurfaceRenderPass.drawIndexed(this.oceanSurface.numIndices);
        oceanSurfaceRenderPass.end();

        const oceanFloorRenderPass = encoder.beginRenderPass({
            label: "ocean floor render pass",
            colorAttachments: [
                {
                    view: this.renderTextureView,
                    clearValue: [0, 0, 0, 0],
                    loadOp: "load",
                    storeOp: "store"
                },
            ],
            depthStencilAttachment: {
                view: this.depthTextureView,
                depthClearValue: 1.0,
                depthLoadOp: "load",
                depthStoreOp: "store"
            }
        });
        oceanFloorRenderPass.setPipeline(this.oceanFloorRenderPipeline);
        oceanFloorRenderPass.setBindGroup(0, this.sceneUniformsBindGroup);
        oceanFloorRenderPass.setBindGroup(1, this.oceanFloorChunk.renderBindGroup);

        oceanFloorRenderPass.setVertexBuffer(0, this.oceanFloor.vertexBuffer);
        oceanFloorRenderPass.setIndexBuffer(this.oceanFloor.indexBuffer, 'uint32');
        oceanFloorRenderPass.drawIndexed(this.oceanFloor.numIndices);
        oceanFloorRenderPass.end();

        const jellyfishRenderPass = encoder.beginRenderPass({
            label: "jellyfish render pass",
            colorAttachments: [
                {
                    view: canvasTextureView,
                    clearValue: [0, 0, 0, 1],
                    loadOp: "clear",
                    storeOp: "store",
                },
            ],
            // depthStencilAttachment: {
            //     view: this.depthTextureView,
            //     depthClearValue: 1.0,
            //     depthLoadOp: "clear",
            //     depthStoreOp: "store",
            // },
        });

        jellyfishRenderPass.setPipeline(this.jellyfishPipeline);
        jellyfishRenderPass.setBindGroup(0, this.sceneUniformsBindGroup); // Pass uniforms
        jellyfishRenderPass.setBindGroup(1, this.jellyfishBindGroup); // Pass textures
        jellyfishRenderPass.draw(6); // Fullscreen quad
        jellyfishRenderPass.end();

        renderer.device.queue.submit([encoder.finish()]);
    }
}
