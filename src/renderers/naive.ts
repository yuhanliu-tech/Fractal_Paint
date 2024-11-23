import * as renderer from '../renderer';
import * as shaders from '../shaders/shaders';
import { OceanSurface } from '../stage/oceansurface';
import * as oceansurface from "../stage/oceansurface"
import { OceanSurfaceChunk } from '../stage/oceansurfacechunk';
import { OceanFloor } from '../stage/oceanfloor';
import * as oceanfloor from "../stage/oceanfloor"
import { OceanFloorChunk } from '../stage/oceanfloorchunk';
import { Stage } from '../stage/stage';

export class NaiveRenderer extends renderer.Renderer {
    oceanSurface: OceanSurface;
    chunk: OceanSurfaceChunk;

    oceanFloor: OceanFloor;
    oceanFloorChunk: OceanFloorChunk;


    sceneUniformsBindGroupLayout: GPUBindGroupLayout;
    sceneUniformsBindGroup: GPUBindGroup;

    albedoTexture: GPUTexture;
    albedoTextureView: GPUTextureView;
    distanceTexture: GPUTexture;
    distanceTextureView: GPUTextureView;
    depthTexture: GPUTexture;
    depthTextureView: GPUTextureView;

    oceanSurfaceRenderPipeline: GPURenderPipeline;
    oceanFloorRenderPipeline: GPURenderPipeline;

