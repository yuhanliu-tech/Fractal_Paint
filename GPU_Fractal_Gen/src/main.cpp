#include <iostream>
#include <cstdio>
#include <stdio.h>

#include <sys/stat.h>

#include "fractalGen/SETTINGS.h"

#include "fractalGen/MC.h"
#include "fractalGen/mesh.h"
#include "fractalGen/field.h"
#include "fractalGen/julia.h"

using namespace std;

int main(int argc, char *argv[]) {
    if(argc != 9) {
        cout << "USAGE: " << endl;
        cout << "To create a self-similar Julia set from a distance field and portal description file:" << endl;
        cout << " " << argv[0] << " <SDF *.f3d> <portals *.txt> <versor octaves> <versor scale> <output resolution> <alpha> <beta> <output *.obj>" << endl << endl;
        //                            argv[1]        argv[2]        argv[3]          argv[4]        argv[5]        argv[6] argv[7]     argv[8]    
        exit(0);
    }

    // Read distfield
    ArrayGrid3D distFieldCoarse(argv[1]);
    PRINTF("Got distance field with res %dx%dx%d\n", distFieldCoarse.xRes, distFieldCoarse.yRes, distFieldCoarse.zRes);

    // Create interpolation grid (smooth it out) --------------------------------------------------------------------------------------

    // description: 
    // create interpolation grid smooths distance field, involves sampling & calculating new values for dense 3D grid
    
    // FIXME: CUDA parallelization

    InterpolationGrid distField(&distFieldCoarse, InterpolationGrid::LINEAR);
    distField.mapBox.setCenter(VEC3F(0,0,0));

    PRINT("NOTE: Setting simulation bounds to hard-coded values (not from distance field)");
    distField.mapBox.min() = VEC3F(-0.5, -0.5, -0.5);
    distField.mapBox.max() = VEC3F(0.5, 0.5, 0.5);

    // ---------------------------------------------------------------------------------------------------------------------------------

    // Now we actually compute the Julia set
    Real alpha = atof(argv[6]);
    Real beta = atof(argv[7]);

    int res = atoi(argv[5]);

    // Offset roots and distance field to reproduce QUIJIBO dissolution
    // effect - this is optional, and for all our results in the paper was zero.
    VEC3F offset3D(0.f, 0.f, 0.f);
    distField.mapBox.setCenter(offset3D);

    // --------------------------------------------------------------------------------------------------------------------------------

    // Set up simulation bounds, taking octree zoom into account
    AABB boundsBox(distField.mapBox.min(), distField.mapBox.max() + VEC3F(0.25, 0.25, 0.25));

    // -------------------------------------------------------------------------------------------------------------------------

    int versor_octaves = atoi(argv[3]);
    Real versor_scale   = atof(argv[4]);

    PRINTF("vo=%s; vs=%s\n",argv[3], argv[4]);
    PRINTF("Computing Julia set with resolution %d, a=%f, b=%f, v. octaves=%d, v. scale=%f, offset=(%f, %f, %f)\n", res, alpha, beta, versor_octaves, versor_scale);

    // Versor field generation using noise ---------------------------------------------------------------------------------
    
    // description: 
    // noise-based versor field calculation, each voxel can independently sample from noise field in kernels
    
    // FIXME: CUDA parallelization

    NoiseVersor  versor(versor_octaves, versor_scale);

    ShapeModulus modulus(&distField, alpha, beta);

    VersorModulusR3Map vm(&versor, &modulus);
    R3JuliaSet         mask_j(&vm, 4, 10);

    vector<VEC3F> portalCenters;
    vector<AngleAxis<Real>> portalRotations;

    // READ PORTAL FILE
    Real portalRadius;
    Real portalScale;
    VEC3F portalLocation;
    AngleAxis<Real> portalRotation;

    ifstream portalFile(argv[2]);
    if (portalFile.is_open()) {
        string line;
        while (getline(portalFile, line)) {
            if (line.length()) {
                string key = line.substr(0, line.find(":"));
                string value = line.substr(line.find(":")+1, line.length()-1);
                transform(key.begin(), key.end(), key.begin(), ::tolower);
                transform(value.begin(), value.end(), value.begin(), ::tolower);
                if (key == "portals radius") {
                    sscanf(value.c_str(), " %lf", &portalRadius);
                } else if (key == "portals scale") {
                    sscanf(value.c_str(), " %lf", &portalScale);
                } else if (key == "portal location") {
                    Real x,y,z;
                    sscanf(value.c_str(), " %lf %lf %lf", &x, &y, &z);
                    portalLocation = VEC3F(x,y,z);
                } else if (key == "portal rotation") {
                    Real t,x,y,z;
                    sscanf(value.c_str(), " %lf %lf %lf %lf", &t, &x, &y, &z);
                    portalRotation = AngleAxis<Real>(t, VEC3F(x,y,z));

                    portalCenters.push_back(portalLocation);
                    portalRotations.push_back(portalRotation);
                }
            }
        }
    }
    portalFile.close();

    PortalMap  pm(&vm, portalCenters, portalRotations, portalRadius, portalScale, &mask_j);
    R3JuliaSet julia(&pm, 7, 10);

    VirtualGrid3DLimitedCache vg(res, res, res, boundsBox.min(), boundsBox.max(), &julia);

    // marching cubes to generate mesh -------------------------------------------------------------------------------

    // description: evaluate each voxel in 3D grid to determine surface intersections

    // FIXME: CUDA parallelization

    std::cout << "marching cubes" << std::endl;
    Mesh m;
    MC::march_cubes(&vg, m, true);
    std::cout << "marched cubes" << std::endl;

    // Transforming mesh to grid field coords ------------------------------------------------------------------------

    // FIXME: CUDA parallelization?

    // Currently march_cubes doesn't take the grid's mapBox into account; all vertices are
    // placed in [ (0, xRes), (0, yRes), (0, zRes) ] space. 
    for (uint i = 0; i < m.vertices.size(); ++i) {
        VEC3F v = m.vertices[i];
        m.vertices[i] = vg.gridToFieldCoords(v);
    }

    std::cout << "grid2field complete" << std::endl;

    m.writeOBJ(argv[8]);

    return 0;
}

