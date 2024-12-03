export class Mesh {
    faces: faceGroup[];
    facesIndex: number[];
    vertices: Vertex[];

    constructor() {
        this.faces = [];
        this.vertices = [];
        this.facesIndex = [];
    }
}

export class faceGroup {
    indices: number[];
    constructor(indices: number[]) {
        this.indices = indices;
    }
}

export class Vertex {
    position: number[];
    normal: number[];
    uv: number[];
    index: number;

    constructor(position: number[], normal: number[], uv: number[], index: number) {
        this.position = position;
        this.normal = normal;
        this.uv = uv;
        this.index = index;
    }
}
export class ObjLoader {
    mesh: Mesh;
    vertexCount: number = 0; // Added for vertex count

    constructor(objData: string) {
        this.mesh = new Mesh();
        const positions: number[] = [];
        const textureCoords: number[] = [];
        const normals: number[] = [];
        const indices: number[] = [];
        const faceGroups: number[][] = [];
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
            } else if (parts[0] === "vt" && parts.length === 3) {
                // Vertex texture
                const texture = parts.slice(1).map(Number);
                if (texture.some(isNaN)) {
                    console.warn(`Invalid texture in line: "${line}"`);
                    continue;
                }
                textureCoords.push(...texture);
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
                        textureIndex: indexData[1] ? parseInt(indexData[1], 10) - 1 : null, // vt
                        normalIndex: indexData[2] ? parseInt(indexData[2], 10) - 1 : null, // vn
                    };
                });

                if (face.some(({ vertexIndex }) => vertexIndex === -1)) {
                    console.warn(`Invalid face indices in line: "${line}"`);
                    continue;
                }

                // nontriangulated face
                const faceIndices: number[] = [];
                for (let i = 0; i < face.length; i++) {
                    faceIndices.push(face[i].vertexIndex);
                    faceIndices.push(face[i].textureIndex ?? 0);
                    faceIndices.push(face[i].normalIndex ?? 0);
                    this.vertexCount++;
                }
                faceGroups.push(faceIndices);

                // Triangulate the face
                for (let i = 1; i < face.length - 1; i++) {
                    indices.push(face[0].vertexIndex, face[i].vertexIndex, face[i + 1].vertexIndex);
                }
            }
        }

        if (positions.length === 0 || indices.length === 0) {
            throw new Error("OBJ data parsing failed.");
        }

        this.populateMesh(positions, textureCoords, normals, faceGroups);
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

    populateMesh(positions: number[], textureCoords: number[], normals: number[], faceGroups: number[][]) {
        let index = 0;
        faceGroups.forEach((faceIndices) => {
            const face = [];
            for (let i = 0; i < faceIndices.length; i += 3) {
                const positionIndex = faceIndices[i] * 3;
                const normalIndex = faceIndices[i + 2] * 3;
                const uvIndex = faceIndices[i + 1] * 2;

                const position = [positions[positionIndex], positions[positionIndex + 1], positions[positionIndex + 2]];
                const normal = [normals[normalIndex], normals[normalIndex + 1], normals[normalIndex + 2]];
                const uv = [textureCoords[uvIndex], textureCoords[uvIndex + 1]];

                this.mesh.vertices.push(new Vertex(position, normal, uv, index));
                face.push(index);
                index++;
            }
            this.mesh.faces.push(new faceGroup(face));
        });

        this.mesh.faces.forEach((face) => {
            //triangulate
            for (let i = 1; i < face.indices.length - 1; i++) {
                this.mesh.facesIndex.push(face.indices[0]);
                this.mesh.facesIndex.push(face.indices[i]);
                this.mesh.facesIndex.push(face.indices[i + 1]);
            }
        });
    }
}
