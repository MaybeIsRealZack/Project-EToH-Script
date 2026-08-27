
local Categories = {
    ["Pit-of-Misery"] = 121814103864070,
    TheEternalAbyss = 15873244701,
    TimelessManor = 131042387601353,
}

return {
    Categories = Categories,
    Towers = {
        --Pit of Misery
        { name = "ToMDC",  category = "Pit-of-Misery", suggestedTime = { min = "5", sec = "5" } },
        { name = "WAT",  category = "Pit-of-Misery", suggestedTime = { min = "0", sec = "5" } },
        { name = "ToG",  category = "Pit-of-Misery", suggestedTime = { min = "5", sec = "5" } },
        { name = "ToGF",  category = "Pit-of-Misery", suggestedTime = { min = "0", sec = "5" } },
        { name = "ToVH",  category = "Pit-of-Misery", suggestedTime = { min = "5", sec = "5" } },
        { name = "ToSE",  category = "Pit-of-Misery", suggestedTime = { min = "5", sec = "5" } },
        { name = "ToTH",  category = "Pit-of-Misery", suggestedTime = { min = "5", sec = "5" } },
        { name = "ToTRP",  category = "Pit-of-Misery", suggestedTime = { min = "5", sec = "5" } },
        { name = "ToEV",  category = "Pit-of-Misery", suggestedTime = { min = "5", sec = "5" } },
        { name = "ToWM",  category = "Pit-of-Misery", suggestedTime = { min = "5", sec = "5" } },
        { name = "ToP",  category = "PitOfMisery", suggestedTime = { min = "7", sec = "5" } },
        { name = "ToBF",  category = "Pit-of-Misery", suggestedTime = { min = "5", sec = "5" } },
        { name = "ToSF",  category = "Pit-of-Misery", suggestedTime = { min = "5", sec = "5" } },
        --The Eternal Abyss
        { name = "ToMH",  category = "TheEternalAbyss", suggestedTime = { min = "16", sec = "5" } },
        --TimelessManor
        { name = "ToDC",  category = "TimelessManor", suggestedTime = { min = "5", sec = "5" } },
    },
    TowerRush = {
        { name = "PoMTR", category = "Pit-of-Misery", places = 15639952229, suggestedTime = { min = "200", sec = "0" }, isTowerRush = true, },
    },
}
