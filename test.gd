extends Node

var rd: RenderingDevice
var shader: RID
var pipeline: RID

var input_uniform_set: RID
var output_uniform_set: RID

var buffers: Array[RID]

const DIM := 50
const LOCAL_SIZE := 8


func init_compute_pipeline(shader_file: RDShaderFile) -> void:
    rd = RenderingServer.create_local_rendering_device()
    
    var shader_spirv := shader_file.get_spirv()
    shader = rd.shader_create_from_spirv(shader_spirv)
    pipeline = rd.compute_pipeline_create(shader)


func get_bytes(dims: Vector3i) -> Array[PackedByteArray]:
    var result = PackedInt32Array([])
    var true_dims = LOCAL_SIZE * dims
    result.resize(true_dims.x * true_dims.y * true_dims.z)
    result.fill(0)
    return [result.to_byte_array()]


func create_uniform_and_buffer(bytes: PackedByteArray, uniforms: Array[RDUniform], add_to_buffers := true) -> void:
    var buffer := rd.storage_buffer_create(bytes.size(), bytes)
    var uniform := RDUniform.new()
    uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
    uniform.binding = uniforms.size()
    uniform.add_id(buffer)

    uniforms.append(uniform)
    if add_to_buffers:
        buffers.append(buffer)


func create_uniform_sets(input_bytes: Array[PackedByteArray], output_bytes: Array[PackedByteArray]) -> void:
    var input_uniforms: Array[RDUniform] = []
    for bytes in input_bytes:
        create_uniform_and_buffer(bytes, input_uniforms, false)
    input_uniform_set = rd.uniform_set_create(input_uniforms, shader, 0)

    var output_uniforms: Array[RDUniform] = []
    for bytes in output_bytes:
        create_uniform_and_buffer(bytes, output_uniforms)
    output_uniform_set = rd.uniform_set_create(output_uniforms, shader, 1)


func clean() -> void:
    rd.free_rid(input_uniform_set)
    rd.free_rid(output_uniform_set)
    for buffer in buffers:
        rd.free_rid(buffer)
    buffers.clear()


func run_pipeline(dims: Vector3i) -> void:
    var compute_list := rd.compute_list_begin()
    rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
    rd.compute_list_bind_uniform_set(compute_list, input_uniform_set, 0)
    rd.compute_list_bind_uniform_set(compute_list, output_uniform_set, 1)
    rd.compute_list_dispatch(compute_list, dims.x, dims.y, dims.z)
    rd.compute_list_end()

    rd.submit()


func run_shader(dims: Vector3i):
    init_compute_pipeline(load("res://test.glsl"))
    create_uniform_sets(get_bytes(dims), get_bytes(dims))
    
    run_pipeline(dims)
    rd.sync()
    var result = rd.buffer_get_data(buffers[0])
    print("received: ", result.size(), " bytes")
    print("array elements should be their index: ", result.to_int32_array()[-1])
    clean()


func _on_button_pressed() -> void:
    var dims = DIM * Vector3i.ONE
    WorkerThreadPool.add_task(run_shader.bind(dims))
