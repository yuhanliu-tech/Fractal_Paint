import { vec3 } from "wgpu-matrix";
import { device } from "../renderer";
import * as shaders from '../shaders/shaders';
import { Camera } from "./camera";
import { Cube } from "./cube";
import { ObjLoader } from "./objLoader";

export class Coral {
    private camera: Camera;
    cube: Cube;
    objModel: ObjLoader | null = null; // Store the loaded model
    numCoral = 500;

    static readonly maxNumCoral = 5000;
    static readonly numFloatsPerCoral = 8; // vec3f is aligned at 16 byte boundaries
    static readonly lightIntensity = 0.1;

    coralArray = new Float32Array(Coral.maxNumCoral * Coral.numFloatsPerCoral);
    coralSetStorageBuffer: GPUBuffer;

    camPosUniformBuffer: GPUBuffer;

    placeCoralComputeBindGroupLayout: GPUBindGroupLayout;
    placeCoralComputeBindGroup: GPUBindGroup;
    placeCoralComputePipeline: GPUComputePipeline;

    vertexBuffer: GPUBuffer | null = null; 
    indexBuffer: GPUBuffer | null = null; 
    indexCount: number = 0;

    constructor(camera: Camera) {
        this.camera = camera;
        this.cube = new Cube(2);

        // Initialize the model asynchronously
        this.loadModel("./wahoo.obj").then(() => {
            if (this.objModel) {
                this.vertexBuffer = device.createBuffer({
                    size: this.objModel.vertices.byteLength,
                    usage: GPUBufferUsage.VERTEX,
                    mappedAtCreation: true,
                });
                new Float32Array(this.vertexBuffer.getMappedRange()).set(this.objModel.vertices);
                device.queue.writeBuffer(this.vertexBuffer, 0, this.objModel.vertices);
        
                this.indexBuffer = device.createBuffer({
                    size: this.objModel.indices.byteLength,
                    usage: GPUBufferUsage.INDEX,
                    mappedAtCreation: true,
                });
                new Uint32Array(this.indexBuffer.getMappedRange()).set(this.objModel.indices);
                device.queue.writeBuffer(this.indexBuffer, 0, this.objModel.indices);
        
                this.indexCount = this.objModel.indices.length;
            } else {
                console.error("Failed to initialize buffers due to missing model.");
            }
        });

        this.coralSetStorageBuffer = device.createBuffer({
            label: "coral",
            size: 16 + this.coralArray.byteLength, // 16 for numCoral + padding
            usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_DST
        });
        this.updateCoralSetUniformNumCoral();

        this.camPosUniformBuffer = device.createBuffer({
            label: "camera position uniform",
            size: 2 * 4,
            usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST
        });

        this.placeCoralComputeBindGroupLayout = device.createBindGroupLayout({
            label: "place coral compute bind group layout",
            entries: [
                { binding: 0, visibility: GPUShaderStage.COMPUTE, buffer: { type: "storage" } },
                { binding: 1, visibility: GPUShaderStage.COMPUTE, buffer: { type: "uniform" } }
            ]
        });

        this.placeCoralComputeBindGroup = device.createBindGroup({
            label: "place coral compute bind group",
            layout: this.placeCoralComputeBindGroupLayout,
            entries: [
                { binding: 0, resource: { buffer: this.coralSetStorageBuffer } },
                { binding: 1, resource: { buffer: this.camPosUniformBuffer } }
            ]
        });

        this.placeCoralComputePipeline = device.createComputePipeline({
            label: "place coral compute pipeline",
            layout: device.createPipelineLayout({
                label: "place coral compute pipeline layout",
                bindGroupLayouts: [this.placeCoralComputeBindGroupLayout]
            }),
            compute: {
                module: device.createShaderModule({
                    label: "place coral compute shader",
                    code: shaders.placeCoralComputeSrc
                }),
                entryPoint: "main"
            }
        });
    }

    private async loadModel(url: string) {
        try {
            console.log(`Loading OBJ model from: ${url}`);
            this.objModel = await ObjLoader.load(url);
            console.log("OBJ model loaded successfully.");
        } catch (error) {
            console.error("Failed to load OBJ model:", error);
        }
    }

    updateCoralSetUniformNumCoral() {
        device.queue.writeBuffer(this.coralSetStorageBuffer, 0, new Uint32Array([this.numCoral]));
    }

    draw(passEncoder: GPURenderPassEncoder) {
        if (!this.vertexBuffer || !this.indexBuffer) return;
        passEncoder.setVertexBuffer(0, this.vertexBuffer);
        passEncoder.setIndexBuffer(this.indexBuffer, "uint32");
        passEncoder.drawIndexed(this.indexCount, this.numCoral);
    }

    onFrame(x: number, y: number) {
        device.queue.writeBuffer(this.camPosUniformBuffer, 0, new Float32Array([x, y]));
        const encoder = device.createCommandEncoder();
        const computePass = encoder.beginComputePass();
        computePass.setPipeline(this.placeCoralComputePipeline);
        computePass.setBindGroup(0, this.placeCoralComputeBindGroup);

        const workgroupCount = Math.ceil(this.numCoral / shaders.constants.moveLightsWorkgroupSize);
        computePass.dispatchWorkgroups(workgroupCount);

        computePass.end();
        device.queue.submit([encoder.finish()]);
    }
}
