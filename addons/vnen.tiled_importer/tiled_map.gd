# The MIT License (MIT)
#
# Copyright (c) 2016 George Marques
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
extends Reference

# http://doc.mapeditor.org/reference/tmx-map-format/#tile-flipping
const FLIPPED_HORIZONTALLY_FLAG = 0x80000000;
const FLIPPED_VERTICALLY_FLAG   = 0x40000000;
const FLIPPED_DIAGONALLY_FLAG   = 0x20000000;

var data = {}
var options = {}
var tilesets = []
var scene = null
var source = ""
var tile_id_mapping = {}

func init(p_source, p_options):
	source = p_source
	options = p_options

	options.name = source.basename()
	options.basedir = source.get_base_dir()

func get_data():
	var f = File.new()
	if f.open(source, File.READ) != OK:
		return "Couldn't open source file"

	var tiled_raw_data = f.get_as_text()
	f.close()

	if data.parse_json(tiled_raw_data) != OK:
		return "Couldn't parse the source file"

	return data;

func build():
	# Validate before doing anything
	if not data.has("tilesets"):
		return 'Invalid Tiled data: missing "tilesets" key.'

	if not data.has("layers"):
		return 'Invalid Tiled data: missing "layers" key.'

	if not data.has("height") or not data.has("width"):
		return 'Invalid Tiled data: missing "height" or "width" keys.'

	if not data.has("tileheight") or not data.has("tilewidth"):
		return 'Invalid Tiled data: missing "tileheight" or "tilewidth" keys.'

	var map_size = Vector2(int(data.width), int(data.height))
	var cell_size = Vector2(int(data.tilewidth), int(data.tileheight))

	# Make tilesets
	for ts in data.tilesets:
		var tileset = TileSet.new()

		var spacing = 0
		var margin = 0
		var firstgid = 0
		var image = ImageTexture.new()
		var image_path = ""
		var image_h = 0
		var image_w = 0
		var name = ""
		var tilesize = Vector2()
		var tilecount = 0

		if ts.has("spacing"):
			spacing = int(ts.spacing)
		if ts.has("margin"):
			margin = int(ts.margin)
		if ts.has("imageheight"):
			image_h = int(ts.imageheight)
		if ts.has("imagewidth"):
			image_w = int(ts.imagewidth)
		if ts.has("firstgid"):
			firstgid = int(ts.firstgid)
		if ts.has("name"):
			name = ts.name
		if ts.has("tilewidth") and ts.has("tileheight"):
			tilesize = Vector2(int(ts.tilewidth), int(ts.tileheight))
		else:
			return "Missing tile dimensions (%s)" % [name]
		if ts.has("tilecount"):
			tilecount = int(ts.tilecount)
		else:
			return "Missing tile count (%s)" % [name]

		if ts.has("image"):
			image_path = options.basedir.plus_file(ts.image)
			var dir = Directory.new()
			if not dir.file_exists(image_path):
				return 'Referenced image "%s" not found' % [image_path]
			image.load(image_path)
			image.set_flags(0)

			if not options.embed:
				var target_image = options.target.get_base_dir() \
								   .plus_file(options.rel_path + name + ".png")
				var err = ResourceSaver.save(target_image, image, ResourceSaver.FLAG_CHANGE_PATH)
				if err != OK:
					return "Couldn't save image for Tileset %s" % [name]
				image.take_over_path(target_image)

		if image.get_width() != image_w or image.get_height() != image_h:
			return "Image dimensions don't match (%s)" % [image_path]

		var gid = firstgid

		for y in range(margin, image_h, tilesize.y + margin + spacing):
			for x in range(margin, image_w, tilesize.x + margin + spacing):
				var tilepos = Vector2(x,y)
				var region = Rect2(tilepos, tilesize)

				tileset.create_tile(gid)
				tileset.tile_set_texture(gid, image)
				tileset.tile_set_region(gid, region)

				var rel_id = str(gid - firstgid)

				if "tiles" in ts and rel_id in ts.tiles and "objectgroup" in ts.tiles[rel_id]:
					for obj in ts.tiles[rel_id].objectgroup.objects:
						var shape = _shape_from_object(obj)

						if typeof(shape) == TYPE_STRING:
							return "Error on shape data in tileset %s:\n%s" % [name, shape]

						var offset = Vector2(int(obj.x), int(obj.y))
						offset += Vector2(int(obj.width) / 2, int(obj.height) / 2)

						if obj.type == "navigation":
							tileset.tile_set_navigation_polygon(gid, shape)
							tileset.tile_set_navigation_polygon_offset(gid, offset)
						elif obj.type == "occluder":
							tileset.tile_set_light_occluder(gid, shape)
							tileset.tile_set_occluder_offset(gid, offset)
						else:
							tileset.tile_set_shape(gid, shape)
							tileset.tile_set_shape_offset(gid, offset)

				gid += 1

		tileset.set_name(name)

		if not options.embed:
			var tileset_path = options.target.get_base_dir().plus_file(options.rel_path + name + ".res")
			var err = ResourceSaver.save(tileset_path, tileset, ResourceSaver.FLAG_CHANGE_PATH)
			if err != OK:
				return "Couldn't save TileSet %s" % [name]
			tileset.take_over_path(tileset_path)

		tilesets.push_back(tileset)

		tile_id_mapping[name] = {
			"firstgid": firstgid,
			"tilecount": tilecount,
			"tileset": tileset,
		}

	# TileSets done, creating the target scene

	scene = Node2D.new()
	scene.set_name(options.target.basename())

	for l in data.layers:
		if l.has("compression"):
			return 'Tiled compressed format is not supported. Change your Map properties to a format without compression.'

		if not l.has("name"):
			return 'Invalid Tiled data: missing "name" key on layer.'
		var name = l.name

		if not l.has("data"):
			return 'Invalid Tiled data: missing "data" key on layer %s.' % [name]
		var layer_data = l.data

		if "encoding" in l:
			if l.encoding != "base64":
				return 'Unsupported layer data encoding. Use Base64 or no enconding.'
			layer_data = _parse_base64_layer(l.data)

		var opacity = 1.0
		var visible = true

		if l.has("opacity"):
			opacity = float(l.opacity)
		if l.has("visible"):
			visible = bool(l.visible)

		var tilemap = TileMap.new()
		tilemap.set_name(name)
		tilemap.set_cell_size(cell_size)
		tilemap.set_opacity(opacity)
		tilemap.set_hidden(not visible)

		var offset = Vector2()
		if l.has("offsetx") and l.has("offsety"):
			offset = Vector2(int(l.offsetx), int(l.offsety))

		tilemap.set_pos(offset)

		var firstgid = 0
		tilemap.set_tileset(_tileset_from_gid(firstgid))

		var count = 0
		for tile_id in layer_data:

			var int_id = int(tile_id)

			if int_id == 0:
				count += 1
				continue

			var flipped_h = int_id & FLIPPED_HORIZONTALLY_FLAG
			var flipped_v = int_id & FLIPPED_VERTICALLY_FLAG
			var flipped_d = int_id & FLIPPED_DIAGONALLY_FLAG

			var gid = int_id & ~(FLIPPED_HORIZONTALLY_FLAG | FLIPPED_VERTICALLY_FLAG | FLIPPED_DIAGONALLY_FLAG)

			if firstgid == 0:
				firstgid = gid
				tilemap.set_tileset(_tileset_from_gid(firstgid))

			var cell_pos = Vector2(count % int(map_size.width), int(count / map_size.width))
			tilemap.set_cellv(cell_pos, gid, flipped_h, flipped_h, flipped_d)

			count += 1

		scene.add_child(tilemap)
		tilemap.set_owner(scene)

	return "OK"

