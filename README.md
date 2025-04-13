# Test for running huge compute shaders without drops in framerate

This repo contains a simple version of a code running a compute shader without slowing down the render thread (too much).
Running a compute shader with big exchanges of data between the GPU and the CPU can lead to freezes when done on the main thread.
The key is simply to do everything on a separate thread.