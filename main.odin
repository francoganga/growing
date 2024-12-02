package main

import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:slice"
import "core:strings"
import rl "vendor:raylib"


CARD_WIDTH :: 25
CARD_HEIGHT :: 35

SCREEN_SIZE :: [2]int{256, 144}

CAMERA_ZOOM :: 5.0

DROP_LINE :: 100

CARD_GAP :: 10
HAND_SIZE :: 5

HAND_WIDTH :: CARD_WIDTH * HAND_SIZE + CARD_GAP * (HAND_SIZE - 1)
HAND_MIDDLE :: HAND_WIDTH / 2


CardState :: enum {
	IDLE,
	DRAGGING,
	RELEASED,
	AIMING,
}

CardType :: enum {
	SKILL,
	SINGLE_TARGET,
}

Card :: struct {
	position:  rl.Vector2,
	color:     rl.Color,
	text:      string,
	state:     CardState,
	type:      CardType,
	animating: bool,
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


gui_start :: proc(gui: ^GUI_State) {

	gui.mouse_pos = rl.GetMousePosition()

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

//draw_card :: proc(card: ^Card) {
//    color = card.color
//    if card.state == .DRAGGING {
//        color = rl.RED
//        mp := gui_state.mouse_pos
//        card.position = mp - gui_state.delta_rect_mouse
//    }
//}

pos_to_rect :: proc(pos: rl.Vector2) -> rl.Rectangle {
	return {pos.x, pos.y, CARD_WIDTH, CARD_HEIGHT}
}

ease_out_cubic :: proc(number: f32) -> f32 {
	return 1.0 - math.pow(1 - number, 3)
}


Selecting :: struct {
	card: ^Card,
}

Aiming :: struct {
	card: ^Card,
	//targets: []int,
}

Idle :: struct {}

GameState :: union #no_nil {
	Idle,
	Selecting,
	Aiming,
}

Game :: struct {
	hand:      [dynamic]Card,
	gui_state: GUI_State,
}


reset_hand :: proc(hand: []Card) {
	hand_size := 4
	gap := 10
	hand_width := CARD_WIDTH * hand_size + gap * (hand_size - 1)
	hand_middle := hand_width / 2

	for i in 0 ..< len(hand) {
		x :=
			(i * (CARD_WIDTH + gap)) +
			int(rl.GetScreenWidth() / CAMERA_ZOOM / 2) -
			int(hand_middle)

		y := rl.GetScreenHeight() / CAMERA_ZOOM - CARD_HEIGHT - 5

		hand[i].position.x = f32(x)
		hand[i].position.y = f32(y)

		hand[i].state = .IDLE
	}

}


draw_hand :: proc(game: ^Game) {

    dragging_idx := -1
    dragging_card: Card
    aiming_card: Card
    aiming: bool

    for &card, i in game.hand {
        color := rl.DARKBLUE

        switch card.state {
            case .RELEASED: continue 
            case .DRAGGING:
                dragging_idx = i
                dragging_card = card
            case .AIMING:
                aiming = true 
                aiming_card = card
            case .IDLE:
                x := (i * (CARD_WIDTH + CARD_GAP)) + int(rl.GetScreenWidth() / CAMERA_ZOOM / 2) - int(HAND_MIDDLE)
		        y := rl.GetScreenHeight() / CAMERA_ZOOM - CARD_HEIGHT - 5

		        card.position.x = f32(x)
		        card.position.y = f32(y)
        }


        if dragging_idx != i {
            rl.DrawRectangleRec(pos_to_rect(card.position), color)
            rl.DrawText(
                strings.clone_to_cstring(card.text),
                i32(card.position.x),
                i32(card.position.y),
                1,
                rl.WHITE,
            )
        }
    }

    if dragging_idx >= 0 {
        rl.DrawRectangleRec(pos_to_rect(dragging_card.position), rl.DARKGREEN)
        rl.DrawText(
            strings.clone_to_cstring(dragging_card.text),
            i32(dragging_card.position.x),
            i32(dragging_card.position.y),
            1,
            rl.WHITE,
        )
    }

    if aiming {

        rl.DrawRectangleRec(pos_to_rect(aiming_card.position), rl.MAGENTA)
        rl.DrawText(
            strings.clone_to_cstring(aiming_card.text),
            i32(aiming_card.position.x),
            i32(aiming_card.position.y),
            1,
            rl.WHITE,
        )

        start := rl.Vector2{aiming_card.position.x + CARD_WIDTH / 2, 70}

        target := rl.GetMousePosition()
        distance := target - start

        point_count := 15
        points := [dynamic]rl.Vector2{}

        for i in 0 ..< point_count {
            t := (1.0 / f32(point_count)) * f32(i)

            x := start.x + (distance.x / f32(point_count)) * f32(i)

            y := start.y + ease_out_cubic(t) * distance.y

            append(&points, rl.Vector2{x, y})
        }

        append(&points, target)

        //rl.DrawLineStrip(raw_data(points), i32(point_count + 1), rl.WHITE)

        thick := f32(2)
        for i in 0 ..< len(points) - 1 {
            thick -= 0.1
            rl.DrawLineEx(points[i], points[i + 1], thick, rl.WHITE)
        }
    }
}


main :: proc() {

	rl.InitWindow(1280, 720, "example")

	rl.SetTargetFPS(60)

	sw := rl.GetScreenWidth() / CAMERA_ZOOM
	sh := rl.GetScreenHeight() / CAMERA_ZOOM

	drop_line := 100

	game := Game{}
	game.hand = [dynamic]Card{}


	for i in 0 ..< HAND_SIZE {
		x :=
			(i * (CARD_WIDTH + CARD_GAP)) +
			int(rl.GetScreenWidth() / CAMERA_ZOOM / 2) -
			int(HAND_MIDDLE)

		y := rl.GetScreenHeight() / CAMERA_ZOOM - CARD_HEIGHT - 5

		append(&game.hand, Card{position = {f32(x), f32(y)}, color = rl.DARKBLUE, text = "red"})
	}

	game.hand[0].type = .SINGLE_TARGET


	camera := rl.Camera2D {
		zoom = CAMERA_ZOOM,
	}

	for !rl.WindowShouldClose() {

		if rl.IsKeyPressed(.R) {
			reset_hand(game.hand[:])
		}

		gui_start(&game.gui_state)


		rl.BeginDrawing()
		rl.BeginMode2D(camera)

		rl.SetMouseScale(0.2, 0.2)


		rl.ClearBackground(rl.BLACK)

		x := (sw - CARD_WIDTH) / 2

		//rl.DrawRectangle(x, 100, CARD_WIDTH, CARD_HEIGHT, rl.DARKBLUE)

        #reverse for &card, i in game.hand {

			id := Gui_Id(uintptr(&card))
			res := update_control(&game.gui_state, id, pos_to_rect(card.position))

			color := card.color

			switch {
			case .Click in res:
				mp := rl.GetMousePosition()
				game.gui_state.delta_rect_mouse = mp - card.position
			case .Active in res:
				{
					if card.state != .IDLE {break}
					card.state = .DRAGGING
				}
			case .Active not_in res:
				{
					if card.state != .DRAGGING {break}
					if int(card.position.y + CARD_HEIGHT) < drop_line {
						switch card.type {
						case .SINGLE_TARGET:
							card.state = .AIMING
						case .SKILL:
                            ordered_remove(&game.hand, i)
						}

					} else {
						card.state = .IDLE

						x := (i * (CARD_WIDTH + CARD_GAP)) +
							int(rl.GetScreenWidth() / CAMERA_ZOOM / 2) -
							int(HAND_MIDDLE)

						y := rl.GetScreenHeight() / CAMERA_ZOOM - CARD_HEIGHT - 5

						card.position = {f32(x), f32(y)}
					}
				}
			}

			if card.state == .DRAGGING {
				mp := game.gui_state.mouse_pos
				card.position = mp - game.gui_state.delta_rect_mouse

				if card.position.y + CARD_HEIGHT < f32(drop_line) && card.type == .SINGLE_TARGET {
                    card.state = .AIMING
				}
			} else if card.state == .AIMING {

                if mp := rl.GetMousePosition(); mp.y > f32(DROP_LINE) {
                    card.state = .IDLE
                    x := (i * (CARD_WIDTH + CARD_GAP)) + int(rl.GetScreenWidth() / CAMERA_ZOOM / 2) - int(HAND_MIDDLE)

		            y := rl.GetScreenHeight() / CAMERA_ZOOM - CARD_HEIGHT - 5

                    card.position = {f32(x), f32(y)}
                } else {
                    card.position.y = linalg.lerp(card.position.y, 70, 0.1)
                    card.position.x = linalg.lerp(card.position.x, f32(rl.GetScreenWidth() / CAMERA_ZOOM / 2) - CARD_WIDTH / 2, 0.1)
                }
            }

			switch card.type {
			case .SINGLE_TARGET:
				card.text = "SINGLE"
			case .SKILL:
				card.text = "SKILL"
			}
		}

		draw_hand(&game)

		gui_end(&game.gui_state)

		rl.EndMode2D()

		rl.EndDrawing()
	}

	rl.CloseWindow()
}
