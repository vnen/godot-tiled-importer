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
const FLIPPED_HORIZONTALLY_FLAG = 0x80000000
const FLIPPED_VERTICALLY_FLAG   = 0x40000000
const FLIPPED_DIAGONALLY_FLAG   = 0x20000000

const parser_error_message = "Error parsing .tmx file"

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

	if source.extension() == "json":
		var f = File.new()
		if f.open(source, File.READ) != OK:
			return "Couldn't open source file"

		var tiled_raw_data = f.get_as_text()
		f.close()

		if data.parse_json(tiled_raw_data) != OK:
			return "Couldn't parse the source file"
	else:
		data = _tmx_to_dict(source)

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

	var basename = options.target.substr(options.target.find_last('/'), options.target.length()).basename()

	var map_size = Vector2(int(data.width), int(data.height))
	var cell_size = Vector2(int(data.tilewidth), int(data.tileheight))
	var map_mode = TileMap.MODE_SQUARE
	if "orientation" in data:
		if data.orientation == "isometric":
			map_mode = TileMap.MODE_ISOMETRIC

	var single_tileset = null

	if options.single_tileset:
		single_tileset = TileSet.new()

	# Make tilesets
	for tstemp in data.tilesets:
		var ts = tstemp
		if tstemp.has("source"):
			var err = OK
			var tileset_src = source.get_base_dir().plus_file(tstemp.source) if tstemp.source.is_rel_path() else tstemp.source
			if tileset_src.extension() == "json":
				var f = File.new()
				err = f.open(tileset_src, File.READ)
				if err != OK:
					return "Couldn't open tileset file %s." % [tileset_src]

				ts = {}
				err = ts.parse_json(f.get_as_text())
				if err != OK:
					return "Couldn't parse tileset file %s." % [tileset_src]
			else:
				var tsparser = XMLParser.new()

				err = tsparser.open(tileset_src)
				if err != OK:
					return "Couldn't open tileset file %s." % [tileset_src]

				while err == OK:
					if tsparser.get_node_type() == XMLParser.NODE_ELEMENT:
						break
					err = tsparser.read()

				if err != OK:
					return "Error parsing tileset file %s." % [tileset_src]

				ts = _parse_tileset(tsparser)
			ts.firstgid = int(tstemp.firstgid)

		var tileset = null
		if options.single_tileset:
			tileset = single_tileset
		else:
			tileset = TileSet.new()

		var spacing = 0
		var margin = 0
		var firstgid = 0
		var image = ImageTexture.new()
		var target_dir = ""
		var image_path = ""
		var image_h = 0
		var image_w = 0
		var name = ""
		var tilesize = Vector2()
		var tilecount = 0
		var has_global_img = false

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
			has_global_img = true
			image_path = options.basedir.plus_file(ts.image) if ts.image.is_rel_path() else ts.image
			target_dir = options.target.get_base_dir().plus_file(options.rel_path)
			image = _load_image(image_path, target_dir, name + ".png", image_w, image_h)
			if typeof(image) == TYPE_STRING:
				return image
		else:
			if options.separate_img_dir:
				target_dir = options.target.get_base_dir().plus_file(options.rel_path).plus_file(name)
				if not Directory.new().dir_exists(target_dir):
					Directory.new().make_dir_recursive(target_dir)
			else:
				target_dir = options.target.get_base_dir().plus_file(options.rel_path)

		var gid = firstgid

		var x = margin
		var y = margin

		var i = 0
		while i < tilecount:

			var tilepos = Vector2(x,y)
			var region = Rect2(tilepos, tilesize)

			var rel_id = str(gid - firstgid)

			tileset.create_tile(gid)
			if has_global_img:
				tileset.tile_set_texture(gid, image)
				tileset.tile_set_region(gid, region)
			elif not rel_id in ts.tiles:
				gid += 1
				continue

			if not has_global_img and "image" in ts.tiles[rel_id]:
				var _img = ts.tiles[rel_id].image
				image_path = options.basedir.plus_file(_img) if _img.is_rel_path() else _img
				_img = _img.get_file().basename()
				image = _load_image(image_path, target_dir, "%s_%s_%s.png" % [name, _img, rel_id], cell_size.x, cell_size.y)
				if typeof(image) == TYPE_STRING:
					return image
				tileset.tile_set_texture(gid, image)

			if "tiles" in ts and rel_id in ts.tiles and "objectgroup" in ts.tiles[rel_id] \
			                 and "objects" in ts.tiles[rel_id].objectgroup:
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
			i += 1
			x += int(tilesize.x) + spacing
			if x >= image_w - margin:
				x = margin
				y += int(tilesize.y) + spacing

		if options.custom_properties and ts.has("properties") and ts.has("propertytypes"):
			_set_meta(tileset, ts.properties, ts.propertytypes)

		tileset.set_name(name)

		if not options.single_tileset:
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

	if options.single_tileset and not options.embed:
		single_tileset.set_name(basename)

		var tileset_path = options.target.get_base_dir().plus_file(options.rel_path + basename + ".res")
		var err = ResourceSaver.save(tileset_path, single_tileset, ResourceSaver.FLAG_CHANGE_PATH)
		if err != OK:
			return "Couldn't save TileSet"
		single_tileset.take_over_path(tileset_path)

	if options.single_tileset:
		tilesets = [single_tileset]

	# TileSets done, creating the target scene

	scene = Node2D.new()
	scene.set_name(basename)

	for l in data.layers:
		if l.has("compression"):
			return 'Tiled compressed format is not supported. Change your Map properties to a format without compression.'

		if not l.has("type"):
			return 'Invalid Tiled data: missing "type" key on layer.'

		if not l.has("name"):
			return 'Invalid Tiled data: missing "name" key on layer.'

		var opacity = 1.0
		var visible = true

		if l.has("opacity"):
			opacity = float(l.opacity)
		if l.has("visible"):
			visible = bool(l.visible)

		if l.type == "tilelayer":
			var name = l.name

			if not l.has("data"):
				return 'Invalid Tiled data: missing "data" key on layer %s.' % [name]
			var layer_data = l.data

			if "encoding" in l:
				if l.encoding != "base64":
					return 'Unsupported layer data encoding. Use Base64 or no enconding.'
				layer_data = _parse_base64_layer(l.data)

			var tilemap = TileMap.new()
			tilemap.set_name(name)
			tilemap.set_cell_size(cell_size)
			tilemap.set_opacity(opacity)
			tilemap.set_hidden(not visible)
			tilemap.set_mode(map_mode)

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

				var flipped_v = bool(int_id & FLIPPED_VERTICALLY_FLAG)
				var flipped_h = bool(int_id & FLIPPED_HORIZONTALLY_FLAG)
				var flipped_d = bool(int_id & FLIPPED_DIAGONALLY_FLAG)

				var gid = int_id & ~(FLIPPED_HORIZONTALLY_FLAG | FLIPPED_VERTICALLY_FLAG | FLIPPED_DIAGONALLY_FLAG)

				if firstgid == 0:
					firstgid = gid
					tilemap.set_tileset(_tileset_from_gid(firstgid))

				var cell_pos = Vector2(count % int(map_size.width), int(count / map_size.width))
				tilemap.set_cellv(cell_pos, gid, flipped_h, flipped_v, flipped_d)

				count += 1

			if options.custom_properties and l.has("properties") and l.has("propertytypes"):
				_set_meta(tilemap, l.properties, l.propertytypes)

			scene.add_child(tilemap)
			tilemap.set_owner(scene)

		elif l.type == "imagelayer":
			if not l.has("image"):
				return 'Invalid Tiled data: missing "image" key on image layer.'

			var sprite = Sprite.new()
			sprite.set_name(l.name)
			sprite.set_centered(false)

			var pos = Vector2()
			var offset = Vector2()
			if l.has("x"):
				pos.x = float(l.x)
			if l.has("y"):
				pos.y = float(l.y)
			if l.has("offsetx"):
				offset.x = float(l.offsetx)
			if l.has("offsety"):
				offset.y = float(l.offsety)

			var image_path = options.basedir.plus_file(l.image) if l.image.is_rel_path() else l.image
			var target_dir = options.target.get_base_dir().plus_file(options.rel_path)
			var image = _load_image(image_path, target_dir, l.name + ".png")

			if typeof(image) == TYPE_STRING:
				return image

			sprite.set_texture(image)
			sprite.set_opacity(opacity)
			sprite.set_hidden(not visible)
			scene.add_child(sprite)
			sprite.set_pos(pos + offset)
			sprite.set_owner(scene)

		elif l.type == "objectgroup":
			if not l.has("objects"):
				return 'Invalid Tiled data: missing "objects" key on object layer.'

			if typeof(l.objects) != TYPE_ARRAY:
				return 'Invalid Tiled data: "objects" key on object layer is not an array.'

			var object = Node2D.new()

			if options.custom_properties and l.has("properties") and l.has("propertytypes"):
				_set_meta(object, l.properties, l.propertytypes)

			object.set_name(l.name)
			object.set_opacity(opacity)
			object.set_hidden(not visible)
			scene.add_child(object)
			object.set_owner(scene)

			for obj in l.objects:
				if not obj.has("gid"):
					if obj.type == "navigation":
						return "Invalid shape in object layer."

					var shape = _shape_from_object(obj)
					if typeof(shape) == TYPE_STRING:
						return shape

					if obj.type == "occluder":
						var occluder = LightOccluder2D.new()
						if obj.has("name") and not obj.name.empty():
							occluder.set_name(obj.name);
						else:
							occluder.set_name(str(obj.id))

						var pos = Vector2()
						if obj.has("x"):
							pos.x = float(obj.x)
						if obj.has("y"):
							pos.y = float(obj.y)
						occluder.set_pos(pos)

						var rot = 0
						if obj.has("rotation"):
							rot = float(obj.rotation)
						occluder.set_rotd(-rot)

						var obj_visible = true
						if obj.has("visible"):
							obj_visible = bool(obj.visible)
						occluder.set_hidden(not obj_visible)

						occluder.set_occluder_polygon(shape)

						object.add_child(occluder)
						occluder.set_owner(scene)

						if options.custom_properties and obj.has("properties") and obj.has("propertytypes"):
							_set_meta(occluder, obj.properties, obj.propertytypes)

					else:
						var body = StaticBody2D.new()
						if obj.has("name") and not obj.name.empty():
							body.set_name(obj.name);
						else:
							body.set_name(str(obj.id))

						var collision
						var offset = Vector2()
						var rot_offset = 0
						if not ("polygon" in obj or "polyline" in obj):
							collision = CollisionShape2D.new()
							collision.set_shape(shape)
							if shape extends RectangleShape2D:
								offset = shape.get_extents()
							elif shape extends CircleShape2D:
								offset = Vector2(shape.get_radius(), shape.get_radius())
							elif shape extends CapsuleShape2D:
								offset = Vector2(shape.get_radius(), shape.get_height())
							collision.set_pos(-offset)
							rot_offset = 180
						else:
							collision = CollisionPolygon2D.new()
							var points = null
							if shape extends ConcavePolygonShape2D:
								points = []
								var segments = shape.get_segments()
								for i in range(0, segments.size()):
									if i % 2 != 0:
										continue
									points.push_back(segments[i])
								collision.set_build_mode(1)
							else:
								points = shape.get_points()
								collision.set_build_mode(0)
							collision.set_polygon(points)

						var obj_visible = true
						if obj.has("visible"):
							obj_visible = bool(obj.visible)
						body.set_hidden(not obj_visible)

						var rot = 0
						if obj.has("rotation"):
							rot = float(obj.rotation)
							if rot_offset != 0:
								rot = rot_offset - rot
							else:
								rot = -rot
						body.set_rotd(rot)

						body.add_shape(shape, Matrix32(0, -offset))

						body.add_child(collision)
						object.add_child(body)
						body.set_owner(scene)
						collision.set_owner(scene)

						var pos = Vector2()
						if obj.has("x"):
							pos.x = float(obj.x)
						if obj.has("y"):
							pos.y = float(obj.y)

						body.set_pos(pos)

						if options.custom_properties and obj.has("properties") and obj.has("propertytypes"):
							_set_meta(body, obj.properties, obj.propertytypes)
				else: # if obj.has("gid"):
					var tile_raw_id = int(obj.gid)
					var tileid = tile_raw_id & ~(FLIPPED_HORIZONTALLY_FLAG | FLIPPED_VERTICALLY_FLAG | FLIPPED_DIAGONALLY_FLAG)
					var tileset = _tileset_from_gid(tileid)

					if tileset == null:
						return "Invalid GID in object layer tile"

					var sprite = Sprite.new()
					sprite.set_texture(tileset.tile_get_texture(tileid))
					sprite.set_region(true)
					sprite.set_region_rect(tileset.tile_get_region(tileid))

					if obj.has("name") and not obj.name.empty():
						sprite.set_name(obj.name);
					else:
						sprite.set_name(str(obj.id))

					if tile_raw_id & FLIPPED_HORIZONTALLY_FLAG:
						sprite.set_flip_h(true)
					if tile_raw_id & FLIPPED_VERTICALLY_FLAG:
						sprite.set_flip_v(true)

					var pos = Vector2()
					if obj.has("x"):
						pos.x = float(obj.x)
					if obj.has("y"):
						pos.y = float(obj.y)
					sprite.set_pos(pos)

					var rot = 0
					if obj.has("rotation"):
						rot = float(obj.rotation)
					sprite.set_rotd(-rot)

					var obj_visible = true
					if obj.has("visible"):
						obj_visible = bool(obj.visible)
					sprite.set_hidden(not obj_visible)

					object.add_child(sprite)
					sprite.set_owner(scene)

					if options.custom_properties and obj.has("properties") and obj.has("propertytypes"):
						_set_meta(sprite, obj.properties, obj.propertytypes)

	if options.custom_properties and data.has("properties") and data.has("propertytypes"):
		_set_meta(scene, data.properties, data.propertytypes)

	return "OK"

