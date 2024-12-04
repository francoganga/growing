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

// ------ACTIONS--------- //
Action_Water :: struct {
    power: int,
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
	None,
	WateringCan,
	WateringScyte,
	Scyte,
}

ToolCard :: struct {
	tool:      Tool,
}
//-----------------------

draw_card :: proc(player: ^Player) -> bool {
    tool := pop_safe(&player.toolDeck) or_return

    tc := ToolCard{ tool }

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
        action.field.card.curr_water_level += 1
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
