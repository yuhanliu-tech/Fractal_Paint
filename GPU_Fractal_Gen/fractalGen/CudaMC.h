#pragma once

// CUDA includes

#include <cuda.h>
#include <cuda_runtime.h>

#include <stdio.h>
#include <thrust/sort.h>
#include <thrust/execution_policy.h>
#include <thrust/random.h>
#include <thrust/device_vector.h>
#include <thrust/host_vector.h>
#include <device_launch_parameters.h>
#include <cmath>
#include <vector>
#include <mutex>

// Marching Cube includes
#include "SETTINGS.h"
#include "mesh.h"
#include "field.h"


void checkCUDAErrorFn(const char* msg, const char* file = NULL, int line = -1);


// inline computations ---------------------------------------------------------------------

inline Real cuda_internalLength2(const VEC3F& v)
{
    return v.x() * v.x() + v.y() * v.y() + v.z() * v.z();
}
inline Real cuda_internalLength(const VEC3F& v)
{
    return std::sqrt(cuda_internalLength2(v));
}
inline VEC3F cuda_internalNormalize(const VEC3F& v)
{
    Real vv = cuda_internalLength(v);
    return VEC3F(v.x() / vv, v.y() / vv, v.z() / vv);
}
inline VEC3F cuda_internalCross(const VEC3F& v1, const VEC3F& v2)
{
    return VEC3F(v1.y() * v2.z() - v1.z() * v2.y(), v1.z() * v2.x() - v1.x() * v2.z(), v1.x() * v2.y() - v1.y() * v2.x());
}
inline VEC3F operator-(const VEC3F& l, const VEC3F r)
{
    return VEC3F(l.x() - r.x(), l.y() - r.y(), l.z() - r.z());
}
    
inline uint cuda_internalToIndex1D(uint i, uint j, uint k, const VEC3I& size)
{
    return (k * size.y() + j) * size.x() + i;
}

inline uint cuda_internalToIndex1DSlab(uint i, uint j, uint k, const VEC3I& size)
{
    return size.x() * size.y() * (k % 2) + j * size.x() + i;
}

// brief: Computes and acumulates the geometric normal of triangle formed by vertices (a, b, c).
// param mesh: the mesh
// param a, b, c: vertex indices
inline void cuda_internalAccumulateNormal(Mesh& mesh, uint a, uint b, uint c)
{
    VEC3F& va = mesh.vertices[a];
    VEC3F& vb = mesh.vertices[b];
    VEC3F& vc = mesh.vertices[c];
    VEC3F ab = va - vb;
    VEC3F cb = vc - vb;
    VEC3F n = cuda_internalCross(cb, ab);
    mesh.normals[a] += n;
    mesh.normals[b] += n;
    mesh.normals[c] += n;
}

// functions ---------------------------------------------------------------------------------

__device__ __device__ void setDefaultArraySizes(
    uint vertSize,
    uint normSize,
    uint triSize);

__global__ void dev_internalComputeEdge(
    VEC3I* slab_inds,
    Mesh& mesh,
    Grid3D* grid,
    float va,
    float vb,
    int axis,
    uint x,
    uint y,
    uint z,
    const VEC3I& size
);

__device__ __host__ void dev_march_cubes(
    Grid3D* grid, 
    Mesh& outputMesh, 
    bool verbose = false
);