func get_tilesets():
	return tilesets

func get_scene():
	return scene

# Get the tileset based on the global tile id
func _tileset_from_gid(gid):
	if options.single_tileset:
		return tilesets[0]

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
			shape.add_outline(vertices)
			shape.make_polygons_from_outlines()
		elif obj.type == "occluder":
			shape = OccluderPolygon2D.new()
			shape.set_polygon(vertices)
			shape.set_closed("polygon" in obj)
		else:
			if _is_convex(vertices):
				shape = ConvexPolygonShape2D.new()
				vertices = _sort_points_cw(vertices)
				shape.set_points(vertices)
			else:
				shape = ConcavePolygonShape2D.new()
				var segments = [vertices[0]]
				for x in range(1, vertices.size()):
					segments.push_back(vertices[x])
					segments.push_back(vertices[x])
				segments.push_back(vertices[0])
				shape.set_segments(segments)

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
				shape.add_outline(vertices)
				shape.make_polygons_from_outlines()
			else:
				shape = OccluderPolygon2D.new()
				shape.set_polygon(vertices)
		else:
			shape = RectangleShape2D.new()
			shape.set_extents(size / 2)

	return shape

func _is_convex(polygon):
	var size = polygon.size()
	if size <= 3:
		# Less than 3 verices can't be concave
		return true

	var cp = 0

	for i in range(0, size + 2):
		var p1 = polygon[(i + 0) % size]
		var p2 = polygon[(i + 1) % size]
		var p3 = polygon[(i + 2) % size]

		var prev_cp = cp
		cp = (p2.x - p1.x) * (p3.y - p2.y) - (p2.y - p1.y) * (p3.x - p2.x)
		if i > 0 and sign(cp) != sign(prev_cp):
			return false

	return true

