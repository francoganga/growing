package main

import "core:fmt"
import "core:strings"
import rl "vendor:raylib"


CARD_WIDTH :: 25
CARD_HEIGHT :: 35

SCREEN_SIZE :: [2]int{256, 144}

CAMERA_ZOOM :: 5.0

CardState :: enum {
	IDLE,
	CLICKED,
	DRAGGING,
	RELEASED,
}

CardType :: enum {
    SKILL,
    SINGLE_TARGET,
}

Card :: struct {
	using rect: rl.Rectangle,
	color:      rl.Color,
	text:     string,
	state:      CardState,
    type:       CardType,
}

Gui_Id :: distinct u64

Mouse_Button :: enum {
	Left,
	Right,
	Middle,
}

Mouse_Button_Set :: distinct bit_set[Mouse_Button]

GUI_State :: struct {
	delta_rect_mouse:              rl.Vector2,
	drop_area:                     rl.Rectangle,
	width, height:                 i32,
	hover_id, active_id:           Gui_Id,
	last_hover_id, last_active_id: Gui_Id,
	updated_hover:                 bool,
	updated_active:                bool,
	mouse_pos:                     rl.Vector2,
	last_mouse_pos:                rl.Vector2,
	current_time:                  f64,
	delta_time:                    f64,
	hover_in_time:                 f64,
	active_in_time:                f64,
	active_out_time:               f64,
	last_pressed_id:               Gui_Id,
	mouse_down:                    Mouse_Button_Set,
	mouse_pressed:                 Mouse_Button_Set,
	mouse_released:                Mouse_Button_Set,
}


gui_start :: proc(gui: ^GUI_State, camera: ^rl.Camera2D) {
	gui.mouse_pos = rl.GetScreenToWorld2D(rl.GetMousePosition(), camera^)

	gui.mouse_down = nil
	gui.mouse_pressed = nil
	gui.mouse_released = nil

	if rl.IsMouseButtonDown(.LEFT) {gui.mouse_down += {.Left}}
	if rl.IsMouseButtonPressed(.LEFT) {gui.mouse_pressed += {.Left}}
	if rl.IsMouseButtonPressed(.LEFT) {gui.mouse_released += {.Left}}

	if rl.IsMouseButtonDown(.RIGHT) {gui.mouse_down += {.Right}}
	if rl.IsMouseButtonPressed(.RIGHT) {gui.mouse_pressed += {.Right}}
	if rl.IsMouseButtonPressed(.RIGHT) {gui.mouse_released += {.Right}}

	if rl.IsMouseButtonDown(.MIDDLE) {gui.mouse_down += {.Middle}}
	if rl.IsMouseButtonPressed(.MIDDLE) {gui.mouse_pressed += {.Middle}}
	if rl.IsMouseButtonPressed(.MIDDLE) {gui.mouse_released += {.Middle}}

	switch {
	case gui.active_id != 0:
		rl.SetMouseCursor(.CROSSHAIR)
	case gui.hover_id != 0:
		rl.SetMouseCursor(.POINTING_HAND)
	case:
		rl.SetMouseCursor(.DEFAULT)
	}
}

gui_end :: proc(gui: ^GUI_State) {
	if gui.hover_id != gui.last_hover_id || gui.active_id == gui.hover_id {
		gui.hover_in_time = gui.current_time
	}

	gui.last_active_id = gui.active_id
	gui.last_hover_id = gui.hover_id

	if !gui.updated_active {
		gui.active_id = 0
	}
	gui.updated_active = false


	if !gui.updated_hover {
		gui.hover_id = 0
	}
	gui.updated_hover = false

	gui.last_mouse_pos = gui.mouse_pos
}

Control_Result :: enum u32 {
	Click,
	Right_Click,
	Middle_Click,
	Dragging,
	Active_In,
	Active_Out,
	Hover_In,
	Hover_Out,
	Active,
	Hover,
}

Control_Result_Set :: distinct bit_set[Control_Result;u32]

update_control :: proc(
	gui: ^GUI_State,
	id: Gui_Id,
	rect: rl.Rectangle,
	allowed_mouse_buttons := Mouse_Button_Set{.Left},
) -> (
	res: Control_Result_Set,
) {
	set_active :: proc(state: ^GUI_State, id: Gui_Id) {
		state.active_id = id
		state.updated_active = true
	}
	set_hover :: proc(state: ^GUI_State, id: Gui_Id) {
		state.hover_id = id
		state.updated_hover = true
	}

	hovered := rl.CheckCollisionPointRec(gui.mouse_pos, rect)

	mouse_pressed := (gui.mouse_pressed & allowed_mouse_buttons) == allowed_mouse_buttons
	mouse_down := (gui.mouse_down & allowed_mouse_buttons) == allowed_mouse_buttons

	if hovered && (!mouse_down || gui.active_id == id) && gui.hover_id != id {
		set_hover(gui, id)
		if gui.hover_id == id {
			res += {.Hover_In}
		}
	}

	if gui.active_id == id {
		if mouse_pressed && !hovered || !mouse_down {
			set_active(gui, 0)
		} else {
			gui.updated_active = true
			if .Left in (gui.mouse_down + gui.mouse_pressed) {
				res += {.Dragging}
			}
		}
	}

	if gui.hover_id == id {
		gui.updated_hover = true
		if mouse_pressed && gui.active_id != id {
			set_active(gui, id)
			res += {.Active_In}
			gui.active_in_time = gui.current_time
			gui.last_pressed_id = id
		} else if !hovered {
			set_hover(gui, 0)
			res += {.Hover_Out}
		}
	}

	if gui.active_id != id && gui.last_active_id == id {
		res += {.Active_Out}
		gui.active_out_time = gui.current_time
	}

	if gui.hover_id == id && gui.mouse_pressed != nil {
		if mouse_pressed && .Left in gui.mouse_pressed {res += {.Click}}
		if mouse_pressed && .Right in gui.mouse_pressed {res += {.Right_Click}}
		if mouse_pressed && .Middle in gui.mouse_pressed {res += {.Middle_Click}}
	}

	if gui.hover_id == id {
		res += {.Hover}
	}
	if gui.active_id == id {
		res += {.Active}
	}

	return

}

