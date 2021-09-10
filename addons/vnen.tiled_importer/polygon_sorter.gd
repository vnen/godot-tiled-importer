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

# Sorter for polygon vertices
tool
extends Reference

var center

# Sort the vertices of a convex polygon to clockwise order
# Receives a PoolVector2Array and returns a new one
func sort_polygon(vertices):
	vertices = Array(vertices)

	var centroid = Vector2()
	var size = vertices.size()

	for i in range(0, size):
		centroid += vertices[i]

	centroid /= size

	center = centroid
	vertices.sort_custom(self, "is_less")

	return PoolVector2Array(vertices)

# Sorter function, determines which of the poins should come first
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
