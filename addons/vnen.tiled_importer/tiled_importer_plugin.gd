# The MIT License (MIT)
#
# Copyright (c) 2017 George Marques
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

const TiledMap = preload("res://addons/vnen.tiled_importer/tiled_map.gd")
const PLUGIN_NAME = "org.vnen.tiled_importer"

var base_plugin = null

func config(b):
	base_plugin = b

func get_preset_count():
	return 0

func get_preset_name(preset):
	return "Default"

func get_recognized_extensions():
	return ['tmx', 'json']

func get_save_extension():
	return 'scn'

func get_import_options(preset):
	return [
		{
			"name": "textures/image_flags",
			"default_value": 0,
			"property_hint": PROPERTY_HINT_FLAGS,
			"hint_string": "Mipmaps,Repeat,Filter,Anisotropic Filter,Convert to Linear,Mirrored Repeat"
		}
	]

func get_visible_name():
	return "Tiled Map as Scene"

func get_resource_type():
	return "PackedScene"

func get_importer_name():
	return PLUGIN_NAME

func import(source_file, save_path, options, r_platform_variants, r_gen_files):

	print("import_options ", options)
	var tiled_map = TiledMap.new()
	var full_path = save_path + "." + get_save_extension()
	var my_options = {
		"single_tileset": true,
		"embed": true,
		"rel_path": "",
		"image_flags": options["textures/image_flags"],
		"separate_img_dir": false,
		"custom_properties": true,
		"post_script": "",
		"target": full_path,
	}

	tiled_map.init(source_file, my_options)

	var tiled_data = tiled_map.get_data()

	if typeof(tiled_data) == TYPE_STRING:
		# If is string then it's an error message
		print("errdata: ", tiled_data)
		return ERR_WTF

	var err = tiled_map.build()
	if typeof(err) == TYPE_STRING and err != "OK":
		# If is string then it's an error message
		print("errbuild: ", err)
		return ERR_WTF

	var scene = tiled_map.get_scene()

	var packed_scene = PackedScene.new()
	err = packed_scene.pack(scene)
	if err != OK:
		return err

	err = ResourceSaver.save(full_path, packed_scene)

	if err != OK:
		return err

	base_plugin.reload_scene(source_file)
	return OK

func get_option_visibility(option, options):
	return true
