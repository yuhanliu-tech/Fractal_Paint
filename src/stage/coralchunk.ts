import { device } from "../renderer";
import * as coral from "./coral"
import * as shaders from '../shaders/shaders';

export class CoralChunk {
    static readonly maxNumCoral = 5000;
    static readonly numCoral = 250;
    static readonly numFloatsPerCoral = 12;
    static readonly chunkSize = 512;

    coral: coral.Coral;
    coralArray: Float32Array;
    coralSet: GPUBuffer;
    centerBuffer: GPUBuffer;
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

        this.centerBuffer = device.createBuffer({
            label: "Coral chunk center buffer",
            size: 4 * 2,
            usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST
        });
        device.queue.writeBuffer(this.centerBuffer, 0, new Float32Array([center[0], center[1]]));

        this.computeBindGroup = device.createBindGroup({
            label: "place coral compute bind group",
            layout: this.coral.placeCoralComputeBindGroupLayout,
            entries: [
                { binding: 0, resource: { buffer: this.coralSet } },
                { binding: 1, resource: { buffer: this.centerBuffer } }
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

    updateCenter(center: [number, number]) {
        this.center = center;
        device.queue.writeBuffer(this.centerBuffer, 0, new Float32Array([center[0], center[1]]));

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

export class CoralChunkManager {
    coral: coral.Coral;
    chunks: Map<string, CoralChunk> = new Map(); // Stores chunks with keys as "col_row"
    radius: number = 1; // Radius of active chunks (in chunks)

    constructor(coral: coral.Coral) {
        this.coral = coral;
        for (let i = -this.radius; i <= this.radius; i++) {
            for (let j = -this.radius; j <= this.radius; j++) {
                const center = [i * CoralChunk.chunkSize, j * CoralChunk.chunkSize];
                const chunk = new CoralChunk(coral, [center[0], center[1]]);
                this.chunks.set(this.getChunkKey(i, j), chunk);
            }
        }
    }

    // Generate a unique key for a chunk based on its coordinates
    private getChunkKey(x: number, z: number): string {
        return `${x}_${z}`;
    }

    // Get or create a chunk at the given coordinates
    getOrCreateChunk(x: number, z: number): CoralChunk {
        const key = this.getChunkKey(x, z);

        if (!this.chunks.has(key)) {
            const center = [x * CoralChunk.chunkSize, z * CoralChunk.chunkSize];
            const chunk = new CoralChunk(this.coral, [center[0], center[1]]);
            this.chunks.set(key, chunk);
        }

        return this.chunks.get(key)!;
    }

    // Update active chunks based on the camera's position
    updateChunks(cameraPos: [number, number]) {
        const camChunkX = Math.floor(cameraPos[0] / CoralChunk.chunkSize);
        const camChunkZ = Math.floor(cameraPos[1] / CoralChunk.chunkSize);

        // move chunks to maintain radius around player
        for (let dx = -this.radius; dx <= this.radius; dx++) {
            for (let dz = -this.radius; dz <= this.radius; dz++) {
                const chunkX = camChunkX + dx;
                const chunkZ = camChunkZ + dz;
                const key = this.getChunkKey(dx, dz);
                const center = [chunkX * CoralChunk.chunkSize, chunkZ * CoralChunk.chunkSize];
                const chunk = this.chunks.get(key);
                chunk?.updateCenter([center[0], center[1]]);
            }
        }
    }

    draw(passEncoder: GPURenderPassEncoder) {
        for (const key of this.chunks.keys()) {
            const chunk = this.chunks.get(key);
            if (chunk) {
                this.coral.draw(passEncoder, chunk);
            }
        }
    }
}