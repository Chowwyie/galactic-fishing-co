class_name FishData
extends RefCounted

# In-water fish render as DARK SILHOUETTES (Dredge-style). Detailed pixel art
# is only revealed on the capture screen / catalog.
const SPECIES: Array = [
	{
		"id": "pink",
		"name": "Bubblescale Minnow",
		"desc": "Our most popular catch! Mild flavor, excellent resale value. Note: specimens occasionally hum in four-part harmony. This is normal. Please do not investigate.",
		"value": 20,
		"speed": 70.0,
		"min_depth": 150.0,
		"water": "fish_pink_sil",   # silhouette frames for swimming
		"art": "fish_pink",          # detailed frames for catalog/capture
	},
	{
		"id": "orange",
		"name": "Copperbelly Glint",
		"desc": "A hardy little earner with a lovely metallic sheen. The sheen is NOT circuitry. Repeat: the sheen is NOT circuitry. Enjoy your performance bonus, valued contractor!",
		"value": 35,
		"speed": 100.0,
		"min_depth": 450.0,
		"water": "fish_orange_sil",
		"art": "fish_orange",
	},
	{
		"id": "teal",
		"name": "Worrywart Wrasse",
		"desc": "Always looks a little sad. Do not be concerned - fish cannot feel things. That is science. Fifty credits of science. Moving on!",
		"value": 50,
		"speed": 125.0,
		"min_depth": 750.0,
		"water": "fish_teal_sil",
		"art": "fish_teal",
	},
]

static func get_species(id: String) -> Dictionary:
	for s in SPECIES:
		if s["id"] == id:
			return s
	return SPECIES[0]

static func frames(prefix: String) -> Array:
	var arr: Array = []
	for i in range(3):
		arr.append(load("res://assets/sprites/%s_%d.png" % [prefix, i]))
	return arr
