import { device } from "../renderer";
import * as shaders from '../shaders/shaders';
import { ObjLoader } from "./objLoader";
import { CoralChunk } from "./coralchunk";

export async function makeCoral(urls: string[]) {
    const models = await Promise.all(urls.map((url) => ObjLoader.load(url)));
    return new Coral(models);
}

export class Coral {
    coralTypes: {
        vertexBuffer: GPUBuffer;
        indexBuffer: GPUBuffer;
        indexCount: number;
        instanceCount: number;
    }[] = []; // Array to store different coral types

    camPosUniformBuffer: GPUBuffer;

    placeCoralComputeBindGroupLayout: GPUBindGroupLayout;
    placeCoralComputePipeline: GPUComputePipeline;

    renderBindGroupLayout: GPUBindGroupLayout;

    constructor(objModels: ObjLoader[]) {
        // Initialize coral types
        this.coralTypes = objModels.map((objModel) => {
            // interleave VBOS ------------------------------------
            const interleavedData = new Float32Array(objModel.mesh.vertices.length * 8);

            // Interleave the data
            let index = 0;
            objModel.mesh.vertices.forEach((vertex) => {
                const position = vertex.position;
                const normal = vertex.normal;
                const uv = vertex.uv;

                interleavedData[index++] = position[0];
                interleavedData[index++] = position[1];
                interleavedData[index++] = position[2];
                interleavedData[index++] = normal[0];
                interleavedData[index++] = normal[1];
                interleavedData[index++] = normal[2];
                interleavedData[index++] = uv[0];
                interleavedData[index++] = uv[1];
            });

            const indices = new Uint32Array(objModel.mesh.facesIndex);

            // ----------------------------------------------------

            const vertexBuffer = device.createBuffer({
                label: "coral vertex buffer",
                size: interleavedData.byteLength,
                usage: GPUBufferUsage.VERTEX | GPUBufferUsage.COPY_DST,
                mappedAtCreation: true,
            });
            new Float32Array(vertexBuffer.getMappedRange()).set(interleavedData);
            vertexBuffer.unmap();
            device.queue.writeBuffer(vertexBuffer, 0, interleavedData);

            const indexBuffer = device.createBuffer({
                label: "coral index buffer",
                size: indices.byteLength,
                usage: GPUBufferUsage.INDEX | GPUBufferUsage.COPY_DST,
                mappedAtCreation: true,
            });
            new Uint32Array(indexBuffer.getMappedRange()).set(indices);
            indexBuffer.unmap();
            device.queue.writeBuffer(indexBuffer, 0, indices);

            return {
                vertexBuffer,
                indexBuffer,
                indexCount: indices.length,
                instanceCount: 10, // Default; can adjust for instanced rendering
            };
        });

        //----

        // this.coralSetStorageBuffer = device.createBuffer({
        //     label: "coral",
        //     size: 16 + this.coralArray.byteLength, // 16 for numCoral + padding
        //     usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_DST
        // });
        // this.updateCoralSetUniformNumCoral();

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

        this.renderBindGroupLayout = device.createBindGroupLayout({
            label: "scene uniforms bind group layout",
            entries: [
                { // coralSet
                    binding: 0,
                    visibility: GPUShaderStage.VERTEX,
                    buffer: { type: "read-only-storage" }
                }
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

    // updateCoralSetUniformNumCoral() {
    //     device.queue.writeBuffer(this.coralSetStorageBuffer, 0, new Uint32Array([this.numCoral]));
    // }

    draw(passEncoder: GPURenderPassEncoder, coralChunk: CoralChunk) {
        let instanceOffset = 0; // Start offset for the first coral type
        passEncoder.setBindGroup(2, coralChunk.renderBindGroup);

        for (const coralType of this.coralTypes) {
            if (!coralType.vertexBuffer || !coralType.indexBuffer) continue;

            // Bind vertex and index buffers
            passEncoder.setVertexBuffer(0, coralType.vertexBuffer);
            passEncoder.setIndexBuffer(coralType.indexBuffer, "uint32");

            // Draw with an offset for this coral type
            passEncoder.drawIndexed(coralType.indexCount, coralType.instanceCount, 0, 0, instanceOffset);

            // Update the offset for the next coral type
            instanceOffset += coralType.instanceCount;
        }
    }

    // onFrame(x: number, y: number) {
    //     device.queue.writeBuffer(this.camPosUniformBuffer, 0, new Float32Array([x, y]));
    //     const encoder = device.createCommandEncoder();
    //     const computePass = encoder.beginComputePass();
    //     computePass.setPipeline(this.placeCoralComputePipeline);
    //     computePass.setBindGroup(0, this.placeCoralComputeBindGroup);

    //     const workgroupCount = Math.ceil(this.numCoral / shaders.constants.moveLightsWorkgroupSize);
    //     computePass.dispatchWorkgroups(workgroupCount);

    //     computePass.end();
    //     device.queue.submit([encoder.finish()]);
    // }
}
