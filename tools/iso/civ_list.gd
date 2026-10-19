extends SceneTree
## Imprime «civs: a b c» con las civilizaciones que tienen módulo de arquitectura (IsoCivs.available()). Lo usa civ_build.sh.

func _initialize() -> void:
	print("civs: ", " ".join(PackedStringArray(IsoCivs.available())))
	quit()