# Sort the vertices of a convex polygon in clockwise order
func _sort_points_cw(vertices):
	vertices = Array(vertices)

	var centroid = Vector2()
	var size = vertices.size()

	for i in range(0, size):
		centroid += vertices[i]

	centroid /= size

	var sorter = PointSorter.new(centroid)
	vertices.sort_custom(sorter, "is_less")

	return Vector2Array(vertices)

class PointSorter:
	var center

	func _init(c):
		center = c

	func is_less(a, b):
		if a.x - center.x >= 0 and b.x - center.x < 0:
			return false
		elif a.x - center.x < 0 and b.x - center.x >= 0:
			return true
		elif a.x - center.x == 0 and b.x - center.x == 0:
			if a.y - center.y >= 0 or b.y - center.y >= 0:
				return a.y < b.y
			return a.y > b.y

		var det = (a.x - center.x) * (b.y - center.y) - (b.x - center.x) * (a.y - center.y)
		if det > 0:
			return true
		elif det < 0:
			return false

		var d1 = (a - center).length_squared()
		var d2 = (b - center).length_squared()

		return d1 < d2

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

# Load, copy and verify image
func _load_image(source_img, target_folder, filename, width = false, height = false):
	var dir = Directory.new()
	if not dir.file_exists(source_img):
		return 'Referenced image "%s" not found' % [source_img]
	var image = ImageTexture.new()
	image.load(source_img)
	image.set_flags(options.image_flags)

	if not options.embed:
		var target_image = target_folder.plus_file(filename)
		var err = ResourceSaver.save(target_image, image)
		if err != OK:
			return "Couldn't save tileset image %s" % [target_image]
		image.take_over_path(target_image)

	return image

