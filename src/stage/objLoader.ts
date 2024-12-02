export class ObjLoader {
    vertices: Float32Array;
    indices: Uint32Array;

    constructor(objData: string) {
        const positions: number[] = [];
        const indices: number[] = [];
        const lines = objData.split("\n");

        for (const line of lines) {
            const trimmedLine = line.trim();
            if (!trimmedLine || trimmedLine.startsWith("#")) continue;

            const parts = trimmedLine.split(/\s+/);
            if (parts[0] === "v" && parts.length === 4) {
                const vertex = parts.slice(1).map(Number);
                if (vertex.some(isNaN)) {
                    console.warn(`Invalid vertex in line: "${line}"`);
                    continue;
                }
                positions.push(...vertex);
            } else if (parts[0] === "f" && parts.length >= 4) {
                const face = parts.slice(1).map(index => parseInt(index.split("/")[0], 10) - 1);
                if (face.includes(-1)) {
                    console.warn(`Invalid face indices in line: "${line}"`);
                    continue;
                }
                indices.push(face[0], face[1], face[2]);
                if (face.length === 4) {
                    indices.push(face[0], face[2], face[3]);
                }
            }
        }

        if (positions.length === 0 || indices.length === 0) {
            throw new Error("OBJ data parsing failed.");
        }

        this.vertices = new Float32Array(positions);
        this.indices = new Uint32Array(indices);
    }

    static async load(url: string): Promise<ObjLoader> {
        try {
            const response = await fetch(url);
            if (!response.ok) throw new Error(`Failed to load OBJ file: ${response.statusText}`);
            const objData = await response.text();

            if (objData.length == 0) {
                throw new Error('File is empty');
            }

            return new ObjLoader(objData);
        } catch (error) {
            console.error("Error loading OBJ file:", error);
            throw error;
        }
    }
}
