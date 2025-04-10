extends Node

var rd: RenderingDevice
var shader: RID
var pipeline: RID

var input_uniform_set: RID
var output_uniform_set: RID

var buffers: Array[RID]

const DIM := 1
const LOCAL_SIZE := 8
const WAITING_TIME_SECONDS := 1.0

var time_waited := WAITING_TIME_SECONDS + 1.0
var ran_compute = null
var start_ref_time: int


func _ready() -> void:
    init_compute_pipeline(load("res://test.glsl"))


func _process(delta: float) -> void:
    time_waited += delta
    if ran_compute and time_waited >= WAITING_TIME_SECONDS:
        var sync_time = Time.get_ticks_msec()
        rd.sync()
        if ran_compute == "sync":
            extract_done(rd.buffer_get_data(buffers[0]))
        ran_compute = null
        print("buffer_get_data blocked for: ", Time.get_ticks_msec() - sync_time, "ms")


func extract_done(result: PackedByteArray):
    print("received: ", result.size(), " bytes in ", Time.get_ticks_msec() - start_ref_time, "ms")
    print("array elements should be their index: ", result.to_int32_array())
    clean()


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


func sync_setup(dims: Vector3i):
    create_uniform_sets(get_bytes(dims), get_bytes(dims))
    
    RenderingServer.call_on_render_thread(
        func():
            run_pipeline(dims)
            ran_compute = "sync"
            time_waited = 0.0
    )


func _on_sync_button_pressed() -> void:
    print("=== SYNC ===")

    start_ref_time = Time.get_ticks_msec()

    var dims = DIM * Vector3i.ONE
    WorkerThreadPool.add_task(sync_setup.bind(dims))


func async_setup(dims: Vector3i):
    create_uniform_sets(get_bytes(dims), get_bytes(dims))

    RenderingServer.call_on_render_thread(
        func():
            # Inverting the following two lines makes the game crash in the editor (at least on my hardware)
            rd.buffer_get_data_async(buffers[0], extract_done)
            run_pipeline(dims)
            ran_compute = "async"
            time_waited = 0.0
    )


func _on_async_button_pressed() -> void:
    print("=== ASYNC ===")

    start_ref_time = Time.get_ticks_msec()
    
    var dims = DIM * Vector3i.ONE
    WorkerThreadPool.add_task(async_setup.bind(dims))
