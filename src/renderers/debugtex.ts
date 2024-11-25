import * as renderer from '../renderer';
import * as shaders from '../shaders/shaders';
import { OceanSurface } from '../stage/oceansurface';
import * as oceansurface from "../stage/oceansurface"
import { OceanSurfaceChunk } from '../stage/oceansurfacechunk';
import { Stage } from '../stage/stage';

export class DebugTexRenderer extends renderer.Renderer {
    oceanSurface: OceanSurface;
    chunk: OceanSurfaceChunk;
    pipeline: GPURenderPipeline;

    constructor(stage: Stage) {
        super(stage);
        this.oceanSurface = new OceanSurface();
        this.chunk = new OceanSurfaceChunk(
            this.oceanSurface.computeBindGroupLayout,
            this.oceanSurface.renderBindGroupLayout,
            this.oceanSurface.sampler
        );

        this.pipeline = renderer.device.createRenderPipeline({
            layout: renderer.device.createPipelineLayout({
                label: "naive pipeline layout",
                bindGroupLayouts: [
                    this.oceanSurface.renderBindGroupLayout
                ]
            }),
            vertex: {
                module: renderer.device.createShaderModule({
                    label: "debug tex vert",
                    code: shaders.outputTextureVertSrc
                }),
                buffers: []
            },
            fragment: {
                module: renderer.device.createShaderModule({
                    label: "debug tex frag",
                    code: shaders.outputTextureFragSrc,
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
        
        const currentTime = performance.now() * 0.001; // Convert to seconds
        this.chunk.updateTime(currentTime);

        const encoder = renderer.device.createCommandEncoder();
        this.oceanSurface.computeTextures(encoder, this.chunk);
        const canvasTextureView = renderer.context.getCurrentTexture().createView();

        const renderPass = encoder.beginRenderPass({
            label: "debug tex render pass",
            colorAttachments: [
                {
                    view: canvasTextureView,
                    clearValue: [0, 0, 0, 0],
                    loadOp: "clear", // load
                    storeOp: "store"
                },
            ],
        });
        renderPass.setPipeline(this.pipeline);
        renderPass.setBindGroup(0, this.chunk.renderBindGroup);
        renderPass.draw(6);
        renderPass.end();
        renderer.device.queue.submit([encoder.finish()]);
    }
}
