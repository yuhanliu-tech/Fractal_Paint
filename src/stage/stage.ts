import { Camera } from "./camera";
import { FrameStats } from "./framestats";
import { Scene } from "./scene";
import { Coral } from "./coral";
import { SpectralUniforms } from "./spectraldata";
import { CoralChunk } from "./coralchunk";

export class Stage {
    scene: Scene;
    coral: Coral;
    coralChunk: CoralChunk;
    spectralUniforms: SpectralUniforms;
    camera: Camera;
    stats: Stats;
    frameStats: FrameStats;

    constructor(scene: Scene, coral: Coral, coralChunk: CoralChunk, spectralUniforms: SpectralUniforms, camera: Camera, stats: Stats, frameStats: FrameStats) {
        this.scene = scene;
        this.coral = coral;
        this.coralChunk = coralChunk;
        this.spectralUniforms = spectralUniforms;
        this.camera = camera;
        this.stats = stats;
        this.frameStats = frameStats;
    }
}
