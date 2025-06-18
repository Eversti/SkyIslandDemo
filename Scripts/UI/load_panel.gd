extends Panel

@onready var bar = $ProgressBar

var current_step

 
func set_up_load(load_steps):
	$".".visible = true
	current_step = 0
	bar.max_value = load_steps
	bar.value = current_step
	
func progress_load():
	current_step += 1
	bar.value = current_step

func complete_load():
	$".".visible = false
