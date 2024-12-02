import { vec3 } from "wgpu-matrix";
import { device } from "../renderer";
import * as shaders from '../shaders/shaders';
import { Camera } from "./camera";
import { Cube } from "./cube";
import { ObjLoader } from "./objLoader";

function hash(p: [number, number]): number {
    // Constants for the dot product
    const k: [number, number] = [127.1, 311.7];
    
    // Compute the dot product
    const dot = p[0] * k[0] + p[1] * k[1];
    
    // Apply sine function and scale
    const value = Math.sin(dot) * 43758.5453;
    
    // Return the fractional part
    return value - Math.floor(value);
}

export async function makeCoral(camera:Camera, url:string) {
    let model = await ObjLoader.load(url);
    return new Coral(camera, model);
}

export class Coral {
    private camera: Camera;
    cube: Cube;
    objModel: ObjLoader; // Store the loaded model
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

    vertexBuffer: GPUBuffer; 
    indexBuffer: GPUBuffer; 
    indexCount: number = 0;

    constructor(camera: Camera, objModel: ObjLoader) {
        this.camera = camera;
        this.cube = new Cube(2);

        // Initialize the model asynchronously
        this.objModel = objModel;

        // interleave VBOS ------------------------------------

        const positions = this.objModel.vertices; // Assuming this is Float32Array of position data
        const normals = this.objModel.normals;
        const uvs = new Float32Array((positions.length / 3) * 2); // Placeholder UVs
        const interleavedData = new Float32Array(positions.length + normals.length + uvs.length);

        // Interleave the data
        // I'm scaling the positions here, I'll fix this later

        for (let i = 0, j = 0; i < positions.length / 3; i++) {
            let scale = hash([positions[i * 3], positions[i * 3 + 2]]) * 20; // don't use this for now
            interleavedData[j++] = positions[i * 3] * 20;     // x
            interleavedData[j++] = positions[i * 3 + 1] * 20; // y
            interleavedData[j++] = positions[i * 3 + 2] * 20; // z
            interleavedData[j++] = normals[i * 3];       // nx (placeholder)
            interleavedData[j++] = normals[i * 3 + 1];   // ny (placeholder)
            interleavedData[j++] = normals[i * 3 + 2];   // nz (placeholder)
            interleavedData[j++] = uvs[i * 2];           // u (placeholder)
            interleavedData[j++] = uvs[i * 2 + 1];       // v (placeholder)
        }

        // ----------------------------------------------------

        this.vertexBuffer = device.createBuffer({
            label: "coral vertex buffer",
            size: interleavedData.byteLength,
            usage: GPUBufferUsage.VERTEX  | GPUBufferUsage.COPY_DST,
            mappedAtCreation: true,
        });
        new Float32Array(this.vertexBuffer.getMappedRange()).set(interleavedData);
        this.vertexBuffer.unmap();
        device.queue.writeBuffer(this.vertexBuffer, 0, interleavedData);

        this.indexBuffer = device.createBuffer({
            label: "coral index buffer",
            size: this.objModel.indices.byteLength,
            usage: GPUBufferUsage.INDEX | GPUBufferUsage.COPY_DST,
            mappedAtCreation: true,
        });
        new Uint32Array(this.indexBuffer.getMappedRange()).set(this.objModel.indices);
        this.indexBuffer.unmap();
        device.queue.writeBuffer(this.indexBuffer, 0, this.objModel.indices);

        this.indexCount = this.objModel.indices.length;

        //----

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
