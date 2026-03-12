package ion

import "core:fmt"
import b2 "vendor:box2d"
import im "shared:odin-imgui"

/*
  TODO:
    Delete joints
    Angles in degree
*/

/*
  All joints have bodyIdA and bodyIdB
*/
interface_edit_joint_common :: proc(joint_def : ^joint_common, interface: ^interface_state) -> bool
{
  level                    := interface.world
  {
    if joint_def.entity_a in  level.static_indexes{
      entity_a := interface.entity_defs[level.static_indexes[joint_def.entity_a]] 
      points_add(&interface.state.draw.points, entity_a.body_def.position, 20.0, b2.HexColor.Plum)
    }
    if joint_def.entity_b in  level.static_indexes{
      entity_b := interface.entity_defs[level.static_indexes[joint_def.entity_b]] 
      points_add(&interface.state.draw.points, entity_b.body_def.position, 20.0, b2.HexColor.Plum)
    }
  }

  /*
    Set body A and Body B on the basis of static index so that it can pesist after restart
  */

  if im.BeginCombo("Index A", fmt.ctprint(joint_def.entity_a))
  {
    for i in level.static_indexes
    {
      if im.Selectable(fmt.ctprint(i), i == joint_def.entity_a) do joint_def.entity_a = i
    }
    im.EndCombo()
  }
  
  im.Separator()
  
  if im.BeginCombo("Index B", fmt.ctprint(joint_def.entity_b))
  {
    for i in level.static_indexes
    {
      if im.Selectable(fmt.ctprint(i), i == joint_def.entity_b) do joint_def.entity_b = i
    }
    im.EndCombo()
  }
  return false
}


interface_edit_distance_joint :: proc( interface : ^interface_state ) -> bool
{
  level                    := interface.world
  interface.curr_joint_type = .distanceJoint

  if len(level.distant_joint_defs) == 0 do im.Text("No distance joint created, Click add to create new")

  if im.Button("Create new joint")
  {
    append(&level.distant_joint_defs, distance_joint_def{def = b2.DefaultDistanceJointDef()})

    interface.curr_joint_index = i32(len(level.distant_joint_defs))
  }

  //Select index
  {
    if im.BeginCombo("Select joint", fmt.ctprint(interface.curr_joint_index))
    {
      for i in 0..<len(level.distant_joint_defs){
        if im.Selectable(fmt.ctprint(i), i32(i) == interface.curr_joint_index) do interface.curr_joint_index = i32(i)
      }
      im.EndCombo()
    }
  }

  if interface.curr_joint_index >= i32(len(level.distant_joint_defs)) do return false

  joint_def := &level.distant_joint_defs[interface.curr_joint_index]
  old_def   := joint_def^

  if interface_edit_joint_common(cast(^joint_common)joint_def, interface) do return true

  /*
    Highlight the bodies here 
  */

  im.SliderFloat2("localAnchorA",  &joint_def.localAnchorA, -5, 5)
  im.SliderFloat2("localAnchorB",  &joint_def.localAnchorB, -5, 5)
  im.SliderFloat("Rest length",    &joint_def.length, 0, 100)
  im.Checkbox("Enable Spring",     &joint_def.enableSpring)
  im.InputFloat("Hertz ",          &joint_def.hertz)
  im.InputFloat("Damping Ratio",   &joint_def.dampingRatio)
  im.Checkbox("Enable Limit",      &joint_def.enableLimit)
  im.InputFloat("Min length",      &joint_def.minLength)
  im.InputFloat("Max length",      &joint_def.maxLength)
  im.Checkbox("Enable Motor",      &joint_def.enableMotor)
  im.InputFloat("Moror Torque",    &joint_def.maxMotorForce)
  im.InputFloat("Moror Speed",     &joint_def.motorSpeed)
  im.Checkbox("Collide Connected", &joint_def.collideConnected)
  
  return old_def != joint_def^
}


interface_edit_revolute_joint :: proc( interface : ^interface_state ) -> bool
{
  level                    := interface.world
  interface.curr_joint_type = .revoluteJoint

  if len(level.revolute_joint_defs) == 0 do im.Text("No revolute joint created, Click add to create new")

  if im.Button("Create new joint")
  {
    append(&level.revolute_joint_defs, revolt_joint_def{def = b2.DefaultRevoluteJointDef()})

    interface.curr_joint_index = i32(len(level.revolute_joint_defs))
  }

  //Select index
  if im.BeginCombo("Select joint", fmt.ctprint(interface.curr_joint_index))
  {
    for i in 0..<len(level.revolute_joint_defs){
      if im.Selectable(fmt.ctprint(i), i32(i) == interface.curr_joint_index) do interface.curr_joint_index = i32(i)
    }
    im.EndCombo()
  }

  if interface.curr_joint_index >= i32(len(level.revolute_joint_defs)) do return false

  joint_def := &level.revolute_joint_defs[interface.curr_joint_index]
  old_def   := joint_def^

  if interface_edit_joint_common(cast(^joint_common)joint_def, interface) do return true

  /*
    Highlight the bodies here 
  */

  im.SliderFloat2("localAnchorA",  &joint_def.localAnchorA, -5, 5)
  im.SliderFloat2("localAnchorB",  &joint_def.localAnchorB, -5, 5)
  im.SliderFloat("Refresh angle",  &joint_def.referenceAngle, 0, 100)
  im.SliderFloat("Target  angle",  &joint_def.targetAngle, 0, 100)
  im.Checkbox("Enable Spring",     &joint_def.enableSpring)
  im.InputFloat("Hertz ",          &joint_def.hertz)
  im.InputFloat("Damping Ratio",   &joint_def.dampingRatio)
  im.InputFloat("Lower Angle",     &joint_def.lowerAngle)
  im.InputFloat("Upper Angle",     &joint_def.upperAngle)
  im.InputFloat("Max Motor Limit", &joint_def.maxMotorTorque)
  im.InputFloat("Motor Speed",     &joint_def.motorSpeed)
  im.InputFloat("Draw Size",       &joint_def.drawSize)
  im.Checkbox("Enable Motor",      &joint_def.enableMotor)
  im.Checkbox("Enable Limit",      &joint_def.enableLimit)
  im.Checkbox("Collide Connected", &joint_def.collideConnected)
  
  return old_def != joint_def^
}