    fullScreenBindGroupLayout: GPUBindGroupLayout;
    fullScreenBindGroup: GPUBindGroup;
    fullScreenPipeline: GPURenderPipeline;

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
                {
                    binding: 0,
                    visibility: GPUShaderStage.VERTEX | GPUShaderStage.FRAGMENT,
                    buffer: { type: "uniform" }
                },
            ]
        });

        this.sceneUniformsBindGroup = renderer.device.createBindGroup({
            label: "scene uniforms bind group",
            layout: this.sceneUniformsBindGroupLayout,
            entries: [
                {
                    binding: 0,
                    resource: { buffer: this.camera.uniformsBuffer }
                }
            ]
        });

        this.albedoTexture = renderer.device.createTexture({
            size: [renderer.canvas.width, renderer.canvas.height],
            format: renderer.canvasFormat,
            usage: GPUTextureUsage.RENDER_ATTACHMENT | GPUTextureUsage.TEXTURE_BINDING
        });
        this.albedoTextureView = this.albedoTexture.createView();

        this.distanceTexture = renderer.device.createTexture({
            size: [renderer.canvas.width, renderer.canvas.height],
            format: "rgba16float",
            usage: GPUTextureUsage.RENDER_ATTACHMENT | GPUTextureUsage.TEXTURE_BINDING
        })
        this.distanceTextureView = this.distanceTexture.createView();

        this.depthTexture = renderer.device.createTexture({
            size: [renderer.canvas.width, renderer.canvas.height],
            format: "depth24plus",
            usage: GPUTextureUsage.RENDER_ATTACHMENT
        });
        this.depthTextureView = this.depthTexture.createView();

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
                    {   // albedo
                        format: renderer.canvasFormat,
                    },
                    {
                        //distance
                        format: "rgba16float"
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
                    {   // albedo
                        format: renderer.canvasFormat,
                    },
                    {
                        //distance
                        format: "rgba16float"
                    }
                ]
            }
        })

        this.fullScreenBindGroupLayout = renderer.device.createBindGroupLayout({
            entries: [
                {   // albedo
                    binding: 0,
                    visibility: GPUShaderStage.FRAGMENT,
                    texture: { sampleType: "unfilterable-float" }
                },
                {   // distance
                    binding: 1,
                    visibility: GPUShaderStage.FRAGMENT,
                    texture: { sampleType: "unfilterable-float" }
                },
                {
                    // depth
                    binding: 2,
                    visibility: GPUShaderStage.FRAGMENT,
                    texture: { sampleType: "depth" }
                }
            ]
        });

        this.fullScreenBindGroup = renderer.device.createBindGroup({
            layout: this.fullScreenBindGroupLayout,
            entries: [
                {   // albedo
                    binding: 0,
                    resource: this.albedoTextureView
                },
                {   // distance
                    binding: 1,
                    resource: this.distanceTextureView
                },
                {   // depth
                    binding: 2,
                    resource: this.depthTextureView
                }
            ]
        });

        this.fullScreenPipeline = renderer.device.createRenderPipeline({
            label: "deferred fullscreen render pipeline",
            layout: renderer.device.createPipelineLayout({
                label: "fullscreen deferred pipeline layout",
                bindGroupLayouts: [
                    this.sceneUniformsBindGroupLayout,
                    this.fullScreenBindGroupLayout
                ]
            }),
            vertex: {
                module: renderer.device.createShaderModule({
                    label: "post process vert shader",
                    code: shaders.postProcessVertSrc
                }),
                buffers: []
            },
            fragment: {
                module: renderer.device.createShaderModule({
                    label: "post process frag shader",
                    code: shaders.postProcessFragSrc,
                }),
                targets: [
                    {
                        format: renderer.canvasFormat,
                    }
                ]
            }
        });
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

        const oceanSurfaceRenderPass = encoder.beginRenderPass({
            label: "ocean surface render pass",
            colorAttachments: [
                {
                    view: this.albedoTextureView,
                    clearValue: [0, 0, 0, 0],
                    loadOp: "clear",
                    storeOp: "store"
                },
                {
                    view: this.distanceTextureView,
                    clearValue: [0, 0, 0, 0],
                    loadOp: "clear",
                    storeOp: "store"
                }
            ],
            depthStencilAttachment: {
                view: this.depthTextureView,
                depthClearValue: 1.0,
                depthLoadOp: "clear", // load 
                depthStoreOp: "store"
            }
        });
        // oceanSurfaceRenderPass.setPipeline(this.oceanSurfaceRenderPipeline);
        // oceanSurfaceRenderPass.setBindGroup(0, this.sceneUniformsBindGroup);
        // oceanSurfaceRenderPass.setBindGroup(1, this.chunk.renderBindGroup);

        // oceanSurfaceRenderPass.setVertexBuffer(0, this.oceanSurface.vertexBuffer);
        // oceanSurfaceRenderPass.setIndexBuffer(this.oceanSurface.indexBuffer, 'uint32');
        // oceanSurfaceRenderPass.drawIndexed(this.oceanSurface.numIndices);
        oceanSurfaceRenderPass.end();

        // const oceanFloorRenderPass = encoder.beginRenderPass({
        //     label: "ocean floor render pass",
        //     colorAttachments: [
        //         {
        //             view: this.albedoTextureView,
        //             loadOp: "load",
        //             storeOp: "store"
        //         },
        //         {
        //             view: this.distanceTextureView,
        //             loadOp: "load",
        //             storeOp: "store"
        //         }
        //     ],
        //     depthStencilAttachment: {
        //         view: this.depthTextureView,
        //         depthClearValue: 1.0,
        //         depthLoadOp: "load",
        //         depthStoreOp: "store"
        //     }
        // });
        // oceanFloorRenderPass.setPipeline(this.oceanFloorRenderPipeline);
        // oceanFloorRenderPass.setBindGroup(0, this.sceneUniformsBindGroup);
        // oceanFloorRenderPass.setBindGroup(1, this.oceanFloorChunk.renderBindGroup);

        // oceanFloorRenderPass.setVertexBuffer(0, this.oceanFloor.vertexBuffer);
        // oceanFloorRenderPass.setIndexBuffer(this.oceanFloor.indexBuffer, 'uint32');
        // oceanFloorRenderPass.drawIndexed(this.oceanFloor.numIndices);
        // oceanFloorRenderPass.end();

        // const canvasTextureView = renderer.context.getCurrentTexture().createView();
        // const fullScreenPass = encoder.beginRenderPass({
        //     label: "post process render pass",
        //     colorAttachments: [
        //         {
        //             view: canvasTextureView,
        //             clearValue: [0, 0, 0, 0],
        //             loadOp: "clear",
        //             storeOp: "store"
        //         }
        //     ]
        // });
        // fullScreenPass.setPipeline(this.fullScreenPipeline);
        // fullScreenPass.setBindGroup(shaders.constants.bindGroup_scene, this.sceneUniformsBindGroup)
        // fullScreenPass.setBindGroup(shaders.constants.bindGroup_fullscreen, this.fullScreenBindGroup);
        // fullScreenPass.draw(6);

        // fullScreenPass.end();

        renderer.device.queue.submit([encoder.finish()]);
    }
}
