import { Camera } from "./camera";
import { FrameStats } from "./framestats";
import { Scene } from "./scene";

export class Stage {
    scene: Scene;
    camera: Camera;
    stats: Stats;
    frameStats : FrameStats;

    constructor(scene: Scene, camera: Camera, stats: Stats, frameStats : FrameStats) {
        this.scene = scene;
        this.camera = camera;
        this.stats = stats;
        this.frameStats = frameStats;
    }
}
