package ion
import "base:runtime"
import "core:slice"
import "core:container/small_array"
import "core:fmt"
import im "shared:odin-imgui"
import "vendor:glfw"
import b2 "vendor:box2d"

/*
This library will only account for box2d's entities editing

It only deals with one world_id, which means typically one level
*/

EditMode :: enum 
{
	ENTITY,
	VERTICES,
	OVERVIEW,
}

interface_state :: struct 
{
	entity_defs:     [dynamic]^engine_entity_def,
	entities:        [dynamic]^engine_entity,
	selected_entity: ^i32,
	world:           ^engine_world,
	state:           ^engine_state,
	
	vertex_index      : ^i32,
	edit_mode         : EditMode,
	
	curr_revolt_joint : revolt_joint_def,

	curr_joint_joint  : distance_joint_def,
	
	curr_static_index : static_index_global,
}

interface_body_def_editor :: proc(def: ^engine_entity_def)
{
	if im.BeginCombo("Body Type", fmt.ctprint(def.body_def.type)) 
	{
		for type in b2.BodyType 
		{
			if im.Selectable(fmt.ctprint(type), def.body_def.type == type) do def.body_def.type = type
		}
		im.EndCombo()
	}

	im.SliderFloat2("Position", &def.body_def.position, -50, 50)

	angle := RAD2DEG * b2.Rot_GetAngle(def.body_def.rotation)

	if im.SliderFloat("Rotation", &angle, 0, 359) 
	{
		rad := DEG2RAD * angle
		def.body_def.rotation = b2.MakeRot(rad)
	}

	im.SliderFloat2("Linear velocity", &def.body_def.linearVelocity, 0, 500)
	im.SliderFloat("Angular velocity", &def.body_def.angularVelocity, 0, 500)
	im.SliderFloat("Linear Damping", &def.body_def.linearDamping, 0, 500)
	im.SliderFloat("Angular Damping", &def.body_def.angularDamping, 0, 500)
	im.SliderFloat("Gravity Scale", &def.body_def.gravityScale, 0, 100)

	im.Checkbox("Fixed rotation", &def.body_def.fixedRotation)

	if im.InputText("Body Name", cstring(&def.name_buf[0]), 255) {
		def.body_def.name = cstring(&def.name_buf[0])
	}
}

interface_shape_def_editor :: proc(def: ^engine_entity_def) -> bool 
{
	shape_def := &def.shape_def
	

	if im.BeginCombo("Shape Type", fmt.ctprint(def.shape_type)) {

		for type in b2.ShapeType 
		{
			if im.Selectable(fmt.ctprint(type), def.shape_type == type) 
			{
				def.shape_type = type
			}
		}

		im.EndCombo()
	}

	switch def.shape_type {

	case .circleShape:
		{
			im.SliderFloat("radius", &def.radius, 0, 40)
		}

	case .polygonShape:
		{
			im.SliderFloat2("Size", &def.size, -500, 500)
		}

	case .capsuleShape:
		{
			im.SliderFloat2("Center 1", &def.centers[0], -100, 100)
			im.SliderFloat2("Center 2", &def.centers[0], -100, 100)
			im.SliderFloat("Radius", &def.radius, 0, 40)
		}

	case .chainSegmentShape:
		{
			im.Checkbox("is loop", &def.is_loop)
		}

	case .segmentShape:
		{
			//TODO
		}

	}

	im.SliderFloat("Density", &def.shape_def.density, 0, 100)

	if im.Button("Flip horizontally") do flip_points(small_array.slice(&def.vertices), .Horizontal)
	if im.Button("Flip Vertically ") do flip_points(small_array.slice(&def.vertices), .Vertical)

	if im.TreeNode("Events and contacts") {
		im.Checkbox("Is sensor", &def.shape_def.isSensor)
		im.Checkbox("Enable Sensor Events", &def.shape_def.enableSensorEvents)
		im.Checkbox("Enable Contact Events", &def.shape_def.enableContactEvents)
		im.Checkbox("Enable Hit Events", &def.shape_def.enableHitEvents)
		im.Checkbox("Enable Presolve Events", &def.shape_def.enablePreSolveEvents)
		im.Checkbox("Invoke contact Creation", &def.shape_def.invokeContactCreation)
		im.Checkbox("Update body mass ", &def.shape_def.updateBodyMass)
		im.TreePop()
	}

	if im.TreeNode("Material") {
		im.Separator()

		im.SliderFloat("Friction", &def.shape_def.material.friction, 0, 1)
		im.SliderFloat("Restitution", &def.shape_def.material.restitution, 0, 1)
		im.SliderFloat("Rolling Resistance", &def.shape_def.material.rollingResistance, 0, 1)
		im.SliderFloat("Tangent Speed", &def.shape_def.material.tangentSpeed, 0, 1)
		im.InputInt("User material id", &def.shape_def.material.userMaterialId)

		//Colorpicker

		if im.TreeNode("Color") {
			color_f32 := u32_to_float4(def.shape_def.material.customColor)

			if im.ColorPicker4("Custom Color", &color_f32, {.Uint8, .InputRGB}) {
				def.shape_def.material.customColor = float4_to_u32(color_f32)
			}
			im.TreePop()
		}

		im.Separator()
		im.TreePop()
	}

	return false
}

