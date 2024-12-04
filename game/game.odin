package game

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
}

// -------CARDS--------
Seed :: enum {
    Potato,
    Tomato,
}

SeedCard :: struct {
	seed:         Seed,
	price:        int,
	water_levels: int,
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


make_player :: proc() -> (player: Player) {
    player.money = 0
    player.toolDeck = make([dynamic]Tool, 15)
    player.seeds = make([dynamic]SeedCard, 20)

    for t, i in default_tool_deck {
        player.toolDeck[i] = t
    }

    return player
}
