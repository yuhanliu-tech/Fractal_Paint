export class ObjLoader {
    vertices: Float32Array;
    indices: Uint32Array;

    constructor(objData: string) {
        const positions: number[] = [];
        const indices: number[] = [];
        const lines = objData.split("\n");

        for (const line of lines) {
            const trimmedLine = line.trim();

            // Skip comments and empty lines
            if (!trimmedLine || trimmedLine.startsWith("#")) {
                continue;
            }

            const parts = trimmedLine.split(/\s+/);

            if (parts[0] === "v") {
                // Parse vertex positions
                if (parts.length !== 4) {
                    console.warn(`Invalid vertex definition: "${line}"`);
                    continue;
                }
                const vertex = parts.slice(1).map(Number);
                if (vertex.some(v => isNaN(v))) {
                    console.warn(`Invalid vertex values in line: "${line}"`);
                    continue;
                }
                positions.push(...vertex);

            } else if (parts[0] === "f") {
                // Parse face indices
                if (parts.length < 4) {
                    console.warn(`Invalid face definition: "${line}"`);
                    continue;
                }

                const face = parts.slice(1).map(index => {
                    const vertexIndex = parseInt(index.split("/")[0], 10) - 1; // OBJ indices are 1-based
                    if (isNaN(vertexIndex) || vertexIndex < 0 || vertexIndex >= positions.length / 3) {
                        console.warn(`Invalid vertex index in face: "${line}"`);
                        return -1;
                    }
                    return vertexIndex;
                });

                if (face.includes(-1)) {
                    console.warn(`Skipping face with invalid indices: "${line}"`);
                    continue;
                }

                if (face.length === 3) {
                    indices.push(...face);
                } else if (face.length === 4) {
                    // Handle quads (triangulate)
                    indices.push(face[0], face[1], face[2], face[0], face[2], face[3]);
                } else {
                    console.warn(`Unsupported face with more than 4 vertices: "${line}"`);
                }
            }
        }

        if (positions.length === 0) {
            throw new Error("No valid vertex positions found in OBJ data.");
        }

        if (indices.length === 0) {
            throw new Error("No valid face definitions found in OBJ data.");
        }

        this.vertices = new Float32Array(positions);
        this.indices = new Uint32Array(indices);

        console.log("Parsed vertices:", this.vertices);
        console.log("Parsed indices:", this.indices);
    }

    static async load(url: string): Promise<ObjLoader> {
        try {
            // Fetch the OBJ file
            const response = await fetch(url);
            if (!response.ok) {
                throw new Error(`Failed to load OBJ file: ${response.statusText}`);
            }

            // Read the file content as text
            const objData = await response.text();

            // Parse the file content and return an ObjLoader instance
            return new ObjLoader(objData);
        } catch (error) {
            console.error("Error loading OBJ file:", error);
            throw error;
        }
    }
}