interface_draw_options :: proc(state: ^engine_state) {
	if im.BeginTabItem("Controls") {
		debug_draw := &state.draw.debug_draw

		im.Checkbox("Shapes", &debug_draw.drawShapes)
		im.Checkbox("Joints", &debug_draw.drawJoints)
		im.Checkbox("Joint Extras", &debug_draw.drawJointExtras)
		im.Checkbox("Bounds", &debug_draw.drawBounds)
		im.Checkbox("Contact Points", &debug_draw.drawContacts)
		im.Checkbox("Contact Normals", &debug_draw.drawContactNormals)
		im.Checkbox("Contact Inpulses", &debug_draw.drawContactImpulses)
		im.Checkbox("Contact Features", &debug_draw.drawContactFeatures)
		im.Checkbox("Friction Inpulses", &debug_draw.drawFrictionImpulses)
		im.Checkbox("Mass ", &debug_draw.drawMass)
		im.Checkbox("Body Names", &debug_draw.drawBodyNames)
		im.Checkbox("Graph Colors", &debug_draw.drawGraphColors)
		im.Checkbox("Islands ", &debug_draw.drawIslands)

		im.SliderFloat("Rotation", &state.draw.cam.rotation, 0, 360)

		im.EndTabItem()
	}
}

interface_edit_static_index :: proc(interface:^interface_state, def: ^engine_entity_def) -> bool
{
	
	curr_index  := &interface.curr_static_index
	entity := interface.entities[interface.selected_entity^] 
	
	level   := interface.world
	
	
	if level.relations[entity.index] == nil
	{
		level.relations[entity.index] = {}
	}
	
	indexes := &level.relations[entity.index]
	
	if im.InputInt("Index Value", &def.index) do return true
	
	ret := false
	
	if def.index != 0
	{
		//For now only select from current room
		
		if im.BeginCombo("Edit Select index", fmt.ctprint(curr_index.index))
		{
			for index in level.static_indexes
			{
				if im.Selectable(fmt.ctprint(index), curr_index.index == index)
				{
					curr_index.index = index
				}
			}
			im.EndCombo()
		}
		if curr_index.index != 0
		{
			if indexes != nil
			{
				if im.Button("Add relation")
				{
					if !slice.contains(indexes[:], interface.curr_static_index)
					{
						append(indexes, interface.curr_static_index)
					}
				}
			}
		}
		
		if indexes != nil{
			for val, i in indexes
			{
				im.Text("%d", val.index)
				im.SameLine()
				if im.Button("Delete") {
					ordered_remove(indexes, i)
				}
			}
		}
	}
	return false
}

