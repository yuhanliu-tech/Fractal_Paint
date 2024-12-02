# Nautilus Engine: Real-Time Ocean Rendering
Joanna Fisch, Nick Liu, Yuhan Liu

Real-time, infinitely explorable ocean, generated by combining some of the latest publications in parallelizable graphics algorithms. 
Implemented in WebGPU. 

[Live Demo](https://yuhanliu-tech.github.io/nautilus-engine/)

## Table of Contents

* 🪸 Coral Reefs: Generation & Placement
* 🌅 Ocean Surface: Tiling & Blending
* 🌊 Underwater Spectral Rendering: Multi and Single Scattering
* 🪼 Additional Features

## 🪸 Coral Reefs: Generation & placement

### Fractalized Mesh Generation

Implementation of 2024 SIGGRAPH paper [Into the portal: Directable Fractal Self-Similarity](https://dl.acm.org/doi/10.1145/3641519.3657466) by Alexa Schor and Theodore Kim

<img src="img/fractal_flow.png" width="500"/> 



### Coral Reef Instanced Rendering

<img src="img/corals.png" width="500"/> 

(FIXME)

## 🌅 Ocean Surface: Tiling & Blending

Implementation of 2024 High Performance Graphics paper [Fast Orientable Aperiodic Ocean Synthesis Using Tiling & Blending](http://arnaud-schoentgen.com/publication/2024_orientable_ocean/2024_orientable_ocean.pdf)

We implemented the above paper's technique for creating a fast and believable ocean surface by combining tiling and blending methods with a foundational sinusoidal ocean texture. 

<img src="img/hextiling.png" width="500"/> 

We begin with a simple, periodic sinusoidal texture, called our "exemplar texture", created by overlapping sine waves to create a simple ocean (left image). The core idea is to efficiently synthesize a realistic ocean by overlapping multiple texture tiles, specifically utilizing three regular hexagonal tilings (middle image). In this method, each texel (texture pixel) is influenced by multiple tiles, with blending weights peaking at the center of each tile and diminishing towards the edges. This approach preserves the spatial mean and variance of the exemplar texture, resulting in a seamless and non-repetitive ocean surface (right image).

This technique is implemented in a WebGPU compute shader, resulting in an ocean texture that preserves the physical characteristics of waves while concealing artificial-looking periodicity. Below is a GIF showing our results. 

<img src="img/ocean.gif" width="500"/> 

## 🌊 Underwater Spectral Rendering: Scattering

(FIXME)

### Ocean Data-Informed Multiple Scattering

(FIXME)

### Lighting Effects via Single Scattering

(FIXME)

## 🪼 Additional Features 

### Raymarched Jellyfish

(FIXME: Jellyfish img)

We created a fragment shader that utilizes ray marching to render jellyfish NPCs. The shader uses ray marching to traverse the underwater space, calculating distances to shapes defined by signed distance functions. Procedural noise functions drive animated effects like pulsation, creating a sense of movement. Volumetric techniques simulate translucent effects, creating the appearance of light scattering within the jellyfish, while custom lighting calculations enhance realism with reflections, refractions, and ambient light. The shader efficiently renders multiple jellyfish instances through spatial repetition functions and optimizes performance by skipping empty spaces during ray marching.

## Sources

Base Code: https://github.com/CIS5650-Fall-2024/Project4-WebGPU-Forward-Plus-and-Clustered-Deferred

OBJ Loading: https://carmencincotti.com/2022-06-06/load-obj-files-into-webgpu/

Jellyfish Shader: https://www.shadertoy.com/view/McGcWW


