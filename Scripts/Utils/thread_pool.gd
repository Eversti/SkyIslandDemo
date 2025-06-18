extends Node

class_name thread_pool

# Limit to CPU core count
var MAX_THREADS = OS.get_processor_count() - 1

var task_queue = []
var active_threads = []
var is_running := false

var queue_mutex := Mutex.new()

signal task_completed(result)

func _ready():
	is_running = true
	for i in range(MAX_THREADS):
		start_worker()

func start_worker():
	var thread = Thread.new()
	active_threads.append(thread)
	thread.start(thread_loop)

func add_task(func_ref):
	print("Adding task: ", func_ref.get_bound_arguments()[0])
	task_queue.append(func_ref)

func thread_loop():
	while is_running:
		var task = null
		
		queue_mutex.lock()
		if task_queue.size() > 0:
			task = task_queue.pop_front()
		queue_mutex.unlock()
		
		if task != null:
			var result = task.call()
			call_deferred("emit_signal", "task_completed", result)
		else:
			OS.delay_msec(50)

func stop():
	is_running = false
	for thread in active_threads:
		thread.wait_to_finish()
