# Tiled Map Importer

This is a plugin for [Godot Engine](https://godotengine.org) to import
`TileMap`s and `TileSet`s from the [Tiled Map Editor](http://www.mapeditor.org).

![](https://lut.im/uWPHymdSvs/l60C9UiVlrqK3bea.png)

## Installation

Simply download it from Godot Asset Library: https://godotengine.org/asset-library/asset/25.

Alternatively, download or clone this repository and copy the contents of the
`addons` folder to your own project's `addons` folder.

Then enable the plugin on the Project Settings.

## Features

* Import Tiled file as a Godot scene. Each layer in Tiled is a TileMap in Godot.
* Both `.tmx` (XML) and `.json` formats.
* Support for Base64 encoded map.
* Orthogonal and isometric maps.
* Import visibility and opacity from layers.
* Import collision/occluder/navigation shapes (based on Tiled object type).
* Custom import options, such as whether to embed the resources into the scene.
* Support for image layers
* Support for object layers, which are imported as StaticBody2D or LightOccluder2D
  for shapes (depending on the `type` property) and as Sprite for tiles.
* Custom properties for maps, layers, tilesets, and objects are imported as
  metadata.
* Support for post-import script.

## Usage

1. In Godot, click on menu Import -> TileMap from Tiled Editor.
2. Set the source Tiled file (either a `.json` or a `.tmx`).
3. Set the target destination scene.
4. Ajusted the desired options.
5. Press ok.

If no error occurs, the generated scene will be stored where you set it. The
TileSets will be on a relative folder or embedded, depending on the options.

## Caveats on Tiled maps

* Godot TileSets only have on collision shape, so the last found will overwrite
  the others.

* The same goes for navigation/occluder polygons.

* There's no Ellipse shape in Godot. If you use it as a collision object, it
  will be converted to a capsule shape, which may be imprecise. However, if the
  Tiled ellipse is a perfect circle, a CircleShape2D will be used instead.

* Set the type of the object to `navigation` or `occluder` to use it as such.

* Objects in object layer cannot be set as `navigation`.

* Only polygons can be used as occluder/navigation. For those, you can make a
  polygon or polyline in Tiled. Rectangles will be converted to polygons, but
  ellipses are not accepted.

* Occluder shapes are set as closed if a polygon is used and as open if it is
  a polyline.

* Godot has no decompression function (yet). So don't save the Tiled Map with
  any compressed format. "Base64 (uncompressed)" is also valid. You'll receive
  an error message if compressed data is detected.

## Options

### Post-import script

The selected script will have it's `post_import(scene)` method run. This
enables you to change the generated scene automatically upon each reimport.

The `post_import` method will receive the built scene and **must** return the
changed scene.

### Single TileSet

Save all Tiled tilesets a single Godot resource. If any of your layers uses
more than one tileset image, this is required otherwise it won't be generated
properly.

### Embed resources

Save all TileSets and images embedded in the target scene. Otherwise they will
be saved individually in the selected relative folder.

### Relative resource path

The relative path from the target scene where to save the resources
(images and tilesets).

### Image flags

The image flags to apply to all imported TileSet images.

### Create separate image directories

When the TileSet is a collection of images, this option tells tp create a new
directory with the TileSet name to hold all of the images.

### Custom properties

Whether or not to save the custom properties as metadata in the nodes and resources.


## License

[MIT License](LICENSE). Copyright (c) 2016 George Marques.
