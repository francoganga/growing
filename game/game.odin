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
	tooldeck:        [dynamic]Tool,
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



make_player :: proc() -> (player: Player) {
    player.money = 0
    player.tooldeck = make([dynamic]Tool, 15)
    player.seeds = make([dynamic]SeedCard, 20)

    for t, i in default_tool_deck {
        player.tooldeck[i] = t
    }

    return player
}
