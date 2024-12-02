import { Camera } from "./camera";
import { FrameStats } from "./framestats";
import { Scene } from "./scene";
import { SpectralUniforms } from "./spectraldata";

export class Stage {
    scene: Scene;
    spectralUniforms: SpectralUniforms;
    camera: Camera;
    stats: Stats;
    frameStats : FrameStats;

    constructor(scene: Scene, spectralUniforms: SpectralUniforms, camera: Camera, stats: Stats, frameStats : FrameStats) {
        this.scene = scene;
        this.spectralUniforms = spectralUniforms;
        this.camera = camera;
        this.stats = stats;
        this.frameStats = frameStats;
    }
}
