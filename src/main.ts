import Stats from 'stats.js';
import { GUI } from 'dat.gui';

import { initWebGPU, Renderer } from './renderer';
import { NaiveRenderer } from './renderers/naive';
import { ForwardPlusRenderer } from './renderers/forward_plus';
import { ClusteredDeferredRenderer } from './renderers/clustered_deferred';

import { setupLoaders, Scene } from './stage/scene';
import { Camera } from './stage/camera';
import { Stage } from './stage/stage';
import { FrameStats } from './stage/framestats';

await initWebGPU();
setupLoaders();

// Load GLTF
let scene = new Scene();
await scene.loadGltf('./scenes/sponza/Sponza.gltf');
//await scene.loadGltf('./GLTF/avo/Avocado.gltf');
//await scene.loadGltf('./GLTF/star/star.gltf');

const camera = new Camera();

const stats = new Stats();
stats.showPanel(0);
document.body.appendChild(stats.dom);

const frameStats = new FrameStats();

const gui = new GUI();
gui.add(frameStats, 'numFrames').name("Num Frames").listen();
gui.add(frameStats, 'timeElapsed').name("Time Elapsed").listen();
gui.add(frameStats, 'frameTime').step(0.01).name("ms per frame").listen();

const stage = new Stage(scene, camera, stats, frameStats);

var renderer: Renderer | undefined;

function setRenderer(mode: string) {
    renderer?.stop();
    switch (mode) {
        case renderModes.naive:
            renderer = new NaiveRenderer(stage);
            break;
        case renderModes.forwardPlus:
            renderer = new ForwardPlusRenderer(stage);
            break;
        case renderModes.clusteredDeferred:
            renderer = new ClusteredDeferredRenderer(stage);
            break;
    }
}

const renderModes = { naive: 'naive', forwardPlus: 'forward+', clusteredDeferred: 'clustered deferred' };
let renderModeController = gui.add({ mode: renderModes.naive }, 'mode', renderModes);
renderModeController.onChange(setRenderer);

setRenderer(renderModeController.getValue());
