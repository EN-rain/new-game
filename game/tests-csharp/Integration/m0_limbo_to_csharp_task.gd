extends BTAction


func _tick(_delta: float) -> Status:
	if agent != null and agent.has_method("enemy_probe_from_limbo"):
		return SUCCESS if agent.enemy_probe_from_limbo("limbo-to-csharp") else FAILURE
	return FAILURE