interface_edit_revolute_joint :: proc(interface: ^interface_state) -> bool
{
	
	//Select static index and then get bodyId from it
	//If chain shapre then allow choosing index
	
	level := interface.world
	
	joint_def := &interface.curr_revolt_joint
	
	if im.BeginCombo("Index A", fmt.ctprint(joint_def.entity_a))
	{
		
		for i in level.static_indexes
		{
			if im.Selectable(fmt.ctprint(i), i == joint_def.entity_a)
			{
				joint_def.entity_a = i
			}
		}
		im.EndCombo()
	}
	
	im.Separator()
	
	if im.BeginCombo("Index B", fmt.ctprint(joint_def.entity_b))
	{
		
		for i in level.static_indexes
		{
			if im.Selectable(fmt.ctprint(i), i == joint_def.entity_b)
			{
				joint_def.entity_b = i
			}
		}
		im.EndCombo()
	}
	
	//Now box2d
	
	im.SliderFloat2("localAnchorA", &joint_def.localAnchorA, -5, 5)
	im.SliderFloat2("localAnchorB", &joint_def.localAnchorB, -5, 5)
	
	//Convert to degree to radian
	im.SliderFloat("Reference Angle", &joint_def.referenceAngle, 0, 100)
	im.SliderFloat("Target Angle",    &joint_def.targetAngle, 0, 100)
	
	im.Checkbox("Enable Spring", &joint_def.enableSpring)
	
	im.InputFloat("Hertz ", &joint_def.hertz)
	
	im.InputFloat("Damping Ratio", &joint_def.dampingRatio)
	
	im.Checkbox("Enable Limit", &joint_def.enableLimit)
	
	im.InputFloat("Lower Angle", &joint_def.lowerAngle)
	im.InputFloat("Upper Angle", &joint_def.upperAngle)
	
	im.Checkbox("Enable Motor", &joint_def.enableMotor)
	im.InputFloat("Moror Torque", &joint_def.maxMotorTorque)
	im.InputFloat("Moror Speed", &joint_def.motorSpeed)
	im.InputFloat("Draw Size", &joint_def.drawSize)
	im.Checkbox("Collide Connected", &joint_def.collideConnected)
	
	if im.Button("Add joint")
	{
		append(&level.revolute_joint_defs, interface.curr_revolt_joint)
		return true
	}
	
	
	return false
}


interface_entity :: proc(interface: ^interface_state) -> bool 
{
	
	entity_selected := interface.selected_entity^ != -1
	
	if entity_selected
	{
		def := interface.entity_defs[interface.selected_entity^]
		def_old := def^
		
		ret := false

		if im.BeginTabItem("Entity", nil, {.Leading}) 
		{
			
			//Flags
			for flag in engine_entity_flags_enum
			{
				contains := flag in def.entity_flags
				if im.Checkbox(fmt.ctprint(flag), &contains) 
				{
					def.entity_flags ~= {flag}
				}
			}
			
			im.Separator()

			if im.CollapsingHeader("Shape Edit") 
			{
				interface_shape_def_editor(def)
			}

			im.Separator()

			if im.CollapsingHeader("Body Edit") 
			{
				interface_body_def_editor(def)
			}
			
			if im.CollapsingHeader("Static Index")
			{
				ret |= interface_edit_static_index(interface, def)
			}
			
			im.EndTabItem()
		}
		
		if im.BeginTabItem("Joints", nil , {})
		{
			
			if im.CollapsingHeader("Revolute Joints")
			{
				ret |= interface_edit_revolute_joint(interface)
			}
			
			im.EndTabItem()
		}
		
		
		return def^ != def_old || ret
	}else{
		return false
	}
}

interface_all :: proc(interface: ^interface_state) -> bool 
{
	ret := false
	if im.Begin("Box2d interface") 
	{
		if im.BeginTabBar("Tabs") 
		{
			if interface_entity(interface) do ret = true
			
			interface_draw_options(interface.state)
			im.EndTabBar()
		}
	}
	im.End()
	return ret
}
