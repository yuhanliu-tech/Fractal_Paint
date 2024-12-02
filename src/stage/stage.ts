import { Camera } from "./camera";
import { FrameStats } from "./framestats";
import { Scene } from "./scene";
import { Coral } from "./coral";

export class Stage {
    scene: Scene;
    coral: Coral;
    camera: Camera;
    stats: Stats;
    frameStats: FrameStats;

    constructor(scene: Scene, coral: Coral, camera: Camera, stats: Stats, frameStats: FrameStats) {
        this.scene = scene;
        this.coral = coral;
        this.camera = camera;
        this.stats = stats;
        this.frameStats = frameStats;
    }
}
