package ion


import "core:encoding/cbor"
import im "shared:odin-imgui"
import "shared:odin-imgui/imgui_impl_glfw"
import "shared:odin-imgui/imgui_impl_opengl3"
import gl "vendor:OpenGL"
import "vendor:glfw"



engine_state :: struct 
{
	window : glfw.WindowHandle,
	draw   : Draw,
	restart, pause : bool,
	substep_count  : u32,
	
	//Must be set before calling ion_init
	width, height  : i32,
	title          : cstring,
	time           : f32,
	tex_line       : u32,
	drop_callback  : glfw.DropProc,
	
	input          : input_state,
}

MAX_KEYS :: 512

input_state :: struct 
{
	mouse_wheel : [2]f64,
	mouse       : [2]f64,
	mouse_prev  : [2]f64,

	curr, prev : [MAX_KEYS]bool,
}

/*
	This will only be called once to initilize the engine
	initilize graphics library, glfw, callbacks
*/
engine_init :: proc(state: ^engine_state) 
{
	
	assert(glfw.Init() == true)
	
	glfw.WindowHint(glfw.SCALE_TO_MONITOR, 1)
	
	state.window = glfw.CreateWindow(state.width, state.height, state.title, nil, nil)
	
	assert(state.window != nil)
	
	glfw.MakeContextCurrent(state.window)
	glfw.SwapInterval(1)
	gl.load_up_to(4, 5, glfw.gl_set_proc_address)
	
	im.CHECKVERSION()
	im.CreateContext()
	
	io := im.GetIO()
	
	io.ConfigFlags += {
		.NavEnableKeyboard,
		.NavEnableGamepad,
		.DpiEnableScaleFonts,
	}
	
	
	im.StyleColorsClassic()
	
	style := im.GetStyle()
	style.ChildBorderSize = 0.
	style.ChildRounding   = 6
	style.TabRounding     = 6
	style.FrameRounding   = 6
	style.GrabRounding    = 6
	style.WindowRounding  = 6
	style.PopupRounding   = 6
	
	imgui_impl_glfw.InitForOpenGL(state.window, true)
	imgui_impl_opengl3.Init("#version 150")
	
	state.draw.cam = camera_init()
	
	display_w, display_h := glfw.GetFramebufferSize(state.window)
	state.draw.cam.width  = display_w
	state.draw.cam.height = display_h
	state.draw.cam.zoom   = 15
	state.draw.show_ui    = true
	
	draw_create(&state.draw, &state.draw.cam)
	
	cbor.tag_register_type({
		marshal = proc(_: ^cbor.Tag_Implementation, e: cbor.Encoder, v: any) -> cbor.Marshal_Error {
			cbor._encode_u8(e.writer, 201, .Tag) or_return
			return nil;
		},
		unmarshal = proc(_: ^cbor.Tag_Implementation, d: cbor.Decoder, _: cbor.Tag_Number, v: any) -> (cbor.Unmarshal_Error) {
			return nil
		},
	}, 201, rawptr)
}

update_frame :: proc(state: ^engine_state)
{
	state.input.mouse_wheel = {}
	glfw.PollEvents()
	
	keyboard_update(state)
	
	gl.ClearColor(0.4, 0.5, 0.6, 1.0)
	gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)
	
	cam := &state.draw.cam
	cam.width, cam.height = glfw.GetWindowSize(state.window)
	
	state.width , state.height = glfw.GetFramebufferSize(state.window)
	gl.Viewport(0, 0, state.width, state.height)
	
	imgui_impl_opengl3.NewFrame()
	imgui_impl_glfw.NewFrame()
	im.NewFrame()
}

end_frame :: proc(state: ^engine_state)
{
	im.Render()
	imgui_impl_opengl3.RenderDrawData(im.GetDrawData())
	glfw.SwapBuffers(state.window)
}

cleanup :: proc(state: ^engine_state)
{
	imgui_impl_opengl3.Shutdown()
	imgui_impl_glfw.Shutdown()
}

engine_should_close :: proc(state : ^engine_state) -> b32
{
	return glfw.WindowShouldClose(state.window)
}


keyboard_update :: proc(state: ^engine_state)
{
	state.input.mouse_prev = state.input.mouse
	
	state.input.mouse.x, state.input.mouse.y = glfw.GetCursorPos(state.window)
	
	state.input.prev       = state.input.curr
	
	//Update current states
	
	for key in glfw.KEY_SPACE ..< MAX_KEYS
	{
		state.input.curr[key] = glfw.GetKey(state.window, i32(key)) == glfw.PRESS
	}
	
	for key in 0..<glfw.KEY_SPACE
	{
		state.input.curr[key] = glfw.GetMouseButton(state.window, i32(key)) == glfw.PRESS
	}
}

is_key_down   :: #force_inline proc(state: ^engine_state, key : i32) -> bool{
	return state.input.curr[key]
}

is_key_pressed :: #force_inline proc(state: ^engine_state, key : i32) -> bool{
	return state.input.curr[key] && !state.input.prev[key]
}

is_key_released :: #force_inline proc(state: ^engine_state, key : i32) -> bool{
	return !state.input.curr[key] && state.input.prev[key]
}







