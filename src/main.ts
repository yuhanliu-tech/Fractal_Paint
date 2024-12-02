import Stats from 'stats.js';
import { GUI } from 'dat.gui';

import { initWebGPU, Renderer } from './renderer';
import { NaiveRenderer } from './renderers/naive';
import { ForwardPlusRenderer } from './renderers/forward_plus';
import { ClusteredDeferredRenderer } from './renderers/clustered_deferred';

import { setupLoaders, Scene } from './stage/scene';
import { Coral, makeCoral } from './stage/coral';
import { Camera } from './stage/camera';
import { Stage } from './stage/stage';
import { FrameStats } from './stage/framestats';

await initWebGPU();
setupLoaders();

let scene = new Scene();
await scene.loadGltf('./scenes/sponza/Sponza.gltf');

const camera = new Camera();

// Determine the base path dynamically
const basePath = window.location.hostname === 'localhost'
    ? '' // No base path for local development
    : '/under_the_sea/blob/main'; // Base path for deployment
const coral = await makeCoral(camera, `${basePath}/GLTF/seastar.obj`);

const stats = new Stats();
stats.showPanel(0);
document.body.appendChild(stats.dom);

const frameStats = new FrameStats();

const gui = new GUI();

// Add camera position components to the GUI
const cameraFolder = gui.addFolder("Camera Position"); // Create a folder for clarity
cameraFolder.add(camera.cameraPos, 0).name("X").listen(); // X position
cameraFolder.add(camera.cameraPos, 1).name("Y").listen(); // Y position
cameraFolder.add(camera.cameraPos, 2).name("Z").listen(); // Z position
cameraFolder.open(); // Open the folder by default

gui.add(frameStats, 'numFrames').name("Num Frames").listen();
gui.add(frameStats, 'timeElapsed').name("Time Elapsed").listen();
gui.add(frameStats, 'frameTime').step(0.01).name("ms per frame").listen();

const stage = new Stage(scene, coral, camera, stats, frameStats);

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
