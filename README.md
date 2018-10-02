# Tiled Map Importer

This is a plugin for [Godot Engine](https://godotengine.org) to import
`TileMap`s and `TileSet`s from the [Tiled Map Editor](http://www.mapeditor.org).

**Note: This is compatible only with Godot 3.0 or later. For Godot 2.x, use the [1.x branch](https://github.com/vnen/godot-tiled-importer/tree/1.x).**

[![ko-fi](https://www.ko-fi.com/img/donate_sm.png)](https://ko-fi.com/P5P1GZ0P)
If you like what I do, please consider buying me a coffee on [Ko-fi](https://ko-fi.com/georgemarques).

<img src="https://user-images.githubusercontent.com/5599796/35366974-29dd3a98-0163-11e8-844b-fcae103b3aa6.png" width="300">
<img src="https://user-images.githubusercontent.com/5599796/35366991-33a8acf6-0163-11e8-8515-1d457bf68d2b.png" width="300">
<img src="https://user-images.githubusercontent.com/5599796/35366983-2d69967a-0163-11e8-87e1-32a2b26a76e8.png" width="300">
<img src="https://user-images.githubusercontent.com/5599796/35366992-369c0cf0-0163-11e8-8008-b8dad1fb5d7f.png" width="300">

## Installation

Simply download it from Godot Asset Library: https://godotengine.org/asset-library/asset/158.

Alternatively, download or clone this repository and copy the contents of the
`addons` folder to your own project's `addons` folder.

Then enable the plugin on the Project Settings.

## Features

* Import Tiled file as a Godot scene. Each layer in Tiled is a TileMap in Godot.
* Import TileSets from Tiled standalone tileset files.
* Both `.tmx` (XML) and `.json` formats for maps.
* Both `.tsx` (XML) and `.json` formats for tilesets.
* Support for Base64 encoded map.
* Support for layer compression, both `zlib` and `gzip` are supported.
* Object templates.
* Orthogonal, isometric, staggered, and hexagonal maps.
* Import visibility and opacity from layers.
* Import collision/occluder/navigation shapes (based on Tiled object type).
* Support for one-way collision shapes.
* Custom import options, such as whether to enable UV clip.
* Support for image layers.
* Support for object layers, which are imported as StaticBody2D, Area2D or LightOccluder2D
  for shapes (depending on the `type` property) and as Sprite for tiles.
* Support for group layers, which are imported as `Node2D`s.
* Custom properties for maps, layers, tilesets, and objects are imported as
  metadata. Custom properties on tiles can be imported into the TileSet resource.
* Map background imported as a parallax background (so it's virtually infinite)
* Support for post-import script.

## Usage (once the plugin is enabled)

1. Place your maps inside your project.
2. Watch Godot import it automatically.

The map file can be used as if it were a scene, but you can not edit it in Godot.
If you need to make changes, create an inherited scene or instance the map in
another scene.

Whenever you make a change to the map in Tiled, Godot will reimport the scene and
update it in the editor if it's open.

If the file can't be imported, an error message will be generated in the output.
Please check the output if you are having an issue.

Note that if you are using external tilesets, they will also be imported, which may
increase the final export size of your project. To mitigate that, you can exclude
those files from the export or put them in a folder alongside a `.gdignore` file so
they are not even imported.

**Note:** If you have other `.json` files in your project, this plugin will try to
import them and fail. There's an option in the Project Settings to disable the JSON
format and avoid this. If you need to use JSON format for Tiled files, consider putting
the non-Tiled JSON files in a folder alongside a `.gdignore` file so Godot won't try
to import them.

Find more useage information on the [Wiki](https://github.com/vnen/godot-tiled-importer/wiki).

## Caveats on Tiled maps

* Godot TileSets only have one navigation and one occluder per tile, so the last found
  will overwrite the others.

* There's no Ellipse shape in Godot. If you use it as a collision object, it
  will be converted to a capsule shape, which may be imprecise. However, if the
  Tiled ellipse is a perfect circle, a CircleShape2D will be used instead.

* Set the type of the object to `area`, `navigation` or `occluder` to use it as such.

* Set the type of the object to `one-way` to mark it as a one-way shape in Godot
(both on tile and on object layers).

* Objects in object layer cannot be set as `navigation`.

* Only polygons can be used as occluder/navigation. For those, you can make a
  polygon or polyline in Tiled. Rectangles will be converted to polygons, but
  ellipses are not accepted.

* Occluder shapes are set as closed if a polygon is used and as open if it is
  a polyline.

* For isometric maps, the collision shapes and objects likely will be out of place,
  because Tiled applies the isometric transform to everything.

## Import system caveats

* If you are embedding images, changing them won't trigger a reimport of the map.

* If you are using external tile sets in Tiled, changing the tile set won't
trigger a reimport.

* Essentially, every change you do that doesn't directly change the source Tiled
map, won't trigger the automatic reimport. In this case you can manually reimport
if needed.

## Options (Maps and TileSets)

There are two import presets: `Default` and `Pixel Art`. The difference is that
the `Pixel Art` preset don't use any flag for the texture, disabling filter,
mipmaps, and repeat.

Because it overrides the image flags, it also embed internal images by default,
otherwise it won't make a difference. If you want to avoid that, use the Default
preset and import your images without flags.

Note that you can set a different default preset on Godot.

**In the Project Settings, there's a `Tiled Importer` section with settings related
to this plugin.** Currently it's only used so you can disable the JSON format if
needed.

### Custom Properties

**Default: `On`**

Whether or not to save the custom properties as metadata in the nodes and resources.

### Tile Metadata

**Default: `Off`**

Whether or not to save the tile metadata into the TileSet resource. It will be set
as a dictionary named `tile_meta` where the key is the tile global id (the same id
used in the Godot TileMap).

### Uv Clip (Map only)

**Default: `On`**

Enable the Clip Uv (Filter Clip on Sprites) to avoid image bleeding on tiles.

### Image Flags

**Default: `Mipmaps, Repeat, Filter`** (Note: this is set as `Texture.FLAGS_DEFAULT`)

The image flags to apply to all imported TileSet images. This will only work if images
are embedded, otherwise they will use the flags from their own import settings.

### Collision Layer (Map only)

**Default: `1`**

The collision layer for the maps and objects imported. If you need custom layers for
each object, consider using a post-import script.

### Embed Internal Images

**Default: `Off`**

By default, if an image is inside the project, it won't be reimported. If this option
is enabled, the images will be embedded into the imported scene. This is useful if you
need to use the image somewhere else with different import settings.

### Save Tiled Properties

**Default: `Off`**

Save the regular properties from Tiled inside the objects as metadata. They will be
placed alongside the custom properties.

**Note:** Not *all* properties from the file are saved, only the ones you can see on
Tiled interface.

### Add Background (Map only)

**Default: `On`**

Add a parallax background to make the map background color from Tiled. This option is
irrelevant if there's no map background color defined in the Tiled map.

### Apply Offset (Tileset only)

**Default `Off`**

Tilesets on Tiled use the bottom-left as origin, while Godot uses top-left. This option
applies an offset to the tileset to make this consistent. It is applied by default on maps
to sort out the positioning of everything, but for Tileset importing this is optional.

### Post-import script

**Default: `None`**

The selected script will have it's `post_import(scene)` method run. This
enables you to change the generated scene automatically upon each reimport.

The `post_import` method will receive the built scene (or TileSet) and **must**
return the changed scene (or TileSet).

## License

[MIT License](LICENSE). Copyright (c) 2018 George Marques.
