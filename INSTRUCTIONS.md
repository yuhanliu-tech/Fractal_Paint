Under the Sea - Instructions
==========================================================


In this project, we render an ocean scene.

## Contents

- `src/` contains all the TypeScript and WGSL code for this project. This contains several subdirectories:
  - `renderers/` defines the different renderers in which you will implement Forward+ and Clustered Deferred shading
  - `shaders/` contains the WGSL files that are interpreted as shader programs at runtime, as well as a `shaders.ts` file which preprocesses the shaders
  - `stage/` includes camera controls, scene loading, and lights, where you will implement the clustering compute shader
- `scenes/` contains the Sponza Atrium model used in the test scene

## Running the code

Follow these steps to install and view the project:
- Clone this repository
- Download and install [Node.js](https://nodejs.org/en/)
- Run `npm install` in the root directory of this project to download and install dependencies
- Run `npm run dev`, which will open the project in your browser
  - The project will automatically reload when you edit any of the files

### Notes:

- Browsers and GPUs
  - This project requires a WebGPU-capable browser. Ensure that you can see the Sponza scene being renderered using this [WebGPU test](https://toji.github.io/webgpu-test/).
    - Google Chrome seems to work best on all platforms.
    - Try [Google Chrome Canary](https://www.google.com/chrome/canary/) for the latest updates.
  - If you have problems running the starter code, use Chrome and make sure you have updated your browser and video drivers.
  - Remember to follow steps from [Project 0](https://github.com/CIS5650-Fall-2024/Project0-Getting-Started/blob/main/INSTRUCTION.md#part-23-project-instructions---webgpu) if needed.
- Ensure that the `Adapter Info -> Description` on https://webgpureport.org/, is your main GPU. Often your low-powered GPU will be selected as default. To make a permanent switch, use your OS's GPU Settings to make the GPU default for your browser.

### GitHub Pages setup

Since this project uses WebGPU, it is easy to deploy it on the web for anyone to see. To set this up, do the following:
- Go to your repository's settings
- Go to the "Pages" tab
- Under "Build and Deployment", set "Source" to "GitHub Actions"

You will also need to go to the "Actions" tab in your repository and enable workflows there.

Once you've done those steps, any new commit to the `main` branch should automatically deploy to the URL `<username>.github.io/<repo_name>`.
