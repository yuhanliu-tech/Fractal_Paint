#pragma once

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

namespace CudaMC {
    void placeholder(int N);
}