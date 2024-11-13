# GPU-based Fractalize Mesh Generation

Based on 2024 SIGGRAPH Publication [Into the Portal: Directable Fractal Self-Similarity](https://github.com/alexaschor/IntoThePortal)

File directory breakdown:

**Wait this is all inaccurate right now tell Yuhan to fix it**

### Repo Structure
```
[ ] (GPU_Fractal_Gen)
 ├── * README.md (this file)
 ├── * CMakeLists.txt (FIXME)
 ├──[ ] src
 │   ├── * main.cpp (compiles into bin/run; builds Julia set, adds portals, marches)
 ├──[ ] sdfGen (lightly modified version of github: christopherbatty/SDFGen)
 ├──[ ] fractalGen
 │   ├── * field.h (provides 3D grid/field representations: caching, interpolation, gradients, etc.)
 │   ├── * julia.h (provides Julia set implementation: shape modulus, portals, etc.)
 │   ├── * MC.h (modified version of github: aparis69/MarchingCubeCpp)
 │   ├── * mesh.h (triangle mesh)
 │   ├── * SETTINGS.h (poorly named: contains debugging/timing/typedef macros)
 │   └── * triangle.cpp, .h (functions on triangles)
 ├──[X] data.7z (lzma archive)
 │   ├──[ ] fields (SDFs for example shapes)
 │   │   ├── * bunny100.f3d  (bunny:  100^3)
 │   │   └── * hebe300.f3d   (hebe statue: 300^3)
 │   └──[ ] portals (portal description files)
 |       ├── * bunny_ears.txt  (two portals on bunny ears)
 |       └── * hebe.txt (one portal in hebe's bowl)
 ├──[ ] bin (compiled executables will end up here)
 │   └── prun (symlink to ../projects/main/prun.py)
 └──[ ] lib (external libraries)
     ├──[ ] Eigen (Eigen library version 3.3.9)
     ├──[ ] PerlinNoise (Perlin Noise implementation from github: reputeless/PerlinNoise)
     └──[ ] Quaternion (quaternion math implementations from github: theodorekim/QUIJIBO)

FIXME: 
* all CMAKELISTS

```

