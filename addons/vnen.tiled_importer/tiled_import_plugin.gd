# The MIT License (MIT)
#
# Copyright (c) 2018 George Marques
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

tool
extends EditorImportPlugin

enum { PRESET_DEFAULT, PRESET_PIXEL_ART }

const TiledMapReader = preload("tiled_map_reader.gd")

func get_importer_name():
	return "vnen.tiled_importer"

func get_visible_name():
	return "Scene from Tiled"

func get_recognized_extensions():
	if ProjectSettings.get_setting("tiled_importer/enable_json_format"):
		return ["json", "tmx"]
	else:
		return ["tmx"]

func get_save_extension():
	return "scn"

func get_priority():
	return 1

func get_import_order():
	return 100

func get_resource_type():
	return "PackedScene"

func get_preset_count():
	return 2

func get_preset_name(preset):
	match preset:
		PRESET_DEFAULT: return "Default"
		PRESET_PIXEL_ART: return "Pixel Art"

func get_import_options(preset):
	return [
		{
			"name": "custom_properties",
			"default_value": true
		},
		{
			"name": "tile_metadata",
			"default_value": false
		},
		{
			"name": "uv_clip",
			"default_value": true
		},
		{
			"name": "image_flags",
			"default_value": 0 if preset == PRESET_PIXEL_ART else Texture.FLAGS_DEFAULT,
			"property_hint": PROPERTY_HINT_FLAGS,
			"hint_string": "Mipmaps,Repeat,Filter,Anisotropic,sRGB,Mirrored Repeat"
		},
		{
			"name": "collision_layer",
			"default_value": 1,
			"property_hint": PROPERTY_HINT_LAYERS_2D_PHYSICS
		},
		{
			"name": "embed_internal_images",
			"default_value": true if preset == PRESET_PIXEL_ART else false
		},
		{
			"name": "save_tiled_properties",
			"default_value": false
		},
		{
			"name": "add_background",
			"default_value": true
		},
		{
			"name": "post_import_script",
			"default_value": "",
			"property_hint": PROPERTY_HINT_FILE,
			"hint_string": "*.gd;GDScript"
		}
	]

func get_option_visibility(option, options):
	return true

func import(source_file, save_path, options, r_platform_variants, r_gen_files):
	var map_reader = TiledMapReader.new()

	# Offset is only optional for importing TileSets
	options.apply_offset = true
	var scene = map_reader.build(source_file, options)

	if typeof(scene) != TYPE_OBJECT:
		# Error happened
		return scene

	# Post imports script
	if not options.post_import_script.empty():
		var script = load(options.post_import_script)
		if not script or not script is GDScript:
			printerr("Post import script is not a GDScript.")
			return ERR_INVALID_PARAMETER

		script = script.new()
		if not script.has_method("post_import"):
			printerr("Post import script does not have a 'post_import' method.")
			return ERR_INVALID_PARAMETER

		scene = script.post_import(scene)

		if not scene or not scene is Node2D:
			printerr("Invalid scene returned from post import script.")
			return ERR_INVALID_DATA

	var packed_scene = PackedScene.new()
	packed_scene.pack(scene)
	return ResourceSaver.save("%s.%s" % [save_path, get_save_extension()], packed_scene)