# Parse the custom properties and set as meta of the objet
func _set_meta(obj, properties, types):
	for prop in properties:
		var value = null
		if types[prop].to_lower() == "bool":
			value = bool(properties[prop])
		elif types[prop].to_lower() == "color":
			value = Color(properties[prop])
		elif types[prop].to_lower() == "float":
			value = float(properties[prop])
		elif types[prop].to_lower() == "int":
			value = int(properties[prop])
		else:
			value = str(properties[prop])
		obj.set_meta(prop, value)

# Read a .tmx file and build a dictionary in the same format as Tiled .json
# This helps normalizing the data and using a single builder
func _tmx_to_dict(path):

	var parser = XMLParser.new()
	var err = parser.open(path)
	if err != OK:
		return "Couldn't open .tmx file %s" % [path]

	while parser.get_node_type() != XMLParser.NODE_ELEMENT:
		err = parser.read()
		if err != OK:
			return "Error parsing .tmx file %s" % [path]

	if parser.get_node_name() != "map":
		return 'Error parsing .tmx file %s. Expected "map" element' % [path]

	var data = _attributes_to_dict(parser)
	data.tilesets = []
	data.layers = []

	err = parser.read()
	if err != OK:
		return parser_error_message

	while err == OK:
		if parser.get_node_type() == XMLParser.NODE_ELEMENT_END:
			if parser.get_node_name() == "map":
				break

		elif parser.get_node_type() == XMLParser.NODE_ELEMENT:
			if parser.get_node_name() == "tileset":
				# Empty element means external tileset
				if not parser.is_empty():
					var tileset = _parse_tileset(parser)
					if typeof(tileset) == TYPE_STRING:
						return tileset
					data.tilesets.push_back(tileset)
				else:
					var tileset_data = _attributes_to_dict(parser)
					var tileset_src = path.get_base_dir().plus_file(tileset_data.source) if tileset_data.source.is_rel_path() else tileset_data.source

					if tileset_src.extension() == "json":
						var f = File.new()
						err = f.open(tileset_src, File.READ)
						if err != OK:
							return "Couldn't open tileset file %s." % [tileset_src]

						var ts = {}
						err = ts.parse_json(f.get_as_text())
						if err != OK:
							return "Couldn't parse tileset file %s." % [tileset_src]

						ts.firstgid = int(tileset_data.firstgid)
						data.tilesets.push_back(ts)

					else:
						var tsparser = XMLParser.new()

						err = tsparser.open(tileset_src)
						if err != OK:
							return "Couldn't open tileset file %s." % [tileset_src]

						while err == OK:
							if tsparser.get_node_type() == XMLParser.NODE_ELEMENT:
								break
							err = tsparser.read()

						if err != OK:
							return "Error parsing tileset file %s." % [tileset_src]

						var ts = _parse_tileset(tsparser)
						ts.firstgid = int(tileset_data.firstgid)
						data.tilesets.push_back(ts)

			elif parser.get_node_name() == "layer":
				 data.layers.push_back(_parse_layer(parser))

			elif parser.get_node_name() == "imagelayer":
				 data.layers.push_back(_parse_imagelayer(parser))

			elif parser.get_node_name() == "objectgroup":
				data.layers.push_back(_parser_objectlayer(parser))


			elif parser.get_node_name() == "properties":
				var prop_data = _parse_properties(parser)
				if typeof(prop_data) == TYPE_STRING:
					return prop_data

				data.properties = prop_data.properties
				data.propertytypes = prop_data.propertytypes


		err = parser.read()

	return data


