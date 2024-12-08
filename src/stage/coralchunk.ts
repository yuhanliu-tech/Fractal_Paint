import { device } from "../renderer";
import * as coral from "./coral"
import * as shaders from '../shaders/shaders';

export class CoralChunk {
    static readonly maxNumCoral = 5000;
    static readonly numCoral = 250;
    static readonly numFloatsPerCoral = 12;
    static readonly chunkSize = 1024;

    coral: coral.Coral;
    coralArray: Float32Array;
    coralSet: GPUBuffer;
    computeBindGroup: GPUBindGroup;
    renderBindGroup: GPUBindGroup;
    // layout: GPUBindGroupLayout;
    center: [number, number];

    constructor(coral: coral.Coral, center: [number, number]) {
        this.coral = coral;
        this.center = center;

        this.coralArray = new Float32Array(CoralChunk.maxNumCoral * CoralChunk.numFloatsPerCoral);

        this.coralSet = device.createBuffer({
            label: "coral",
            size: 16 + this.coralArray.byteLength, // 16 for numCoral + padding
            usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_DST
        });
        // FIXME: Don't hardcode number of coral
        device.queue.writeBuffer(this.coralSet, 0, new Uint32Array([CoralChunk.maxNumCoral]));

        let centerBuffer = device.createBuffer({
            label: "Coral chunk center buffer",
            size: 4 * 2,
            usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST
        });
        device.queue.writeBuffer(centerBuffer, 0, new Float32Array([center[0], center[1]]));

        this.computeBindGroup = device.createBindGroup({
            label: "place coral compute bind group",
            layout: this.coral.placeCoralComputeBindGroupLayout,
            entries: [
                { binding: 0, resource: { buffer: this.coralSet } },
                { binding: 1, resource: { buffer: centerBuffer } }
            ]
        });

        this.renderBindGroup = device.createBindGroup({
            label: "coral render bind group",
            layout: this.coral.renderBindGroupLayout,
            entries: [
                { binding: 0, resource: { buffer: this.coralSet } },
            ]
        });

        const encoder = device.createCommandEncoder();
        const computePass = encoder.beginComputePass();
        computePass.setPipeline(this.coral.placeCoralComputePipeline);
        computePass.setBindGroup(0, this.computeBindGroup);

        // FIXME: Don't hardcode number of coral
        const workgroupCount = Math.ceil(CoralChunk.numCoral / shaders.constants.moveLightsWorkgroupSize);
        computePass.dispatchWorkgroups(workgroupCount);

        computePass.end();
        device.queue.submit([encoder.finish()]);
    }
}