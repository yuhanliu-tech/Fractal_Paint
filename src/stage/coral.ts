import { vec3 } from "wgpu-matrix";
import { device } from "../renderer";

import * as shaders from '../shaders/shaders';
import { Camera } from "./camera";
import { Cube } from "./cube";

export class Coral {
    private camera: Camera;
    cube: Cube;

    numLights = 500;
    static readonly maxNumCoral = 5000;
    static readonly numFloatsPerCoral = 8; // vec3f is aligned at 16 byte boundaries

    static readonly lightIntensity = 0.1;

    coralArray = new Float32Array(Coral.maxNumCoral * Coral.numFloatsPerCoral);
    coralSetStorageBuffer: GPUBuffer;

    camPosUniformBuffer: GPUBuffer;

    placeCoralComputeBindGroupLayout: GPUBindGroupLayout;
    placeCoralComputeBindGroup: GPUBindGroup;
    placeCoralComputePipeline: GPUComputePipeline;

    constructor(camera: Camera) {
        this.camera = camera;
        this.cube = new Cube(1);

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
                { // coralSet
                    binding: 0,
                    visibility: GPUShaderStage.COMPUTE,
                    buffer: { type: "storage" }
                },
                { // camera position
                    binding: 1,
                    visibility: GPUShaderStage.COMPUTE,
                    buffer: { type: "uniform" }
                }
            ]
        });

        this.placeCoralComputeBindGroup = device.createBindGroup({
            label: "place coral compute bind group",
            layout: this.placeCoralComputeBindGroupLayout,
            entries: [
                {
                    binding: 0,
                    resource: { buffer: this.coralSetStorageBuffer }
                },
                {
                    binding: 1,
                    resource: { buffer: this.camPosUniformBuffer }
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

    updateCoralSetUniformNumCoral() {
        device.queue.writeBuffer(this.coralSetStorageBuffer, 0, new Uint32Array([this.numLights]));
    }

    // CHECKITOUT: this is where the coral placement compute shader is dispatched from the host
    onFrame(x: number, y: number) {
        device.queue.writeBuffer(this.camPosUniformBuffer, 0, new Float32Array([x, y]));

        // not using same encoder as render pass so this doesn't interfere with measuring actual rendering performance
        const encoder = device.createCommandEncoder();

        const computePass = encoder.beginComputePass();
        computePass.setPipeline(this.placeCoralComputePipeline);

        computePass.setBindGroup(0, this.placeCoralComputeBindGroup);

        const workgroupCount = Math.ceil(this.numLights / shaders.constants.moveLightsWorkgroupSize);
        computePass.dispatchWorkgroups(workgroupCount);

        computePass.end();

        device.queue.submit([encoder.finish()]);
    }
}