import { device } from "../renderer";

export class Cube {
    vertexBuffer: GPUBuffer;
    indexBuffer: GPUBuffer;
    instanceBuffer: GPUBuffer;

    vertexCount: number;
    indexCount: number;
    instanceCount: number;

    constructor(instanceCount: number) {
        // Define cube vertex positions
        // Define interleaved vertex data (position, normal, UV)
        const vertices = new Float32Array([
            // Front face
            -1, -1, 1, 0, 0, 1, 0, 0,   // Bottom-left
            1, -1, 1, 0, 0, 1, 1, 0,   // Bottom-right
            1, 1, 1, 0, 0, 1, 1, 1,   // Top-right
            -1, 1, 1, 0, 0, 1, 0, 1,   // Top-left

            // Back face
            -1, -1, -1, 0, 0, -1, 1, 0,
            1, -1, -1, 0, 0, -1, 0, 0,
            1, 1, -1, 0, 0, -1, 0, 1,
            -1, 1, -1, 0, 0, -1, 1, 1,

            // Top face
            -1, 1, -1, 0, 1, 0, 0, 0,
            1, 1, -1, 0, 1, 0, 1, 0,
            1, 1, 1, 0, 1, 0, 1, 1,
            -1, 1, 1, 0, 1, 0, 0, 1,

            // Bottom face
            -1, -1, -1, 0, -1, 0, 1, 1,
            1, -1, -1, 0, -1, 0, 0, 1,
            1, -1, 1, 0, -1, 0, 0, 0,
            -1, -1, 1, 0, -1, 0, 1, 0,

            // Right face
            1, -1, -1, 1, 0, 0, 0, 0,
            1, 1, -1, 1, 0, 0, 0, 1,
            1, 1, 1, 1, 0, 0, 1, 1,
            1, -1, 1, 1, 0, 0, 1, 0,

            // Left face
            -1, -1, -1, -1, 0, 0, 1, 0,
            -1, 1, -1, -1, 0, 0, 1, 1,
            -1, 1, 1, -1, 0, 0, 0, 1,
            -1, -1, 1, -1, 0, 0, 0, 0,
        ]);

        // Define cube indices
        const indices = new Uint16Array([
            0, 1, 2, 2, 3, 0,    // Front face
            4, 5, 6, 6, 7, 4,    // Back face
            8, 9, 10, 10, 11, 8,    // Top face
            12, 13, 14, 14, 15, 12,    // Bottom face
            16, 17, 18, 18, 19, 16,    // Right face
            20, 21, 22, 22, 23, 20,    // Left face
        ]);

        this.vertexCount = vertices.length / 8; // 3 pos + 3 nor + 2 uv
        this.indexCount = indices.length;
        this.instanceCount = instanceCount;

        // Create GPU buffers
        // Create the vertex buffer
        this.vertexBuffer = device.createBuffer({
            size: vertices.byteLength,
            usage: GPUBufferUsage.VERTEX | GPUBufferUsage.COPY_DST,
            mappedAtCreation: true,
        });
        new Float32Array(this.vertexBuffer.getMappedRange()).set(vertices);
        this.vertexBuffer.unmap();

        // Create the index buffer
        this.indexBuffer = device.createBuffer({
            size: indices.byteLength,
            usage: GPUBufferUsage.INDEX | GPUBufferUsage.COPY_DST,
            mappedAtCreation: true,
        });
        new Uint16Array(this.indexBuffer.getMappedRange()).set(indices);
        this.indexBuffer.unmap();

        // Create the instance buffer
        this.instanceBuffer = device.createBuffer({
            size: instanceCount * 16, // Each instance has vec3 position + padding
            usage: GPUBufferUsage.VERTEX | GPUBufferUsage.STORAGE,
        });
    }
}
