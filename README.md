# Eneroth SVG Exporter

Create scaled 2D top view SVG export of selected entities.
Useful for small exports, like signage in a scale model, where the native SketchUp vector exporter fails.
To precisely control the extents of the exported file, you may include a hidden "backdrop" rectangle in the selection.

Activated from **Extensions > Eneroth SVG Exporter**.

## For developers

This is an [open source extension](https://github.com/Eneroth3/eneroth-svg-exporter),
showcasing some concepts you can use in your own work:

* Scale input
* Traversing/walking the model
* Resolving visibility and material inheritance using "backtrace"
* Maybe some transformation magic