func _parse_tileset(parser):

	var err = OK
	var data = _attributes_to_dict(parser)
	data.tiles = {}

	err = parser.read()
	while err == OK:
		if parser.get_node_type() == XMLParser.NODE_ELEMENT_END:
			if parser.get_node_name() == "tileset":
				break
		elif parser.get_node_type() == XMLParser.NODE_ELEMENT:
			if parser.get_node_name() == "tile":
				var attr = _attributes_to_dict(parser)
				var tile_data = _parse_tile_data(parser)
				if typeof(tile_data) == TYPE_STRING:
					return tile_data
				data.tiles[str(attr.id)] = tile_data
			elif parser.get_node_name() == "image":
				var attr = _attributes_to_dict(parser)
				if not "source" in attr:
					return "Error loading image tag.\nNo source attribute found."
				data.image = attr.source
				data.imagewidth = attr.width
				data.imageheight = attr.height
			elif parser.get_node_name() == "properties":
				var prop_data = _parse_properties(parser)
				if typeof(prop_data) == TYPE_STRING:
					return prop_data

				data.properties = prop_data.properties
				data.propertytypes = prop_data.propertytypes

		err = parser.read()

	return data


func _parse_tile_data(parser):
	var err = OK
	var data = {}

	if parser.is_empty():
		return data

	err = parser.read()

	var obj_group = {}

	while err == OK:

		if parser.get_node_type() == XMLParser.NODE_ELEMENT_END:
			if parser.get_node_name() == "tile":
				return data
			elif parser.get_node_name() == "objectgroup":
				data.objectgroup = obj_group

		elif parser.get_node_type() == XMLParser.NODE_ELEMENT:
			if parser.get_node_name() == "image":
				# If there are multiple images in one tile we only use the last one.
				var attr = _attributes_to_dict(parser)
				if not "source" in attr:
					return "Error loading image tag.\nNo source attribute found."
				data.image = attr.source
			elif parser.get_node_name() == "objectgroup":
				obj_group = _attributes_to_dict(parser)
				for attr in ["width", "height", "offsetx", "offsety"]:
					if not attr in obj_group:
						data[attr] = 0
				if not "opacity" in data:
					data.opacity = 1
				if not "visible" in data:
					data.visible = true
				if parser.is_empty():
					data.objectgroup = obj_group
			elif parser.get_node_name() == "object":
				if not "objects" in obj_group:
					obj_group.objects = []
				var obj = _parse_object(parser)
				obj_group.objects.push_back(obj)

		err = parser.read()

	return data


