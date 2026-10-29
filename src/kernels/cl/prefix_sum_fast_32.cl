#ifdef __CLION_IDE__
#include <libgpu/opencl/cl/clion_defines.cl> // This file helps CLion IDE to know what additional functions exists in OpenCL's extended C99
#endif

#include "helpers/rassert.cl"
#include "../defines.h"

__attribute__((reqd_work_group_size(128, 1, 1)))
__kernel void prefix_sum_fast_in_group_32(
    __global const uint* cur_arr,
    __global       uint* new_arr,
    __global       uint* helper_arr
)
{
    int index = get_global_id(0);
    int local_index = get_local_id(0);
    __local uint arr[128];
    arr[local_index] = cur_arr[index];

    barrier(CLK_LOCAL_MEM_FENCE);

    if (local_index == 0) {
        for (int i = 1; i < 128; ++i) {
            arr[i] += arr[i - 1];
        }
        helper_arr[index / 128] = arr[127];
    }

    barrier(CLK_LOCAL_MEM_FENCE);

    new_arr[index] = arr[local_index];
}

__attribute__((reqd_work_group_size(128, 1, 1)))
__kernel void prefix_sum_fast_32(
    __global const uint* cur_arr,
    __global const uint* cur_helper_arr,
    __global       uint* new_arr,
    __global       uint* new_helper_arr,
    int n,
    uint block_size,
    uint helper_size
) {
    uint index = get_global_id(0);
    uint local_index = get_local_id(0);

    __local uint helper[128];
    uint my_index = (index / block_size);
    uint start = my_index & (~127);

    helper[local_index] = (start + local_index < helper_size ? cur_helper_arr[start + local_index] : 0);

    barrier(CLK_LOCAL_MEM_FENCE);

    __local uint sum_before;
    if (local_index == 0) {
        sum_before = 0;
        for (int i = 0; i < my_index - start; ++i) {
            sum_before += helper[i];
        }

        if (index + 127 < n && ((index + 127) & (block_size * 128 - 1)) == block_size * 128 - 1) {
            new_helper_arr[my_index / 128] = sum_before + cur_arr[index + 127];
        }
    }

    barrier(CLK_LOCAL_MEM_FENCE);

    new_arr[index] = cur_arr[index] + sum_before;
}