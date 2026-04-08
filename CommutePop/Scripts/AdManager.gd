extends Node

func show_reward_ad(on_success: Callable) -> void:
	await get_tree().create_timer(1.5).timeout
	on_success.call()

func show_interstitial_ad() -> void:
	await get_tree().create_timer(0.8).timeout