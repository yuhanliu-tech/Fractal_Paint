import { Camera } from "./camera";
import { FrameStats } from "./framestats";
import { Scene } from "./scene";
import { Coral } from "./coral";
import { SpectralUniforms } from "./spectraldata";

export class Stage {
    scene: Scene;
    coral: Coral;
    spectralUniforms: SpectralUniforms;
    camera: Camera;
    stats: Stats;
    frameStats: FrameStats;

    constructor(scene: Scene, coral: Coral, spectralUniforms: SpectralUniforms, camera: Camera, stats: Stats, frameStats: FrameStats) {
        this.scene = scene;
        this.coral = coral;
        this.spectralUniforms = spectralUniforms;
        this.camera = camera;
        this.stats = stats;
        this.frameStats = frameStats;
    }
}
