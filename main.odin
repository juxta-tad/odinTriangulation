package main

import "core:math/rand"
import "core:slice"
import rl "vendor:raylib"


screenWidth  :: 800
screenHeight :: 600

Point :: struct {
	X, Y : f32,
}

Edge :: struct {
	A, B : Point
}

Triangle ::  struct {
	A, B, C : Point,
}

DelaunayTriangulation :: proc(points : [dynamic]Point) ->  [dynamic]Triangle {
	// Sort points by X coordinate
	slice.sort_by(points[:], proc(i, j : Point) -> bool{
		return (i.X < j.X)
	})
	
	superTriangle := createSuperTriangle(points)
	triangles := [dynamic]Triangle{superTriangle}

	for point in points {
		badTriangles := make([dynamic]Triangle, 0)

		for triangle in triangles {
			if pointInsideCircumcircle(point, triangle) {
				append(&badTriangles, triangle)
			}
		}

		polygon := make([dynamic]Edge, 0)
		for triangle in badTriangles {
			for edge in triangleEdges(triangle) {
				if isEdgeShared(edge, badTriangles) {
					append(&polygon, edge)
				}
			}
		}

		triangles = removeBadTriangles(triangles, badTriangles)

		for edge in polygon {
			triangle := Triangle{edge.A, edge.B, point}
			append(&triangles, triangle)
		}
	}

	triangles = removeSuperTriangle(triangles, superTriangle)

	return triangles
}

createSuperTriangle :: proc(points : [dynamic]Point) -> Triangle {
	minX, minY := points[0].X, points[0].Y
	maxX, maxY := points[0].X, points[0].Y

	for point in points {
		if point.X < minX {
			minX = point.X
		}
		if point.X > maxX {
			maxX = point.X
		}
		if point.Y < minY {
			minY = point.Y
		}
		if point.Y > maxY {
			maxY = point.Y
		}
	}

	delta := max(maxX-minX, maxY-minY)
	midX := (minX + maxX) / 2
	midY := (minY + maxY) / 2
	sideLength := 2 * delta
	superTriangle := Triangle{
		Point{midX, midY + sideLength},
		Point{midX - sideLength, midY - sideLength},
		Point{midX + sideLength, midY - sideLength},
	}

	return superTriangle
}

pointInsideCircumcircle :: proc(point : Point, triangle : Triangle) -> bool {
	ax, ay := triangle.A.X, triangle.A.Y
	bx, by := triangle.B.X, triangle.B.Y
	cx, cy := triangle.C.X, triangle.C.Y
	d := 2 * (ax*(by-cy) + bx*(cy-ay) + cx*(ay-by))
	ux := ((ax*ax+ay*ay)*(by-cy) + (bx*bx+by*by)*(cy-ay) + (cx*cx+cy*cy)*(ay-by)) / d
	uy := ((ax*ax+ay*ay)*(cx-bx) + (bx*bx+by*by)*(ax-cx) + (cx*cx+cy*cy)*(bx-ax)) / d
	r := ((ax-ux)*(ax-ux) + (ay-uy)*(ay-uy))

	px, py := point.X, point.Y
	distance := ((px-ux)*(px-ux) + (py-uy)*(py-uy))

	return distance <= r
}

isEdgeShared :: proc(edge :Edge, triangles : [dynamic]Triangle) -> bool {
	count := 0
	for triangle in triangles {
		if (edge.A == triangle.A || edge.A == triangle.B || edge.A == triangle.C) &&
			(edge.B == triangle.A || edge.B == triangle.B || edge.B == triangle.C) {
			count+=1
		}
	}
	return count == 1
}

triangleEdges :: proc (triangle : Triangle) -> [dynamic]Edge {
	a, b, c := triangle.A, triangle.B, triangle.C
	edges := [dynamic]Edge{{a, b}, {b, c}, {c, a}}
	return edges
}

removeBadTriangles :: proc(triangles, badTriangles : [dynamic]Triangle) -> [dynamic]Triangle {
	remainingTriangles := make([dynamic]Triangle, 0)
	for triangle in triangles {
		if !containsTriangle(badTriangles, triangle) {
			append(&remainingTriangles, triangle)
		}
	}
	return remainingTriangles
}

removeSuperTriangle :: proc(triangles : [dynamic]Triangle, superTriangle : Triangle) -> [dynamic]Triangle {
	remainingTriangles := make([dynamic]Triangle, 0)
	for triangle in triangles {
		if !containsPoint(superTriangle.A, triangle) &&
			!containsPoint(superTriangle.B, triangle) &&
			!containsPoint(superTriangle.C, triangle) {
			append(&remainingTriangles, triangle)
		}
	}
	return remainingTriangles
}

containsTriangle :: proc(triangles : [dynamic]Triangle, target : Triangle) -> bool {
	for triangle in triangles {
		if triangle == target {
			return true
		}
	}
	return false
}

containsPoint :: proc(point : Point, triangle : Triangle) -> bool {
	return point == triangle.A || point == triangle.B || point == triangle.C
}

countConnections :: proc(triangles : [dynamic]Triangle) -> map[Point]int {
	connections := make(map[Point]int)
	for triangle in triangles {
		connections[triangle.A]+=1
		connections[triangle.B]+=1
		connections[triangle.C]+=1
	}
	return connections
}

main :: proc() {
	points := make([dynamic]Point, 0)
	triangles := make([dynamic]Triangle, 0)
	connections := make(map[Point]int)

	// Generate random points
	for i := 0; i < 8; i+=1 {
		x := f32(rand.int_max(screenWidth-100) + 50)
		y := f32(rand.int_max(screenHeight-100) + 50)
		append(&points, Point{x, y})
	}

	// Compute Delaunay triangulation
	triangles = DelaunayTriangulation(points)
	connections = countConnections(triangles)

	// Initialize Raylib
	rl.InitWindow(screenWidth, screenHeight,"triangulation")
	rl.SetTargetFPS(60)

	for !rl.WindowShouldClose() {
		rl.BeginDrawing()

		rl.ClearBackground(rl.WHITE)

		// Draw triangles
		for triangle in triangles {
			rl.DrawLine(i32(triangle.A.X), i32(triangle.A.Y), i32(triangle.B.X), i32(triangle.B.Y), rl.BLUE)
			rl.DrawLine(i32(triangle.B.X), i32(triangle.B.Y), i32(triangle.C.X), i32(triangle.C.Y), rl.BLUE)
			rl.DrawLine(i32(triangle.C.X), i32(triangle.C.Y), i32(triangle.A.X), i32(triangle.A.Y), rl.BLUE)
		}

		// Draw connections
		for point, count in connections {
			rl.DrawCircle(i32(point.X), i32(point.Y), 3, rl.RED)
			rl.DrawText(rl.TextFormat("%d", count), i32(point.X)-8, i32(point.Y)+10, 10, rl.BLACK)
		}

		rl.EndDrawing()
	}

	rl.CloseWindow()
}