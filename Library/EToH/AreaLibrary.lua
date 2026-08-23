local AreaData = {
    TGI = {
        R0 = {
            Name    = "Ring 0: Purgatorio",
            WorldID = "W1",
            PlaceID = 9070958509,
        },
        R1 = {
            Name         = "Ring 1: Limbo",
            WorldID      = "W1",
            PlaceID      = 9070657865,
            EntranceBadge = 3000238536354200,
            Subrealm     = "FR",
        },
        R2 = {
            Name         = "Ring 2: Desire",
            WorldID      = "W1",
            PlaceID      = 9070979698,
            EntranceBadge = 2125364443,
            Subrealm     = "GoE",
        },
        R3 = {
            Name         = "Ring 3: Gluttony",
            WorldID      = "W1",
            PlaceID      = 9070980083,
            EntranceBadge = 2125365440,
        },
        R4 = {
            Name         = "Ring 4: Greed",
            WorldID      = "W1",
            PlaceID      = 9070980555,
            EntranceBadge = 2125383763,
            Subrealm     = "SA",
        },
        R5 = {
            Name         = "Ring 5: Wrath",
            WorldID      = "W1",
            PlaceID      = 9070980846,
            EntranceBadge = 2125383894,
            Subrealm     = "LR",
        },
        R6 = {
            Name         = "Ring 6: Heresy",
            WorldID      = "W1",
            PlaceID      = 9070981164,
            EntranceBadge = 2125384013,
            Subrealm     = "ATw",
        },
        R7 = {
            Name         = "Ring 7: Violence",
            WorldID      = "W1",
            PlaceID      = 9070981409,
            EntranceBadge = 2125394307,
        },
        R8 = {
            Name         = "Ring 8: Fraud",
            WorldID      = "W1",
            PlaceID      = 9070981722,
            EntranceBadge = 2125416473,
            Subrealm     = "TSA",
        },
        R9 = {
            Name         = "Ring 9: Treachery",
            WorldID      = "W1",
            PlaceID      = 9070982474,
            EntranceBadge = 2125416536,
        },
        R10 = {
            Name       = "The Final Stretch",
            WorldID    = "W1",
            PlaceID    = 9070983350,
            Unreleased = true,
        },
    },
    
    SS = {
        Z1 = {
            Name         = "Zone 1: Sea",
            WorldID      = "W2",
            PlaceID      = 9071001075,
            Subrealm     = "SH",
        },
        Z2 = {
            Name         = "Zone 2: Surface",
            WorldID      = "W2",
            PlaceID      = 9071001366,
            EntranceBadge = 2125418283,
            Subrealm     = "AA",
        },
        Z3 = {
            Name         = "Zone 3: Sky",
            WorldID      = "W2",
            PlaceID      = 9071001563,
            EntranceBadge = 2125418395,
            Subrealm     = "PA",
        },
        Z4 = {
            Name         = "Zone 4: Exosphere",
            WorldID      = "W2",
            PlaceID      = 9071001883,
            EntranceBadge = 2125418521,
        },
        Z5 = {
            Name         = "Zone 5: The Moon",
            WorldID      = "W2",
            PlaceID      = 9071002104,
            EntranceBadge = 2125418581,
            Subrealm     = "DSotM",
        },
        Z6 = {
            Name         = "Zone 6: Mars",
            WorldID      = "W2",
            PlaceID      = 9071002463,
            EntranceBadge = 2125418653,
        },
        Z7 = {
            Name         = "Zone 7: Asteroid Belt",
            WorldID      = "W2",
            PlaceID      = 9071002677,
            EntranceBadge = 2127933620,
        },
        Z8 = {
            Name         = "Zone 8: Pluto",
            WorldID      = "W2",
            PlaceID      = 9071002915,
            EntranceBadge = 4499496967815200,
        },
        Z9 = {
            Name         = "Zone 9: Singularity",
            WorldID      = "W2",
            PlaceID      = 9071004505,
            EntranceBadge = 2603846111248000,
        },
        Z10 = {
            Name         = "Zone 10: Interstellar Shore",
            WorldID      = "W2",
            PlaceID      = 9071004898,
            EntranceBadge = 2099542350799000,
        },
        Z11 = {
            Name       = "The Void's Farewell",
            WorldID    = "W2",
            PlaceID    = 9856440401,
            Unreleased = true,
        },
    },

    Subrealms = {
        FR = {
            Name    = "Forgotten Ridge",
            PlaceID = 9070954594,
        },
        GoE = {
            Name    = "Garden of Eeshöl",
            PlaceID = 9070960075,
        },
        SA = {
            Name    = "Silent Abyss",
            PlaceID = 11916533264,
        },
        LR = {
            Name    = "Lost River",
            PlaceID = 9945448769,
        },
        ATw = {
            Name    = "Ashen Towerworks",
            PlaceID = 14399266686,
        },
        TSA = {
            Name    = "The Starlit Archives",
            PlaceID = 137445538655680,
        },
        SH = {
            Name    = "Steelspire Horizon",
            PlaceID = 18538513621,
        },
        AA = {
            Name    = "Arcane Area",
            PlaceID = 9070944007,
        },
        PA = {
            Name    = "Paradise Atoll",
            PlaceID = 9070975342,
        },
        DSotM = {
            Name    = "Dark Side of the Moon",
            PlaceID = 76003383649350,
        },
    },

    Misc = {
        -- Halloween
        HE2018 = { Name = "Heccfire Depths",         PlaceID = 9070963935        },
        HE2019 = { Name = "Abyssal Badlands",         PlaceID = 9070940724        },
        HE2020 = { Name = "Forsaken Manor",           PlaceID = 9070957584        },
        HE2022 = { Name = "Eclipsed Headquarters",    PlaceID = 11402141810       },
        HE2023 = { Name = "Harvest Carnival",         PlaceID = 14399267725       },
        HE2025 = { Name = "Saint Venoma",             PlaceID = 80158334909597    },
        HE2026 = { Name = "HE2026",                   PlaceID = 18892014130       },

        -- Christmas
        CE2018 = { Name = "T H I R S T Z O N E",     PlaceID = 9070983600        },
        CE2019 = { Name = "Snowy Cabin",              PlaceID = 9070982934        },
        CE2020 = { Name = "Old Frosted Kingdom",      PlaceID = 9070972538        },
        CE2021 = { Name = "Festive Cliffside",        PlaceID = 9070951600        },
        CE2023 = { Name = "Snowmetropolis",           PlaceID = 14399270175       },
        CE2024 = { Name = "Glacial Outpost",          PlaceID = 95630397821208    },
        CE2025 = { Name = "Borealis Reach",           PlaceID = 93695130452528    },

        -- April Fools
        AF2021 = { Name = "Fool's Ring 9",            PlaceID = 9070952780        },
        AF2022 = { Name = "Terrain World",            PlaceID = 9247591798        },
        AF2023 = { Name = "Something Otherworldly...", PlaceID = 12966817992      },
        AF2024 = { Name = "The Doghouse",             PlaceID = 16976865869       },
        AF2025 = { Name = "BIOUMS",                   PlaceID = 111393548264970   },

        -- Summer / Spring Events
        SE2019 = { Name = "Beggmuda Triangle",        PlaceID = 9070946020        },
        SE2026 = { Name = "Elysian Fields",           PlaceID = 95241871632790    },
        TE2019 = { Name = "The Eternal Potluck",      PlaceID = 9070971186        },

        -- Time-Lost Series
        TLP    = { Name = "Time-Lost Plain",          PlaceID = 9070997222        },
        TLC    = { Name = "Time-Lost Clockwork",      PlaceID = 13671413767       },
        TLS    = { Name = "Time-Lost Sands",          PlaceID = 102253882954080   },
        TLN    = { Name = "Time-Lost Nexus",          PlaceID = 88764361702760    },
        TLT    = { Name = "Time-Lost Tempest",        PlaceID = 127134690806440   },

        -- Misc
        PoM    = { Name = "Pit of Misery",            PlaceID = 15639952229       },
        LF     = { Name = "Legacy Fortress",          PlaceID = 116826560849730   },
        SoM    = { Name = "Summit of Memories",       PlaceID = 90713610472463    },
        WP     = { Name = "Windswept Peak",           PlaceID = 112597732892200   },
        ER     = { Name = "Event Realm",              PlaceID = 82312199603536    },
        ["100M"] = { Name = "100M Replay",            PlaceID = 115856553162060   },
        TEST   = { Name = "🍵 test place",            PlaceID = 14631353950       },
    },
}

return AreaData