func get_tilesets():
	return tilesets

func get_scene():
	return scene

# Get the tileset based on the global tile id
func _tileset_from_gid(gid):
	for map_id in tile_id_mapping:
		var map = tile_id_mapping[map_id]
		if gid >= map.firstgid and gid < (map.firstgid + map.tilecount):
			return map.tileset

	return null

# Get a shape based on the object data
func _shape_from_object(obj):
	var shape = "No shape created. That really shouldn't happen..."

	if "polygon" in obj or "polyline" in obj:
		var vertices = Vector2Array()

		if "polygon" in obj:
			for point in obj.polygon:
				vertices.push_back(Vector2(int(point.x), int(point.y)))
		else:
			for point in obj.polyline:
				vertices.push_back(Vector2(int(point.x), int(point.y)))

		if obj.type == "navigation":
			shape = NavigationPolygon.new()
			shape.set_vertices(vertices)
		elif obj.type == "occluder":
			shape = OccluderPolygon2D.new()
			shape.set_polygon(vertices)
			shape.set_closed("polygon" in obj)
		else:
			shape = ConcavePolygonShape2D.new()
			shape.set_segments(vertices)

	elif "ellipse" in obj:
		if obj.type == "navigation" or obj.type == "occluder":
			return "Ellipse shapes are not supported as navigation or occluder. Use a polygon/polyline or a rectangle."

		var w = int(obj.width)
		var h = int(obj.height)

		if w == h:
			shape = CircleShape2D.new()
			shape.set_radius(w/2)
		else:
			shape = CapsuleShape2D.new()
			shape.set_radius(w/2)
			shape.set_height(h/2)

	else:
		# Rectangle
		var size = Vector2(int(obj.width), int(obj.height))

		if obj.type == "navigation" or obj.type == "occluder":
			var vertices = Vector2Array([
				Vector2(0, 0),
				Vector2(size.width, 0),
				size,
				Vector2(0, size.height),
			])

			if obj.type == "navigation":
				shape = NavigationPolygon.new()
				shape.set_vertices(vertices)
			else:
				shape = OccluderPolygon2D.new()
				shape.set_polygon(vertices)
		else:
			shape = RectangleShape2D.new()
			shape.set_extents(size / 2)

	return shape

func _parse_base64_layer(data):
	var decoded = Marshalls.base64_to_raw(data)

	var result = []

	for i in range(0, decoded.size(), 4):

		var num = (decoded[i]) | \
		          (decoded[i + 1] << 8) | \
		          (decoded[i + 2] << 16) | \
		          (decoded[i + 3] << 24)
		result.push_back(num)

	return result
