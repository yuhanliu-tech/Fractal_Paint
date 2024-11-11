import * as renderer from '../renderer';
import * as shaders from '../shaders/shaders';
import { Stage } from '../stage/stage';

export class OceanRenderer extends renderer.Renderer {
    private displacementTexture!: GPUTexture;
    private normalTexture!: GPUTexture;
    private displacementTextureView!: GPUTextureView;
    private normalTextureView!: GPUTextureView;

    private sceneUniformsBindGroupLayout!: GPUBindGroupLayout;
    private sceneUniformsBindGroup!: GPUBindGroup;

    private computePipeline!: GPUComputePipeline;
    private renderPipeline!: GPURenderPipeline;
    private computeBindGroup!: GPUBindGroup;

    constructor(stage: Stage) {
        super(stage);

        this.initializeTextures();
        this.initializeComputePipeline();
        this.initializeRenderPipeline();
        this.createBindGroups();
    }

    // Step 1: Initialize Textures for displacement and normals
    private initializeTextures() {
        const textureSize = 512;

        this.displacementTexture = renderer.device.createTexture({
            size: [textureSize, textureSize],
            format: "rgba32float",
            usage: GPUTextureUsage.STORAGE_BINDING | GPUTextureUsage.TEXTURE_BINDING | GPUTextureUsage.RENDER_ATTACHMENT
        });

        this.normalTexture = renderer.device.createTexture({
            size: [textureSize, textureSize],
            format: "rgba32float",
            usage: GPUTextureUsage.STORAGE_BINDING | GPUTextureUsage.TEXTURE_BINDING | GPUTextureUsage.RENDER_ATTACHMENT
        });

        this.displacementTextureView = this.displacementTexture.createView();
        this.normalTextureView = this.normalTexture.createView();
    }

    // Step 2: Create Compute Pipeline for generating Tessendorf waves
    private initializeComputePipeline() {
        const computeShaderModule = renderer.device.createShaderModule({
            code: shaders.oceanComputeSrc // Tessendorf compute shader
        });

        this.computePipeline = renderer.device.createComputePipeline({
            layout: 'auto',
            compute: {
                module: computeShaderModule,
                entryPoint: 'main'
            }
        });

        // Create a bind group for the compute pipeline
        this.computeBindGroup = renderer.device.createBindGroup({
            layout: this.computePipeline.getBindGroupLayout(0),
            entries: [
                { binding: 0, resource: this.displacementTexture.createView() },
                { binding: 1, resource: this.normalTexture.createView() }
            ]
        });
    }

    // Step 3: Create Render Pipeline for rendering the ocean
    private initializeRenderPipeline() {
        // Create a pipeline layout
        this.sceneUniformsBindGroupLayout = renderer.device.createBindGroupLayout({
            entries: [
                { binding: 0, visibility: GPUShaderStage.VERTEX | GPUShaderStage.FRAGMENT, buffer: { type: "uniform" } }
            ]
        });

        // Create the vertex and fragment shaders
        const vertexShaderModule = renderer.device.createShaderModule({
            code: shaders.oceanVertSrc
        });

        const fragmentShaderModule = renderer.device.createShaderModule({
            code: shaders.oceanFragSrc
        });

        // Create the render pipeline
        this.renderPipeline = renderer.device.createRenderPipeline({
            layout: renderer.device.createPipelineLayout({
                bindGroupLayouts: [this.sceneUniformsBindGroupLayout]
            }),
            vertex: {
                module: vertexShaderModule,
                entryPoint: 'main',
                buffers: [renderer.vertexBufferLayout]
            },
            fragment: {
                module: fragmentShaderModule,
                entryPoint: 'main',
                targets: [{ format: renderer.canvasFormat }]
            },
            primitive: {
                topology: 'triangle-list'
            },
            depthStencil: {
                format: 'depth24plus',
                depthWriteEnabled: true,
                depthCompare: 'less'
            }
        });
    }

    // Step 4: Create Bind Groups
    private createBindGroups() {
        this.sceneUniformsBindGroup = renderer.device.createBindGroup({
            layout: this.sceneUniformsBindGroupLayout,
            entries: [
                { binding: 0, resource: { buffer: this.stage.camera.uniformsBuffer } }
            ]
        });
    }

    // Step 5: Run the compute pass to generate the displacement map
    private runComputePass() {
        const commandEncoder = renderer.device.createCommandEncoder();
        const passEncoder = commandEncoder.beginComputePass();
        passEncoder.setPipeline(this.computePipeline);
        passEncoder.setBindGroup(0, this.computeBindGroup);
        passEncoder.dispatchWorkgroups(64, 64); // Adjust based on texture size
        passEncoder.end();
        renderer.device.queue.submit([commandEncoder.finish()]);
    }

    // Step 6: Render the ocean surface using the generated displacement map
    public draw() {
        this.runComputePass();

        const commandEncoder = renderer.device.createCommandEncoder();
        const renderPass = commandEncoder.beginRenderPass({
            colorAttachments: [{
                view: renderer.context.getCurrentTexture().createView(),
                loadOp: 'clear',
                storeOp: 'store',
                clearValue: { r: 0, g: 0, b: 0, a: 1 }
            }],
            depthStencilAttachment: {
                view: renderer.context.getCurrentTexture().createView(),
                depthLoadOp: 'clear',
                depthStoreOp: 'store',
                depthClearValue: 1.0
            }
        });

        renderPass.setPipeline(this.renderPipeline);
        renderPass.setBindGroup(0, this.sceneUniformsBindGroup);
        renderPass.draw(6);
        renderPass.end();

        renderer.device.queue.submit([commandEncoder.finish()]);
    }
}