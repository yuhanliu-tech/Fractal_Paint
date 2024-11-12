#define GLM_FORCE_CUDA
#include "CudaMC.h"
#include <cuda_runtime.h>

// CUDA Constants and device variables
__constant__ int d_mc_internalMarching_cube_tris[256][16];
__device__ int defaultVerticeArraySize = 30000;
__device__ int defaultNormalArraySize = 30000;
__device__ int defaultTriangleArraySize = 60000;

void checkCUDAErrorFn(const char* msg, const char* file, int line) {
    cudaError_t err = cudaGetLastError();
    if (cudaSuccess == err) {
        return;
    }

    fprintf(stderr, "CUDA error");
    if (file) {
        fprintf(stderr, " (%s:%d)", file, line);
    }
    fprintf(stderr, ": %s: %s\n", msg, cudaGetErrorString(err));
    exit(EXIT_FAILURE);
}

void CudaMC::placeholder(int N) {
    int help = N;
}