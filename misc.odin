package ion

import "core:slice"
import b2 "vendor:box2d"


saturate :: proc(f : f32) -> f32 {
	return (f < 0.0) ? 0.0 : (f > 1.0) ? 1.0 : f
}

f32_to_u8_sat :: proc(val : f32) -> u8 {

	sat := saturate(val)
	sat *= 255
	sat += 0.5

	ret := cast(u8)sat
	return ret
}


float4_to_u32 :: proc(color : [4]f32) -> u32 {
	out : u32
	out = u32(f32_to_u8_sat(color.a)) << 24
	out |= u32(f32_to_u8_sat(color.r)) << 16
	out |= u32(f32_to_u8_sat(color.g)) << 8
	out |= u32(f32_to_u8_sat(color.b))
	return out
}


u32_to_float4 :: proc(color : u32) -> [4]f32 {
	ret : [4]f32
	ret.a = f32((color >> 24) & 0xFF) / 255.0
	ret.r = f32((color >> 16) & 0xFF) / 255.0
	ret.g = f32((color >> 8) & 0xFF) / 255.0
	ret.b = f32((color) & 0xFF) / 255.0
	return ret
}



centroid :: proc(points: []b2.Vec2) -> b2.Vec2{
	center := b2.Vec2{0,0}
	for p in points do center += p
	center /= f32(len(points))
	return center
}


cross :: proc(o, a, b : b2.Vec2) -> f32{
	return (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x)
}

//For sorting
curr_center : b2.Vec2

sort_points_ccw :: proc(points : []b2.Vec2){
	if len(points) == 0 do return

	curr_center = centroid(points)
	slice.sort_by(points , proc(a, b: b2.Vec2) -> bool{
		c := cross(curr_center, a, b)

		if abs(c) < 1e-7{
   return b2.Distance(curr_center, a) < b2.Distance(curr_center, b)
		}
		return c > 0
	})
}

FlipDirection :: enum {
	Horizontal,
	Vertical,
	Both,  // Flip both horizontally and vertically
}


flip_points :: proc(points: []b2.Vec2, direction : FlipDirection){
	for &vertex, i in points{
		switch direction {
		case .Horizontal:
			points[i] = b2.Vec2{-vertex.x, vertex.y}
		case .Vertical:
			points[i] = b2.Vec2{vertex.x, -vertex.y}
		case .Both:
			points[i] = b2.Vec2{-vertex.x, -vertex.y}
		}
	}
}
