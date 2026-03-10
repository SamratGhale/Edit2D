package ion

import b2 "vendor:box2d"
import array "core:container/small_array"

static_index :: i32

static_index_global :: struct 
{
	index : i32,
	level : string,
	offset : b2.Vec2,
}

/*
	This file contains code to handle box2d stuffs of the game code
	Don't put game's logic here
*/

revolt_joint_def :: struct 
{
	using def : b2.RevoluteJointDef,
	
	//Everything else can be stored in the def
	entity_a, entity_b : static_index, 
}

distance_joint_def :: struct 
{
	using def : b2.DistanceJointDef,
	
	//Everything else can be stored in the def
	entity_a, entity_b : static_index, 
}

engine_world :: struct 
{
	world_id : b2.WorldId,
	
	//This in engine code?
	static_indexes          : map[static_index]int `cbor:"-"`,
	relations               : map[^static_index][dynamic]static_index_global `cbor:"-"`,
	relations_serializeable : map[ static_index][dynamic]static_index_global,
	
	revolute_joint_defs     : [dynamic]revolt_joint_def,
	distant_joint_defs      : [dynamic]distance_joint_def,
	
	revolute_joints         : [dynamic]b2.JointId,
}

engine_entity_flags_enum :: enum u64 {
	POLYGON_IS_BOX,
	MULTI_BODIES,
	MULTI_SHAPES,
}

engine_entity_flags :: bit_set[engine_entity_flags_enum]

engine_entity_def :: struct {
	body_def   : b2.BodyDef,
	shape_def  : b2.ShapeDef,
	shape_type : b2.ShapeType,
	
	
	radius, scale : f32,
	centers       : [2]b2.Vec2,
	size          : b2.Vec2,
	is_loop       : bool,
	vertices      : array.Small_Array(b2.MAX_POLYGON_VERTICES, b2.Vec2),
	name_buf      : [255]u8 `fmt:"-" cbor:"-"`,
	
	entity_flags  : engine_entity_flags,
	
	index         : static_index,
	
	body_count    : int,
}

engine_entity  :: struct {
	body_id       : b2.BodyId,
	shape_id      : b2.ShapeId,
	
	//This is if the entity has multiple bodies
	bodies        : [dynamic]b2.BodyId,
	shapes        : [dynamic]b2.ShapeId,
	joints        : [dynamic]b2.JointId,
	entity_flags  : engine_entity_flags,
	index         : ^static_index,
} 



engine_entity_single_body :: proc(def : ^engine_entity_def, world_id: b2.WorldId, index : i32) -> engine_entity
{
	
	def := def
	
	new_entity : engine_entity
	
	
	if def.index != 0
	{
		new_entity.index  = new(static_index)
		new_entity.index^ = def.index
	}
	
	new_entity.body_id = b2.CreateBody(world_id, def.body_def)
	
	switch def.shape_type{
	
	case .circleShape:
		{
			def.radius *= def.scale
			circle := b2.Circle{ radius = def.radius }
			
			def.scale = 1
			
			new_entity.shape_id = b2.CreateCircleShape(new_entity.body_id, def.shape_def, circle)
		}
		
	case .capsuleShape:
		{
			def.radius     *= def.scale
			def.centers[0] *= def.scale
			def.centers[1] *= def.scale
			
			def.scale = 1
			
			capsule := b2.Capsule{
				center1 = def.centers[0], 
				center2 = def.centers[1], 
				radius = def.radius
			}
			
			new_entity.shape_id = b2.CreateCapsuleShape(
				new_entity.body_id,
				def.shape_def,
				capsule
			)
		}
	case .chainSegmentShape:
		{
			chain_def := b2.DefaultChainDef()
			verts :[dynamic]b2.Vec2
			
			for &v in array.slice(&def.vertices){
				v *= def.scale
			}
			
			
			for v in array.slice(&def.vertices){
				//If it's not a looped chain then it needs two defination
				
				if !def.is_loop do append(&verts, v)
				
				append(&verts, v)
			}
			
			slice := array.slice(&def.vertices)
			
			chain_def.points = &verts[0]
			chain_def.count = i32(len(verts))
			chain_def.isLoop = def.is_loop
			
			c := b2.CreateChain(new_entity.body_id, chain_def)
			
			shapes_data :[10]b2.ShapeId
			shapes := b2.Body_GetShapes(new_entity.body_id, shapes_data[:])
			
			for shape in shapes{
				b2.Shape_SetUserData(shape, rawptr(uintptr(index)))
			}
			
			def.scale = 1
			
			
		}	
	case .segmentShape:
		{
			for &v in array.slice(&def.vertices){
				v *= def.scale
			}
			segment : b2.Segment = {point1 = array.get(def.vertices, 0), point2 = array.get(def.vertices, 2)}
			
			new_entity.shape_id = b2.CreateSegmentShape(new_entity.body_id, def.shape_def, segment)
			def.scale = 1
			
		}
	case .polygonShape:
		{
			poly : b2.Polygon
			
			if .POLYGON_IS_BOX in def.entity_flags
			{
				def.size *= def.scale
				poly      = b2.MakeBox(def.size.x, def.size.y)
				def.scale = 1
			}else
			{
				//def.size *= def.scale
				
				for &v in array.slice(&def.vertices){
					v *= def.scale
				}
				
				points := make([dynamic]b2.Vec2, 0)
				
				for p, i in array.slice(&def.vertices){
					if i >= int(def.vertices.len) do break
					append_elem(&points, p)
				}
				sort_points_ccw(points[:])
				
				hull := b2.ComputeHull(points[:])
				poly = b2.MakePolygon(hull, 0)
				delete(points)
				def.scale = 1
			}
			new_entity.shape_id = b2.CreatePolygonShape(new_entity.body_id, def.shape_def, poly)
		}
	
	}
	
	if def.shape_type != .chainSegmentShape{
		b2.Shape_SetUserData(new_entity.shape_id, rawptr(uintptr(index)))
	}
	
	return new_entity
}








