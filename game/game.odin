package game

import "core:fmt"

default_tool_deck :: [15]Tool {
	.WateringCan,
	.WateringCan,
	.WateringCan,
	.WateringCan,
	.WateringCan,
	.WateringCan,
	.WateringCan,
	.WateringCan,
	.Scyte,
	.Scyte,
	.Scyte,
	.Scyte,
	.Scyte,
	.Scyte,
	.Scyte,
}

watering_levels :: [Seed]int {
    .Potato = 4,
    .Tomato = 2,
}

tool_water_charges := [Tool]int {
    .Scyte = 0,
    .WateringCan = 1,
    .WateringScyte = 1,
}

// ------ACTIONS--------- //
Action_Water :: struct {
    power: int,
    tool: ^ToolCard,
    field: ^Field,
}

Action_Reap :: struct {
    target: ^SeedCard,
}

Action :: union {
    Action_Water,
    Action_Reap,
}
// --------------------- //

Upgrade :: enum {
	Sprinkler,
	Pigs,
	Chicken,
	Barn,
}

Field :: struct {
	card:        ^SeedCard,
	water_level: int,
}

Player :: struct {
    money:           int,
	upgrades:        [dynamic]Upgrade,
	fields:          [dynamic]Field,
	seeds:           [dynamic]SeedCard,
	toolDeck:        [dynamic]Tool,
    toolDiscard:     [dynamic]Tool,
	hand:            [dynamic]ToolCard,
    do_stack:        [dynamic]Action,
}

// -------CARDS--------
Seed :: enum {
    Potato,
    Tomato,
}

SeedCard :: struct {
	seed:              Seed,
	price:             int,
	curr_water_level:  int,
}

Tool :: enum {
	WateringCan,
	WateringScyte,
	Scyte,
}

ToolCardState :: enum {
	IDLE,
	DRAGGING,
	RELEASED,
	AIMING,
}

ToolCard :: struct {
    position: [2]f32,
    water_charges: int,
    reap_charges: int,
	tool:      Tool,
    state: ToolCardState,
}
//-----------------------

draw_card :: proc(player: ^Player) -> bool {
    tool := pop_safe(&player.toolDeck) or_return

    water_charges := tool_water_charges[tool]

    tc := ToolCard{ tool = tool, water_charges = water_charges }

    append(&player.hand, tc)

    return true
}

get_hand :: proc(player: ^Player) -> bool {
    for i in 0..<5 {
        draw_card(player) or_return
    }

    return true
}

do_action :: proc(player: ^Player, action: Action) {
    switch action in action {
    case Action_Water:
        if action.tool.water_charges > 0 {
            action.tool.water_charges -= 1
            action.field.card.curr_water_level += 1
        }

        if action.tool.water_charges == 0 && action.tool.reap_charges == 0 {
            //unordered_remove(player.hand
        }

        append(&player.do_stack, action)
    case Action_Reap:
        fmt.printf("reaping %v\n", action.target)
    }
}

undo_action :: proc(player: ^Player) {
    action, ok := pop_safe(&player.do_stack)
    if !ok { return }


    switch action in action {
    case Action_Water:
        fmt.printf("undoing action=%v\n", action)
        action.field.card.curr_water_level -= 1
    case Action_Reap:
        fmt.printf("undoing action=%v\n", action)
    }
}

make_player :: proc() -> (player: Player) {
    player.money = 0
    player.toolDeck = make([dynamic]Tool, 15)
    player.seeds = make([dynamic]SeedCard, 20)
    player.fields = make([dynamic]Field, 2)

    for t, i in default_tool_deck {
        player.toolDeck[i] = t
    }

    return player
}