func _parse_object(parser):
	var err = OK
	var data = _attributes_to_dict(parser)

	if not parser.is_empty():
		err = parser.read()
		while err == OK:

			if parser.get_node_type() == XMLParser.NODE_ELEMENT_END:
				if parser.get_node_name() == "object":
					break

			elif parser.get_node_type() == XMLParser.NODE_ELEMENT:
				if parser.get_node_name() == "ellipse":
					data.ellipse = true
				elif parser.get_node_name() == "polygon" or parser.get_node_name() == "polyline":
					var points = []
					var points_raw = parser.get_named_attribute_value("points").split(" ")

					for pr in points_raw:
						points.push_back({
							"x": float(pr.split(",")[0]),
							"y": float(pr.split(",")[1]),
						})

					data[parser.get_node_name()] = points

			err = parser.read()

	for attr in ["width", "height", "x", "y", "rotation"]:
		if not attr in data:
			data[attr] = 0
	if not "type" in data:
		data.type = ""
	if not "visible" in data:
		data.visible = true

	return data


func _parse_layer(parser):
	var err = OK
	var data = _attributes_to_dict(parser)
	data.type = "tilelayer"

	if not parser.is_empty():
		err = parser.read()

		while err == OK:
			if parser.get_node_type() == XMLParser.NODE_ELEMENT_END:
				if parser.get_node_name() == "layer":
					break

			elif parser.get_node_type() == XMLParser.NODE_ELEMENT:
				if parser.get_node_name() == "data":
					var attr = _attributes_to_dict(parser)

					if "compression" in attr:
						data.compression = attr.compression

					if "encoding" in attr:
						parser.read()

						if attr.encoding != "csv":
							data.encoding = attr.encoding
							data.data = parser.get_node_data().strip_edges()
						else:
							var csv = parser.get_node_data().split(",", false)
							data.data = []

							for v in csv:
								data.data.push_back(int(v.strip_edges()))
					else:
						data.data = []

				elif parser.get_node_name() == "tile":
					data.data.push_back(int(parser.get_named_attribute_value("gid")))

				elif parser.get_node_name() == "properties":
					var prop_data = _parse_properties(parser)
					if typeof(prop_data) == TYPE_STRING:
						return prop_data

					data.properties = prop_data.properties
					data.propertytypes = prop_data.propertytypes

			err = parser.read()

	return data

