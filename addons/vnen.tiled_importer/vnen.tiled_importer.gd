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
extends EditorPlugin

var import_plugin = null
var tileset_import_plugin = null

func get_name():
	return "Tiled Map Importer"

func _enter_tree():
	if not ProjectSettings.has_setting("tiled_importer/enable_json_format"):
		ProjectSettings.set_setting("tiled_importer/enable_json_format", true)

	import_plugin = preload("tiled_import_plugin.gd").new()
	tileset_import_plugin = preload("tiled_tileset_import_plugin.gd").new()
	add_import_plugin(import_plugin)
	add_import_plugin(tileset_import_plugin)

func _exit_tree():
	remove_import_plugin(import_plugin)
	remove_import_plugin(tileset_import_plugin)
	import_plugin = null
	tileset_import_plugin = null
