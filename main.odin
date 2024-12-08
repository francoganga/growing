package main

import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:math/rand"
import "core:slice"
import "core:strings"
import rl "vendor:raylib"
import g "./game"


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
    rl.SetMouseScale(0.2, 0.2)

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

pos_to_rect :: proc(pos: rl.Vector2) -> rl.Rectangle {
	return {pos.x, pos.y, CARD_WIDTH, CARD_HEIGHT}
}

ease_out_cubic :: proc(number: f32) -> f32 {
	return 1.0 - math.pow(1 - number, 3)
}

UI_State :: struct {
    active_tab_idx: i32,
    item_scroll_idx: i32,
    active_item: i32,
}

Game :: struct {
    debug: bool,
	gui_state: GUI_State,
    ui_state: UI_State,
    player: ^g.Player,
    camera: ^rl.Camera2D
}


reset_hand :: proc(hand: []g.ToolCard) {
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
    dragging_card: g.ToolCard
    aiming_card: g.ToolCard
    aiming: bool

    for &card, i in game.player.hand {

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


        if dragging_idx != i && aiming_card != card {
            rl.DrawRectangleRec(pos_to_rect(card.position), color)
        }

        if i32(i) == game.ui_state.active_item {
            rl.DrawRectangleLinesEx(pos_to_rect(card.position), 1, rl.WHITE)
        }
    }

    if dragging_idx >= 0 {
        rl.DrawRectangleRec(pos_to_rect(dragging_card.position), rl.DARKGREEN)
    }

    if aiming {

        rl.DrawRectangleRec(pos_to_rect(aiming_card.position), rl.ORANGE)

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

draw_ui :: proc(game: ^Game) {

    if !game.debug { return }

	sw := rl.GetScreenWidth() / CAMERA_ZOOM
	sh := rl.GetScreenHeight() / CAMERA_ZOOM

    cellWidth := 10


    for x in 0..<sw {
        start, end: rl.Vector2
        x := f32(10 * x)
        y := f32(0)
        start = {x, 0}
        end = { x, f32(sh) }

        rl.DrawLineV(start, end, rl.GRAY)
    }

    for row in 0..<sh {
        start, end: rl.Vector2

        x := f32(0)
        y := f32(10 * row)
        start = {x, y}
        end = {f32(sw), y }

        rl.DrawLineV(start, end, rl.GRAY)
    }


}

update :: proc(game: ^Game) {
    #reverse for &card, i in game.player.hand {
        id := Gui_Id(uintptr(&card))
        res := update_control(&game.gui_state, id, pos_to_rect(card.position))

        color := rl.DARKBLUE

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
                if int(card.position.y + CARD_HEIGHT) < DROP_LINE {
                    card.state = .AIMING
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

            if card.position.y + CARD_HEIGHT < f32(DROP_LINE) {
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
    }
}

render_game :: proc(game: ^Game) {
    rl.SetMouseScale(0.2, 0.2)
    //draw_ui(game)
    draw_hand(game)
}

render_gui :: proc(game: ^Game) {
    rl.SetMouseScale(1,1)
    if rl.GuiButton({20,20, 80, 40}, "Draw Cards") {
        if len(game.player.hand) != 5 {g.get_hand(game.player)}
    }

    //rl.GuiToggleGroup({975, 2, 100, 40}, "game;assets", &game.ui_state.active_tab_idx)

    items := strings.builder_make()

    for card, i in game.player.hand {
        switch card.tool {
        case .WateringCan:
            strings.write_string(&items, "watering_can")
        case .WateringScyte:
            strings.write_string(&items, "watering_Scyte")
        case .Scyte:
            strings.write_string(&items, "scyte")
        }

        if i != len(game.player.hand) -1 { 
            strings.write_string(&items, ";")
        }
    }

    rl.GuiListView({1120, 200, 150, 150}, strings.to_cstring(&items), &game.ui_state.item_scroll_idx, &game.ui_state.active_item)

    rl.GuiToggle({ 1200, 2, 80, 40 }, "DEBUG", &game.debug)

    mp := game.gui_state.mouse_pos


    if game.debug {

        rl.GuiPanel({1120, 355, 150, 200}, nil)

        toolText: cstring

        if game.ui_state.active_item >= 0 {
            card := game.player.hand[game.ui_state.active_item]

            toolText = fmt.ctprintf("%#v", card)
        }

        glh := proc(s: cstring) -> i32 {
            font := rl.GetFontDefault()
            text_size := rl.MeasureTextEx(font, s, 1, 1)

            res := i32(1)

            for c in string(s) {
                if c == '\n' {
                    res += 1
                }
            }

            return res * i32(text_size.y)
        }

        toolTextLH := glh(toolText)

        tw := rl.MeasureText(toolText, 1)

        //fmt.printf("tw=%d, toolTextLH=%d\n", tw, toolTextLH)

        lr := rl.Rectangle {1130, 360, 150, 300}
        //rl.GuiLabel(lr, toolText)
        rl.DrawTextEx(rl.GetFontDefault(), toolText, {1130, 360}, 11, 1, rl.WHITE)
        //rl.DrawRectangleLinesEx(lr, 1, rl.RED)

        world_pos_text := fmt.ctprintf("world_pos: (%f, %f)", mp.x, mp.y)
        rl.GuiLabel({10, 680, 300, 20}, world_pos_text)

        screen_mp := rl.GetMousePosition()
        screen_pos_text := fmt.ctprintf("screen_pos: (%f, %f)", screen_mp.x, screen_mp.y)
        rl.GuiLabel({10, 700, 300, 20}, screen_pos_text)
    }
}

render_debug_grid :: proc(debug: bool) {
    if !debug { return }

    sw := f32(rl.GetScreenWidth())
    sh := f32(rl.GetScreenHeight())
    rl.GuiGrid({0, 0, sw, sh}, "asd", 40, 2, nil)
}

main :: proc() {

	rl.InitWindow(1280, 720, "example")

	rl.SetTargetFPS(60)
    rl.GuiLoadStyle("style_dark.rgs")

	sw := rl.GetScreenWidth() / CAMERA_ZOOM
	sh := rl.GetScreenHeight() / CAMERA_ZOOM

	drop_line := 100

	game := Game{}
    player := g.make_player()
	game.player = &player
    rand.shuffle(player.toolDeck[:])
    game.ui_state.active_item = -1

	game.camera = &rl.Camera2D {
		zoom = CAMERA_ZOOM,
	}

    // render_texture := rl.LoadRenderTexture(1080, 720)
    // defer rl.UnloadRenderTexture(render_texture)

	for !rl.WindowShouldClose() {

		if rl.IsKeyPressed(.SPACE) {
            g.get_hand(game.player)
		}

        rl.ClearBackground(rl.BLACK)

		gui_start(&game.gui_state)

        update(&game)

		rl.BeginDrawing()

        render_debug_grid(game.debug)

        rl.BeginMode2D(game.camera^)

        render_game(&game)

        rl.EndMode2D()

        render_gui(&game)

        gui_end(&game.gui_state)
		rl.EndDrawing()
	}

	rl.CloseWindow()
}


main2 :: proc() {
    player := g.make_player()
    player.fields[0] = g.Field { card = &player.seeds[0], water_level = 0 }

    rand.shuffle(player.toolDeck[:])

    g.get_hand(&player)

    a := g.Action_Water{ field = &player.fields[0], power = 1}

    fmt.printf("before=%v\n", player.fields[0])

    g.do_action(&player, a)

    fmt.printf("after=%v\n", player.fields[0])


}