main :: proc() {

	rl.InitWindow(1280, 720, "example")

	rl.SetTargetFPS(60)

	sw := rl.GetScreenWidth() / CAMERA_ZOOM
	sh := rl.GetScreenHeight() / CAMERA_ZOOM

	gui_state: GUI_State

	gui_state.drop_area = {0, 0, f32(sw), 100}

	drop_line := 100

	hand := [dynamic]Card{}

	hand_size := 4
	gap := 10
	hand_width := CARD_WIDTH * hand_size + gap * (hand_size - 1)
	hand_middle := hand_width / 2

	for i in 0 ..< hand_size {
		x :=
			(i * (CARD_WIDTH + gap)) +
			int(rl.GetScreenWidth() / CAMERA_ZOOM / 2) -
			int(hand_middle)

		y := rl.GetScreenHeight() / CAMERA_ZOOM - CARD_HEIGHT - 5

		append(
			&hand,
			Card {
				rect = {f32(x), f32(y), CARD_WIDTH, CARD_HEIGHT},
				color = rl.DARKBLUE,
				text = "red",
			},
		)
	}

    hand[0].type = .SINGLE_TARGET


	camera := rl.Camera2D {
		zoom = CAMERA_ZOOM,
	}

	for !rl.WindowShouldClose() {

		gui_start(&gui_state, &camera)


		rl.BeginDrawing()
		rl.BeginMode2D(camera)


		rl.ClearBackground(rl.BLACK)

		x := (sw - CARD_WIDTH) / 2

		//rl.DrawRectangle(x, 100, CARD_WIDTH, CARD_HEIGHT, rl.DARKBLUE)

		for &card, i in hand {

			id := Gui_Id(uintptr(&card))
			res := update_control(&gui_state, id, card.rect)

			color := card.color

			switch {
			case .Click in res:
				mp := rl.GetScreenToWorld2D(rl.GetMousePosition(), camera)
				gui_state.delta_rect_mouse = mp - {card.rect.x, card.rect.y}
			case .Active in res:
                {
                    color = rl.ORANGE
                    card.state = .DRAGGING
				    card.text = "dragging"
                }
			case .Hover in res:
				color = rl.DARKGREEN
                card.text = "hover"
                card.state = .IDLE

			case .Dragging in res:
				color = rl.DARKPURPLE
            case:
                card.state = .IDLE
                card.text = "idle"
			}

			if .Active in res {
				card.state = .DRAGGING
				card.text = "dragging"
			} else {

				if int(card.rect.y + card.rect.height) < drop_line {
					card.state = .RELEASED
					card.text = "released"
					color = rl.Color{66, 212, 245, 255}

                    card.rect.x = f32(CARD_WIDTH * hand_size + gap * (hand_size - 1) / 2 - CARD_WIDTH / 2)

				} else {

					x :=
						(i * (CARD_WIDTH + gap)) +
						int(rl.GetScreenWidth() / CAMERA_ZOOM / 2) -
						int(hand_middle)

					y := rl.GetScreenHeight() / CAMERA_ZOOM - CARD_HEIGHT - 5

					card.rect.x = f32(x)
					card.rect.y = f32(y)

				}
			}

			if card.state == .DRAGGING {
				mp := gui_state.mouse_pos

				np := mp - gui_state.delta_rect_mouse

				card.rect.x = np.x
				card.rect.y = np.y
			}

			rl.DrawRectangleRec(card.rect, color)
			rl.DrawText(
				strings.clone_to_cstring(card.text),
				i32(card.rect.x),
				i32(card.rect.y),
				1,
				rl.WHITE,
			)

		}

		rl.DrawRectangleLines(
			i32(gui_state.drop_area.x),
			i32(gui_state.drop_area.y),
			i32(gui_state.drop_area.width),
			i32(gui_state.drop_area.height),
			rl.RED,
		)

		//rl.DrawText(fmt.ctprintf("sp: %v, wp: %v", sp, wp), 0, 0, 1, rl.WHITE)


		gui_end(&gui_state)

		rl.EndMode2D()

		rl.EndDrawing()
	}

	rl.CloseWindow()
}
