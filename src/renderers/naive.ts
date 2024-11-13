import * as renderer from '../renderer';
import * as shaders from '../shaders/shaders';
import { OceanSurface } from '../stage/oceansurface';
import * as oceansurface from "../stage/oceansurface"
import { OceanSurfaceChunk } from '../stage/oceansurfacechunk';
import { Stage } from '../stage/stage';

export class NaiveRenderer extends renderer.Renderer {
    oceanSurface: OceanSurface;
    chunk: OceanSurfaceChunk;

    sceneUniformsBindGroupLayout: GPUBindGroupLayout;
    sceneUniformsBindGroup: GPUBindGroup;

    depthTexture: GPUTexture;
    depthTextureView: GPUTextureView;

    pipeline: GPURenderPipeline;

    oceanSurfaceRenderPipeline: GPURenderPipeline;

    constructor(stage: Stage) {
        super(stage);
        this.oceanSurface = new OceanSurface();
        this.chunk = new OceanSurfaceChunk(
            this.oceanSurface.computeBindGroupLayout,
            this.oceanSurface.renderBindGroupLayout,
            this.oceanSurface.sampler
        );

        this.sceneUniformsBindGroupLayout = renderer.device.createBindGroupLayout({
            label: "scene uniforms bind group layout",
            entries: [
                {
                    binding: 0,
                    visibility: GPUShaderStage.VERTEX,
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

        this.depthTexture = renderer.device.createTexture({
            size: [renderer.canvas.width, renderer.canvas.height],
            format: "depth24plus",
            usage: GPUTextureUsage.RENDER_ATTACHMENT
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
    }

    override draw() {
        this.chunk.updatePosition(this.camera.cameraPos[0], this.camera.cameraPos[2]);

        const encoder = renderer.device.createCommandEncoder();
        this.oceanSurface.computeTextures(encoder, this.chunk);
        const canvasTextureView = renderer.context.getCurrentTexture().createView();
        
        const renderPass = encoder.beginRenderPass({
            label: "naive render pass",
            colorAttachments: [
                {
                    view: canvasTextureView,
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

        const oceanSurfaceRenderPass = encoder.beginRenderPass({
            label: "ocean surface render pass",
            colorAttachments: [
                {
                    view: canvasTextureView,
                    clearValue: [0, 0, 0, 0],
                    loadOp: "load",    // TODO: change loadOp when rendering on top of other stuff
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
        oceanSurfaceRenderPass.setPipeline(this.oceanSurfaceRenderPipeline);
        oceanSurfaceRenderPass.setBindGroup(0, this.sceneUniformsBindGroup);
        // TODO: Bind group for chunk position
        oceanSurfaceRenderPass.setBindGroup(1, this.chunk.renderBindGroup);
        
        oceanSurfaceRenderPass.setVertexBuffer(0, this.oceanSurface.vertexBuffer);
        oceanSurfaceRenderPass.setIndexBuffer(this.oceanSurface.indexBuffer, 'uint32');
        oceanSurfaceRenderPass.drawIndexed(this.oceanSurface.numIndices);
        oceanSurfaceRenderPass.end();  
        renderer.device.queue.submit([encoder.finish()]);
    }
}
