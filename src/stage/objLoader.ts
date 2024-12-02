
export class ObjLoader {
    vertices: Float32Array;
    normals: Float32Array; // Added for normals
    indices: Uint32Array;

    constructor(objData: string) {
        const positions: number[] = [];
        const normals: number[] = []; 
        const indices: number[] = [];
        const lines = objData.split("\n");

        for (const line of lines) {
            const trimmedLine = line.trim();
            if (!trimmedLine || trimmedLine.startsWith("#")) continue;

            const parts = trimmedLine.split(/\s+/);
            if (parts[0] === "v" && parts.length === 4) {
                // Vertex position
                const vertex = parts.slice(1).map(Number);
                if (vertex.some(isNaN)) {
                    console.warn(`Invalid vertex in line: "${line}"`);
                    continue;
                }
                positions.push(...vertex);
            } else if (parts[0] === "vn" && parts.length === 4) {
                // Vertex normal
                const normal = parts.slice(1).map(Number);
                if (normal.some(isNaN)) {
                    console.warn(`Invalid normal in line: "${line}"`);
                    continue;
                }
                normals.push(...normal);
            } else if (parts[0] === "f" && parts.length >= 4) {
                // Face indices
                const face = parts.slice(1).map((part) => {
                    const indexData = part.split("/"); // Handle `v/vt/vn` format
                    return {
                        vertexIndex: parseInt(indexData[0], 10) - 1, // v
                        normalIndex: indexData[2] ? parseInt(indexData[2], 10) - 1 : null, // vn
                    };
                });

                if (face.some(({ vertexIndex }) => vertexIndex === -1)) {
                    console.warn(`Invalid face indices in line: "${line}"`);
                    continue;
                }

                // Triangulate the face
                for (let i = 1; i < face.length - 1; i++) {
                    indices.push(face[0].vertexIndex, face[i].vertexIndex, face[i + 1].vertexIndex);
                }
            }
        }

        if (positions.length === 0 || indices.length === 0) {
            throw new Error("OBJ data parsing failed.");
        }

        this.vertices = new Float32Array(positions);
        this.normals = new Float32Array(normals);
        this.indices = new Uint32Array(indices);
    }

    static async load(url: string): Promise<ObjLoader> {
        try {
            const response = await fetch(url);
            if (!response.ok) throw new Error(`Failed to load OBJ file: ${response.statusText}`);
            const objData = await response.text();

            if (objData.length === 0) {
                throw new Error("File is empty");
            }

            return new ObjLoader(objData);
        } catch (error) {
            console.error("Error loading OBJ file:", error);
            throw error;
        }
    }
}
