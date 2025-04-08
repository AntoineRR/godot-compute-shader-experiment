#[compute]
#version 460

layout(local_size_x = 8, local_size_y = 8, local_size_z = 8) in;

layout(set = 0, binding = 0, std430) restrict readonly buffer InputBuffer {
    uint[] input_buffer;
};

layout(set = 1, binding = 0, std430) restrict writeonly buffer OutputBuffer {
    uint[] output_buffer;
};

void main() {
    uvec3 id = gl_GlobalInvocationID;
    uint index = id.x * (gl_NumWorkGroups.y * gl_WorkGroupSize.y) * (gl_NumWorkGroups.z * gl_WorkGroupSize.z)
        + id.y * (gl_NumWorkGroups.z * gl_WorkGroupSize.z) + id.z;
    output_buffer[index] = index;
}