func _parse_imagelayer(parser):
	var err = OK
	var data = _attributes_to_dict(parser)
	data.type = "imagelayer"

	if not parser.is_empty():
		err = parser.read()

		while err == OK:
			if parser.get_node_type() == XMLParser.NODE_ELEMENT_END:
				if parser.get_node_name().to_lower() == "imagelayer":
					break
			elif parser.get_node_type() == XMLParser.NODE_ELEMENT:
				if parser.get_node_name().to_lower() == "image":
					var image = _attributes_to_dict(parser)
					if not image.has("source"):
						return "Missing source attribute in imagelayer";

					data.image = image.source
				elif parser.get_node_name() == "properties":
					var prop_data = _parse_properties(parser)
					if typeof(prop_data) == TYPE_STRING:
						return prop_data
					data.properties = prop_data.properties
					data.propertytypes = prop_data.propertytypes

			err = parser.read()

	return data

func _parser_objectlayer(parser):
	var err = OK
	var data = _attributes_to_dict(parser)
	data.type = "objectgroup"
	data.objects = []

	if not parser.is_empty():
		err = parser.read()
		while err == OK:
			if parser.get_node_type() == XMLParser.NODE_ELEMENT_END:
				if parser.get_node_name() == "objectgroup":
					break
			if parser.get_node_type() == XMLParser.NODE_ELEMENT:
				if parser.get_node_name() == "object":
					data.objects.push_back(_parse_object(parser))
				elif parser.get_node_name() == "properties":
					var prop_data = _parse_properties(parser)
					if typeof(prop_data) == TYPE_STRING:
						return prop_data
					data.properties = prop_data.properties
					data.propertytypes = prop_data.propertytypes

			err = parser.read()

	return data

# Parse custom properties
func _parse_properties(parser):
	var err = OK
	var data = {
		"properties": {},
		"propertytypes": {},
	}

	if not parser.is_empty():
		err = parser.read()

		while err == OK:
			if parser.get_node_type() == XMLParser.NODE_ELEMENT_END:
				if parser.get_node_name() == "properties":
					break
			elif parser.get_node_type() == XMLParser.NODE_ELEMENT:
				if parser.get_node_name() == "property":
					var prop_data = _attributes_to_dict(parser)
					if not (prop_data.has("name") and prop_data.has("value")):
						return "Missing information in custom properties"

					data.properties[prop_data.name] = prop_data.value
					if prop_data.has("type"):
						data.propertytypes[prop_data.name] = prop_data.type
					else:
						data.propertytypes[prop_data.name] = "string"

			err = parser.read()

	return data


func _attributes_to_dict(parser):
	var data = {}
	for i in range(parser.get_attribute_count()):
		var attr = parser.get_attribute_name(i)
		var val = parser.get_attribute_value(i)
		if val.is_valid_integer():
			val = int(val)
		elif val.is_valid_float():
			val = float(val)
		elif val == "true":
			val = true
		elif val == "false":
			val = false
		data[attr] = val
	return data
