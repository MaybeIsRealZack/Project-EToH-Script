
local Categories = {
    -- Keep this key even though no tower below uses it: the merged script joins both
    -- registries' place ids under one "Pit-of-Misery" category, and it's what makes the
    -- TEA Pit of Misery place known to the place filter. The PoM towers themselves are
    -- listed once in Games/EToH/TowerRegistry.lua -- their route files only exist there,
    -- and the same towers are present in this game's PoM, so listing them here again
    -- (with route URLs pointing at folders this repo doesn't have) just made them 404.
    ["Pit-of-Misery"] = 121814103864070,
    TheEternalAbyss = 15873244701,
    TimelessManor = 131042387601353,
}

return {
    Categories = Categories,
    Towers = {
        --The Eternal Abyss
        { name = "ToMH",  category = "TheEternalAbyss", suggestedTime = { min = "16", sec = "5" } },
        --TimelessManor
        { name = "ToDC",  category = "TimelessManor", suggestedTime = { min = "5", sec = "5" } },
    },
    TowerRush = {
        -- PoMTR lives in Games/EToH/Pit-of-Misery/ and is pinned to the original PoM
        -- place (15639952229) there; a copy here only ever produced a dead route URL.
    },
}
