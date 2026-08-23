-- BloxFruitScript
-- Self-contained multi-sea automation runtime with adaptive combat transport,
-- event-maintained world caches, persistent settings, and responsive UI.

if not game:IsLoaded() then game.Loaded:Wait() end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")
local VirtualInputManager = game:GetService("VirtualInputManager")
local Lighting = game:GetService("Lighting")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")
local CollectionService = game:GetService("CollectionService")
local LocalPlayer = Players.LocalPlayer
local Environment = (getgenv and getgenv()) or _G

if Environment.BloxFruitScript and type(Environment.BloxFruitScript.Destroy) == "function" then
    pcall(Environment.BloxFruitScript.Destroy)
end

local PLACE_TO_SEA = {
    [2753915549] = 1,
    [4442272183] = 2,
    [7449423635] = 3,
}

local Sea = PLACE_TO_SEA[game.PlaceId]
assert(Sea, "BloxFruitScript: unsupported PlaceId " .. tostring(game.PlaceId))

local LEVEL_DATA = {
    [1] = {
        { Min=1, Max=9, Team="Marines", Enemy="Trainee", Quest="MarineQuest", Slot=1, Title="Trainee", QuestCFrame=CFrame.new(-2708.54956, 23.9876823, 2105.38086, 0.551831365, -0.171465367, 0.816138268, 0.0559562929, 0.984042466, 0.168906137, -0.832076192, -0.0475396216, 0.552620113), EnemyCFrame=CFrame.new(-2709.67944, 24.5206585, 2104.24585, -0.744724929, -3.97967455e-8, -0.667371571, 4.32403588e-8, 1, -1.07884304e-7, 0.667371571, -1.09201515e-7, -0.744724929) },
        { Min=1, Max=9, Team="Pirates", Enemy="Bandit", Quest="BanditQuest1", Slot=1, Title="Bandit", QuestCFrame=CFrame.new(1059.0304, 16.2651749, 1551.71191, 0.588351011, 0.0359242484, -0.807807326, -0.000423941325, 0.999026179, 0.0441192314, 0.808605552, -0.0256151129, 0.587793291), EnemyCFrame=CFrame.new(1045.962646484375, 27.00250816345215, 1560.8203125) },
        { Min=10, Max=14, Team=nil, Enemy="Monkey", Quest="JungleQuest", Slot=1, Title="Monkey", QuestCFrame=CFrame.new(-1598.10095, 36.3327827, 153.365112, 0.565101802, -0.0235849079, 0.824684024, -0.00421982305, 0.999495566, 0.0314758494, -0.825010478, -0.0212670621, 0.564717233), EnemyCFrame=CFrame.new(-1448.51806640625, 67.85301208496094, 11.46579647064209) },
        { Min=15, Max=29, Team=nil, Enemy="Gorilla", Quest="JungleQuest", Slot=2, Title="Gorilla", QuestCFrame=CFrame.new(-1598.10095, 36.3327827, 153.365112, 0.565101802, -0.0235849079, 0.824684024, -0.00421982305, 0.999495566, 0.0314758494, -0.825010478, -0.0212670621, 0.564717233), EnemyCFrame=CFrame.new(-1129.8836669921875, 40.46354675292969, -525.4237060546875) },
        { Min=30, Max=39, Team=nil, Enemy="Pirate", Quest="BuggyQuest1", Slot=1, Title="Pirate", QuestCFrame=CFrame.new(-1141.11523, 4.22801352, 3831.57739, 0.466678292, -0.0266258121, -0.884026289, -0.00679375185, 0.999409318, -0.0336874351, 0.884401083, 0.0217270516, 0.46622175), EnemyCFrame=CFrame.new(-1103.513427734375, 13.752052307128906, 3896.091064453125) },
        { Min=40, Max=59, Team=nil, Enemy="Brute", Quest="BuggyQuest1", Slot=2, Title="Brute", QuestCFrame=CFrame.new(-1141.11523, 4.22801352, 3831.57739, 0.466678292, -0.0266258121, -0.884026289, -0.00679375185, 0.999409318, -0.0336874351, 0.884401083, 0.0217270516, 0.46622175), EnemyCFrame=CFrame.new(-1140.083740234375, 14.809885025024414, 4322.92138671875) },
        { Min=60, Max=74, Team=nil, Enemy="Desert Bandit", Quest="DesertQuest", Slot=1, Title="Desert Bandit", QuestCFrame=CFrame.new(894.546265, 5.94077444, 4392.45166, 0.28321889, 0.0492709801, 0.957788825, -0.00534322672, 0.998745084, -0.0497978739, -0.959040463, 0.0089860186, 0.283126742), EnemyCFrame=CFrame.new(924.7998046875, 6.44867467880249, 4481.5859375) },
        { Min=75, Max=89, Team=nil, Enemy="Desert Officer", Quest="DesertQuest", Slot=2, Title="Desert Officer", QuestCFrame=CFrame.new(894.546265, 5.94077444, 4392.45166, 0.28321889, 0.0492709801, 0.957788825, -0.00534322672, 0.998745084, -0.0497978739, -0.959040463, 0.0089860186, 0.283126742), EnemyCFrame=CFrame.new(1608.2822265625, 8.614224433898926, 4371.00732421875) },
        { Min=90, Max=99, Team=nil, Enemy="Snow Bandit", Quest="SnowQuest", Slot=1, Title="Snow Bandit", QuestCFrame=CFrame.new(1387.2179, 86.7898254, -1295.06165, -0.19740738, 0.0237135217, 0.980034709, -0.0140903126, 0.999535501, -0.027023565, -0.980220258, -0.0191436484, -0.196981549), EnemyCFrame=CFrame.new(1354.347900390625, 87.27277374267578, -1393.946533203125) },
        { Min=100, Max=119, Team=nil, Enemy="Snowman", Quest="SnowQuest", Slot=2, Title="Snowman", QuestCFrame=CFrame.new(1387.2179, 86.7898254, -1295.06165, -0.19740738, 0.0237135217, 0.980034709, -0.0140903126, 0.999535501, -0.027023565, -0.980220258, -0.0191436484, -0.196981549), EnemyCFrame=CFrame.new(1201.6412353515625, 144.57958984375, -1550.0670166015625) },
        { Min=120, Max=149, Team=nil, Enemy="Chief Petty Officer", Quest="MarineQuest2", Slot=1, Title="Chief Petty Officer", QuestCFrame=CFrame.new(-5039.58643, 27.3500385, 4324.68018, 0, 0, -1, 0, 1, 0, 1, 0, 0), EnemyCFrame=CFrame.new(-4881.23095703125, 22.65204429626465, 4273.75244140625) },
        { Min=150, Max=174, Team=nil, Enemy="Sky Bandit", Quest="SkyQuest", Slot=1, Title="Sky Bandit", QuestCFrame=CFrame.new(-4839.53027, 716.368591, -2619.44165, 0.866007268, 0, 0.500031412, 0, 1, 0, -0.500031412, 0, 0.866007268), EnemyCFrame=CFrame.new(-4953.20703125, 295.74420166015625, -2899.22900390625) },
        { Min=175, Max=189, Team=nil, Enemy="Dark Master", Quest="SkyQuest", Slot=2, Title="Dark Master", QuestCFrame=CFrame.new(-4839.53027, 716.368591, -2619.44165, 0.866007268, 0, 0.500031412, 0, 1, 0, -0.500031412, 0, 0.866007268), EnemyCFrame=CFrame.new(-5259.8447265625, 391.3976745605469, -2229.035400390625) },
        { Min=190, Max=209, Team=nil, Enemy="Prisoner", Quest="PrisonerQuest", Slot=1, Title="Prisoner", QuestCFrame=CFrame.new(5308.93115, 1.65517521, 475.120514, -0.0894274712, -5.00292918e-9, -0.995993316, 1.60817859e-9, 1, -5.16744869e-9, 0.995993316, -2.06384709e-9, -0.0894274712), EnemyCFrame=CFrame.new(5098.9736328125, -0.3204058110713959, 474.2373352050781) },
        { Min=210, Max=249, Team=nil, Enemy="Dangerous Prisoner", Quest="PrisonerQuest", Slot=2, Title="Dangerous Prisoner", QuestCFrame=CFrame.new(5308.93115, 1.65517521, 475.120514, -0.0894274712, -5.00292918e-9, -0.995993316, 1.60817859e-9, 1, -5.16744869e-9, 0.995993316, -2.06384709e-9, -0.0894274712), EnemyCFrame=CFrame.new(5654.5634765625, 15.633401870727539, 866.2991943359375) },
        { Min=250, Max=274, Team=nil, Enemy="Toga Warrior", Quest="ColosseumQuest", Slot=1, Title="Toga Warrior", QuestCFrame=CFrame.new(-1580.04663, 6.35000277, -2986.47534, -0.515037298, 0, -0.857167721, 0, 1, 0, 0.857167721, 0, -0.515037298), EnemyCFrame=CFrame.new(-1820.21484375, 51.68385696411133, -2740.6650390625) },
        { Min=275, Max=299, Team=nil, Enemy="Gladiator", Quest="ColosseumQuest", Slot=2, Title="Gladiator", QuestCFrame=CFrame.new(-1580.04663, 6.35000277, -2986.47534, -0.515037298, 0, -0.857167721, 0, 1, 0, 0.857167721, 0, -0.515037298), EnemyCFrame=CFrame.new(-1292.838134765625, 56.380882263183594, -3339.031494140625) },
        { Min=300, Max=324, Team=nil, Enemy="Military Soldier", Quest="MagmaQuest", Slot=1, Title="Military Soldier", QuestCFrame=CFrame.new(-5313.37012, 10.9500084, 8515.29395, -0.499959469, 0, 0.866048813, 0, 1, 0, -0.866048813, 0, -0.499959469), EnemyCFrame=CFrame.new(-5411.16455078125, 11.081554412841797, 8454.29296875) },
        { Min=325, Max=374, Team=nil, Enemy="Military Spy", Quest="MagmaQuest", Slot=2, Title="Military Spy", QuestCFrame=CFrame.new(-5313.37012, 10.9500084, 8515.29395, -0.499959469, 0, 0.866048813, 0, 1, 0, -0.866048813, 0, -0.499959469), EnemyCFrame=CFrame.new(-5802.8681640625, 86.26241302490234, 8828.859375) },
        { Min=375, Max=399, Team=nil, Enemy="Fishman Warrior", Quest="FishmanQuest", Slot=1, Title="Fishman Warrior", QuestCFrame=CFrame.new(61122.65234375, 18.497442245483, 1569.3997802734), EnemyCFrame=CFrame.new(60878.30078125, 18.482830047607422, 1543.7574462890625) },
        { Min=400, Max=449, Team=nil, Enemy="Fishman Commando", Quest="FishmanQuest", Slot=2, Title="Fishman Commando", QuestCFrame=CFrame.new(61122.65234375, 18.497442245483, 1569.3997802734), EnemyCFrame=CFrame.new(61922.6328125, 18.482830047607422, 1493.934326171875) },
        { Min=450, Max=474, Team=nil, Enemy="God's Guard", Quest="SkyExp1Quest", Slot=1, Title="God's Guard", QuestCFrame=CFrame.new(-4721.88867, 843.874695, -1949.96643, 0.996191859, 0, -0.0871884301, 0, 1, 0, 0.0871884301, 0, 0.996191859), EnemyCFrame=CFrame.new(-4710.04296875, 845.2769775390625, -1927.3079833984375) },
        { Min=475, Max=524, Team=nil, Enemy="Shanda", Quest="SkyExp1Quest", Slot=2, Title="Shanda", QuestCFrame=CFrame.new(-7859.09814, 5544.19043, -381.476196, -0.422592998, 0, 0.906319618, 0, 1, 0, -0.906319618, 0, -0.422592998), EnemyCFrame=CFrame.new(-7678.48974609375, 5566.40380859375, -497.2156066894531) },
        { Min=525, Max=549, Team=nil, Enemy="Royal Squad", Quest="SkyExp2Quest", Slot=1, Title="Royal Squad", QuestCFrame=CFrame.new(-7906.81592, 5634.6626, -1411.99194, 0, 0, -1, 0, 1, 0, 1, 0, 0), EnemyCFrame=CFrame.new(-7624.25244140625, 5658.13330078125, -1467.354248046875) },
        { Min=550, Max=624, Team=nil, Enemy="Royal Soldier", Quest="SkyExp2Quest", Slot=2, Title="Royal Soldier", QuestCFrame=CFrame.new(-7906.81592, 5634.6626, -1411.99194, 0, 0, -1, 0, 1, 0, 1, 0, 0), EnemyCFrame=CFrame.new(-7836.75341796875, 5645.6640625, -1790.6236572265625) },
        { Min=625, Max=649, Team=nil, Enemy="Galley Pirate", Quest="FountainQuest", Slot=1, Title="Galley Pirate", QuestCFrame=CFrame.new(5259.81982, 37.3500175, 4050.0293, 0.087131381, 0, 0.996196866, 0, 1, 0, -0.996196866, 0, 0.087131381), EnemyCFrame=CFrame.new(5551.02197265625, 78.90135192871094, 3930.412841796875) },
        { Min=650, Max=math.huge, Team=nil, Enemy="Galley Captain", Quest="FountainQuest", Slot=2, Title="Galley Captain", QuestCFrame=CFrame.new(5259.81982, 37.3500175, 4050.0293, 0.087131381, 0, 0.996196866, 0, 1, 0, -0.996196866, 0, 0.087131381), EnemyCFrame=CFrame.new(5441.95166015625, 42.50205993652344, 4950.09375) },
    },
    [2] = {
        { Min=700, Max=724, Team=nil, Enemy="Raider", Quest="Area1Quest", Slot=1, Title="Raider", QuestCFrame=CFrame.new(-429.543518, 71.7699966, 1836.18188, -0.22495985, 0, -0.974368095, 0, 1, 0, 0.974368095, 0, -0.22495985), EnemyCFrame=CFrame.new(-728.3267211914062, 52.779319763183594, 2345.7705078125) },
        { Min=725, Max=774, Team=nil, Enemy="Mercenary", Quest="Area1Quest", Slot=2, Title="Mercenary", QuestCFrame=CFrame.new(-429.543518, 71.7699966, 1836.18188, -0.22495985, 0, -0.974368095, 0, 1, 0, 0.974368095, 0, -0.22495985), EnemyCFrame=CFrame.new(-1004.3244018554688, 80.15886688232422, 1424.619384765625) },
        { Min=775, Max=799, Team=nil, Enemy="Swan Pirate", Quest="Area2Quest", Slot=1, Title="Swan Pirate", QuestCFrame=CFrame.new(638.43811, 71.769989, 918.282898, 0.139203906, 0, 0.99026376, 0, 1, 0, -0.99026376, 0, 0.139203906), EnemyCFrame=CFrame.new(1068.664306640625, 137.61428833007812, 1322.1060791015625) },
        { Min=800, Max=874, Team=nil, Enemy="Factory Staff", Quest="Area2Quest", Slot=2, Title="Factory Staff", QuestCFrame=CFrame.new(632.698608, 73.1055908, 918.666321, -0.0319722369, 8.96074881e-10, -0.999488771, 1.36326533e-10, 1, 8.92172336e-10, 0.999488771, -1.07732087e-10, -0.0319722369), EnemyCFrame=CFrame.new(73.07867431640625, 81.86344146728516, -27.470672607421875) },
        { Min=875, Max=899, Team=nil, Enemy="Marine Lieutenant", Quest="MarineQuest3", Slot=1, Title="Marine Lieutenant", QuestCFrame=CFrame.new(-2440.79639, 71.7140732, -3216.06812, 0.866007268, 0, 0.500031412, 0, 1, 0, -0.500031412, 0, 0.866007268), EnemyCFrame=CFrame.new(-2821.372314453125, 75.89727783203125, -3070.089111328125) },
        { Min=900, Max=949, Team=nil, Enemy="Marine Captain", Quest="MarineQuest3", Slot=2, Title="Marine Captain", QuestCFrame=CFrame.new(-2440.79639, 71.7140732, -3216.06812, 0.866007268, 0, 0.500031412, 0, 1, 0, -0.500031412, 0, 0.866007268), EnemyCFrame=CFrame.new(-1861.2310791015625, 80.17658233642578, -3254.697509765625) },
        { Min=950, Max=974, Team=nil, Enemy="Zombie", Quest="ZombieQuest", Slot=1, Title="Zombie", QuestCFrame=CFrame.new(-5497.06152, 47.5923004, -795.237061, -0.29242146, 0, -0.95628953, 0, 1, 0, 0.95628953, 0, -0.29242146), EnemyCFrame=CFrame.new(-5657.77685546875, 78.96973419189453, -928.68701171875) },
        { Min=975, Max=999, Team=nil, Enemy="Vampire", Quest="ZombieQuest", Slot=2, Title="Vampire", QuestCFrame=CFrame.new(-5497.06152, 47.5923004, -795.237061, -0.29242146, 0, -0.95628953, 0, 1, 0, 0.95628953, 0, -0.29242146), EnemyCFrame=CFrame.new(-6037.66796875, 32.18463897705078, -1340.6597900390625) },
        { Min=1000, Max=1049, Team=nil, Enemy="Snow Trooper", Quest="SnowMountainQuest", Slot=1, Title="Snow Trooper", QuestCFrame=CFrame.new(609.858826, 400.119904, -5372.25928, -0.374604106, 0, 0.92718488, 0, 1, 0, -0.92718488, 0, -0.374604106), EnemyCFrame=CFrame.new(549.1473388671875, 427.3870544433594, -5563.69873046875) },
        { Min=1050, Max=1099, Team=nil, Enemy="Winter Warrior", Quest="SnowMountainQuest", Slot=2, Title="Winter Warrior", QuestCFrame=CFrame.new(609.858826, 400.119904, -5372.25928, -0.374604106, 0, 0.92718488, 0, 1, 0, -0.92718488, 0, -0.374604106), EnemyCFrame=CFrame.new(1142.7451171875, 475.6398010253906, -5199.41650390625) },
        { Min=1100, Max=1124, Team=nil, Enemy="Lab Subordinate", Quest="IceSideQuest", Slot=1, Title="Lab Subordinate", QuestCFrame=CFrame.new(-6064.06885, 15.2422857, -4902.97852, 0.453972578, 0, -0.891015649, 0, 1, 0, 0.891015649, 0, 0.453972578), EnemyCFrame=CFrame.new(-5707.4716796875, 15.951709747314453, -4513.39208984375) },
        { Min=1125, Max=1174, Team=nil, Enemy="Horned Warrior", Quest="IceSideQuest", Slot=2, Title="Horned Warrior", QuestCFrame=CFrame.new(-6064.06885, 15.2422857, -4902.97852, 0.453972578, 0, -0.891015649, 0, 1, 0, 0.891015649, 0, 0.453972578), EnemyCFrame=CFrame.new(-6341.36669921875, 15.951770782470703, -5723.162109375) },
        { Min=1175, Max=1199, Team=nil, Enemy="Magma Ninja", Quest="FireSideQuest", Slot=1, Title="Magma Ninja", QuestCFrame=CFrame.new(-5428.03174, 15.0622921, -5299.43457, -0.882952213, 0, 0.469463557, 0, 1, 0, -0.469463557, 0, -0.882952213), EnemyCFrame=CFrame.new(-5449.6728515625, 76.65874481201172, -5808.20068359375) },
        { Min=1200, Max=1249, Team=nil, Enemy="Lava Pirate", Quest="FireSideQuest", Slot=2, Title="Lava Pirate", QuestCFrame=CFrame.new(-5428.03174, 15.0622921, -5299.43457, -0.882952213, 0, 0.469463557, 0, 1, 0, -0.469463557, 0, -0.882952213), EnemyCFrame=CFrame.new(-5213.33154296875, 49.73788070678711, -4701.451171875) },
        { Min=1250, Max=1274, Team=nil, Enemy="Ship Deckhand", Quest="ShipQuest1", Slot=1, Title="Ship Deckhand", QuestCFrame=CFrame.new(1037.80127, 125.092171, 32911.6016), EnemyCFrame=CFrame.new(1212.0111083984375, 150.79205322265625, 33059.24609375) },
        { Min=1275, Max=1299, Team=nil, Enemy="Ship Engineer", Quest="ShipQuest1", Slot=2, Title="Ship Engineer", QuestCFrame=CFrame.new(1037.80127, 125.092171, 32911.6016), EnemyCFrame=CFrame.new(919.4786376953125, 43.54401397705078, 32779.96875) },
        { Min=1300, Max=1324, Team=nil, Enemy="Ship Steward", Quest="ShipQuest2", Slot=1, Title="Ship Steward", QuestCFrame=CFrame.new(968.80957, 125.092171, 33244.125), EnemyCFrame=CFrame.new(919.4385375976562, 129.55599975585938, 33436.03515625) },
        { Min=1325, Max=1349, Team=nil, Enemy="Ship Officer", Quest="ShipQuest2", Slot=2, Title="Ship Officer", QuestCFrame=CFrame.new(968.80957, 125.092171, 33244.125), EnemyCFrame=CFrame.new(1036.0179443359375, 181.4390411376953, 33315.7265625) },
        { Min=1350, Max=1374, Team=nil, Enemy="Arctic Warrior", Quest="FrostQuest", Slot=1, Title="Arctic Warrior", QuestCFrame=CFrame.new(5667.6582, 26.7997818, -6486.08984, -0.933587909, 0, -0.358349502, 0, 1, 0, 0.358349502, 0, -0.933587909), EnemyCFrame=CFrame.new(5966.24609375, 62.97002029418945, -6179.3828125) },
        { Min=1375, Max=1424, Team=nil, Enemy="Snow Lurker", Quest="FrostQuest", Slot=2, Title="Snow Lurker", QuestCFrame=CFrame.new(5667.6582, 26.7997818, -6486.08984, -0.933587909, 0, -0.358349502, 0, 1, 0, 0.358349502, 0, -0.933587909), EnemyCFrame=CFrame.new(5407.07373046875, 69.19437408447266, -6880.88037109375) },
        { Min=1425, Max=1449, Team=nil, Enemy="Sea Soldier", Quest="ForgottenQuest", Slot=1, Title="Sea Soldier", QuestCFrame=CFrame.new(-3054.44458, 235.544281, -10142.8193, 0.990270376, 0, -0.13915664, 0, 1, 0, 0.13915664, 0, 0.990270376), EnemyCFrame=CFrame.new(-3028.2236328125, 64.67451477050781, -9775.4267578125) },
        { Min=1450, Max=math.huge, Team=nil, Enemy="Water Fighter", Quest="ForgottenQuest", Slot=2, Title="Water Fighter", QuestCFrame=CFrame.new(-3054.44458, 235.544281, -10142.8193, 0.990270376, 0, -0.13915664, 0, 1, 0, 0.13915664, 0, 0.990270376), EnemyCFrame=CFrame.new(-3352.9013671875, 285.01556396484375, -10534.841796875) },
    },
    [3] = {
        { Min=1500, Max=1524, Team=nil, Enemy="Pirate Millionaire", Quest="PiratePortQuest", Slot=1, Title="Pirate Millionaire", QuestCFrame=CFrame.new(-712.8272705078125, 98.5770492553711, 5711.9541015625), EnemyCFrame=CFrame.new(-712.8272705078125, 98.5770492553711, 5711.9541015625) },
        { Min=1525, Max=1574, Team=nil, Enemy="Pistol Billionaire", Quest="PiratePortQuest", Slot=2, Title="Pistol Billionaire", QuestCFrame=CFrame.new(-723.4331665039062, 147.42906188964844, 5931.9931640625), EnemyCFrame=CFrame.new(-723.4331665039062, 147.42906188964844, 5931.9931640625) },
        { Min=1575, Max=1599, Team=nil, Enemy="Dragon Crew Warrior", Quest="DragonCrewQuest", Slot=1, Title="Dragon Crew Warrior", QuestCFrame=CFrame.new(6735.12061, 127.107239, -711.085754, -0.474887252, 0.0169004519, -0.879884422, -0.00234961393, 0.999787629, 0.020471612, 0.880043507, 0.0117890798, -0.474746734), EnemyCFrame=CFrame.new(6735.12061, 127.107239, -711.085754, -0.474887252, 0.0169004519, -0.879884422, -0.00234961393, 0.999787629, 0.020471612, 0.880043507, 0.0117890798, -0.474746734) },
        { Min=1600, Max=1624, Team=nil, Enemy="Dragon Crew Archer", Quest="DragonCrewQuest", Slot=2, Title="Dragon Crew Archer", QuestCFrame=CFrame.new(6955.8974609375, 546.6658935546875, 309.0401306152344), EnemyCFrame=CFrame.new(6955.8974609375, 546.6658935546875, 309.0401306152344) },
        { Min=1625, Max=1649, Team=nil, Enemy="Hydra Enforcer", Quest="VenomCrewQuest", Slot=1, Title="Hydra Enforcer", QuestCFrame=CFrame.new(4620.61572265625, 1002.2954711914062, 399.0868835449219), EnemyCFrame=CFrame.new(4620.61572265625, 1002.2954711914062, 399.0868835449219) },
        { Min=1650, Max=1699, Team=nil, Enemy="Venomous Assailant", Quest="VenomCrewQuest", Slot=2, Title="Venomous Assailant", QuestCFrame=CFrame.new(4697.5918, 1100.65137, 946.401978, 0.579397917, -4.19689783e-10, 0.81504482, -1.49287818e-10, 1, 6.21053986e-10, -0.81504482, -4.81513662e-10, 0.579397917), EnemyCFrame=CFrame.new(4697.5918, 1100.65137, 946.401978, 0.579397917, -4.19689783e-10, 0.81504482, -1.49287818e-10, 1, 6.21053986e-10, -0.81504482, -4.81513662e-10, 0.579397917) },
        { Min=1700, Max=1724, Team=nil, Enemy="Marine Commodore", Quest="MarineTreeIsland", Slot=1, Title="Marine Commodore", QuestCFrame=CFrame.new(2180.54126, 27.8156815, -6741.5498, -0.965929747, 0, 0.258804798, 0, 1, 0, -0.258804798, 0, -0.965929747), EnemyCFrame=CFrame.new(2286.0078125, 73.13391876220703, -7159.80908203125) },
        { Min=1725, Max=1774, Team=nil, Enemy="Marine Rear Admiral", Quest="MarineTreeIsland", Slot=2, Title="Marine Rear Admiral", QuestCFrame=CFrame.new(2179.98828125, 28.731239318848, -6740.0551757813), EnemyCFrame=CFrame.new(3656.773681640625, 160.52406311035156, -7001.5986328125) },
        { Min=1775, Max=1799, Team=nil, Enemy="Fishman Raider", Quest="DeepForestIsland3", Slot=1, Title="Fishman Raider", QuestCFrame=CFrame.new(-10581.6563, 330.872955, -8761.18652, -0.882952213, 0, 0.469463557, 0, 1, 0, -0.469463557, 0, -0.882952213), EnemyCFrame=CFrame.new(-10407.5263671875, 331.76263427734375, -8368.5166015625) },
        { Min=1800, Max=1824, Team=nil, Enemy="Fishman Captain", Quest="DeepForestIsland3", Slot=2, Title="Fishman Captain", QuestCFrame=CFrame.new(-10581.6563, 330.872955, -8761.18652, -0.882952213, 0, 0.469463557, 0, 1, 0, -0.469463557, 0, -0.882952213), EnemyCFrame=CFrame.new(-10994.701171875, 352.38140869140625, -9002.1103515625) },
        { Min=1825, Max=1849, Team=nil, Enemy="Forest Pirate", Quest="DeepForestIsland", Slot=1, Title="Forest Pirate", QuestCFrame=CFrame.new(-13234.04, 331.488495, -7625.40137, 0.707134247, 0, -0.707079291, 0, 1, 0, 0.707079291, 0, 0.707134247), EnemyCFrame=CFrame.new(-13274.478515625, 332.3781433105469, -7769.58056640625) },
        { Min=1850, Max=1899, Team=nil, Enemy="Mythological Pirate", Quest="DeepForestIsland", Slot=2, Title="Mythological Pirate", QuestCFrame=CFrame.new(-13234.04, 331.488495, -7625.40137, 0.707134247, 0, -0.707079291, 0, 1, 0, 0.707079291, 0, 0.707134247), EnemyCFrame=CFrame.new(-13680.607421875, 501.08154296875, -6991.189453125) },
        { Min=1900, Max=1924, Team=nil, Enemy="Jungle Pirate", Quest="DeepForestIsland2", Slot=1, Title="Jungle Pirate", QuestCFrame=CFrame.new(-12680.3818, 389.971039, -9902.01953, -0.0871315002, 0, 0.996196866, 0, 1, 0, -0.996196866, 0, -0.0871315002), EnemyCFrame=CFrame.new(-12256.16015625, 331.73828125, -10485.8369140625) },
        { Min=1925, Max=1974, Team=nil, Enemy="Musketeer Pirate", Quest="DeepForestIsland2", Slot=2, Title="Musketeer Pirate", QuestCFrame=CFrame.new(-12680.3818, 389.971039, -9902.01953, -0.0871315002, 0, 0.996196866, 0, 1, 0, -0.996196866, 0, -0.0871315002), EnemyCFrame=CFrame.new(-13457.904296875, 391.545654296875, -9859.177734375) },
        { Min=1975, Max=1999, Team=nil, Enemy="Reborn Skeleton", Quest="HauntedQuest1", Slot=1, Title="Reborn Skeleton", QuestCFrame=CFrame.new(-9479.2168, 141.215088, 5566.09277, 0, 0, 1, 0, 1, 0, -1, 0, 0), EnemyCFrame=CFrame.new(-8763.7236328125, 165.72299194335938, 6159.86181640625) },
        { Min=2000, Max=2024, Team=nil, Enemy="Living Zombie", Quest="HauntedQuest1", Slot=2, Title="Living Zombie", QuestCFrame=CFrame.new(-9479.2168, 141.215088, 5566.09277, 0, 0, 1, 0, 1, 0, -1, 0, 0), EnemyCFrame=CFrame.new(-10144.1318359375, 138.62667846679688, 5838.0888671875) },
        { Min=2025, Max=2049, Team=nil, Enemy="Demonic Soul", Quest="HauntedQuest2", Slot=1, Title="Demonic Soul", QuestCFrame=CFrame.new(-9516.99316, 172.017181, 6078.46533, 0, 0, -1, 0, 1, 0, 1, 0, 0), EnemyCFrame=CFrame.new(-9505.8720703125, 172.10482788085938, 6158.9931640625) },
        { Min=2050, Max=2074, Team=nil, Enemy="Posessed Mummy", Quest="HauntedQuest2", Slot=2, Title="Posessed Mummy", QuestCFrame=CFrame.new(-9516.99316, 172.017181, 6078.46533, 0, 0, -1, 0, 1, 0, 1, 0, 0), EnemyCFrame=CFrame.new(-9582.0224609375, 6.251527309417725, 6205.478515625) },
        { Min=2075, Max=2099, Team=nil, Enemy="Peanut Scout", Quest="NutsIslandQuest", Slot=1, Title="Peanut Scout", QuestCFrame=CFrame.new(-2104.3908691406, 38.104167938232, -10194.21875, 0, 0, -1, 0, 1, 0, 1, 0, 0), EnemyCFrame=CFrame.new(-2143.241943359375, 47.72198486328125, -10029.9951171875) },
        { Min=2100, Max=2124, Team=nil, Enemy="Peanut President", Quest="NutsIslandQuest", Slot=2, Title="Peanut President", QuestCFrame=CFrame.new(-2104.3908691406, 38.104167938232, -10194.21875, 0, 0, -1, 0, 1, 0, 1, 0, 0), EnemyCFrame=CFrame.new(-1859.35400390625, 38.10316848754883, -10422.4296875) },
        { Min=2125, Max=2149, Team=nil, Enemy="Ice Cream Chef", Quest="IceCreamIslandQuest", Slot=1, Title="Ice Cream Chef", QuestCFrame=CFrame.new(-820.64825439453, 65.819526672363, -10965.795898438, 0, 0, -1, 0, 1, 0, 1, 0, 0), EnemyCFrame=CFrame.new(-872.24658203125, 65.81957244873047, -10919.95703125) },
        { Min=2150, Max=2199, Team=nil, Enemy="Ice Cream Commander", Quest="IceCreamIslandQuest", Slot=2, Title="Ice Cream Commander", QuestCFrame=CFrame.new(-820.64825439453, 65.819526672363, -10965.795898438, 0, 0, -1, 0, 1, 0, 1, 0, 0), EnemyCFrame=CFrame.new(-558.06103515625, 112.04895782470703, -11290.7744140625) },
        { Min=2200, Max=2224, Team=nil, Enemy="Cookie Crafter", Quest="CakeQuest1", Slot=1, Title="Cookie Crafter", QuestCFrame=CFrame.new(-2021.32007, 37.7982254, -12028.7295, 0.957576931, -8.80302053e-8, 0.288177818, 6.9301187e-8, 1, 7.51931211e-8, -0.288177818, -5.2032135e-8, 0.957576931), EnemyCFrame=CFrame.new(-2374.13671875, 37.79826354980469, -12125.30859375) },
        { Min=2225, Max=2249, Team=nil, Enemy="Cake Guard", Quest="CakeQuest1", Slot=2, Title="Cake Guard", QuestCFrame=CFrame.new(-2021.32007, 37.7982254, -12028.7295, 0.957576931, -8.80302053e-8, 0.288177818, 6.9301187e-8, 1, 7.51931211e-8, -0.288177818, -5.2032135e-8, 0.957576931), EnemyCFrame=CFrame.new(-1598.3070068359375, 43.773197174072266, -12244.5810546875) },
        { Min=2250, Max=2274, Team=nil, Enemy="Baking Staff", Quest="CakeQuest2", Slot=1, Title="Baking Staff", QuestCFrame=CFrame.new(-1927.91602, 37.7981339, -12842.5391, -0.96804446, 4.22142143e-8, 0.250778586, 4.74911062e-8, 1, 1.49904711e-8, -0.250778586, 2.64211941e-8, -0.96804446), EnemyCFrame=CFrame.new(-1887.8099365234375, 77.6185073852539, -12998.3505859375) },
        { Min=2275, Max=2299, Team=nil, Enemy="Head Baker", Quest="CakeQuest2", Slot=2, Title="Head Baker", QuestCFrame=CFrame.new(-1927.91602, 37.7981339, -12842.5391, -0.96804446, 4.22142143e-8, 0.250778586, 4.74911062e-8, 1, 1.49904711e-8, -0.250778586, 2.64211941e-8, -0.96804446), EnemyCFrame=CFrame.new(-2216.188232421875, 82.884521484375, -12869.2939453125) },
        { Min=2300, Max=2324, Team=nil, Enemy="Cocoa Warrior", Quest="ChocQuest1", Slot=1, Title="Cocoa Warrior", QuestCFrame=CFrame.new(233.22836303710938, 29.876001358032227, -12201.2333984375), EnemyCFrame=CFrame.new(-21.55328369140625, 80.57499694824219, -12352.3876953125) },
        { Min=2325, Max=2349, Team=nil, Enemy="Chocolate Bar Battler", Quest="ChocQuest1", Slot=2, Title="Chocolate Bar Battler", QuestCFrame=CFrame.new(233.22836303710938, 29.876001358032227, -12201.2333984375), EnemyCFrame=CFrame.new(582.590576171875, 77.18809509277344, -12463.162109375) },
        { Min=2350, Max=2374, Team=nil, Enemy="Sweet Thief", Quest="ChocQuest2", Slot=1, Title="Sweet Thief", QuestCFrame=CFrame.new(150.5066375732422, 30.693693161010742, -12774.5029296875), EnemyCFrame=CFrame.new(165.1884765625, 76.05885314941406, -12600.8369140625) },
        { Min=2375, Max=2399, Team=nil, Enemy="Candy Rebel", Quest="ChocQuest2", Slot=2, Title="Candy Rebel", QuestCFrame=CFrame.new(150.5066375732422, 30.693693161010742, -12774.5029296875), EnemyCFrame=CFrame.new(134.86563110351562, 77.2476806640625, -12876.5478515625) },
        { Min=2400, Max=2449, Team=nil, Enemy="Candy Pirate", Quest="CandyQuest1", Slot=1, Title="Candy Pirate", QuestCFrame=CFrame.new(-1150.0400390625, 20.378934860229492, -14446.3349609375), EnemyCFrame=CFrame.new(-1310.5003662109375, 26.016523361206055, -14562.404296875) },
        { Min=2450, Max=2474, Team=nil, Enemy="Isle Outlaw", Quest="TikiQuest1", Slot=1, Title="Isle Outlaw", QuestCFrame=CFrame.new(-16548.8164, 55.6059914, -172.8125, 0.213092566, 0, -0.977032006, 0, 1, 0, 0.977032006, 0, 0.213092566), EnemyCFrame=CFrame.new(-16479.900390625, 226.6117401123047, -300.3114318847656) },
        { Min=2475, Max=2499, Team=nil, Enemy="Island Boy", Quest="TikiQuest1", Slot=2, Title="Island Boy", QuestCFrame=CFrame.new(-16548.8164, 55.6059914, -172.8125, 0.213092566, 0, -0.977032006, 0, 1, 0, 0.977032006, 0, 0.213092566), EnemyCFrame=CFrame.new(-16849.396484375, 192.86505126953125, -150.7853240966797) },
        { Min=2500, Max=2524, Team=nil, Enemy="Sun-kissed Warrior", Quest="TikiQuest2", Slot=1, Title="kissed Warrior", QuestCFrame=CFrame.new(-16538, 55, 1049), EnemyCFrame=CFrame.new(-16347, 64, 984) },
        { Min=2525, Max=2550, Team=nil, Enemy="Isle Champion", Quest="TikiQuest2", Slot=2, Title="Isle Champion", QuestCFrame=CFrame.new(-16541.0215, 57.3082275, 1051.46118, 0.0410757065, 0, -0.999156058, 0, 1, 0, 0.999156058, 0, 0.0410757065), EnemyCFrame=CFrame.new(-16602.1015625, 130.38734436035156, 1087.24560546875) },
        { Min=2551, Max=2574, Team=nil, Enemy="Serpent Hunter", Quest="TikiQuest3", Slot=1, Title="Serpent Hunter", QuestCFrame=CFrame.new(-16679.4785, 176.7473, 1474.3995), EnemyCFrame=CFrame.new(-16679.4785, 176.7473, 1474.3995) },
        { Min=2575, Max=2599, Team=nil, Enemy="Skull Slayer", Quest="TikiQuest3", Slot=2, Title="Skull Slayer", QuestCFrame=CFrame.new(-16759.5898, 71.2837, 1595.3399), EnemyCFrame=CFrame.new(-16759.5898, 71.2837, 1595.3399) },
        { Min=2600, Max=2624, Team=nil, Enemy="Reef Bandit", Quest="SubmergedQuest1", Slot=1, Title="Reef Bandit", QuestCFrame=CFrame.new(10882.264, -2086.322, 10034.226), EnemyCFrame=CFrame.new(10736.6191, -2087.8439, 9338.4882) },
        { Min=2625, Max=2649, Team=nil, Enemy="Coral Pirate", Quest="SubmergedQuest1", Slot=2, Title="Coral Pirate", QuestCFrame=CFrame.new(10882.264, -2086.322, 10034.226), EnemyCFrame=CFrame.new(10965.1025, -2158.8842, 9177.2597) },
        { Min=2650, Max=2674, Team=nil, Enemy="Sea Chanter", Quest="SubmergedQuest2", Slot=1, Title="Sea Chanter", QuestCFrame=CFrame.new(10882.264, -2086.322, 10034.226), EnemyCFrame=CFrame.new(10621.0342, -2087.844, 10102.0332) },
        { Min=2675, Max=2699, Team=nil, Enemy="Ocean Prophet", Quest="SubmergedQuest2", Slot=2, Title="Ocean Prophet", QuestCFrame=CFrame.new(10882.264, -2086.322, 10034.226), EnemyCFrame=CFrame.new(11056.1445, -2001.6717, 10117.4493) },
        { Min=2700, Max=2724, Team=nil, Enemy="High Disciple", Quest="SubmergedQuest3", Slot=1, Title="High Disciple", QuestCFrame=CFrame.new(9636.52441, -1992.19507, 9609.52832), EnemyCFrame=CFrame.new(9828.087890625, -1940.908935546875, 9693.0634765625) },
        { Min=2725, Max=2800, Team=nil, Enemy="Grand Devotee", Quest="SubmergedQuest3", Slot=2, Title="Grand Devotee", QuestCFrame=CFrame.new(9636.52441, -1992.19507, 9609.52832), EnemyCFrame=CFrame.new(9557.5849609375, -1928.0404052734375, 9859.1826171875) },
    },
}

local BOSS_DATA = {
    [1] = {
        ["The Gorilla King"] = { Model="The Gorilla King", Quest="JungleQuest", Slot=3, QuestCFrame=CFrame.new(-1601.6553955078, 36.85213470459, 153.38809204102), BossCFrame=CFrame.new(-1088.75977, 8.13463783, -488.559906, -0.707134247, 0, 0.707079291, 0, 1, 0, -0.707079291, 0, -0.707134247) },
        ["Bobby"] = { Model="Bobby", Quest="BuggyQuest1", Slot=3, QuestCFrame=CFrame.new(-1140.1761474609, 4.752049446106, 3827.4057617188), BossCFrame=CFrame.new(-1087.3760986328, 46.949409484863, 4040.1462402344) },
        ["The Saw"] = { Model="The Saw", Quest=nil, Slot=nil, QuestCFrame=nil, BossCFrame=CFrame.new(-784.89715576172, 72.427383422852, 1603.5822753906) },
        ["Yeti"] = { Model="Yeti", Quest="SnowQuest", Slot=3, QuestCFrame=CFrame.new(1386.8073730469, 87.272789001465, -1298.3576660156), BossCFrame=CFrame.new(1218.7956542969, 138.01184082031, -1488.0262451172) },
        ["Mob Leader"] = { Model="Mob Leader", Quest=nil, Slot=nil, QuestCFrame=nil, BossCFrame=CFrame.new(-2844.7307128906, 7.4180502891541, 5356.6723632813) },
        ["Vice Admiral"] = { Model="Vice Admiral", Quest="MarineQuest2", Slot=2, QuestCFrame=CFrame.new(-5036.2465820313, 28.677835464478, 4324.56640625), BossCFrame=CFrame.new(-5006.5454101563, 88.032081604004, 4353.162109375) },
        ["Saber Expert"] = { Model="Saber Expert", Quest=nil, Slot=nil, QuestCFrame=nil, BossCFrame=CFrame.new(-1458.89502, 29.8870335, -50.633564) },
        ["Warden"] = { Model="Warden", Quest="ImpelQuest", Slot=1, QuestCFrame=CFrame.new(5191.86133, 2.84020686, 686.438721, -0.731384635, 0, 0.681965172, 0, 1, 0, -0.681965172, 0, -0.731384635), BossCFrame=CFrame.new(5278.04932, 2.15167475, 944.101929, 0.220546961, -0.00000449946401, 0.975376427, -0.0000195412576, 1, 0.00000903162072, -0.975376427, -0.0000210519756, 0.220546961) },
        ["Chief Warden"] = { Model="Chief Warden", Quest="ImpelQuest", Slot=2, QuestCFrame=CFrame.new(5191.86133, 2.84020686, 686.438721, -0.731384635, 0, 0.681965172, 0, 1, 0, -0.681965172, 0, -0.731384635), BossCFrame=CFrame.new(5206.92578, 0.997753382, 814.976746, 0.342041343, -0.00062915677, 0.939684749, 0.00191645394, 0.999998152, -0.0000280422337, -0.939682961, 0.00181045406, 0.342041939) },
        ["Swan"] = { Model="Swan", Quest="ImpelQuest", Slot=3, QuestCFrame=CFrame.new(5191.86133, 2.84020686, 686.438721, -0.731384635, 0, 0.681965172, 0, 1, 0, -0.681965172, 0, -0.731384635), BossCFrame=CFrame.new(5325.09619, 7.03906584, 719.570679, -0.309060812, 0, 0.951042235, 0, 1, 0, -0.951042235, 0, -0.309060812) },
        ["Magma Admiral"] = { Model="Magma Admiral", Quest="MagmaQuest", Slot=3, QuestCFrame=CFrame.new(-5314.6220703125, 12.262420654297, 8517.279296875), BossCFrame=CFrame.new(-5765.8969726563, 82.92064666748, 8718.3046875) },
        ["Fishman Lord"] = { Model="Fishman Lord", Quest="FishmanQuest", Slot=3, QuestCFrame=CFrame.new(61122.65234375, 18.497442245483, 1569.3997802734), BossCFrame=CFrame.new(61260.15234375, 30.950881958008, 1193.4329833984) },
        ["Wysper"] = { Model="Wysper", Quest="SkyExp1Quest", Slot=3, QuestCFrame=CFrame.new(-7861.947265625, 5545.517578125, -379.85974121094), BossCFrame=CFrame.new(-7866.1333007813, 5576.4311523438, -546.74816894531) },
        ["Thunder God"] = { Model="Thunder God", Quest="SkyExp2Quest", Slot=3, QuestCFrame=CFrame.new(-7903.3828125, 5635.9897460938, -1410.923828125), BossCFrame=CFrame.new(-7994.984375, 5761.025390625, -2088.6479492188) },
        ["Cyborg"] = { Model="Cyborg", Quest="FountainQuest", Slot=3, QuestCFrame=CFrame.new(5258.2788085938, 38.526931762695, 4050.044921875), BossCFrame=CFrame.new(6094.0249023438, 73.770050048828, 3825.7348632813) },
        ["Ice Admiral"] = { Model="Ice Admiral", Quest=nil, Slot=nil, QuestCFrame=CFrame.new(1266.08948, 26.1757946, -1399.57678, -0.573599219, 0, -0.81913656, 0, 1, 0, 0.81913656, 0, -0.573599219), BossCFrame=CFrame.new(1266.08948, 26.1757946, -1399.57678, -0.573599219, 0, -0.81913656, 0, 1, 0, 0.81913656, 0, -0.573599219) },
        ["Greybeard"] = { Model="Greybeard", Quest=nil, Slot=nil, QuestCFrame=CFrame.new(-5081.3452148438, 85.221641540527, 4257.3588867188), BossCFrame=CFrame.new(-5081.3452148438, 85.221641540527, 4257.3588867188) },
    },
    [2] = {
        ["Diamond"] = { Model="Diamond", Quest="Area1Quest", Slot=3, QuestCFrame=CFrame.new(-427.5666809082, 73.313781738281, 1835.4208984375), BossCFrame=CFrame.new(-1576.7166748047, 198.59265136719, 13.724286079407) },
        ["Jeremy"] = { Model="Jeremy", Quest="Area2Quest", Slot=3, QuestCFrame=CFrame.new(636.79943847656, 73.413787841797, 918.00415039063), BossCFrame=CFrame.new(2006.9261474609, 448.95666503906, 853.98284912109) },
        ["Orbitus"] = { Model="Orbitus", Quest="MarineQuest3", Slot=3, QuestCFrame=CFrame.new(-2441.986328125, 73.359344482422, -3217.5324707031), BossCFrame=CFrame.new(-2172.7399902344, 103.32216644287, -4015.025390625) },
        ["Don Swan"] = { Model="Don Swan", Quest=nil, Slot=nil, QuestCFrame=nil, BossCFrame=CFrame.new(2286.2004394531, 15.177839279175, 863.8388671875) },
        ["Smoke Admiral"] = { Model="Smoke Admiral", Quest="IceSideQuest", Slot=3, QuestCFrame=CFrame.new(-5429.0473632813, 15.977565765381, -5297.9614257813), BossCFrame=CFrame.new(-5275.1987304688, 20.757257461548, -5260.6669921875) },
        ["Awakened Ice Admiral"] = { Model="Awakened Ice Admiral", Quest="FrostQuest", Slot=3, QuestCFrame=CFrame.new(5668.9780273438, 28.519989013672, -6483.3520507813), BossCFrame=CFrame.new(6403.5439453125, 340.29766845703, -6894.5595703125) },
        ["Tide Keeper"] = { Model="Tide Keeper", Quest="ForgottenQuest", Slot=3, QuestCFrame=CFrame.new(-3053.9814453125, 237.18954467773, -10145.0390625), BossCFrame=CFrame.new(-3795.6423339844, 105.88877105713, -11421.307617188) },
        ["Darkbeard"] = { Model="Darkbeard", Quest=nil, Slot=nil, QuestCFrame=CFrame.new(3677.08203125, 62.751937866211, -3144.8332519531), BossCFrame=CFrame.new(3677.08203125, 62.751937866211, -3144.8332519531) },
        ["Cursed Captaim"] = { Model="Cursed Captain", Quest=nil, Slot=nil, QuestCFrame=CFrame.new(916.928589, 181.092773, 33422), BossCFrame=CFrame.new(916.928589, 181.092773, 33422) },
        ["Order"] = { Model="Order", Quest=nil, Slot=nil, QuestCFrame=CFrame.new(-6217.2021484375, 28.047645568848, -5053.1357421875), BossCFrame=CFrame.new(-6217.2021484375, 28.047645568848, -5053.1357421875) },
    },
    [3] = {
        ["Stone"] = { Model="Stone", Quest="PiratePortQuest", Slot=3, QuestCFrame=CFrame.new(-289.76705932617, 43.819011688232, 5579.9384765625), BossCFrame=CFrame.new(-1027.6512451172, 92.404174804688, 6578.8530273438) },
        ["Hydra Leader"] = { Model="Hydra Leader", Quest="VenomCrewQuest", Slot=3, QuestCFrame=CFrame.new(5211.021484375, 1004.35778859375, 758.1847534179688), BossCFrame=CFrame.new(5821.89794921875, 1019.0950927734375, -73.71923065185547) },
        ["Kilo Admiral"] = { Model="Kilo Admiral", Quest="MarineTreeIsland", Slot=3, QuestCFrame=CFrame.new(2179.3010253906, 28.731239318848, -6739.9741210938), BossCFrame=CFrame.new(2764.2233886719, 432.46154785156, -7144.4580078125) },
        ["Captain Elephant"] = { Model="Captain Elephant", Quest="DeepForestIsland", Slot=3, QuestCFrame=CFrame.new(-13232.682617188, 332.40396118164, -7626.01171875), BossCFrame=CFrame.new(-13376.7578125, 433.28689575195, -8071.392578125) },
        ["Beautiful Pirate"] = { Model="Beautiful Pirate", Quest="DeepForestIsland2", Slot=3, QuestCFrame=CFrame.new(-12682.096679688, 390.88653564453, -9902.1240234375), BossCFrame=CFrame.new(5283.609375, 22.56223487854, -110.78285217285) },
        ["Cake Queen"] = { Model="Cake Queen", Quest="IceCreamIslandQuest", Slot=3, QuestCFrame=CFrame.new(-819.376709, 64.9259796, -10967.2832, -0.766061664, 0, 0.642767608, 0, 1, 0, -0.642767608, 0, -0.766061664), BossCFrame=CFrame.new(-678.648804, 381.353943, -11114.2012, -0.908641815, 0.00149294338, 0.41757378, 0.00837114919, 0.999857843, 0.0146408929, -0.417492568, 0.0167988986, -0.90852499) },
        ["Longma"] = { Model="Longma", Quest=nil, Slot=nil, QuestCFrame=CFrame.new(-10238.875976563, 389.7912902832, -9549.7939453125), BossCFrame=CFrame.new(-10238.875976563, 389.7912902832, -9549.7939453125) },
        ["Soul Reaper"] = { Model="Soul Reaper", Quest=nil, Slot=nil, QuestCFrame=CFrame.new(-9524.7890625, 315.80429077148, 6655.7192382813), BossCFrame=CFrame.new(-9524.7890625, 315.80429077148, 6655.7192382813) },
    },
}

local BOSS_LISTS = {
    [1] = { "The Gorilla King", "Bobby", "The Saw", "Yeti", "Mob Leader", "Vice Admiral", "Saber Expert", "Warden", "Chief Warden", "Swan", "Magma Admiral", "Fishman Lord", "Wysper", "Thunder God", "Cyborg", "Ice Admiral", "Greybeard" },
    [2] = { "Diamond", "Jeremy", "Orbitus", "Don Swan", "Smoke Admiral", "Awakened Ice Admiral", "Tide Keeper", "Darkbeard", "Cursed Captain", "Order" },
    [3] = { "Stone", "Hydra Leader", "Kilo Admiral", "Captain Elephant", "Beautiful Pirate", "Cake Queen", "Dough King", "Longma", "Soul Reaper", "rip_indra True Form", "Tyrant of the Skies" },
}

local MATERIAL_DATA = {
    [1] = {
        ["Angel Wings"] = { Enemies={"God's Guard"}, CFrame=CFrame.new(-4721.36377, 848.927002, -1935.25195, -0.38518405, 0.194819495, 0.902041435, 0.134163186, 0.978899539, -0.154129535, -0.913035393, 0.0616525188, -0.40319407) },
        ["Leather + Scrap Metal"] = { Enemies={"Brute", "Pirate"}, CFrame=CFrame.new(-1150.06604, 58.0500031, 4164.63477, -0.156446099, 0, 0.987686574, 0, 1, 0, -0.987686574, 0, -0.156446099) },
        ["Magma Ore"] = { Enemies={"Military Soldier", "Military Spy", "Magma Admiral"}, CFrame=CFrame.new(-5514.16504, 61.553009, 8577.87207, 0.819155693, -0.0000823268638, -0.573571265, 0.0000823268638, 1, -0.000025957268, 0.573571265, -0.000025957268, 0.819155693) },
        ["Fish Tail"] = { Enemies={"Fishman Warrior"}, CFrame=CFrame.new(60874.8242, 17.2460022, 1342.86206, 0.786440969, -0.0395703204, 0.616396666, 0.0789907277, 0.99619478, -0.0368298516, -0.61259377, 0.0776541233, 0.786574006) },
    },
    [2] = {
        ["Leather + Scrap Metal"] = { Enemies={"Marine Captain"}, CFrame=CFrame.new(-2010, 73, -3326) },
        ["Magma Ore"] = { Enemies={"Magma Ninja", "Lava Pirate"}, CFrame=CFrame.new(-5428, 78, -5959) },
        ["Ectoplasm"] = { Enemies={"Ship Deckhand", "Ship Engineer", "Ship Steward", "Ship Officer"}, CFrame=CFrame.new(911, 125, 33159) },
        ["Mystic Droplet"] = { Enemies={"Water Fighter"}, CFrame=CFrame.new(-3385, 239, -10542) },
        ["Radioactive Material"] = { Enemies={"Factory Staff"}, CFrame=CFrame.new(295, 73, -56) },
        ["Vampire Fang"] = { Enemies={"Vampire"}, CFrame=CFrame.new(-6033, 7, -1317) },
    },
    [3] = {
        ["Scrap Metal"] = { Enemies={"Jungle Pirate", "Forest Pirate"}, CFrame=CFrame.new(-11975, 331, -10620) },
        ["Fish Tail"] = { Enemies={"Fishman Raider", "Fishman Captain"}, CFrame=CFrame.new(-10993, 332, -8940) },
        ["Conjured Cocoa"] = { Enemies={"Chocolate Bar Battler", "Cocoa Warrior"}, CFrame=CFrame.new(620, 78, -12581) },
        ["Dragon Scale"] = { Enemies={"Dragon Crew Archer", "Dragon Crew Warrior"}, CFrame=CFrame.new(6594, 383, 139) },
        ["Gunpowder"] = { Enemies={"Pistol Billionaire"}, CFrame=CFrame.new(-85, 85, 6132) },
        ["Mini Tusk"] = { Enemies={"Mythological Pirate"}, CFrame=CFrame.new(-13545, 470, -6917) },
        ["Demonic Wisp"] = { Enemies={"Demonic Soul"}, CFrame=CFrame.new(-9495, 453, 5977) },
    },
}

local MATERIAL_LISTS = {
    [1] = { "Angel Wings", "Leather + Scrap Metal", "Magma Ore", "Fish Tail" },
    [2] = { "Leather + Scrap Metal", "Magma Ore", "Ectoplasm", "Mystic Droplet", "Radioactive Material", "Vampire Fang" },
    [3] = { "Scrap Metal", "Fish Tail", "Conjured Cocoa", "Dragon Scale", "Gunpowder", "Mini Tusk", "Demonic Wisp" },
}

-- Exact current metadata defect, repaired only at the public selection boundary.
local BOSS_ALIASES = { ["Cursed Captain"] = "Cursed Captaim" }

-- Stable, sea-specific travel catalog. Live _WorldOrigin markers are merged
-- into this list, but are not required for the dropdown or chest scanner.
local ISLAND_DATA = {
    [1] = {
        {Name="Pirate Starter", CFrame=CFrame.new(1059, 20, 1552)},
        {Name="Marine Starter", CFrame=CFrame.new(-2709, 28, 2105)},
        {Name="Middle Town", CFrame=CFrame.new(-690, 15, 1583)},
        {Name="Jungle", CFrame=CFrame.new(-1598, 42, 153)},
        {Name="Pirate Village", CFrame=CFrame.new(-1141, 12, 3832)},
        {Name="Desert", CFrame=CFrame.new(895, 14, 4392)},
        {Name="Frozen Village", CFrame=CFrame.new(1387, 95, -1295)},
        {Name="Marine Fortress", CFrame=CFrame.new(-5040, 35, 4325)},
        {Name="Lower Skylands", CFrame=CFrame.new(-4840, 724, -2619)},
        {Name="Prison", CFrame=CFrame.new(5309, 10, 475)},
        {Name="Colosseum", CFrame=CFrame.new(-1580, 14, -2986)},
        {Name="Magma Village", CFrame=CFrame.new(-5313, 19, 8515)},
        {Name="Underwater City", CFrame=CFrame.new(61123, 26, 1569)},
        {Name="Upper Skylands", CFrame=CFrame.new(-7907, 5643, -1412)},
        {Name="Fountain City", CFrame=CFrame.new(5260, 45, 4050)},
    },
    [2] = {
        {Name="Kingdom of Rose", CFrame=CFrame.new(-430, 80, 1836)},
        {Name="Cafe", CFrame=CFrame.new(-386, 80, 297)},
        {Name="Second Sea Colosseum", CFrame=CFrame.new(-1836, 52, 1360)},
        {Name="Factory", CFrame=CFrame.new(633, 81, 919)},
        {Name="Green Zone", CFrame=CFrame.new(-2441, 80, -3216)},
        {Name="Graveyard", CFrame=CFrame.new(-5497, 56, -795)},
        {Name="Snow Mountain", CFrame=CFrame.new(610, 408, -5372)},
        {Name="Hot and Cold", CFrame=CFrame.new(-5428, 24, -5299)},
        {Name="Cursed Ship", CFrame=CFrame.new(1038, 133, 32912)},
        {Name="Ice Castle", CFrame=CFrame.new(5668, 35, -6486)},
        {Name="Forgotten Island", CFrame=CFrame.new(-3054, 244, -10143)},
        {Name="Dark Arena", CFrame=CFrame.new(3677, 70, -3145)},
    },
    [3] = {
        {Name="Port Town", CFrame=CFrame.new(-713, 107, 5712)},
        {Name="Hydra Island", CFrame=CFrame.new(5229, 604, 345)},
        {Name="Great Tree", CFrame=CFrame.new(2180, 37, -6740)},
        {Name="Floating Turtle", CFrame=CFrame.new(-12680, 398, -9902)},
        {Name="Mansion", CFrame=CFrame.new(-12548, 345, -7482)},
        {Name="Castle on the Sea", CFrame=CFrame.new(-5073, 323, -3152)},
        {Name="Haunted Castle", CFrame=CFrame.new(-9479, 149, 5566)},
        {Name="Peanut Land", CFrame=CFrame.new(-2104, 46, -10194)},
        {Name="Ice Cream Land", CFrame=CFrame.new(-821, 74, -10966)},
        {Name="Cake Land", CFrame=CFrame.new(-2021, 46, -12029)},
        {Name="Chocolate Land", CFrame=CFrame.new(233, 38, -12201)},
        {Name="Candy Land", CFrame=CFrame.new(-1150, 28, -14446)},
        {Name="Tiki Outpost", CFrame=CFrame.new(-16549, 64, -173)},
        {Name="Submerged Island", CFrame=CFrame.new(10882, -2078, 10034)},
    },
}

local ISLAND_LOOKUP = {}
for _, island in ipairs(ISLAND_DATA[Sea] or {}) do ISLAND_LOOKUP[island.Name] = island end

-- Current canonical inventory/shop identifiers. Physical tools use display
-- names such as "Rocket Fruit", while CommF_ StoreFruit expects Rocket-Rocket.
local FRUIT_NAMES = {
    "Rocket-Rocket", "Spin-Spin", "Blade-Blade", "Spring-Spring", "Bomb-Bomb",
    "Smoke-Smoke", "Spike-Spike", "Flame-Flame", "Ice-Ice", "Sand-Sand",
    "Dark-Dark", "Eagle-Eagle", "Diamond-Diamond", "Light-Light", "Rubber-Rubber",
    "Ghost-Ghost", "Magma-Magma", "Quake-Quake", "Buddha-Buddha", "Love-Love",
    "Creation-Creation", "Spider-Spider", "Sound-Sound", "Phoenix-Phoenix",
    "Portal-Portal", "Lightning-Lightning", "Pain-Pain", "Blizzard-Blizzard",
    "Gravity-Gravity", "T-Rex-T-Rex", "Mammoth-Mammoth", "Dough-Dough",
    "Shadow-Shadow", "Venom-Venom", "Gas-Gas", "Control-Control", "Spirit-Spirit",
    "Leopard-Leopard", "Yeti-Yeti", "Kitsune-Kitsune", "Dragon-Dragon",
}

local FRUIT_NAME_LOOKUP = {}
for _, name in ipairs(FRUIT_NAMES) do FRUIT_NAME_LOOKUP[string.lower(name)] = name end
local FRUIT_BASE_ALIASES = {
    chop = "Blade",
    falcon = "Eagle",
    barrier = "Creation",
    rumble = "Lightning",
}

local Settings = {
    ProfileVersion = 2,
    AutoFarmLevel = false,
    AutoFarmNearest = false,
    AutoKillMob = false,
    AutoFarmBoss = false,
    AutoFarmAllBoss = false,
    AutoFarmMaterial = false,
    AutoEliteHunter = false,
    AutoRefreshBossList = true,
    AutoObservation = false,
    AutoFarmObservation = false,
    AutoCollectChest = false,
    WholeSeaChestSweep = true,
    AutoCollectBerries = false,
    AutoRaid = false,
    AutoEventEnemy = false,
    AcceptLevelQuests = true,
    AcceptBossQuests = true,
    BringMobs = true,
    FastAttack = true,
    ActivateTool = true,
    SelectedMob = Sea == 1 and "Bandit" or (Sea == 2 and "Raider" or "Pirate Millionaire"),
    SelectedBoss = BOSS_LISTS[Sea][1],
    SelectedMaterial = MATERIAL_LISTS[Sea][1],
    SelectedRaidChip = "Flame",
    SelectedStockFruit = "Light-Light",
    SelectedStoreFruit = "All Fruits",
    RedeemCode = "",
    JoinJobId = "",
    SelectedEventEnemy = "Terrorshark",
    SelectedIsland = "",
    SelectedFishingRod = "Fishing Rod",
    SelectedBait = "Basic Bait",
    AutoFishing = false,
    AutoBuyBait = false,
    AutoFishingQuest = false,
    AutoDojoTrainer = false,
    AutoFarmMastery = false,
    MasteryType = "Blox Fruit",
    LockWalkSpeed = false,
    LockJumpPower = false,
    SelectedPlayer = "",
    TeleportToPlayer = false,
    SpectatePlayer = false,
    AimbotCamera = false,
    AimbotSkills = false,
    InfiniteMinkV3 = false,
    InfiniteEnergy = false,
    InfiniteSoru = false,
    InfiniteObservationRange = false,
    IgnoreSameTeams = false,
    AcceptAllies = false,
    WalkOnWater = true,
    WalkSpeed = 16,
    JumpPower = 50,
    WeaponCategory = "Melee",
    ExactToolName = nil,
    Height = 20,
    TweenSpeed = 300,
    BringRadius = 3000,
    TargetRadius = 60,
    HitboxSize = 60,
    HitboxTransparency = 1,
    AttackMode = "Instant",
    StatsValue = 2,
    AutoMelee = false,
    AutoDefense = false,
    AutoSword = false,
    AutoGun = false,
    AutoFruitStats = false,
    AutoRandomFruit = false,
    AutoCollectFruit = false,
    AutoStoreFruit = false,
    AutoBuyStockFruit = false,
    FruitESP = false,
    ChestESP = false,
    BerryESP = false,
    IslandESP = false,
    PlayerESP = false,
    AutoRaceV3 = false,
    AutoRaceV4 = false,
    AutoSeaBeast = false,
    AutoShark = false,
    AutoPiranha = false,
    AutoTerrorShark = false,
    AutoCombatSkills = false,
    AutoSkillZ = true,
    AutoSkillX = true,
    AutoSkillC = true,
    AutoSkillV = true,
    AutoSkillF = false,
    AutoBuso = true,
    AntiAFK = true,
    FullBright = false,
    RemoveFog = false,
    AggressiveFPSBoost = false,
    CreateUI = true,
}

local SETTINGS_FOLDER = "BloxFruitScript"
local SETTINGS_PATH = SETTINGS_FOLDER .. "/Sea" .. tostring(Sea) .. ".json"
Environment.__BloxFruitScriptProfiles = Environment.__BloxFruitScriptProfiles or {}

local function serializableSettings()
    local output = {}
    for key, value in pairs(Settings) do
        if type(value) == "boolean" or type(value) == "number" or type(value) == "string" then
            output[key] = value
        end
    end
    return output
end

local function loadPersistentSettings()
    local saved = Environment.__BloxFruitScriptProfiles[Sea]
    if type(isfile) == "function" and type(readfile) == "function" and isfile(SETTINGS_PATH) then
        local ok, decoded = pcall(function() return HttpService:JSONDecode(readfile(SETTINGS_PATH)) end)
        if ok and type(decoded) == "table" then saved = decoded end
    end
    if type(saved) == "table" then
        for key, value in pairs(saved) do
            if Settings[key] ~= nil and type(value) == type(Settings[key]) then Settings[key] = value end
        end
    end
    return type(saved) == "table" and (tonumber(saved.ProfileVersion) or 0) or 0
end

local SettingsSaveGeneration = 0
local function savePersistentSettings(immediate)
    SettingsSaveGeneration += 1
    local generation = SettingsSaveGeneration
    local function write()
        if generation ~= SettingsSaveGeneration then return end
        local payload = serializableSettings()
        Environment.__BloxFruitScriptProfiles[Sea] = payload
        if type(writefile) == "function" and type(makefolder) == "function" then
            pcall(function()
                if type(isfolder) ~= "function" or not isfolder(SETTINGS_FOLDER) then makefolder(SETTINGS_FOLDER) end
                writefile(SETTINGS_PATH, HttpService:JSONEncode(payload))
            end)
        end
    end
    if immediate then write() else task.delay(0.6, write) end
end

local loadedProfileVersion = loadPersistentSettings()
local RETIRED_FRUIT_IDS = {
    ["Chop-Chop"] = "Blade-Blade",
    ["Falcon-Falcon"] = "Eagle-Eagle",
    ["Barrier-Barrier"] = "Creation-Creation",
    ["Rumble-Rumble"] = "Lightning-Lightning",
}
Settings.SelectedStockFruit = RETIRED_FRUIT_IDS[Settings.SelectedStockFruit] or Settings.SelectedStockFruit
Settings.SelectedStoreFruit = RETIRED_FRUIT_IDS[Settings.SelectedStoreFruit] or Settings.SelectedStoreFruit
if not FRUIT_NAME_LOOKUP[string.lower(Settings.SelectedStockFruit)] then Settings.SelectedStockFruit = "Light-Light" end
if Settings.SelectedStoreFruit ~= "All Fruits"
    and not FRUIT_NAME_LOOKUP[string.lower(Settings.SelectedStoreFruit)]
then
    Settings.SelectedStoreFruit = "All Fruits"
end
if loadedProfileVersion < 2 then
    -- Existing profiles predate the requested instant-by-default cadence.
    Settings.AttackMode = "Instant"
    Settings.ProfileVersion = 2
    savePersistentSettings(true)
end

local ATTACK_DELAYS = {
    ["Normal Attack"] = 0.3,
    ["Fast Attack"] = 0.2,
    ["Super Fast Attack"] = 0.1,
    ["Instant"] = 0.03,
}

local FARM_TOGGLE_KEYS = {
    AutoFarmLevel = true,
    AutoFarmNearest = true,
    AutoKillMob = true,
    AutoFarmBoss = true,
    AutoFarmAllBoss = true,
    AutoFarmMaterial = true,
    AutoEliteHunter = true,
    AutoFarmObservation = true,
    AutoFarmMastery = true,
    AutoRaid = true,
    AutoSeaBeast = true,
    AutoEventEnemy = true,
}

local Runtime = {
    Alive = true,
    Connections = {},
    EnemyBuckets = {},
    CurrentTarget = nil,
    CurrentMode = "Idle",
    FastTargets = {},
    HitParts = {},
    PrimaryTarget = nil,
    AttackTransport = nil,
    LastAttack = 0,
    LastQuestRemote = 0,
    LastSimulationRadius = 0,
    MovementTween = nil,
    MovementGoal = nil,
    MovementOwner = nil,
    MovementCharacter = nil,
    MovementStarted = 0,
    MovementLastProgress = 0,
    MovementLastPosition = nil,
    MovementRetryCount = 0,
    MovementRetryGoal = nil,
    BlockedMovementGoal = nil,
    BlockedMovementUntil = 0,
    LastRejectedNavigation = nil,
    NavigationRejectCount = 0,
    LastLandCFrame = nil,
    RecoveryCount = 0,
    ForceReleaseUntil = 0,
    ManualTravelHold = false,
    ManualTravelInProgress = false,
    Respawning = false,
    CharacterGeneration = 0,
    RespawnFarmSettings = nil,
    UIHydrating = false,
    FarmAnchor = nil,
    FarmAnchorKey = nil,
    AnchorReached = false,
    OwnedBodyMovers = setmetatable({}, { __mode = "k" }),
    CollisionState = setmetatable({}, { __mode = "k" }),
    EnemyMutationState = setmetatable({}, { __mode = "k" }),
    FeatureLastRun = {},
    Chests = setmetatable({}, { __mode = "k" }),
    Berries = setmetatable({}, { __mode = "k" }),
    Islands = setmetatable({}, { __mode = "k" }),
    EnemySpawnBuckets = {},
    EnemySpawnRoot = nil,
    ChestCooldown = setmetatable({}, { __mode = "k" }),
    BerryCooldown = setmetatable({}, { __mode = "k" }),
    FruitCooldown = setmetatable({}, { __mode = "k" }),
    PickupBusy = false,
    PickupKind = nil,
    PickupTarget = nil,
    PickupLastFound = 0,
    ChestSweepQueue = nil,
    ChestSweepIndex = 1,
    ChestSweepArrivedAt = nil,
    ChestSweepNextAt = 0,
    ChestStreamRequestBusy = false,
    ChestStreamRequestSupported = true,
    AllBossIndex = 1,
    AllBossArrivedAt = nil,
    ESPObjects = setmetatable({}, { __mode = "k" }),
    RaidSummonAttempt = 0,
    UIControls = {},
    AttackAttempts = 0,
    DamageRegistrations = 0,
    ObservedHealth = setmetatable({}, { __mode = "k" }),
    CombatToken = nil,
    CombatTransport = "initializing",
    TokenHookInstalled = false,
    LastTokenProbe = 0,
    LastBatchSize = 0,
    BossDropdown = nil,
    IslandDropdown = nil,
    PlayerDropdown = nil,
    StaticIslandParts = {},
    StatusCards = {},
    VisualState = setmetatable({}, { __mode = "k" }),
    FPSWorldState = nil,
    EnergyFloor = nil,
    WaterPart = nil,
    OriginalCameraSubject = nil,
    SkillAimbotHookInstalled = false,
    SoruClosures = nil,
    LastFruitSpinResult = nil,
    LastFruitStoreResult = nil,
    LastFruitStockResult = nil,
    FruitStoreDropdown = nil,
    FruitStockDropdown = nil,
}

local function connect(signal, callback)
    local connection = signal:Connect(callback)
    table.insert(Runtime.Connections, connection)
    return connection
end

local function character()
    return LocalPlayer.Character
end

local function characterParts()
    local model = character()
    if not model then return nil, nil, nil end
    return model, model:FindFirstChildOfClass("Humanoid"), model:FindFirstChild("HumanoidRootPart")
end

local function aliveModel(model)
    if not model or not model.Parent then return nil, nil end
    local humanoid = model:FindFirstChildOfClass("Humanoid") or model:FindFirstChild("Humanoid")
    local root = model:FindFirstChild("HumanoidRootPart")
    if not humanoid or not root or humanoid.Health <= 0 then return nil, nil end
    return humanoid, root
end

local function enemiesFolder()
    return workspace:FindFirstChild("Enemies")
end

local function addEnemy(model)
    if not model:IsA("Model") then return end
    local name = model.Name
    local bucket = Runtime.EnemyBuckets[name]
    if not bucket then
        bucket = setmetatable({}, { __mode = "k" })
        Runtime.EnemyBuckets[name] = bucket
    end
    bucket[model] = true
end

local function removeEnemy(model)
    local bucket = Runtime.EnemyBuckets[model.Name]
    if bucket then bucket[model] = nil end
    if Runtime.CurrentTarget == model then Runtime.CurrentTarget = nil end
end

local function rebuildEnemyCache()
    table.clear(Runtime.EnemyBuckets)
    local folder = enemiesFolder()
    if not folder then return end
    for _, model in ipairs(folder:GetChildren()) do addEnemy(model) end
end

local EnemyFolder = enemiesFolder() or workspace:WaitForChild("Enemies", 15)
assert(EnemyFolder, "BloxFruitScript: workspace.Enemies was not found")
rebuildEnemyCache()
connect(EnemyFolder.ChildAdded, addEnemy)
connect(EnemyFolder.ChildRemoved, removeEnemy)

local function canonicalFruitName(value)
    local raw = string.match(tostring(value or ""), "^%s*(.-)%s*$")
    if raw == "" then return nil end
    local exact = FRUIT_NAME_LOOKUP[string.lower(raw)]
    if exact then return exact end

    local bracketed = string.match(raw, "[Ff]ruit%s*%[([^%]]+)%]")
    local base = bracketed or raw
    base = string.gsub(base, "%s+[Ff]ruit$", "")
    base = string.gsub(base, "^[Ff]ruit%s+", "")
    base = string.match(base, "^%s*(.-)%s*$")
    local alias = FRUIT_BASE_ALIASES[string.lower(base)]
    if alias then base = alias end
    local canonical = base .. "-" .. base
    return FRUIT_NAME_LOOKUP[string.lower(canonical)] or canonical
end

local function fruitIdentity(tool)
    if not tool or not tool:IsA("Tool") then return nil end
    local original = tool:GetAttribute("OriginalName")
        or tool:GetAttribute("FruitName")
        or tool:GetAttribute("FruitId")
    local tooltip = string.lower(tostring(tool.ToolTip or ""))
    local raw = type(original) == "string" and original or tool.Name
    if type(original) ~= "string"
        and not string.find(string.lower(raw), "fruit", 1, true)
        and not string.find(tooltip, "fruit", 1, true)
    then
        return nil
    end
    return canonicalFruitName(raw)
end

local WorldFruits = setmetatable({}, { __mode = "k" })
local function trackWorldFruit(instance)
    if instance:IsA("Tool") and fruitIdentity(instance) and not instance:IsDescendantOf(LocalPlayer) then
        WorldFruits[instance] = true
    end
end
for _, instance in ipairs(workspace:GetDescendants()) do trackWorldFruit(instance) end
connect(workspace.DescendantAdded, trackWorldFruit)
connect(workspace.DescendantRemoving, function(instance)
    WorldFruits[instance] = nil
    Runtime.FruitCooldown[instance] = nil
end)

local function chestCandidate(instance)
    if not (instance:IsA("Model") or instance:IsA("BasePart")) then return false end
    local name = string.lower(instance.Name)
    return string.find(name, "chest", 1, true) ~= nil
        or CollectionService:HasTag(instance, "_ChestTagged")
end

local function destroyESPEntry(instance)
    local entry = Runtime.ESPObjects[instance]
    if type(entry) == "table" then
        for _, object in pairs(entry) do
            if typeof(object) == "Instance" then pcall(object.Destroy, object) end
        end
    elseif typeof(entry) == "Instance" then
        pcall(entry.Destroy, entry)
    end
    Runtime.ESPObjects[instance] = nil
end

local function canonicalChest(instance)
    local current, found = instance, nil
    while current and current ~= workspace do
        if CollectionService:HasTag(current, "_ChestTagged") then return current end
        if not found and chestCandidate(current) then found = current end
        current = current.Parent
    end
    return found
end

local function trackChest(instance)
    local chest = canonicalChest(instance)
    if chest then Runtime.Chests[chest] = true end
end

local function berryCandidate(instance)
    if CollectionService:HasTag(instance, "BerryBush") then return true end
    if not (instance:IsA("Model") or instance:IsA("BasePart")) then return false end
    return string.find(string.lower(instance.Name), "berry", 1, true) ~= nil
end

local function canonicalBerry(instance)
    local current, found, tagged = instance, nil, nil
    while current and current ~= workspace do
        if CollectionService:HasTag(current, "BerryBush") then tagged = current end
        if berryCandidate(current) then found = current end
        current = current.Parent
    end
    return tagged or found
end

local function trackBerry(instance)
    local berry = canonicalBerry(instance)
    if berry then Runtime.Berries[berry] = true end
end

local function trackIsland(instance)
    local parent = instance.Parent
    if parent and parent.Name == "Locations"
        and parent.Parent and parent.Parent.Name == "_WorldOrigin"
        and (instance:IsA("Model") or instance:IsA("BasePart"))
    then
        Runtime.Islands[instance] = true
    end
end

local function normalizedEntityName(value)
    local name = string.lower(tostring(value or ""))
    name = string.gsub(name, "%s*%[lv%.?%s*%d+%].*", "")
    name = string.gsub(name, "%s*%[boss%].*", "")
    name = string.gsub(name, "^%s+", "")
    name = string.gsub(name, "%s+$", "")
    return name
end

local function enemySpawnAncestor(instance)
    local current = instance and instance.Parent
    while current and current ~= workspace do
        if current.Name == "EnemySpawns" then return current end
        current = current.Parent
    end
end

local function trackEnemySpawn(instance)
    if not instance:IsA("BasePart") then return end
    local spawnRoot = enemySpawnAncestor(instance)
    if not spawnRoot then return end
    Runtime.EnemySpawnRoot = spawnRoot
    local names = {instance.Name}
    if instance.Parent and instance.Parent ~= spawnRoot then names[#names + 1] = instance.Parent.Name end
    for _, value in ipairs(names) do
        local key = normalizedEntityName(value)
        if key ~= "" and key ~= "spawn" and key ~= "spawnlocation" then
            local bucket = Runtime.EnemySpawnBuckets[key]
            if not bucket then
                bucket = setmetatable({}, { __mode = "k" })
                Runtime.EnemySpawnBuckets[key] = bucket
            end
            bucket[instance] = true
        end
    end
end

for _, instance in ipairs(workspace:GetDescendants()) do
    trackChest(instance)
    trackBerry(instance)
    trackIsland(instance)
    trackEnemySpawn(instance)
end
for _, taggedChest in ipairs(CollectionService:GetTagged("_ChestTagged")) do trackChest(taggedChest) end
for _, bush in ipairs(CollectionService:GetTagged("BerryBush")) do trackBerry(bush) end
connect(CollectionService:GetInstanceAddedSignal("_ChestTagged"), trackChest)
connect(CollectionService:GetInstanceRemovedSignal("_ChestTagged"), function(instance)
    local chest = canonicalChest(instance) or instance
    Runtime.Chests[chest] = nil
    Runtime.ChestCooldown[chest] = nil
    destroyESPEntry(chest)
end)
connect(CollectionService:GetInstanceAddedSignal("BerryBush"), trackBerry)
connect(CollectionService:GetInstanceRemovedSignal("BerryBush"), function(instance)
    Runtime.Berries[instance] = nil
    destroyESPEntry(instance)
end)
connect(workspace.DescendantAdded, function(instance)
    trackChest(instance)
    trackBerry(instance)
    trackIsland(instance)
    trackEnemySpawn(instance)
end)
connect(workspace.DescendantRemoving, function(instance)
    for chest in pairs(Runtime.Chests) do
        if chest == instance or chest:IsDescendantOf(instance) then
            Runtime.Chests[chest] = nil
            Runtime.ChestCooldown[chest] = nil
            destroyESPEntry(chest)
        end
    end
    for berry in pairs(Runtime.Berries) do
        if berry == instance or berry:IsDescendantOf(instance) then
            Runtime.Berries[berry] = nil
            Runtime.BerryCooldown[berry] = nil
            destroyESPEntry(berry)
        end
    end
    Runtime.Islands[instance] = nil
    destroyESPEntry(instance)
end)

local Remotes = ReplicatedStorage:FindFirstChild("Remotes") or ReplicatedStorage:WaitForChild("Remotes", 15)
local CommF = Remotes and (Remotes:FindFirstChild("CommF_") or Remotes:WaitForChild("CommF_", 10))
local CommE = Remotes and Remotes:FindFirstChild("CommE")
local RedeemRemote = Remotes and Remotes:FindFirstChild("Redeem")
local Modules = ReplicatedStorage:FindFirstChild("Modules")
local Net = Modules and Modules:FindFirstChild("Net")
local RegisterAttack = Net and Net:FindFirstChild("RE/RegisterAttack")
local RegisterHit = Net and Net:FindFirstChild("RE/RegisterHit")
local FishingRequest = (Net and Net:FindFirstChild("RF/FishingRequest"))
    or (Remotes and Remotes:FindFirstChild("FishingRequest", true))
local DragonHunterRemote = (Net and Net:FindFirstChild("RF/DragonHunter"))
local DragonQuestRemote = (Net and Net:FindFirstChild("RF/InteractDragonQuest"))
local LegacyRigController = ReplicatedStorage:FindFirstChild("RigControllerEvent")

local function resolveCommF()
    if CommF and CommF.Parent then return CommF end
    Remotes = ReplicatedStorage:FindFirstChild("Remotes") or ReplicatedStorage:WaitForChild("Remotes", 5)
    CommF = Remotes and (Remotes:FindFirstChild("CommF_") or Remotes:WaitForChild("CommF_", 5))
    return CommF
end

local function invokeComm(...)
    local remote = resolveCommF()
    if not remote then return false, "CommF_ unavailable" end
    local ok, result = pcall(remote.InvokeServer, remote, ...)
    return ok, result
end

local function fireComm(...)
    if not CommE then return false end
    local ok = pcall(CommE.FireServer, CommE, ...)
    return ok
end

local function isCombatToken(value)
    return type(value) == "string" and #value == 8 and value:match("^%x+$") ~= nil
end

local function captureCombatToken(value)
    if not isCombatToken(value) then return false end
    Runtime.CombatToken = value
    Runtime.CombatTransport = "Net token ready"
    return true
end

local function inspectTokenValues(values)
    for _, value in pairs(values) do
        if captureCombatToken(value) then return true end
    end
    return false
end

local function watchTokenRemote(instance)
    if not instance:IsA("RemoteEvent") then return end
    connect(instance.OnClientEvent, function(...)
        if Runtime.Alive then inspectTokenValues({...}) end
    end)
end

local function scanLoadedCombatState()
    if type(getgc) ~= "function" then return false end
    local ok, objects = pcall(getgc, true)
    if not ok or type(objects) ~= "table" then return false end
    for _, object in ipairs(objects) do
        if isCombatToken(object) then
            captureCombatToken(object)
            return true
        elseif type(object) == "table" then
            for _, value in pairs(object) do
                if isCombatToken(value) then
                    captureCombatToken(value)
                    return true
                end
            end
        elseif type(object) == "function" and type(debug) == "table"
            and type(debug.getupvalues) == "function"
        then
            local success, upvalues = pcall(debug.getupvalues, object)
            if success and type(upvalues) == "table" and inspectTokenValues(upvalues) then return true end
        end
    end
    return false
end

local function installCombatTokenCapture()
    if Runtime.TokenHookInstalled or not RegisterHit then return end
    Runtime.TokenHookInstalled = true

    if Net then
        for _, remote in ipairs(Net:GetDescendants()) do watchTokenRemote(remote) end
        connect(Net.DescendantAdded, watchTokenRemote)
    end

    if type(hookmetamethod) == "function" and type(getnamecallmethod) == "function" then
        local oldNamecall
        local interceptor = function(self, ...)
            local args = {...}
            local method = getnamecallmethod()
            if Runtime.Alive and method == "FireServer" and self == RegisterHit then
                captureCombatToken(args[4])
            end
            local results = table.pack(oldNamecall(self, ...))
            if Runtime.Alive and method == "InvokeServer" then
                for index = 1, results.n do captureCombatToken(results[index]) end
            end
            return table.unpack(results, 1, results.n)
        end
        if type(newcclosure) == "function" then interceptor = newcclosure(interceptor) end
        local installed, original = pcall(hookmetamethod, game, "__namecall", interceptor)
        if installed then oldNamecall = original end
    end

    scanLoadedCombatState()
end

local function probeCombatToken()
    if not RegisterAttack or Runtime.CombatToken then return end
    local now = os.clock()
    if now - Runtime.LastTokenProbe < 2 then return end
    Runtime.LastTokenProbe = now
    task.spawn(function()
        for _ = 1, 5 do
            if not Runtime.Alive or Runtime.CombatToken then break end
            pcall(RegisterAttack.FireServer, RegisterAttack, 0.5)
            pcall(function()
                VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 0)
                task.wait(0.04)
                VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 0)
            end)
            task.wait(0.12)
        end
        if not Runtime.CombatToken then scanLoadedCombatState() end
    end)
end

if RegisterAttack and RegisterHit then
    Runtime.CombatTransport = "Net token pending"
    installCombatTokenCapture()
    probeCombatToken()
elseif LegacyRigController then
    Runtime.CombatTransport = "Legacy RigController"
else
    Runtime.CombatTransport = "Input fallback"
end

local function activeFarmMode()
    if Settings.AutoRaid then return "Raid" end
    if Settings.AutoSeaBeast then return "SeaBeast" end
    if Settings.AutoEventEnemy then return "Event" end
    if Settings.AutoFarmObservation then return "Observation" end
    if Settings.AutoFarmMastery then return "Mastery" end
    if Settings.AutoEliteHunter then return "Elite" end
    if Settings.AutoFarmMaterial then return "Material" end
    if Settings.AutoFarmBoss then return "Boss" end
    if Settings.AutoFarmAllBoss then return "AllBoss" end
    if Settings.AutoKillMob then return "Mob" end
    if Settings.AutoFarmNearest then return "Nearest" end
    if Settings.AutoFarmLevel then return "Level" end
    return nil
end

local function farmEnabled()
    return activeFarmMode() ~= nil
end

local function getQuestState()
    local gui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    local main = gui and gui:FindFirstChild("Main")
    local quest = main and main:FindFirstChild("Quest")
    if not quest then return false, "" end
    local container = quest:FindFirstChild("Container")
    local questTitle = container and container:FindFirstChild("QuestTitle")
    local title = questTitle and questTitle:FindFirstChild("Title")
    return quest.Visible == true, title and title.Text or ""
end

local function currentLevel()
    local data = LocalPlayer:FindFirstChild("Data")
    local value = data and data:FindFirstChild("Level")
    return value and tonumber(value.Value) or 1
end

local function teamName()
    local team = LocalPlayer.Team
    return team and team.Name or nil
end

local function levelMetadata()
    local level = currentLevel()
    local team = teamName()
    local fallback
    for _, row in ipairs(LEVEL_DATA[Sea]) do
        if level >= row.Min and level <= row.Max then
            if row.Team == team then return row end
            if row.Team == nil then fallback = row end
        end
    end
    return fallback
end

local Movement = {}

function Movement:FinitePosition(position)
    return typeof(position) == "Vector3"
        and position.X == position.X and position.Y == position.Y and position.Z == position.Z
        and math.abs(position.X) < 1000000 and math.abs(position.Y) < 1000000
        and math.abs(position.Z) < 1000000
end

function Movement:GroundBelowPosition(position)
    if not self:FinitePosition(position) then return nil end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    local excluded = {}
    local model = character()
    if model then excluded[#excluded + 1] = model end
    if EnemyFolder then excluded[#excluded + 1] = EnemyFolder end
    params.FilterDescendantsInstances = excluded
    params.IgnoreWater = false
    return workspace:Raycast(position + Vector3.new(0, 250, 0), Vector3.new(0, -2500, 0), params)
end

function Movement:RejectNavigation(reason, destination)
    Runtime.NavigationRejectCount += 1
    Runtime.LastRejectedNavigation = tostring(reason)
    if typeof(destination) == "CFrame" then
        Runtime.BlockedMovementGoal = destination.Position
        Runtime.BlockedMovementUntil = os.clock() + 8
    end
    return nil
end

function Movement:SafeLandDestination(destination, source)
    if typeof(destination) ~= "CFrame" or not self:FinitePosition(destination.Position) then
        return self:RejectNavigation((source or "destination") .. ": invalid CFrame", destination)
    end
    local ground = self:GroundBelowPosition(destination.Position)
    if ground and ground.Material == Enum.Material.Water then
        return self:RejectNavigation((source or "destination") .. ": water below destination", destination)
    end
    return destination
end

function Movement:SafeLevelSpawn(metadata, destination, source)
    destination = self:SafeLandDestination(destination, source or "spawn")
    if not destination then return nil end
    if metadata and typeof(metadata.QuestCFrame) == "CFrame" then
        local delta = destination.Position - metadata.QuestCFrame.Position
        local horizontal = Vector2.new(delta.X, delta.Z).Magnitude
        -- Every current level quest/spawn pair is below 1,510 studs. A wider
        -- 2,200-stud guard leaves room for roaming while rejecting stale rows
        -- that point to a different island or the open sea.
        if horizontal > 2200 then
            return self:RejectNavigation(string.format("%s rejected: %.0f studs from quest", source or "spawn", horizontal), destination)
        end
    end
    return destination
end

function Movement:MatchingLevelMetadata(enemyName)
    for _, row in ipairs(LEVEL_DATA[Sea] or {}) do
        if row.Enemy == enemyName then return row end
    end
end

local function refreshEnemySpawnCache()
    local worldOrigin = workspace:FindFirstChild("_WorldOrigin")
    local spawnRoot = worldOrigin and worldOrigin:FindFirstChild("EnemySpawns", true)
    if not spawnRoot then return end
    if Runtime.EnemySpawnRoot ~= spawnRoot then
        Runtime.EnemySpawnRoot = spawnRoot
        table.clear(Runtime.EnemySpawnBuckets)
    end
    for _, instance in ipairs(spawnRoot:GetDescendants()) do trackEnemySpawn(instance) end
end

local function enemySpawnCFrame(name, reference)
    refreshEnemySpawnCache()
    local wanted = normalizedEntityName(name)
    local buckets = {}
    local exact = Runtime.EnemySpawnBuckets[wanted]
    if exact then buckets[#buckets + 1] = exact end
    if not exact then
        for key, bucket in pairs(Runtime.EnemySpawnBuckets) do
            if string.find(key, wanted, 1, true) or string.find(wanted, key, 1, true) then
                buckets[#buckets + 1] = bucket
            end
        end
    end
    local referencePosition
    if typeof(reference) == "CFrame" then referencePosition = reference.Position
    elseif typeof(reference) == "Vector3" then referencePosition = reference end
    local best, bestDistance
    for _, bucket in ipairs(buckets) do
        for part in pairs(bucket) do
            if part and part.Parent then
                local distance = referencePosition and (part.Position - referencePosition).Magnitude or 0
                if not bestDistance or distance < bestDistance then
                    best, bestDistance = part, distance
                end
            end
        end
    end
    return best and best.CFrame or nil
end

local function bossMetadata(name)
    local resolved = BOSS_ALIASES[name] or name
    return BOSS_DATA[Sea][resolved], resolved
end

local function findNearestByName(name, playerRoot)
    local bucket = Runtime.EnemyBuckets[name]
    if not bucket then return nil end
    local nearest, nearestDistance
    for model in pairs(bucket) do
        local humanoid, root = aliveModel(model)
        if humanoid and root then
            local distance = (playerRoot.Position - root.Position).Magnitude
            if not nearestDistance or distance < nearestDistance then
                nearest, nearestDistance = model, distance
            end
        end
    end
    return nearest, nearestDistance
end

local function findNearestBoss(playerRoot)
    local nearest, nearestDistance
    for _, name in ipairs(BOSS_LISTS[Sea]) do
        local bucket = Runtime.EnemyBuckets[name]
        if bucket then
            for model in pairs(bucket) do
                local humanoid, root = aliveModel(model)
                if humanoid and root then
                    local distance = (playerRoot.Position - root.Position).Magnitude
                    if not nearestDistance or distance < nearestDistance then
                        nearest, nearestDistance = model, distance
                    end
                end
            end
        end
    end
    return nearest, nearestDistance
end

local function findNearestEnemy(playerRoot)
    local nearest, nearestDistance
    for _, bucket in pairs(Runtime.EnemyBuckets) do
        for model in pairs(bucket) do
            local humanoid, root = aliveModel(model)
            if humanoid and root then
                local ground = Movement:GroundBelowPosition(root.Position)
                -- Auto Farm Nearest is for land/humanoid farming. Ignore sea
                -- event humanoids whose only surface below them is water.
                if not ground or ground.Material ~= Enum.Material.Water then
                    local distance = (playerRoot.Position - root.Position).Magnitude
                    if not nearestDistance or distance < nearestDistance then
                        nearest, nearestDistance = model, distance
                    end
                end
            end
        end
    end
    return nearest, nearestDistance
end

local function findNearestFromNames(names, playerRoot)
    local nearest, nearestDistance
    for _, name in ipairs(names or {}) do
        local model, distance = findNearestByName(name, playerRoot)
        if model and (not nearestDistance or distance < nearestDistance) then
            nearest, nearestDistance = model, distance
        end
    end
    return nearest, nearestDistance
end

function Movement:Cancel(expectedOwner)
    if expectedOwner and Runtime.MovementOwner ~= expectedOwner then return false end
    if Runtime.MovementTween then
        pcall(Runtime.MovementTween.Cancel, Runtime.MovementTween)
    end
    Runtime.MovementTween = nil
    Runtime.MovementGoal = nil
    Runtime.MovementOwner = nil
    Runtime.MovementCharacter = nil
    return true
end

function Movement:Go(destination, owner)
    if typeof(destination) ~= "CFrame" then return false end
    owner = owner or "Automation"
    if Runtime.Respawning then return false end
    if Runtime.ManualTravelHold and owner ~= "ManualTravel" then return false end
    if owner ~= "ManualTravel" and Runtime.BlockedMovementGoal and os.clock() < Runtime.BlockedMovementUntil
        and (Runtime.BlockedMovementGoal - destination.Position).Magnitude <= 12
    then
        return false
    elseif os.clock() >= Runtime.BlockedMovementUntil then
        Runtime.BlockedMovementGoal = nil
    end
    local model, humanoid, root = characterParts()
    if not humanoid or not root or humanoid.Health <= 0 then return false end
    if humanoid.Sit then humanoid.Sit = false end

    local distance = (root.Position - destination.Position).Magnitude
    if distance <= 3 then
        self:Cancel()
        if distance > 0.75 then root.CFrame = destination end
        Runtime.ManualTravelInProgress = false
        return true
    end

    if Runtime.MovementOwner == owner and Runtime.MovementGoal
        and (Runtime.MovementGoal.Position - destination.Position).Magnitude <= 2
    then
        return false
    end

    if not Runtime.MovementRetryGoal
        or (Runtime.MovementRetryGoal - destination.Position).Magnitude > 2
    then
        Runtime.MovementRetryCount = 0
        Runtime.MovementRetryGoal = destination.Position
    end
    self:Cancel()
    Runtime.MovementGoal = destination
    Runtime.MovementOwner = owner
    Runtime.MovementCharacter = model
    Runtime.MovementStarted = os.clock()
    Runtime.MovementLastProgress = os.clock()
    Runtime.MovementLastPosition = root.Position
    local speed = math.clamp(tonumber(Settings.TweenSpeed) or 300, 5, 600)
    local tween = TweenService:Create(root, TweenInfo.new(distance / speed, Enum.EasingStyle.Linear), {
        CFrame = destination,
    })
    Runtime.MovementTween = tween
    local completion
    completion = tween.Completed:Connect(function(playbackState)
        if completion then completion:Disconnect(); completion = nil end
        if Runtime.MovementTween == tween then
            Runtime.MovementTween = nil
            Runtime.MovementGoal = nil
            Runtime.MovementOwner = nil
            Runtime.MovementCharacter = nil
            Runtime.MovementRetryCount = 0
            Runtime.MovementRetryGoal = nil
            if owner == "ManualTravel" then Runtime.ManualTravelInProgress = false end
            if playbackState == Enum.PlaybackState.Completed then Runtime.MovementLastProgress = os.clock() end
        end
    end)
    tween:Play()
    return true
end

local function landBelow(root)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    local model = character()
    params.FilterDescendantsInstances = model and {model} or {}
    local result = workspace:Raycast(root.Position + Vector3.new(0, 3, 0), Vector3.new(0, -140, 0), params)
    return result and result.Material ~= Enum.Material.Water
end

task.spawn(function()
    local strandedSince = nil
    while Runtime.Alive do
        local _, humanoid, root = characterParts()
        if humanoid and root and humanoid.Health > 0 and not Runtime.Respawning then
            if humanoid.FloorMaterial ~= Enum.Material.Air
                and humanoid.FloorMaterial ~= Enum.Material.Water
                and landBelow(root)
            then
                Runtime.LastLandCFrame = root.CFrame
            end

            local goal = Runtime.MovementGoal
            if Runtime.MovementTween and goal and Runtime.MovementCharacter == character() then
                local previous = Runtime.MovementLastPosition
                if not previous or (root.Position - previous).Magnitude >= 2 then
                    Runtime.MovementLastPosition = root.Position
                    Runtime.MovementLastProgress = os.clock()
                elseif os.clock() - Runtime.MovementLastProgress > 2.5
                    and (root.Position - goal.Position).Magnitude > 10
                then
                    local retry, owner = goal, Runtime.MovementOwner
                    Runtime.RecoveryCount += 1
                    Runtime.MovementRetryCount += 1
                    Movement:Cancel()
                    if Runtime.MovementRetryCount >= 2 then
                        Runtime.BlockedMovementGoal = retry.Position
                        Runtime.BlockedMovementUntil = os.clock() + 10
                        Runtime.LastRejectedNavigation = "movement stalled twice; goal blocked for 10s"
                        Runtime.NavigationRejectCount += 1
                        Runtime.CurrentTarget = nil
                        Runtime.FarmAnchor = nil
                        Runtime.FarmAnchorKey = nil
                        Runtime.AnchorReached = false
                    else
                        Movement:Go(retry, owner)
                    end
                end
                strandedSince = nil
            elseif farmEnabled() and not Runtime.ManualTravelHold and not Runtime.PickupBusy and not Runtime.AnchorReached
                and not Runtime.CurrentTarget and not landBelow(root)
            then
                strandedSince = strandedSince or os.clock()
                if os.clock() - strandedSince > 2.5 then
                    local levelRow = levelMetadata()
                    local mode = activeFarmMode()
                    local questFallback = (mode == "Level" or mode == "Mob") and levelRow
                        and Movement:SafeLandDestination(levelRow.QuestCFrame, "stranded quest recovery")
                    local fallback = questFallback or Runtime.LastLandCFrame
                    if fallback then
                    Runtime.RecoveryCount += 1
                    Movement:Go(fallback * CFrame.new(0, 5, 0))
                    end
                    strandedSince = nil
                end
            else
                strandedSince = nil
            end
        end
        task.wait(0.35)
    end
end)

local function ensureBodyVelocity(root, name, force)
    local body = root:FindFirstChild(name)
    if body and body:IsA("BodyVelocity") then
        Runtime.OwnedBodyMovers[body] = true
        pcall(body.SetAttribute, body, "BloxFruitOwned", true)
        return body
    end
    body = Instance.new("BodyVelocity")
    body.Name = name
    body.MaxForce = force
    body.Velocity = Vector3.zero
    body:SetAttribute("BloxFruitOwned", true)
    body.Parent = root
    Runtime.OwnedBodyMovers[body] = true
    return body
end

local function networkOwner(root)
    if type(isnetworkowner) ~= "function" then return true end
    local ok, owned = pcall(isnetworkowner, root)
    return ok and owned == true
end

local function expandSimulationRadius()
    local now = os.clock()
    if now - Runtime.LastSimulationRadius < 1 then return end
    Runtime.LastSimulationRadius = now
    if type(sethiddenproperty) == "function" then
        pcall(sethiddenproperty, LocalPlayer, "SimulationRadius", math.huge)
    elseif type(setsimulationradius) == "function" then
        pcall(setsimulationradius, math.huge, math.huge)
    end
end

local function mutateEnemy(model, humanoid, root, destination)
    local state = Runtime.EnemyMutationState[root]
    if not state then
        state = {
            Size = root.Size,
            Transparency = root.Transparency,
            CanCollide = root.CanCollide,
            WalkSpeed = humanoid.WalkSpeed,
            JumpPower = humanoid.JumpPower,
            AutoRotate = humanoid.AutoRotate,
        }
        Runtime.EnemyMutationState[root] = state
    end

    local size = math.clamp(tonumber(Settings.HitboxSize) or 60, 8, 100)
    root.Size = Vector3.new(size, size, size)
    -- The expanded server hitbox is intentionally never rendered to the user.
    root.Transparency = 1
    root.CanCollide = false
    humanoid.WalkSpeed = 0
    humanoid.JumpPower = 0
    humanoid.AutoRotate = false
    ensureBodyVelocity(root, "BodyVelocity", Vector3.new(1e9, 1e9, 1e9))
    if destination and networkOwner(root) then root.CFrame = destination end
end

local function restoreEnemies()
    for root, state in pairs(Runtime.EnemyMutationState) do
        if root and root.Parent then
            local model = root.Parent
            local humanoid = model and model:FindFirstChildOfClass("Humanoid")
            pcall(function()
                root.Size = state.Size
                root.Transparency = state.Transparency
                root.CanCollide = state.CanCollide
                if humanoid then
                    humanoid.WalkSpeed = state.WalkSpeed
                    humanoid.JumpPower = state.JumpPower
                    humanoid.AutoRotate = state.AutoRotate
                end
            end)
            local velocity = root:FindFirstChild("BodyVelocity")
            if velocity and Runtime.OwnedBodyMovers[velocity] then
                Runtime.OwnedBodyMovers[velocity] = nil
                pcall(velocity.Destroy, velocity)
            end
        end
        Runtime.EnemyMutationState[root] = nil
    end
end

local function clearFarmAnchor(restore)
    Runtime.FarmAnchor = nil
    Runtime.FarmAnchorKey = nil
    Runtime.AnchorReached = false
    if restore then restoreEnemies() end
end

local function ensureFarmAnchor(key, fallback)
    if Runtime.FarmAnchorKey ~= key then
        clearFarmAnchor(true)
        Runtime.FarmAnchorKey = key
    end
    if not Runtime.FarmAnchor and typeof(fallback) == "CFrame" then
        Runtime.FarmAnchor = fallback
    end
    return Runtime.FarmAnchor
end

local function bringEnemy(anchor, destination)
    local anchorHumanoid, anchorRoot = aliveModel(anchor)
    if not anchorHumanoid or not anchorRoot then return end

    destination = destination or anchorRoot.CFrame
    if not Settings.BringMobs then
        mutateEnemy(anchor, anchorHumanoid, anchorRoot, nil)
        return
    end

    expandSimulationRadius()
    local anchorPosition = destination.Position
    local bucket = Runtime.EnemyBuckets[anchor.Name]
    if bucket then
        for candidate in pairs(bucket) do
            local humanoid, root = aliveModel(candidate)
            if humanoid and root and (root.Position - anchorPosition).Magnitude <= 3000 then
                mutateEnemy(candidate, humanoid, root, destination)
            end
        end
    end
    mutateEnemy(anchor, anchorHumanoid, anchorRoot, destination)
end

local function toolCategory(tool)
    local attribute = tool:GetAttribute("WeaponType")
    if type(attribute) == "string" and attribute ~= "" then return attribute end
    return tool.ToolTip
end

local function selectedTool()
    local model = character()
    if not model then return nil end

    if Settings.ExactToolName then
        return model:FindFirstChild(Settings.ExactToolName)
            or LocalPlayer.Backpack:FindFirstChild(Settings.ExactToolName)
    end

    local function scan(container)
        for _, child in ipairs(container:GetChildren()) do
            if child:IsA("Tool") and toolCategory(child) == Settings.WeaponCategory then
                return child
            end
        end
    end
    return scan(model) or scan(LocalPlayer.Backpack)
end

local function equipWeapon()
    local model, humanoid = characterParts()
    if not model or not humanoid then return nil end
    local tool = selectedTool()
    if tool and tool.Parent ~= model then
        pcall(humanoid.EquipTool, humanoid, tool)
    end
    return tool
end

local function appendBaseParts(model, output)
    for _, child in ipairs(model:GetChildren()) do
        if child:IsA("BasePart") then output[#output + 1] = child end
    end
end

local function collectFastTargets()
    table.clear(Runtime.FastTargets)
    table.clear(Runtime.HitParts)
    Runtime.PrimaryTarget = nil

    local model, humanoid, playerRoot = characterParts()
    local tool = model and model:FindFirstChildOfClass("Tool")
    if not tool or not humanoid or not playerRoot or humanoid.Health <= 0 then return end

    local category = toolCategory(tool)
    local radius = 60
    local function accept(candidate, fruitMode)
        local targetHumanoid, root = aliveModel(candidate)
        if not targetHumanoid or not root then return end
        if (root.Position - playerRoot.Position).Magnitude > radius then return end
        Runtime.FastTargets[#Runtime.FastTargets + 1] = candidate
        if not Runtime.PrimaryTarget then Runtime.PrimaryTarget = candidate:FindFirstChild("Head") end
        if fruitMode then
            local part = candidate:FindFirstChild("Head")
                or candidate:FindFirstChild("UpperTorso")
                or candidate:FindFirstChild("HumanoidRootPart", true)
            if part then Runtime.HitParts[#Runtime.HitParts + 1] = part end
        else
            appendBaseParts(candidate, Runtime.HitParts)
        end
    end

    local fruitMode = category == "Blox Fruit"
    for _, bucket in pairs(Runtime.EnemyBuckets) do
        for candidate in pairs(bucket) do accept(candidate, fruitMode) end
    end
    local characters = workspace:FindFirstChild("Characters")
    if characters and not fruitMode then
        for _, candidate in ipairs(characters:GetChildren()) do
            if candidate ~= model then accept(candidate, false) end
        end
    end

    if fruitMode then
        local seaBeasts = workspace:FindFirstChild("SeaBeasts")
        if seaBeasts then
            for _, beast in ipairs(seaBeasts:GetChildren()) do
                local health = beast:FindFirstChild("Health")
                local root = beast:FindFirstChild("HumanoidRootPart", true)
                if health and root and health.Value > 0
                    and (root.Position - playerRoot.Position).Magnitude <= radius
                then
                    Runtime.FastTargets[#Runtime.FastTargets + 1] = beast
                    Runtime.HitParts[#Runtime.HitParts + 1] = root
                    if not Runtime.PrimaryTarget then Runtime.PrimaryTarget = root end
                end
            end
        end
    end
end

local function inputAttack(tool)
    pcall(tool.Activate, tool)
    if type(mouse1click) == "function" then pcall(mouse1click) end
    pcall(function()
        local camera = workspace.CurrentCamera
        local center = camera.ViewportSize / 2
        VirtualInputManager:SendMouseButtonEvent(center.X, center.Y, 0, true, game, 0)
        VirtualInputManager:SendMouseButtonEvent(center.X, center.Y, 0, false, game, 0)
    end)
    pcall(function()
        VirtualUser:CaptureController()
        VirtualUser:Button1Down(Vector2.zero, workspace.CurrentCamera.CFrame)
        VirtualUser:Button1Up(Vector2.zero, workspace.CurrentCamera.CFrame)
    end)
end

local function currentHitModel(targetModels)
    local current = Runtime.CurrentTarget
    if current and aliveModel(current) then return current end
    for _, model in ipairs(targetModels or {}) do
        if model:IsA("Model") and aliveModel(model) then return model end
    end
    return nil
end

local function hitPartFor(model)
    if not model or not model:IsA("Model") then return nil end
    return model:FindFirstChild("LeftHand")
        or model:FindFirstChild("RightHand")
        or model:FindFirstChild("Head")
        or model:FindFirstChild("HumanoidRootPart")
end

local function netTokenAttack(targetModels)
    if not RegisterAttack or not RegisterHit then return false end
    if not Runtime.CombatToken then
        probeCombatToken()
        return false
    end
    local ordered, seen = {}, {}
    local current = currentHitModel(targetModels)
    if current then
        ordered[#ordered + 1] = current
        seen[current] = true
    end
    for _, model in ipairs(targetModels or {}) do
        if model:IsA("Model") and not seen[model] and aliveModel(model) then
            ordered[#ordered + 1] = model
            seen[model] = true
        end
    end
    if #ordered == 0 then return false end
    local attackOk = pcall(RegisterAttack.FireServer, RegisterAttack, 0.5)
    local hitCount = 0
    -- One attack registration, then one deduplicated hit per nearby model. This
    -- preserves the known current packet shape instead of guessing a bulk arg.
    for index, model in ipairs(ordered) do
        if index > 24 then break end
        local part = hitPartFor(model)
        if part then
            local hitOk = pcall(RegisterHit.FireServer, RegisterHit, part, {}, nil, Runtime.CombatToken)
            if hitOk then hitCount += 1 end
        end
    end
    Runtime.LastBatchSize = hitCount
    if attackOk and hitCount > 0 then
        Runtime.CombatTransport = string.format("Net multi-hit (%d)", hitCount)
        return true
    end
    return false
end

local function legacyRigAttack(tool, targetModels)
    if not LegacyRigController then return false end
    local roots, seen = {}, {}
    for _, model in ipairs(targetModels or {}) do
        local root
        if model.Parent == EnemyFolder then
            local _, candidateRoot = aliveModel(model)
            root = candidateRoot
        end
        if root and not seen[model] then
            seen[model] = true
            roots[#roots + 1] = root
        end
    end
    if #roots == 0 then return false end
    local weaponName = tool and tool.Name or ""
    local changed = pcall(LegacyRigController.FireServer, LegacyRigController, "weaponChange", weaponName)
    local hit = pcall(LegacyRigController.FireServer, LegacyRigController, "hit", roots, 1, "")
    if changed and hit then
        Runtime.CombatTransport = "Legacy RigController attack"
        return true
    end
    return false
end

local function defaultAttackTransport(tool, primaryTarget, hitParts, targetModels)
    if not Settings.ActivateTool or not tool or not primaryTarget or #hitParts == 0 then return end
    Runtime.AttackAttempts += 1
    if netTokenAttack(targetModels) then return end
    if legacyRigAttack(tool, targetModels) then return end
    Runtime.CombatTransport = RegisterHit and "Net token pending; input probe" or "Input fallback"
    inputAttack(tool)
end
Runtime.AttackTransport = defaultAttackTransport

local function attackTick()
    if not Settings.FastAttack then return end
    if Runtime.Respawning or Runtime.ManualTravelHold then return end
    if Runtime.PickupBusy then return end
    if activeFarmMode() == "Observation" then return end
    collectFastTargets()
    if not farmEnabled() or not Runtime.PrimaryTarget then return end
    for _, target in ipairs(Runtime.FastTargets) do
        local humanoid = target:FindFirstChildOfClass("Humanoid")
        if humanoid then
            local previous = Runtime.ObservedHealth[target]
            if previous and humanoid.Health < previous then Runtime.DamageRegistrations += 1 end
            Runtime.ObservedHealth[target] = humanoid.Health
        end
    end
    local now = os.clock()
    local delay = ATTACK_DELAYS[Settings.AttackMode] or 0.2
    if now - Runtime.LastAttack < delay then return end
    Runtime.LastAttack = now
    local primaryTarget = Runtime.PrimaryTarget
    local current = Runtime.CurrentTarget
    if current then
        local currentHumanoid, currentRoot = aliveModel(current)
        local _, _, playerRoot = characterParts()
        if currentHumanoid and currentRoot and playerRoot
            and (currentRoot.Position - playerRoot.Position).Magnitude <= 60
        then
            primaryTarget = current:FindFirstChild("Head") or currentRoot
        end
    end
    local model = character()
    local tool = model and model:FindFirstChildOfClass("Tool")
    pcall(Runtime.AttackTransport, tool, primaryTarget, Runtime.HitParts, Runtime.FastTargets)
end

local function questMatches(title, wanted)
    return title ~= "" and string.find(string.lower(title), string.lower(wanted), 1, true) ~= nil
end

local function questRemoteReady(interval)
    local now = os.clock()
    if now - Runtime.LastQuestRemote < interval then return false end
    Runtime.LastQuestRemote = now
    return true
end

local function ensureQuest(metadata, titleMatch)
    if not metadata or not metadata.Quest or not metadata.Slot or not metadata.QuestCFrame then return true end
    local visible, title = getQuestState()
    if visible and not questMatches(title, titleMatch) then
        if questRemoteReady(0.75) then invokeComm("AbandonQuest") end
        return false
    end
    if not visible then
        local questCFrame = Movement:SafeLandDestination(metadata.QuestCFrame, tostring(metadata.Quest) .. " quest giver")
        if not questCFrame then
            Runtime.CurrentTarget = nil
            clearFarmAnchor(true)
            return false
        end
        Movement:Go(questCFrame)
        local _, _, root = characterParts()
        if root and (root.Position - questCFrame.Position).Magnitude <= 5
            and questRemoteReady(0.75)
        then
            invokeComm("StartQuest", metadata.Quest, metadata.Slot)
        end
        return false
    end
    return true
end

local function combatTarget(target, anchorKey)
    local humanoid, root = aliveModel(target)
    if not humanoid or not root then return false end
    local _, _, playerRoot = characterParts()
    if not playerRoot then return false end

    -- A combat anchor is created only from a replicated, living target. Spawn
    -- metadata is navigation guidance, never authority for the root lock.
    local anchor = ensureFarmAnchor(anchorKey, root.CFrame)
    if not anchor then return false end
    Runtime.CurrentTarget = target

    if target:GetAttribute("Locked") == nil then
        target:SetAttribute("Locked", anchor)
    end
    bringEnemy(target, anchor)
    equipWeapon()
    local playerGoal = anchor
        * CFrame.new(0, tonumber(Settings.Height) or 20, 0)
        * CFrame.Angles(0, math.pi, 0)
    local distance = (playerRoot.Position - playerGoal.Position).Magnitude
    if distance <= 6 then
        Movement:Cancel()
        playerRoot.CFrame = playerGoal
        Runtime.AnchorReached = true
    else
        Runtime.AnchorReached = false
        Movement:Go(playerGoal)
    end
    return true
end

function Movement:WaitingSpawn(playerRoot, destination)
    if not playerRoot or typeof(destination) ~= "CFrame" then return false end
    local goal = destination * CFrame.new(0, 5, 0)
    if (playerRoot.Position - goal.Position).Magnitude > 12 then
        return self:Go(goal)
    end
    self:Cancel("Automation")
    return true
end

local function tickLevel(playerRoot)
    local metadata = levelMetadata()
    if not metadata then return end
    if Settings.AcceptLevelQuests and not ensureQuest(metadata, metadata.Title) then
        Runtime.CurrentTarget = nil
        clearFarmAnchor(true)
        return
    end
    local target = Runtime.CurrentTarget
    local targetHumanoid = target and aliveModel(target)
    if not targetHumanoid or target.Name ~= metadata.Enemy then
        target = findNearestByName(metadata.Enemy, playerRoot)
        Runtime.CurrentTarget = nil
    end
    local liveSpawn = enemySpawnCFrame(metadata.Enemy, metadata.QuestCFrame)
    local spawnCFrame = liveSpawn and Movement:SafeLevelSpawn(metadata, liveSpawn, "live " .. metadata.Enemy .. " spawn")
        or Movement:SafeLevelSpawn(metadata, metadata.EnemyCFrame, "static " .. metadata.Enemy .. " spawn")
    if target then
        combatTarget(target, "Level:" .. metadata.Enemy)
    elseif spawnCFrame then
        if Runtime.FarmAnchor then clearFarmAnchor(true) end
        Runtime.AnchorReached = false
        Movement:WaitingSpawn(playerRoot, spawnCFrame)
    end
end

local function tickMob(playerRoot)
    local target = Runtime.CurrentTarget
    local targetHumanoid = target and aliveModel(target)
    if not targetHumanoid or target.Name ~= Settings.SelectedMob then
        target = findNearestByName(Settings.SelectedMob, playerRoot)
        Runtime.CurrentTarget = nil
    end
    local metadata = Movement:MatchingLevelMetadata(Settings.SelectedMob)
    local reference = metadata and metadata.QuestCFrame or playerRoot.Position
    local liveSpawn = enemySpawnCFrame(Settings.SelectedMob, reference)
    local spawnCFrame = liveSpawn and Movement:SafeLevelSpawn(metadata, liveSpawn, "live " .. Settings.SelectedMob .. " spawn")
        or (metadata and Movement:SafeLevelSpawn(metadata, metadata.EnemyCFrame, "static " .. Settings.SelectedMob .. " spawn"))
    if target then
        combatTarget(target, "Mob:" .. Settings.SelectedMob)
    elseif spawnCFrame then
        if Runtime.FarmAnchor then clearFarmAnchor(true) end
        Runtime.AnchorReached = false
        Movement:WaitingSpawn(playerRoot, spawnCFrame)
    end
end

local function tickNearest(playerRoot)
    local target = Runtime.CurrentTarget
    local targetHumanoid = target and aliveModel(target)
    if not targetHumanoid then
        target = findNearestEnemy(playerRoot)
        Runtime.CurrentTarget = nil
    end
    if target then combatTarget(target, "Nearest:" .. target.Name) end
end

local function tickEvent(playerRoot)
    local name = Settings.SelectedEventEnemy
    local target = Runtime.CurrentTarget
    local targetHumanoid = target and aliveModel(target)
    if not targetHumanoid or target.Name ~= name then
        target = findNearestByName(name, playerRoot)
        Runtime.CurrentTarget = nil
    end
    if target then combatTarget(target, "Event:" .. name) end
end

local function tickBoss(playerRoot)
    local metadata = bossMetadata(Settings.SelectedBoss)
    if not metadata then return end
    if Settings.AcceptBossQuests and metadata.Quest
        and not ensureQuest(metadata, metadata.Model)
    then
        Runtime.CurrentTarget = nil
        clearFarmAnchor(true)
        return
    end

    local target = findNearestByName(metadata.Model, playerRoot)
    local rawSpawn = enemySpawnCFrame(metadata.Model, metadata.QuestCFrame or metadata.BossCFrame)
        or metadata.BossCFrame
    local spawnCFrame = rawSpawn and Movement:SafeLandDestination(rawSpawn, metadata.Model .. " boss spawn")
    if target then
        combatTarget(target, "Boss:" .. metadata.Model)
        return
    end

    Runtime.CurrentTarget = nil
    if spawnCFrame then Movement:WaitingSpawn(playerRoot, spawnCFrame) end
end

local function tickAllBoss(playerRoot)
    local target = Runtime.CurrentTarget
    local targetHumanoid = target and aliveModel(target)
    if not targetHumanoid or not table.find(BOSS_LISTS[Sea], target.Name) then
        target = findNearestBoss(playerRoot)
        Runtime.CurrentTarget = nil
    end
    if target then
        Runtime.AllBossArrivedAt = nil
        combatTarget(target, "AllBoss:" .. target.Name)
        return
    end

    -- No boss is currently streamed. Cycle the known current-sea spawns so a
    -- distant live boss can stream in, instead of leaving All Boss idle.
    local names = BOSS_LISTS[Sea] or {}
    if #names == 0 then return end
    Runtime.AllBossIndex = math.clamp(Runtime.AllBossIndex or 1, 1, #names)
    local publicName = names[Runtime.AllBossIndex]
    local metadata = bossMetadata(publicName)
    local destination = metadata and (
        enemySpawnCFrame(metadata.Model, metadata.QuestCFrame or metadata.BossCFrame)
        or metadata.BossCFrame
    )
    if destination then destination = Movement:SafeLandDestination(destination, metadata.Model .. " all-boss spawn") end
    if not destination then
        Runtime.AllBossIndex = Runtime.AllBossIndex % #names + 1
        return
    end
    local goal = destination * CFrame.new(0, 5, 0)
    if (playerRoot.Position - goal.Position).Magnitude > 12 then
        Runtime.AllBossArrivedAt = nil
        Movement:Go(goal)
        return
    end
    Movement:Cancel()
    Runtime.AllBossArrivedAt = Runtime.AllBossArrivedAt or os.clock()
    if os.clock() - Runtime.AllBossArrivedAt >= 2 then
        Runtime.AllBossIndex = Runtime.AllBossIndex % #names + 1
        Runtime.AllBossArrivedAt = nil
    end
end

local function tickMaterial(playerRoot)
    local metadata = MATERIAL_DATA[Sea][Settings.SelectedMaterial]
    if not metadata then return end
    local target = Runtime.CurrentTarget
    local targetHumanoid = target and aliveModel(target)
    if not targetHumanoid or not table.find(metadata.Enemies, target.Name) then
        target = findNearestFromNames(metadata.Enemies, playerRoot)
        Runtime.CurrentTarget = nil
    end
    if target then
        combatTarget(target, "Material:" .. Settings.SelectedMaterial)
    elseif metadata.CFrame then
        local destination = Movement:SafeLandDestination(metadata.CFrame, Settings.SelectedMaterial .. " material spawn")
        if not destination then return end
        if Runtime.FarmAnchor then clearFarmAnchor(true) end
        Runtime.AnchorReached = false
        Movement:WaitingSpawn(playerRoot, destination)
    end
end

local ELITE_NAMES = {"Diablo", "Deandre", "Urban"}
local function tickElite(playerRoot)
    local visible, title = getQuestState()
    local hasEliteQuest = visible and (
        questMatches(title, "Diablo")
        or questMatches(title, "Deandre")
        or questMatches(title, "Urban")
    )
    if not hasEliteQuest and questRemoteReady(2) then invokeComm("EliteHunter") end

    local target = findNearestFromNames(ELITE_NAMES, playerRoot)
    if target then
        combatTarget(target, "Elite:" .. target.Name)
        return
    end
    Runtime.CurrentTarget = nil
    for _, name in ipairs(ELITE_NAMES) do
        local template = ReplicatedStorage:FindFirstChild(name)
        local root = template and template:FindFirstChild("HumanoidRootPart")
        if root then Movement:WaitingSpawn(playerRoot, root.CFrame); return end
    end
end

local function objectPart(instance)
    if not instance or not instance.Parent then return nil end
    if instance:IsA("BasePart") then return instance end
    if instance:IsA("Model") then
        return instance.PrimaryPart or instance:FindFirstChildWhichIsA("BasePart", true)
    end
    return instance:FindFirstChildWhichIsA("BasePart", true)
end

local function findNearestCached(playerRoot, cache, cooldowns, predicate)
    local nearest, nearestPart, nearestDistance
    local now = os.clock()
    for object in pairs(cache) do
        local part = objectPart(object)
        if part and part.Parent then
            local retryAt = cooldowns[object] or 0
            if retryAt <= now and (not predicate or predicate(object)) then
                local distance = (part.Position - playerRoot.Position).Magnitude
                if not nearestDistance or distance < nearestDistance then
                    nearest, nearestPart, nearestDistance = object, part, distance
                end
            end
        else
            cache[object] = nil
            cooldowns[object] = nil
        end
    end
    return nearest, nearestPart, nearestDistance
end

local function chestAvailable(chest)
    if not chest or not chest.Parent then return false end
    if chest:GetAttribute("IsDisabled") == true then return false end
    local disabled = chest:FindFirstChild("IsDisabled")
    if disabled and disabled:IsA("BoolValue") and disabled.Value then return false end
    return true
end

local function interactPickup(playerRoot, object, primaryPart)
    local touched, prompted = 0, 0
    local function touch(part)
        if touched >= 64 or not part:IsA("BasePart") or type(firetouchinterest) ~= "function" then return end
        local began = pcall(firetouchinterest, playerRoot, part, 0)
        local ended = pcall(firetouchinterest, playerRoot, part, 1)
        if began or ended then touched += 1 end
    end
    touch(primaryPart)
    for _, descendant in ipairs(object:GetDescendants()) do
        if descendant:IsA("BasePart") then
            touch(descendant)
        elseif descendant:IsA("ProximityPrompt") and type(fireproximityprompt) == "function" then
            prompted += 1
            pcall(fireproximityprompt, descendant)
        elseif descendant:IsA("ClickDetector") and type(fireclickdetector) == "function" then
            prompted += 1
            pcall(fireclickdetector, descendant)
        end
    end
    if touched == 0 and prompted == 0 then
        -- Low-capability executors may not expose any interaction primitive.
        -- Physical overlap remains the game's native chest/fruit pickup path.
        pcall(function() playerRoot.CFrame = primaryPart.CFrame * CFrame.new(0, 2, 0) end)
    end
end

local function finishPickupOverlay()
    if not Runtime.PickupBusy then return end
    Runtime.PickupBusy = false
    Runtime.PickupKind = nil
    Runtime.PickupTarget = nil
    Movement:Cancel()
    clearFarmAnchor(true)
end

local function beginPickupOverlay(kind, object)
    if not Runtime.PickupBusy then
        Runtime.PickupBusy = true
        Runtime.CurrentTarget = nil
        Movement:Cancel()
        clearFarmAnchor(true)
    end
    Runtime.PickupKind = kind
    Runtime.PickupTarget = object
end

local function buildChestSweepQueue(playerRoot)
    local queue, seen = {}, {}
    local function addWaypoint(destination, object, name)
        if typeof(destination) ~= "CFrame" then return end
        local position = destination.Position
        -- One stop per broad map cell is enough to request streaming without
        -- repeatedly visiting every quest pad on the same island.
        local key = string.format("%d:%d", math.floor(position.X / 1200), math.floor(position.Z / 1200))
        if seen[key] then return end
        seen[key] = true
        queue[#queue + 1] = {
            Object = object,
            CFrame = destination,
            Name = name or (object and object.Name) or "map sector",
        }
    end
    for island in pairs(Runtime.Islands) do
        local part = objectPart(island)
        local lower = string.lower(island and island.Name or "")
        local raidMarker = string.match(lower, "^island%s*%d+$") or string.find(lower, "raid", 1, true)
        if part and part.Parent and not raidMarker then
            local destination = island:IsA("BasePart") and island.CFrame or island:GetPivot()
            addWaypoint(destination, island, island.Name)
        end
    end

    for _, island in ipairs(ISLAND_DATA[Sea] or {}) do
        addWaypoint(island.CFrame, nil, island.Name)
    end

    -- Streaming can hide both distant chests and distant location markers.
    -- Current quest/boss metadata therefore supplies a complete sea-wide
    -- fallback route instead of silently degrading to nearby-only collection.
    for _, row in ipairs(LEVEL_DATA[Sea] or {}) do
        addWaypoint(row.QuestCFrame, nil, row.Enemy .. " quest")
        addWaypoint(row.EnemyCFrame, nil, row.Enemy .. " spawn")
    end
    for name, row in pairs(BOSS_DATA[Sea] or {}) do
        addWaypoint(row.QuestCFrame, nil, name .. " quest")
        addWaypoint(row.BossCFrame, nil, name .. " spawn")
    end
    table.sort(queue, function(a, b)
        return (a.CFrame.Position - playerRoot.Position).Magnitude < (b.CFrame.Position - playerRoot.Position).Magnitude
    end)
    Runtime.ChestSweepQueue = queue
    Runtime.ChestSweepIndex = 1
    Runtime.ChestSweepArrivedAt = nil
    return queue
end

local function tickChestSweep(playerRoot)
    if not Settings.AutoCollectChest or not Settings.WholeSeaChestSweep then return false end
    local now = os.clock()
    if Runtime.ChestStreamRequestBusy then return false end
    if now < Runtime.ChestSweepNextAt then return false end
    local queue = Runtime.ChestSweepQueue
    if not queue then queue = buildChestSweepQueue(playerRoot) end
    local entry = queue[Runtime.ChestSweepIndex]
    while entry and typeof(entry.CFrame) ~= "CFrame" do
        Runtime.ChestSweepIndex += 1
        entry = queue[Runtime.ChestSweepIndex]
    end
    if not entry then
        Runtime.ChestSweepQueue = nil
        Runtime.ChestSweepIndex = 1
        Runtime.ChestSweepArrivedAt = nil
        Runtime.ChestSweepNextAt = now + 20
        finishPickupOverlay()
        return false
    end


    -- Ask Roblox streaming for the distant sector without moving the player.
    -- Autofarm continues during the request; any replicated _ChestTagged
    -- instances are picked up immediately by the normal nearest-chest loop.
    if Runtime.ChestStreamRequestSupported then
        local requestedIndex = Runtime.ChestSweepIndex
        Runtime.ChestStreamRequestBusy = true
        task.spawn(function()
            local ok = pcall(function()
                LocalPlayer:RequestStreamAroundAsync(entry.CFrame.Position, 2)
            end)
            Runtime.ChestStreamRequestBusy = false
            if not Runtime.Alive or not Settings.AutoCollectChest then return end
            if ok then
                if Runtime.ChestSweepIndex == requestedIndex then Runtime.ChestSweepIndex += 1 end
                Runtime.ChestSweepNextAt = os.clock() + 0.35
            else
                Runtime.ChestStreamRequestSupported = false
                Runtime.ChestSweepNextAt = 0
            end
        end)
        return false
    end

    beginPickupOverlay("Chest sweep", entry.Object)
    local destination = entry.CFrame * CFrame.new(0, 35, 0)
    local distance = (playerRoot.Position - destination.Position).Magnitude
    if distance > 18 then
        Runtime.ChestSweepArrivedAt = nil
        Movement:Go(destination)
        return true
    end
    Movement:Cancel()
    Runtime.ChestSweepArrivedAt = Runtime.ChestSweepArrivedAt or now
    if now - Runtime.ChestSweepArrivedAt >= 1.25 then
        Runtime.ChestSweepIndex += 1
        Runtime.ChestSweepArrivedAt = nil
        -- Release movement back to the selected farm between map sectors.
        -- This keeps chest collection an overlay instead of turning farming off
        -- or monopolising movement for a full-sea pass.
        Runtime.ChestSweepNextAt = now + 2
        finishPickupOverlay()
        return false
    end
    return true
end

local function choosePickup(playerRoot)
    if Settings.AutoCollectFruit then
        local fruit, part, distance = findNearestCached(playerRoot, WorldFruits, Runtime.FruitCooldown)
        if fruit then return "Fruit", fruit, part, distance end
    end
    if Settings.AutoCollectChest then
        local chest, part, distance = findNearestCached(playerRoot, Runtime.Chests, Runtime.ChestCooldown, chestAvailable)
        if chest then return "Chest", chest, part, distance end
    end
    if Settings.AutoCollectBerries then
        local berry, part, distance = findNearestCached(playerRoot, Runtime.Berries, Runtime.BerryCooldown)
        if berry then return "Berry", berry, part, distance end
    end
    return nil
end

local function tickPickupOverlay(playerRoot)
    if Runtime.Respawning or Runtime.ManualTravelHold or os.clock() < Runtime.ForceReleaseUntil then
        finishPickupOverlay()
        return
    end
    if not Settings.AutoCollectFruit and not Settings.AutoCollectChest and not Settings.AutoCollectBerries then
        finishPickupOverlay()
        return
    end

    local kind, object, part, distance = choosePickup(playerRoot)
    if not object or not part then
        if tickChestSweep(playerRoot) then return end
        if Runtime.PickupBusy and os.clock() - Runtime.PickupLastFound >= 0.3 then
            finishPickupOverlay()
        end
        return
    end

    Runtime.PickupLastFound = os.clock()
    beginPickupOverlay(kind, object)
    if distance > 7 then
        Movement:Go(part.CFrame * CFrame.new(0, 3, 0))
        return
    end
    Movement:Cancel()
    interactPickup(playerRoot, object, part)
    if kind == "Fruit" then
        Runtime.FruitCooldown[object] = os.clock() + 12
    elseif kind == "Chest" then
        Runtime.ChestCooldown[object] = os.clock() + 8
    else
        Runtime.BerryCooldown[object] = os.clock() + 20
    end
    Runtime.PickupTarget = nil
end

local function raidIslandCFrame()
    local origin = workspace:FindFirstChild("_WorldOrigin")
    local locations = origin and origin:FindFirstChild("Locations")
    local bestIndex, bestCFrame
    if not locations then return nil end
    for _, location in ipairs(locations:GetChildren()) do
        local index = tonumber(string.match(location.Name, "Island%s*(%d+)"))
        local destination = location:IsA("BasePart") and location.CFrame
            or (location:IsA("Model") and location:GetPivot())
        if index and destination and (not bestIndex or index > bestIndex) then
            bestIndex, bestCFrame = index, destination
        end
    end
    return bestCFrame
end

local function tryStartRaid()
    if os.clock() - Runtime.RaidSummonAttempt < 5 then return end
    Runtime.RaidSummonAttempt = os.clock()
    invokeComm("RaidsNpc", "Select", Settings.SelectedRaidChip)
    if type(fireclickdetector) ~= "function" then return end
    for _, instance in ipairs(workspace:GetDescendants()) do
        if instance:IsA("ClickDetector") then
            local ancestor = instance:FindFirstAncestor("RaidSummon")
                or instance:FindFirstAncestor("RaidSummon2")
            local fullName = string.lower(instance:GetFullName())
            if ancestor or string.find(fullName, "raidsummon", 1, true) then
                pcall(fireclickdetector, instance)
                return
            end
        end
    end
end

local function tickRaid(playerRoot)
    local island = raidIslandCFrame()
    if not island then
        Runtime.CurrentTarget = nil
        tryStartRaid()
        return
    end
    local target = findNearestEnemy(playerRoot)
    if target then
        combatTarget(target, "Raid:" .. target.Name)
        return
    end
    Runtime.CurrentTarget = nil
    Movement:Go(island * CFrame.new(0, 25, 0))
end

local function findSeaBeast(playerRoot)
    local folder = workspace:FindFirstChild("SeaBeasts")
    local nearest, nearestRoot, nearestDistance
    if not folder then return nil end
    for _, beast in ipairs(folder:GetChildren()) do
        local health = beast:FindFirstChild("Health")
        local root = beast:FindFirstChild("HumanoidRootPart", true)
        if health and root and tonumber(health.Value) and health.Value > 0 then
            local distance = (root.Position - playerRoot.Position).Magnitude
            if not nearestDistance or distance < nearestDistance then
                nearest, nearestRoot, nearestDistance = beast, root, distance
            end
        end
    end
    return nearest, nearestRoot, nearestDistance
end

local function tickSeaBeast(playerRoot)
    Runtime.CurrentTarget = nil
    local beast, root = findSeaBeast(playerRoot)
    Runtime.SeaTarget = beast
    if not beast or not root then return end
    equipWeapon()
    Movement:Go(root.CFrame * CFrame.new(0, math.max(30, tonumber(Settings.Height) or 20), 20))
end

local function enableObservation()
    fireComm("Ken", true)
    pcall(function()
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
        task.wait(0.04)
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
    end)
end

local function tickObservation(playerRoot)
    if os.clock() - (Runtime.FeatureLastRun.ObservationPulse or 0) >= 1.5 then
        Runtime.FeatureLastRun.ObservationPulse = os.clock()
        enableObservation()
    end
    local target = findNearestEnemy(playerRoot)
    Runtime.CurrentTarget = nil
    clearFarmAnchor(true)
    if not target then return end
    local humanoid, root = aliveModel(target)
    if humanoid and root then
        Movement:Go(root.CFrame * CFrame.new(0, 0, 4))
    end
end

local function tickMastery(playerRoot)
    Settings.WeaponCategory = Settings.MasteryType
    local target = findNearestEnemy(playerRoot)
    if target then combatTarget(target, "Mastery:" .. target.Name) end
end

local MODE_INTERVALS = { Level = 0.2, Mob = 0.03, Nearest = 0.05, Boss = 0.2, AllBoss = 0.1, Material = 0.06, Elite = 0.12, Raid = 0.08, SeaBeast = 0.12, Event = 0.06, Observation = 0.12, Mastery = 0.06 }

task.spawn(function()
    local lastMode, lastRun = nil, 0
    while Runtime.Alive do
        local mode = activeFarmMode()
        if mode ~= lastMode then
            Runtime.CurrentTarget = nil
            clearFarmAnchor(true)
            Runtime.CurrentMode = mode or "Idle"
            lastMode = mode
        end

        if mode and not Runtime.Respawning and not Runtime.ManualTravelHold
            and not Runtime.PickupBusy and os.clock() - lastRun >= MODE_INTERVALS[mode]
        then
            lastRun = os.clock()
            local _, humanoid, playerRoot = characterParts()
            if humanoid and playerRoot and humanoid.Health > 0 then
                humanoid.Sit = false
                local ok, err = pcall(function()
                    if mode == "Level" then tickLevel(playerRoot)
                    elseif mode == "Mob" then tickMob(playerRoot)
                    elseif mode == "Nearest" then tickNearest(playerRoot)
                    elseif mode == "Boss" then tickBoss(playerRoot)
                    elseif mode == "AllBoss" then tickAllBoss(playerRoot)
                    elseif mode == "Material" then tickMaterial(playerRoot)
                    elseif mode == "Elite" then tickElite(playerRoot)
                    elseif mode == "Raid" then tickRaid(playerRoot)
                    elseif mode == "SeaBeast" then tickSeaBeast(playerRoot)
                    elseif mode == "Observation" then tickObservation(playerRoot)
                    elseif mode == "Mastery" then tickMastery(playerRoot)
                    elseif mode == "Event" then tickEvent(playerRoot) end
                end)
                if not ok then warn("BloxFruitScript farm tick:", err) end
            end
        elseif not mode and not Runtime.PickupBusy and Runtime.MovementTween
            and Runtime.MovementOwner ~= "ManualTravel"
        then
            Movement:Cancel()
        end
        task.wait(0.03)
    end
end)

-- Fruit, chest, and berry collection are overlays, not farm modes. They temporarily
-- borrow movement, drain every cached pickup, then release control without
-- changing whichever farming toggle the user enabled.
task.spawn(function()
    while Runtime.Alive do
        local _, humanoid, playerRoot = characterParts()
        if humanoid and playerRoot and humanoid.Health > 0
            and not Runtime.Respawning and not Runtime.ManualTravelHold
        then
            local ok, err = pcall(tickPickupOverlay, playerRoot)
            if not ok then warn("BloxFruitScript pickup tick:", err) end
        end
        task.wait(0.08)
    end
end)

local function featureReady(key, interval)
    local now = os.clock()
    local previous = Runtime.FeatureLastRun[key]
    if previous ~= nil and now - previous < interval then return false end
    Runtime.FeatureLastRun[key] = now
    return true
end

local function addStats()
    local amount = math.clamp(math.floor(tonumber(Settings.StatsValue) or 10), 1, 1000)
    if Settings.AutoMelee then invokeComm("AddPoint", "Melee", amount) end
    if Settings.AutoDefense then invokeComm("AddPoint", "Defense", amount) end
    if Settings.AutoSword then invokeComm("AddPoint", "Sword", amount) end
    if Settings.AutoGun then invokeComm("AddPoint", "Gun", amount) end
    if Settings.AutoFruitStats then invokeComm("AddPoint", "Demon Fruit", amount) end
end

local function remoteResultText(ok, result)
    if not ok then return "transport failed: " .. tostring(result or "unknown error") end
    if result == nil then return "request accepted" end
    if type(result) == "table" then
        local okEncode, encoded = pcall(HttpService.JSONEncode, HttpService, result)
        return okEncode and encoded or "server returned a table"
    end
    return tostring(result)
end

local function heldFruitEntries()
    local entries, seen = {}, {}
    local function scan(container)
        if not container then return end
        for _, tool in ipairs(container:GetChildren()) do
            if tool:IsA("Tool") and not seen[tool] then
                local canonical = fruitIdentity(tool)
                if canonical then
                    seen[tool] = true
                    entries[#entries + 1] = {Tool = tool, Name = canonical}
                end
            end
        end
    end
    -- StoreFruit is most reliable with the actual Backpack tool instance.
    scan(LocalPlayer:FindFirstChildOfClass("Backpack"))
    scan(character())
    return entries
end

local function storeHeldFruits()
    local selected = Settings.SelectedStoreFruit
    local entries = heldFruitEntries()
    local hasEquippedMatch = false
    local model, humanoid = characterParts()
    for _, entry in ipairs(entries) do
        if (selected == "All Fruits" or entry.Name == selected) and entry.Tool.Parent == model then
            hasEquippedMatch = true
            break
        end
    end
    if hasEquippedMatch and humanoid then
        pcall(humanoid.UnequipTools, humanoid)
        task.wait(0.08)
        entries = heldFruitEntries()
    end

    local matched, requested = 0, 0
    local lastResult = nil
    for _, entry in ipairs(entries) do
        if selected == "All Fruits" or entry.Name == selected then
            matched += 1
            local ok, result = invokeComm("StoreFruit", entry.Name, entry.Tool)
            lastResult = remoteResultText(ok, result)
            if ok then requested += 1 end
            task.wait(0.05)
        end
    end
    if matched == 0 then
        Runtime.LastFruitStoreResult = selected == "All Fruits"
            and "No held fruit tool was found"
            or ("Selected fruit is not held: " .. tostring(selected))
    else
        Runtime.LastFruitStoreResult = string.format("%d/%d store request(s) sent • %s",
            requested, matched, lastResult or "no response")
    end
    return requested > 0, Runtime.LastFruitStoreResult
end

local function spinRandomFruit()
    local ok, result = invokeComm("Cousin", "Buy")
    Runtime.LastFruitSpinResult = remoteResultText(ok, result)
    return ok, result
end

local function buySelectedStockFruit()
    -- The current transport keeps the third boolean argument used by the game
    -- dealer path; omitting it makes some server revisions reject silently.
    local ok, result = invokeComm("PurchaseRawFruit", Settings.SelectedStockFruit, false)
    Runtime.LastFruitStockResult = remoteResultText(ok, result)
    return ok, result
end

local function findOwnedTool(name)
    local model = character()
    local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
    return (model and model:FindFirstChild(name)) or (backpack and backpack:FindFirstChild(name))
end

local function fishingTick()
    local model, humanoid = characterParts()
    if not model or not humanoid then return end
    local rod = findOwnedTool(Settings.SelectedFishingRod)
    if not rod then
        for _, container in ipairs({model, LocalPlayer:FindFirstChildOfClass("Backpack")}) do
            if container then
                for _, tool in ipairs(container:GetChildren()) do
                    if tool:IsA("Tool") and string.find(string.lower(tool.Name), "rod", 1, true) then rod = tool; break end
                end
            end
            if rod then break end
        end
    end
    if not rod then return end
    if rod.Parent ~= model then pcall(humanoid.EquipTool, humanoid, rod) end
    pcall(rod.Activate, rod)
    if FishingRequest then
        if FishingRequest:IsA("RemoteFunction") then pcall(FishingRequest.InvokeServer, FishingRequest, "Catch")
        elseif FishingRequest:IsA("RemoteEvent") then pcall(FishingRequest.FireServer, FishingRequest, "Catch") end
    end
end

local function interactFishingNPC()
    for _, descendant in ipairs(workspace:GetDescendants()) do
        if descendant:IsA("ProximityPrompt") then
            local fullName = string.lower(descendant:GetFullName())
            if string.find(fullName, "fishing", 1, true) or string.find(fullName, "fisher", 1, true) then
                if type(fireproximityprompt) == "function" then pcall(fireproximityprompt, descendant) end
                return true
            end
        end
    end
    return false
end

local function invokeDojoRemote(remote)
    if not remote then return false end
    if remote:IsA("RemoteFunction") then return pcall(remote.InvokeServer, remote) end
    if remote:IsA("RemoteEvent") then return pcall(remote.FireServer, remote) end
    return false
end

local function currentBossNames()
    local values, seen = {}, {}
    for _, name in ipairs(BOSS_LISTS[Sea] or {}) do
        local repaired = BOSS_ALIASES[name] or name
        if not seen[repaired] then seen[repaired] = true; values[#values + 1] = repaired end
    end
    for _, model in ipairs(EnemyFolder:GetChildren()) do
        local humanoid = model:FindFirstChildOfClass("Humanoid")
        local lower = string.lower(model.Name)
        if humanoid and (string.find(lower, "boss", 1, true) or BOSS_DATA[model.Name]) and not seen[model.Name] then
            seen[model.Name] = true
            values[#values + 1] = model.Name
        end
    end
    table.sort(values)
    return values
end

local function currentIslandNames()
    local values, seen = {}, {}
    for _, island in ipairs(ISLAND_DATA[Sea] or {}) do
        seen[island.Name] = true
        values[#values + 1] = island.Name
    end
    for island in pairs(Runtime.Islands) do
        if island and island.Parent and not seen[island.Name] then
            seen[island.Name] = true
            values[#values + 1] = island.Name
        end
    end
    table.sort(values)
    return values
end

local function selectedIslandDestination()
    local static = ISLAND_LOOKUP[Settings.SelectedIsland]
    if static then return static.CFrame end
    for island in pairs(Runtime.Islands) do
        if island and island.Parent and island.Name == Settings.SelectedIsland then
            return island:IsA("BasePart") and island.CFrame or island:GetPivot()
        end
    end
end

local function travelToSelectedIsland(instant)
    local destination = selectedIslandDestination()
    if not destination then return false end
    destination = destination * CFrame.new(0, 8, 0)
    Runtime.ManualTravelHold = true
    Runtime.ManualTravelInProgress = not instant
    Runtime.CurrentTarget = nil
    finishPickupOverlay()
    Movement:Cancel()
    clearFarmAnchor(true)
    if instant then
        local _, _, root = characterParts()
        if root then
            root.Anchored = false
            root.CFrame = destination
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
            return true
        end
        Runtime.ManualTravelHold = false
        return false
    end
    local started = Movement:Go(destination, "ManualTravel")
    if not started and not Runtime.MovementTween then Runtime.ManualTravelInProgress = false end
    return started or Runtime.ManualTravelHold
end

local function resumeAutomationMovement()
    Movement:Cancel("ManualTravel")
    Runtime.ManualTravelHold = false
    Runtime.ManualTravelInProgress = false
    Runtime.CurrentTarget = nil
    clearFarmAnchor(true)
    return true
end

local function joinServerJobId(jobId)
    jobId = string.match(tostring(jobId or ""), "^%s*(.-)%s*$")
    if jobId == "" then return false, "Enter a server Job ID first" end
    local ok, err = pcall(TeleportService.TeleportToPlaceInstance,
        TeleportService, game.PlaceId, jobId, LocalPlayer)
    return ok, err
end

local function hopServer(preferLowestPing)
    local ok, response = pcall(function()
        return game:HttpGet(string.format("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100", game.PlaceId))
    end)
    if not ok then return false, response end
    local decodedOk, data = pcall(HttpService.JSONDecode, HttpService, response)
    if not decodedOk or type(data) ~= "table" then return false, "Invalid server response" end
    local servers = {}
    for _, server in ipairs(data.data or {}) do
        if server.id ~= game.JobId and tonumber(server.playing) and tonumber(server.maxPlayers)
            and server.playing < server.maxPlayers
        then
            servers[#servers + 1] = server
        end
    end
    table.sort(servers, function(a, b)
        if preferLowestPing then return (a.ping or math.huge) < (b.ping or math.huge) end
        return a.playing < b.playing
    end)
    if not servers[1] then return false, "No open server found" end
    TeleportService:TeleportToPlaceInstance(game.PlaceId, servers[1].id, LocalPlayer)
    return true
end

local function sendCombatKey(keyName)
    local keyCode = Enum.KeyCode[keyName]
    if not keyCode then return end
    pcall(function()
        VirtualInputManager:SendKeyEvent(true, keyCode, false, game)
        task.wait(0.045)
        VirtualInputManager:SendKeyEvent(false, keyCode, false, game)
    end)
end

local function castEnabledSkills()
    if not Settings.AutoCombatSkills or not farmEnabled() then return end
    local targetReady = Runtime.PrimaryTarget ~= nil
        or (Settings.AutoSeaBeast and Runtime.SeaTarget ~= nil)
    if not targetReady then return end
    for _, keyName in ipairs({"Z", "X", "C", "V", "F"}) do
        if Settings["AutoSkill" .. keyName] then sendCombatKey(keyName) end
    end
end

local function espAdornee(instance)
    if not instance or not instance.Parent then return nil end
    if instance:IsA("Tool") then
        return instance:FindFirstChild("Handle") or instance:FindFirstChildWhichIsA("BasePart")
    end
    if instance:IsA("Model") or instance:IsA("BasePart") then return instance end
    return instance:FindFirstChildWhichIsA("BasePart", true)
end

local function espPart(instance)
    local adornee = espAdornee(instance)
    if not adornee then return nil end
    if adornee:IsA("BasePart") then return adornee end
    if adornee:IsA("Model") then
        return adornee.PrimaryPart or adornee:FindFirstChildWhichIsA("BasePart", true)
    end
    return nil
end

local function setESP(instance, enabled, color, displayName, useHighlight)
    local existing = Runtime.ESPObjects[instance]
    if not enabled then
        destroyESPEntry(instance)
        return
    end
    local adornee = espAdornee(instance)
    local part = espPart(instance)
    if not adornee or not part then return nil end
    if type(existing) ~= "table" then
        destroyESPEntry(instance)
        existing = {}
        Runtime.ESPObjects[instance] = existing
    end

    if useHighlight ~= false then
        local highlight = existing.Highlight
        if not highlight or not highlight.Parent then
            highlight = Instance.new("Highlight")
            highlight.Name = "BloxFruitESP"
            highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            highlight.FillTransparency = 0.88
            highlight.OutlineTransparency = 0.22
            highlight.Parent = adornee
            existing.Highlight = highlight
        end
        highlight.Adornee = adornee
        highlight.FillColor = color
        highlight.OutlineColor = color
    elseif existing.Highlight then
        pcall(existing.Highlight.Destroy, existing.Highlight)
        existing.Highlight = nil
    end

    local billboard = existing.Billboard
    if not billboard or not billboard.Parent then
        billboard = Instance.new("BillboardGui")
        billboard.Name = "BloxFruitESPLabel"
        billboard.AlwaysOnTop = true
        billboard.LightInfluence = 0
        billboard.MaxDistance = 25000
        billboard.Size = UDim2.fromOffset(132, 18)
        billboard.StudsOffset = Vector3.new(0, 2, 0)
        billboard.Enabled = false
        billboard.Parent = part
        existing.Billboard = billboard

        local label = Instance.new("TextLabel")
        label.Name = "Label"
        label.BackgroundColor3 = Color3.fromRGB(8, 10, 14)
        label.BackgroundTransparency = 0.16
        label.Size = UDim2.fromScale(1, 1)
        label.Font = Enum.Font.GothamMedium
        label.TextScaled = false
        label.TextSize = 10
        label.TextStrokeTransparency = 0.82
        label.TextTruncate = Enum.TextTruncate.AtEnd
        label.Parent = billboard
        Instance.new("UICorner", label).CornerRadius = UDim.new(0, 4)
        local stroke = Instance.new("UIStroke")
        stroke.Color = color
        stroke.Transparency = 0.55
        stroke.Thickness = 1
        stroke.Parent = label
        existing.Label = label
    end
    billboard.Adornee = part
    local _, _, playerRoot = characterParts()
    local distance = playerRoot and math.floor((part.Position - playerRoot.Position).Magnitude + 0.5)
    local label = existing.Label or billboard:FindFirstChild("Label")
    if label then
        label.TextColor3 = color
        label.Text = string.format(" %s%s ", displayName or instance.Name, distance and string.format(" · %dm", distance) or "")
        local stroke = label:FindFirstChildOfClass("UIStroke")
        if stroke then stroke.Color = color end
    end
    existing.Part = part
    existing.Distance = distance or math.huge
    return existing
end

local function clearStaticIslandParts()
    for _, part in pairs(Runtime.StaticIslandParts) do
        if part and part.Parent then
            destroyESPEntry(part)
            pcall(part.Destroy, part)
        end
    end
    table.clear(Runtime.StaticIslandParts)
end

local function staticIslandPart(island)
    local part = Runtime.StaticIslandParts[island.Name]
    if part and part.Parent then part.CFrame = island.CFrame; return part end
    part = Instance.new("Part")
    part.Name = "BloxFruitIslandMarker"
    part.Size = Vector3.new(1, 1, 1)
    part.Anchored = true
    part.CanCollide = false
    part.CanTouch = false
    part.CanQuery = false
    part.Transparency = 1
    part.CFrame = island.CFrame
    part:SetAttribute("BloxFruitOwned", true)
    part.Parent = workspace
    Runtime.StaticIslandParts[island.Name] = part
    return part
end

local function updateESPs()
    local candidates = {}
    local function add(instance, enabled, color, name, highlight, category, maxDistance)
        local entry = setESP(instance, enabled, color, name, highlight)
        if entry then
            candidates[#candidates + 1] = {
                Entry = entry,
                Category = category,
                MaxDistance = maxDistance,
            }
        end
    end
    for fruit in pairs(WorldFruits) do
        add(fruit, Settings.FruitESP, Color3.fromRGB(255, 95, 220), "FRUIT  " .. (fruitIdentity(fruit) or fruit.Name), true, "Fruit", 8000)
    end
    for chest in pairs(Runtime.Chests) do
        add(chest, Settings.ChestESP, Color3.fromRGB(255, 210, 70), "CHEST  " .. chest.Name, true, "Chest", 6000)
    end
    for berry in pairs(Runtime.Berries) do
        add(berry, Settings.BerryESP, Color3.fromRGB(80, 175, 255), "BERRY  " .. berry.Name, true, "Berry", 5000)
    end
    local islandNames = {}
    if Settings.IslandESP then
        for _, island in ipairs(ISLAND_DATA[Sea] or {}) do
            islandNames[island.Name] = true
            add(staticIslandPart(island), true, Color3.fromRGB(110, 255, 165), "ISLAND  " .. island.Name, false, "Island", 20000)
        end
    else
        clearStaticIslandParts()
    end
    for island in pairs(Runtime.Islands) do
        if not islandNames[island.Name] then
            add(island, Settings.IslandESP, Color3.fromRGB(110, 255, 165), "ISLAND  " .. island.Name, false, "Island", 20000)
        end
    end
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            add(player.Character, Settings.PlayerESP, Color3.fromRGB(255, 120, 120), "PLAYER  " .. player.DisplayName, true, "Player", 10000)
        end
    end

    table.sort(candidates, function(a, b) return a.Entry.Distance < b.Entry.Distance end)
    local camera = workspace.CurrentCamera
    if not camera then
        for _, candidate in ipairs(candidates) do
            if candidate.Entry.Billboard then candidate.Entry.Billboard.Enabled = false end
            if candidate.Entry.Highlight then candidate.Entry.Highlight.Enabled = false end
        end
        return
    end
    local occupied, categoryCount, highlightCount, shown = {}, {}, {}, 0
    local categoryLimit = {Island = 5, Fruit = 8, Chest = 8, Berry = 6, Player = 6}
    local highlightLimit = {Island = 0, Fruit = 16, Chest = 20, Berry = 12, Player = 10}
    for _, candidate in ipairs(candidates) do
        local entry = candidate.Entry
        local point, onScreen = camera:WorldToViewportPoint(entry.Part.Position)
        local count = categoryCount[candidate.Category] or 0
        local clear = true
        if onScreen and point.Z > 0 then
            for _, position in ipairs(occupied) do
                if math.abs(point.X - position.X) < 132 and math.abs(point.Y - position.Y) < 22 then
                    clear = false
                    break
                end
            end
        end
        local labelVisible = onScreen and point.Z > 0 and entry.Distance <= candidate.MaxDistance
            and shown < 14 and count < (categoryLimit[candidate.Category] or 6) and clear
        if labelVisible then
            occupied[#occupied + 1] = Vector2.new(point.X, point.Y)
            categoryCount[candidate.Category] = count + 1
            shown += 1
        end
        if entry.Billboard then entry.Billboard.Enabled = labelVisible end
        if entry.Highlight then
            local highlights = highlightCount[candidate.Category] or 0
            local highlightVisible = entry.Distance <= candidate.MaxDistance
                and highlights < (highlightLimit[candidate.Category] or 12)
            entry.Highlight.Enabled = highlightVisible
            if highlightVisible then highlightCount[candidate.Category] = highlights + 1 end
        end
    end
end

local function optimizeVisualInstance(instance)
    if instance:IsDescendantOf(LocalPlayer:FindFirstChildOfClass("PlayerGui") or LocalPlayer) then return end
    pcall(function()
        if instance:IsA("BasePart") then
            if not Runtime.VisualState[instance] then
                Runtime.VisualState[instance] = {
                    Kind = "Part", CastShadow = instance.CastShadow,
                    Reflectance = instance.Reflectance, Material = instance.Material,
                    TextureID = instance:IsA("MeshPart") and instance.TextureID or nil,
                    RenderFidelity = instance:IsA("MeshPart") and instance.RenderFidelity or nil,
                }
            end
            instance.CastShadow = false
            instance.Reflectance = 0
            instance.Material = Enum.Material.SmoothPlastic
            if instance:IsA("MeshPart") then
                instance.TextureID = ""
                instance.RenderFidelity = Enum.RenderFidelity.Performance
            end
        elseif instance:IsA("Decal") or instance:IsA("Texture") then
            if not Runtime.VisualState[instance] then Runtime.VisualState[instance] = {Kind = "Transparency", Transparency = instance.Transparency} end
            instance.Transparency = 1
        elseif instance:IsA("ParticleEmitter") or instance:IsA("Trail")
            or instance:IsA("Beam") or instance:IsA("Smoke")
            or instance:IsA("Fire") or instance:IsA("Sparkles")
        then
            if not Runtime.VisualState[instance] then Runtime.VisualState[instance] = {Kind = "Enabled", Enabled = instance.Enabled} end
            instance.Enabled = false
        elseif instance:IsA("PostEffect") or instance:IsA("Light") then
            if not Runtime.VisualState[instance] then Runtime.VisualState[instance] = {Kind = "Enabled", Enabled = instance.Enabled} end
            instance.Enabled = false
        elseif instance:IsA("Explosion") then
            if not Runtime.VisualState[instance] then Runtime.VisualState[instance] = {Kind = "Explosion", Visible = instance.Visible, BlastPressure = instance.BlastPressure} end
            instance.Visible = false
            instance.BlastPressure = 0
        end
    end)
end

local function applyAggressiveFPSBoost()
    if Runtime.FPSApplied then return end
    Runtime.FPSApplied = true
    local terrain = workspace.Terrain
    Runtime.FPSWorldState = {
        WaterWaveSize = terrain.WaterWaveSize,
        WaterWaveSpeed = terrain.WaterWaveSpeed,
        WaterReflectance = terrain.WaterReflectance,
        WaterTransparency = terrain.WaterTransparency,
        GlobalShadows = Lighting.GlobalShadows,
        FogEnd = Lighting.FogEnd,
        Brightness = Lighting.Brightness,
        EnvironmentDiffuseScale = Lighting.EnvironmentDiffuseScale,
        EnvironmentSpecularScale = Lighting.EnvironmentSpecularScale,
    }
    pcall(function() Runtime.FPSWorldState.QualityLevel = settings().Rendering.QualityLevel end)
    pcall(function() Runtime.FPSWorldState.MeshPartDetailLevel = settings().Rendering.MeshPartDetailLevel end)

    if type(setfpscap) == "function" then pcall(setfpscap, 60) end
    pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Level01 end)
    pcall(function() settings().Rendering.MeshPartDetailLevel = Enum.MeshPartDetailLevel.Level01 end)
    pcall(function() sethiddenproperty(workspace.Terrain, "Decoration", false) end)
    pcall(function()
        local terrain = workspace.Terrain
        terrain.WaterWaveSize = 0
        terrain.WaterWaveSpeed = 0
        terrain.WaterReflectance = 0
        terrain.WaterTransparency = 1
    end)
    pcall(function()
        Lighting.GlobalShadows = false
        Lighting.FogEnd = 1000000
        Lighting.Brightness = 1
        Lighting.EnvironmentDiffuseScale = 0
        Lighting.EnvironmentSpecularScale = 0
    end)

    for _, instance in ipairs(workspace:GetDescendants()) do optimizeVisualInstance(instance) end
    for _, instance in ipairs(Lighting:GetDescendants()) do optimizeVisualInstance(instance) end
    pcall(function() collectgarbage("collect") end)
end

local function restoreAggressiveFPSBoost()
    if not Runtime.FPSApplied then return end
    Runtime.FPSApplied = false
    if type(setfpscap) == "function" then pcall(setfpscap, 0) end
    for instance, state in pairs(Runtime.VisualState) do
        if instance and instance.Parent then
            pcall(function()
                if state.Kind == "Part" then
                    instance.CastShadow = state.CastShadow
                    instance.Reflectance = state.Reflectance
                    instance.Material = state.Material
                    if instance:IsA("MeshPart") then
                        instance.TextureID = state.TextureID
                        instance.RenderFidelity = state.RenderFidelity
                    end
                elseif state.Kind == "Transparency" then
                    instance.Transparency = state.Transparency
                elseif state.Kind == "Enabled" then
                    instance.Enabled = state.Enabled
                elseif state.Kind == "Explosion" then
                    instance.Visible = state.Visible
                    instance.BlastPressure = state.BlastPressure
                end
            end)
        end
        Runtime.VisualState[instance] = nil
    end
    local state = Runtime.FPSWorldState
    if state then
        pcall(function()
            local terrain = workspace.Terrain
            terrain.WaterWaveSize = state.WaterWaveSize
            terrain.WaterWaveSpeed = state.WaterWaveSpeed
            terrain.WaterReflectance = state.WaterReflectance
            terrain.WaterTransparency = state.WaterTransparency
            Lighting.GlobalShadows = state.GlobalShadows
            Lighting.FogEnd = state.FogEnd
            Lighting.Brightness = state.Brightness
            Lighting.EnvironmentDiffuseScale = state.EnvironmentDiffuseScale
            Lighting.EnvironmentSpecularScale = state.EnvironmentSpecularScale
        end)
        if state.QualityLevel then pcall(function() settings().Rendering.QualityLevel = state.QualityLevel end) end
        if state.MeshPartDetailLevel then pcall(function() settings().Rendering.MeshPartDetailLevel = state.MeshPartDetailLevel end) end
    end
    Runtime.FPSWorldState = nil
end

connect(workspace.DescendantAdded, function(instance)
    if Settings.AggressiveFPSBoost then task.defer(optimizeVisualInstance, instance) end
end)
connect(Lighting.DescendantAdded, function(instance)
    if Settings.AggressiveFPSBoost then task.defer(optimizeVisualInstance, instance) end
end)

local function playerNames()
    local values = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then values[#values + 1] = player.Name end
    end
    table.sort(values)
    return values
end

local function selectedPlayer()
    local name = tostring(Settings.SelectedPlayer or "")
    if name == "" then return nil end
    return Players:FindFirstChild(name)
end

local function selectedPlayerTarget()
    local player = selectedPlayer()
    if not player or player == LocalPlayer then return nil end
    if Settings.IgnoreSameTeams and LocalPlayer.Team ~= nil and player.Team == LocalPlayer.Team then return nil end
    local model = player.Character
    local humanoid = model and model:FindFirstChildOfClass("Humanoid")
    local root = model and model:FindFirstChild("HumanoidRootPart")
    if not humanoid or not root or humanoid.Health <= 0 then return nil end
    return player, model, humanoid, root
end

local function updateSpectateAndAim()
    local camera = workspace.CurrentCamera
    if not camera then return end
    local _, _, targetHumanoid, targetRoot = selectedPlayerTarget()
    if Settings.SpectatePlayer and targetHumanoid then
        Runtime.OriginalCameraSubject = Runtime.OriginalCameraSubject or camera.CameraSubject
        camera.CameraSubject = targetHumanoid
    elseif Runtime.OriginalCameraSubject then
        local _, localHumanoid = characterParts()
        camera.CameraSubject = localHumanoid or Runtime.OriginalCameraSubject
        Runtime.OriginalCameraSubject = nil
    end
    if Settings.AimbotCamera and targetRoot then
        camera.CFrame = CFrame.lookAt(camera.CFrame.Position, targetRoot.Position)
    end
end

local function installSkillAimbotHook()
    if Runtime.SkillAimbotHookInstalled then return end
    if type(hookmetamethod) ~= "function" or type(getnamecallmethod) ~= "function" then return end
    local wrapper = type(newcclosure) == "function" and newcclosure or function(callback) return callback end
    local previous
    local ok = pcall(function()
        previous = hookmetamethod(game, "__namecall", wrapper(function(remote, ...)
            local method = getnamecallmethod()
            local callerIsScript = type(checkcaller) ~= "function" or not checkcaller()
            if Settings.AimbotSkills and callerIsScript and method == "FireServer" then
                local _, _, _, targetRoot = selectedPlayerTarget()
                if targetRoot and typeof(remote) == "Instance" and remote:IsA("RemoteEvent") then
                    local args = table.pack(...)
                    local changed = false
                    for index = 1, args.n do
                        if typeof(args[index]) == "Vector3" then
                            args[index] = targetRoot.Position
                            changed = true
                        elseif typeof(args[index]) == "CFrame" then
                            args[index] = targetRoot.CFrame
                            changed = true
                        end
                    end
                    if changed then return previous(remote, table.unpack(args, 1, args.n)) end
                end
            end
            return previous(remote, ...)
        end))
    end)
    Runtime.SkillAimbotHookInstalled = ok and type(previous) == "function"
end

local function maintainInfiniteEnergy()
    if not Settings.InfiniteEnergy then Runtime.EnergyFloor = nil; return end
    local model = character()
    local energy = model and model:FindFirstChild("Energy")
    if not energy or not (energy:IsA("NumberValue") or energy:IsA("IntValue")) then return end
    Runtime.EnergyFloor = math.max(tonumber(Runtime.EnergyFloor) or 0, tonumber(energy.Value) or 0)
    if energy.Value < Runtime.EnergyFloor then energy.Value = Runtime.EnergyFloor end
end

local function maintainInfiniteObservation()
    if not Settings.InfiniteObservationRange then return end
    local radius = LocalPlayer:FindFirstChild("VisionRadius")
    if radius and (radius:IsA("NumberValue") or radius:IsA("IntValue")) then
        radius.Value = math.huge
    end
end

local function resetSoruCooldowns()
    if not Settings.InfiniteSoru then return end
    if Runtime.SoruClosures == nil then
        Runtime.SoruClosures = {}
        if type(getgc) == "function" then
            local ok, objects = pcall(getgc, true)
            if ok and type(objects) == "table" then
                for _, object in ipairs(objects) do
                    if type(object) == "function" then
                        local envOk, env = pcall(getfenv, object)
                        local source = envOk and env and env.script
                        if source and string.lower(source.Name) == "soru" then
                            Runtime.SoruClosures[#Runtime.SoruClosures + 1] = object
                        end
                    end
                end
            end
        end
    end
    local getUps = type(getupvalues) == "function" and getupvalues
        or (debug and type(debug.getupvalues) == "function" and debug.getupvalues)
    if not getUps then return end
    for _, callback in ipairs(Runtime.SoruClosures) do
        local ok, values = pcall(getUps, callback)
        if ok and type(values) == "table" then
            for _, value in pairs(values) do
                if type(value) == "table" then
                    if value.LastUse ~= nil then value.LastUse = 0 end
                    if value.LastUsed ~= nil then value.LastUsed = 0 end
                    if value.Cooldown ~= nil and type(value.Cooldown) == "number" then value.Cooldown = 0 end
                end
            end
        end
    end
end

local function maintainWaterWalk()
    if not Settings.WalkOnWater then
        if Runtime.WaterPart then pcall(Runtime.WaterPart.Destroy, Runtime.WaterPart); Runtime.WaterPart = nil end
        return
    end
    local model, humanoid, root = characterParts()
    if not model or not humanoid or not root then return end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {model, Runtime.WaterPart}
    params.IgnoreWater = false
    local result = workspace:Raycast(root.Position + Vector3.new(0, 10, 0), Vector3.new(0, -100, 0), params)
    local overWater = result and result.Material == Enum.Material.Water
    if not overWater and humanoid.FloorMaterial ~= Enum.Material.Water then
        if Runtime.WaterPart then Runtime.WaterPart.CFrame = CFrame.new(0, -10000, 0) end
        return
    end
    local part = Runtime.WaterPart
    if not part or not part.Parent then
        part = Instance.new("Part")
        part.Name = "BloxFruitWaterWalk"
        part.Size = Vector3.new(18, 0.5, 18)
        part.Anchored = true
        part.CanCollide = true
        part.CanTouch = false
        part.Transparency = 1
        part:SetAttribute("BloxFruitOwned", true)
        part.Parent = workspace
        Runtime.WaterPart = part
    end
    local y = overWater and (result.Position.Y + 0.25) or (root.Position.Y - 3.25)
    part.CFrame = CFrame.new(root.Position.X, y, root.Position.Z)
end

local function acceptAllyRequest()
    if not Settings.AcceptAllies then return end
    local gui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if not gui then return end
    for _, object in ipairs(gui:GetDescendants()) do
        if object:IsA("GuiButton") then
            local text = string.lower((object:IsA("TextButton") and object.Text) or object.Name)
            if string.find(text, "accept", 1, true) and string.find(text, "all", 1, true) then
                if type(firesignal) == "function" then pcall(firesignal, object.Activated) else pcall(object.Activate, object) end
            end
        end
    end
end

connect(LocalPlayer.CharacterRemoving, function(removingCharacter)
    Runtime.Respawning = true
    Runtime.CharacterGeneration += 1
    local snapshot = {}
    for key in pairs(FARM_TOGGLE_KEYS) do snapshot[key] = Settings[key] == true end
    Runtime.RespawnFarmSettings = snapshot
    Runtime.ManualTravelHold = false
    Runtime.ManualTravelInProgress = false
    Runtime.CurrentTarget = nil
    finishPickupOverlay()
    Movement:Cancel()
    clearFarmAnchor(true)
    for part, original in pairs(Runtime.CollisionState) do
        if part and part:IsDescendantOf(removingCharacter) then
            pcall(function() part.CanCollide = original end)
            Runtime.CollisionState[part] = nil
        end
    end
    for body in pairs(Runtime.OwnedBodyMovers) do
        if body and body.Name == "BodyClip" and body:IsDescendantOf(removingCharacter) then
            Runtime.OwnedBodyMovers[body] = nil
            if body.Parent then pcall(body.Destroy, body) end
        end
    end
end)

connect(LocalPlayer.CharacterAdded, function(addedCharacter)
    Runtime.CharacterGeneration += 1
    local generation = Runtime.CharacterGeneration
    Runtime.Respawning = true
    Runtime.EnergyFloor = nil
    Runtime.SoruClosures = nil
    Runtime.LastLandCFrame = nil
    Runtime.CurrentTarget = nil
    Runtime.ManualTravelHold = false
    Runtime.ManualTravelInProgress = false
    Runtime.ForceReleaseUntil = 0
    Movement:Cancel()
    clearFarmAnchor(true)
    if Runtime.WaterPart then pcall(Runtime.WaterPart.Destroy, Runtime.WaterPart); Runtime.WaterPart = nil end
    task.spawn(function()
        local humanoid = addedCharacter:WaitForChild("Humanoid", 15)
        local root = addedCharacter:WaitForChild("HumanoidRootPart", 15)
        if not Runtime.Alive or generation ~= Runtime.CharacterGeneration
            or addedCharacter ~= LocalPlayer.Character or not humanoid or not root
        then
            return
        end
        root.Anchored = false
        humanoid.PlatformStand = false
        humanoid.AutoRotate = true
        local snapshot = Runtime.RespawnFarmSettings
        Runtime.RespawnFarmSettings = nil
        if snapshot then
            for key, enabled in pairs(snapshot) do
                if enabled then
                    Settings[key] = true
                    for _, control in ipairs(Runtime.UIControls[key] or {}) do
                        pcall(control.Set, control, true)
                    end
                end
            end
        end
        Runtime.Respawning = false
        savePersistentSettings(true)
    end)
end)
connect(Players.PlayerAdded, function()
    if Runtime.PlayerDropdown then pcall(Runtime.PlayerDropdown.Refresh, Runtime.PlayerDropdown, playerNames()) end
end)
connect(Players.PlayerRemoving, function(player)
    if Settings.SelectedPlayer == player.Name then Settings.SelectedPlayer = "" end
    if Runtime.PlayerDropdown then pcall(Runtime.PlayerDropdown.Refresh, Runtime.PlayerDropdown, playerNames()) end
end)
installSkillAimbotHook()

connect(LocalPlayer.Idled, function()
    if not Settings.AntiAFK then return end
    pcall(function()
        VirtualUser:CaptureController()
        VirtualUser:Button2Down(Vector2.zero, workspace.CurrentCamera.CFrame)
        task.wait(0.1)
        VirtualUser:Button2Up(Vector2.zero, workspace.CurrentCamera.CFrame)
    end)
end)

task.spawn(function()
    while Runtime.Alive do
        if featureReady("Stats", 0.3) then pcall(addStats) end
        if Settings.AutoBuso and featureReady("Buso", 2) then
            local model = character()
            if model and not model:FindFirstChild("HasBuso") then pcall(invokeComm, "Buso") end
        end
        if Settings.AutoRandomFruit and featureReady("RandomFruit", 2) then
            spinRandomFruit()
        end
        if Settings.AutoStoreFruit and featureReady("StoreFruit", 1) then pcall(storeHeldFruits) end
        if Settings.AutoBuyStockFruit and featureReady("StockFruit", 4) then
            pcall(buySelectedStockFruit)
        end
        if Settings.AutoRaceV3 and featureReady("RaceV3", 2) then pcall(fireComm, "ActivateAbility") end
        if Settings.AutoRaceV4 and featureReady("RaceV4", 2) then pcall(fireComm, "ActivateAbility") end
        if Settings.AutoObservation and featureReady("Observation", 1.5) then pcall(enableObservation) end
        if Settings.AutoFishing and featureReady("Fishing", 1.1) then pcall(fishingTick) end
        if (Settings.AutoBuyBait or Settings.AutoFishingQuest) and featureReady("FishingNPC", 3) then pcall(interactFishingNPC) end
        if Settings.AutoDojoTrainer and featureReady("Dojo", 2) then
            pcall(invokeDojoRemote, DragonQuestRemote)
            pcall(invokeDojoRemote, DragonHunterRemote)
        end
        if Settings.AutoRefreshBossList and featureReady("DropdownRefresh", 2) then
            if Runtime.BossDropdown then pcall(Runtime.BossDropdown.Refresh, Runtime.BossDropdown, currentBossNames()) end
            if Runtime.IslandDropdown then
                local islands = currentIslandNames()
                pcall(Runtime.IslandDropdown.Refresh, Runtime.IslandDropdown, islands)
                if Settings.SelectedIsland == "" and islands[1] then
                    Settings.SelectedIsland = islands[1]
                    pcall(Runtime.IslandDropdown.Set, Runtime.IslandDropdown, islands[1])
                end
            end
        end
        if Settings.TeleportToPlayer then
            local _, _, _, targetRoot = selectedPlayerTarget()
            if targetRoot then Movement:Go(targetRoot.CFrame * CFrame.new(0, 5, 3)) end
        end
        pcall(updateSpectateAndAim)
        pcall(maintainInfiniteEnergy)
        pcall(maintainInfiniteObservation)
        pcall(maintainWaterWalk)
        if Settings.InfiniteMinkV3 and featureReady("InfiniteMinkV3", 0.25) then pcall(fireComm, "ActivateAbility") end
        if Settings.InfiniteSoru and featureReady("InfiniteSoru", 0.5) then pcall(resetSoruCooldowns) end
        if Settings.AcceptAllies and featureReady("AcceptAllies", 1) then pcall(acceptAllyRequest) end
        local _, humanoid = characterParts()
        if humanoid then
            if Settings.LockWalkSpeed then humanoid.WalkSpeed = math.clamp(tonumber(Settings.WalkSpeed) or 16, 0, 500) end
            if Settings.LockJumpPower then humanoid.JumpPower = math.clamp(tonumber(Settings.JumpPower) or 50, 0, 500) end
        end
        if Settings.AutoCombatSkills and featureReady("CombatSkills", 0.7) then pcall(castEnabledSkills) end
        if featureReady("ESP", 0.75) then pcall(updateESPs) end
        task.wait(0.12)
    end
end)

local function restoreCharacterPhysics(aggressive)
    local released = aggressive == true or next(Runtime.CollisionState) ~= nil
    for part, original in pairs(Runtime.CollisionState) do
        if part and part.Parent then pcall(function() part.CanCollide = original end) end
        Runtime.CollisionState[part] = nil
    end
    for body in pairs(Runtime.OwnedBodyMovers) do
        if body and body.Name == "BodyClip" then
            released = true
            Runtime.OwnedBodyMovers[body] = nil
            if body.Parent then pcall(body.Destroy, body) end
        end
    end
    local model, humanoid, root = characterParts()
    if model and aggressive then
        for _, object in ipairs(model:GetDescendants()) do
            if object:IsA("BasePart") then
                object.Anchored = false
            elseif (object:IsA("BodyVelocity") or object:IsA("BodyPosition")
                or object:IsA("BodyGyro") or object:IsA("LinearVelocity")
                or object:IsA("AngularVelocity") or object:IsA("VectorForce")
                or object:IsA("AlignPosition") or object:IsA("AlignOrientation"))
                and (object.Name == "BodyClip" or object:GetAttribute("BloxFruitOwned") == true)
            then
                Runtime.OwnedBodyMovers[object] = nil
                pcall(object.Destroy, object)
            end
        end
    end
    local staleBodyClip = root and root:FindFirstChild("BodyClip")
    if staleBodyClip and staleBodyClip:IsA("BodyVelocity") then
        released = true
        Runtime.OwnedBodyMovers[staleBodyClip] = nil
        pcall(staleBodyClip.Destroy, staleBodyClip)
    end
    if root and root.Anchored then
        released = true
        root.Anchored = false
    end
    if released and root then
        -- A small downward velocity guarantees that a character released over
        -- open air falls normally instead of remaining suspended after a farm.
        root.AssemblyLinearVelocity = Vector3.new(0, -8, 0)
        root.AssemblyAngularVelocity = Vector3.zero
    end
    if released and humanoid then
        humanoid.PlatformStand = false
        humanoid.Sit = false
        humanoid.AutoRotate = true
        local releaseState = humanoid.FloorMaterial == Enum.Material.Air
            and Enum.HumanoidStateType.Freefall or Enum.HumanoidStateType.Running
        pcall(humanoid.ChangeState, humanoid, releaseState)
        task.defer(function()
            if humanoid.Parent and humanoid.Health > 0 then
                local state = humanoid.FloorMaterial == Enum.Material.Air
                    and Enum.HumanoidStateType.Freefall or Enum.HumanoidStateType.Running
                pcall(humanoid.ChangeState, humanoid, state)
            end
        end)
    end
end

local function forceReleaseAutomation()
    Runtime.ForceReleaseUntil = os.clock() + 1.25
    Runtime.CurrentTarget = nil
    finishPickupOverlay()
    Movement:Cancel()
    clearFarmAnchor(true)
    restoreCharacterPhysics(true)
    return true
end

local fastAccumulator, physicsAccumulator = 0, 0
connect(RunService.Heartbeat, function(delta)
    if not Runtime.Alive then return end
    fastAccumulator += delta
    local delay = ATTACK_DELAYS[Settings.AttackMode] or 0.2
    if fastAccumulator >= delay then
        fastAccumulator = 0
        local ok, err = pcall(attackTick)
        if not ok then warn("BloxFruitScript target tick:", err) end
    end

    physicsAccumulator += delta
    if physicsAccumulator >= 0.12 then
        physicsAccumulator = 0
        local manualTween = Runtime.ManualTravelInProgress
            and Runtime.MovementOwner == "ManualTravel"
        local automationPhysics = Runtime.PickupBusy or manualTween
            or Runtime.MovementTween ~= nil
            or (farmEnabled() and (Runtime.CurrentTarget ~= nil or Runtime.AnchorReached))
        if os.clock() < Runtime.ForceReleaseUntil then
            restoreCharacterPhysics(true)
        elseif automationPhysics
            and not Runtime.Respawning and (not Runtime.ManualTravelHold or manualTween)
        then
            local model, _, root = characterParts()
            if root then ensureBodyVelocity(root, "BodyClip", Vector3.new(100000, 100000, 100000)) end
            if not Runtime.PickupBusy and root and Runtime.AnchorReached and Runtime.FarmAnchor then
                local _, targetRoot = aliveModel(Runtime.CurrentTarget)
                if targetRoot and (targetRoot.Position - Runtime.FarmAnchor.Position).Magnitude
                    <= math.max(120, tonumber(Settings.BringRadius) or 3000)
                then
                    root.CFrame = Runtime.FarmAnchor
                        * CFrame.new(0, tonumber(Settings.Height) or 20, 0)
                        * CFrame.Angles(0, math.pi, 0)
                    root.AssemblyLinearVelocity = Vector3.zero
                else
                    Runtime.AnchorReached = false
                    Runtime.FarmAnchor = nil
                    Runtime.FarmAnchorKey = nil
                end
            end
            if model then
                for _, part in ipairs(model:GetDescendants()) do
                    if part:IsA("BasePart") then
                        if Runtime.CollisionState[part] == nil then Runtime.CollisionState[part] = part.CanCollide end
                        part.CanCollide = false
                    end
                end
            end
        else
            restoreCharacterPhysics()
        end
    end
end)

local API = {}
API.Settings = Settings
API.Runtime = Runtime
API.LevelData = LEVEL_DATA
API.BossData = BOSS_DATA
API.BossLists = BOSS_LISTS
API.MaterialData = MATERIAL_DATA
API.MaterialLists = MATERIAL_LISTS

function API.GetHeldFruits()
    local names = {}
    for _, entry in ipairs(heldFruitEntries()) do names[#names + 1] = entry.Name end
    return names
end

API.SpinRandomFruit = spinRandomFruit
API.StoreHeldFruits = storeHeldFruits
API.ForceReleaseCharacter = forceReleaseAutomation

function API.Set(name, value)
    if type(name) ~= "string" or Settings[name] == nil then
        warn("BloxFruitScript ignored unknown UI setting:", tostring(name))
        return nil
    end
    -- RenLib may replay stored control flags while constructing the window.
    -- The script profile is authoritative during that short hydration phase.
    if Runtime.UIHydrating then return Settings[name] end
    if name == "Height" then value = math.max(16, tonumber(value) or 20) end
    if name == "TweenSpeed" then value = math.clamp(tonumber(value) or 300, 5, 600) end
    if name == "StatsValue" then value = math.clamp(math.floor(tonumber(value) or 2), 1, 1000) end
    if name == "WalkSpeed" then value = math.clamp(tonumber(value) or 16, 0, 500) end
    if name == "JumpPower" then value = math.clamp(tonumber(value) or 50, 0, 500) end
    if value == true and FARM_TOGGLE_KEYS[name] then
        resumeAutomationMovement()
        for other in pairs(FARM_TOGGLE_KEYS) do
            if other ~= name and Settings[other] then
                Settings[other] = false
                for _, control in ipairs(Runtime.UIControls[other] or {}) do
                    pcall(control.Set, control, false)
                end
            end
        end
    end
    Settings[name] = value
    if name == "AutoRandomFruit" and value == true then Runtime.FeatureLastRun.RandomFruit = nil end
    if name == "AutoStoreFruit" and value == true then Runtime.FeatureLastRun.StoreFruit = nil end
    if name == "AutoBuyStockFruit" and value == true then Runtime.FeatureLastRun.StockFruit = nil end
    if name == "AggressiveFPSBoost" then
        if value == true then applyAggressiveFPSBoost() else restoreAggressiveFPSBoost() end
    end
    if name == "AimbotSkills" and value == true then installSkillAimbotHook() end
    if name == "SpectatePlayer" and value == false then pcall(updateSpectateAndAim) end
    if name == "WalkOnWater" and value == false then pcall(maintainWaterWalk) end
    if FARM_TOGGLE_KEYS[name] or name == "SelectedMob" or name == "SelectedBoss"
        or name == "SelectedMaterial" or name == "SelectedEventEnemy"
    then
        Runtime.CurrentTarget = nil
        if name == "AutoFarmAllBoss" then Runtime.AllBossIndex = 1; Runtime.AllBossArrivedAt = nil end
        clearFarmAnchor(true)
        if FARM_TOGGLE_KEYS[name] and value == false and not farmEnabled() then
            forceReleaseAutomation()
        end
    elseif name == "BringMobs" and value == false then
        restoreEnemies()
    elseif (name == "FruitESP" or name == "ChestESP" or name == "BerryESP" or name == "IslandESP" or name == "PlayerESP") and value == false then
        updateESPs()
    elseif name == "AutoCollectChest" then
        Runtime.ChestSweepQueue = nil
        Runtime.ChestSweepIndex = 1
        Runtime.ChestSweepArrivedAt = nil
        Runtime.ChestStreamRequestBusy = false
        Runtime.ChestStreamRequestSupported = true
        Runtime.ChestSweepNextAt = value and 0 or math.huge
        if value == false and not Settings.AutoCollectFruit and not Settings.AutoCollectBerries then
            finishPickupOverlay()
        end
    elseif (name == "AutoCollectFruit" or name == "AutoCollectChest" or name == "AutoCollectBerries") and value == false
        and not Settings.AutoCollectFruit and not Settings.AutoCollectChest and not Settings.AutoCollectBerries
    then
        finishPickupOverlay()
    end
    -- Farm state is committed immediately so even executors that rebuild the
    -- injected LocalScript on CharacterAdded restore the enabled toggle.
    savePersistentSettings(FARM_TOGGLE_KEYS[name] == true)
    return value
end

function API.SetAttackTransport(callback)
    assert(type(callback) == "function", "Attack transport must be a function")
    Runtime.AttackTransport = callback
end

function API.ResetAttackTransport()
    Runtime.AttackTransport = defaultAttackTransport
end

function API.GetFastTargets()
    return Runtime.FastTargets, Runtime.HitParts, Runtime.PrimaryTarget
end

function API.Bring(target)
    return bringEnemy(target)
end

function API.Move(destination)
    return Movement:Go(destination)
end

function API.ResumeAutomationMovement()
    return resumeAutomationMovement()
end

function API.StopAll()
    for key in pairs(Settings) do
        if string.sub(key, 1, 4) == "Auto" and key ~= "AutoRefreshBossList" then
            Settings[key] = false
            for _, control in ipairs(Runtime.UIControls[key] or {}) do
                pcall(control.Set, control, false)
            end
        end
    end
    Runtime.CurrentTarget = nil
    finishPickupOverlay()
    Movement:Cancel()
    clearFarmAnchor(true)
    forceReleaseAutomation()
    savePersistentSettings(true)
end

local function uiParent()
    if type(gethui) == "function" then
        local ok, result = pcall(gethui)
        if ok and result then return result end
    end
    local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    return playerGui or CoreGui
end

local function makeUI()
    local parent = uiParent()
    local old = parent:FindFirstChild("BloxFruitScriptUI")
    if old then old:Destroy() end

    local gui = Instance.new("ScreenGui")
    gui.Name = "BloxFruitScriptUI"
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Parent = parent

    local frame = Instance.new("Frame")
    frame.Name = "Main"
    frame.Size = UDim2.fromOffset(420, 510)
    frame.Position = UDim2.new(0, 24, 0.5, -255)
    frame.BackgroundColor3 = Color3.fromRGB(13, 13, 18)
    frame.BorderSizePixel = 0
    frame.Active = true
    frame.Parent = gui
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)

    local stroke = Instance.new("UIStroke", frame)
    stroke.Color = Color3.fromRGB(255, 45, 145)
    stroke.Thickness = 2

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -16, 0, 42)
    title.Position = UDim2.fromOffset(8, 4)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBold
    title.Text = "BLOX FRUIT SCRIPT"
    title.TextColor3 = Color3.fromRGB(255, 240, 250)
    title.TextSize = 16
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = frame

    local content = Instance.new("ScrollingFrame")
    content.Size = UDim2.new(1, -20, 1, -92)
    content.Position = UDim2.fromOffset(10, 48)
    content.BackgroundTransparency = 1
    content.BorderSizePixel = 0
    content.ScrollBarThickness = 4
    content.ScrollBarImageColor3 = Color3.fromRGB(255, 45, 145)
    content.AutomaticCanvasSize = Enum.AutomaticSize.Y
    content.CanvasSize = UDim2.new()
    content.Parent = frame
    local layout = Instance.new("UIListLayout", content)
    layout.Padding = UDim.new(0, 6)

    local function row(height)
        local holder = Instance.new("Frame")
        holder.Size = UDim2.new(1, -4, 0, height or 34)
        holder.BackgroundColor3 = Color3.fromRGB(24, 24, 32)
        holder.BorderSizePixel = 0
        holder.Parent = content
        Instance.new("UICorner", holder).CornerRadius = UDim.new(0, 6)
        return holder
    end

    local function toggle(label, key)
        local holder = row()
        local button = Instance.new("TextButton")
        button.Size = UDim2.new(1, -10, 1, -6)
        button.Position = UDim2.fromOffset(5, 3)
        button.BackgroundTransparency = 1
        button.Font = Enum.Font.GothamMedium
        button.TextSize = 14
        button.TextXAlignment = Enum.TextXAlignment.Left
        button.Parent = holder
        local function refresh()
            button.Text = string.format("%s   [%s]", label, Settings[key] and "ON" or "OFF")
            button.TextColor3 = Settings[key] and Color3.fromRGB(255, 75, 165) or Color3.fromRGB(205, 205, 215)
        end
        connect(button.MouseButton1Click, function()
            API.Set(key, not Settings[key])
            refresh()
        end)
        refresh()
    end

    local function input(label, key, numeric)
        local holder = row(38)
        local text = Instance.new("TextLabel")
        text.Size = UDim2.new(0.44, -8, 1, 0)
        text.Position = UDim2.fromOffset(8, 0)
        text.BackgroundTransparency = 1
        text.Font = Enum.Font.GothamMedium
        text.Text = label
        text.TextColor3 = Color3.fromRGB(205, 205, 215)
        text.TextSize = 13
        text.TextXAlignment = Enum.TextXAlignment.Left
        text.Parent = holder
        local box = Instance.new("TextBox")
        box.Size = UDim2.new(0.56, -10, 1, -10)
        box.Position = UDim2.new(0.44, 2, 0, 5)
        box.BackgroundColor3 = Color3.fromRGB(35, 35, 46)
        box.BorderSizePixel = 0
        box.ClearTextOnFocus = false
        box.Font = Enum.Font.Code
        box.Text = tostring(Settings[key] or "")
        box.TextColor3 = Color3.fromRGB(255, 235, 247)
        box.TextSize = 13
        box.Parent = holder
        Instance.new("UICorner", box).CornerRadius = UDim.new(0, 5)
        connect(box.FocusLost, function()
            local value = numeric and tonumber(box.Text) or box.Text
            if value ~= nil and value ~= "" then API.Set(key, value) end
            box.Text = tostring(Settings[key] or "")
        end)
    end

    toggle("Auto Farm Level", "AutoFarmLevel")
    toggle("Auto Kill Mob", "AutoKillMob")
    toggle("Auto Farm Boss", "AutoFarmBoss")
    toggle("Auto Farm All Boss", "AutoFarmAllBoss")
    toggle("Accept Level Quests", "AcceptLevelQuests")
    toggle("Accept Boss Quests", "AcceptBossQuests")
    toggle("Bring Mobs", "BringMobs")
    toggle("Fast Target Collector", "FastAttack")
    toggle("Activate Equipped Tool", "ActivateTool")
    input("Selected Mob", "SelectedMob", false)
    input("Selected Boss", "SelectedBoss", false)
    input("Weapon Category", "WeaponCategory", false)
    input("Height", "Height", true)
    input("Tween Speed", "TweenSpeed", true)
    input("Attack Mode", "AttackMode", false)

    local status = Instance.new("TextLabel")
    status.Size = UDim2.new(1, -100, 0, 30)
    status.Position = UDim2.new(0, 10, 1, -38)
    status.BackgroundTransparency = 1
    status.Font = Enum.Font.Code
    status.TextColor3 = Color3.fromRGB(190, 190, 205)
    status.TextSize = 12
    status.TextXAlignment = Enum.TextXAlignment.Left
    status.Parent = frame

    local stop = Instance.new("TextButton")
    stop.Size = UDim2.fromOffset(84, 28)
    stop.Position = UDim2.new(1, -94, 1, -37)
    stop.BackgroundColor3 = Color3.fromRGB(255, 45, 145)
    stop.BorderSizePixel = 0
    stop.Font = Enum.Font.GothamBold
    stop.Text = "STOP ALL"
    stop.TextColor3 = Color3.new(1, 1, 1)
    stop.TextSize = 12
    stop.Parent = frame
    Instance.new("UICorner", stop).CornerRadius = UDim.new(0, 6)
    connect(stop.MouseButton1Click, API.StopAll)

    local dragging, dragStart, frameStart
    connect(title.InputBegan, function(inputObject)
        if inputObject.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging, dragStart, frameStart = true, inputObject.Position, frame.Position
        end
    end)
    connect(UserInputService.InputEnded, function(inputObject)
        if inputObject.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end)
    connect(UserInputService.InputChanged, function(inputObject)
        if dragging and inputObject.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = inputObject.Position - dragStart
            frame.Position = frameStart + UDim2.fromOffset(delta.X, delta.Y)
        end
    end)

    task.spawn(function()
        while Runtime.Alive and gui.Parent do
            local target = Runtime.CurrentTarget
            status.Text = string.format("%s  •  %s  •  targets:%d", Runtime.CurrentMode, target and target.Name or "none", #Runtime.FastTargets)
            task.wait(0.4)
        end
    end)
    Runtime.Gui = gui
end

local function makeRenLibUI()
    local RenLib = (function()
-- GENERATED FILE: edit RenLibSource/Modules, then run Build-RenLib.ps1
-- Module count: 22

--[[ MODULE: 00_runtime.part.lua ]]
-- Module fragment: runtime, services, constants, root state
-- Generated from the working V7 baseline; edit this feature in isolation.
-- RenLib V9.1.0 beta modular compatibility bundle
-- Responsive Roblox UI framework with centralized navigation, non-destructive
-- search, mobile-first input, live theming, addons, and deterministic cleanup.

--// SERVICES
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")
local TextService = game:GetService("TextService")
local GuiService = game:GetService("GuiService")
local ContentProvider = game:GetService("ContentProvider")

--// LOCAL SHORTCUTS
local Plr = Players.LocalPlayer
local Mouse = Plr:GetMouse()
local Camera = workspace.CurrentCamera

--// DEVICE DETECTION
local function getViewport()
    Camera = workspace.CurrentCamera or Camera
    return Camera and Camera.ViewportSize or Vector2.new(800, 600)
end

local function getDeviceMode(scale)
    local viewport = getViewport()
    local normalizedScale = math.max(tonumber(scale) or 1, 0.01)
    -- Larger UI scales reduce usable physical space, so responsive mode is
    -- chosen from the canvas people can actually see rather than raw pixels.
    local scalePressure = normalizedScale < 1 and normalizedScale or (1 / normalizedScale)
    local effectiveWidth = viewport.X * scalePressure
    if effectiveWidth <= 620 then
        return "Phone"
    elseif effectiveWidth <= 960 or (UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled) then
        return "Tablet"
    end
    return "Desktop"
end

local DeviceMode = getDeviceMode(1)
local IsMobile = DeviceMode ~= "Desktop"
local ScreenSize = getViewport()

--// CONSTANTS
local CONFIG_FOLDER = "RenLib/Configs"
local RUNTIME_KEY = "__RENLIB_V8_RUNTIME"
local INFINITE_YIELD_URL = "https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/source"
local RenCore_LOADER_URL = "https://raw.githubusercontent.com/xsakyx/RobloxUILib/refs/heads/main/Loaders/RenCoreLoader"
local BRAND_ICON_ASSET_ID = "rbxassetid://84928996923191"
local BRAND_ICON_FALLBACK = "rbxassetid://6034316009"
local function resolveRuntimeEnvironment()
    if type(getgenv) == "function" then
        local ok, environment = pcall(getgenv)
        if ok and type(environment) == "table" then
            return environment
        end
        if not ok then
            warn("[RenLib] getgenv failed; using a fallback environment: " .. tostring(environment))
        end
    end
    if type(shared) == "table" then
        return shared
    end
    if type(_G) == "table" then
        return _G
    end
    return {}
end

local RuntimeEnvironment = resolveRuntimeEnvironment()

-- Only one RenLib session may own input and UI at a time.
local PreviousSession = RuntimeEnvironment[RUNTIME_KEY]
if PreviousSession and type(PreviousSession.Unload) == "function" then
    pcall(function()
        PreviousSession:Unload("replaced")
    end)
end

--// EMOJI ICONS
local EMOJIS = {
    Logo = "</>",
    Settings = "⚙️",
    Search = "🔍",
    Close = "❌",
    Minimize = "➖",
    Arrow = "▼",
    Check = "✓",
    Star = "⭐",
    Play = "▶",
    Trash = "🗑️",
    Refresh = "🔄",
    Info = "ℹ️",
    Warning = "⚠️",
    Success = "✅",
    Error = "❌",
    Home = "🏠",
    Code = "</>",
    Terminal = "💻",
    User = "👤",
    Lock = "🔒",
    Unlock = "🔓"
}

-- Material icons hosted on Roblox. These keep core chrome crisp at every UI scale.
local ICONS = {
    Settings = "rbxassetid://6031280882",
    Search = "rbxassetid://6031154871",
    Close = "rbxassetid://6031094678",
    Minimize = "rbxassetid://6026568240",
    ChevronDown = "rbxassetid://6034818372",
    ChevronRight = "rbxassetid://6034818365",
    Home = "rbxassetid://9080449299",
    Profile = "rbxassetid://6022668898",
    Play = "rbxassetid://6026663699",
    Palette = "rbxassetid://6034316009",
    Restore = "rbxassetid://6031260800",
    Dashboard = "rbxassetid://6034287594",
    Layers = "rbxassetid://6034328955",
    Glass = "rbxassetid://6034925618",
    Check = "rbxassetid://6031094667",
    Menu = "rbxassetid://6031091002"
}

--// ROOT LIBRARY
local Library = {}
Library.Version = "9.1.0-beta"
Library.Architecture = "modular-bundle"
Library.Title = "RenLib"
Library.Connections = {}
Library.Tasks = {}
Library.Flags = {}
Library.Options = {}
Library.PendingAutoloadFlags = {}
Library.AutoloadConfigName = nil
Library.AutoloadThemeName = nil
Library.KnownConfigs = {}
Library.Unloaded = false
Library.Keybinds = {}
Library.KeybindDefaults = {}
Library.Addons = {}
Library.AddonOrder = {}
Library.ESPManagers = {}
Library.ToggleKey = Enum.KeyCode.K
Library.IsMinimized = false
Library.IsMobile = IsMobile
Library.DeviceMode = DeviceMode
Library.DPIScale = 1
Library.ReducedMotion = false
Library.MotionScale = 1
-- Strong registries are intentional. Some injected Instance wrappers are not
-- stable as weak-table keys, which can make theme entries disappear mid-session.
-- Every registry is explicitly cleared by Unload, so this does not leak state.
Library.ActiveTweens = {}
Library.LayoutTweens = {}
Library.VisibilityTweens = {}
Library.GradientRegistry = {}
Library.ActiveTheme = "Obsidian"
Library.ScalePreview = nil
Library.MaterialMode = "Solid"
Library.MaterialIntensity = 18
Library.MaterialRegistry = {}
Library.MaterialDecorations = {}
Library.BrandIcon = BRAND_ICON_ASSET_ID
-- Brand marks use semantic text contrast. A dark theme therefore receives a
-- bright mark while a light theme receives a dark mark, without hard-coded
-- per-theme exceptions.
Library.BrandIconTint = nil
Library.BrandMarks = {}
Library.Icons = ICONS
Library.WorkflowPresets = {
    Leveling = {
        Name = "Leveling",
        Description = "Prioritize repeatable progression and experience actions.",
        Synonyms = {"level", "levels", "xp", "grind", "farm"},
        Flags = {}
    },
    Items = {
        Name = "Items",
        Description = "Prioritize item collection, ownership checks, and upgrades.",
        Synonyms = {"item", "items", "loot", "collect", "inventory"},
        Flags = {}
    },
    Raids = {
        Name = "Raids",
        Description = "Prioritize raid preparation, islands, and boss actions.",
        Synonyms = {"raid", "raids", "boss", "event", "island"},
        Flags = {}
    },
    LowEnd = {
        Name = "Low-end devices",
        Description = "Reduce motion and expensive material effects for a lighter UI.",
        Synonyms = {"low end", "performance", "fps", "mobile", "potato"},
        Flags = {},
        ReducedMotion = true,
        MotionScale = 0.5,
        MaterialMode = "Solid"
    }
}
Library.StrategyProfilePrefix = "strategy_"

-- Theme (can be changed at runtime)
Library.Theme = {
    Main = Color3.fromRGB(9, 11, 16),
    Secondary = Color3.fromRGB(14, 17, 24),
    Surface = Color3.fromRGB(20, 24, 34),
    SurfaceAlt = Color3.fromRGB(28, 33, 45),
    Stroke = Color3.fromRGB(66, 74, 94),
    Divider = Color3.fromRGB(38, 44, 58),
    Text = Color3.fromRGB(241, 244, 249),
    SubText = Color3.fromRGB(147, 156, 174),
    Hover = Color3.fromRGB(31, 37, 50),
    Click = Color3.fromRGB(39, 46, 61),
    Accent = Color3.fromRGB(103, 151, 255),
    Accent2 = Color3.fromRGB(69, 207, 190),
    Accent3 = Color3.fromRGB(184, 118, 255),
    Success = Color3.fromRGB(75, 215, 155),
    Warn = Color3.fromRGB(242, 184, 78),
    Error = Color3.fromRGB(241, 89, 113)
}

Library.ThemePresets = {
    Obsidian = {
        Main = Color3.fromRGB(9, 11, 16), Secondary = Color3.fromRGB(14, 17, 24),
        Surface = Color3.fromRGB(20, 24, 34), SurfaceAlt = Color3.fromRGB(28, 33, 45),
        Stroke = Color3.fromRGB(66, 74, 94), Divider = Color3.fromRGB(38, 44, 58),
        Text = Color3.fromRGB(241, 244, 249), SubText = Color3.fromRGB(147, 156, 174),
        Hover = Color3.fromRGB(31, 37, 50), Click = Color3.fromRGB(39, 46, 61),
        Accent = Color3.fromRGB(103, 151, 255), Accent2 = Color3.fromRGB(69, 207, 190), Accent3 = Color3.fromRGB(184, 118, 255),
        Success = Color3.fromRGB(75, 215, 155), Warn = Color3.fromRGB(242, 184, 78), Error = Color3.fromRGB(241, 89, 113)
    },
    Midnight = {
        Main = Color3.fromRGB(23, 26, 36), Secondary = Color3.fromRGB(29, 32, 44),
        Surface = Color3.fromRGB(36, 40, 53), SurfaceAlt = Color3.fromRGB(44, 48, 63),
        Stroke = Color3.fromRGB(82, 87, 108), Divider = Color3.fromRGB(58, 62, 79),
        Text = Color3.fromRGB(244, 245, 248), SubText = Color3.fromRGB(158, 160, 176),
        Hover = Color3.fromRGB(49, 53, 68), Click = Color3.fromRGB(57, 61, 78),
        Accent = Color3.fromRGB(96, 164, 255), Accent2 = Color3.fromRGB(120, 220, 226), Success = Color3.fromRGB(60, 220, 120),
        Warn = Color3.fromRGB(240, 200, 60), Error = Color3.fromRGB(240, 60, 60)
    },
    Nebula = {
        Main = Color3.fromRGB(29, 23, 43), Secondary = Color3.fromRGB(36, 29, 52),
        Surface = Color3.fromRGB(44, 35, 63), SurfaceAlt = Color3.fromRGB(53, 42, 75),
        Stroke = Color3.fromRGB(91, 75, 122), Divider = Color3.fromRGB(70, 59, 95),
        Text = Color3.fromRGB(246, 243, 255), SubText = Color3.fromRGB(174, 164, 199),
        Hover = Color3.fromRGB(58, 47, 80), Click = Color3.fromRGB(66, 53, 90),
        Accent = Color3.fromRGB(170, 106, 255), Accent2 = Color3.fromRGB(89, 189, 255), Success = Color3.fromRGB(76, 218, 157),
        Warn = Color3.fromRGB(255, 198, 88), Error = Color3.fromRGB(255, 94, 117)
    },
    Celestial = {
        Main = Color3.fromRGB(24, 26, 37), Secondary = Color3.fromRGB(29, 32, 44),
        Surface = Color3.fromRGB(36, 39, 53), SurfaceAlt = Color3.fromRGB(44, 47, 63),
        Stroke = Color3.fromRGB(82, 86, 111), Divider = Color3.fromRGB(57, 60, 79),
        Text = Color3.fromRGB(245, 245, 249), SubText = Color3.fromRGB(158, 160, 178),
        Hover = Color3.fromRGB(48, 51, 68), Click = Color3.fromRGB(55, 59, 77),
        Accent = Color3.fromRGB(157, 112, 255), Accent2 = Color3.fromRGB(91, 190, 255), Success = Color3.fromRGB(66, 224, 171),
        Warn = Color3.fromRGB(255, 205, 92), Error = Color3.fromRGB(255, 92, 120)
    },
    Rose = {
        Main = Color3.fromRGB(42, 27, 36), Secondary = Color3.fromRGB(50, 32, 43),
        Surface = Color3.fromRGB(61, 38, 52), SurfaceAlt = Color3.fromRGB(72, 44, 61),
        Stroke = Color3.fromRGB(111, 70, 91), Divider = Color3.fromRGB(86, 55, 73),
        Text = Color3.fromRGB(255, 241, 247), SubText = Color3.fromRGB(201, 157, 178),
        Hover = Color3.fromRGB(77, 48, 65), Click = Color3.fromRGB(86, 53, 73),
        Accent = Color3.fromRGB(255, 105, 180), Accent2 = Color3.fromRGB(177, 117, 255), Success = Color3.fromRGB(73, 219, 157),
        Warn = Color3.fromRGB(255, 198, 91), Error = Color3.fromRGB(255, 86, 107)
    },
    Aurora = {
        Main = Color3.fromRGB(18, 32, 38), Secondary = Color3.fromRGB(23, 40, 47),
        Surface = Color3.fromRGB(29, 49, 57), SurfaceAlt = Color3.fromRGB(36, 59, 67),
        Stroke = Color3.fromRGB(71, 110, 118), Divider = Color3.fromRGB(50, 81, 88),
        Text = Color3.fromRGB(238, 253, 252), SubText = Color3.fromRGB(147, 185, 185),
        Hover = Color3.fromRGB(41, 65, 73), Click = Color3.fromRGB(47, 74, 82),
        Accent = Color3.fromRGB(48, 226, 183), Accent2 = Color3.fromRGB(102, 149, 255), Success = Color3.fromRGB(64, 226, 158),
        Warn = Color3.fromRGB(255, 205, 94), Error = Color3.fromRGB(255, 92, 117)
    },
    Ember = {
        Main = Color3.fromRGB(42, 28, 23), Secondary = Color3.fromRGB(51, 34, 28),
        Surface = Color3.fromRGB(62, 41, 33), SurfaceAlt = Color3.fromRGB(74, 48, 38),
        Stroke = Color3.fromRGB(118, 79, 62), Divider = Color3.fromRGB(90, 59, 48),
        Text = Color3.fromRGB(255, 247, 239), SubText = Color3.fromRGB(201, 169, 146),
        Hover = Color3.fromRGB(80, 52, 41), Click = Color3.fromRGB(91, 59, 46),
        Accent = Color3.fromRGB(255, 132, 72), Accent2 = Color3.fromRGB(255, 83, 129), Accent3 = Color3.fromRGB(255, 202, 102), Success = Color3.fromRGB(87, 220, 153),
        Warn = Color3.fromRGB(255, 201, 87), Error = Color3.fromRGB(255, 83, 99)
    },
    ["Prism Frost"] = {
        Main = Color3.fromRGB(218, 228, 232), Secondary = Color3.fromRGB(230, 238, 241),
        Surface = Color3.fromRGB(242, 246, 248), SurfaceAlt = Color3.fromRGB(250, 252, 253),
        Stroke = Color3.fromRGB(123, 145, 155), Divider = Color3.fromRGB(168, 184, 191),
        Text = Color3.fromRGB(31, 39, 43), SubText = Color3.fromRGB(100, 111, 117),
        Hover = Color3.fromRGB(224, 234, 239), Click = Color3.fromRGB(211, 224, 230),
        Accent = Color3.fromRGB(168, 208, 255), Accent2 = Color3.fromRGB(255, 222, 166), Accent3 = Color3.fromRGB(186, 222, 255),
        Success = Color3.fromRGB(67, 171, 127), Warn = Color3.fromRGB(218, 150, 51), Error = Color3.fromRGB(211, 75, 102)
    },
    ["Moss Archive"] = {
        Main = Color3.fromRGB(31, 40, 42), Secondary = Color3.fromRGB(38, 48, 50),
        Surface = Color3.fromRGB(45, 56, 57), SurfaceAlt = Color3.fromRGB(52, 65, 64),
        Stroke = Color3.fromRGB(96, 111, 96), Divider = Color3.fromRGB(117, 119, 91),
        Text = Color3.fromRGB(236, 235, 222), SubText = Color3.fromRGB(190, 181, 151),
        Hover = Color3.fromRGB(52, 64, 63), Click = Color3.fromRGB(59, 72, 69),
        Accent = Color3.fromRGB(156, 186, 105), Accent2 = Color3.fromRGB(196, 207, 148), Accent3 = Color3.fromRGB(126, 160, 89),
        Success = Color3.fromRGB(113, 196, 128), Warn = Color3.fromRGB(223, 180, 88), Error = Color3.fromRGB(225, 104, 105)
    },
    ["Velvet Latte"] = {
        Main = Color3.fromRGB(27, 28, 45), Secondary = Color3.fromRGB(35, 36, 56),
        Surface = Color3.fromRGB(43, 44, 66), SurfaceAlt = Color3.fromRGB(52, 53, 78),
        Stroke = Color3.fromRGB(101, 105, 143), Divider = Color3.fromRGB(76, 80, 113),
        Text = Color3.fromRGB(232, 236, 255), SubText = Color3.fromRGB(175, 181, 215),
        Hover = Color3.fromRGB(51, 52, 77), Click = Color3.fromRGB(59, 60, 87),
        Accent = Color3.fromRGB(232, 164, 207), Accent2 = Color3.fromRGB(181, 148, 238), Accent3 = Color3.fromRGB(120, 174, 239),
        Success = Color3.fromRGB(120, 207, 157), Warn = Color3.fromRGB(238, 190, 104), Error = Color3.fromRGB(239, 117, 144)
    }
}

-- Registry for dynamic theming
Library.Registry = {}
Library.Scales = {}

-- Global keybinds list
Library.KeybindManager = nil
Library.KeybindList = {}


--[[ MODULE: 05_capabilities.part.lua ]]
-- Module fragment: host capability discovery and safe adapters
-- Optional executor functions are captured once and never called directly by UI modules.

local Capabilities = {
    Functions = {},
    Failures = {}
}

local function captureCapability(name, resolver)
    local ok, value = pcall(resolver)
    if ok and type(value) == "function" then
        Capabilities.Functions[name] = value
        return value
    end
    return nil
end

captureCapability("loadstring", function() return loadstring end)
captureCapability("request", function() return request end)
captureCapability("request", function() return http_request end)
captureCapability("request", function() return syn and syn.request end)
captureCapability("request", function() return http and http.request end)
captureCapability("gethui", function() return gethui end)
captureCapability("protectGui", function() return syn and syn.protect_gui end)
captureCapability("setclipboard", function() return setclipboard end)
captureCapability("setclipboard", function() return toclipboard end)
captureCapability("isfolder", function() return isfolder end)
captureCapability("makefolder", function() return makefolder end)
captureCapability("isfile", function() return isfile end)
captureCapability("readfile", function() return readfile end)
captureCapability("writefile", function() return writefile end)
captureCapability("delfile", function() return delfile end)
captureCapability("listfiles", function() return listfiles end)

function Capabilities:Has(name)
    return type(self.Functions[name]) == "function"
end

function Capabilities:Call(name, ...)
    local fn = self.Functions[name]
    if type(fn) ~= "function" then
        return false, name .. " is unavailable"
    end
    return pcall(fn, ...)
end

function Capabilities:Disable(name, reason)
    self.Functions[name] = nil
    self.Failures[name] = tostring(reason or "capability failed")
end

function Capabilities:HttpGet(url)
    local gameOk, gameResult = pcall(function()
        return game:HttpGet(url)
    end)
    if gameOk and type(gameResult) == "string" and gameResult ~= "" then
        return true, gameResult
    end

    local requestFn = self.Functions.request
    if type(requestFn) == "function" then
        local requestOk, response = pcall(requestFn, {Url = url, Method = "GET"})
        if requestOk and type(response) == "table" then
            local status = response.StatusCode or response.Status or response.status_code
            local body = response.Body or response.body
            if (status == nil or (tonumber(status) and tonumber(status) >= 200 and tonumber(status) < 300))
                and type(body) == "string" then
                return true, body
            end
            return false, "request returned status " .. tostring(status)
        end
        self:Disable("request", response)
    end

    return false, gameOk and "HTTP returned an empty response" or gameResult
end

function Capabilities:Compile(source)
    local compiler = self.Functions.loadstring
    if type(compiler) ~= "function" then
        return false, "loadstring is unavailable"
    end
    local callOk, chunk, compileError = pcall(compiler, source)
    if not callOk then return false, chunk end
    if type(chunk) ~= "function" then return false, compileError or "compiler returned no function" end
    return true, chunk
end

function Capabilities:SetClipboard(text)
    local ok, result = self:Call("setclipboard", tostring(text or ""))
    if not ok then self.Failures.setclipboard = tostring(result) end
    return ok, result
end

function Capabilities:GetGuiParent()
    local getHui = self.Functions.gethui
    if type(getHui) == "function" then
        local ok, result = pcall(getHui)
        if ok and result then return result end
        self:Disable("gethui", result)
    end
    if CoreGui then return CoreGui end
    return Plr and Plr:FindFirstChildOfClass("PlayerGui") or nil
end

function Capabilities:ProtectGui(gui)
    local protect = self.Functions.protectGui
    if type(protect) ~= "function" then return false end
    return pcall(protect, gui)
end

function Capabilities:GetReport()
    local report = {}
    for name in pairs(self.Functions) do report[name] = true end
    for name, reason in pairs(self.Failures) do report[name] = reason end
    return report
end

Library.Capabilities = Capabilities


--[[ MODULE: 10_utility.part.lua ]]
-- Module fragment: utility, assets, animation, responsive helpers
-- Generated from the working V7 baseline; edit this feature in isolation.
--// MODULE: UTILITY (extended)
local Utility = {}

function Library:Connect(signal, callback)
    local connection = signal:Connect(callback)
    table.insert(self.Connections, connection)
    return connection
end

function Utility:SafeCall(callback, ...)
    if type(callback) ~= "function" then return true end
    local args = table.pack(...)
    local ok, err = xpcall(function()
        callback(table.unpack(args, 1, args.n))
    end, debug.traceback)
    if not ok then
        warn("[RenLib] Callback error:\n" .. tostring(err))
        if Library.Notify and not Library.Unloaded then
            Library:Notify({Title = "Callback error", Content = tostring(err):match("^[^\n]+") or "Unknown error", Duration = 5})
        end
    end
    return ok, err
end

function Utility:RandomString(length)
    local chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
    local result = ""
    for i = 1, length do
        local rand = math.random(1, #chars)
        result = result .. chars:sub(rand, rand)
    end
    return result
end

function Utility:NormalizeAssetId(asset, fallback)
    if asset == nil or asset == "" then return fallback end
    local value = tostring(asset)
    if value:match("^%d+$") then
        if tonumber(value) <= 0 then return fallback end
        return "rbxassetid://" .. value
    end
    if value:match("^rbxassetid://%d+$") or value:match("^https?://") then
        return value
    end
    return fallback
end

local THEME_PROPERTY_KEYS = {
    BackgroundColor3 = {"Main", "Secondary", "Surface", "SurfaceAlt", "Hover", "Click", "Accent", "Accent2", "Accent3", "Success", "Warn", "Error", "Divider"},
    TextColor3 = {"Text", "SubText", "Accent", "Accent2", "Accent3", "Success", "Warn", "Error"},
    PlaceholderColor3 = {"SubText", "Text"},
    ImageColor3 = {"Text", "SubText", "Accent", "Accent2", "Accent3", "Success", "Warn", "Error"},
    ScrollBarImageColor3 = {"Accent", "Accent2", "SubText", "Text"},
    Color = {"Stroke", "Divider", "Accent", "Accent2", "Accent3", "Text", "SubText"}
}

local function resolveThemeKey(property, value)
    if typeof(value) ~= "Color3" then return nil end
    for _, key in ipairs(THEME_PROPERTY_KEYS[property] or {}) do
        if Library.Theme[key] == value then return key end
    end
    return nil
end

function Utility:Create(class, properties)
    local instance = Instance.new(class)
    if class == "UIStroke" and properties.Transparency == nil then
        instance.Transparency = 0.56
    end
    for k, v in pairs(properties) do
        if k ~= "Parent" then
            instance[k] = v
        end
    end
    -- Theme registration is automatic for semantic theme colors. Explicit
    -- RegisterProperty calls still override this, but missed labels can no
    -- longer keep a stale color after a preset change.
    for property, value in pairs(properties) do
        local colorKey = resolveThemeKey(property, value)
        if colorKey then
            Library.Registry[instance] = Library.Registry[instance] or {}
            Library.Registry[instance][property] = colorKey
        end
    end
    if properties.Parent then
        instance.Parent = properties.Parent
    end
    return instance
end

function Utility:LoadBrandIcon(callback)
    task.spawn(function()
        local resolved = Utility:NormalizeAssetId(BRAND_ICON_ASSET_ID, BRAND_ICON_FALLBACK)
        local preloadOk = pcall(function()
            ContentProvider:PreloadAsync({resolved})
        end)
        if not preloadOk then
            resolved = BRAND_ICON_FALLBACK
        end
        Library.BrandIcon = resolved
        Library.BrandIconTint = nil
        for mark in pairs(Library.BrandMarks) do
            local markOk = pcall(function()
                if mark and mark.Parent then
                    mark.Image = resolved
                    if Library.Registry[mark] then Library.Registry[mark].ImageColor3 = nil end
                    mark.ImageColor3 = Color3.new(1, 1, 1)
                end
            end)
            if not markOk or not mark or not mark.Parent then Library.BrandMarks[mark] = nil end
        end
        if callback then Utility:SafeCall(callback, resolved) end
    end)
end

function Library:SetBrandIcon(asset)
    local resolved = Utility:NormalizeAssetId(asset)
    if not resolved then return false, "Invalid icon asset" end
    BRAND_ICON_ASSET_ID = resolved
    Utility:LoadBrandIcon()
    return true
end

function Utility:Tween(instance, info, properties, callback)
    if not instance or not instance.Parent then return nil end
    local previous = Library.ActiveTweens[instance]
    if previous then
        pcall(function() previous:Cancel() end)
        Library.ActiveTweens[instance] = nil
    end

    local duration = Library.ReducedMotion and 0 or math.max(0, info.Time * Library.MotionScale)
    if duration == 0 then
        for property, value in pairs(properties) do
            instance[property] = value
        end
        if callback then task.defer(callback) end
        return nil
    end

    local tweenInfo = TweenInfo.new(duration, info.EasingStyle, info.EasingDirection, info.RepeatCount, info.Reverses, info.DelayTime)
    local tween = TweenService:Create(instance, tweenInfo, properties)
    Library.ActiveTweens[instance] = tween
    tween:Play()
    Library:Connect(tween.Completed, function(playbackState)
        if Library.ActiveTweens[instance] == tween then
            Library.ActiveTweens[instance] = nil
        end
        if callback and playbackState == Enum.PlaybackState.Completed then callback() end
    end)
    return tween
end

function Utility:StopTween(instance)
    local tween = instance and Library.ActiveTweens[instance]
    if not tween then return false end
    Library.ActiveTweens[instance] = nil
    pcall(function() tween:Cancel() end)
    return true
end

-- Geometry and visual-state animations must not cancel one another. A hover
-- color tween used to stop an in-flight sidebar resize tween, leaving active
-- tabs and profile cards permanently stuck in their compact geometry.
function Utility:TweenLayout(instance, info, properties, callback)
    if not instance or not instance.Parent then return nil end
    local previous = Library.LayoutTweens[instance]
    if previous then
        pcall(function() previous:Cancel() end)
        Library.LayoutTweens[instance] = nil
    end

    local duration = Library.ReducedMotion and 0 or math.max(0, info.Time * Library.MotionScale)
    if duration == 0 then
        for property, value in pairs(properties) do instance[property] = value end
        if callback then task.defer(callback) end
        return nil
    end

    local tweenInfo = TweenInfo.new(duration, info.EasingStyle, info.EasingDirection, info.RepeatCount, info.Reverses, info.DelayTime)
    local tween = TweenService:Create(instance, tweenInfo, properties)
    Library.LayoutTweens[instance] = tween
    tween:Play()
    Library:Connect(tween.Completed, function(playbackState)
        if Library.LayoutTweens[instance] == tween then Library.LayoutTweens[instance] = nil end
        if callback and playbackState == Enum.PlaybackState.Completed then callback() end
    end)
    return tween
end

function Utility:StopLayoutTween(instance)
    local tween = instance and Library.LayoutTweens[instance]
    if not tween then return false end
    Library.LayoutTweens[instance] = nil
    pcall(function() tween:Cancel() end)
    return true
end

function Utility:TweenVisibility(instance, info, properties, callback)
    if not instance or not instance.Parent then return nil end
    local previous = Library.VisibilityTweens[instance]
    if previous then
        pcall(function() previous:Cancel() end)
        Library.VisibilityTweens[instance] = nil
    end
    local duration = Library.ReducedMotion and 0 or math.max(0, info.Time * Library.MotionScale)
    if duration == 0 then
        for property, value in pairs(properties) do instance[property] = value end
        if callback then task.defer(callback) end
        return nil
    end
    local tweenInfo = TweenInfo.new(duration, info.EasingStyle, info.EasingDirection, info.RepeatCount, info.Reverses, info.DelayTime)
    local tween = TweenService:Create(instance, tweenInfo, properties)
    Library.VisibilityTweens[instance] = tween
    tween:Play()
    Library:Connect(tween.Completed, function(playbackState)
        if Library.VisibilityTweens[instance] == tween then Library.VisibilityTweens[instance] = nil end
        if callback and playbackState == Enum.PlaybackState.Completed then callback() end
    end)
    return tween
end

function Utility:StopVisibilityTween(instance)
    local tween = instance and Library.VisibilityTweens[instance]
    if not tween then return false end
    Library.VisibilityTweens[instance] = nil
    pcall(function() tween:Cancel() end)
    return true
end

function Utility:MakeDraggable(topbar, object)
    local dragging, dragInput, dragStart, startPos
    local dragState = {Moved = false}

    function dragState:ConsumeDrag()
        local moved = self.Moved
        self.Moved = false
        return moved
    end

    local function keepRecoverable()
        if not object or not object.Parent then return end
        local viewport = getViewport()
        local position = object.AbsolutePosition
        local size = object.AbsoluteSize
        local minimumVisible = math.min(52, math.max(28, viewport.X * 0.12))
        local deltaX, deltaY = 0, 0
        if position.X + size.X < minimumVisible then
            deltaX = minimumVisible - (position.X + size.X)
        elseif position.X > viewport.X - minimumVisible then
            deltaX = (viewport.X - minimumVisible) - position.X
        end
        if position.Y + 40 < 0 then
            deltaY = -(position.Y + 40)
        elseif position.Y > viewport.Y - minimumVisible then
            deltaY = (viewport.Y - minimumVisible) - position.Y
        end
        if deltaX ~= 0 or deltaY ~= 0 then
            local scale = math.max(0.01, Library.DPIScale)
            object.Position = UDim2.new(
                object.Position.X.Scale,
                object.Position.X.Offset + deltaX / scale,
                object.Position.Y.Scale,
                object.Position.Y.Offset + deltaY / scale
            )
        end
    end

    Library:Connect(topbar.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragState.Moved = false
            dragStart = Vector2.new(input.Position.X, input.Position.Y)
            startPos = object.Position
            dragInput = input.UserInputType == Enum.UserInputType.Touch and input or nil

            Library:Connect(input.Changed, function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                    task.defer(keepRecoverable)
                end
            end)
        end
    end)

    Library:Connect(topbar.InputChanged, function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)

    Library:Connect(UserInputService.InputChanged, function(input)
        local isPointerMove = input.UserInputType == Enum.UserInputType.MouseMovement
            or (input.UserInputType == Enum.UserInputType.Touch and input == dragInput)
        if dragging and isPointerMove then
            local pointer = Vector2.new(input.Position.X, input.Position.Y)
            local delta = (pointer - dragStart) / math.max(0.01, Library.DPIScale)
            if delta.Magnitude >= 4 then dragState.Moved = true end
            object.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end
    end)
    return dragState
end

function Utility:GetColor(colorKey)
    if type(colorKey) == "string" then
        return Library.Theme[colorKey] or Color3.new(1,1,1)
    end
    return colorKey
end

function Utility:RegisterProperty(instance, property, colorKey)
    if not Library.Registry[instance] then
        Library.Registry[instance] = {}
    end
    Library.Registry[instance][property] = colorKey
    instance[property] = Utility:GetColor(colorKey)
end

local function buildGradient(keys)
    local points = {}
    local count = math.max(#keys, 2)
    for index, key in ipairs(keys) do
        table.insert(points, ColorSequenceKeypoint.new((index - 1) / (count - 1), Utility:GetColor(key)))
    end
    if #points == 1 then
        table.insert(points, ColorSequenceKeypoint.new(1, points[1].Value))
    end
    return ColorSequence.new(points)
end

function Utility:RegisterGradient(instance, ...)
    local keys = {...}
    Library.GradientRegistry[instance] = keys
    instance.Color = buildGradient(keys)
end

function Utility:RegisterMaterial(instance, frostedTransparency, solidTransparency, property)
    property = property or "BackgroundTransparency"
    Library.MaterialRegistry[instance] = {
        Frosted = math.clamp(tonumber(frostedTransparency) or 0.18, 0, 1),
        Solid = math.clamp(tonumber(solidTransparency) or instance[property] or 0, 0, 1),
        Property = property
    }
    local state = Library.MaterialRegistry[instance]
    instance[property] = Library:ResolveMaterialTransparency(state)
end


--[[ MODULE: 20_theme.part.lua ]]
-- Module fragment: themes and material system
-- Generated from the working V7 baseline; edit this feature in isolation.
--// DYNAMIC THEME UPDATE
function Library:UpdateColors()
    for instance, props in pairs(self.Registry) do
        for prop, colorKey in pairs(props) do
            pcall(function()
                instance[prop] = Utility:GetColor(colorKey)
            end)
        end
    end
    for gradient, keys in pairs(self.GradientRegistry) do
        pcall(function()
            gradient.Color = buildGradient(keys)
        end)
    end
end

function Library:SetTheme(newTheme)
    if type(newTheme) ~= "table" then return false, "Theme must be a table" end
    local merged = {}
    for key, value in pairs(self.Theme) do merged[key] = value end
    for key, value in pairs(newTheme) do
        if typeof(value) == "Color3" then merged[key] = value end
    end
    if typeof(newTheme.Accent2) ~= "Color3" and typeof(newTheme.Accent) == "Color3" then
        merged.Accent2 = newTheme.Accent
    end
    if typeof(newTheme.Accent3) ~= "Color3" then
        merged.Accent3 = merged.Accent2 or merged.Accent
    end
    for key, value in pairs(merged) do self.Theme[key] = value end
    self:UpdateColors()
    self:SetMaterialIntensity(self.MaterialIntensity)
    if self.Window and self.Window.RefreshThemeState then self.Window:RefreshThemeState() end
    return true
end

function Library:ApplyThemePreset(name)
    if name == "Starlight" then name = "Celestial" end -- V6.2 compatibility alias
    local preset = self.ThemePresets[name]
    if not preset then
        return false, "Unknown theme preset: " .. tostring(name)
    end
    self:SetTheme(preset)
    self.ActiveTheme = name
    return true
end

function Library:SetReducedMotion(enabled)
    self.ReducedMotion = enabled == true
end

function Library:SetMotionScale(scale)
    self.MotionScale = math.clamp(tonumber(scale) or 1, 0, 2)
end

function Library:GetThemeLuminance()
    local color = self.Theme.Main
    return color.R * 0.2126 + color.G * 0.7152 + color.B * 0.0722
end

function Library:ResolveMaterialTransparency(state)
    if not state then return 0 end
    if self.MaterialMode ~= "Frosted" then return state.Solid end
    local transparencyBoost = (self.MaterialIntensity / 32) * 0.24
    if self:GetThemeLuminance() < 0.35 then transparencyBoost = transparencyBoost + 0.08 end
    return math.clamp(state.Frosted + transparencyBoost, 0, 0.84)
end

function Library:SetMaterialIntensity(value)
    self.MaterialIntensity = math.clamp(tonumber(value) or 18, 0, 32)
    if self.MaterialMode == "Frosted" then
        for instance, state in pairs(self.MaterialRegistry) do
            pcall(function()
                instance[state.Property or "BackgroundTransparency"] = self:ResolveMaterialTransparency(state)
            end)
        end
    end
    return self.MaterialIntensity
end

function Library:RefreshMaterialVisibility()
    local visible = self.MaterialMode == "Frosted" and not self.Unloaded and not self.IsMinimized
    for decoration in pairs(self.MaterialDecorations) do
        pcall(function() decoration.Visible = visible end)
    end
end

function Library:SetMaterialMode(mode)
    mode = tostring(mode or "Solid")
    if mode ~= "Solid" and mode ~= "Frosted" then
        return false, "Unknown material mode: " .. mode
    end
    self.MaterialMode = mode
    for instance, state in pairs(self.MaterialRegistry) do
        pcall(function()
            local property = state.Property or "BackgroundTransparency"
            Utility:Tween(instance, TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                [property] = self:ResolveMaterialTransparency(state)
            })
        end)
    end
    self:RefreshMaterialVisibility()
    return true
end


--[[ MODULE: 30_scaling.part.lua ]]
-- Module fragment: DPI and scale preview
-- Generated from the working V7 baseline; edit this feature in isolation.
--// DPI SCALING
function Library:SetDPIScale(percent)
    percent = math.clamp(tonumber(percent) or 100, 100, 150)
    local scale = percent / 100
    for _, uiScale in ipairs(self.Scales) do
        uiScale.Scale = scale
    end
    self.DPIScale = scale
    if self.Window and self.Window.ApplyResponsiveLayout then
        task.defer(function()
            RunService.RenderStepped:Wait()
            if self.Window and not self.Unloaded then
                self.Window:ApplyResponsiveLayout(true)
                task.defer(function()
                    if self.Window and not self.Unloaded then self.Window:ApplyResponsiveLayout(false) end
                end)
            end
        end)
    end
    return percent
end

function Library:KeepDPIScale(token)
    local preview = self.ScalePreview
    if not preview or (token and preview.Token ~= token) then return false end
    preview.Kept = true
    self.ScalePreview = nil
    return true
end

function Library:RevertDPIScale(token)
    local preview = self.ScalePreview
    if not preview or (token and preview.Token ~= token) then return false end
    self.ScalePreview = nil
    self:SetDPIScale(preview.OriginalPercent)
    self.Flags.__RenLibScale = preview.OriginalPercent
    local scaleOption = self.Options.__RenLibScale
    if scaleOption and scaleOption.SetSilent then scaleOption:SetSilent(preview.OriginalPercent) end
    return true
end

function Library:PreviewDPIScale(percent, timeout)
    timeout = math.clamp(tonumber(timeout) or 10, 5, 30)
    local activePreview = self.ScalePreview
    local originalPercent = activePreview and activePreview.OriginalPercent or math.floor(self.DPIScale * 100 + 0.5)
    local token = Utility:RandomString(12)
    local candidate = self:SetDPIScale(percent)
    self.Flags.__RenLibScale = candidate
    self.ScalePreview = {
        Token = token,
        OriginalPercent = originalPercent,
        CandidatePercent = candidate,
        Kept = false
    }

    if self.Notify then
        self:Notify({
            Title = "Keep this UI size?",
            Content = tostring(candidate) .. "% preview. It will reset in " .. tostring(timeout) .. " seconds unless you keep it.",
            Duration = timeout,
            Actions = {
                {Name = "Keep", Callback = function()
                    if self:KeepDPIScale(token) and self.Notify then
                        self:Notify({Title = "UI size kept", Content = tostring(candidate) .. "%", Duration = 2})
                    end
                end},
                {Name = "Revert", Callback = function()
                    if self:RevertDPIScale(token) and self.Notify then
                        self:Notify({Title = "UI size restored", Content = tostring(originalPercent) .. "%", Duration = 2})
                    end
                end}
            }
        })
    end

    task.delay(timeout, function()
        local preview = self.ScalePreview
        if preview and preview.Token == token and not preview.Kept then
            self:RevertDPIScale(token)
            if self.Notify and not self.Unloaded then
                self:Notify({Title = "UI size restored", Content = "The preview timed out safely.", Duration = 3})
            end
        end
    end)
    return token
end


--[[ MODULE: 40_storage.part.lua ]]
-- Module fragment: config storage and autoload
-- Disk persistence is preferred, with a transparent session-memory fallback.

local MEMORY_STORAGE_KEY = "__RENLIB_V8_MEMORY_STORAGE"
local AUTOLOAD_PATH = "RenLib/autoload.txt"

local virtualReadOk, VirtualStorage = pcall(function()
    return RuntimeEnvironment[MEMORY_STORAGE_KEY]
end)
if not virtualReadOk then VirtualStorage = nil end
if type(VirtualStorage) ~= "table" then
    VirtualStorage = {Configs = {}, Autoload = nil}
    pcall(function() RuntimeEnvironment[MEMORY_STORAGE_KEY] = VirtualStorage end)
end
if type(VirtualStorage.Configs) ~= "table" then VirtualStorage.Configs = {} end

local Storage = {
    Mode = "Memory",
    Persistent = false,
    LastError = nil,
    Initialized = false,
    WarningShown = false
}

local function cleanConfigName(name)
    local cleaned = tostring(name or "default"):gsub("[^%w_%-%s]", ""):sub(1, 64)
    cleaned = cleaned:match("^%s*(.-)%s*$") or ""
    return cleaned ~= "" and cleaned or "default"
end

local CONFIG_MANAGER_FLAGS = {
    __RenLibConfigSelection = true,
    __RenLibConfigName = true,
    __RenLibConfigRename = true
}

local function encodeValue(value)
    if typeof(value) == "Color3" then
        return {__type = "Color3", r = value.R, g = value.G, b = value.B}
    elseif type(value) == "table" then
        local encoded = {}
        for key, item in pairs(value) do encoded[key] = encodeValue(item) end
        return encoded
    end
    return value
end

local function decodeValue(value)
    if type(value) == "table" and value.__type == "Color3" then
        return Color3.new(value.r or 1, value.g or 1, value.b or 1)
    elseif type(value) == "table" then
        local decoded = {}
        for key, item in pairs(value) do decoded[key] = decodeValue(item) end
        return decoded
    end
    return value
end

local function copyPayload(payload)
    if type(payload) ~= "table" then return payload end
    local copied = {}
    for key, value in pairs(payload) do
        copied[key] = type(value) == "table" and copyPayload(value) or value
    end
    return copied
end

function Storage:UseMemory(reason)
    self.Mode = "Memory"
    self.Persistent = false
    self.LastError = reason and tostring(reason) or self.LastError
    Library.StorageMode = self.Mode
    Library.PersistenceAvailable = false
    if self.LastError and not self.WarningShown then
        self.WarningShown = true
        warn("[RenLib] Persistent config storage unavailable; using session memory: " .. self.LastError)
    end
    return true
end

function Storage:Initialize()
    if self.Initialized then return true end
    self.Initialized = true

    local required = {"isfolder", "makefolder", "isfile", "readfile", "writefile"}
    for _, name in ipairs(required) do
        if not Capabilities:Has(name) then
            return self:UseMemory(name .. " is unavailable")
        end
    end

    local ok, failure = pcall(function()
        local rootOk, rootExists = Capabilities:Call("isfolder", "RenLib")
        if not rootOk then error(rootExists) end
        if not rootExists then
            local makeOk, makeError = Capabilities:Call("makefolder", "RenLib")
            if not makeOk then error(makeError) end
        end

        local folderOk, folderExists = Capabilities:Call("isfolder", CONFIG_FOLDER)
        if not folderOk then error(folderExists) end
        if not folderExists then
            local makeOk, makeError = Capabilities:Call("makefolder", CONFIG_FOLDER)
            if not makeOk then error(makeError) end
        end
    end)

    if not ok then return self:UseMemory(failure) end
    self.Mode = "File"
    self.Persistent = true
    self.LastError = nil
    Library.StorageMode = self.Mode
    Library.PersistenceAvailable = true
    return true
end

function Storage:Save(name, payload)
    self:Initialize()
    local cleaned = cleanConfigName(name)
    VirtualStorage.Configs[cleaned] = copyPayload(payload)

    if self.Mode == "File" then
        local encodedOk, encoded = pcall(function() return HttpService:JSONEncode(payload) end)
        if not encodedOk then return false, encoded end
        local writeOk, writeError = Capabilities:Call("writefile", CONFIG_FOLDER .. "/" .. cleaned .. ".json", encoded)
        if not writeOk then self:UseMemory(writeError) end
    end
    return true, self.Mode == "Memory" and "Saved for this session" or nil
end

function Storage:Load(name)
    self:Initialize()
    local cleaned = cleanConfigName(name)
    if self.Mode == "File" then
        local path = CONFIG_FOLDER .. "/" .. cleaned .. ".json"
        local existsOk, exists = Capabilities:Call("isfile", path)
        if not existsOk then
            self:UseMemory(exists)
        elseif exists then
            local readOk, contents = Capabilities:Call("readfile", path)
            if readOk then
                local decodeOk, payload = pcall(function() return HttpService:JSONDecode(contents) end)
                if decodeOk and type(payload) == "table" then
                    VirtualStorage.Configs[cleaned] = copyPayload(payload)
                    return true, payload
                end
                return false, payload
            end
            self:UseMemory(contents)
        end
    end

    local payload = VirtualStorage.Configs[cleaned]
    if type(payload) ~= "table" then return false, "Config does not exist" end
    return true, copyPayload(payload)
end

function Storage:List()
    self:Initialize()
    local names, seen = {}, {}
    local function add(name)
        name = cleanConfigName(name)
        local key = name:lower()
        if not seen[key] then
            seen[key] = true
            table.insert(names, name)
        end
    end

    for name in pairs(VirtualStorage.Configs) do add(name) end
    for name in pairs(Library.KnownConfigs) do add(name) end

    if self.Mode == "File" and Capabilities:Has("listfiles") then
        local listOk, files = Capabilities:Call("listfiles", CONFIG_FOLDER)
        if listOk and type(files) == "table" then
            for _, path in ipairs(files) do
                local normalized = tostring(path):gsub("\\", "/")
                local name = normalized:match("/([^/]+)%.json$") or normalized:match("^([^/]+)%.json$")
                if name then add(name) end
            end
        elseif not listOk then
            Capabilities:Disable("listfiles", files)
        end
    end

    table.sort(names, function(a, b) return a:lower() < b:lower() end)
    return names
end

function Storage:Delete(name)
    self:Initialize()
    local cleaned = cleanConfigName(name)
    local existedInMemory = VirtualStorage.Configs[cleaned] ~= nil
    VirtualStorage.Configs[cleaned] = nil

    if self.Mode == "File" then
        local path = CONFIG_FOLDER .. "/" .. cleaned .. ".json"
        local existsOk, exists = Capabilities:Call("isfile", path)
        if not existsOk then
            self:UseMemory(exists)
        elseif exists then
            if not Capabilities:Has("delfile") then
                return false, "delfile is unavailable"
            end
            local deleteOk, deleteError = Capabilities:Call("delfile", path)
            if not deleteOk then return false, deleteError end
            return true
        elseif not existedInMemory then
            return false, "Config does not exist"
        end
    elseif not existedInMemory then
        return false, "Config does not exist"
    end
    return true
end

function Storage:Rename(oldName, newName)
    local oldClean, newClean = cleanConfigName(oldName), cleanConfigName(newName)
    if oldClean == newClean then return true end
    local loadOk, payload = self:Load(oldClean)
    if not loadOk then return false, payload end
    local duplicateOk = self:Load(newClean)
    if duplicateOk then return false, "A config already uses that name" end
    local saveOk, saveError = self:Save(newClean, payload)
    if not saveOk then return false, saveError end
    local deleteOk, deleteError = self:Delete(oldClean)
    if not deleteOk then return false, deleteError end
    return true
end

function Storage:GetAutoload()
    self:Initialize()
    if self.Mode == "File" then
        local existsOk, exists = Capabilities:Call("isfile", AUTOLOAD_PATH)
        if existsOk and exists then
            local readOk, name = Capabilities:Call("readfile", AUTOLOAD_PATH)
            if readOk then
                name = tostring(name or ""):match("^%s*(.-)%s*$")
                if name and name ~= "" then
                    VirtualStorage.Autoload = cleanConfigName(name)
                    return VirtualStorage.Autoload
                end
            else
                self:UseMemory(name)
            end
        elseif not existsOk then
            self:UseMemory(exists)
        end
    end
    return VirtualStorage.Autoload and cleanConfigName(VirtualStorage.Autoload) or nil
end

function Storage:SetAutoload(name)
    local cleaned = cleanConfigName(name)
    local exists = self:Load(cleaned)
    if not exists then return false, "Config does not exist" end
    VirtualStorage.Autoload = cleaned
    if self.Mode == "File" then
        local writeOk, writeError = Capabilities:Call("writefile", AUTOLOAD_PATH, cleaned)
        if not writeOk then self:UseMemory(writeError) end
    end
    return true, self.Mode == "Memory" and "Autoload applies for this session" or nil
end

function Storage:ClearAutoload()
    self:Initialize()
    VirtualStorage.Autoload = nil
    if self.Mode == "File" then
        local existsOk, exists = Capabilities:Call("isfile", AUTOLOAD_PATH)
        if not existsOk then
            self:UseMemory(exists)
        elseif exists then
            if Capabilities:Has("delfile") then
                local deleteOk, deleteError = Capabilities:Call("delfile", AUTOLOAD_PATH)
                if not deleteOk then return false, deleteError end
            else
                local clearOk, clearError = Capabilities:Call("writefile", AUTOLOAD_PATH, "")
                if not clearOk then return false, clearError end
            end
        end
    end
    return true
end

Library.Storage = Storage
Library.StorageMode = "Memory"
Library.PersistenceAvailable = false

local function ensureConfigFolders()
    return Storage:Initialize()
end

function Library:SaveConfig(name)
    local payload = {version = self.Version, flags = {}}
    for flag, value in pairs(self.Flags) do
        if not CONFIG_MANAGER_FLAGS[flag] then payload.flags[flag] = encodeValue(value) end
    end
    local cleaned = cleanConfigName(name)
    local ok, result = Storage:Save(cleaned, payload)
    if ok then self.KnownConfigs[cleaned] = true end
    return ok, result
end

function Library:GetConfigList()
    return Storage:List()
end

function Library:LoadConfig(name)
    local cleaned = cleanConfigName(name)
    local ok, payload = Storage:Load(cleaned)
    if not ok or type(payload) ~= "table" then return false, payload end
    self.KnownConfigs[cleaned] = true
    for flag, rawValue in pairs(payload.flags or {}) do
        local value = decodeValue(rawValue)
        self.Flags[flag] = value
        local option = self.Options[flag]
        if option and option.Set then Utility:SafeCall(function() option:Set(value) end) end
    end
    return true
end

function Library:DeleteConfig(name)
    local cleaned = cleanConfigName(name)
    local ok, err = Storage:Delete(cleaned)
    if not ok then return false, err end
    self.KnownConfigs[cleaned] = nil
    if self:GetAutoloadConfigName() == cleaned then
        local cleared, clearError = self:ClearAutoloadConfig()
        if not cleared then return false, "Config deleted, but autoload cleanup failed: " .. tostring(clearError) end
    end
    return true
end

function Library:RenameConfig(oldName, newName)
    local oldClean, newClean = cleanConfigName(oldName), cleanConfigName(newName)
    local ok, err = Storage:Rename(oldClean, newClean)
    if not ok then return false, err end
    self.KnownConfigs[oldClean] = nil
    self.KnownConfigs[newClean] = true
    if self:GetAutoloadConfigName() == oldClean then
        local updated, updateError = self:SetAutoloadConfig(newClean)
        if not updated then return false, "Config renamed, but autoload update failed: " .. tostring(updateError) end
    end
    return true
end

function Library:GetAutoloadConfigName()
    return Storage:GetAutoload()
end

function Library:SetAutoloadConfig(name)
    local ok, err = Storage:SetAutoload(name)
    if ok then self.AutoloadConfigName = cleanConfigName(name) end
    return ok, err
end

function Library:ClearAutoloadConfig()
    local ok, err = Storage:ClearAutoload()
    if ok then
        self.AutoloadConfigName = nil
        self.AutoloadThemeName = nil
    end
    return ok, err
end

function Library:PrepareAutoloadConfig()
    self.AutoloadThemeName = nil
    local name = self:GetAutoloadConfigName()
    if not name then return false, "No autoload config" end
    local ok, payload = Storage:Load(name)
    if not ok or type(payload) ~= "table" then
        self:ClearAutoloadConfig()
        return false, payload or "Autoload config no longer exists"
    end
    self.AutoloadConfigName = name
    self.KnownConfigs[name] = true
    self.PendingAutoloadFlags = {}
    for flag, rawValue in pairs(payload.flags or {}) do
        local value = decodeValue(rawValue)
        self.PendingAutoloadFlags[flag] = value
        self.Flags[flag] = value
    end
    local preset = self.PendingAutoloadFlags.__RenLibTheme
    if type(preset) == "string" and self.ThemePresets[preset] then
        self.AutoloadThemeName = preset
        self:ApplyThemePreset(preset)
    end
    local material = self.PendingAutoloadFlags.__RenLibMaterial
    if material == "Solid" or material == "Frosted" then self:SetMaterialMode(material) end
    if self.PendingAutoloadFlags.__RenLibFrostIntensity ~= nil then
        self:SetMaterialIntensity(self.PendingAutoloadFlags.__RenLibFrostIntensity)
    end
    if self.PendingAutoloadFlags.__RenLibReducedMotion ~= nil then
        self:SetReducedMotion(self.PendingAutoloadFlags.__RenLibReducedMotion)
    end
    if self.PendingAutoloadFlags.__RenLibScale ~= nil then
        self:SetDPIScale(self.PendingAutoloadFlags.__RenLibScale)
    end
    self.PendingAutoloadFlags.__RenLibTheme = nil
    self.PendingAutoloadFlags.__RenLibMaterial = nil
    self.PendingAutoloadFlags.__RenLibFrostIntensity = nil
    self.PendingAutoloadFlags.__RenLibReducedMotion = nil
    self.PendingAutoloadFlags.__RenLibScale = nil
    return true
end

--[[ MODULE: 50_extensions.part.lua ]]
-- Module fragment: options, icons, addons, relaunch helpers
-- Generated from the working V7 baseline; edit this feature in isolation.
local function cloneFeatureValue(value)
    if type(value) ~= "table" then return value end
    local cloned = {}
    for key, item in pairs(value) do cloned[key] = cloneFeatureValue(item) end
    return cloned
end

function Library:RegisterOption(flag, controller, defaultValue)
    self.Options[flag] = controller
    controller.Flag = flag
    controller.Default = cloneFeatureValue(defaultValue)
    function controller:Reset()
        if self.Default == nil or type(self.Set) ~= "function" then
            return false, "This feature has no reset value"
        end
        self:Set(cloneFeatureValue(self.Default))
        return true
    end
    if self.PendingAutoloadFlags[flag] ~= nil and controller and controller.Set then
        local value = self.PendingAutoloadFlags[flag]
        self.PendingAutoloadFlags[flag] = nil
        task.defer(function()
            if not self.Unloaded and self.Options[flag] == controller then
                Utility:SafeCall(function() controller:Set(value) end)
            end
        end)
    end
    return controller
end

function Library:ResetFeature(flag)
    local controller = self.Options[flag]
    if not controller then return false, "Unknown feature: " .. tostring(flag) end
    if type(controller.Reset) ~= "function" then return false, "Feature cannot be reset" end
    return controller:Reset()
end

function Library:ResetFeatures(flags)
    local reset, failures = {}, {}
    local requested = flags
    if type(requested) ~= "table" then
        requested = {}
        for flag in pairs(self.Options) do table.insert(requested, flag) end
    end
    for key, value in pairs(requested) do
        local flag = type(key) == "number" and value or key
        if value ~= false then
            local ok, err = self:ResetFeature(flag)
            if ok then table.insert(reset, flag) else failures[flag] = err end
        end
    end
    return next(failures) == nil, reset, failures
end

function Library:RegisterWorkflowPreset(name, definition)
    assert(type(definition) == "table", "[RenLib] RegisterWorkflowPreset requires a table")
    local key = tostring(name or definition.Name or ""):match("^%s*(.-)%s*$")
    assert(key ~= "", "[RenLib] RegisterWorkflowPreset requires a name")
    definition.Name = definition.Name or key
    self.WorkflowPresets[key] = definition
    return definition
end

function Library:GetWorkflowPresets()
    local presets = {}
    for key, definition in pairs(self.WorkflowPresets) do
        table.insert(presets, {Key = key, Definition = definition})
    end
    table.sort(presets, function(a, b)
        return tostring(a.Definition.Name or a.Key):lower() < tostring(b.Definition.Name or b.Key):lower()
    end)
    return presets
end

function Library:ApplyWorkflowPreset(name)
    local preset = type(name) == "table" and name or self.WorkflowPresets[tostring(name)]
    if type(preset) ~= "table" then return false, "Unknown workflow preset: " .. tostring(name) end
    local applied = {}
    for flag, value in pairs(preset.Flags or {}) do
        local controller = self.Options[flag]
        if controller and type(controller.Set) == "function" then
            controller:Set(cloneFeatureValue(value))
        else
            self.Flags[flag] = cloneFeatureValue(value)
        end
        table.insert(applied, flag)
    end
    if preset.ReducedMotion ~= nil then self:SetReducedMotion(preset.ReducedMotion) end
    if preset.MotionScale ~= nil then self:SetMotionScale(preset.MotionScale) end
    if preset.MaterialMode ~= nil then self:SetMaterialMode(preset.MaterialMode) end
    if preset.MaterialIntensity ~= nil then self:SetMaterialIntensity(preset.MaterialIntensity) end
    if preset.DPIScale ~= nil then self:SetDPIScale(preset.DPIScale) end
    Utility:SafeCall(preset.Callback, preset, applied)
    return true, applied
end

function Library:SaveStrategyProfile(name, flags)
    local profileName = cleanConfigName(name)
    local selected = {}
    if type(flags) == "table" then
        for key, value in pairs(flags) do
            local flag = type(key) == "number" and value or key
            if value ~= false and self.Flags[flag] ~= nil then selected[flag] = encodeValue(self.Flags[flag]) end
        end
    else
        for flag, value in pairs(self.Flags) do
            if not CONFIG_MANAGER_FLAGS[flag] then selected[flag] = encodeValue(value) end
        end
    end
    return Storage:Save(self.StrategyProfilePrefix .. profileName, {
        version = self.Version,
        kind = "strategy",
        displayName = profileName,
        flags = selected
    })
end

function Library:GetStrategyProfiles()
    local profiles = {}
    local prefix = self.StrategyProfilePrefix
    for _, storedName in ipairs(Storage:List()) do
        if storedName:sub(1, #prefix) == prefix then
            table.insert(profiles, storedName:sub(#prefix + 1))
        end
    end
    table.sort(profiles, function(a, b) return a:lower() < b:lower() end)
    return profiles
end

function Library:LoadStrategyProfile(name)
    local ok, payload = Storage:Load(self.StrategyProfilePrefix .. cleanConfigName(name))
    if not ok or type(payload) ~= "table" then return false, payload end
    for flag, rawValue in pairs(payload.flags or {}) do
        local value = decodeValue(rawValue)
        local controller = self.Options[flag]
        if controller and type(controller.Set) == "function" then controller:Set(value) else self.Flags[flag] = value end
    end
    return true
end

function Library:DeleteStrategyProfile(name)
    return Storage:Delete(self.StrategyProfilePrefix .. cleanConfigName(name))
end

function Library:RegisterIcon(name, asset)
    name = tostring(name or "")
    assert(name ~= "", "[RenLib] RegisterIcon requires a name")
    local normalized = Utility:NormalizeAssetId(asset)
    assert(normalized, "[RenLib] RegisterIcon requires a Roblox image asset")
    self.Icons[name] = normalized
    return normalized
end

function Library:GetIcon(name, fallback)
    if name == nil then return Utility:NormalizeAssetId(fallback) end
    return self.Icons[tostring(name)] or Utility:NormalizeAssetId(name, fallback)
end

function Library:RegisterAddon(name, addon)
    name = tostring(name or "")
    assert(name ~= "", "[RenLib] RegisterAddon requires a name")
    assert(type(addon) == "table", "[RenLib] RegisterAddon requires an addon table")
    if self.Addons[name] then self:DisableAddon(name) end
    local record = {Name = name, Module = addon, Enabled = false}
    self.Addons[name] = record
    table.insert(self.AddonOrder, name)
    if type(addon.Init) == "function" then
        local ok = Utility:SafeCall(addon.Init, addon, self)
        if not ok then
            self.Addons[name] = nil
            return nil
        end
    end
    if addon.AutoStart ~= false then self:EnableAddon(name) end
    return record
end

function Library:GetAddon(name)
    local record = self.Addons[tostring(name or "")]
    return record and record.Module or nil
end

function Library:EnableAddon(name)
    local record = self.Addons[tostring(name or "")]
    if not record or record.Enabled then return record ~= nil end
    record.Enabled = true
    if type(record.Module.Start) == "function" then
        local ok = Utility:SafeCall(record.Module.Start, record.Module, self)
        if not ok then record.Enabled = false end
    end
    return record.Enabled
end

function Library:DisableAddon(name)
    local record = self.Addons[tostring(name or "")]
    if not record or not record.Enabled then return record ~= nil end
    record.Enabled = false
    if type(record.Module.Stop) == "function" then
        Utility:SafeCall(record.Module.Stop, record.Module, self)
    end
    return true
end

function Library:UnregisterAddon(name)
    name = tostring(name or "")
    local record = self.Addons[name]
    if not record then return false end
    self:DisableAddon(name)
    if type(record.Module.Unload) == "function" then
        Utility:SafeCall(record.Module.Unload, record.Module, self)
    end
    self.Addons[name] = nil
    for index, registeredName in ipairs(self.AddonOrder) do
        if registeredName == name then table.remove(self.AddonOrder, index) break end
    end
    return true
end

function Library:LoadAutoloadConfig()
    local name = self:GetAutoloadConfigName()
    if not name then return false, "No autoload config" end
    return self:LoadConfig(name)
end

function Library:LaunchInfiniteYield()
    if not Capabilities:Has("loadstring") then
        if self.Notify then self:Notify({Title = "Infinite Yield unavailable", Content = "This environment does not expose loadstring.", Duration = 4}) end
        return false, "loadstring is unavailable"
    end

    local ok, source = Capabilities:HttpGet(INFINITE_YIELD_URL)
    if not ok or type(source) ~= "string" or source == "" then
        if self.Notify then self:Notify({Title = "Infinite Yield failed", Content = tostring(source), Duration = 5}) end
        return false, source
    end

    local compiled, chunk = Capabilities:Compile(source)
    if not compiled then
        local compileError = chunk
        if self.Notify then self:Notify({Title = "Infinite Yield failed", Content = tostring(compileError), Duration = 5}) end
        return false, compileError
    end

    task.spawn(function()
        local ran, runtimeError = pcall(chunk)
        if not ran and self.Notify and not self.Unloaded then
            self:Notify({Title = "Infinite Yield error", Content = tostring(runtimeError), Duration = 5})
        end
    end)
    if self.Notify then self:Notify({Title = "Infinite Yield launched", Content = "Loaded from the official EdgeIY source.", Duration = 3}) end
    return true
end

function Library:RelaunchRenCore(beforeRelaunch)
    if not Capabilities:Has("loadstring") then
        if self.Notify then self:Notify({Title = "RenCore unavailable", Content = "This environment does not expose loadstring.", Duration = 4}) end
        return false, "loadstring is unavailable"
    end
    local ok, source = Capabilities:HttpGet(RenCore_LOADER_URL)
    if not ok or type(source) ~= "string" or source == "" then
        if self.Notify then self:Notify({Title = "RenCore failed to load", Content = tostring(source), Duration = 5}) end
        return false, source
    end
    local compiled, chunk = Capabilities:Compile(source)
    if not compiled then
        local compileError = chunk
        if self.Notify then self:Notify({Title = "RenCore failed to compile", Content = tostring(compileError), Duration = 5}) end
        return false, compileError
    end
    Utility:SafeCall(beforeRelaunch)
    self:Unload("relaunching RenCore")
    task.defer(function()
        local ran, runtimeError = pcall(chunk)
        if not ran then warn("[RenLib] RenCore relaunch failed: " .. tostring(runtimeError)) end
    end)
    return true
end


--[[ MODULE: 55_esp_runtime.part.lua ]]
-- Reusable, executor-safe ESP renderer for players, NPCs, models, parts,
-- attachments, pickups, and other world objects. It deliberately uses Roblox
-- GUI instances instead of Drawing so it works in more client environments.
local ESP_R15_JOINTS = {
    {"Head", "UpperTorso"}, {"UpperTorso", "LowerTorso"},
    {"UpperTorso", "LeftUpperArm"}, {"LeftUpperArm", "LeftLowerArm"}, {"LeftLowerArm", "LeftHand"},
    {"UpperTorso", "RightUpperArm"}, {"RightUpperArm", "RightLowerArm"}, {"RightLowerArm", "RightHand"},
    {"LowerTorso", "LeftUpperLeg"}, {"LeftUpperLeg", "LeftLowerLeg"}, {"LeftLowerLeg", "LeftFoot"},
    {"LowerTorso", "RightUpperLeg"}, {"RightUpperLeg", "RightLowerLeg"}, {"RightLowerLeg", "RightFoot"},
}
local ESP_R6_JOINTS = {
    {"Head", "Torso"}, {"Torso", "Left Arm"}, {"Torso", "Right Arm"},
    {"Torso", "Left Leg"}, {"Torso", "Right Leg"},
}
local ESP_DEFAULTS = {
    Enabled = true,
    IncludeLocalPlayer = false,
    AliveOnly = true,
    MaxDistance = 2500,
    MaxVisible = 64,
    NearestOnly = false,
    UpdateRate = 0,
    MinScreenHeight = 4,
    Color = Color3.fromRGB(105, 190, 255),
    HiddenColor = nil,
    HiddenTransparency = 0.3,
    Box = true,
    BoxStyle = "Corners",
    BoxThickness = 1.5,
    BoxTransparency = 0,
    CornerScale = 0.26,
    Outline = true,
    OutlineColor = Color3.fromRGB(3, 3, 5),
    OutlineThickness = 2,
    OutlineTransparency = 0.08,
    ShowName = true,
    NameColor = nil,
    NameSize = 14,
    NameOffset = Vector2.zero,
    ShowDetails = true,
    DetailsColor = Color3.fromRGB(238, 241, 247),
    DetailsSize = 11,
    DetailsOffset = Vector2.zero,
    Font = Enum.Font.GothamBold,
    TextStrokeColor = Color3.new(0, 0, 0),
    TextStrokeTransparency = 0.12,
    ShowDistance = true,
    DistanceSuffix = "m",
    HealthBar = true,
    HealthText = true,
    HealthBarWidth = 5,
    HealthSide = "Left",
    HealthBackgroundColor = Color3.fromRGB(4, 4, 5),
    Skeleton = false,
    SkeletonColor = nil,
    SkeletonThickness = 1.5,
    SkeletonMaxDistance = 350,
    SkeletonMinScreenHeight = 28,
    SkeletonLineLimit = 24,
    Highlight = false,
    HighlightColor = nil,
    HighlightDepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
    HighlightFillTransparency = 0.88,
    HighlightOutlineTransparency = 0.08,
    OccludedFillTransparency = 0.72,
    Tracer = false,
    TracerColor = nil,
    TracerThickness = 1,
    TracerOrigin = "Bottom",
    VisibilityCheck = true,
    VisibilityInterval = 0.08,
    DefaultObjectSize = Vector3.new(2, 2, 2),
}

local function copyEspTable(source)
    local result = {}
    for key, value in pairs(source or {}) do result[key] = value end
    return result
end

local function mergeEspTables(base, override)
    local result = copyEspTable(base)
    for key, value in pairs(override or {}) do result[key] = value end
    return result
end

Library.ESPDefaults = copyEspTable(ESP_DEFAULTS)

local function createEspInstance(className, properties)
    local object = Instance.new(className)
    for key, value in pairs(properties or {}) do
        if key ~= "Parent" then object[key] = value end
    end
    if properties and properties.Parent then object.Parent = properties.Parent end
    return object
end

local function createEspLine(parent, zIndex)
    return createEspInstance("Frame", {
        Parent = parent,
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(0, 1),
        Visible = false,
        ZIndex = zIndex or 22,
    })
end

local function positionEspLine(line, a, b, thickness)
    local delta = b - a
    local length = delta.Magnitude
    if length < 0.35 then line.Visible = false return false end
    line.Position = UDim2.fromOffset((a.X + b.X) * 0.5, (a.Y + b.Y) * 0.5)
    line.Size = UDim2.fromOffset(length, math.max(0.5, tonumber(thickness) or 1))
    line.Rotation = math.deg(math.atan2(delta.Y, delta.X))
    line.Visible = true
    return true
end

local function createEspLinePair(parent, zIndex)
    return {
        Shadow = createEspLine(parent, (zIndex or 22) - 1),
        Main = createEspLine(parent, zIndex or 22),
    }
end

local function hideEspLinePair(pair)
    pair.Shadow.Visible = false
    pair.Main.Visible = false
end

local function renderEspLinePair(pair, a, b, color, thickness, transparency, style)
    local visible = positionEspLine(pair.Main, a, b, thickness)
    if not visible then pair.Shadow.Visible = false return end
    pair.Main.BackgroundColor3 = color
    pair.Main.BackgroundTransparency = transparency or 0
    if style.Outline then
        positionEspLine(pair.Shadow, a, b, (tonumber(thickness) or 1) + (tonumber(style.OutlineThickness) or 2))
        pair.Shadow.BackgroundColor3 = style.OutlineColor
        pair.Shadow.BackgroundTransparency = style.OutlineTransparency
    else
        pair.Shadow.Visible = false
    end
end

local function createEspText(parent, size, zIndex)
    return createEspInstance("TextLabel", {
        Parent = parent,
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Font = Enum.Font.GothamBold,
        Size = UDim2.fromOffset(420, 20),
        Text = "",
        TextColor3 = Color3.new(1, 1, 1),
        TextSize = size,
        TextStrokeColor3 = Color3.new(0, 0, 0),
        TextStrokeTransparency = 0.12,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Visible = false,
        ZIndex = zIndex or 30,
    })
end

local function resolveEspInstance(target, targetOptions)
    if type(targetOptions.GetInstance) == "function" then
        local ok, value = pcall(targetOptions.GetInstance, target, targetOptions)
        if ok and typeof(value) == "Instance" then return value end
    end
    if typeof(target) ~= "Instance" then return nil end
    if target:IsA("Player") then return target.Character end
    return target
end

local function resolveEspBounds(instance, style, target, targetOptions)
    if type(targetOptions.GetBounds) == "function" then
        local ok, cf, size = pcall(targetOptions.GetBounds, target, instance, targetOptions)
        if ok and typeof(cf) == "CFrame" and typeof(size) == "Vector3" then return cf, size end
    end
    if not instance then return nil end
    if instance:IsA("Model") then
        local ok, cf, size = pcall(instance.GetBoundingBox, instance)
        if ok then return cf, size end
    elseif instance:IsA("BasePart") then
        return instance.CFrame, instance.Size
    elseif instance:IsA("Attachment") then
        return instance.WorldCFrame, targetOptions.Size or style.DefaultObjectSize
    end
    local part = instance:FindFirstChildWhichIsA("BasePart", true)
    if part then return part.CFrame, targetOptions.Size or part.Size end
    return nil
end

local function projectEspBounds(camera, cf, size)
    local half = size * 0.5
    local left, top = math.huge, math.huge
    local right, bottom = -math.huge, -math.huge
    local visibleCorners = 0
    for x = -1, 1, 2 do
        for y = -1, 1, 2 do
            for z = -1, 1, 2 do
                local worldPoint = cf:PointToWorldSpace(Vector3.new(half.X * x, half.Y * y, half.Z * z))
                local screen = camera:WorldToViewportPoint(worldPoint)
                if screen.Z > 0.05 then
                    visibleCorners += 1
                    left = math.min(left, screen.X)
                    right = math.max(right, screen.X)
                    top = math.min(top, screen.Y)
                    bottom = math.max(bottom, screen.Y)
                end
            end
        end
    end
    if visibleCorners == 0 then return nil end
    return left, top, right, bottom
end

local function getEspDistanceOrigin(style)
    local origin = style.DistanceOrigin
    if type(origin) == "function" then
        local ok, value = pcall(origin)
        if ok then origin = value end
    end
    if typeof(origin) == "Instance" then
        if origin:IsA("Attachment") then return origin.WorldPosition end
        if origin:IsA("BasePart") then return origin.Position end
    elseif typeof(origin) == "Vector3" then
        return origin
    end
    local character = Plr and Plr.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    return root and root.Position or (Camera and Camera.CFrame.Position) or Vector3.zero
end

local function resolveEspHealth(target, instance, options)
    if type(options.GetHealth) == "function" then
        local ok, health, maximum = pcall(options.GetHealth, target, instance, options)
        if ok and tonumber(health) then return tonumber(health), math.max(tonumber(maximum) or 100, 1) end
    end
    local humanoid = instance and instance:FindFirstChildOfClass("Humanoid")
    if humanoid then return humanoid.Health, math.max(humanoid.MaxHealth, 1), humanoid end
    local health = instance and instance:GetAttribute("Health")
    if tonumber(health) then return tonumber(health), math.max(tonumber(instance:GetAttribute("MaxHealth")) or 100, 1) end
    return nil
end

local function cacheEspRigParts(instance)
    local parts = {}
    if not instance then return parts end
    for _, child in ipairs(instance:GetDescendants()) do
        if child:IsA("BasePart") and parts[child.Name] == nil then parts[child.Name] = child end
    end
    return parts
end

function Library:CreateESP(options)
    options = options or {}
    local guiParent = Capabilities:GetGuiParent()
    assert(guiParent, "[RenLib] No supported UI parent is available for ESP")

    local overlayGui = createEspInstance("ScreenGui", {
        Name = tostring(options.GuiName or ("RenLibESP_" .. Utility:RandomString(7))),
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        DisplayOrder = tonumber(options.DisplayOrder) or 9999,
        ZIndexBehavior = Enum.ZIndexBehavior.Global,
    })
    overlayGui:SetAttribute("RenLibESP", true)
    overlayGui:SetAttribute("RenLibVersion", self.Version)
    Capabilities:ProtectGui(overlayGui)
    overlayGui.Parent = guiParent
    local overlay = createEspInstance("Frame", {
        Name = "Overlay",
        Parent = overlayGui,
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        ZIndex = 10,
    })

    local manager = {
        Type = "ESPManager",
        Options = mergeEspTables(ESP_DEFAULTS, options),
        Records = {},
        Connections = {},
        Tracks = {},
        OverlayGui = overlayGui,
        Overlay = overlay,
        Enabled = options.Enabled ~= false,
        Destroyed = false,
        LastUpdate = 0,
        VisibleCount = 0,
    }
    manager.Options.Enabled = manager.Enabled
    table.insert(self.ESPManagers, manager)

    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    rayParams.IgnoreWater = options.IgnoreWater == true

    local function connect(signal, callback)
        local connection = signal:Connect(callback)
        table.insert(manager.Connections, connection)
        return connection
    end

    local function hideRecord(record)
        if not record or not record.Visual then return end
        local wasVisible = record.Visible == true
        for _, pair in ipairs(record.Visual.BoxLines) do hideEspLinePair(pair) end
        for _, pair in ipairs(record.Visual.SkeletonLines) do hideEspLinePair(pair) end
        hideEspLinePair(record.Visual.Tracer)
        record.Visual.Name.Visible = false
        record.Visual.Details.Visible = false
        record.Visual.HealthBack.Visible = false
        record.Visual.HealthFill.Visible = false
        if record.Visual.Highlight then record.Visual.Highlight.Enabled = false end
        record.Visible = false
        if wasVisible then Utility:SafeCall(record.Style.OnVisibilityChanged, false, record) end
    end

    local function destroyRecord(record)
        if not record then return end
        hideRecord(record)
        for _, connection in ipairs(record.Connections or {}) do pcall(function() connection:Disconnect() end) end
        if record.Visual.Highlight then record.Visual.Highlight:Destroy() end
        record.Visual.Container:Destroy()
        record.Destroyed = true
    end

    local function makeVisual(target, style)
        local container = createEspInstance("Frame", {
            Name = "ESP_" .. tostring((typeof(target) == "Instance" and target.Name) or "Target"),
            Parent = overlay,
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 1),
            ZIndex = 20,
        })
        local visual = {Container = container, BoxLines = {}, SkeletonLines = {}}
        for index = 1, 8 do visual.BoxLines[index] = createEspLinePair(container, 22) end
        for index = 1, math.max(14, tonumber(style.SkeletonLineLimit) or 24) do
            visual.SkeletonLines[index] = createEspLinePair(container, 25)
        end
        visual.Tracer = createEspLinePair(container, 21)
        visual.Name = createEspText(container, style.NameSize, 31)
        visual.Details = createEspText(container, style.DetailsSize, 31)
        visual.HealthBack = createEspInstance("Frame", {Parent = container, BackgroundColor3 = Color3.fromRGB(4, 4, 5), BorderSizePixel = 0, Visible = false, ZIndex = 27})
        visual.HealthFill = createEspInstance("Frame", {Parent = container, AnchorPoint = Vector2.new(0, 1), BackgroundColor3 = Color3.fromRGB(80, 235, 105), BorderSizePixel = 0, Visible = false, ZIndex = 28})
        return visual
    end

    local function ensureHighlight(record, instance)
        if not record.Style.Highlight then
            if record.Visual.Highlight then record.Visual.Highlight.Enabled = false end
            return nil
        end
        local adornee = instance
        if not adornee or (not adornee:IsA("Model") and not adornee:IsA("BasePart")) then
            if record.Visual.Highlight then record.Visual.Highlight.Enabled = false end
            return nil
        end
        if not record.Visual.Highlight then
            record.Visual.Highlight = createEspInstance("Highlight", {
                Name = "RenESPHighlight",
                Parent = overlayGui,
                Enabled = false,
            })
        end
        record.Visual.Highlight.Adornee = adornee
        return record.Visual.Highlight
    end

    local function resolveColor(record, instance, occluded)
        local style = record.Style
        local color = record.Options.Color or style.Color
        local callback = record.Options.GetColor or style.GetColor
        if type(callback) == "function" then
            local ok, result = pcall(callback, record.Target, instance, record)
            if ok and typeof(result) == "Color3" then color = result end
        end
        if occluded and typeof(style.HiddenColor) == "Color3" then color = style.HiddenColor end
        return typeof(color) == "Color3" and color or ESP_DEFAULTS.Color
    end

    local function resolveName(record, instance)
        local callback = record.Options.GetName or record.Style.GetName
        if type(callback) == "function" then
            local ok, result = pcall(callback, record.Target, instance, record)
            if ok and result ~= nil then return tostring(result) end
        end
        if record.Options.Name ~= nil then return tostring(record.Options.Name) end
        if typeof(record.Target) == "Instance" and record.Target:IsA("Player") then
            local player = record.Target
            return player.DisplayName ~= player.Name and (player.DisplayName .. "  @" .. player.Name) or ("@" .. player.Name)
        end
        return instance and instance.Name or "Target"
    end

    local function resolveDetail(record, instance, health, maximum, distance, occluded)
        local callback = record.Options.GetText or record.Style.GetText
        if type(callback) == "function" then
            local ok, result = pcall(callback, record.Target, instance, record)
            if ok and result ~= nil then return tostring(result) end
        end
        if record.Options.Text ~= nil then return tostring(record.Options.Text) end
        local pieces = {}
        if record.Style.HealthText and health then table.insert(pieces, string.format("HP %d/%d", math.max(0, math.floor(health + 0.5)), math.floor(maximum + 0.5))) end
        if record.Style.ShowDistance then table.insert(pieces, tostring(math.floor(distance + 0.5)) .. tostring(record.Style.DistanceSuffix or "m")) end
        if occluded then table.insert(pieces, "OCCLUDED") end
        return table.concat(pieces, "  •  ")
    end

    local function renderBox(record, left, top, right, bottom, color, transparency)
        local style = record.Style
        local lines = record.Visual.BoxLines
        if not style.Box or style.BoxStyle == "None" then
            for _, pair in ipairs(lines) do hideEspLinePair(pair) end
            return
        end
        local thickness = tonumber(style.BoxThickness) or 1.5
        if tostring(style.BoxStyle):lower() == "full" then
            local points = {
                {Vector2.new(left, top), Vector2.new(right, top)},
                {Vector2.new(right, top), Vector2.new(right, bottom)},
                {Vector2.new(right, bottom), Vector2.new(left, bottom)},
                {Vector2.new(left, bottom), Vector2.new(left, top)},
            }
            for index, pair in ipairs(lines) do
                local pointsForLine = points[index]
                if pointsForLine then renderEspLinePair(pair, pointsForLine[1], pointsForLine[2], color, thickness, transparency, style) else hideEspLinePair(pair) end
            end
            return
        end
        local width, height = right - left, bottom - top
        local corner = math.clamp(math.min(width, height) * (tonumber(style.CornerScale) or 0.26), 4, 22)
        local points = {
            {Vector2.new(left, top), Vector2.new(left + corner, top)}, {Vector2.new(left, top), Vector2.new(left, top + corner)},
            {Vector2.new(right - corner, top), Vector2.new(right, top)}, {Vector2.new(right, top), Vector2.new(right, top + corner)},
            {Vector2.new(left, bottom - corner), Vector2.new(left, bottom)}, {Vector2.new(left, bottom), Vector2.new(left + corner, bottom)},
            {Vector2.new(right, bottom - corner), Vector2.new(right, bottom)}, {Vector2.new(right - corner, bottom), Vector2.new(right, bottom)},
        }
        for index, pair in ipairs(lines) do renderEspLinePair(pair, points[index][1], points[index][2], color, thickness, transparency, style) end
    end

    local function updateRecord(record, now)
        local style = record.Style
        local instance = resolveEspInstance(record.Target, record.Options)
        if not manager.Enabled or style.Enabled == false or not instance or not instance.Parent then hideRecord(record) return false end
        if type(style.Predicate) == "function" then
            local ok, allowed = pcall(style.Predicate, record.Target, instance, record)
            if not ok or allowed == false then hideRecord(record) return false end
        end
        local cf, size = resolveEspBounds(instance, style, record.Target, record.Options)
        if not cf or not size then hideRecord(record) return false end
        local health, maximum, humanoid = resolveEspHealth(record.Target, instance, record.Options)
        if style.AliveOnly and humanoid and health <= 0 then hideRecord(record) return false end
        Camera = workspace.CurrentCamera or Camera
        if not Camera then hideRecord(record) return false end
        local distance = (cf.Position - getEspDistanceOrigin(style)).Magnitude
        if tonumber(style.MaxDistance) and style.MaxDistance > 0 and distance > style.MaxDistance then hideRecord(record) return false end
        local left, top, right, bottom = projectEspBounds(Camera, cf, size)
        if not left then hideRecord(record) return false end
        local width, height = right - left, bottom - top
        local viewport = Camera.ViewportSize
        if height < (tonumber(style.MinScreenHeight) or 4) or right < -24 or left > viewport.X + 24 or bottom < -24 or top > viewport.Y + 24 then hideRecord(record) return false end

        local occluded = false
        if style.VisibilityCheck and now >= (record.NextVisibilityUpdate or 0) then
            record.NextVisibilityUpdate = now + math.max(0.02, tonumber(style.VisibilityInterval) or 0.08)
            local filters = {}
            for _, item in ipairs(style.RaycastIgnore or {}) do if typeof(item) == "Instance" then table.insert(filters, item) end end
            if Plr and Plr.Character then table.insert(filters, Plr.Character) end
            table.insert(filters, Camera)
            table.insert(filters, instance)
            rayParams.FilterDescendantsInstances = filters
            local origin = Camera.CFrame.Position
            record.Occluded = workspace:Raycast(origin, cf.Position - origin, rayParams) ~= nil
        end
        occluded = record.Occluded == true
        local baseColor = resolveColor(record, instance, occluded)
        local transparency = math.clamp((tonumber(style.BoxTransparency) or 0) + (occluded and (tonumber(style.HiddenTransparency) or 0.3) or 0), 0, 0.95)
        renderBox(record, left, top, right, bottom, style.BoxColor or baseColor, transparency)

        local centerX = (left + right) * 0.5
        local nameOffset = typeof(style.NameOffset) == "Vector2" and style.NameOffset or Vector2.zero
        record.Visual.Name.Position = UDim2.fromOffset(centerX + nameOffset.X, top - math.max(10, style.NameSize or 14) * 0.72 + nameOffset.Y)
        record.Visual.Name.Text = resolveName(record, instance)
        record.Visual.Name.TextColor3 = style.NameColor or baseColor
        record.Visual.Name.TextSize = tonumber(style.NameSize) or 14
        record.Visual.Name.Font = typeof(style.Font) == "EnumItem" and style.Font or Enum.Font.GothamBold
        record.Visual.Name.TextStrokeColor3 = style.TextStrokeColor
        record.Visual.Name.TextStrokeTransparency = style.TextStrokeTransparency
        record.Visual.Name.Visible = style.ShowName == true

        local details = resolveDetail(record, instance, health, maximum, distance, occluded)
        local detailsOffset = typeof(style.DetailsOffset) == "Vector2" and style.DetailsOffset or Vector2.zero
        record.Visual.Details.Position = UDim2.fromOffset(centerX + detailsOffset.X, bottom + math.max(9, style.DetailsSize or 11) * 0.78 + detailsOffset.Y)
        record.Visual.Details.Text = details
        record.Visual.Details.TextColor3 = style.DetailsColor or baseColor
        record.Visual.Details.TextSize = tonumber(style.DetailsSize) or 11
        record.Visual.Details.Font = typeof(style.Font) == "EnumItem" and style.Font or Enum.Font.GothamBold
        record.Visual.Details.TextStrokeColor3 = style.TextStrokeColor
        record.Visual.Details.TextStrokeTransparency = style.TextStrokeTransparency
        record.Visual.Details.Visible = style.ShowDetails == true and details ~= ""

        local showHealth = style.HealthBar == true and health ~= nil
        if showHealth then
            local ratio = math.clamp(health / math.max(maximum, 1), 0, 1)
            local barWidth = math.max(2, tonumber(style.HealthBarWidth) or 5)
            local healthX = tostring(style.HealthSide):lower() == "right" and right + 2 or left - barWidth - 4
            record.Visual.HealthBack.Position = UDim2.fromOffset(healthX, top - 1)
            record.Visual.HealthBack.Size = UDim2.fromOffset(barWidth + 2, height + 2)
            record.Visual.HealthFill.Position = UDim2.fromOffset(healthX + 1, bottom)
            record.Visual.HealthFill.Size = UDim2.fromOffset(barWidth, math.max(1, height * ratio))
            local healthColor = style.HealthColor
            if type(healthColor) == "function" then
                local ok, resolved = pcall(healthColor, ratio, record)
                healthColor = ok and typeof(resolved) == "Color3" and resolved or nil
            end
            record.Visual.HealthFill.BackgroundColor3 = healthColor or Color3.fromHSV(ratio * 0.33, 0.85, 0.98)
            record.Visual.HealthBack.BackgroundColor3 = style.HealthBackgroundColor
        end
        record.Visual.HealthBack.Visible = showHealth
        record.Visual.HealthFill.Visible = showHealth

        if style.Tracer then
            local tracerOrigin = style.TracerOrigin
            local start
            if typeof(tracerOrigin) == "Vector2" then start = tracerOrigin
            elseif tostring(tracerOrigin):lower() == "center" then start = viewport * 0.5
            elseif tostring(tracerOrigin):lower() == "top" then start = Vector2.new(viewport.X * 0.5, 0)
            else start = Vector2.new(viewport.X * 0.5, viewport.Y) end
            renderEspLinePair(record.Visual.Tracer, start, Vector2.new(centerX, bottom), style.TracerColor or baseColor, style.TracerThickness, transparency, style)
        else hideEspLinePair(record.Visual.Tracer) end

        local highlight = ensureHighlight(record, instance)
        if highlight then
            highlight.Enabled = true
            highlight.DepthMode = style.HighlightDepthMode
            highlight.FillColor = style.HighlightColor or baseColor
            highlight.OutlineColor = style.HighlightOutlineColor or style.HighlightColor or baseColor
            highlight.FillTransparency = occluded and style.OccludedFillTransparency or style.HighlightFillTransparency
            highlight.OutlineTransparency = style.HighlightOutlineTransparency
        end

        local drawSkeleton = style.Skeleton == true and instance:IsA("Model") and height >= (style.SkeletonMinScreenHeight or 28)
            and (not style.SkeletonMaxDistance or style.SkeletonMaxDistance <= 0 or distance <= style.SkeletonMaxDistance)
        if drawSkeleton then
            if now >= (record.NextRigRefresh or 0) then
                record.NextRigRefresh = now + 0.25
                record.RigParts = cacheEspRigParts(instance)
            end
            local joints = record.Options.SkeletonJoints or style.SkeletonJoints or (record.RigParts.UpperTorso and ESP_R15_JOINTS or ESP_R6_JOINTS)
            for index, pair in ipairs(record.Visual.SkeletonLines) do
                local joint = joints[index]
                local a = joint and record.RigParts[joint[1]]
                local b = joint and record.RigParts[joint[2]]
                if a and b and a.Parent and b.Parent then
                    local aScreen = Camera:WorldToViewportPoint(a.Position)
                    local bScreen = Camera:WorldToViewportPoint(b.Position)
                    if aScreen.Z > 0.05 and bScreen.Z > 0.05 then
                        renderEspLinePair(pair, Vector2.new(aScreen.X, aScreen.Y), Vector2.new(bScreen.X, bScreen.Y), style.SkeletonColor or baseColor, style.SkeletonThickness, occluded and 0.06 or 0, style)
                    else hideEspLinePair(pair) end
                else hideEspLinePair(pair) end
            end
        else
            for _, pair in ipairs(record.Visual.SkeletonLines) do hideEspLinePair(pair) end
        end
        record.Instance = instance
        record.Distance = distance
        record.Bounds = {Left = left, Top = top, Right = right, Bottom = bottom, Width = width, Height = height}
        local becameVisible = not record.Visible
        record.Visible = true
        if becameVisible then Utility:SafeCall(style.OnVisibilityChanged, true, record) end
        Utility:SafeCall(style.OnRender, record, {Instance = instance, Distance = distance, Occluded = occluded, Bounds = record.Bounds, Color = baseColor})
        return true
    end

    function manager:Add(target, targetOptions)
        targetOptions = targetOptions or {}
        if typeof(target) ~= "Instance" then return nil, "ESP target must be a Roblox Instance" end
        local existing = self.Records[target]
        if existing then existing:Configure(targetOptions) return existing end
        if target:IsA("Player") and target == Plr and not (targetOptions.IncludeLocalPlayer or self.Options.IncludeLocalPlayer) then return nil, "Local player is excluded" end
        local style = mergeEspTables(self.Options, targetOptions)
        local record = {
            Type = "ESPRecord",
            Manager = self,
            Target = target,
            Options = copyEspTable(targetOptions),
            Style = style,
            Visual = makeVisual(target, style),
            Visible = false,
            Destroyed = false,
            Occluded = false,
            Connections = {},
        }
        function record:Configure(values)
            for key, value in pairs(values or {}) do
                self.Options[key] = value
                self.Style[key] = value
            end
            return self
        end
        function record:SetOption(name, value) self.Options[name] = value self.Style[name] = value return self end
        function record:SetFeature(name, value) return self:SetOption(name, value == true) end
        function record:SetColor(value) return self:SetOption("Color", value) end
        function record:SetText(value) self.Options.Text = value return self end
        function record:SetName(value) self.Options.Name = value return self end
        function record:SetVisible(value) self.Style.Enabled = value == true if not value then hideRecord(self) end return self end
        function record:ClearOverride(name)
            self.Options[name] = nil
            self.Style[name] = self.Manager.Options[name]
            return self
        end
        function record:Remove() return self.Manager:Remove(self.Target) end
        self.Records[target] = record
        if not target:IsA("Player") then
            table.insert(record.Connections, connect(target.AncestryChanged, function(_, parent)
                if parent == nil and self.Records[target] == record then self:Remove(target) end
            end))
        end
        return record
    end

    function manager:Remove(target)
        local record = self.Records[target]
        if not record then return false end
        self.Records[target] = nil
        destroyRecord(record)
        return true
    end

    function manager:Clear()
        local targets = {}
        for target in pairs(self.Records) do table.insert(targets, target) end
        for _, target in ipairs(targets) do self:Remove(target) end
        return self
    end

    function manager:SetEnabled(value)
        self.Enabled = value == true
        self.Options.Enabled = self.Enabled
        if not self.Enabled then for _, record in pairs(self.Records) do hideRecord(record) end end
        return self
    end

    function manager:SetOption(name, value)
        self.Options[name] = value
        for _, record in pairs(self.Records) do
            if record.Options[name] == nil then record.Style[name] = value end
        end
        if name == "Enabled" then self:SetEnabled(value) end
        return self
    end

    function manager:SetOptions(values)
        for name, value in pairs(values or {}) do self:SetOption(name, value) end
        return self
    end

    function manager:SetFeature(name, value) return self:SetOption(name, value == true) end
    function manager:GetOptions() return copyEspTable(self.Options) end
    function manager:GetRecord(target) return self.Records[target] end
    function manager:GetRecords() return self.Records end
    function manager:GetStats()
        local total = 0
        for _ in pairs(self.Records) do total += 1 end
        return {Total = total, Visible = self.VisibleCount, Enabled = self.Enabled, UpdateRate = self.Options.UpdateRate}
    end

    function manager:TrackPlayers(trackOptions)
        trackOptions = trackOptions or {}
        local track = {Targets = {}, Active = true}
        local function add(player)
            if not track.Active or (player == Plr and not (trackOptions.IncludeLocalPlayer or self.Options.IncludeLocalPlayer)) then return end
            local record = self:Add(player, trackOptions)
            if record then track.Targets[player] = true end
        end
        for _, player in ipairs(Players:GetPlayers()) do add(player) end
        table.insert(track, connect(Players.PlayerAdded, add))
        table.insert(track, connect(Players.PlayerRemoving, function(player)
            track.Targets[player] = nil
            self:Remove(player)
        end))
        function track:Stop(removeTargets)
            if not self.Active then return false end
            self.Active = false
            for _, connection in ipairs(self) do pcall(function() connection:Disconnect() end) end
            if removeTargets ~= false then
                for target in pairs(self.Targets) do manager:Remove(target) end
            end
            table.clear(self.Targets)
            return true
        end
        table.insert(self.Tracks, track)
        return track
    end

    function manager:TrackContainer(container, trackOptions)
        assert(typeof(container) == "Instance", "[RenLib] TrackContainer requires an Instance")
        trackOptions = trackOptions or {}
        local track = {Targets = {}, Active = true}
        local function allowed(instance)
            if type(trackOptions.Predicate) == "function" then
                local ok, result = pcall(trackOptions.Predicate, instance)
                return ok and result == true
            end
            return instance:IsA("Model") or instance:IsA("BasePart") or instance:IsA("Attachment")
        end
        local function add(instance)
            if track.Active and allowed(instance) then
                local record = self:Add(instance, trackOptions)
                if record then track.Targets[instance] = true end
            end
        end
        local initial = trackOptions.Recursive and container:GetDescendants() or container:GetChildren()
        for _, instance in ipairs(initial) do add(instance) end
        local addedSignal = trackOptions.Recursive and container.DescendantAdded or container.ChildAdded
        local removingSignal = trackOptions.Recursive and container.DescendantRemoving or container.ChildRemoved
        table.insert(track, connect(addedSignal, add))
        table.insert(track, connect(removingSignal, function(instance)
            if track.Targets[instance] then track.Targets[instance] = nil self:Remove(instance) end
        end))
        function track:Stop(removeTargets)
            if not self.Active then return false end
            self.Active = false
            for _, connection in ipairs(self) do pcall(function() connection:Disconnect() end) end
            if removeTargets ~= false then for target in pairs(self.Targets) do manager:Remove(target) end end
            table.clear(self.Targets)
            return true
        end
        table.insert(self.Tracks, track)
        return track
    end

    function manager:Refresh()
        self.LastUpdate = 0
        return self
    end

    function manager:Destroy()
        if self.Destroyed then return end
        self.Destroyed = true
        for _, track in ipairs(self.Tracks) do track:Stop(false) end
        self:Clear()
        for _, connection in ipairs(self.Connections) do pcall(function() connection:Disconnect() end) end
        table.clear(self.Connections)
        if self.OverlayGui then self.OverlayGui:Destroy() end
        for index, candidate in ipairs(Library.ESPManagers) do
            if candidate == self then table.remove(Library.ESPManagers, index) break end
        end
    end

    local function approximateDistance(record)
        local instance = resolveEspInstance(record.Target, record.Options)
        if not instance then return math.huge end
        local position
        if instance:IsA("Attachment") then
            position = instance.WorldPosition
        elseif instance:IsA("BasePart") then
            position = instance.Position
        elseif instance:IsA("Model") then
            local root = instance.PrimaryPart or instance:FindFirstChild("HumanoidRootPart") or instance:FindFirstChildWhichIsA("BasePart", true)
            position = root and root.Position
        else
            local root = instance:FindFirstChildWhichIsA("BasePart", true)
            position = root and root.Position
        end
        return position and (position - getEspDistanceOrigin(record.Style)).Magnitude or math.huge
    end

    connect(RunService.RenderStepped, function()
        if manager.Destroyed or Library.Unloaded then return end
        local now = os.clock()
        local updateRate = math.max(0, tonumber(manager.Options.UpdateRate) or 0)
        if updateRate > 0 and now - manager.LastUpdate < updateRate then return end
        manager.LastUpdate = now
        Camera = workspace.CurrentCamera or Camera
        if not Camera then return end
        local candidates = {}
        for _, record in pairs(manager.Records) do
            table.insert(candidates, {Record = record, Distance = approximateDistance(record)})
        end
        table.sort(candidates, function(a, b) return a.Distance < b.Distance end)
        local limit = manager.Options.NearestOnly and 1 or math.max(1, tonumber(manager.Options.MaxVisible) or #candidates)
        local visible = 0
        for index, candidate in ipairs(candidates) do
            if index <= limit and updateRecord(candidate.Record, now) then visible += 1 else hideRecord(candidate.Record) end
        end
        manager.VisibleCount = visible
    end)

    if options.AutoPlayers then manager.PlayerTrack = manager:TrackPlayers(options.PlayerOptions or {}) end
    return manager
end

-- Compatibility facade for safely migrating scripts that were authored
-- against Rayfield's tab-level control API. The rendered UI, persistence,
-- cleanup, input handling, and controllers are all RenLib-owned.

--[[ MODULE: 60_rayfield_compat.part.lua ]]
-- Module fragment: Rayfield compatibility adapter
-- Generated from the working V7 baseline; edit this feature in isolation.
function Library:CreateRayfieldAdapter()
    local source = self
    local adapter = {ConfigName = nil, Window = nil}

    local function safeCallback(callback, ...)
        if callback then Utility:SafeCall(callback, ...) end
    end

    local function unwrapSingle(value)
        if type(value) == "table" then return value[1] end
        return value
    end

    local function selectedArray(value, values)
        local selected = {}
        if type(value) ~= "table" then
            if value ~= nil then table.insert(selected, value) end
            return selected
        end
        for _, option in ipairs(values or {}) do
            if value[option] == true then table.insert(selected, option) end
        end
        if #selected == 0 then
            for key, item in pairs(value) do
                if type(key) == "number" then table.insert(selected, item) end
            end
        end
        return selected
    end

    local function proxyController(controller, transformSet)
        local proxy = {Raw = controller}
        function proxy:Set(value)
            if controller and controller.Set then controller:Set(transformSet and transformSet(value) or value) end
            return self
        end
        function proxy:Get()
            return controller and controller.Get and controller:Get() or nil
        end
        return setmetatable(proxy, {__index = controller})
    end

    function adapter:Notify(options)
        return source:Notify(options or {})
    end

    function adapter:Destroy()
        return source:Unload("compatibility adapter")
    end

    function adapter:LoadConfiguration()
        if self.ConfigName then
            local ok = source:LoadConfig(self.ConfigName)
            if ok then return true end
        end
        return source:LoadAutoloadConfig()
    end

    function adapter:CreateWindow(options)
        options = options or {}
        local saving = options.ConfigurationSaving or {}
        if saving.Enabled then self.ConfigName = cleanConfigName(saving.FileName or options.Name or "default") end
        local themeAliases = {
            Default = "Celestial", AmberGlow = "Ember", Amethyst = "Nebula",
            Bloom = "Rose", DarkBlue = "Midnight", Green = "Moss Archive",
            Light = "Prism Frost", Ocean = "Aurora", Serenity = "Celestial"
        }
        -- A saved autoload theme is the user's explicit choice and must win
        -- over a legacy script's hard-coded Rayfield theme.
        if not source.AutoloadThemeName and type(options.Theme) == "string" then
            source:ApplyThemePreset(themeAliases[options.Theme] or options.Theme)
        elseif not source.AutoloadThemeName and type(options.Theme) == "table" then
            source:SetTheme({
                Main = options.Theme.Background,
                Secondary = options.Theme.Topbar or options.Theme.Background,
                Surface = options.Theme.ElementBackground,
                SurfaceAlt = options.Theme.SecondaryElementBackground or options.Theme.ElementBackground,
                Stroke = options.Theme.ElementStroke,
                Divider = options.Theme.SecondaryElementStroke or options.Theme.ElementStroke,
                Text = options.Theme.TextColor,
                SubText = options.Theme.PlaceholderColor,
                Hover = options.Theme.ElementBackgroundHover,
                Click = options.Theme.DropdownSelected,
                Accent = options.Theme.ToggleEnabled or options.Theme.SliderProgress,
                Accent2 = options.Theme.ToggleEnabledStroke or options.Theme.SliderProgress,
                Accent3 = options.Theme.TabBackgroundSelected or options.Theme.ToggleEnabled
            })
        end
        local toggleKey = options.ToggleUIKeybind
        if typeof(toggleKey) == "EnumItem" then
            source.ToggleKey = toggleKey
        elseif type(toggleKey) == "string" and Enum.KeyCode[toggleKey] then
            source.ToggleKey = Enum.KeyCode[toggleKey]
        end
        local rawWindow = source:CreateWindow({
            Name = options.Name or options.LoadingTitle or "RenLib Script",
            Icon = options.Icon,
            SidebarMode = "Expanded",
            ShowUserProfile = true,
            ShowInfiniteYield = false,
            EnableGlobalSearch = true
        })
        self.Window = rawWindow
        local window = {Raw = rawWindow}

        function window:CreateTab(name, icon)
            local rawTab = rawWindow:CreateTab({Name = tostring(name or "Tab"), Icon = icon})
            local tab = {Raw = rawTab, CurrentSection = nil, SectionCount = 0}

            local function currentSection()
                if not tab.CurrentSection then
                    tab.SectionCount = tab.SectionCount + 1
                    tab.CurrentSection = rawTab:CreateSection({Name = "Controls", Side = "Left"})
                end
                return tab.CurrentSection
            end

            function tab:CreateSection(sectionOptions)
                local sectionName = type(sectionOptions) == "table" and sectionOptions.Name or sectionOptions
                self.SectionCount = self.SectionCount + 1
                self.CurrentSection = rawTab:CreateSection({
                    Name = tostring(sectionName or "Section"),
                    Side = self.SectionCount % 2 == 1 and "Left" or "Right"
                })
                return self.CurrentSection
            end

            function tab:CreateButton(controlOptions)
                controlOptions = controlOptions or {}
                return currentSection():CreateButton({
                    Name = controlOptions.Name,
                    Description = controlOptions.Description,
                    Icon = controlOptions.Icon,
                    Callback = controlOptions.Callback
                })
            end

            function tab:CreateToggle(controlOptions)
                controlOptions = controlOptions or {}
                return proxyController(currentSection():CreateToggle({
                    Name = controlOptions.Name,
                    Default = controlOptions.CurrentValue,
                    Flag = controlOptions.Flag,
                    Callback = controlOptions.Callback
                }))
            end

            function tab:CreateSlider(controlOptions)
                controlOptions = controlOptions or {}
                local range = controlOptions.Range or {0, 100}
                return proxyController(currentSection():CreateSlider({
                    Name = controlOptions.Name,
                    Min = range[1],
                    Max = range[2],
                    Step = controlOptions.Increment or 1,
                    Default = controlOptions.CurrentValue or range[1],
                    Flag = controlOptions.Flag,
                    CallbackMode = controlOptions.CallbackMode or "Changed",
                    Callback = controlOptions.Callback
                }))
            end

            function tab:CreateDropdown(controlOptions)
                controlOptions = controlOptions or {}
                local values = controlOptions.Options or {}
                local multi = controlOptions.MultipleOptions == true
                local default = multi and (controlOptions.CurrentOption or {}) or unwrapSingle(controlOptions.CurrentOption)
                local callback = controlOptions.Callback
                local raw = currentSection():CreateDropdown({
                    Name = controlOptions.Name,
                    Values = values,
                    Multi = multi,
                    Default = default,
                    Flag = controlOptions.Flag,
                    Callback = function(value)
                        safeCallback(callback, multi and selectedArray(value, values) or {value})
                    end
                })
                local proxy = proxyController(raw, function(value) return multi and value or unwrapSingle(value) end)
                function proxy:Refresh(newValues, newSelection)
                    values = type(newValues) == "table" and newValues or {}
                    raw:Refresh(values)
                    if newSelection ~= nil and newSelection ~= true then self:Set(newSelection) end
                    return self
                end
                return proxy
            end

            function tab:CreateInput(controlOptions)
                controlOptions = controlOptions or {}
                return proxyController(currentSection():CreateInput({
                    Name = controlOptions.Name,
                    Default = controlOptions.CurrentValue or "",
                    Placeholder = controlOptions.PlaceholderText or controlOptions.Placeholder,
                    Flag = controlOptions.Flag,
                    Callback = controlOptions.Callback
                }))
            end

            function tab:CreateColorPicker(controlOptions)
                controlOptions = controlOptions or {}
                return proxyController(currentSection():CreateColorPicker({
                    Name = controlOptions.Name,
                    Default = controlOptions.Color or controlOptions.CurrentColor or Color3.new(1, 1, 1),
                    Flag = controlOptions.Flag,
                    Callback = controlOptions.Callback
                }))
            end

            function tab:CreateLabel(labelOptions)
                local text = type(labelOptions) == "table" and (labelOptions.Text or labelOptions.Name) or labelOptions
                local raw = currentSection():CreateLabel(tostring(text or ""))
                local proxy = {Raw = raw}
                function proxy:Set(nextText) raw:SetText(tostring(nextText or "")); return self end
                return setmetatable(proxy, {__index = raw})
            end

            function tab:CreateParagraph(controlOptions)
                controlOptions = type(controlOptions) == "table" and controlOptions or {Content = controlOptions}
                local raw = currentSection():CreateParagraph({Title = controlOptions.Title, Content = controlOptions.Content})
                local proxy = {Raw = raw}
                function proxy:Set(value)
                    if type(value) == "table" then
                        if value.Title ~= nil then raw:SetTitle(value.Title) end
                        if value.Content ~= nil then raw:SetContent(value.Content) end
                    else
                        raw:SetContent(tostring(value or ""))
                    end
                    return self
                end
                return setmetatable(proxy, {__index = raw})
            end

            function tab:CreateKeybind(controlOptions)
                controlOptions = controlOptions or {}
                local key = controlOptions.CurrentKeybind
                if typeof(key) == "EnumItem" then key = key.Name end
                key = tostring(key or "None")
                local callback = controlOptions.Callback
                local raw = currentSection():CreateKeyPicker({
                    Name = controlOptions.Name,
                    Default = key,
                    Flag = controlOptions.Flag,
                    Mode = "Toggle",
                    Callback = function() end
                })
                source:Connect(UserInputService.InputBegan, function(input, processed)
                    if not processed and input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode.Name == raw:GetKey() then
                        safeCallback(callback)
                    end
                end)
                return proxyController(raw, function(value)
                    return typeof(value) == "EnumItem" and value.Name or tostring(value)
                end)
            end

            return tab
        end

        return window
    end

    return adapter
end


--[[ MODULE: 70_window_shell.part.lua ]]
-- Module fragment: window shell, navigation, notifications
-- Generated from the working V7 baseline; edit this feature in isolation.
--// CORE UI: WINDOW
function Library:CreateWindow(options)
    options = options or {}
    local WindowTitle = options.Name or "RenLib"
    local EnableSidebarResize = options.EnableSidebarResize == nil and true or options.EnableSidebarResize
    local EnableGlobalSearch = options.EnableGlobalSearch == nil and true or options.EnableGlobalSearch
    local SidebarCompactMode = options.SidebarCompactMode or false
    local SidebarMode = tostring(options.SidebarMode or (SidebarCompactMode and "Compact" or (DeviceMode == "Desktop" and "Expanded" or "Compact")))
    if SidebarMode ~= "Dynamic" and SidebarMode ~= "Expanded" and SidebarMode ~= "Compact" then SidebarMode = "Expanded" end
    local WindowIcon = Utility:NormalizeAssetId(options.Icon or options.Logo)
    local SettingsIcon = Utility:NormalizeAssetId(options.SettingsIcon, ICONS.Settings)
    local ShowUserProfile = options.ShowUserProfile == nil and true or options.ShowUserProfile
    local RequestedMaterialMode = options.MaterialMode or self.MaterialMode or "Solid"
    local EnableCommandPalette = options.EnableCommandPalette == nil and true or options.EnableCommandPalette

    local brandLoadStarted = false
    local function createWindowMark(parent, textSize, zIndex)
        local mark = Utility:Create("ImageLabel", {
            Parent = parent,
            BackgroundTransparency = 1,
            Position = UDim2.fromScale(0.16, 0.16),
            Size = UDim2.fromScale(0.68, 0.68),
            Image = WindowIcon or Library.BrandIcon,
            ImageColor3 = (WindowIcon or not Library.BrandIconTint) and Color3.new(1, 1, 1) or Library.Theme[Library.BrandIconTint],
            ScaleType = Enum.ScaleType.Fit,
            ZIndex = zIndex
        })
        if not WindowIcon then
            Library.BrandMarks[mark] = true
            if Library.BrandIconTint then Utility:RegisterProperty(mark, "ImageColor3", Library.BrandIconTint) end
            if not brandLoadStarted then
                brandLoadStarted = true
                Utility:LoadBrandIcon()
            end
        end
        return mark
    end

    if self.ScreenGui then
        pcall(function() self.ScreenGui:Destroy() end)
        self.ScreenGui = nil
    end
    self.Unloaded = false
    DeviceMode = getDeviceMode(self.DPIScale)
    IsMobile = DeviceMode ~= "Desktop"
    self.DeviceMode = DeviceMode
    self.IsMobile = IsMobile

    -- Calculate sizes based on device
    local initialViewport = getViewport()
    local initialLayoutWidth = initialViewport.X / math.max(self.DPIScale, 0.01)
    local initialLayoutHeight = initialViewport.Y / math.max(self.DPIScale, 0.01)
    local WinWidth, WinHeight, SidebarWidth, FontScale
    if IsMobile then
        WinWidth = math.min(720, math.max(1, initialLayoutWidth - 12))
        WinHeight = math.min(680, math.max(1, initialLayoutHeight - 12))
        SidebarWidth = WinWidth < 340 and 54 or 60
        FontScale = 0.9
        EnableSidebarResize = false
    else
        WinWidth = math.min(options.Width or 880, math.max(1, initialLayoutWidth - 32))
        WinHeight = math.min(options.Height or 580, math.max(1, initialLayoutHeight - 32))
        SidebarWidth = SidebarMode == "Expanded" and 190 or 80
        FontScale = 1
    end

    -- Main ScreenGui with UIScale for DPI
    local ScreenGui = Utility:Create("ScreenGui", {
        Name = "RenLibV6_" .. Utility:RandomString(8),
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        IgnoreGuiInset = true,
        DisplayOrder = options.DisplayOrder or 1000
    })
    ScreenGui:SetAttribute("RenLibVersion", Library.Version)
    local uiScale = Utility:Create("UIScale", {Parent = ScreenGui})
    table.insert(Library.Scales, uiScale)

    Capabilities:ProtectGui(ScreenGui)
    local guiParent = Capabilities:GetGuiParent()
    assert(guiParent, "[RenLib] No supported UI parent is available")
    ScreenGui.Parent = guiParent
    Library.ScreenGui = ScreenGui

    -- Main Container
    local MainFrame = Utility:Create("Frame", {
        Name = "Main",
        Parent = ScreenGui,
        BackgroundColor3 = Library.Theme.Main,
        Position = UDim2.new(0.5, -WinWidth / 2, 0.5, -WinHeight / 2),
        Size = UDim2.new(0, WinWidth, 0, WinHeight),
        ClipsDescendants = true,
        ZIndex = 1,
        BorderSizePixel = 0
    })
    Utility:RegisterProperty(MainFrame, "BackgroundColor3", "Main")
    Utility:RegisterMaterial(MainFrame, 0.24, 0)
    Utility:Create("UICorner", {CornerRadius = UDim.new(0, 14), Parent = MainFrame})
    local mainGradient = Utility:Create("UIGradient", {Parent = MainFrame, Rotation = 115})
    Utility:RegisterGradient(mainGradient, "Main", "Secondary")
    local glassTint = Utility:Create("ImageLabel", {
        Name = "GlassTint",
        Parent = MainFrame,
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        Image = "rbxassetid://9968344105",
        ImageColor3 = Library.Theme.Accent2,
        ImageTransparency = 0.95,
        ScaleType = Enum.ScaleType.Tile,
        TileSize = UDim2.fromOffset(128, 128),
        Visible = false,
        ZIndex = 1
    })
    Utility:RegisterProperty(glassTint, "ImageColor3", "Accent2")
    Utility:Create("UICorner", {CornerRadius = UDim.new(0, 14), Parent = glassTint})
    Library.MaterialDecorations[glassTint] = true
    local glassNoise = Utility:Create("ImageLabel", {
        Name = "GlassNoise",
        Parent = MainFrame,
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        Image = "rbxassetid://9968344227",
        ImageColor3 = Color3.new(1, 1, 1),
        ImageTransparency = 0.93,
        ScaleType = Enum.ScaleType.Tile,
        TileSize = UDim2.fromOffset(128, 128),
        Visible = false,
        ZIndex = 1
    })
    Utility:Create("UICorner", {CornerRadius = UDim.new(0, 14), Parent = glassNoise})
    Library.MaterialDecorations[glassNoise] = true
    local WindowScale = Utility:Create("UIScale", {Parent = MainFrame, Scale = 1})
    local mainStroke = Utility:Create("UIStroke", {Parent = MainFrame, Color = Library.Theme.Stroke, Thickness = 1})
    Utility:RegisterProperty(mainStroke, "Color", "Stroke")
    -- Sidebar
    local Sidebar = Utility:Create("Frame", {
        Name = "Sidebar",
        Parent = MainFrame,
        BackgroundTransparency = 1,
        Size = UDim2.new(0, SidebarWidth, 1, 0),
        ZIndex = 2,
        BorderSizePixel = 0
    })
    -- The rounded shell and square inner extension are composited once by the
    -- CanvasGroup. Frosted themes therefore keep one uniform tint instead of
    -- revealing a darker double-layer seam behind the sidebar.
    local sidebarSurfaceGroup = Utility:Create("CanvasGroup", {
        Name = "SidebarSurface",
        Parent = Sidebar,
        BackgroundTransparency = 1,
        GroupTransparency = 0,
        Size = UDim2.fromScale(1, 1),
        ZIndex = 1,
        BorderSizePixel = 0
    })
    Utility:RegisterMaterial(sidebarSurfaceGroup, 0.32, 0, "GroupTransparency")
    local sidebarRoundedSurface = Utility:Create("Frame", {
        Name = "RoundedSurface",
        Parent = sidebarSurfaceGroup,
        BackgroundColor3 = Library.Theme.Secondary,
        Size = UDim2.fromScale(1, 1),
        ZIndex = 1,
        BorderSizePixel = 0
    })
    Utility:RegisterProperty(sidebarRoundedSurface, "BackgroundColor3", "Secondary")
    Utility:Create("UICorner", {CornerRadius = UDim.new(0, 14), Parent = sidebarRoundedSurface})
    local sidebarGradient = Utility:Create("UIGradient", {Parent = sidebarRoundedSurface, Rotation = 90})
    Utility:RegisterGradient(sidebarGradient, "Secondary", "Main")
    local sidebarSquareEdge = Utility:Create("Frame", {
        Name = "SidebarSquareInnerEdge",
        Parent = sidebarSurfaceGroup,
        BackgroundColor3 = Library.Theme.Secondary,
        Position = UDim2.fromOffset(14, 0),
        Size = UDim2.new(1, -14, 1, 0),
        BorderSizePixel = 0,
        ZIndex = 2
    })
    Utility:RegisterProperty(sidebarSquareEdge, "BackgroundColor3", "Secondary")
    local sidebarSquareGradient = Utility:Create("UIGradient", {Parent = sidebarSquareEdge, Rotation = 90})
    Utility:RegisterGradient(sidebarSquareGradient, "Secondary", "Main")
    local sidebarDivider = Utility:Create("Frame", {
        Parent = Sidebar,
        BackgroundColor3 = Library.Theme.Divider,
        BorderSizePixel = 0,
        Position = UDim2.new(1, -1, 0, 0),
        Size = UDim2.new(0, 1, 1, 0),
        ZIndex = 3
    })
    Utility:RegisterProperty(sidebarDivider, "BackgroundColor3", "Divider")

    local TabContainer = Utility:Create("ScrollingFrame", {
        Name = "Tabs",
        Parent = Sidebar,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, IsMobile and 0 or 8, 0, IsMobile and 70 or 78),
        Size = UDim2.new(1, IsMobile and 0 or -16, 1, IsMobile and -122 or -142),
        ScrollBarThickness = 0,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        ElasticBehavior = Enum.ElasticBehavior.WhenScrollable,
        Active = true,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        ZIndex = 4,
        BorderSizePixel = 0
    })

    local TabLayout = Utility:Create("UIListLayout", {
        Parent = TabContainer,
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, IsMobile and 8 or 6)
    })

    Library:Connect(TabLayout:GetPropertyChangedSignal("AbsoluteContentSize"), function()
        TabContainer.CanvasSize = UDim2.new(0, 0, 0, TabLayout.AbsoluteContentSize.Y + 20)
    end)

    -- NAVIGATION HEADER
    -- One container owns the logo, wordmark, and sidebar toggle. This avoids
    -- stacked corner treatments and guarantees that compact controls never
    -- occupy the same pixels.
    local NavHeader = Utility:Create("Frame", {
        Name = "NavigationHeader",
        Parent = Sidebar,
        BackgroundColor3 = Library.Theme.Surface,
        BackgroundTransparency = 0.56,
        Position = UDim2.fromOffset(8, 10),
        Size = UDim2.new(1, -16, 0, 46),
        ClipsDescendants = true,
        ZIndex = 100,
        BorderSizePixel = 0
    })
    Utility:RegisterProperty(NavHeader, "BackgroundColor3", "Surface")
    Utility:RegisterMaterial(NavHeader, 0.18, 0.56)
    Utility:Create("UICorner", {CornerRadius = UDim.new(0, 10), Parent = NavHeader})
    local navHeaderStroke = Utility:Create("UIStroke", {
        Parent = NavHeader,
        Color = Library.Theme.Stroke,
        Transparency = 0.28,
        Thickness = 1
    })
    Utility:RegisterProperty(navHeaderStroke, "Color", "Stroke")

    -- LOGO
    local logoSize = IsMobile and 28 or (SidebarWidth < 132 and 26 or 36)
    local LogoContainer = Utility:Create("Frame", {
        Name = "LogoContainer",
        Parent = NavHeader,
        BackgroundTransparency = 1,
        Position = IsMobile and UDim2.fromOffset(5, 9)
            or (SidebarWidth < 132 and UDim2.fromOffset(4, 10) or UDim2.fromOffset(7, 5)),
        Size = UDim2.new(0, logoSize, 0, logoSize),
        ZIndex = 100,
        BorderSizePixel = 0
    })
    local Logo = createWindowMark(LogoContainer, IsMobile and 14 or 18, 101)
    Logo.Name = "Logo"

    local BrandLabel = Utility:Create("TextLabel", {
        Parent = NavHeader,
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(52, 4),
        Size = UDim2.new(1, -118, 0, 22),
        Font = Enum.Font.GothamBold,
        Text = Library.Title,
        TextColor3 = Library.Theme.Text,
        TextSize = 15,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Visible = not IsMobile,
        ZIndex = 101
    })
    Utility:RegisterProperty(BrandLabel, "TextColor3", "Text")
    local BrandSubtitle = Utility:Create("TextLabel", {
        Parent = NavHeader,
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(52, 24),
        Size = UDim2.new(1, -118, 0, 16),
        Font = Enum.Font.Gotham,
        Text = "Interface Suite",
        TextColor3 = Library.Theme.SubText,
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Visible = not IsMobile,
        ZIndex = 101
    })
    Utility:RegisterProperty(BrandSubtitle, "TextColor3", "SubText")

    local SidebarModeButton = Utility:Create("TextButton", {
        Name = "SidebarModeButton",
        Parent = NavHeader,
        BackgroundColor3 = Library.Theme.SurfaceAlt,
        BackgroundTransparency = 0.34,
        Position = SidebarMode == "Expanded" and UDim2.new(1, -62, 0, 9) or UDim2.new(1, -32, 0, 9),
        Size = SidebarMode == "Expanded" and UDim2.fromOffset(58, 28) or UDim2.fromOffset(28, 28),
        Text = "",
        AutoButtonColor = false,
        ZIndex = 104,
        BorderSizePixel = 0
    })
    Utility:RegisterProperty(SidebarModeButton, "BackgroundColor3", "SurfaceAlt")
    Utility:Create("UICorner", {CornerRadius = UDim.new(0, 8), Parent = SidebarModeButton})
    local sidebarModeStroke = Utility:Create("UIStroke", {
        Parent = SidebarModeButton,
        Color = Library.Theme.Stroke,
        Transparency = 0.28,
        Thickness = 1
    })
    Utility:RegisterProperty(sidebarModeStroke, "Color", "Stroke")
    local SidebarModeIcon = Utility:Create("ImageLabel", {
        Parent = SidebarModeButton,
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(6, 6),
        Size = UDim2.fromOffset(16, 16),
        Image = ICONS.ChevronRight,
        ImageColor3 = Library.Theme.Text,
        ScaleType = Enum.ScaleType.Fit,
        ZIndex = 105
    })
    Utility:RegisterProperty(SidebarModeIcon, "ImageColor3", "Text")
    local SidebarModeLabel = Utility:Create("TextLabel", {
        Parent = SidebarModeButton,
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(27, 0),
        Size = UDim2.new(1, -32, 1, 0),
        Font = Enum.Font.GothamBold,
        Text = SidebarMode == "Expanded" and "Auto" or "Pin",
        TextColor3 = Library.Theme.Text,
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Left,
        Visible = SidebarMode == "Expanded",
        ZIndex = 105
    })
    Utility:RegisterProperty(SidebarModeLabel, "TextColor3", "Text")

    -- SETTINGS BUTTON
    local settingsBtnSize = IsMobile and 36 or 44
    local SettingsBtn = Utility:Create("TextButton", {
        Name = "SettingsBtn",
        Parent = Sidebar,
        BackgroundColor3 = Library.Theme.Accent,
        BackgroundTransparency = 0.64,
        Position = IsMobile and UDim2.new(0.5, -settingsBtnSize / 2, 1, -(settingsBtnSize + 12)) or UDim2.new(0, 10, 1, -54),
        Size = IsMobile and UDim2.fromOffset(settingsBtnSize, settingsBtnSize) or UDim2.new(1, -20, 0, 42),
        AutoButtonColor = false,
        Text = "",
        ZIndex = 100,
        BorderSizePixel = 0
    })
    Utility:RegisterProperty(SettingsBtn, "BackgroundColor3", "Accent")
    Utility:Create("UICorner", {CornerRadius = UDim.new(0, 8), Parent = SettingsBtn})
    local settingsStroke = Utility:Create("UIStroke", {Parent = SettingsBtn, Color = Library.Theme.Stroke, Thickness = 1})
    Utility:RegisterProperty(settingsStroke, "Color", "Stroke")
    local settingsGradient = Utility:Create("UIGradient", {Parent = SettingsBtn, Rotation = 18})
    Utility:RegisterGradient(settingsGradient, "Accent", "Accent2", "Accent3")

    local SettingsEmoji = Utility:Create("ImageLabel", {
        Parent = SettingsBtn,
        BackgroundTransparency = 1,
        Position = IsMobile and UDim2.fromScale(0.18, 0.18) or UDim2.fromOffset(8, 5),
        Size = IsMobile and UDim2.fromScale(0.64, 0.64) or UDim2.fromOffset(32, 32),
        Image = SettingsIcon,
        ImageColor3 = Library.Theme.SubText,
        ScaleType = Enum.ScaleType.Fit,
        ZIndex = 101
    })
    Utility:RegisterProperty(SettingsEmoji, "ImageColor3", "SubText")

    local SettingsLabel = Utility:Create("TextLabel", {
        Parent = SettingsBtn, BackgroundTransparency = 1,
        Position = UDim2.fromOffset(48, 0), Size = UDim2.new(1, -58, 1, 0),
        Font = Enum.Font.Gotham, Text = "Settings", TextColor3 = Library.Theme.SubText,
        TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left,
        Visible = not IsMobile, ZIndex = 101
    })
    Utility:RegisterProperty(SettingsLabel, "TextColor3", "SubText")

    local SettingsIndicator = Utility:Create("Frame", {
        Parent = SettingsBtn,
        BackgroundColor3 = Library.Theme.Accent,
        Position = UDim2.new(0, 0, 0.5, -10),
        Size = UDim2.new(0, 4, 0, 20),
        BackgroundTransparency = 1,
        ZIndex = 102,
        BorderSizePixel = 0
    })
    Utility:RegisterProperty(SettingsIndicator, "BackgroundColor3", "Accent")
    Utility:Create("UICorner", {CornerRadius = UDim.new(0, 2), Parent = SettingsIndicator})

    -- NATIVE OVERVIEW BUTTON
    -- Overview is pinned with the profile and settings destinations so user
    -- tabs can scroll independently without hiding the session launcher.
    local OverviewBtn = Utility:Create("TextButton", {
        Name = "OverviewBtn",
        Parent = Sidebar,
        BackgroundColor3 = Library.Theme.Accent,
        BackgroundTransparency = 0.64,
        Position = IsMobile and UDim2.new(0.5, -settingsBtnSize / 2, 1, -(settingsBtnSize + 62)) or UDim2.new(0, 10, 1, -102),
        Size = IsMobile and UDim2.fromOffset(settingsBtnSize, settingsBtnSize) or UDim2.new(1, -20, 0, 42),
        AutoButtonColor = false,
        Text = "",
        ZIndex = 100,
        BorderSizePixel = 0
    })
    Utility:RegisterProperty(OverviewBtn, "BackgroundColor3", "Accent")
    Utility:Create("UICorner", {CornerRadius = UDim.new(0, 8), Parent = OverviewBtn})
    local overviewStroke = Utility:Create("UIStroke", {Parent = OverviewBtn, Color = Library.Theme.Stroke, Thickness = 1})
    Utility:RegisterProperty(overviewStroke, "Color", "Stroke")
    local overviewGradient = Utility:Create("UIGradient", {Parent = OverviewBtn, Rotation = 18})
    Utility:RegisterGradient(overviewGradient, "Accent", "Accent2", "Accent3")
    local OverviewIcon = Utility:Create("ImageLabel", {
        Parent = OverviewBtn,
        BackgroundTransparency = 1,
        Position = IsMobile and UDim2.fromScale(0.18, 0.18) or UDim2.fromOffset(8, 5),
        Size = IsMobile and UDim2.fromScale(0.64, 0.64) or UDim2.fromOffset(32, 32),
        Image = ICONS.Dashboard,
        ImageColor3 = Library.Theme.SubText,
        ScaleType = Enum.ScaleType.Fit,
        ZIndex = 101
    })
    Utility:RegisterProperty(OverviewIcon, "ImageColor3", "SubText")
    local OverviewLabel = Utility:Create("TextLabel", {
        Parent = OverviewBtn,
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(48, 0),
        Size = UDim2.new(1, -58, 1, 0),
        Font = Enum.Font.Gotham,
        Text = "Overview",
        TextColor3 = Library.Theme.SubText,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        Visible = not IsMobile,
        ZIndex = 101
    })
    Utility:RegisterProperty(OverviewLabel, "TextColor3", "SubText")
    local OverviewIndicator = Utility:Create("Frame", {
        Parent = OverviewBtn,
        BackgroundColor3 = Library.Theme.Accent,
        Position = UDim2.new(0, 0, 0.5, -10),
        Size = UDim2.new(0, 4, 0, 20),
        BackgroundTransparency = 1,
        ZIndex = 102,
        BorderSizePixel = 0
    })
    Utility:RegisterProperty(OverviewIndicator, "BackgroundColor3", "Accent")
    Utility:Create("UICorner", {CornerRadius = UDim.new(0, 2), Parent = OverviewIndicator})

    -- A single selection surface moves between every navigation destination.
    -- Keeping it outside the UIListLayout lets it travel cleanly across
    -- category gaps and down to the pinned Settings destination.
    local NavigationSelection = Utility:Create("Frame", {
        Name = "NavigationSelection",
        Parent = Sidebar,
        BackgroundColor3 = Library.Theme.Accent,
        BackgroundTransparency = 0.1,
        Position = UDim2.fromOffset(8, 78),
        Size = UDim2.fromOffset(42, 42),
        Visible = false,
        -- Keep the moving surface below the TabContainer sibling group. In
        -- Sibling ZIndex mode, matching the container's ZIndex can place this
        -- later-created frame over every icon and label inside that group.
        ZIndex = 3,
        BorderSizePixel = 0
    })
    Utility:RegisterProperty(NavigationSelection, "BackgroundColor3", "Accent")
    Utility:Create("UICorner", {CornerRadius = UDim.new(0, 8), Parent = NavigationSelection})
    local navigationSelectionStroke = Utility:Create("UIStroke", {
        Parent = NavigationSelection,
        Color = Library.Theme.Accent2,
        Transparency = 0.2,
        Thickness = 1
    })
    Utility:RegisterProperty(navigationSelectionStroke, "Color", "Accent2")
    local navigationSelectionGradient = Utility:Create("UIGradient", {
        Parent = NavigationSelection,
        Rotation = 18
    })
    Utility:RegisterGradient(navigationSelectionGradient, "Accent", "Accent2", "Accent3")
    local NavigationSelectionRail = Utility:Create("Frame", {
        Parent = NavigationSelection,
        BackgroundColor3 = Library.Theme.Text,
        BackgroundTransparency = 0.08,
        Position = UDim2.new(0, 3, 0.5, -9),
        Size = UDim2.fromOffset(3, 18),
        ZIndex = 5,
        BorderSizePixel = 0
    })
    Utility:RegisterProperty(NavigationSelectionRail, "BackgroundColor3", "Text")
    Utility:Create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = NavigationSelectionRail})

    -- USER PROFILE
    local ProfileCard, ProfileAvatar, ProfileNameLabel, ProfileSubtitleLabel, ProfileStroke
    local ProfileCompact = IsMobile
    local SetProfileData = function() end
    if ShowUserProfile then
        ProfileCard = Utility:Create("Frame", {
            Name = "UserProfile",
            Parent = Sidebar,
            BackgroundColor3 = Library.Theme.Surface,
            BackgroundTransparency = ProfileCompact and 1 or 0,
            Position = ProfileCompact and UDim2.new(0.5, -19, 1, -(settingsBtnSize + 112)) or UDim2.new(0, 10, 1, -158),
            Size = ProfileCompact and UDim2.fromOffset(38, 38) or UDim2.new(1, -20, 0, 48),
            ClipsDescendants = true,
            ZIndex = 98,
            BorderSizePixel = 0
        })
        Utility:RegisterProperty(ProfileCard, "BackgroundColor3", "Surface")
        Utility:RegisterMaterial(ProfileCard, 0.28, 0)
        Utility:Create("UICorner", {CornerRadius = UDim.new(0, 9), Parent = ProfileCard})
        ProfileStroke = Utility:Create("UIStroke", {Parent = ProfileCard, Color = Library.Theme.Stroke, Thickness = 1, Enabled = not ProfileCompact})
        Utility:RegisterProperty(ProfileStroke, "Color", "Stroke")

        ProfileAvatar = Utility:Create("ImageLabel", {
            Parent = ProfileCard,
            BackgroundColor3 = Library.Theme.SurfaceAlt,
            Position = ProfileCompact and UDim2.fromOffset(2, 2) or UDim2.fromOffset(6, 6),
            Size = ProfileCompact and UDim2.new(1, -4, 1, -4) or UDim2.fromOffset(36, 36),
            Image = Utility:NormalizeAssetId(options.ProfileAvatar, ICONS.Profile),
            ImageColor3 = Color3.new(1, 1, 1),
            ScaleType = Enum.ScaleType.Crop,
            ZIndex = 99
        })
        Utility:RegisterProperty(ProfileAvatar, "BackgroundColor3", "SurfaceAlt")
        Utility:Create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = ProfileAvatar})
        local avatarStroke = Utility:Create("UIStroke", {Parent = ProfileAvatar, Color = Library.Theme.Accent, Thickness = 1})
        Utility:RegisterProperty(avatarStroke, "Color", "Accent")

        ProfileNameLabel = Utility:Create("TextLabel", {
            Parent = ProfileCard,
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(50, 7),
            Size = UDim2.new(1, -58, 0, 18),
            Font = Enum.Font.GothamMedium,
            Text = tostring(options.ProfileTitle or Plr.DisplayName or Plr.Name),
            TextColor3 = Library.Theme.Text,
            TextSize = 11,
            TextTruncate = Enum.TextTruncate.AtEnd,
            TextXAlignment = Enum.TextXAlignment.Left,
            Visible = not ProfileCompact,
            ZIndex = 99
        })
        Utility:RegisterProperty(ProfileNameLabel, "TextColor3", "Text")
        ProfileSubtitleLabel = Utility:Create("TextLabel", {
            Parent = ProfileCard,
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(50, 24),
            Size = UDim2.new(1, -58, 0, 16),
            Font = Enum.Font.Gotham,
            Text = tostring(options.ProfileSubtitle or ("@" .. Plr.Name)),
            TextColor3 = Library.Theme.SubText,
            TextSize = 9,
            TextTruncate = Enum.TextTruncate.AtEnd,
            TextXAlignment = Enum.TextXAlignment.Left,
            Visible = not ProfileCompact,
            ZIndex = 99
        })
        Utility:RegisterProperty(ProfileSubtitleLabel, "TextColor3", "SubText")

        local ProfileButton = Utility:Create("TextButton", {
            Parent = ProfileCard,
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 1),
            Text = "",
            AutoButtonColor = false,
            ZIndex = 100
        })
        Library:Connect(ProfileButton.MouseEnter, function()
            if not ProfileCompact then Utility:Tween(ProfileCard, TweenInfo.new(0.15), {BackgroundColor3 = Library.Theme.Hover}) end
        end)
        Library:Connect(ProfileButton.MouseLeave, function()
            Utility:Tween(ProfileCard, TweenInfo.new(0.15), {BackgroundColor3 = Library.Theme.Surface})
        end)
        Library:Connect(ProfileButton.MouseButton1Click, function()
            Utility:SafeCall(options.OnProfileClick, Plr)
        end)

        SetProfileData = function(data)
            data = data or {}
            if data.Title ~= nil then ProfileNameLabel.Text = tostring(data.Title) end
            if data.Subtitle ~= nil then ProfileSubtitleLabel.Text = tostring(data.Subtitle) end
            local customAvatar = Utility:NormalizeAssetId(data.Avatar)
            if customAvatar then ProfileAvatar.Image = customAvatar end
        end

        if not Utility:NormalizeAssetId(options.ProfileAvatar) then
            local profileUserId = tonumber(options.ProfileUserId) or Plr.UserId
            task.spawn(function()
                local ok, thumbnail = pcall(function()
                    return Players:GetUserThumbnailAsync(profileUserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
                end)
                if ok and ProfileAvatar and ProfileAvatar.Parent then ProfileAvatar.Image = thumbnail end
            end)
        end
    end

    local navigationLabelTokens = setmetatable({}, {__mode = "k"})
    local function applyLayout(instance, properties, animated)
        if animated then
            Utility:TweenLayout(instance, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), properties)
        else
            Utility:StopLayoutTween(instance)
            for property, value in pairs(properties) do instance[property] = value end
        end
    end

    local function setNavigationLabel(label, visible, animated)
        if not label then return end
        local token = (navigationLabelTokens[label] or 0) + 1
        navigationLabelTokens[label] = token
        if not animated then
            Utility:StopVisibilityTween(label)
            label.Visible = visible
            label.TextTransparency = visible and 0 or 1
            return
        end
        if visible then
            label.Visible = true
            label.TextTransparency = 1
            Utility:TweenVisibility(label, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {TextTransparency = 0})
        else
            Utility:TweenVisibility(label, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {TextTransparency = 1}, function()
                if navigationLabelTokens[label] == token then label.Visible = false end
            end)
        end
    end

    local function getNavigationBottomInset(compact, mobile, hideProfile)
        if ShowUserProfile and not hideProfile then return compact and 224 or 234 end
        return 176
    end

    local function applyProfileLayout(compact, hidden, animated)
        ProfileCompact = compact
        if not ProfileCard then return end
        ProfileCard.Visible = not hidden
        applyLayout(ProfileCard, {
            BackgroundTransparency = compact and 1 or Library:ResolveMaterialTransparency(Library.MaterialRegistry[ProfileCard]),
            Position = compact and UDim2.new(0.5, -19, 1, -(settingsBtnSize + 112)) or UDim2.new(0, 10, 1, -158),
            Size = compact and UDim2.fromOffset(38, 38) or UDim2.new(1, -20, 0, 48)
        }, animated)
        applyLayout(ProfileAvatar, {
            Position = compact and UDim2.fromOffset(2, 2) or UDim2.fromOffset(6, 6),
            Size = compact and UDim2.new(1, -4, 1, -4) or UDim2.fromOffset(36, 36)
        }, animated)
        setNavigationLabel(ProfileNameLabel, not compact, animated)
        setNavigationLabel(ProfileSubtitleLabel, not compact, animated)
        ProfileStroke.Enabled = not compact
    end

    applyProfileLayout(IsMobile)
    TabContainer.Size = UDim2.new(1, IsMobile and 0 or -16, 1, -getNavigationBottomInset(IsMobile, IsMobile))

    -- Content Area
    local Pages = Utility:Create("Frame", {
        Name = "Pages",
        Parent = MainFrame,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, SidebarWidth, 0, 0),
        Size = UDim2.new(1, -SidebarWidth, 1, 0),
        ClipsDescendants = true,
        ZIndex = 1,
        BorderSizePixel = 0
    })

    -- TOP BAR
    local TopBar = Utility:Create("Frame", {
        Name = "TopBar",
        Parent = MainFrame,
        BackgroundColor3 = Library.Theme.Secondary,
        BackgroundTransparency = 0.08,
        Position = UDim2.new(0, SidebarWidth, 0, 0),
        Size = UDim2.new(1, -SidebarWidth, 0, IsMobile and 88 or 60),
        ZIndex = 100,
        BorderSizePixel = 0
    })
    Utility:RegisterProperty(TopBar, "BackgroundColor3", "Secondary")
    Utility:RegisterMaterial(TopBar, 0.4, 0.08)

    Utility:MakeDraggable(TopBar, MainFrame)

    local TitleLabel = Utility:Create("TextLabel", {
        Parent = TopBar,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 20, 0, IsMobile and 13 or 16),
        Size = UDim2.new(0, 200, 0, 30),
        Font = Enum.Font.GothamBold,
        Text = WindowTitle,
        TextColor3 = Library.Theme.Text,
        TextSize = IsMobile and 17 or 19,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 101
    })
    Utility:RegisterProperty(TitleLabel, "TextColor3", "Text")

    local TopDivider = Utility:Create("Frame", {
        Parent = MainFrame,
        BackgroundColor3 = Library.Theme.Divider,
        Position = UDim2.new(0, SidebarWidth, 0, IsMobile and 87 or 59),
        Size = UDim2.new(1, -SidebarWidth, 0, 1),
        BorderSizePixel = 0,
        ZIndex = 90
    })
    Utility:RegisterProperty(TopDivider, "BackgroundColor3", "Divider")

    -- MINIMIZE BUTTON
    local MinimizeBtn = Utility:Create("TextButton", {
        Name = "MinimizeBtn",
        Parent = TopBar,
        BackgroundColor3 = Library.Theme.Surface,
        Position = UDim2.new(1, -80, 0, IsMobile and 10 or 15),
        Size = UDim2.new(0, IsMobile and 26 or 28, 0, IsMobile and 26 or 28),
        AutoButtonColor = false,
        Text = "",
        ZIndex = 101,
        BorderSizePixel = 0
    })
    Utility:RegisterProperty(MinimizeBtn, "BackgroundColor3", "Surface")
    Utility:Create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = MinimizeBtn})
    local minimizeStroke = Utility:Create("UIStroke", {Parent = MinimizeBtn, Color = Library.Theme.Stroke, Thickness = 1})
    Utility:RegisterProperty(minimizeStroke, "Color", "Stroke")

    local MinimizeIcon = Utility:Create("ImageLabel", {
        Parent = MinimizeBtn,
        BackgroundTransparency = 1,
        Position = UDim2.fromScale(0.22, 0.22),
        Size = UDim2.fromScale(0.56, 0.56),
        Image = ICONS.Minimize,
        ImageColor3 = Library.Theme.SubText,
        ScaleType = Enum.ScaleType.Fit,
        ZIndex = 102
    })
    Utility:RegisterProperty(MinimizeIcon, "ImageColor3", "SubText")

    -- CLOSE BUTTON
    local CloseBtn = Utility:Create("TextButton", {
        Name = "CloseBtn",
        Parent = TopBar,
        BackgroundColor3 = Library.Theme.Surface,
        Position = UDim2.new(1, -40, 0, IsMobile and 10 or 15),
        Size = UDim2.new(0, IsMobile and 26 or 28, 0, IsMobile and 26 or 28),
        AutoButtonColor = false,
        Text = "",
        ZIndex = 101,
        BorderSizePixel = 0
    })
    Utility:RegisterProperty(CloseBtn, "BackgroundColor3", "Surface")
    Utility:Create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = CloseBtn})
    local closeStroke = Utility:Create("UIStroke", {Parent = CloseBtn, Color = Library.Theme.Stroke, Thickness = 1})
    Utility:RegisterProperty(closeStroke, "Color", "Stroke")

    local CloseIcon = Utility:Create("ImageLabel", {
        Parent = CloseBtn,
        BackgroundTransparency = 1,
        Position = UDim2.fromScale(0.22, 0.22),
        Size = UDim2.fromScale(0.56, 0.56),
        Image = ICONS.Close,
        ImageColor3 = Library.Theme.SubText,
        ScaleType = Enum.ScaleType.Fit,
        ZIndex = 102
    })
    Utility:RegisterProperty(CloseIcon, "ImageColor3", "SubText")

    -- SEARCH BOX (Global Search)
    local SearchBox = nil
    if EnableGlobalSearch then
        SearchBox = Utility:Create("TextBox", {
            Parent = TopBar,
            BackgroundColor3 = Library.Theme.Surface,
            AnchorPoint = IsMobile and Vector2.new(0, 0) or Vector2.new(0.5, 0),
            Position = IsMobile and UDim2.new(0, 8, 0, 50) or UDim2.new(0.5, 0, 0, 15),
            Size = IsMobile and UDim2.new(1, -16, 0, 30) or UDim2.new(0, 250, 0, 30),
            PlaceholderText = "Search controls...",
            Text = "",
            TextColor3 = Library.Theme.Text,
            Font = Enum.Font.Gotham,
            TextSize = IsMobile and 12 or 14,
            ClearTextOnFocus = false,
            ZIndex = 101,
            BorderSizePixel = 0
        })
        Utility:RegisterProperty(SearchBox, "BackgroundColor3", "Surface")
        Utility:RegisterProperty(SearchBox, "TextColor3", "Text")
        Utility:RegisterProperty(SearchBox, "PlaceholderColor3", "SubText")
        Utility:Create("UICorner", {CornerRadius = UDim.new(0, 6), Parent = SearchBox})
        Utility:Create("UIPadding", {Parent = SearchBox, PaddingLeft = UDim.new(0, 34), PaddingRight = UDim.new(0, 54)})
        local SearchIcon = Utility:Create("ImageLabel", {
            Parent = SearchBox,
            BackgroundTransparency = 1,
            Position = UDim2.new(0, -25, 0.5, -8),
            Size = UDim2.fromOffset(16, 16),
            Image = ICONS.Search,
            ImageColor3 = Library.Theme.SubText,
            ScaleType = Enum.ScaleType.Fit,
            ZIndex = 102
        })
        Utility:RegisterProperty(SearchIcon, "ImageColor3", "SubText")
        local searchStroke = Utility:Create("UIStroke", {Parent = SearchBox, Color = Library.Theme.Stroke, Thickness = 1})
        Utility:RegisterProperty(searchStroke, "Color", "Stroke")
    end

    -- Notification Container
    local NotifyArea = Utility:Create("Frame", {
        Name = "Notifications",
        Parent = ScreenGui,
        BackgroundTransparency = 1,
        Position = UDim2.new(1, IsMobile and -220 or -320, 1, -20),
        Size = UDim2.new(0, IsMobile and 200 or 300, 1, 0),
        AnchorPoint = Vector2.new(1, 1),
        ZIndex = 200
    })
    Utility:Create("UIListLayout", {
        Parent = NotifyArea,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 8),
        VerticalAlignment = Enum.VerticalAlignment.Bottom
    })

    -- Minimized Icon
    local MinimizedIcon = Utility:Create("Frame", {
        Name = "MinimizedIcon",
        Parent = ScreenGui,
        BackgroundColor3 = Library.Theme.Main,
        Position = UDim2.new(1, -70, 0, 20),
        Size = UDim2.new(0, 50, 0, 50),
        Visible = false,
        ZIndex = 300,
        BorderSizePixel = 0
    })
    Utility:RegisterProperty(MinimizedIcon, "BackgroundColor3", "Main")
    Utility:Create("UICorner", {CornerRadius = UDim.new(0, 10), Parent = MinimizedIcon})
    local minIconStroke = Utility:Create("UIStroke", {Parent = MinimizedIcon, Color = Library.Theme.Accent, Thickness = 2})
    Utility:RegisterProperty(minIconStroke, "Color", "Accent")
    local MinimizedLogo = createWindowMark(MinimizedIcon, 20, 301)
    local MinIconBtn = Utility:Create("TextButton", {
        Parent = MinimizedIcon,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, 0),
        Text = "",
        ZIndex = 302
    })

    -- Mobile Toggle Button
    local MobileToggleBtn
    do
        MobileToggleBtn = Utility:Create("Frame", {
            Name = "MobileToggle",
            Parent = ScreenGui,
            BackgroundColor3 = Library.Theme.Main,
            Position = UDim2.new(0, 10, 0.5, -25),
            Size = UDim2.new(0, 40, 0, 40),
            Visible = false,
            ZIndex = 400,
            BorderSizePixel = 0
        })
        Utility:RegisterProperty(MobileToggleBtn, "BackgroundColor3", "Main")
        Utility:Create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = MobileToggleBtn})
        local mobileStroke = Utility:Create("UIStroke", {Parent = MobileToggleBtn, Color = Library.Theme.Accent, Thickness = 2})
        Utility:RegisterProperty(mobileStroke, "Color", "Accent")
        local MobileToggleLogo = createWindowMark(MobileToggleBtn, 16, 401)
        local MobileToggleTapBtn = Utility:Create("TextButton", {
            Parent = MobileToggleBtn,
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 1, 0),
            Text = "",
            ZIndex = 402
        })
        local mobileToggleDrag = Utility:MakeDraggable(MobileToggleTapBtn, MobileToggleBtn)
        Library:Connect(MobileToggleTapBtn.MouseButton1Click, function()
            if mobileToggleDrag:ConsumeDrag() then return end
            if Library.IsMinimized then
                Library.IsMinimized = false
                Library:RefreshMaterialVisibility()
                MinimizedIcon.Visible = false
                MainFrame.Visible = true
                MobileToggleBtn.Visible = false
            else
                MainFrame.Visible = not MainFrame.Visible
                Library.IsMinimized = not MainFrame.Visible
                if not MainFrame.Visible then
                    MobileToggleBtn.Visible = true
                end
                Library:RefreshMaterialVisibility()
            end
        end)
    end

    -- Window Object (declared early so resizer can reference it)
    local Window = {
        Tabs = {},
        TabCategories = {},
        CurrentTabCategory = nil,
        NextNavOrder = 0,
        ActiveTab = nil,
        Gui = ScreenGui,
        Main = MainFrame,
        SettingsTab = nil,
        SearchBox = SearchBox,
        Sidebar = Sidebar,
        SidebarMode = SidebarMode,
        NavigationListeners = {},
        NavigationRevision = 0,
        SearchResults = {},
        SearchQuery = "",
        Commands = {},
        CommandOrder = {},
        Favorites = cloneFeatureValue(Library.Flags.__RenLibFavorites or {}),
        RecentActions = cloneFeatureValue(Library.Flags.__RenLibRecentActions or {}),
        MaxRecentActions = math.max(1, tonumber(options.MaxRecentActions) or 8),
        PhoneCompactEnabled = options.PhoneCompact == nil and true or options.PhoneCompact == true,
        CommandPaletteEnabled = EnableCommandPalette,
        ContentDensity = tostring(options.ContentDensity or "Compact"),
        ContentSpacing = ({Tight = 2, Compact = 5, Comfortable = 8})[tostring(options.ContentDensity or "Compact")] or 5
    }

    local commandPalette, commandSearch, commandResults, commandEmpty
    local function normalizeActionId(value)
        local id = tostring(value or ""):lower():gsub("[^%w]+", "-"):gsub("^%-+", ""):gsub("%-+$", "")
        return id ~= "" and id or ("action-" .. tostring(#Window.CommandOrder + 1))
    end

    function Window:MarkActionUsed(id)
        id = normalizeActionId(id)
        for index = #self.RecentActions, 1, -1 do
            if self.RecentActions[index] == id then table.remove(self.RecentActions, index) end
        end
        table.insert(self.RecentActions, 1, id)
        while #self.RecentActions > self.MaxRecentActions do table.remove(self.RecentActions) end
        Library.Flags.__RenLibRecentActions = cloneFeatureValue(self.RecentActions)
        return self.RecentActions
    end

    function Window:SetFavorite(id, favorite)
        id = normalizeActionId(id)
        self.Favorites[id] = favorite == true or nil
        Library.Flags.__RenLibFavorites = cloneFeatureValue(self.Favorites)
        return self.Favorites[id] == true
    end

    function Window:ToggleFavorite(id)
        return self:SetFavorite(id, not self.Favorites[normalizeActionId(id)])
    end

    function Window:GetFavoriteActions()
        local actions = {}
        for _, id in ipairs(self.CommandOrder) do
            if self.Favorites[id] and self.Commands[id] then table.insert(actions, self.Commands[id]) end
        end
        return actions
    end

    function Window:GetRecentActions()
        local actions = {}
        for _, id in ipairs(self.RecentActions) do
            if self.Commands[id] then table.insert(actions, self.Commands[id]) end
        end
        return actions
    end

    function Window:RegisterCommand(commandOptions)
        commandOptions = commandOptions or {}
        local id = normalizeActionId(commandOptions.Id or commandOptions.Name)
        local command = self.Commands[id]
        if not command then
            command = {Id = id}
            self.Commands[id] = command
            table.insert(self.CommandOrder, id)
        end
        command.Name = tostring(commandOptions.Name or command.Name or id)
        command.Description = tostring(commandOptions.Description or command.Description or "")
        command.Category = tostring(commandOptions.Category or command.Category or "Actions")
        command.Synonyms = commandOptions.Synonyms or commandOptions.Aliases or command.Synonyms or {}
        command.Callback = commandOptions.Callback or command.Callback
        command.Requirement = commandOptions.Requirement
        command.Icon = Utility:NormalizeAssetId(commandOptions.Icon or command.Icon)
        command.Data = commandOptions.Data or command.Data
        return command
    end

    Window.RegisterAction = Window.RegisterCommand

    function Window:ExecuteCommand(idOrCommand)
        local command = type(idOrCommand) == "table" and idOrCommand or self.Commands[normalizeActionId(idOrCommand)]
        if not command then return false, "Unknown command" end
        local requirement = command.Requirement
        if type(requirement) == "function" then
            local ok, allowed, reason = pcall(requirement, command.Data or command, command)
            if not ok then return false, allowed end
            if allowed == false then return false, reason or "Requirements are not met" end
        elseif requirement == false then
            return false, "Requirements are not met"
        end
        self:MarkActionUsed(command.Id)
        local ok, err = Utility:SafeCall(command.Callback, command)
        return ok, err
    end

    local function commandHaystack(command)
        local synonyms = command.Synonyms
        if type(synonyms) == "table" then synonyms = table.concat(synonyms, " ") end
        return table.concat({command.Name or "", command.Description or "", command.Category or "", tostring(synonyms or "")}, " "):lower()
    end

    local function ensureCommandPalette()
        if commandPalette or not EnableCommandPalette then return commandPalette end
        commandPalette = Utility:Create("Frame", {
            Name = "CommandPalette", Parent = MainFrame, AnchorPoint = Vector2.new(0.5, 0),
            Position = UDim2.new(0.5, 0, 0, IsMobile and 48 or 72),
            Size = UDim2.new(1, IsMobile and -18 or -160, 0, IsMobile and 310 or 360),
            BackgroundColor3 = Library.Theme.Secondary, Visible = false,
            ClipsDescendants = true, BorderSizePixel = 0, ZIndex = 410
        })
        Utility:RegisterProperty(commandPalette, "BackgroundColor3", "Secondary")
        Utility:RegisterMaterial(commandPalette, 0.08, 0)
        Utility:Create("UICorner", {Parent = commandPalette, CornerRadius = UDim.new(0, 12)})
        local paletteStroke = Utility:Create("UIStroke", {Parent = commandPalette, Color = Library.Theme.Accent, Thickness = 1.5, Transparency = 0.08})
        Utility:RegisterProperty(paletteStroke, "Color", "Accent")

        local header = Utility:Create("Frame", {
            Parent = commandPalette, BackgroundColor3 = Library.Theme.Surface,
            Size = UDim2.new(1, 0, 0, 52), BorderSizePixel = 0, ZIndex = 411
        })
        Utility:RegisterProperty(header, "BackgroundColor3", "Surface")
        commandSearch = Utility:Create("TextBox", {
            Name = "Search", Parent = header, BackgroundTransparency = 1,
            Position = UDim2.fromOffset(16, 0), Size = UDim2.new(1, -62, 1, 0),
            ClearTextOnFocus = false, PlaceholderText = "Search actions, features, or synonyms…",
            Text = "", TextColor3 = Library.Theme.Text, PlaceholderColor3 = Library.Theme.SubText,
            Font = Enum.Font.Gotham, TextSize = IsMobile and 13 or 14,
            TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 412
        })
        Utility:RegisterProperty(commandSearch, "TextColor3", "Text")
        Utility:RegisterProperty(commandSearch, "PlaceholderColor3", "SubText")
        local closePalette = Utility:Create("TextButton", {
            Parent = header, BackgroundTransparency = 1, Position = UDim2.new(1, -44, 0, 0),
            Size = UDim2.fromOffset(44, 52), Text = "×", TextColor3 = Library.Theme.SubText,
            Font = Enum.Font.GothamBold, TextSize = 22, ZIndex = 412
        })
        Utility:RegisterProperty(closePalette, "TextColor3", "SubText")
        commandResults = Utility:Create("ScrollingFrame", {
            Name = "Results", Parent = commandPalette, BackgroundTransparency = 1,
            Position = UDim2.fromOffset(8, 60), Size = UDim2.new(1, -16, 1, -68),
            CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
            ScrollBarThickness = 2, ScrollBarImageColor3 = Library.Theme.Accent,
            BorderSizePixel = 0, ZIndex = 411
        })
        Utility:RegisterProperty(commandResults, "ScrollBarImageColor3", "Accent")
        Utility:Create("UIListLayout", {Parent = commandResults, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6)})
        commandEmpty = Utility:Create("TextLabel", {
            Name = "Empty", Parent = commandResults, BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 56), Text = "No matching actions",
            TextColor3 = Library.Theme.SubText, Font = Enum.Font.Gotham,
            TextSize = 12, Visible = false, ZIndex = 412
        })
        Utility:RegisterProperty(commandEmpty, "TextColor3", "SubText")
        Library:Connect(closePalette.MouseButton1Click, function() Window:CloseCommandPalette() end)
        Library:Connect(commandSearch:GetPropertyChangedSignal("Text"), function() Window:RefreshCommandPalette(commandSearch.Text) end)
        Library:Connect(commandSearch.FocusLost, function(enterPressed)
            if not enterPressed then return end
            local first = commandResults and commandResults:FindFirstChild("CommandResult")
            if first then Window:ExecuteCommand(first:GetAttribute("CommandId")); Window:CloseCommandPalette() end
        end)
        return commandPalette
    end

    function Window:RefreshCommandPalette(query)
        if not ensureCommandPalette() then return {} end
        query = tostring(query or ""):lower():match("^%s*(.-)%s*$") or ""
        for _, child in ipairs(commandResults:GetChildren()) do
            if child.Name == "CommandResult" then child:Destroy() end
        end
        local matches = {}
        for _, id in ipairs(self.CommandOrder) do
            local command = self.Commands[id]
            if command and (query == "" or commandHaystack(command):find(query, 1, true)) then table.insert(matches, command) end
        end
        table.sort(matches, function(a, b)
            local af, bf = self.Favorites[a.Id] == true, self.Favorites[b.Id] == true
            if af ~= bf then return af end
            local ar, br = table.find(self.RecentActions, a.Id), table.find(self.RecentActions, b.Id)
            if (ar ~= nil) ~= (br ~= nil) then return ar ~= nil end
            if ar and br and ar ~= br then return ar < br end
            return a.Name:lower() < b.Name:lower()
        end)
        local limit = IsMobile and 5 or 7
        for index, command in ipairs(matches) do
            if index > limit then break end
            local row = Utility:Create("TextButton", {
                Name = "CommandResult", Parent = commandResults, BackgroundColor3 = Library.Theme.Surface,
                Size = UDim2.new(1, -4, 0, IsMobile and 44 or 48), Text = "", AutoButtonColor = false,
                LayoutOrder = index, BorderSizePixel = 0, ZIndex = 412
            })
            row:SetAttribute("CommandId", command.Id)
            Utility:RegisterProperty(row, "BackgroundColor3", "Surface")
            Utility:Create("UICorner", {Parent = row, CornerRadius = UDim.new(0, 7)})
            local label = Utility:Create("TextLabel", {
                Parent = row, BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 5),
                Size = UDim2.new(1, -54, 0, 19), Text = command.Name,
                TextColor3 = Library.Theme.Text, Font = Enum.Font.GothamMedium,
                TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 413
            })
            Utility:RegisterProperty(label, "TextColor3", "Text")
            local detail = Utility:Create("TextLabel", {
                Parent = row, BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 23),
                Size = UDim2.new(1, -54, 0, 16), Text = command.Category .. (command.Description ~= "" and ("  •  " .. command.Description) or ""),
                TextColor3 = Library.Theme.SubText, Font = Enum.Font.Gotham, TextSize = 10,
                TextTruncate = Enum.TextTruncate.AtEnd, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 413
            })
            Utility:RegisterProperty(detail, "TextColor3", "SubText")
            local star = Utility:Create("TextButton", {
                Parent = row, BackgroundTransparency = 1, Position = UDim2.new(1, -42, 0, 0),
                Size = UDim2.fromOffset(42, IsMobile and 44 or 48), Text = self.Favorites[command.Id] and "★" or "☆",
                TextColor3 = Library.Theme.Warn, Font = Enum.Font.GothamBold, TextSize = 17, ZIndex = 414
            })
            Utility:RegisterProperty(star, "TextColor3", "Warn")
            Library:Connect(star.MouseButton1Click, function()
                Window:ToggleFavorite(command.Id)
                Window:RefreshCommandPalette(query)
            end)
            Library:Connect(row.MouseButton1Click, function()
                local ok, err = Window:ExecuteCommand(command)
                if not ok then Library:Notify({Title = "Action unavailable", Content = tostring(err), Duration = 3}) end
                Window:CloseCommandPalette()
            end)
            Library:Connect(row.MouseEnter, function() Utility:Tween(row, TweenInfo.new(0.12), {BackgroundColor3 = Library.Theme.Hover}) end)
            Library:Connect(row.MouseLeave, function() Utility:Tween(row, TweenInfo.new(0.12), {BackgroundColor3 = Library.Theme.Surface}) end)
        end
        commandEmpty.Visible = #matches == 0
        return matches
    end

    function Window:OpenCommandPalette(query)
        if not self.CommandPaletteEnabled or not ensureCommandPalette() then return false end
        commandPalette.Position = UDim2.new(0.5, 0, 0, Library.DeviceMode == "Phone" and 42 or 72)
        commandPalette.Size = UDim2.new(1, Library.DeviceMode == "Phone" and -14 or -160, 0, Library.DeviceMode == "Phone" and 292 or 360)
        commandPalette.Visible = true
        commandSearch.Text = tostring(query or "")
        self:RefreshCommandPalette(commandSearch.Text)
        task.defer(function() if commandSearch and commandSearch.Parent then commandSearch:CaptureFocus() end end)
        return true
    end

    function Window:CloseCommandPalette()
        if commandPalette then commandPalette.Visible = false end
        if commandSearch then commandSearch:ReleaseFocus() end
        return self
    end

    function Window:ToggleCommandPalette()
        if commandPalette and commandPalette.Visible then return self:CloseCommandPalette() end
        self:OpenCommandPalette("")
        return self
    end

    local PaletteOpenButton
    if EnableCommandPalette then
        PaletteOpenButton = Utility:Create("TextButton", {
            Name = "PhoneCommandPalette", Parent = ScreenGui, AnchorPoint = Vector2.new(1, 1),
            Position = UDim2.new(1, -12, 1, -12), Size = UDim2.fromOffset(42, 42),
            BackgroundColor3 = Library.Theme.Accent, Text = "⌘", TextColor3 = Library.Theme.Text,
            Font = Enum.Font.GothamBold, TextSize = 18, AutoButtonColor = false,
            Visible = DeviceMode == "Phone", BorderSizePixel = 0, ZIndex = 405
        })
        Utility:RegisterProperty(PaletteOpenButton, "BackgroundColor3", "Accent")
        Utility:RegisterProperty(PaletteOpenButton, "TextColor3", "Text")
        Utility:Create("UICorner", {Parent = PaletteOpenButton, CornerRadius = UDim.new(1, 0)})
        Library:Connect(PaletteOpenButton.MouseButton1Click, function() Window:ToggleCommandPalette() end)
        Library:Connect(UserInputService.InputBegan, function(input, processed)
            if input.KeyCode == Enum.KeyCode.Escape and commandPalette and commandPalette.Visible then
                Window:CloseCommandPalette()
            elseif not processed and input.KeyCode == Enum.KeyCode.K
                and (UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)) then
                Window:ToggleCommandPalette()
            end
        end)
    end
    Library:Connect(UserInputService.InputBegan, function(input, processed)
        if processed or input.KeyCode ~= Enum.KeyCode.Tab then return end
        if not (UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)) then return end
        local backwards = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
        if backwards then Window:PreviousTab() else Window:NextTab() end
    end)

    function Window:OnTabChanged(callback)
        if type(callback) == "function" then table.insert(self.NavigationListeners, callback) end
        return self
    end

    function Window:SelectTab(tab, selectOptions)
        selectOptions = selectOptions or {}
        if tab ~= nil then
            local known = false
            for _, candidate in ipairs(self.Tabs) do
                if candidate == tab then known = true break end
            end
            if not known then return false, "Unknown tab" end
        end

        local previous = self.ActiveTab
        self.NavigationRevision = self.NavigationRevision + 1
        self.ActiveTab = tab

        for _, candidate in ipairs(self.Tabs) do
            local active = candidate == tab
            candidate.Active = active
            if candidate.Page then candidate.Page.Visible = active end
            if candidate.ApplyActiveVisual then candidate:ApplyActiveVisual(active, selectOptions.Animate ~= false) end
        end

        if tab then
            TitleLabel.Text = tab.Name
            if selectOptions.ResetScroll ~= false and tab.Page then tab.Page.CanvasPosition = Vector2.new(0, 0) end
            task.defer(function()
                if Window.ActiveTab == tab and not Library.Unloaded then
                    Window:MoveNavigationSelection(selectOptions.Animate ~= false)
                end
            end)
        else
            NavigationSelection.Visible = false
        end

        if previous ~= tab then
            for _, callback in ipairs(self.NavigationListeners) do
                Utility:SafeCall(callback, tab, previous, self.NavigationRevision)
            end
        end
        return true
    end

    function Window:GetTab(name)
        local target = tostring(name or ""):lower()
        for _, tab in ipairs(self.Tabs) do
            if tostring(tab.Name):lower() == target then return tab end
        end
        return nil
    end

    function Window:SelectTabByName(name, selectOptions)
        local tab = self:GetTab(name)
        if not tab then return false, "Unknown tab: " .. tostring(name) end
        return self:SelectTab(tab, selectOptions)
    end

    function Window:CycleTab(direction)
        local navigable = {}
        for _, tab in ipairs(self.Tabs) do
            if not tab.IsSettings and not tab.IsOverview then table.insert(navigable, tab) end
        end
        if #navigable == 0 then return false end
        local currentIndex = table.find(navigable, self.ActiveTab) or 0
        local nextIndex = ((currentIndex - 1 + (tonumber(direction) or 1)) % #navigable) + 1
        return navigable[nextIndex]:Activate({ResetScroll = false, Animate = true})
    end

    function Window:NextTab() return self:CycleTab(1) end
    function Window:PreviousTab() return self:CycleTab(-1) end

    local navigationSelectionToken = 0
    function Window:MoveNavigationSelection(animate)
        local active = self.ActiveTab
        local button = active and active.TabBtn
        if not button or not button.Parent or not Sidebar.Parent then
            NavigationSelection.Visible = false
            return
        end
        local effectiveScale = math.max(Library.DPIScale * WindowScale.Scale, 0.01)
        local offset = button.AbsolutePosition - Sidebar.AbsolutePosition
        local absoluteSize = button.AbsoluteSize
        if absoluteSize.X < 1 or absoluteSize.Y < 1 then return end
        local target = {
            Position = UDim2.fromOffset(offset.X / effectiveScale, offset.Y / effectiveScale),
            Size = UDim2.fromOffset(absoluteSize.X / effectiveScale, absoluteSize.Y / effectiveScale)
        }
        NavigationSelection.Visible = true
        if animate then
            Utility:Tween(NavigationSelection, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), target)
        else
            Utility:StopTween(NavigationSelection)
            NavigationSelection.Position = target.Position
            NavigationSelection.Size = target.Size
        end
    end

    function Window:TrackNavigationSelection(duration)
        navigationSelectionToken = navigationSelectionToken + 1
        local token = navigationSelectionToken
        task.spawn(function()
            local started = os.clock()
            repeat
                RunService.RenderStepped:Wait()
                if token ~= navigationSelectionToken or Library.Unloaded then return end
                Window:MoveNavigationSelection(false)
            until os.clock() - started >= (duration or 0.32)
            Window:MoveNavigationSelection(false)
        end)
    end

    Library:Connect(TabContainer:GetPropertyChangedSignal("CanvasPosition"), function()
        Window:MoveNavigationSelection(false)
    end)

    function Window:GetLayoutDiagnostics()
        local issues = {}
        local function add(code, message)
            table.insert(issues, {Code = code, Message = message})
        end
        local function overlaps(a, b, padding)
            padding = padding or 0
            local ap, as = a.AbsolutePosition, a.AbsoluteSize
            local bp, bs = b.AbsolutePosition, b.AbsoluteSize
            return ap.X + as.X + padding > bp.X
                and bp.X + bs.X + padding > ap.X
                and ap.Y + as.Y + padding > bp.Y
                and bp.Y + bs.Y + padding > ap.Y
        end
        if Library.DPIScale < 1 then
            add("scale-floor", "UI scale is below the supported 100% minimum")
        end
        if MainFrame.ClipsDescendants ~= true then
            add("shell-clip", "The root shell is not clipping internal chrome to its corner")
        end
        if SidebarModeButton.Visible and overlaps(LogoContainer, SidebarModeButton, 2) then
            add("nav-header-overlap", "The brand mark and sidebar-mode control overlap")
        end
        if BrandLabel.Visible and SidebarModeButton.Visible and overlaps(BrandLabel, SidebarModeButton, 2) then
            add("nav-header-label-overlap", "The sidebar-mode control overlaps the RenLib wordmark")
        end
        if SidebarModeButton.Visible and (SidebarModeButton.AbsoluteSize.X < 28 or SidebarModeButton.AbsoluteSize.Y < 28) then
            add("nav-toggle-hit-area", "The sidebar-mode control is smaller than its safe pointer target")
        end
        if self.SidebarVisualExpanded and self.ActiveTab and self.ActiveTab.TabBtn
            and self.ActiveTab.TabBtn.AbsoluteSize.X < Sidebar.AbsoluteSize.X * 0.6 then
            add("active-tab-state", "The selected tab is still using compact geometry inside an expanded sidebar")
        end
        if self.SidebarVisualExpanded and ProfileCard and ProfileCard.Visible
            and ProfileCard.AbsoluteSize.X < Sidebar.AbsoluteSize.X * 0.6 then
            add("profile-state", "The profile card is still using compact geometry inside an expanded sidebar")
        end
        if OverviewBtn.Visible and overlaps(OverviewBtn, SettingsBtn, 4) then
            add("native-navigation-overlap", "Overview and Settings overlap")
        end
        if ProfileCard and ProfileCard.Visible and overlaps(ProfileCard, OverviewBtn, 4) then
            add("profile-overview-overlap", "The profile card overlaps Overview")
        end
        local seamDistance = math.abs((Sidebar.AbsolutePosition.X + Sidebar.AbsoluteSize.X) - TopBar.AbsolutePosition.X)
        if seamDistance > 2 then
            add("chrome-seam", "The sidebar and top bar no longer share one seam")
        end
        return #issues == 0, issues
    end

    function Window:SetProfile(data)
        SetProfileData(data)
    end

    function Window:RefreshThemeState()
        for _, tab in ipairs(self.Tabs) do
            local textKey = tab.Active and "Text" or "SubText"
            if tab.TabLabel then tab.TabLabel.TextColor3 = Library.Theme[textKey] end
            if tab.TabEmoji then
                if tab.TabEmoji:IsA("TextLabel") then
                    tab.TabEmoji.TextColor3 = Library.Theme[textKey]
                elseif tab.TabEmoji:IsA("ImageLabel") then
                    tab.TabEmoji.ImageColor3 = Library.Theme[textKey]
                end
            end
            if tab.TabBtn then tab.TabBtn.BackgroundTransparency = tab.Active and 1 or 0.64 end
            if tab.TabStroke then
                tab.TabStroke.Color = tab.Active and Library.Theme.Accent or Library.Theme.Stroke
                tab.TabStroke.Transparency = tab.Active and 0.08 or 0.24
            end
        end
        self:MoveNavigationSelection(false)
    end

    -- RESIZABLE SIDEBAR (PC only)
    local sidebarResizer = nil
    local dividerLine = nil
    local currentSidebarWidth = math.clamp(tonumber(options.SidebarWidth) or 190, 132, 240)
    local sidebarHoverExpanded = false
    local isCompact = IsMobile or SidebarMode ~= "Expanded"
    if EnableSidebarResize and not IsMobile then
        dividerLine = Utility:Create("Frame", {
            Parent = MainFrame,
            BackgroundColor3 = Library.Theme.Stroke,
            BackgroundTransparency = 1,
            Position = UDim2.new(0, SidebarWidth, 0, 0),
            Size = UDim2.new(0, 1, 1, 0),
            ZIndex = 5,
            BorderSizePixel = 0
        })
        sidebarResizer = Utility:Create("TextButton", {
            Parent = dividerLine,
            BackgroundTransparency = 1,
            Size = UDim2.new(0, 4, 1, 0),
            Position = UDim2.new(1, -2, 0, 0),
            Text = "",
            ZIndex = 6,
            AutoButtonColor = false
        })
        local dragging = false
        local startX, startWidth
        Library:Connect(sidebarResizer.InputBegan, function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 and not isCompact then
                dragging = true
                startX = input.Position.X
                startWidth = currentSidebarWidth
                Library:Connect(input.Changed, function()
                    if input.UserInputState == Enum.UserInputState.End then
                        dragging = false
                    end
                end)
            end
        end)
        Library:Connect(UserInputService.InputChanged, function(input)
            if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
                local delta = input.Position.X - startX
                local newWidth = math.clamp(startWidth + delta, 62, 240)
                currentSidebarWidth = newWidth
                SidebarMode = "Expanded"
                Window.SidebarMode = SidebarMode
                Window:ApplyResponsiveLayout(false)
            end
        end)
    end

    local lastDeviceMode = DeviceMode

    function Window:ApplyResponsiveLayout(recenter, animateNavigation)
        local viewport = getViewport()
        local scale = math.max(Library.DPIScale, 0.01)
        local layoutViewport = Vector2.new(viewport.X / scale, viewport.Y / scale)
        local mode = getDeviceMode(scale)
        local mobile = mode ~= "Desktop"
        local phoneCompact = mode == "Phone" and self.PhoneCompactEnabled
        local horizontalMargin = phoneCompact and 3 or (mobile and 6 or 16)
        local verticalMargin = phoneCompact and 3 or (mobile and 6 or 16)
        local maximumWidth = math.max(1, layoutViewport.X - horizontalMargin * 2)
        local maximumHeight = math.max(1, layoutViewport.Y - verticalMargin * 2)
        local width = math.min(mobile and 720 or (options.Width or 880), maximumWidth)
        local height = math.min(mobile and 680 or (options.Height or 580), maximumHeight)
        if self.Maximized then
            width = maximumWidth
            height = maximumHeight
        end
        local navigationExpanded = SidebarMode == "Expanded" or (SidebarMode == "Dynamic" and sidebarHoverExpanded)
        local sidebarWidth = phoneCompact and 52 or (mobile and (width < 340 and 54 or 60))
            or (navigationExpanded and math.clamp(currentSidebarWidth, 132, math.min(240, width * 0.32)) or 80)
        local shortViewport = mobile and height < 420
        local hideSearch = mobile and height < 300
        local hideProfile = height < 380
        local topBarHeight = mobile and (hideSearch and 48 or (shortViewport and 72 or (phoneCompact and 82 or 88))) or 60
        Window.ContentTopInset = topBarHeight

        DeviceMode = mode
        IsMobile = mobile
        Library.DeviceMode = mode
        Library.IsMobile = mobile
        MainFrame.Size = UDim2.fromOffset(width, height)
        local absolutePosition = MainFrame.AbsolutePosition
        local absoluteSize = MainFrame.AbsoluteSize
        local unreachable = absolutePosition.X + absoluteSize.X < 40
            or absolutePosition.Y + 40 < 0
            or absolutePosition.X > viewport.X - 40
            or absolutePosition.Y > viewport.Y - 40
        if recenter or unreachable then
            MainFrame.Position = UDim2.new(0.5, -width / 2, 0.5, -height / 2)
        end
        applyLayout(Sidebar, {Size = UDim2.new(0, sidebarWidth, 1, 0)}, animateNavigation)
        applyLayout(Pages, {
            Position = UDim2.new(0, sidebarWidth, 0, 0),
            Size = UDim2.new(1, -sidebarWidth, 1, 0)
        }, animateNavigation)
        isCompact = mobile or sidebarWidth < 132
        local visibleContentWidth = math.max(1, (width - sidebarWidth) * scale)
        local singleColumn = mobile or visibleContentWidth < 640
        applyLayout(TopBar, {
            Position = UDim2.new(0, sidebarWidth, 0, 0),
            Size = UDim2.new(1, -sidebarWidth, 0, topBarHeight)
        }, animateNavigation)
        applyLayout(TitleLabel, {
            Position = UDim2.new(0, 16, 0, mobile and (hideSearch and 9 or 11) or 16),
            Size = UDim2.new(1, -(mobile and 108 or 430), 0, 30)
        }, animateNavigation)
        TitleLabel.TextSize = phoneCompact and 15 or (mobile and 17 or 19)
        applyLayout(TopDivider, {
            Position = UDim2.new(0, sidebarWidth, 0, topBarHeight - 1),
            Size = UDim2.new(1, -sidebarWidth, 0, 1)
        }, animateNavigation)
        MinimizeBtn.Position = UDim2.new(1, -76, 0, mobile and 8 or 15)
        CloseBtn.Position = UDim2.new(1, -40, 0, mobile and 8 or 15)
        local activeLogoSize = mobile and 28 or (isCompact and 26 or 36)
        local showWordmark = not isCompact and sidebarWidth >= 174
        applyLayout(LogoContainer, {
            Size = UDim2.fromOffset(activeLogoSize, activeLogoSize),
            Position = mobile and UDim2.new(0.5, -activeLogoSize / 2, 0, 9)
                or (isCompact and UDim2.fromOffset(4, 10) or UDim2.fromOffset(7, 5))
        }, animateNavigation)
        setNavigationLabel(BrandLabel, showWordmark, animateNavigation)
        setNavigationLabel(BrandSubtitle, showWordmark, animateNavigation)
        SidebarModeButton.Visible = not mobile
        SidebarModeLabel.Text = SidebarMode == "Expanded" and "Auto" or "Pin"
        applyLayout(SidebarModeButton, {
            Position = isCompact and UDim2.new(1, -32, 0, 9) or UDim2.new(1, -62, 0, 9),
            Size = isCompact and UDim2.fromOffset(28, 28) or UDim2.fromOffset(58, 28)
        }, animateNavigation)
        applyLayout(SidebarModeIcon, {
            Position = isCompact and UDim2.fromOffset(6, 6) or UDim2.fromOffset(7, 6),
            Size = UDim2.fromOffset(16, 16),
            Rotation = isCompact and 0 or 180
        }, animateNavigation)
        setNavigationLabel(SidebarModeLabel, not isCompact, animateNavigation)
        applyLayout(TabContainer, {
            Position = UDim2.new(0, isCompact and 0 or 8, 0, mobile and 70 or 68),
            Size = UDim2.new(1, isCompact and 0 or -16, 1, -getNavigationBottomInset(isCompact, mobile, hideProfile))
        }, animateNavigation)
        applyLayout(SettingsBtn, {
            Position = isCompact and UDim2.new(0.5, -settingsBtnSize / 2, 1, -(settingsBtnSize + 12)) or UDim2.new(0, 10, 1, -54),
            Size = isCompact and UDim2.fromOffset(settingsBtnSize, settingsBtnSize) or UDim2.new(1, -20, 0, 42)
        }, animateNavigation)
        applyLayout(SettingsEmoji, {
            Position = isCompact and UDim2.fromScale(0.18, 0.18) or UDim2.fromOffset(8, 5),
            Size = isCompact and UDim2.fromScale(0.64, 0.64) or UDim2.fromOffset(32, 32)
        }, animateNavigation)
        setNavigationLabel(SettingsLabel, not isCompact, animateNavigation)
        applyLayout(OverviewBtn, {
            Position = isCompact and UDim2.new(0.5, -settingsBtnSize / 2, 1, -(settingsBtnSize + 62)) or UDim2.new(0, 10, 1, -102),
            Size = isCompact and UDim2.fromOffset(settingsBtnSize, settingsBtnSize) or UDim2.new(1, -20, 0, 42)
        }, animateNavigation)
        applyLayout(OverviewIcon, {
            Position = isCompact and UDim2.fromScale(0.18, 0.18) or UDim2.fromOffset(8, 5),
            Size = isCompact and UDim2.fromScale(0.64, 0.64) or UDim2.fromOffset(32, 32)
        }, animateNavigation)
        setNavigationLabel(OverviewLabel, not isCompact, animateNavigation)
        applyProfileLayout(isCompact, hideProfile, animateNavigation)
        NotifyArea.Position = UDim2.new(1, mobile and -12 or -20, 1, -20)
        NotifyArea.Size = UDim2.new(0, mobile and math.max(180, math.min(300, layoutViewport.X - 24)) or 300, 1, 0)
        if SearchBox then
            SearchBox.Visible = not hideSearch
            SearchBox.AnchorPoint = mobile and Vector2.new(0, 0) or Vector2.new(0.5, 0)
            SearchBox.Position = mobile and UDim2.new(0, 8, 0, shortViewport and 41 or 50)
                or UDim2.new(0.5, 0, 0, 15)
            SearchBox.Size = mobile and UDim2.new(1, -16, 0, shortViewport and 26 or (phoneCompact and 28 or 30)) or UDim2.new(0, 270, 0, 30)
        end
        if PaletteOpenButton then PaletteOpenButton.Visible = mode == "Phone" and MainFrame.Visible end
        if dividerLine then
            dividerLine.Visible = not mobile and not isCompact
            dividerLine.Position = UDim2.new(0, sidebarWidth, 0, 0)
        end
        for _, tab in ipairs(Window.Tabs) do
            if tab.ApplyNavigationLayout then tab:ApplyNavigationLayout(mobile, isCompact, animateNavigation) end
            if tab.ApplyResponsiveLayout then
                tab:ApplyResponsiveLayout(singleColumn, topBarHeight, phoneCompact)
            end
        end
        for _, category in ipairs(Window.TabCategories) do
            category.Label.Visible = true
            applyLayout(category.Label, {
                Size = UDim2.new(1, -8, 0, isCompact and 0 or 20),
                TextTransparency = isCompact and 1 or 0
            }, animateNavigation)
        end
        if animateNavigation then
            self:TrackNavigationSelection(0.34)
        else
            task.defer(function() if not Library.Unloaded then self:MoveNavigationSelection(false) end end)
        end
        self.SidebarVisualExpanded = not isCompact
        if Library.IsMinimized then
            MobileToggleBtn.Visible = mobile
            MinimizedIcon.Visible = not mobile
        end
        if mode ~= lastDeviceMode then
            lastDeviceMode = mode
            Utility:SafeCall(options.OnDeviceChanged, mode)
        end
        task.delay(animateNavigation and 0.34 or 0, function()
            if not Library.Unloaded then
                local passed, issues = self:GetLayoutDiagnostics()
                self.LastLayoutAudit = {Passed = passed, Issues = issues, CheckedAt = os.clock()}
            end
        end)
        return mode
    end

    function Window:SetSidebarMode(mode)
        mode = tostring(mode or "Dynamic")
        if mode ~= "Dynamic" and mode ~= "Expanded" and mode ~= "Compact" then return false end
        SidebarMode = mode
        self.SidebarMode = mode
        sidebarHoverExpanded = false
        SidebarModeLabel.Text = mode == "Expanded" and "Auto" or "Pin"
        self:ApplyResponsiveLayout(false, true)
        return true
    end

    function Window:SetPhoneCompact(enabled)
        self.PhoneCompactEnabled = enabled == true
        self:ApplyResponsiveLayout(false, true)
        return self
    end

    local sidebarHoverToken = 0
    local function setSidebarHover(expanded)
        if SidebarMode ~= "Dynamic" or IsMobile then return end
        sidebarHoverToken = sidebarHoverToken + 1
        local token = sidebarHoverToken
        if expanded then
            if not sidebarHoverExpanded then
                sidebarHoverExpanded = true
                Window:ApplyResponsiveLayout(false, true)
            end
        else
            task.delay(0.35, function()
                if token == sidebarHoverToken and SidebarMode == "Dynamic" then
                    sidebarHoverExpanded = false
                    Window:ApplyResponsiveLayout(false, true)
                end
            end)
        end
    end

    -- Hover expansion belongs to navigation content, not the mode button.
    -- The compact button therefore stays under the pointer and can be clicked
    -- immediately instead of moving away on the first hover.
    Library:Connect(TabContainer.MouseEnter, function() setSidebarHover(true) end)
    Library:Connect(TabContainer.MouseLeave, function() setSidebarHover(false) end)
    Library:Connect(SettingsBtn.MouseEnter, function() setSidebarHover(true) end)
    Library:Connect(SettingsBtn.MouseLeave, function() setSidebarHover(false) end)
    Library:Connect(OverviewBtn.MouseEnter, function() setSidebarHover(true) end)
    Library:Connect(OverviewBtn.MouseLeave, function() setSidebarHover(false) end)
    if ProfileCard then
        Library:Connect(ProfileCard.MouseEnter, function() setSidebarHover(true) end)
        Library:Connect(ProfileCard.MouseLeave, function() setSidebarHover(false) end)
    end
    Library:Connect(NavHeader.MouseEnter, function()
        if sidebarHoverExpanded then sidebarHoverToken = sidebarHoverToken + 1 end
    end)
    Library:Connect(NavHeader.MouseLeave, function()
        if sidebarHoverExpanded then setSidebarHover(false) end
    end)
    Library:Connect(SidebarModeButton.MouseEnter, function()
        Utility:Tween(SidebarModeButton, TweenInfo.new(0.14), {BackgroundTransparency = 0.12})
        Utility:Tween(sidebarModeStroke, TweenInfo.new(0.14), {Transparency = 0.05})
    end)
    Library:Connect(SidebarModeButton.MouseLeave, function()
        Utility:Tween(SidebarModeButton, TweenInfo.new(0.14), {BackgroundTransparency = 0.34})
        Utility:Tween(sidebarModeStroke, TweenInfo.new(0.14), {Transparency = 0.28})
    end)
    Library:Connect(SidebarModeButton.MouseButton1Click, function()
        Window:SetSidebarMode(SidebarMode == "Expanded" and "Dynamic" or "Expanded")
    end)

    function Window:SetTitle(title)
        WindowTitle = tostring(title)
        TitleLabel.Text = WindowTitle
    end

    function Window:SetVisible(visible)
        if visible then Window:Restore() else Window:Minimize() end
    end

    function Window:SetSearch(query)
        if SearchBox then SearchBox.Text = tostring(query or "") end
    end

    local normalPosition = MainFrame.Position
    local normalSize = MainFrame.Size
    function Window:SetMaximized(maximized)
        if maximized and not self.Maximized then
            normalPosition = MainFrame.Position
            normalSize = MainFrame.Size
        end
        self.Maximized = maximized == true
        local viewport = getViewport()
        local scale = math.max(Library.DPIScale, 0.01)
        local margin = 8 / scale
        Utility:Tween(MainFrame, TweenInfo.new(0.28, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
            Position = self.Maximized and UDim2.fromOffset(margin, margin) or normalPosition,
            Size = self.Maximized and UDim2.fromOffset(viewport.X / scale - margin * 2, viewport.Y / scale - margin * 2) or normalSize
        })
    end

    local TooltipFrame = Utility:Create("Frame", {
        Name = "Tooltip", Parent = ScreenGui, BackgroundColor3 = Library.Theme.Secondary,
        BackgroundTransparency = 0.04, AutomaticSize = Enum.AutomaticSize.XY,
        Visible = false, ZIndex = 950, BorderSizePixel = 0
    })
    Utility:RegisterProperty(TooltipFrame, "BackgroundColor3", "Secondary")
    Utility:Create("UICorner", {Parent = TooltipFrame, CornerRadius = UDim.new(0, 6)})
    local tooltipStroke = Utility:Create("UIStroke", {Parent = TooltipFrame, Color = Library.Theme.Stroke, Thickness = 1})
    Utility:RegisterProperty(tooltipStroke, "Color", "Stroke")
    Utility:Create("UIPadding", {
        Parent = TooltipFrame, PaddingLeft = UDim.new(0, 9), PaddingRight = UDim.new(0, 9),
        PaddingTop = UDim.new(0, 7), PaddingBottom = UDim.new(0, 7)
    })
    local TooltipText = Utility:Create("TextLabel", {
        Parent = TooltipFrame, BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.Y,
        Size = UDim2.fromOffset(220, 0), TextWrapped = true, TextColor3 = Library.Theme.Text,
        Font = Enum.Font.Gotham, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 951
    })
    Utility:RegisterProperty(TooltipText, "TextColor3", "Text")
    local activeTooltipTarget = nil

    function Window:ShowTooltip(text, position, target)
        text = tostring(text or "")
        if text == "" then return end
        activeTooltipTarget = target
        TooltipText.Text = text
        TooltipFrame.Visible = true
        task.defer(function()
            if not TooltipFrame.Visible or (target and activeTooltipTarget ~= target) then return end
            local viewport = getViewport()
            local size = TooltipFrame.AbsoluteSize
            local x = math.clamp((position and position.X or 0) + 14, 8, math.max(8, viewport.X - size.X - 8))
            local y = math.clamp((position and position.Y or 0) + 16, 8, math.max(8, viewport.Y - size.Y - 8))
            TooltipFrame.Position = UDim2.fromOffset(x, y)
        end)
    end

    function Window:HideTooltip(target)
        if target and activeTooltipTarget ~= target then return end
        activeTooltipTarget = nil
        TooltipFrame.Visible = false
    end

    function Window:AttachTooltip(target, text)
        if not target or not target:IsA("GuiObject") or text == nil or tostring(text) == "" then return nil end
        local touching = false
        Library:Connect(target.MouseEnter, function()
            local mouse = UserInputService:GetMouseLocation()
            Window:ShowTooltip(text, mouse, target)
        end)
        Library:Connect(target.MouseMoved, function(x, y)
            if activeTooltipTarget == target then Window:ShowTooltip(text, Vector2.new(x, y), target) end
        end)
        Library:Connect(target.MouseLeave, function() Window:HideTooltip(target) end)
        Library:Connect(target.InputBegan, function(input)
            if input.UserInputType ~= Enum.UserInputType.Touch then return end
            touching = true
            task.delay(0.45, function()
                if touching and target.Parent and not Library.Unloaded then Window:ShowTooltip(text, input.Position, target) end
            end)
        end)
        Library:Connect(target.InputEnded, function(input)
            if input.UserInputType == Enum.UserInputType.Touch then touching = false Window:HideTooltip(target) end
        end)
        return {Show = function() Window:ShowTooltip(text, target.AbsolutePosition + target.AbsoluteSize, target) end,
            Hide = function() Window:HideTooltip(target) end,
            Set = function(_, value) text = tostring(value or "") end}
    end

    function Window:Dialog(dialogOptions)
        dialogOptions = dialogOptions or {}
        local overlay = Utility:Create("TextButton", {
            Name = "DialogOverlay", Parent = ScreenGui, BackgroundColor3 = Color3.new(0,0,0),
            BackgroundTransparency = 1, Size = UDim2.fromScale(1,1), Text = "",
            AutoButtonColor = false, ZIndex = 800
        })
        local dialogLayoutWidth = getViewport().X / math.max(Library.DPIScale, 0.01)
        local card = Utility:Create("Frame", {
            Parent = overlay, AnchorPoint = Vector2.new(0.5,0.5), Position = UDim2.fromScale(0.5,0.5),
            Size = UDim2.fromOffset(math.max(1, math.min(IsMobile and 320 or 400, dialogLayoutWidth - 24)), 0),
            AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = Library.Theme.Main,
            BorderSizePixel = 0, ZIndex = 801
        })
        Utility:RegisterProperty(card, "BackgroundColor3", "Main")
        Utility:Create("UICorner", {Parent = card, CornerRadius = UDim.new(0,10)})
        local cardStroke = Utility:Create("UIStroke", {Parent = card, Color = Library.Theme.Stroke, Thickness = 1})
        Utility:RegisterProperty(cardStroke, "Color", "Stroke")
        Utility:Create("UIPadding", {
            Parent = card, PaddingTop = UDim.new(0,16), PaddingBottom = UDim.new(0,16),
            PaddingLeft = UDim.new(0,16), PaddingRight = UDim.new(0,16)
        })
        Utility:Create("UIListLayout", {Parent = card, Padding = UDim.new(0,10), SortOrder = Enum.SortOrder.LayoutOrder})
        local dialogTitle = Utility:Create("TextLabel", {
            Parent = card, BackgroundTransparency = 1, Size = UDim2.new(1,0,0,24),
            Text = tostring(dialogOptions.Title or "Confirm"), TextColor3 = Library.Theme.Text,
            Font = Enum.Font.GothamBold, TextSize = 16, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 802
        })
        Utility:RegisterProperty(dialogTitle, "TextColor3", "Text")
        local dialogContent = Utility:Create("TextLabel", {
            Parent = card, BackgroundTransparency = 1, Size = UDim2.new(1,0,0,20), AutomaticSize = Enum.AutomaticSize.Y,
            Text = tostring(dialogOptions.Content or ""), TextColor3 = Library.Theme.SubText, Font = Enum.Font.Gotham,
            TextSize = 13, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 802
        })
        Utility:RegisterProperty(dialogContent, "TextColor3", "SubText")
        local actionBar = Utility:Create("Frame", {Parent = card, BackgroundTransparency = 1, Size = UDim2.new(1,0,0,34), ZIndex = 802})
        Utility:Create("UIListLayout", {Parent = actionBar, FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Right, Padding = UDim.new(0,8)})
        local closed = false
        local function close()
            if closed then return end
            closed = true
            Utility:Tween(overlay, TweenInfo.new(0.18), {BackgroundTransparency = 1}, function() if overlay.Parent then overlay:Destroy() end end)
            if Library.ReducedMotion and overlay.Parent then overlay:Destroy() end
        end
        local actions = dialogOptions.Actions or {{Name = "Okay"}}
        for _, action in ipairs(actions) do
            local actionButton = Utility:Create("TextButton", {
                Parent = actionBar, BackgroundColor3 = action.Primary and Library.Theme.Accent or Library.Theme.Hover,
                Size = UDim2.fromOffset(90,32), Text = tostring(action.Name or "Okay"), TextColor3 = Library.Theme.Text,
                Font = Enum.Font.GothamBold, TextSize = 12, AutoButtonColor = false, BorderSizePixel = 0, ZIndex = 803
            })
            Utility:Create("UICorner", {Parent = actionButton, CornerRadius = UDim.new(0,6)})
            Library:Connect(actionButton.MouseButton1Click, function()
                Utility:SafeCall(action.Callback)
                if action.Close ~= false then close() end
            end)
        end
        Library:Connect(overlay.MouseButton1Click, function() if dialogOptions.Dismissable ~= false then close() end end)
        Utility:Tween(overlay, TweenInfo.new(0.18), {BackgroundTransparency = 0.35})
        return {Close = close, Frame = card}
    end

    function Window:Prompt(promptOptions)
        promptOptions = promptOptions or {}
        local overlay = Utility:Create("TextButton", {
            Name = "PromptOverlay", Parent = ScreenGui, BackgroundColor3 = Color3.new(0, 0, 0),
            BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Text = "",
            AutoButtonColor = false, ZIndex = 820
        })
        local layoutWidth = getViewport().X / math.max(Library.DPIScale, 0.01)
        local card = Utility:Create("Frame", {
            Parent = overlay, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.fromOffset(math.max(1, math.min(IsMobile and 320 or 420, layoutWidth - 24)), 0),
            AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = Library.Theme.Main,
            BorderSizePixel = 0, ZIndex = 821
        })
        Utility:RegisterProperty(card, "BackgroundColor3", "Main")
        Utility:Create("UICorner", {Parent = card, CornerRadius = UDim.new(0, 10)})
        local stroke = Utility:Create("UIStroke", {Parent = card, Color = Library.Theme.Stroke, Thickness = 1})
        Utility:RegisterProperty(stroke, "Color", "Stroke")
        Utility:Create("UIPadding", {
            Parent = card, PaddingTop = UDim.new(0, 16), PaddingBottom = UDim.new(0, 16),
            PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16)
        })
        Utility:Create("UIListLayout", {Parent = card, Padding = UDim.new(0, 9), SortOrder = Enum.SortOrder.LayoutOrder})
        local title = Utility:Create("TextLabel", {
            Parent = card, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 24),
            Text = tostring(promptOptions.Title or "Enter a value"), TextColor3 = Library.Theme.Text,
            Font = Enum.Font.GothamBold, TextSize = 16, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 822
        })
        Utility:RegisterProperty(title, "TextColor3", "Text")
        if promptOptions.Content then
            local content = Utility:Create("TextLabel", {
                Parent = card, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 18), AutomaticSize = Enum.AutomaticSize.Y,
                Text = tostring(promptOptions.Content), TextColor3 = Library.Theme.SubText, Font = Enum.Font.Gotham,
                TextSize = 12, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 822
            })
            Utility:RegisterProperty(content, "TextColor3", "SubText")
        end
        local input = Utility:Create("TextBox", {
            Parent = card, BackgroundColor3 = Library.Theme.Surface, Size = UDim2.new(1, 0, 0, 38),
            Text = tostring(promptOptions.Default or ""), PlaceholderText = tostring(promptOptions.Placeholder or "Type here..."),
            ClearTextOnFocus = false, TextColor3 = Library.Theme.Text, PlaceholderColor3 = Library.Theme.SubText,
            Font = Enum.Font.Gotham, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 822, BorderSizePixel = 0
        })
        Utility:RegisterProperty(input, "BackgroundColor3", "Surface")
        Utility:RegisterProperty(input, "TextColor3", "Text")
        Utility:RegisterProperty(input, "PlaceholderColor3", "SubText")
        Utility:Create("UICorner", {Parent = input, CornerRadius = UDim.new(0, 6)})
        Utility:Create("UIPadding", {Parent = input, PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10)})
        local errorLabel = Utility:Create("TextLabel", {
            Parent = card, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
            Text = "", TextColor3 = Library.Theme.Error, Font = Enum.Font.Gotham, TextSize = 11,
            TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, Visible = false, ZIndex = 822
        })
        Utility:RegisterProperty(errorLabel, "TextColor3", "Error")
        local actions = Utility:Create("Frame", {Parent = card, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 34), ZIndex = 822})
        Utility:Create("UIListLayout", {Parent = actions, FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Right, Padding = UDim.new(0, 8)})
        local closed = false
        local function close(cancelled)
            if closed then return end
            closed = true
            if cancelled then Utility:SafeCall(promptOptions.OnCancel) end
            Utility:Tween(overlay, TweenInfo.new(0.18), {BackgroundTransparency = 1}, function()
                if overlay.Parent then overlay:Destroy() end
            end)
            if Library.ReducedMotion and overlay.Parent then overlay:Destroy() end
        end
        local function submit()
            local value = input.Text
            if type(promptOptions.Validate) == "function" then
                local ok, valid, message = pcall(promptOptions.Validate, value)
                if not ok or valid == false then
                    errorLabel.Text = tostring(ok and message or valid)
                    errorLabel.Visible = true
                    return
                end
            end
            Utility:SafeCall(promptOptions.Callback, value)
            close(false)
        end
        local function makeAction(name, primary, callback)
            local button = Utility:Create("TextButton", {
                Parent = actions, BackgroundColor3 = primary and Library.Theme.Accent or Library.Theme.Hover,
                Size = UDim2.fromOffset(96, 32), Text = name, TextColor3 = Library.Theme.Text,
                Font = Enum.Font.GothamBold, TextSize = 12, AutoButtonColor = false, BorderSizePixel = 0, ZIndex = 823
            })
            Utility:Create("UICorner", {Parent = button, CornerRadius = UDim.new(0, 6)})
            Library:Connect(button.MouseButton1Click, callback)
        end
        makeAction(tostring(promptOptions.CancelText or "Cancel"), false, function() close(true) end)
        makeAction(tostring(promptOptions.SubmitText or "Submit"), true, submit)
        Library:Connect(input.FocusLost, function(enterPressed) if enterPressed then submit() end end)
        Library:Connect(overlay.MouseButton1Click, function() if promptOptions.Dismissable ~= false then close(true) end end)
        Utility:Tween(overlay, TweenInfo.new(0.18), {BackgroundTransparency = 0.35})
        task.defer(function() if input.Parent then input:CaptureFocus() end end)
        return {Close = function() close(true) end, Submit = submit, Get = function() return input.Text end,
            Set = function(_, value) input.Text = tostring(value or "") end, Frame = card, Input = input}
    end

    local function ensureBuiltinKeybinds()
    if Library.__BuiltinKeybindsRegistered then
        return
    end

    Library.__BuiltinKeybindsRegistered = true

    local savedToggleKey = Library.Flags.__RenLibToggleUI
    if type(savedToggleKey) == "string" and Enum.KeyCode[savedToggleKey] then
        Library.ToggleKey = Enum.KeyCode[savedToggleKey]
    end

    local entry
    entry = {
        name = "Toggle UI",
        key = Library.ToggleKey.Name,
        default = Library.ToggleKey.Name,
        mode = "Press",
        flag = "__RenLibToggleUI",
        Virtual = true,
    }

    entry.controller = {
        Set = function(_, key)
            local keyName = typeof(key) == "EnumItem" and key.Name or tostring(key)

            if Enum.KeyCode[keyName] then
                Library.ToggleKey = Enum.KeyCode[keyName]
                Library.Flags.__RenLibToggleUI = keyName
                entry.key = keyName
            end
        end,

        Get = function()
            return entry.key
        end,

        GetKey = function()
            return entry.key
        end,
    }

    table.insert(Library.KeybindList, entry)
end

function Window:ShowKeybindManager()
    ensureBuiltinKeybinds()

    if self.KeybindManagerOverlay and self.KeybindManagerOverlay.Parent then
        if self.KeybindManagerRebuild then
            self.KeybindManagerRebuild()
        end

        self.KeybindManagerOverlay.Visible = true
        return self.KeybindManagerOverlay
    end
        local overlay = Utility:Create("TextButton", {
            Name = "KeybindManagerOverlay", Parent = ScreenGui, BackgroundColor3 = Color3.new(0, 0, 0),
            BackgroundTransparency = 0.35, Size = UDim2.fromScale(1, 1), Text = "",
            AutoButtonColor = false, ZIndex = 840
        })
        self.KeybindManagerOverlay = overlay
        local card = Utility:Create("Frame", {
            Parent = overlay, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.fromOffset(math.min(IsMobile and 330 or 460, getViewport().X - 24), math.min(430, getViewport().Y - 24)),
            BackgroundColor3 = Library.Theme.Main, BorderSizePixel = 0, ZIndex = 841
        })
        Utility:RegisterProperty(card, "BackgroundColor3", "Main")
        Utility:Create("UICorner", {Parent = card, CornerRadius = UDim.new(0, 10)})
        local stroke = Utility:Create("UIStroke", {Parent = card, Color = Library.Theme.Stroke, Thickness = 1})
        Utility:RegisterProperty(stroke, "Color", "Stroke")
        local title = Utility:Create("TextLabel", {
            Parent = card, BackgroundTransparency = 1, Position = UDim2.fromOffset(16, 12),
            Size = UDim2.new(1, -72, 0, 28), Text = "Keybind manager", TextColor3 = Library.Theme.Text,
            Font = Enum.Font.GothamBold, TextSize = 16, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 842
        })
        Utility:RegisterProperty(title, "TextColor3", "Text")
        local closeButton = Utility:Create("TextButton", {
            Parent = card, BackgroundColor3 = Library.Theme.Surface, Position = UDim2.new(1, -46, 0, 10),
            Size = UDim2.fromOffset(34, 30), Text = "×", TextColor3 = Library.Theme.Text,
            Font = Enum.Font.GothamBold, TextSize = 18, AutoButtonColor = false, BorderSizePixel = 0, ZIndex = 843
        })
        Utility:RegisterProperty(closeButton, "BackgroundColor3", "Surface")
        Utility:RegisterProperty(closeButton, "TextColor3", "Text")
        Utility:Create("UICorner", {Parent = closeButton, CornerRadius = UDim.new(0, 6)})
        local list = Utility:Create("ScrollingFrame", {
            Parent = card, BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 52),
            Size = UDim2.new(1, -24, 1, -104), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
            ScrollBarThickness = 2, ScrollBarImageColor3 = Library.Theme.Accent, BorderSizePixel = 0, ZIndex = 842
        })
        Utility:RegisterProperty(list, "ScrollBarImageColor3", "Accent")
        Utility:Create("UIListLayout", {Parent = list, Padding = UDim.new(0, 7), SortOrder = Enum.SortOrder.LayoutOrder})
local function rebuild()
    for _, child in ipairs(list:GetChildren()) do
        if child:IsA("GuiObject") then
            child:Destroy()
        end
    end

    local rendered = 0

    for _, entry in ipairs(Library.KeybindList) do
        local isVisibleEntry =
            entry.Virtual == true
            or (entry.controller and entry.controller.Holder and entry.controller.Holder.Parent)

        if isVisibleEntry then
            rendered += 1

            local row = Utility:Create("Frame", {
                Parent = list,
                BackgroundColor3 = Library.Theme.Surface,
                Size = UDim2.new(1, -4, 0, 42),
                BorderSizePixel = 0,
                ZIndex = 843
            })

            Utility:RegisterProperty(row, "BackgroundColor3", "Surface")
            Utility:Create("UICorner", {Parent = row, CornerRadius = UDim.new(0, 6)})

            local label = Utility:Create("TextLabel", {
                Parent = row,
                BackgroundTransparency = 1,
                Position = UDim2.fromOffset(10, 0),
                Size = UDim2.new(1, -160, 1, 0),
                Text = entry.name .. "  ·  " .. entry.mode,
                TextColor3 = Library.Theme.Text,
                Font = Enum.Font.Gotham,
                TextSize = 12,
                TextXAlignment = Enum.TextXAlignment.Left,
                ZIndex = 844
            })

            Utility:RegisterProperty(label, "TextColor3", "Text")

            local keyButton = Utility:Create("TextButton", {
                Parent = row,
                BackgroundColor3 = Library.Theme.Secondary,
                Position = UDim2.new(1, -142, 0.5, -14),
                Size = UDim2.fromOffset(76, 28),
                Text = tostring(entry.key),
                TextColor3 = Library.Theme.Text,
                Font = Enum.Font.GothamBold,
                TextSize = 11,
                AutoButtonColor = false,
                BorderSizePixel = 0,
                ZIndex = 844
            })

            Utility:RegisterProperty(keyButton, "BackgroundColor3", "Secondary")
            Utility:RegisterProperty(keyButton, "TextColor3", "Text")
            Utility:Create("UICorner", {Parent = keyButton, CornerRadius = UDim.new(0, 5)})

            local resetButton = Utility:Create("TextButton", {
                Parent = row,
                BackgroundTransparency = 1,
                Position = UDim2.new(1, -60, 0.5, -14),
                Size = UDim2.fromOffset(52, 28),
                Text = "Reset",
                TextColor3 = Library.Theme.SubText,
                Font = Enum.Font.GothamBold,
                TextSize = 10,
                AutoButtonColor = false,
                ZIndex = 844
            })

            Utility:RegisterProperty(resetButton, "TextColor3", "SubText")

            Library:Connect(keyButton.MouseButton1Click, function()
                keyButton.Text = "Press…"

                local connection
                connection = UserInputService.InputBegan:Connect(function(input, processed)
                    if processed or input.UserInputType ~= Enum.UserInputType.Keyboard then
                        return
                    end

                    connection:Disconnect()

                    if entry.controller and entry.controller.Set then
                        entry.controller:Set(input.KeyCode.Name)
                    end

                    entry.key = input.KeyCode.Name
                    keyButton.Text = input.KeyCode.Name
                end)
            end)

            Library:Connect(resetButton.MouseButton1Click, function()
                if entry.controller and entry.controller.Set then
                    entry.controller:Set(entry.default)
                end

                entry.key = entry.default
                keyButton.Text = tostring(entry.default)
            end)
        end
    end

    if rendered == 0 then
        local empty = Utility:Create("TextLabel", {
            Parent = list,
            BackgroundTransparency = 1,
            Size = UDim2.new(1, -8, 0, 90),
            Text = "No keybinds registered yet.\nUse CreateKeyPicker(...) to add shortcuts here.",
            TextColor3 = Library.Theme.SubText,
            Font = Enum.Font.Gotham,
            TextSize = 13,
            TextWrapped = true,
            TextXAlignment = Enum.TextXAlignment.Center,
            TextYAlignment = Enum.TextYAlignment.Center,
            ZIndex = 843
        })

        Utility:RegisterProperty(empty, "TextColor3", "SubText")
    end
end

self.KeybindManagerRebuild = rebuild
        local footer = Utility:Create("TextButton", {
            Parent = card, BackgroundColor3 = Library.Theme.Surface, Position = UDim2.new(0, 12, 1, -42),
            Size = UDim2.new(1, -24, 0, 30), Text = "Reset all keybinds", TextColor3 = Library.Theme.Text,
            Font = Enum.Font.GothamBold, TextSize = 11, AutoButtonColor = false, BorderSizePixel = 0, ZIndex = 843
        })
        Utility:RegisterProperty(footer, "BackgroundColor3", "Surface")
        Utility:RegisterProperty(footer, "TextColor3", "Text")
        Utility:Create("UICorner", {Parent = footer, CornerRadius = UDim.new(0, 6)})
        Library:Connect(footer.MouseButton1Click, function()
            for _, entry in ipairs(Library.KeybindList) do
                if entry.controller then entry.controller:Set(entry.default) end
            end
            rebuild()
        end)
        local function hide() overlay.Visible = false end
        Library:Connect(closeButton.MouseButton1Click, hide)
        Library:Connect(overlay.MouseButton1Click, hide)
        rebuild()
        return overlay
    end

    Library.KeybindManager = {Show = function() return Window:ShowKeybindManager() end,
        Hide = function() if Window.KeybindManagerOverlay then Window.KeybindManagerOverlay.Visible = false end end}

    Window:ApplyResponsiveLayout(true)
    Library:SetMaterialIntensity(options.MaterialIntensity or Library.MaterialIntensity)
    Library:SetMaterialMode(RequestedMaterialMode)
    if Camera then
        Library:Connect(Camera:GetPropertyChangedSignal("ViewportSize"), function()
            Window:ApplyResponsiveLayout(false)
        end)
    end

    -- MINIMIZE/RESTORE/CLOSE
    local visibilityToken = 0
    function Window:Minimize()
        if Library.IsMinimized then return end
        visibilityToken = visibilityToken + 1
        local token = visibilityToken
        Library.IsMinimized = true
        self:CloseCommandPalette()
        if PaletteOpenButton then PaletteOpenButton.Visible = false end
        Library:RefreshMaterialVisibility()
        if IsMobile then
            if MobileToggleBtn then
                MobileToggleBtn.Visible = true
            end
        else
            MinimizedIcon.Visible = true
        end
        Utility:Tween(WindowScale, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Scale = 0.96})
        Utility:Tween(MainFrame, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {BackgroundTransparency = 1}, function()
            if token == visibilityToken and Library.IsMinimized then MainFrame.Visible = false end
        end)
        if Library.ReducedMotion then MainFrame.Visible = false end
    end

    function Window:Restore()
        visibilityToken = visibilityToken + 1
        Library.IsMinimized = false
        Library:RefreshMaterialVisibility()
        MinimizedIcon.Visible = false
        MainFrame.Visible = true
        if PaletteOpenButton then PaletteOpenButton.Visible = Library.DeviceMode == "Phone" end
        MainFrame.BackgroundTransparency = 1
        WindowScale.Scale = 0.96
        Utility:Tween(WindowScale, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1})
        local mainMaterial = Library.MaterialRegistry[MainFrame]
        local restoredTransparency = mainMaterial and (Library.MaterialMode == "Frosted" and mainMaterial.Frosted or mainMaterial.Solid) or 0
        Utility:Tween(MainFrame, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = restoredTransparency})
        if IsMobile and MobileToggleBtn then
            MobileToggleBtn.Visible = false
        end
    end

    function Window:Toggle()
        if Library.IsMinimized then
            Window:Restore()
        else
            Window:Minimize()
        end
    end

    function Window:Close()
        Library:Unload()
    end

    Library:Connect(MinimizeBtn.MouseButton1Click, function() Window:Minimize() end)
    Library:Connect(MinimizeBtn.MouseEnter, function()
        Utility:Tween(MinimizeBtn, TweenInfo.new(0.12), {BackgroundColor3 = Library.Theme.Hover})
    end)
    Library:Connect(MinimizeBtn.MouseLeave, function()
        Utility:Tween(MinimizeBtn, TweenInfo.new(0.12), {BackgroundColor3 = Library.Theme.Surface})
    end)
    local minimizedIconDrag = Utility:MakeDraggable(MinIconBtn, MinimizedIcon)
    Library:Connect(MinIconBtn.MouseButton1Click, function()
        if minimizedIconDrag:ConsumeDrag() then return end
        Window:Restore()
    end)
    Library:Connect(CloseBtn.MouseButton1Click, function() Window:Close() end)
    Library:Connect(CloseBtn.MouseEnter, function()
        Utility:Tween(CloseBtn, TweenInfo.new(0.12), {BackgroundColor3 = Library.Theme.Error})
    end)
    Library:Connect(CloseBtn.MouseLeave, function()
        Utility:Tween(CloseBtn, TweenInfo.new(0.12), {BackgroundColor3 = Library.Theme.Surface})
    end)

-- GLOBAL SEARCH: indexes controls and highlights matches without changing the
-- structural visibility of tabs, pages, sections, or controls. Navigation is
-- still owned exclusively by Window:SelectTab.
if SearchBox then
    local highlights = setmetatable({}, {__mode = "k"})
    local SearchStatus = Utility:Create("TextLabel", {
        Name = "SearchStatus", Parent = SearchBox, AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(42, 18),
        BackgroundTransparency = 1, Text = "", TextColor3 = Library.Theme.SubText,
        Font = Enum.Font.GothamBold, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Right,
        ZIndex = SearchBox.ZIndex + 1
    })
    Utility:RegisterProperty(SearchStatus, "TextColor3", "SubText")

    local function clearHighlights()
        for holder, stroke in pairs(highlights) do
            if stroke and stroke.Parent then stroke:Destroy() end
            highlights[holder] = nil
        end
    end

    local function highlight(holder)
        if not holder or not holder:IsA("GuiObject") or highlights[holder] then return end
        local stroke = Utility:Create("UIStroke", {
            Name = "RenSearchHighlight", Parent = holder, Color = Library.Theme.Accent,
            Thickness = 2, Transparency = 0.05, ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        })
        Utility:RegisterProperty(stroke, "Color", "Accent")
        highlights[holder] = stroke
    end

    function Window:FocusSearchResult(index)
        local count = #self.SearchResults
        if count == 0 then return false end
        index = ((tonumber(index) or self.SearchIndex or 0) - 1) % count + 1
        self.SearchIndex = index
        local result = self.SearchResults[index]
        self:SelectTab(result.Tab, {ResetScroll = false, Animate = true})
        SearchStatus.Text = tostring(index) .. "/" .. tostring(count)
        task.defer(function()
            local holder, page = result.Holder, result.Tab.Page
            if not holder or not holder.Parent or not page or not page.Parent then return end
            local localY = holder.AbsolutePosition.Y - page.AbsolutePosition.Y + page.CanvasPosition.Y
            page.CanvasPosition = Vector2.new(0, math.max(0, localY - 12))
            local stroke = highlights[holder]
            if stroke then
                stroke.Transparency = 0
                Utility:Tween(stroke, TweenInfo.new(0.45), {Transparency = 0.18})
            end
        end)
        return true
    end

    function Window:RefreshSearch(query)
        query = tostring(query or ""):lower():match("^%s*(.-)%s*$") or ""
        self.SearchQuery = query
        self.SearchIndex = 0
        self.SearchResults = {}
        clearHighlights()

        if query == "" then
            SearchStatus.Text = ""
            return self.SearchResults
        end

        local seen = {}
        for _, tab in ipairs(self.Tabs) do
            for _, section in ipairs(tab.Sections or {}) do
                for _, element in ipairs(section.Elements or {}) do
                    local holder = element.Holder
                    local synonyms = element.Synonyms or element.Aliases or ""
                    if type(synonyms) == "table" then synonyms = table.concat(synonyms, " ") end
                    local haystack = table.concat({tab.Name or "", section.Name or "", element.Text or element.Name or "", tostring(synonyms)}, " "):lower()
                    if holder and holder.Parent and haystack:find(query, 1, true) and not seen[holder] then
                        seen[holder] = true
                        table.insert(self.SearchResults, {Tab = tab, Section = section, Element = element, Holder = holder})
                        highlight(holder)
                        if element.NestedParentHolder then highlight(element.NestedParentHolder) end
                    end
                end
            end
        end

        SearchStatus.Text = #self.SearchResults == 0 and "0" or tostring(#self.SearchResults)
        return self.SearchResults
    end

    function Window:ClearSearch()
        SearchBox.Text = ""
        self:RefreshSearch("")
        return self
    end

    Library:Connect(SearchBox:GetPropertyChangedSignal("Text"), function()
        Window:RefreshSearch(SearchBox.Text)
    end)
    Library:Connect(SearchBox.FocusLost, function(enterPressed)
        if enterPressed and Window.SearchQuery ~= "" then
            Window:FocusSearchResult((Window.SearchIndex or 0) + 1)
        end
    end)
end

    -- NOTIFICATIONS
    function Library:Notify(notifyOpts)
        notifyOpts = notifyOpts or {}
        local Title = notifyOpts.Title or "Notification"
        local Content = notifyOpts.Content or ""
        local Duration = notifyOpts.Duration or 3
        local Emoji = notifyOpts.Emoji or EMOJIS.Info
        local Progress = notifyOpts.Progress
        local Actions = notifyOpts.Actions or {}

        local notifHeight = (IsMobile and 58 or 66) + (#Actions > 0 and 34 or 0)
        local NotifyFrame = Utility:Create("Frame", {
            Name = "Notify",
            Parent = NotifyArea,
            BackgroundColor3 = Library.Theme.Main,
            Size = UDim2.new(1, 0, 0, notifHeight),
            Position = UDim2.new(2, 0, 0, 0),
            ClipsDescendants = true,
            ZIndex = 201,
            BorderSizePixel = 0
        })
        Utility:RegisterProperty(NotifyFrame, "BackgroundColor3", "Main")
        Utility:Create("UICorner", {CornerRadius = UDim.new(0, 8), Parent = NotifyFrame})
        local stroke = Utility:Create("UIStroke", {Parent = NotifyFrame, Color = Library.Theme.Stroke, Thickness = 1})
        Utility:RegisterProperty(stroke, "Color", "Stroke")

        local titleText = Utility:Create("TextLabel", {
            Parent = NotifyFrame,
            BackgroundTransparency = 1,
            Position = UDim2.new(0, 10, 0, 10),
            Size = UDim2.new(0, IsMobile and 28 or 36, 0, IsMobile and 28 or 36),
            Font = Enum.Font.GothamBold,
            Text = Emoji,
            TextColor3 = Library.Theme.Accent,
            TextSize = IsMobile and 18 or 24,
            TextXAlignment = Enum.TextXAlignment.Center,
            TextYAlignment = Enum.TextYAlignment.Center,
            ZIndex = 202
        })
        Utility:Create("TextLabel", {
            Parent = NotifyFrame,
            BackgroundTransparency = 1,
            Position = UDim2.new(0, IsMobile and 44 or 58, 0, IsMobile and 8 or 12),
            Size = UDim2.new(1, IsMobile and -76 or -92, 0, 16),
            Font = Enum.Font.GothamBold,
            Text = Title,
            TextColor3 = Library.Theme.Text,
            TextSize = IsMobile and 12 or 14,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 202
        })
        local contentText = Utility:Create("TextLabel", {
            Parent = NotifyFrame,
            BackgroundTransparency = 1,
            Position = UDim2.new(0, IsMobile and 44 or 58, 0, IsMobile and 24 or 30),
            Size = UDim2.new(1, IsMobile and -76 or -92, 0, #Actions > 0 and 26 or 28),
            Font = Enum.Font.Gotham,
            Text = Content,
            TextColor3 = Library.Theme.SubText,
            TextSize = IsMobile and 11 or 13,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextWrapped = true,
            ZIndex = 202
        })

        local closeButton = Utility:Create("TextButton", {
            Parent = NotifyFrame, BackgroundTransparency = 1,
            Position = UDim2.new(1, -30, 0, 6), Size = UDim2.fromOffset(24, 24),
            Text = "×", TextColor3 = Library.Theme.SubText, Font = Enum.Font.GothamBold,
            TextSize = 18, AutoButtonColor = false, ZIndex = 204
        })
        Utility:RegisterProperty(closeButton, "TextColor3", "SubText")

        -- Progress bar
        local progressBar = nil
        if Progress ~= nil then
            progressBar = Utility:Create("Frame", {
                Parent = NotifyFrame,
                BackgroundColor3 = Library.Theme.Accent,
                Position = UDim2.new(0, 0, 1, -4),
                Size = UDim2.new(Progress, 0, 0, 4),
                ZIndex = 203,
                BorderSizePixel = 0
            })
            Utility:RegisterProperty(progressBar, "BackgroundColor3", "Accent")
        end


        local Closed = false
        local function Close()
            if Closed then return end
            Closed = true
            Utility:Tween(NotifyFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                Position = UDim2.new(1, 300, 0, 0),
                BackgroundTransparency = 1
            }, function()
                if NotifyFrame.Parent then NotifyFrame:Destroy() end
            end)
            if Library.ReducedMotion and NotifyFrame.Parent then NotifyFrame:Destroy() end
        end

        Library:Connect(closeButton.MouseButton1Click, Close)

        if #Actions > 0 then
            local actionBar = Utility:Create("Frame", {
                Parent = NotifyFrame, BackgroundTransparency = 1,
                Position = UDim2.new(0, IsMobile and 44 or 58, 1, -38),
                Size = UDim2.new(1, IsMobile and -52 or -68, 0, 28), ZIndex = 203
            })
            Utility:Create("UIListLayout", {
                Parent = actionBar, FillDirection = Enum.FillDirection.Horizontal,
                HorizontalAlignment = Enum.HorizontalAlignment.Right, Padding = UDim.new(0, 6)
            })
            for _, action in ipairs(Actions) do
                local actionButton = Utility:Create("TextButton", {
                    Parent = actionBar, BackgroundColor3 = Library.Theme.Hover,
                    Size = UDim2.fromOffset(math.max(64, TextService:GetTextSize(tostring(action.Name or "Action"), 11, Enum.Font.GothamBold, Vector2.new(160, 24)).X + 20), 26),
                    Text = tostring(action.Name or "Action"), TextColor3 = Library.Theme.Text,
                    Font = Enum.Font.GothamBold, TextSize = 11, AutoButtonColor = false,
                    BorderSizePixel = 0, ZIndex = 204
                })
                Utility:RegisterProperty(actionButton, "BackgroundColor3", "Hover")
                Utility:RegisterProperty(actionButton, "TextColor3", "Text")
                Utility:Create("UICorner", {CornerRadius = UDim.new(0, 5), Parent = actionButton})
                Library:Connect(actionButton.MouseButton1Click, function()
                    Utility:SafeCall(action.Callback)
                    if action.Close ~= false then Close() end
                end)
            end
        end

        NotifyFrame.Position = UDim2.new(1, 300, 0, 0)
        Utility:Tween(NotifyFrame, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Position = UDim2.new(0, 0, 0, 0)
        })

        if Duration and Duration > 0 then
            if not progressBar then
                progressBar = Utility:Create("Frame", {
                    Parent = NotifyFrame, BackgroundColor3 = Library.Theme.Accent,
                    Position = UDim2.new(0, 0, 1, -3), Size = UDim2.new(1, 0, 0, 3),
                    BorderSizePixel = 0, ZIndex = 203
                })
                Utility:RegisterProperty(progressBar, "BackgroundColor3", "Accent")
                Utility:Tween(progressBar, TweenInfo.new(Duration, Enum.EasingStyle.Linear), {Size = UDim2.new(0, 0, 0, 3)})
            end
            task.delay(Duration, Close)
        end
        return {
            Close = Close,
            SetProgress = function(self, amount)
                if progressBar then progressBar.Size = UDim2.new(math.clamp(amount, 0, 1), 0, 0, 4) end
            end,
            SetContent = function(self, text) contentText.Text = tostring(text) end,
            SetTitle = function(self, text) titleText.Text = tostring(text) end
        }
    end


--[[ MODULE: 80_tabs.part.lua ]]
-- Module fragment: tabs and activation
-- Generated from the working V7 baseline; edit this feature in isolation.
    --// TABS
    function Window:CreateTabCategory(name)
        self.NextNavOrder = self.NextNavOrder + 1
        local category = Utility:Create("TextLabel", {
            Name = "Category_" .. tostring(name), Parent = TabContainer,
            BackgroundTransparency = 1, Size = UDim2.new(1, -8, 0, isCompact and 0 or 20),
            Text = string.upper(tostring(name or "")), TextColor3 = Library.Theme.SubText,
            Font = Enum.Font.GothamBold, TextSize = 9, TextXAlignment = Enum.TextXAlignment.Left,
            TextTransparency = isCompact and 1 or 0,
            ZIndex = 5, Visible = true, LayoutOrder = self.NextNavOrder
        })
        Utility:RegisterProperty(category, "TextColor3", "SubText")
        local categoryEntry = {Label = category, Tabs = {}}
        table.insert(self.TabCategories, categoryEntry)
        self.CurrentTabCategory = categoryEntry
        return category
    end

    function Window:CreateTab(options)
        options = options or {}
        local Name = options.Name or "Tab"
        local Emoji = options.Emoji
        local IsSettings = options.IsSettings or false
        local IsOverview = options.IsOverview or false
        local Icon = Utility:NormalizeAssetId(options.Icon)
        self.NextNavOrder = self.NextNavOrder + 1
        if not Icon and Emoji == nil and not IsSettings and not IsOverview then Icon = ICONS.Home end

        local Tab = {
            Name = Name,
            Active = false,
            Sections = {},
            HeaderHeight = 0,
            ResponsiveCallbacks = {},
            IsSettings = IsSettings,
            IsOverview = IsOverview,
            Page = nil,
            TabBtn = nil,
            TabLabel = nil
        }
        if not IsSettings and not IsOverview and self.CurrentTabCategory then
            table.insert(self.CurrentTabCategory.Tabs, Tab)
        end

        local TabBtn, TabEmoji, Indicator, TabGradient
        local tabBtnSize = IsMobile and 38 or 42

        if not IsSettings and not IsOverview then
            TabBtn = Utility:Create("TextButton", {
                Name = Name,
                Parent = TabContainer,
                BackgroundColor3 = Library.Theme.Accent,
                BackgroundTransparency = 0.64,
                Size = (IsMobile or isCompact) and UDim2.fromOffset(tabBtnSize, tabBtnSize) or UDim2.new(1, 0, 0, tabBtnSize),
                AutoButtonColor = false,
                Text = "",
                ZIndex = 5,
                LayoutOrder = self.NextNavOrder,
                BorderSizePixel = 0
            })
            Utility:RegisterProperty(TabBtn, "BackgroundColor3", "Accent")
            Utility:Create("UICorner", {CornerRadius = UDim.new(0, 8), Parent = TabBtn})
            local tabStroke = Utility:Create("UIStroke", {Parent = TabBtn, Color = Library.Theme.Stroke, Thickness = 1})
            Utility:RegisterProperty(tabStroke, "Color", "Stroke")
            TabGradient = Utility:Create("UIGradient", {Parent = TabBtn, Rotation = 18})
            Utility:RegisterGradient(TabGradient, "Accent", "Accent2", "Accent3")

            if Icon then
                TabEmoji = Utility:Create("ImageLabel", {
                    Parent = TabBtn,
                    BackgroundTransparency = 1,
                    Position = (IsMobile or isCompact) and UDim2.fromScale(0.18, 0.18) or UDim2.fromOffset(6, 5),
                    Size = (IsMobile or isCompact) and UDim2.fromScale(0.64, 0.64) or UDim2.fromOffset(32, 32),
                    Image = Icon,
                    ImageColor3 = Library.Theme.SubText,
                    ScaleType = Enum.ScaleType.Fit,
                    ZIndex = 6
                })
                Utility:RegisterProperty(TabEmoji, "ImageColor3", "SubText")
            else
                TabEmoji = Utility:Create("TextLabel", {
                    Parent = TabBtn,
                    BackgroundTransparency = 1,
                    Position = (IsMobile or isCompact) and UDim2.fromScale(0.18, 0.18) or UDim2.fromOffset(6, 5),
                    Size = (IsMobile or isCompact) and UDim2.fromScale(0.64, 0.64) or UDim2.fromOffset(32, 32),
                    Font = Enum.Font.GothamBold,
                    Text = Emoji or "",
                    TextColor3 = Library.Theme.SubText,
                    TextSize = IsMobile and 16 or 20,
                    TextXAlignment = Enum.TextXAlignment.Center,
                    TextYAlignment = Enum.TextYAlignment.Center,
                    ZIndex = 6
                })
                Utility:RegisterProperty(TabEmoji, "TextColor3", "SubText")
            end

            Indicator = Utility:Create("Frame", {
                Parent = TabBtn,
                BackgroundColor3 = Library.Theme.Accent,
                Position = UDim2.new(0, 3, 0.5, -9),
                Size = UDim2.new(0, 3, 0, 18),
                BackgroundTransparency = 1,
                ZIndex = 7,
                BorderSizePixel = 0
            })
            Utility:RegisterProperty(Indicator, "BackgroundColor3", "Accent")
            Utility:Create("UICorner", {CornerRadius = UDim.new(0, 2), Parent = Indicator})

            local TabLabel = Utility:Create("TextLabel", {
                Parent = TabBtn,
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 48, 0, 0),
                Size = UDim2.new(1, -58, 1, 0),
                Font = Enum.Font.Gotham,
                Text = Name,
                TextColor3 = Library.Theme.SubText,
                TextSize = 12,
                TextXAlignment = Enum.TextXAlignment.Left,
                Visible = not (IsMobile or isCompact),
                ZIndex = 6
            })
            Utility:RegisterProperty(TabLabel, "TextColor3", "SubText")

            Tab.TabBtn = TabBtn
            Tab.TabEmoji = TabEmoji
            Tab.Indicator = Indicator
            Tab.TabLabel = TabLabel
            Tab.TabGradient = TabGradient
            Tab.TabStroke = tabStroke
        elseif IsOverview then
            TabBtn = OverviewBtn
            TabEmoji = OverviewIcon
            Indicator = OverviewIndicator
            Tab.TabBtn = OverviewBtn
            Tab.TabLabel = OverviewLabel
            Tab.TabEmoji = TabEmoji
            Tab.Indicator = Indicator
            Tab.TabStroke = overviewStroke
        else
            TabEmoji = SettingsEmoji
            Indicator = SettingsIndicator
            Tab.TabBtn = SettingsBtn
            Tab.TabLabel = SettingsLabel
            Tab.TabEmoji = TabEmoji
            Tab.Indicator = Indicator
            Tab.TabStroke = settingsStroke
        end

        local TabStatusDot = Utility:Create("Frame", {
            Name = "StatusDot", Parent = Tab.TabBtn, AnchorPoint = Vector2.new(1, 0),
            Position = UDim2.new(1, -4, 0, 4), Size = UDim2.fromOffset(8, 8),
            BackgroundColor3 = Library.Theme.SubText, Visible = false,
            BorderSizePixel = 0, ZIndex = 9
        })
        Utility:RegisterProperty(TabStatusDot, "BackgroundColor3", "SubText")
        Utility:Create("UICorner", {Parent = TabStatusDot, CornerRadius = UDim.new(1, 0)})
        local tabStatusStroke = Utility:Create("UIStroke", {Parent = TabStatusDot, Color = Library.Theme.Main, Thickness = 1})
        Utility:RegisterProperty(tabStatusStroke, "Color", "Main")
        Tab.StatusDot = TabStatusDot
        Tab.Status = "Idle"
        Tab.StatusDetail = ""
        local TabBadge = Utility:Create("TextLabel", {
            Name = "Badge", Parent = Tab.TabBtn, AnchorPoint = Vector2.new(1, 1),
            Position = UDim2.new(1, -3, 1, -3), Size = UDim2.fromOffset(17, 17),
            BackgroundColor3 = Library.Theme.Accent, Text = "", TextColor3 = Library.Theme.Text,
            Font = Enum.Font.GothamBold, TextSize = 8, Visible = false,
            BorderSizePixel = 0, ZIndex = 9
        })
        Utility:RegisterProperty(TabBadge, "BackgroundColor3", "Accent")
        Utility:RegisterProperty(TabBadge, "TextColor3", "Text")
        Utility:Create("UICorner", {Parent = TabBadge, CornerRadius = UDim.new(1, 0)})
        Tab.Badge = TabBadge

        function Tab:SetStatus(status, detail)
            local normalized = tostring(status or "Idle"):lower()
            local colorKeys = {active = "Success", waiting = "Warn", error = "Error", success = "Success"}
            local colorKey = colorKeys[normalized]
            self.Status = normalized
            self.StatusDetail = tostring(detail or "")
            TabStatusDot.Visible = colorKey ~= nil
            if colorKey then
                Library.Registry[TabStatusDot]["BackgroundColor3"] = colorKey
                Utility:Tween(TabStatusDot, TweenInfo.new(0.15), {BackgroundColor3 = Library.Theme[colorKey]})
            end
            if self._StatusTooltip then
                self._StatusTooltip:Set(self.Name .. "  •  " .. (self.StatusDetail ~= "" and self.StatusDetail or normalized))
            end
            return self
        end

        function Tab:SetBadge(value, colorKey)
            local numberValue = tonumber(value)
            local text = value == nil and "" or tostring(value)
            if numberValue and numberValue > 99 then text = "99+" end
            TabBadge.Text = text
            TabBadge.Visible = text ~= "" and text ~= "0"
            colorKey = Library.Theme[colorKey] and colorKey or "Accent"
            Library.Registry[TabBadge]["BackgroundColor3"] = colorKey
            TabBadge.BackgroundColor3 = Library.Theme[colorKey]
            self.BadgeValue = value
            return self
        end

        Tab._StatusTooltip = Window:AttachTooltip(Tab.TabBtn, Name .. "  •  idle")
        if options.Status then Tab:SetStatus(options.Status, options.StatusDetail or options.StatusText) end
        if options.Badge ~= nil then Tab:SetBadge(options.Badge, options.BadgeColor) end

        function Tab:ApplyNavigationLayout(mobile, compact, animated)
            if self.IsSettings or self.IsOverview or not self.TabBtn then return end
            local iconOnly = mobile or compact
            applyLayout(self.TabBtn, {
                Size = iconOnly and UDim2.fromOffset(tabBtnSize, tabBtnSize) or UDim2.new(1, 0, 0, tabBtnSize)
            }, animated)
            if self.TabEmoji then
                applyLayout(self.TabEmoji, {
                    Position = iconOnly and UDim2.fromScale(0.18, 0.18) or UDim2.fromOffset(6, 5),
                    Size = iconOnly and UDim2.fromScale(0.64, 0.64) or UDim2.fromOffset(32, 32)
                }, animated)
            end
            setNavigationLabel(self.TabLabel, not iconOnly, animated)
        end

        local useSingleColumn = IsMobile
        local Page = Utility:Create("ScrollingFrame", {
            Name = Name,
            Parent = Pages,
            BackgroundTransparency = 1,
            Position = UDim2.new(0, IsMobile and 10 or 20, 0, IsMobile and 92 or 70),
            Size = UDim2.new(1, IsMobile and -20 or -40, 1, IsMobile and -102 or -90),
            ScrollBarThickness = 2,
            ScrollBarImageColor3 = Library.Theme.Accent,
            ScrollingDirection = Enum.ScrollingDirection.Y,
            ElasticBehavior = Enum.ElasticBehavior.WhenScrollable,
            VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
            Active = true,
            CanvasSize = UDim2.new(0, 0, 0, 0),
            Visible = false,
            ZIndex = 2,
            BorderSizePixel = 0
        })
        Utility:RegisterProperty(Page, "ScrollBarImageColor3", "Accent")
        Tab.Page = Page

        local LeftColumn = Utility:Create("Frame", {
            Name = "Left",
            Parent = Page,
            BackgroundTransparency = 1,
            Size = useSingleColumn and UDim2.new(1, 0, 1, 0) or UDim2.new(0.5, -4, 1, 0),
            Position = UDim2.new(0, 0, 0, 0),
            ZIndex = 2,
            BorderSizePixel = 0
        })
        local RightColumn = Utility:Create("Frame", {
            Name = "Right",
            Parent = Page,
            BackgroundTransparency = 1,
            Size = UDim2.new(0.5, -4, 1, 0),
            Position = UDim2.new(0.5, 4, 0, 0),
            Visible = not useSingleColumn,
            ZIndex = 2,
            BorderSizePixel = 0
        })
        local LeftLayout = Utility:Create("UIListLayout", {
            Parent = LeftColumn,
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, 8)
        })
        local RightLayout = Utility:Create("UIListLayout", {
            Parent = RightColumn,
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, 8)
        })

        local function UpdateCanvas()
            local LeftH = LeftLayout.AbsoluteContentSize.Y
            local RightH = useSingleColumn and 0 or RightLayout.AbsoluteContentSize.Y
            Page.CanvasSize = UDim2.new(0, 0, 0, Tab.HeaderHeight + math.max(LeftH, RightH) + 14)
        end
        Library:Connect(LeftLayout:GetPropertyChangedSignal("AbsoluteContentSize"), UpdateCanvas)
        Library:Connect(RightLayout:GetPropertyChangedSignal("AbsoluteContentSize"), UpdateCanvas)

        function Tab:ApplyResponsiveLayout(mobile, topInset, phoneCompact)
            useSingleColumn = mobile
            local pageTop = mobile and ((topInset or 88) + 4) or 70
            local pageMargin = phoneCompact and 5 or (mobile and 8 or 14)
            Page.Position = UDim2.new(0, pageMargin, 0, pageTop)
            Page.Size = UDim2.new(1, -pageMargin * 2, 1, -(pageTop + (phoneCompact and 6 or 10)))
            Page.ScrollBarThickness = mobile and 3 or 2
            LeftColumn.Size = mobile and UDim2.new(1, 0, 1, 0) or UDim2.new(0.5, -4, 1, 0)
            LeftColumn.Position = UDim2.new(0, 0, 0, Tab.HeaderHeight)
            RightColumn.Size = UDim2.new(0.5, -4, 1, 0)
            RightColumn.Position = UDim2.new(0.5, 4, 0, Tab.HeaderHeight)
            RightColumn.Visible = not mobile
            LeftLayout.Padding = UDim.new(0, mobile and 7 or 8)
            for _, section in ipairs(Tab.Sections) do
                if mobile then
                    section.SectionFrame.Parent = LeftColumn
                elseif section.RequestedSide == "Right" then
                    section.SectionFrame.Parent = RightColumn
                elseif section.RequestedSide == "Auto" and LeftLayout.AbsoluteContentSize.Y > RightLayout.AbsoluteContentSize.Y then
                    section.SectionFrame.Parent = RightColumn
                else
                    section.SectionFrame.Parent = LeftColumn
                end
            end
            UpdateCanvas()
            task.defer(UpdateCanvas)
            for _, callback in ipairs(Tab.ResponsiveCallbacks) do
                Utility:SafeCall(callback, mobile, Page.AbsoluteSize)
            end
        end

        function Tab:OnResponsive(callback)
            table.insert(self.ResponsiveCallbacks, callback)
            return self
        end

        function Tab:SetHeader(frame, height)
            frame.Parent = Page
            frame.LayoutOrder = -1000
            self.HeaderHeight = math.max(0, tonumber(height) or 0)
            LeftColumn.Position = UDim2.new(0, 0, 0, self.HeaderHeight)
            RightColumn.Position = UDim2.new(0.5, 6, 0, self.HeaderHeight)
            UpdateCanvas()
            return frame
        end

        function Tab:ApplyActiveVisual(active, animated)
            local tweenInfo = TweenInfo.new(animated == false and 0 or 0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
            if Tab.TabBtn then
                Utility:Tween(Tab.TabBtn, tweenInfo, {BackgroundTransparency = active and 1 or 0.64})
            end
            if Tab.TabStroke then
                Utility:Tween(Tab.TabStroke, tweenInfo, {
                    Color = active and Library.Theme.Accent or Library.Theme.Stroke,
                    Transparency = active and 0.08 or 0.24
                })
            end
            if Tab.TabLabel then
                Utility:Tween(Tab.TabLabel, tweenInfo, {TextColor3 = active and Library.Theme.Text or Library.Theme.SubText})
            end
            if TabEmoji then
                if TabEmoji:IsA("TextLabel") then
                    Utility:Tween(TabEmoji, tweenInfo, {TextColor3 = active and Library.Theme.Text or Library.Theme.SubText})
                elseif TabEmoji:IsA("ImageLabel") then
                    Utility:Tween(TabEmoji, tweenInfo, {ImageColor3 = active and Library.Theme.Text or Library.Theme.SubText})
                end
            end
            if Indicator then Indicator.BackgroundTransparency = 1 end
        end

        function Tab:Activate(selectOptions)
            selectOptions = selectOptions or {}
            if selectOptions.ResetScroll == nil then selectOptions.ResetScroll = true end
            return Window:SelectTab(Tab, selectOptions)
        end

        function Tab:Deactivate()
            if Window.ActiveTab == Tab then return Window:SelectTab(nil) end
            return true
        end

        if TabBtn then
            Library:Connect(TabBtn.MouseButton1Click, function() Tab:Activate() end)
            Library:Connect(TabBtn.MouseEnter, function()
                if not Tab.Active then Utility:Tween(TabBtn, TweenInfo.new(0.15), {BackgroundTransparency = 0.4}) end
            end)
            Library:Connect(TabBtn.MouseLeave, function()
                if not Tab.Active then Utility:Tween(TabBtn, TweenInfo.new(0.15), {BackgroundTransparency = 0.64}) end
            end)
        end

        table.insert(Window.Tabs, Tab)
        if not IsSettings and not IsOverview then
            Window:RegisterCommand({
                Id = "tab-" .. Name, Name = "Go to " .. Name,
                Description = "Open the " .. Name .. " tab.", Category = "Navigation",
                Synonyms = options.Synonyms or {Name, "open " .. Name, "show " .. Name},
                Callback = function() Tab:Activate({ResetScroll = false, Animate = true}) end
            })
        end
        Tab:ApplyResponsiveLayout(IsMobile, Window.ContentTopInset)
        if not IsSettings and not IsOverview and not Window.ActiveTab then
            Tab:Activate()
        end


--[[ MODULE: 81_sections.part.lua ]]
-- Module fragment: section composition and controller contracts
-- Generated from the working V7 baseline; edit this feature in isolation.
        --// SECTIONS
        function Tab:CreateSection(options)
            options = options or {}
            local SectionName = options.Name or "Section"
            local Side = options.Side or "Auto"
            local SectionIcon = Utility:NormalizeAssetId(options.Icon)

            local ParentCol = LeftColumn
            if not useSingleColumn then
                if Side == "Right" then
                    ParentCol = RightColumn
                elseif Side == "Auto" then
                    if LeftLayout.AbsoluteContentSize.Y > RightLayout.AbsoluteContentSize.Y then
                        ParentCol = RightColumn
                    end
                end
            end

            local Section = { Name = SectionName, RequestedSide = Side, Elements = {}, SectionFrame = nil, ContentContainer = nil }
            table.insert(Tab.Sections, Section)

            local SectionFrame = Utility:Create("Frame", {
                Name = SectionName,
                Parent = ParentCol,
                BackgroundColor3 = Library.Theme.Secondary,
                Size = UDim2.new(1, 0, 0, 50),
                -- Allow expanded controls to render above the section frame.
                ClipsDescendants = false,
                ZIndex = 3,
                BorderSizePixel = 0
            })
            Utility:RegisterProperty(SectionFrame, "BackgroundColor3", "Secondary")
            Utility:RegisterMaterial(SectionFrame, 0.16, 0)
            Utility:Create("UICorner", {CornerRadius = UDim.new(0, 9), Parent = SectionFrame})
            local sectionStroke = Utility:Create("UIStroke", {
                Parent = SectionFrame,
                Color = Library.Theme.Stroke,
                Thickness = 1,
                Transparency = 0.72,
                Enabled = options.Outline == true
            })
            Utility:RegisterProperty(sectionStroke, "Color", "Stroke")
            local sectionGradient = Utility:Create("UIGradient", {Parent = SectionFrame, Rotation = 105})
            Utility:RegisterGradient(sectionGradient, "Surface", "Secondary")
            local sectionAccent = Utility:Create("Frame", {
                Parent = SectionFrame,
                BackgroundColor3 = Library.Theme.Accent,
                Position = UDim2.fromOffset(10, 11),
                Size = UDim2.fromOffset(3, 14),
                BorderSizePixel = 0,
                ZIndex = 5
            })
            Utility:RegisterProperty(sectionAccent, "BackgroundColor3", "Accent")
            Utility:Create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = sectionAccent})
            if SectionIcon then
                sectionAccent.Visible = false
                local sectionIcon = Utility:Create("ImageLabel", {
                    Parent = SectionFrame, BackgroundTransparency = 1,
                    Position = UDim2.fromOffset(9, 8), Size = UDim2.fromOffset(19, 19),
                    Image = SectionIcon, ImageColor3 = Library.Theme.Accent,
                    ScaleType = Enum.ScaleType.Fit, ZIndex = 5
                })
                Utility:RegisterProperty(sectionIcon, "ImageColor3", "Accent")
            end
            Section.SectionFrame = SectionFrame

            local Head = Utility:Create("TextLabel", {
                Parent = SectionFrame,
                BackgroundTransparency = 1,
                Position = UDim2.new(0, SectionIcon and 35 or 20, 0, 8),
                Size = UDim2.new(1, SectionIcon and -45 or -30, 0, 20),
                Font = Enum.Font.GothamBold,
                Text = SectionName,
                TextColor3 = Library.Theme.Text,
                TextSize = IsMobile and 11 or 12,
                TextXAlignment = Enum.TextXAlignment.Left,
                ZIndex = 4
            })
            Utility:RegisterProperty(Head, "TextColor3", "Text")

            local ContentContainer = Utility:Create("Frame", {
                Parent = SectionFrame,
                BackgroundColor3 = Library.Theme.Secondary,
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 10, 0, IsMobile and 31 or 32),
                Size = UDim2.new(1, -20, 0, 0),
                ZIndex = 4,
                BorderSizePixel = 0
            })
            Utility:RegisterProperty(ContentContainer, "BackgroundColor3", "Secondary")
            Utility:Create("UIPadding", {
                Parent = ContentContainer,
                PaddingLeft = UDim.new(0, 0), PaddingRight = UDim.new(0, 0),
                PaddingTop = UDim.new(0, 2), PaddingBottom = UDim.new(0, 8)
            })
            Section.ContentContainer = ContentContainer

            local ContentLayout = Utility:Create("UIListLayout", {
                Parent = ContentContainer,
                SortOrder = Enum.SortOrder.LayoutOrder,
                Padding = UDim.new(0, IsMobile and math.min(4, Window.ContentSpacing) or Window.ContentSpacing)
            })

            local function RefreshLayout()
                ContentContainer.Size = UDim2.new(1, -20, 0, ContentLayout.AbsoluteContentSize.Y + 10)
                SectionFrame.Size = UDim2.new(1, 0, 0, ContentLayout.AbsoluteContentSize.Y + (IsMobile and 43 or 44))
            end

            Section.ContentLayout = ContentLayout
            Section.Outline = sectionStroke
            function Section:SetSpacing(value)
                ContentLayout.Padding = UDim.new(0, math.clamp(tonumber(value) or 5, 0, 24))
                RefreshLayout()
                return self
            end
            function Section:SetOutlineVisible(value)
                sectionStroke.Enabled = value == true
                return self
            end
            function Section:SetSurfaceTransparency(value)
                SectionFrame.BackgroundTransparency = math.clamp(tonumber(value) or 0, 0, 1)
                return self
            end

            Library:Connect(ContentLayout:GetPropertyChangedSignal("AbsoluteContentSize"), function()
                ContentContainer.Size = UDim2.new(1, -20, 0, ContentLayout.AbsoluteContentSize.Y + 10)
                Utility:Tween(SectionFrame, TweenInfo.new(0.2), {
                    Size = UDim2.new(1, 0, 0, ContentLayout.AbsoluteContentSize.Y + (IsMobile and 43 or 44))
                })
            end)

            local function addElement(element)
                table.insert(Section.Elements, element)
                -- Only re-parent if the holder isn't already in ContentContainer
                if element.Holder and element.Holder.Parent ~= ContentContainer then
                    element.Holder.Parent = ContentContainer
                end
                if Window.SearchQuery ~= "" and Window.RefreshSearch then
                    task.defer(function()
                        if not Library.Unloaded then Window:RefreshSearch(Window.SearchQuery) end
                    end)
                end
            end

            local function createBadge(parent, text, colorKey, layoutOrder)
                text = tostring(text or "")
                if text == "" then return nil end
                colorKey = Library.Theme[colorKey] and colorKey or "Accent"
                local width = math.clamp(TextService:GetTextSize(text, 9, Enum.Font.GothamBold, Vector2.new(96, 18)).X + 14, 34, 96)
                local badge = Utility:Create("TextLabel", {
                    Name = "Badge", Parent = parent, BackgroundColor3 = Library.Theme[colorKey],
                    BackgroundTransparency = 0.78, Size = UDim2.fromOffset(width, 18),
                    Text = text, TextColor3 = Library.Theme[colorKey], Font = Enum.Font.GothamBold,
                    TextSize = 9, TextTruncate = Enum.TextTruncate.AtEnd,
                    LayoutOrder = layoutOrder or 0, BorderSizePixel = 0, ZIndex = (parent.ZIndex or 5) + 1
                })
                Utility:RegisterProperty(badge, "BackgroundColor3", colorKey)
                Utility:RegisterProperty(badge, "TextColor3", colorKey)
                Utility:Create("UICorner", {Parent = badge, CornerRadius = UDim.new(1, 0)})
                return badge
            end

            local function finishController(controller, holder, name, tooltip)
                controller = controller or {}
                controller.Holder = holder
                controller.Name = name
                controller.Locked = false
                if holder:IsA("GuiObject") and holder.BackgroundTransparency < 0.98 and not Library.MaterialRegistry[holder] then
                    Utility:RegisterMaterial(holder, math.min(0.48, holder.BackgroundTransparency + 0.3), holder.BackgroundTransparency)
                end
                local nestedHost, nestedLayout
                local nestedBaseHeight = holder.Size.Y.Offset
                local nestedVisible = true

                local function refreshNested()
                    if not nestedHost then return end
                    local nestedHeight = nestedVisible and (nestedLayout.AbsoluteContentSize.Y + 16) or 0
                    nestedHost.Visible = nestedVisible
                    nestedHost.Size = UDim2.new(1, -16, 0, nestedHeight)
                    holder.Size = UDim2.new(holder.Size.X.Scale, holder.Size.X.Offset, 0, nestedBaseHeight + (nestedHeight > 0 and nestedHeight + 8 or 0))
                    RefreshLayout()
                end

                function controller:AddNested(childController)
                    if not childController or not childController.Holder then return self end
                    if not nestedHost then
                        holder.ClipsDescendants = true
                        nestedHost = Utility:Create("Frame", {
                            Name = "NestedControls", Parent = holder, BackgroundColor3 = Library.Theme.Main,
                            BackgroundTransparency = 0.22, Position = UDim2.new(0, 8, 0, nestedBaseHeight),
                            Size = UDim2.new(1, -16, 0, 0), BorderSizePixel = 0,
                            ClipsDescendants = true, ZIndex = holder.ZIndex + 2
                        })
                        Utility:RegisterProperty(nestedHost, "BackgroundColor3", "Main")
                        Utility:RegisterMaterial(nestedHost, 0.48, 0.22)
                        Utility:Create("UICorner", {CornerRadius = UDim.new(0, 7), Parent = nestedHost})
                        local nestedStroke = Utility:Create("UIStroke", {Parent = nestedHost, Color = Library.Theme.Divider, Thickness = 1, Transparency = 0.15})
                        Utility:RegisterProperty(nestedStroke, "Color", "Divider")
                        Utility:Create("UIPadding", {
                            Parent = nestedHost, PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8),
                            PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8)
                        })
                        nestedLayout = Utility:Create("UIListLayout", {
                            Parent = nestedHost, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6)
                        })
                        Library:Connect(nestedLayout:GetPropertyChangedSignal("AbsoluteContentSize"), refreshNested)
                    end
                    childController.Holder.Parent = nestedHost
                    childController.NestedParent = self
                    for _, sectionElement in ipairs(Section.Elements) do
                        if sectionElement.Holder == childController.Holder then
                            sectionElement.NestedParentHolder = holder
                            break
                        end
                    end
                    childController.Holder.LayoutOrder = #nestedHost:GetChildren()
                    Library:Connect(childController.Holder:GetPropertyChangedSignal("Size"), refreshNested)
                    task.defer(refreshNested)
                    return self
                end

                function controller:SetNestedVisible(visible)
                    nestedVisible = visible == true
                    refreshNested()
                    return self
                end
                local blocker
                local loadingOverlay
                local loadingToken = 0
                function controller:SetVisible(visible)
                    holder.Visible = visible == true
                    RefreshLayout()
                end
                function controller:Destroy()
                    holder:Destroy()
                    RefreshLayout()
                end
                function controller:SetLocked(locked)
                    self.Locked = locked == true
                    if self.Locked and not blocker then
                        blocker = Utility:Create("TextButton", {
                            Name = "RenLibLock",
                            Parent = holder,
                            BackgroundColor3 = Library.Theme.Main,
                            BackgroundTransparency = 0.35,
                            Size = UDim2.fromScale(1, 1),
                            Text = EMOJIS.Lock,
                            TextColor3 = Library.Theme.SubText,
                            TextSize = 14,
                            AutoButtonColor = false,
                            ZIndex = 100
                        })
                        Utility:Create("UICorner", {CornerRadius = UDim.new(0, 6), Parent = blocker})
                    elseif blocker then
                        blocker:Destroy()
                        blocker = nil
                    end
                end
                function controller:SetLoading(loading, message)
                    loadingToken = loadingToken + 1
                    local token = loadingToken
                    if loading == true then
                        if not loadingOverlay then
                            loadingOverlay = Utility:Create("Frame", {
                                Name = "RenLibLoading", Parent = holder, BackgroundColor3 = Library.Theme.Main,
                                BackgroundTransparency = 0.18, Size = UDim2.fromScale(1, 1),
                                BorderSizePixel = 0, ZIndex = 110
                            })
                            Utility:RegisterProperty(loadingOverlay, "BackgroundColor3", "Main")
                            Utility:Create("UICorner", {Parent = loadingOverlay, CornerRadius = UDim.new(0, 6)})
                            local loadingText = Utility:Create("TextLabel", {
                                Name = "Status", Parent = loadingOverlay, BackgroundTransparency = 1,
                                Size = UDim2.fromScale(1, 1), Text = tostring(message or "Loading…"),
                                TextColor3 = Library.Theme.Text, Font = Enum.Font.GothamBold,
                                TextSize = 12, ZIndex = 111
                            })
                            Utility:RegisterProperty(loadingText, "TextColor3", "Text")
                        else
                            loadingOverlay.Status.Text = tostring(message or "Loading…")
                            loadingOverlay.Status.TextTransparency = 0
                            loadingOverlay.Visible = true
                        end
                        task.spawn(function()
                            local dim = false
                            while token == loadingToken and loadingOverlay and loadingOverlay.Parent and not Library.Unloaded do
                                dim = not dim
                                Utility:Tween(loadingOverlay.Status, TweenInfo.new(0.45), {TextTransparency = dim and 0.45 or 0})
                                task.wait(0.5)
                            end
                        end)
                    elseif loadingOverlay then
                        loadingOverlay.Visible = false
                    end
                    return self
                end
                function controller:SetTooltip(text)
                    self.Tooltip = tostring(text or "")
                    if self._TooltipAttached then
                        self._TooltipAttached:Set(self.Tooltip)
                    elseif self.Tooltip ~= "" then
                        self._TooltipAttached = Window:AttachTooltip(holder, self.Tooltip)
                    end
                    return self
                end
                function controller:Lock() self:SetLocked(true) end
                function controller:Unlock() self:SetLocked(false) end
                if tooltip ~= nil then controller:SetTooltip(tooltip) end
                return controller
            end


--[[ MODULE: 82_input.part.lua ]]
-- Module fragment: text input control
-- Generated from the working V7 baseline; edit this feature in isolation.
            -- TEXT INPUT
            function Section:CreateInput(options)
                options = options or {}
                local name = options.Name or "Input"
                local flag = options.Flag or name
                local value = tostring(Library.Flags[flag] ~= nil and Library.Flags[flag] or options.Default or "")
                local listeners = {}
                local multiline = options.MultiLine == true
                local container = Utility:Create("Frame", {
                    Name = name,
                    Parent = ContentContainer,
                    BackgroundColor3 = Library.Theme.Surface,
                    Size = UDim2.new(1, 0, 0, multiline and 82 or 44),
                    BorderSizePixel = 0,
                    ZIndex = 5
                })
                Utility:RegisterProperty(container, "BackgroundColor3", "Surface")
                Utility:Create("UICorner", {CornerRadius = UDim.new(0, 6), Parent = container})
                local inputStroke = Utility:Create("UIStroke", {Parent = container, Color = Library.Theme.Stroke, Thickness = 1})
                Utility:RegisterProperty(inputStroke, "Color", "Stroke")
                local box = Utility:Create("TextBox", {
                    Parent = container,
                    BackgroundTransparency = 1,
                    Position = UDim2.new(0, 12, 0, multiline and 8 or 0),
                    Size = UDim2.new(1, -24, 1, multiline and -16 or 0),
                    ClearTextOnFocus = false,
                    MultiLine = multiline,
                    PlaceholderText = options.Placeholder or name,
                    Text = value,
                    TextColor3 = Library.Theme.Text,
                    PlaceholderColor3 = Library.Theme.SubText,
                    Font = Enum.Font.Gotham,
                    TextSize = IsMobile and 12 or 13,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextYAlignment = multiline and Enum.TextYAlignment.Top or Enum.TextYAlignment.Center,
                    TextWrapped = multiline,
                    ZIndex = 6
                })
                Utility:RegisterProperty(box, "TextColor3", "Text")
                Utility:RegisterProperty(box, "PlaceholderColor3", "SubText")

                local function setValue(nextValue, fire)
                    value = tostring(nextValue or "")
                    if options.Numeric then
                        value = value:gsub("[^%d%.%-]", "")
                    end
                    box.Text = value
                    Library.Flags[flag] = options.Numeric and tonumber(value) or value
                    if fire ~= false then
                        Utility:SafeCall(options.Callback, Library.Flags[flag])
                        for _, listener in ipairs(listeners) do Utility:SafeCall(listener, Library.Flags[flag]) end
                    end
                end
                Library.Flags[flag] = options.Numeric and tonumber(value) or value
                Library:Connect(box.Focused, function()
                    Utility:Tween(inputStroke, TweenInfo.new(0.18), {Color = Library.Theme.Accent})
                end)
                Library:Connect(box.FocusLost, function(enterPressed)
                    setValue(box.Text, true)
                    Utility:Tween(inputStroke, TweenInfo.new(0.18), {Color = Library.Theme.Stroke})
                    if options.Finished then Utility:SafeCall(options.Finished, Library.Flags[flag], enterPressed) end
                end)
                local controller = finishController({
                    Type = "Input",
                    Set = function(self, nextValue) setValue(nextValue, true) end,
                    Get = function() return Library.Flags[flag] end,
                    OnChanged = function(self, fn) table.insert(listeners, fn) end
                }, container, name, options.Tooltip)
                Library:RegisterOption(flag, controller, options.Numeric and tonumber(options.Default) or tostring(options.Default or ""))
                addElement({Holder = container, Text = name})
                return controller
            end

            function Section:CreateParagraph(options)
                if type(options) == "string" then options = {Content = options} end
                options = options or {}
                local title = options.Title or ""
                local content = options.Content or options.Text or ""
                local container = Utility:Create("Frame", {
                    Parent = ContentContainer,
                    BackgroundColor3 = Library.Theme.Surface,
                    Size = UDim2.new(1, 0, 0, 56),
                    BorderSizePixel = 0,
                    ZIndex = 5
                })
                Utility:RegisterProperty(container, "BackgroundColor3", "Surface")
                Utility:Create("UICorner", {CornerRadius = UDim.new(0, 6), Parent = container})
                local titleLabel = Utility:Create("TextLabel", {
                    Parent = container, BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 8),
                    Size = UDim2.new(1, -24, 0, title == "" and 0 or 18), Font = Enum.Font.GothamBold,
                    Text = title, TextColor3 = Library.Theme.Text, TextSize = 13,
                    TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 6
                })
                local contentLabel = Utility:Create("TextLabel", {
                    Parent = container, BackgroundTransparency = 1,
                    Position = UDim2.fromOffset(12, title == "" and 8 or 29), Size = UDim2.new(1, -24, 0, 20),
                    Font = Enum.Font.Gotham, Text = content, TextColor3 = Library.Theme.SubText,
                    TextSize = 12, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
                    TextYAlignment = Enum.TextYAlignment.Top, AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 6
                })
                Utility:RegisterProperty(titleLabel, "TextColor3", "Text")
                Utility:RegisterProperty(contentLabel, "TextColor3", "SubText")
                local function resize()
                    container.Size = UDim2.new(1, 0, 0, (title == "" and 16 or 37) + math.max(20, contentLabel.TextBounds.Y))
                    RefreshLayout()
                end
                Library:Connect(contentLabel:GetPropertyChangedSignal("TextBounds"), resize)
                local controller = finishController({
                    SetTitle = function(self, text) title = tostring(text); titleLabel.Text = title; resize() end,
                    SetContent = function(self, text) contentLabel.Text = tostring(text); resize() end
                }, container, title, options.Tooltip)
                addElement({Holder = container, Text = title .. " " .. content})
                task.defer(resize)
                return controller
            end

            function Section:CreateMetric(options)
                options = options or {}
                local name = tostring(options.Name or "Metric")
                local value = tostring(options.Value or "--")
                local detail = tostring(options.Detail or "")
                local container = Utility:Create("Frame", {
                    Parent = ContentContainer,
                    BackgroundColor3 = Library.Theme.Surface,
                    Size = UDim2.new(1, 0, 0, detail ~= "" and 54 or 42),
                    BorderSizePixel = 0,
                    ZIndex = 5
                })
                Utility:RegisterProperty(container, "BackgroundColor3", "Surface")
                Utility:Create("UICorner", {CornerRadius = UDim.new(0, 7), Parent = container})
                local accent = Utility:Create("Frame", {
                    Parent = container, BackgroundColor3 = Library.Theme.Accent,
                    Position = UDim2.new(0, 0, 0, 8), Size = UDim2.new(0, 3, 1, -16),
                    BorderSizePixel = 0, ZIndex = 6
                })
                Utility:RegisterProperty(accent, "BackgroundColor3", "Accent")
                Utility:Create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = accent})
                local nameLabel = Utility:Create("TextLabel", {
                    Parent = container, BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 5),
                    Size = UDim2.new(0.62, -12, 0, 20), Text = name, TextColor3 = Library.Theme.Text,
                    Font = Enum.Font.GothamMedium, TextSize = IsMobile and 11 or 12,
                    TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 6
                })
                Utility:RegisterProperty(nameLabel, "TextColor3", "Text")
                local valueLabel = Utility:Create("TextLabel", {
                    Parent = container, BackgroundTransparency = 1, Position = UDim2.new(0.62, 0, 0, 5),
                    Size = UDim2.new(0.38, -12, 0, 20), Text = value, TextColor3 = Library.Theme.Accent,
                    Font = Enum.Font.GothamBold, TextSize = IsMobile and 12 or 14,
                    TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 6
                })
                Utility:RegisterProperty(valueLabel, "TextColor3", "Accent")
                local detailLabel
                if detail ~= "" then
                    detailLabel = Utility:Create("TextLabel", {
                        Parent = container, BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 27),
                        Size = UDim2.new(1, -24, 0, 17), Text = detail, TextColor3 = Library.Theme.SubText,
                        Font = Enum.Font.Gotham, TextSize = 10, TextTruncate = Enum.TextTruncate.AtEnd,
                        TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 6
                    })
                    Utility:RegisterProperty(detailLabel, "TextColor3", "SubText")
                end
                local controller = finishController({
                    Type = "Metric",
                    SetValue = function(self, nextValue) valueLabel.Text = tostring(nextValue) end,
                    SetDetail = function(self, nextDetail) if detailLabel then detailLabel.Text = tostring(nextDetail) end end
                }, container, name, options.Tooltip)
                addElement({Holder = container, Text = name .. " " .. value .. " " .. detail})
                return controller
            end

            function Section:CreateDivider(text)
                local container = Utility:Create("Frame", {
                    Parent = ContentContainer, BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, text and 24 or 12), ZIndex = 5
                })
                local line = Utility:Create("Frame", {
                    Parent = container, BackgroundColor3 = Library.Theme.Divider,
                    Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.new(1, 0, 0, 1), BorderSizePixel = 0, ZIndex = 5
                })
                Utility:RegisterProperty(line, "BackgroundColor3", "Divider")
                if text then
                    local label = Utility:Create("TextLabel", {
                        Parent = container, BackgroundColor3 = Library.Theme.Secondary,
                        Position = UDim2.new(0.5, -50, 0.5, -10), Size = UDim2.fromOffset(100, 20),
                        Text = tostring(text), TextColor3 = Library.Theme.SubText, Font = Enum.Font.Gotham,
                        TextSize = 11, ZIndex = 6
                    })
                    Utility:RegisterProperty(label, "BackgroundColor3", "Secondary")
                    Utility:RegisterProperty(label, "TextColor3", "SubText")
                end
                addElement({Holder = container, Text = text or ""})
                return finishController({}, container, text or "Divider")
            end


--[[ MODULE: 83_button.part.lua ]]
-- Module fragment: button control
-- Generated from the working V7 baseline; edit this feature in isolation.
            -- BUTTON
            function Section:CreateButton(options)
                options = options or {}
                local Name = options.Name or "Button"
                local Callback = options.Callback or function() end
                local Description = tostring(options.Description or "")
                local ButtonIconAsset = Utility:NormalizeAssetId(options.Icon)
                local ButtonActionId = normalizeActionId(options.Id or (Tab.Name .. "-" .. SectionName .. "-" .. Name))

                local btnHeight = Description ~= "" and (IsMobile and 56 or 54) or (IsMobile and 44 or 42)
                local ButtonContainer = Utility:Create("Frame", {
                    Name = Name,
                    Parent = ContentContainer,
                    BackgroundColor3 = Library.Theme.Surface,
                    Size = UDim2.new(1, 0, 0, btnHeight),
                    ClipsDescendants = true,
                    ZIndex = 5,
                    BorderSizePixel = 0
                })
                Utility:RegisterProperty(ButtonContainer, "BackgroundColor3", "Surface")
                Utility:Create("UICorner", {CornerRadius = UDim.new(0, 6), Parent = ButtonContainer})
                local Stroke = Utility:Create("UIStroke", {
                    Parent = ButtonContainer,
                    Color = Library.Theme.Stroke,
                    Thickness = 1
                })
                Utility:RegisterProperty(Stroke, "Color", "Stroke")

                local Btn = Utility:Create("TextButton", {
                    Parent = ButtonContainer,
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 1, 0),
                    Text = "",
                    AutoButtonColor = false,
                    ZIndex = 9,
                    BorderSizePixel = 0
                })

                local textInset = ButtonIconAsset and 44 or 12
                if ButtonIconAsset then
                    local ButtonIcon = Utility:Create("ImageLabel", {
                        Parent = ButtonContainer,
                        BackgroundTransparency = 1,
                        Position = UDim2.new(0, 12, 0.5, -10),
                        Size = UDim2.fromOffset(20, 20),
                        Image = ButtonIconAsset,
                        ImageColor3 = Library.Theme.SubText,
                        ScaleType = Enum.ScaleType.Fit,
                        ZIndex = 7
                    })
                    Utility:RegisterProperty(ButtonIcon, "ImageColor3", "SubText")
                end
                local ButtonTitle = Utility:Create("TextLabel", {
                    Parent = ButtonContainer,
                    BackgroundTransparency = 1,
                    Position = UDim2.new(0, textInset, 0, Description ~= "" and 7 or 0),
                    Size = UDim2.new(1, -(textInset + 32), 0, Description ~= "" and 20 or btnHeight),
                    Font = Enum.Font.GothamMedium,
                    Text = Name,
                    TextColor3 = Library.Theme.Text,
                    TextSize = IsMobile and 12 or 13,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    ZIndex = 7
                })
                Utility:RegisterProperty(ButtonTitle, "TextColor3", "Text")
                local ButtonDescription
                if Description ~= "" then
                    ButtonDescription = Utility:Create("TextLabel", {
                        Parent = ButtonContainer,
                        BackgroundTransparency = 1,
                        Position = UDim2.new(0, textInset, 0, 27),
                        Size = UDim2.new(1, -(textInset + 32), 0, 17),
                        Font = Enum.Font.Gotham,
                        Text = Description,
                        TextColor3 = Library.Theme.SubText,
                        TextSize = IsMobile and 10 or 11,
                        TextTruncate = Enum.TextTruncate.AtEnd,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        ZIndex = 7
                    })
                    Utility:RegisterProperty(ButtonDescription, "TextColor3", "SubText")
                end
                local ButtonArrow = Utility:Create("ImageLabel", {
                    Parent = ButtonContainer,
                    BackgroundTransparency = 1,
                    Position = UDim2.new(1, -24, 0.5, -8),
                    Size = UDim2.fromOffset(16, 16),
                    Image = ICONS.ChevronRight,
                    ImageColor3 = Library.Theme.SubText,
                    ScaleType = Enum.ScaleType.Fit,
                    ZIndex = 7
                })
                Utility:RegisterProperty(ButtonArrow, "ImageColor3", "SubText")

                Library:Connect(Btn.MouseEnter, function()
                    Utility:Tween(Stroke, TweenInfo.new(0.2), {Color = Library.Theme.Accent})
                    Utility:Tween(ButtonContainer, TweenInfo.new(0.2), {BackgroundColor3 = Library.Theme.Hover})
                end)
                Library:Connect(Btn.MouseLeave, function()
                    Utility:Tween(Stroke, TweenInfo.new(0.2), {Color = Library.Theme.Stroke})
                    Utility:Tween(ButtonContainer, TweenInfo.new(0.2), {BackgroundColor3 = Library.Theme.Surface})
                end)
                Library:Connect(Btn.MouseButton1Click, function()
                    if IsMobile then
                        Utility:Tween(Stroke, TweenInfo.new(0.1), {Color = Library.Theme.Accent})
                        Utility:Tween(ButtonContainer, TweenInfo.new(0.1), {BackgroundColor3 = Library.Theme.Hover})
                        task.delay(0.15, function()
                            Utility:Tween(Stroke, TweenInfo.new(0.2), {Color = Library.Theme.Stroke})
                            Utility:Tween(ButtonContainer, TweenInfo.new(0.2), {BackgroundColor3 = Library.Theme.Surface})
                        end)
                    end
                    local ok, err = Window:ExecuteCommand(ButtonActionId)
                    if not ok then Library:Notify({Title = "Action unavailable", Content = tostring(err), Duration = 3}) end
                end)
                Window:RegisterCommand({
                    Id = ButtonActionId, Name = Name, Description = Description,
                    Category = options.Category or (Tab.Name .. " / " .. SectionName),
                    Synonyms = options.Synonyms or options.Aliases,
                    Requirement = options.Requirement, Icon = options.Icon, Callback = Callback
                })
                addElement({Holder = ButtonContainer, Text = Name .. " " .. Description, Synonyms = options.Synonyms or options.Aliases})
                return finishController({
                    SetText = function(self, text) ButtonTitle.Text = tostring(text) end,
                    SetDescription = function(self, text)
                        if ButtonDescription then ButtonDescription.Text = tostring(text) end
                    end
                }, ButtonContainer, Name, options.Tooltip)
            end


--[[ MODULE: 84_toggle.part.lua ]]
-- Module fragment: toggle control
-- Generated from the working V7 baseline; edit this feature in isolation.
            -- TOGGLE
            function Section:CreateToggle(options)
                options = options or {}
                local Name = options.Name or "Toggle"
                local Default = options.Default or false
                local Callback = options.Callback or function() end
                local Flag = options.Flag or Name

                local CurrentValue = Default
                if Library.Flags[Flag] ~= nil then
                    CurrentValue = Library.Flags[Flag]
                end
                Library.Flags[Flag] = CurrentValue

                local toggleHeight = IsMobile and 40 or 40
                local ToggleContainer = Utility:Create("Frame", {
                    Name = Name,
                    Parent = ContentContainer,
                    BackgroundColor3 = Library.Theme.Surface,
                    Size = UDim2.new(1, 0, 0, toggleHeight),
                    ClipsDescendants = true,
                    ZIndex = 5,
                    BorderSizePixel = 0
                })
                Utility:RegisterProperty(ToggleContainer, "BackgroundColor3", "Surface")
                Utility:Create("UICorner", {CornerRadius = UDim.new(0, 6), Parent = ToggleContainer})
                local stroke = Utility:Create("UIStroke", {Parent = ToggleContainer, Color = Library.Theme.Stroke, Thickness = 1})
                Utility:RegisterProperty(stroke, "Color", "Stroke")

                local ToggleBtn = Utility:Create("TextButton", {
                    Parent = ToggleContainer,
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 1, 0),
                    Font = Enum.Font.Gotham,
                    Text = Name,
                    TextColor3 = Library.Theme.Text,
                    TextSize = IsMobile and 12 or 13,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    AutoButtonColor = false,
                    ZIndex = 6,
                    BorderSizePixel = 0
                })
                Utility:RegisterProperty(ToggleBtn, "TextColor3", "Text")
                Utility:Create("UIPadding", {Parent = ToggleBtn, PaddingLeft = UDim.new(0, 12)})

                local switchWidth = IsMobile and 30 or 35
                local switchHeight = IsMobile and 17 or 20
                local dotSize = IsMobile and 13 or 16

                local SwitchBg = Utility:Create("Frame", {
                    Parent = ToggleBtn,
                    BackgroundColor3 = CurrentValue and Library.Theme.Accent or Library.Theme.SurfaceAlt,
                    Position = UDim2.new(1, -(switchWidth + 10), 0.5, -math.floor(switchHeight / 2)),
                    Size = UDim2.new(0, switchWidth, 0, switchHeight),
                    BorderSizePixel = 0,
                    ZIndex = 6
                })
                Utility:RegisterProperty(SwitchBg, "BackgroundColor3", CurrentValue and "Accent" or "SurfaceAlt")
                Utility:Create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = SwitchBg})
                local SwitchDot = Utility:Create("Frame", {
                    Parent = SwitchBg,
                    BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                    Position = CurrentValue and UDim2.new(1, -(dotSize + 2), 0.5, -math.floor(dotSize / 2)) or UDim2.new(0, 2, 0.5, -math.floor(dotSize / 2)),
                    Size = UDim2.new(0, dotSize, 0, dotSize),
                    ZIndex = 7,
                    BorderSizePixel = 0
                })
                Utility:Create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = SwitchDot})

                local changeListeners = {}

                local function Update()
                    Library.Flags[Flag] = CurrentValue
                    Utility:SafeCall(Callback, CurrentValue)
                    if CurrentValue then
                        Library.Registry[SwitchBg]["BackgroundColor3"] = "Accent"
                        Utility:Tween(SwitchBg, TweenInfo.new(0.2), {BackgroundColor3 = Library.Theme.Accent})
                        Utility:Tween(SwitchDot, TweenInfo.new(0.2), {Position = UDim2.new(1, -(dotSize + 2), 0.5, -math.floor(dotSize / 2))})
                    else
                        Library.Registry[SwitchBg]["BackgroundColor3"] = "SurfaceAlt"
                        Utility:Tween(SwitchBg, TweenInfo.new(0.2), {BackgroundColor3 = Library.Theme.SurfaceAlt})
                        Utility:Tween(SwitchDot, TweenInfo.new(0.2), {Position = UDim2.new(0, 2, 0.5, -math.floor(dotSize / 2))})
                    end
                    for _, listener in ipairs(changeListeners) do
                        pcall(listener, CurrentValue)
                    end
                end

                Library:Connect(ToggleBtn.MouseButton1Click, function()
                    CurrentValue = not CurrentValue
                    Update()
                end)
                Library:Connect(ToggleBtn.MouseEnter, function()
                    Utility:Tween(ToggleContainer, TweenInfo.new(0.2), {BackgroundColor3 = Library.Theme.Hover})
                end)
                Library:Connect(ToggleBtn.MouseLeave, function()
                    Utility:Tween(ToggleContainer, TweenInfo.new(0.2), {BackgroundColor3 = Library.Theme.Surface})
                end)

                addElement({Holder = ToggleContainer, Text = Name})

                local toggleObj = {
                    Type = "Toggle",
                    Set = function(self, val)
                        CurrentValue = val
                        Update()
                    end,
                    Get = function() return CurrentValue end,
                    OnChanged = function(self, fn)
                        table.insert(changeListeners, fn)
                    end
                }
                finishController(toggleObj, ToggleContainer, Name, options.Tooltip)
                Library:RegisterOption(Flag, toggleObj, Default)
                return toggleObj
            end


--[[ MODULE: 85_slider.part.lua ]]
-- Module fragment: slider control
-- Generated from the working V7 baseline; edit this feature in isolation.
            -- SLIDER
            function Section:CreateSlider(options)
                options = options or {}
                local Name = options.Name or "Slider"
                local Min = options.Min or 0
                local Max = options.Max or 100
                local Default = options.Default or Min
                local Callback = options.Callback or function() end
                local Flag = options.Flag or Name
                local Step = math.max(tonumber(options.Step) or 1, 0.000001)
                local CallbackMode = options.CallbackMode or (options.CallbackOnRelease and "Release" or "Changed")

                local Value = Default
                if Library.Flags[Flag] ~= nil then Value = Library.Flags[Flag] end
                Library.Flags[Flag] = Value

                local sliderHeight = IsMobile and 44 or 50
                local SliderContainer = Utility:Create("Frame", {
                    Name = Name,
                    Parent = ContentContainer,
                    BackgroundColor3 = Library.Theme.Surface,
                    Size = UDim2.new(1, 0, 0, sliderHeight),
                    ClipsDescendants = true,
                    ZIndex = 5,
                    BorderSizePixel = 0
                })
                Utility:RegisterProperty(SliderContainer, "BackgroundColor3", "Surface")
                Utility:Create("UICorner", {CornerRadius = UDim.new(0, 6), Parent = SliderContainer})
                local stroke = Utility:Create("UIStroke", {Parent = SliderContainer, Color = Library.Theme.Stroke, Thickness = 1})
                Utility:RegisterProperty(stroke, "Color", "Stroke")

                Utility:Create("TextLabel", {
                    Parent = SliderContainer,
                    BackgroundTransparency = 1,
                    Position = UDim2.new(0, 12, 0, IsMobile and 6 or 8),
                    Size = UDim2.new(1, -24, 0, 20),
                    Font = Enum.Font.Gotham,
                    Text = Name,
                    TextColor3 = Library.Theme.Text,
                    TextSize = IsMobile and 12 or 13,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    ZIndex = 6
                })
                local ValueLabel = Utility:Create("TextLabel", {
                    Parent = SliderContainer,
                    BackgroundTransparency = 1,
                    Position = UDim2.new(0, 12, 0, IsMobile and 6 or 8),
                    Size = UDim2.new(1, -24, 0, 20),
                    Font = Enum.Font.GothamBold,
                    Text = tostring(Value),
                    TextColor3 = Library.Theme.SubText,
                    TextSize = IsMobile and 12 or 13,
                    TextXAlignment = Enum.TextXAlignment.Right,
                    ZIndex = 6
                })
                local trackHeight = IsMobile and 10 or 6
                local Track = Utility:Create("TextButton", {
                    Parent = SliderContainer,
                    BackgroundColor3 = Library.Theme.SurfaceAlt,
                    Position = UDim2.new(0, 12, 0, IsMobile and 28 or 34),
                    Size = UDim2.new(1, -24, 0, trackHeight),
                    AutoButtonColor = false,
                    Text = "",
                    ZIndex = 6,
                    BorderSizePixel = 0
                })
                Utility:RegisterProperty(Track, "BackgroundColor3", "SurfaceAlt")
                Utility:Create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = Track})
                local Fill = Utility:Create("Frame", {
                    Parent = Track,
                    BackgroundColor3 = Library.Theme.Accent,
                    Size = UDim2.new((Value - Min) / (Max - Min), 0, 1, 0),
                    BorderSizePixel = 0,
                    ZIndex = 7
                })
                Utility:RegisterProperty(Fill, "BackgroundColor3", "Accent")
                local fillGradient = Utility:Create("UIGradient", {Parent = Fill})
                Utility:RegisterGradient(fillGradient, "Accent", "Accent2", "Accent3")
                Utility:Create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = Fill})
                local Dragging = false
                local DragInput = nil
                local pendingCallback = false

                local function EmitValue()
                    pendingCallback = false
                    Utility:SafeCall(Callback, Value)
                end

                local function UpdateSlider(input)
                    local SizeX = math.clamp((input.Position.X - Track.AbsolutePosition.X) / math.max(1, Track.AbsoluteSize.X), 0, 1)
                    local NewValue = Min + ((Max - Min) * SizeX)
                    NewValue = math.clamp(Min + math.floor(((NewValue - Min) / Step) + 0.5) * Step, Min, Max)
                    Value = NewValue
                    ValueLabel.Text = tostring(Value)
                    Library.Flags[Flag] = Value
                    pendingCallback = true
                    if CallbackMode ~= "Release" then EmitValue() end
                    Utility:Tween(Fill, TweenInfo.new(0.05), {Size = UDim2.new((Value - Min) / math.max(0.000001, Max - Min), 0, 1, 0)})
                end

                Library:Connect(Track.InputBegan, function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                        Dragging = true
                        DragInput = input.UserInputType == Enum.UserInputType.Touch and input or nil
                        UpdateSlider(input)
                    end
                end)
                Library:Connect(UserInputService.InputChanged, function(input)
                    local pointerMove = input.UserInputType == Enum.UserInputType.MouseMovement
                        or (input.UserInputType == Enum.UserInputType.Touch and input == DragInput)
                    if Dragging and pointerMove then
                        UpdateSlider(input)
                    end
                end)
                Library:Connect(UserInputService.InputEnded, function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                        local wasDragging = Dragging
                        Dragging = false
                        if wasDragging and pendingCallback then task.defer(EmitValue) end
                        if wasDragging and options.Finished then task.defer(function() Utility:SafeCall(options.Finished, Value) end) end
                    end
                end)

                addElement({Holder = SliderContainer, Text = Name})
                local function SetValue(val, fire)
                    Value = math.clamp(tonumber(val) or Min, Min, Max)
                    ValueLabel.Text = tostring(Value)
                    Library.Flags[Flag] = Value
                    Utility:Tween(Fill, TweenInfo.new(0.1), {Size = UDim2.new((Value - Min) / math.max(0.000001, Max - Min), 0, 1, 0)})
                    pendingCallback = false
                    if fire ~= false then EmitValue() end
                end
                local sliderObj = {
                    Type = "Slider",
                    Set = function(self, val)
                        SetValue(val, true)
                    end,
                    SetSilent = function(self, val) SetValue(val, false) end,
                    Get = function() return Value end
                }
                finishController(sliderObj, SliderContainer, Name, options.Tooltip)
                Library:RegisterOption(Flag, sliderObj, Default)
                return sliderObj
            end


--[[ MODULE: 86_dropdown.part.lua ]]
-- Module fragment: dropdown controls
-- Generated from the working V7 baseline; edit this feature in isolation.
            -- DROPDOWN
            function Section:CreateDropdown(options)
                options = options or {}
                local Name = options.Name or "Dropdown"
                local Values = options.Values or {}
                local Multi = options.Multi or false
                local Default = options.Default or (Multi and {} or Values[1])
                local Callback = options.Callback or function() end
                local Flag = options.Flag or Name

                local function normalizeMulti(value)
                    if not Multi then return value end
                    local normalized = {}
                    if type(value) == "table" then
                        for key, selected in pairs(value) do
                            if type(key) == "number" then
                                normalized[selected] = true
                            elseif selected == true then
                                normalized[key] = true
                            end
                        end
                    end
                    return normalized
                end

                local CurrentValue = normalizeMulti(Default)
                if Library.Flags[Flag] ~= nil then CurrentValue = Library.Flags[Flag] end
                CurrentValue = normalizeMulti(CurrentValue)
                Library.Flags[Flag] = CurrentValue

                local headerHeight = IsMobile and 38 or 44
                local Expanded = false
                local listHeight = 0

                local changeListeners = {}

                local DropdownContainer = Utility:Create("Frame", {
                    Name = Name,
                    Parent = ContentContainer,
                    BackgroundColor3 = Library.Theme.Surface,
                    Size = UDim2.new(1, 0, 0, headerHeight),
                    ClipsDescendants = true,
                    ZIndex = 5,
                    BorderSizePixel = 0
                })
                Utility:RegisterProperty(DropdownContainer, "BackgroundColor3", "Surface")
                Utility:Create("UICorner", {CornerRadius = UDim.new(0, 6), Parent = DropdownContainer})
                local stroke = Utility:Create("UIStroke", {Parent = DropdownContainer, Color = Library.Theme.Stroke, Thickness = 1})
                Utility:RegisterProperty(stroke, "Color", "Stroke")

                -- Header clip frame to prevent button overflow
                local HeaderClip = Utility:Create("Frame", {
                    Parent = DropdownContainer,
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, headerHeight),
                    ClipsDescendants = true,
                    ZIndex = 5
                })

                local Header = Utility:Create("TextButton", {
                    Parent = HeaderClip,
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, headerHeight),
                    AutoButtonColor = false,
                    Text = "",
                    ZIndex = 6,
                    BorderSizePixel = 0
                })
                Utility:Create("TextLabel", {
                    Parent = Header,
                    BackgroundTransparency = 1,
                    Position = UDim2.new(0, 12, 0, IsMobile and 10 or 12),
                    Size = UDim2.new(0.5, 0, 0, 20),
                    Font = Enum.Font.Gotham,
                    Text = Name,
                    TextColor3 = Library.Theme.Text,
                    TextSize = IsMobile and 12 or 13,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    ZIndex = 7
                })
                local Status = Utility:Create("TextLabel", {
                    Parent = Header,
                    BackgroundTransparency = 1,
                    Position = UDim2.new(0.5, 0, 0, IsMobile and 10 or 12),
                    Size = UDim2.new(0.5, -30, 0, 20),
                    Font = Enum.Font.GothamBold,
                    Text = (Multi and "..." or tostring(CurrentValue)),
                    TextColor3 = Library.Theme.SubText,
                    TextSize = IsMobile and 12 or 13,
                    TextXAlignment = Enum.TextXAlignment.Right,
                    ZIndex = 7
                })
                local Arrow = Utility:Create("ImageLabel", {
                    Parent = Header,
                    BackgroundTransparency = 1,
                    Position = UDim2.new(1, -28, 0.5, -8),
                    Size = UDim2.fromOffset(16, 16),
                    Image = ICONS.ChevronDown,
                    ImageColor3 = Library.Theme.SubText,
                    ScaleType = Enum.ScaleType.Fit,
                    ZIndex = 7
                })
                Utility:RegisterProperty(Arrow, "ImageColor3", "SubText")

                -- List rendered outside HeaderClip so it can overflow
                local ListFrame = Utility:Create("ScrollingFrame", {
                    Parent = DropdownContainer,
                    BackgroundColor3 = Library.Theme.Surface,
                    Position = UDim2.new(0, 8, 0, headerHeight),
                    Size = UDim2.new(1, -16, 0, 0),
                    CanvasSize = UDim2.new(0, 0, 0, 0),
                    ScrollBarThickness = 2,
                    ScrollBarImageColor3 = Library.Theme.Accent,
                    ZIndex = 20,
                    BorderSizePixel = 0,
                    Visible = false
                })
                Utility:RegisterProperty(ListFrame, "BackgroundColor3", "Surface")
                Utility:RegisterMaterial(ListFrame, 0.24, 0)
                Utility:Create("UICorner", {CornerRadius = UDim.new(0, 6), Parent = ListFrame})
                local listStroke = Utility:Create("UIStroke", {Parent = ListFrame, Color = Library.Theme.Stroke, Thickness = 1})
                Utility:RegisterProperty(listStroke, "Color", "Stroke")

                local itemHeight = IsMobile and 30 or 26

                local function SetExpanded(open)
                    Expanded = open == true
                    if Expanded then ListFrame.Visible = true end
                    Utility:Tween(Arrow, TweenInfo.new(0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Rotation = Expanded and 180 or 0})
                    Utility:Tween(DropdownContainer, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                        Size = UDim2.new(1, 0, 0, Expanded and (headerHeight + listHeight + 8) or headerHeight)
                    }, function()
                        if not Expanded then ListFrame.Visible = false end
                    end)
                    if Library.ReducedMotion and not Expanded then ListFrame.Visible = false end
                end

                local function UpdateStatus()
                    if Multi then
                        local selected = {}
                        for _, optionValue in ipairs(Values) do
                            if CurrentValue[optionValue] then table.insert(selected, tostring(optionValue)) end
                        end
                        if #selected == 0 then
                            Status.Text = "None selected"
                        elseif #selected <= 2 then
                            Status.Text = table.concat(selected, ", ")
                        else
                            Status.Text = selected[1] .. ", " .. selected[2] .. " +" .. tostring(#selected - 2)
                        end
                    else
                        Status.Text = CurrentValue ~= nil and tostring(CurrentValue) or "No options"
                    end
                end

                local function Refresh()
                    UpdateStatus()
                    Library.Flags[Flag] = CurrentValue
                    Utility:SafeCall(Callback, CurrentValue)
                    for _, listener in ipairs(changeListeners) do
                        pcall(listener, CurrentValue)
                    end
                end

                local function BuildList()
                    ListFrame:ClearAllChildren()
                    Utility:Create("UICorner", {CornerRadius = UDim.new(0, 7), Parent = ListFrame})
                    local rebuiltStroke = Utility:Create("UIStroke", {Parent = ListFrame, Color = Library.Theme.Stroke, Thickness = 1})
                    Utility:RegisterProperty(rebuiltStroke, "Color", "Stroke")
                    Utility:Create("UIListLayout", {Parent = ListFrame, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4)})
                    Utility:Create("UIPadding", {Parent = ListFrame, PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), PaddingTop = UDim.new(0, 4)})
                    for _, val in pairs(Values) do
                        local Item = Utility:Create("TextButton", {
                            Parent = ListFrame,
                            BackgroundColor3 = Library.Theme.SurfaceAlt,
                            BackgroundTransparency = 1,
                            Size = UDim2.new(1, 0, 0, itemHeight),
                            AutoButtonColor = false,
                            Text = "",
                            ZIndex = 21,
                            BorderSizePixel = 0
                        })
                        Utility:RegisterProperty(Item, "BackgroundColor3", "SurfaceAlt")
                        Utility:Create("UICorner", {CornerRadius = UDim.new(0, 4), Parent = Item})
                        local IsSelected = Multi and CurrentValue[val] or (not Multi and CurrentValue == val)
                        local itemText = Utility:Create("TextLabel", {
                            Parent = Item, BackgroundTransparency = 1, Position = UDim2.fromOffset(9, 0),
                            Size = UDim2.new(1, -38, 1, 0), Text = tostring(val),
                            TextColor3 = IsSelected and Library.Theme.Text or Library.Theme.SubText,
                            Font = Enum.Font.Gotham, TextSize = IsMobile and 12 or 13,
                            TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 22
                        })
                        Utility:RegisterProperty(itemText, "TextColor3", IsSelected and "Text" or "SubText")
                        local checkIcon = Utility:Create("ImageLabel", {
                            Parent = Item, BackgroundTransparency = 1, Position = UDim2.new(1, -25, 0.5, -7),
                            Size = UDim2.fromOffset(14, 14), Image = ICONS.Check,
                            ImageColor3 = Library.Theme.Accent, ImageTransparency = IsSelected and 0 or 1,
                            ScaleType = Enum.ScaleType.Fit, ZIndex = 22
                        })
                        Utility:RegisterProperty(checkIcon, "ImageColor3", "Accent")
                        if IsSelected then
                            Item.BackgroundTransparency = 0.08
                        end
                        Library:Connect(Item.MouseButton1Click, function()
                            if Multi then
                                CurrentValue[val] = not CurrentValue[val]
                                BuildList()
                            else
                                CurrentValue = val
                                SetExpanded(false)
                                BuildList()
                            end
                            Refresh()
                        end)
                    end
                    listHeight = math.min(#Values * (itemHeight + 4) + 10, IsMobile and 132 or 156)
                    ListFrame.CanvasSize = UDim2.new(0, 0, 0, #Values * (itemHeight + 4) + 10)
                    ListFrame.Size = UDim2.new(1, -16, 0, listHeight)
                    if Expanded then DropdownContainer.Size = UDim2.new(1, 0, 0, headerHeight + listHeight + 8) end
                end

                Library:Connect(Header.MouseButton1Click, function()
                    SetExpanded(not Expanded)
                end)
                BuildList()
                UpdateStatus()
                addElement({Holder = DropdownContainer, Text = Name})

                local dropObj = {
                    Type = "Dropdown",
                    Set = function(self, val)
                        CurrentValue = normalizeMulti(val)
                        Refresh()
                        BuildList()
                    end,
                    Refresh = function(self, newVals, preserveSelection)
                        Values = type(newVals) == "table" and newVals or {}
                        if not Multi then
                            local stillExists = false
                            for _, optionValue in ipairs(Values) do
                                if optionValue == CurrentValue then stillExists = true break end
                            end
                            if not stillExists and preserveSelection ~= true then CurrentValue = Values[1] end
                        end
                        Refresh()
                        BuildList()
                    end,
                    Get = function() return CurrentValue end,
                    GetList = function()
                        local selected = {}
                        if Multi then
                            for _, value in ipairs(Values) do if CurrentValue[value] then table.insert(selected, value) end end
                        elseif CurrentValue ~= nil then
                            table.insert(selected, CurrentValue)
                        end
                        return selected
                    end,
                    Clear = function(self)
                        if Multi then CurrentValue = {} else CurrentValue = nil end
                        Refresh(); BuildList()
                    end,
                    SelectAll = function(self)
                        if Multi then
                            CurrentValue = {}
                            for _, value in ipairs(Values) do CurrentValue[value] = true end
                            Refresh(); BuildList()
                        end
                    end,
                    OnChanged = function(self, fn)
                        table.insert(changeListeners, fn)
                    end,
                    SetExpanded = function(self, open) SetExpanded(open) end
                }
                finishController(dropObj, DropdownContainer, Name, options.Tooltip)
                Library:RegisterOption(Flag, dropObj, Default)
                return dropObj
            end

            function Section:CreateMultiDropdown(options)
                options = options or {}
                options.Multi = true
                return self:CreateDropdown(options)
            end


--[[ MODULE: 87_content.part.lua ]]
-- Module fragment: labels, dependency boxes, warnings, images
-- Generated from the working V7 baseline; edit this feature in isolation.
            -- LABEL
            function Section:CreateLabel(Text)
                local Container = Utility:Create("Frame", {
                    Name = "Label",
                    Parent = ContentContainer,
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, 20),
                    ZIndex = 5,
                    BorderSizePixel = 0
                })
                local Lab = Utility:Create("TextLabel", {
                    Parent = Container,
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 1, 0),
                    Font = Enum.Font.Gotham,
                    Text = Text,
                    TextColor3 = Library.Theme.Text,
                    TextSize = IsMobile and 12 or 13,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextWrapped = true,
                    ZIndex = 6
                })
                Utility:RegisterProperty(Lab, "TextColor3", "Text")
                Library:Connect(Lab:GetPropertyChangedSignal("TextBounds"), function()
                    Container.Size = UDim2.new(1, 0, 0, Lab.TextBounds.Y + 4)
                end)
                addElement({Holder = Container, Text = Text})
                return finishController({
                    SetText = function(self, t)
                        Lab.Text = t
                    end
                }, Container, Text)
            end

            -- DEPENDENCY BOX
            function Section:CreateDependencyBox(dependencies)
                local depContainer = Utility:Create("Frame", {
                    Parent = ContentContainer,
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, 0),
                    ClipsDescendants = true,
                    Visible = false,
                    ZIndex = 5,
                    BorderSizePixel = 0
                })
                local layout = Utility:Create("UIListLayout", {
                    Parent = depContainer,
                    SortOrder = Enum.SortOrder.LayoutOrder,
                    Padding = UDim.new(0, IsMobile and 6 or 8)
                })

                local function updateVisibility()
                    local allMatch = true
                    for _, dep in ipairs(dependencies) do
                        local element, expected = dep[1], dep[2]
                        local val = element.Get and element.Get() or nil
                        if val == nil then
                            allMatch = false; break
                        end
                        if element.Type == "Toggle" then
                            if val ~= expected then allMatch = false; break end
                        elseif element.Type == "Dropdown" then
                            if type(val) == "table" then
                                if not val[expected] then allMatch = false; break end
                            elseif val ~= expected then
                                allMatch = false; break
                            end
                        end
                    end
                    depContainer.Visible = allMatch
                    -- Manually update canvas size
                    if allMatch then
                        depContainer.Size = UDim2.new(1, 0, 0, layout.AbsoluteContentSize.Y)
                    else
                        depContainer.Size = UDim2.new(1, 0, 0, 0)
                    end
                    RefreshLayout()
                end

                for _, dep in ipairs(dependencies) do
                    local element = dep[1]
                    if element.OnChanged then
                        element:OnChanged(updateVisibility)
                    end
                end
                updateVisibility()
                addElement({Holder = depContainer})
                return depContainer
            end

            -- WARNING BOX
            function Section:CreateWarningBox(options)
                options = options or {}
                local title = options.Title or "Warning"
                local text = options.Text or ""
                local color = options.Color or "Warn"
                local closable = options.Closable or false

                local bgColor = Library.Theme[color] or Library.Theme.Warn
                local container = Utility:Create("Frame", {
                    Parent = ContentContainer,
                    BackgroundColor3 = bgColor,
                    Size = UDim2.new(1, 0, 0, 40),
                    ClipsDescendants = false,
                    ZIndex = 5,
                    BorderSizePixel = 0
                })
                Utility:Create("UICorner", {CornerRadius = UDim.new(0, 6), Parent = container})

                local titleLabel = Utility:Create("TextLabel", {
                    Parent = container,
                    BackgroundTransparency = 1,
                    Position = UDim2.new(0, 10, 0, 8),
                    Size = UDim2.new(1, closable and -30 or -20, 0, 20),
                    Font = Enum.Font.GothamBold,
                    Text = title,
                    TextColor3 = Library.Theme.Text,
                    TextSize = 14,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    ZIndex = 6
                })

                local textLabel = Utility:Create("TextLabel", {
                    Parent = container,
                    BackgroundTransparency = 1,
                    Position = UDim2.new(0, 10, 0, 30),
                    Size = UDim2.new(1, -20, 0, 20),
                    Font = Enum.Font.Gotham,
                    Text = text,
                    TextColor3 = Library.Theme.SubText,
                    TextSize = 12,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextWrapped = true,
                    ZIndex = 6
                })

                Library:Connect(textLabel:GetPropertyChangedSignal("TextBounds"), function()
                    local textH = textLabel.TextBounds.Y + 4
                    textLabel.Size = UDim2.new(1, -20, 0, textH)
                    local totalHeight = 30 + textH + 10
                    container.Size = UDim2.new(1, 0, 0, totalHeight)
                    RefreshLayout()
                end)

                if closable then
                    local closeBtn = Utility:Create("TextButton", {
                        Parent = container,
                        BackgroundTransparency = 1,
                        Position = UDim2.new(1, -24, 0, 4),
                        Size = UDim2.new(0, 20, 0, 20),
                        Text = "✖",
                        TextColor3 = Library.Theme.Text,
                        Font = Enum.Font.Gotham,
                        TextSize = 14,
                        ZIndex = 7
                    })
                    Library:Connect(closeBtn.MouseButton1Click, function()
                        container:Destroy()
                        RefreshLayout()
                    end)
                end
                addElement({Holder = container})
                return container
            end

            -- IMAGE
            function Section:CreateImage(options)
                options = options or {}
                local image = options.Image or ""
                local width = options.Width or 200
                local height = options.Height or 200
                local scaleType = options.ScaleType or Enum.ScaleType.Fit

                local container = Utility:Create("Frame", {
                    Parent = ContentContainer,
                    BackgroundTransparency = 1,
                    Size = UDim2.new(0, width, 0, height),
                    ZIndex = 5,
                    BorderSizePixel = 0
                })
                local img = Utility:Create("ImageLabel", {
                    Parent = container,
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 1, 0),
                    Image = image,
                    ScaleType = scaleType,
                    ZIndex = 6
                })
                addElement({Holder = container})
                return finishController({
                    SetImage = function(self, newImage) img.Image = newImage end,
                    SetSize = function(self, w, h) container.Size = UDim2.new(0, w, 0, h) end
                }, container, "Image", options.Tooltip)
            end


--[[ MODULE: 88_keybind.part.lua ]]
-- Module fragment: keybind picker
-- Generated from the working V7 baseline; edit this feature in isolation.
            -- KEYBIND PICKER
            function Section:CreateKeyPicker(options)
                options = options or {}
                local name = options.Name or "Keybind"
                local defaultKey = options.Default or "None"
                if typeof(defaultKey) == "EnumItem" then defaultKey = defaultKey.Name else defaultKey = tostring(defaultKey) end
                local mode = options.Mode or "Toggle"
                local callback = options.Callback or function() end
                local flag = options.Flag or name

                local currentKey = Library.Flags[flag] or defaultKey
                if typeof(currentKey) == "EnumItem" then currentKey = currentKey.Name else currentKey = tostring(currentKey) end
                local toggled = false
                local listening = false
                local keyHeld = false
                local keybindEntry = {name = name, key = currentKey, default = defaultKey, mode = mode, callback = callback, flag = flag}
                table.insert(Library.KeybindList, keybindEntry)
                Library.KeybindDefaults[flag] = defaultKey

                local container = Utility:Create("Frame", {
                    Parent = ContentContainer,
                    BackgroundColor3 = Library.Theme.Surface,
                    Size = UDim2.new(1, 0, 0, IsMobile and 32 or 36),
                    ClipsDescendants = true,
                    ZIndex = 5,
                    BorderSizePixel = 0
                })
                Utility:Create("UICorner", {CornerRadius = UDim.new(0, 6), Parent = container})
                local stroke = Utility:Create("UIStroke", {Parent = container, Color = Library.Theme.Stroke, Thickness = 1})
                Utility:RegisterProperty(container, "BackgroundColor3", "Surface")
                Utility:RegisterProperty(stroke, "Color", "Stroke")

                local label = Utility:Create("TextLabel", {
                    Parent = container,
                    BackgroundTransparency = 1,
                    Position = UDim2.new(0, 12, 0.5, -10),
                    Size = UDim2.new(0.6, 0, 0, 20),
                    Font = Enum.Font.Gotham,
                    Text = name,
                    TextColor3 = Library.Theme.Text,
                    TextSize = IsMobile and 12 or 13,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    ZIndex = 6
                })
                Utility:RegisterProperty(label, "TextColor3", "Text")

                local keyBtn = Utility:Create("TextButton", {
                    Parent = container,
                    BackgroundColor3 = Library.Theme.Secondary,
                    Position = UDim2.new(0.7, 0, 0.5, -12),
                    Size = UDim2.new(0.25, 0, 0, 24),
                    Text = currentKey,
                    TextColor3 = Library.Theme.Text,
                    Font = Enum.Font.GothamBold,
                    TextSize = 12,
                    AutoButtonColor = false,
                    ZIndex = 6
                })
                Utility:Create("UICorner", {CornerRadius = UDim.new(0, 4), Parent = keyBtn})
                Utility:RegisterProperty(keyBtn, "BackgroundColor3", "Secondary")
                Utility:RegisterProperty(keyBtn, "TextColor3", "Text")

                local stateIndicator = Utility:Create("Frame", {
                    Parent = container,
                    BackgroundColor3 = Library.Theme.Accent,
                    Position = UDim2.new(0.96, 0, 0.5, -4),
                    Size = UDim2.new(0, 8, 0, 8),
                    Visible = false,
                    ZIndex = 7
                })
                Utility:Create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = stateIndicator})
                Utility:RegisterProperty(stateIndicator, "BackgroundColor3", "Accent")

                local listenBtn = Utility:Create("TextButton", {
                    Parent = container,
                    BackgroundTransparency = 1,
                    Position = UDim2.new(0.96, 0, 0, 0),
                    Size = UDim2.new(0, 20, 1, 0),
                    Text = "✎",
                    TextColor3 = Library.Theme.SubText,
                    Font = Enum.Font.Gotham,
                    TextSize = 14,
                    ZIndex = 7
                })
                Utility:RegisterProperty(listenBtn, "TextColor3", "SubText")

                Library:Connect(listenBtn.MouseButton1Click, function()
                    if listening then return end
                    listening = true
                    keyBtn.Text = "..."
                    local conn
                    conn = Library:Connect(UserInputService.InputBegan, function(input, gpe)
                        if gpe then return end
                        if input.UserInputType == Enum.UserInputType.Keyboard then
                            currentKey = input.KeyCode.Name
                            Library.Flags[flag] = currentKey
                            keyBtn.Text = currentKey
                            listening = false
                            conn:Disconnect()
                            keybindEntry.key = currentKey
                        end
                    end)
                end)

                if mode == "Hold" then
                    local holding = false
                    local holdConn
                    Library:Connect(keyBtn.InputBegan, function(input)
                        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                            if listening then return end
                            holding = true
                            stateIndicator.Visible = true
                            Utility:SafeCall(callback, currentKey, true)
                            holdConn = Library:Connect(RunService.Heartbeat, function()
                                if holding then
                                    Utility:SafeCall(callback, currentKey, true)
                                end
                            end)
                        end
                    end)
                    Library:Connect(keyBtn.InputEnded, function(input)
                        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                            if holding then
                                holding = false
                                stateIndicator.Visible = false
                                if holdConn then holdConn:Disconnect() end
                                Utility:SafeCall(callback, currentKey, false)
                            end
                        end
                    end)
                elseif mode == "Toggle" then
                    Library:Connect(keyBtn.MouseButton1Click, function()
                        if listening then return end
                        toggled = not toggled
                        stateIndicator.Visible = toggled
                        Utility:SafeCall(callback, currentKey, toggled)
                    end)
                end

                Library:Connect(UserInputService.InputBegan, function(input, processed)
                    if processed or listening or input.UserInputType ~= Enum.UserInputType.Keyboard then return end
                    if input.KeyCode.Name ~= currentKey then return end
                    if mode == "Hold" then
                        if keyHeld then return end
                        keyHeld = true
                        stateIndicator.Visible = true
                        Utility:SafeCall(callback, currentKey, true)
                    elseif mode == "Toggle" then
                        toggled = not toggled
                        stateIndicator.Visible = toggled
                        Utility:SafeCall(callback, currentKey, toggled)
                    else
                        Utility:SafeCall(callback, currentKey, true)
                    end
                end)
                Library:Connect(UserInputService.InputEnded, function(input)
                    if mode ~= "Hold" or input.UserInputType ~= Enum.UserInputType.Keyboard or input.KeyCode.Name ~= currentKey then return end
                    keyHeld = false
                    stateIndicator.Visible = false
                    Utility:SafeCall(callback, currentKey, false)
                end)

                addElement({Holder = container, Text = name})
                local controller = finishController({
                    Type = "KeyPicker",
                    Set = function(self, key)
                        currentKey = typeof(key) == "EnumItem" and key.Name or tostring(key)
                        keyBtn.Text = currentKey
                        Library.Flags[flag] = currentKey
                        keybindEntry.key = currentKey
                    end,
                    Get = function() return currentKey end,
                    GetKey = function() return currentKey end,
                    GetState = function() return toggled end
                }, container, name, options.Tooltip)
                Library.Flags[flag] = currentKey
                Library:RegisterOption(flag, controller, defaultKey)
                keybindEntry.controller = controller
                return controller
            end


--[[ MODULE: 89_colorpicker.part.lua ]]
-- Module fragment: color picker
-- Generated from the working V7 baseline; edit this feature in isolation.
            -- COLOR PICKER (touch-friendly HSV editor)
            function Section:CreateColorPicker(options)
                options = options or {}
                local name = options.Name or "Color"
                local defaultColor = options.Default or Color3.new(1,1,1)
                local callback = options.Callback or function() end
                local flag = options.Flag or name
                local currentColor = Library.Flags[flag] or defaultColor
                local hue, saturation, value = Color3.toHSV(currentColor)
                local expanded = false
                local listeners = {}
                local headerHeight = IsMobile and 40 or 38

                local container = Utility:Create("Frame", {
                    Parent = ContentContainer,
                    BackgroundColor3 = Library.Theme.Surface,
                    Size = UDim2.new(1, 0, 0, headerHeight),
                    ClipsDescendants = true,
                    ZIndex = 5,
                    BorderSizePixel = 0
                })
                Utility:Create("UICorner", {CornerRadius = UDim.new(0, 6), Parent = container})
                local stroke = Utility:Create("UIStroke", {Parent = container, Color = Library.Theme.Stroke, Thickness = 1})
                Utility:RegisterProperty(container, "BackgroundColor3", "Surface")
                Utility:RegisterProperty(stroke, "Color", "Stroke")

                local headerButton = Utility:Create("TextButton", {
                    Parent = container,
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, headerHeight),
                    Text = "",
                    AutoButtonColor = false,
                    ZIndex = 7
                })

                local label = Utility:Create("TextLabel", {
                    Parent = headerButton,
                    BackgroundTransparency = 1,
                    Position = UDim2.new(0, 12, 0, 0),
                    Size = UDim2.new(1, -92, 0, headerHeight),
                    Font = Enum.Font.Gotham,
                    Text = name,
                    TextColor3 = Library.Theme.Text,
                    TextSize = IsMobile and 12 or 13,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    ZIndex = 6
                })
                Utility:RegisterProperty(label, "TextColor3", "Text")

                local headerSwatch = Utility:Create("Frame", {
                    Parent = headerButton,
                    BackgroundColor3 = currentColor,
                    Position = UDim2.new(1, -58, 0.5, -10),
                    Size = UDim2.fromOffset(20, 20),
                    BorderSizePixel = 0,
                    ZIndex = 8
                })
                Utility:Create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = headerSwatch})
                local colorStroke = Utility:Create("UIStroke", {Parent = headerSwatch, Color = Library.Theme.Stroke, Thickness = 1})
                Utility:RegisterProperty(colorStroke, "Color", "Stroke")

                local headerArrow = Utility:Create("ImageLabel", {
                    Parent = headerButton,
                    BackgroundTransparency = 1,
                    Position = UDim2.new(1, -28, 0.5, -8),
                    Size = UDim2.fromOffset(16, 16),
                    Image = ICONS.ChevronDown,
                    ImageColor3 = Library.Theme.SubText,
                    ScaleType = Enum.ScaleType.Fit,
                    ZIndex = 8
                })
                Utility:RegisterProperty(headerArrow, "ImageColor3", "SubText")

                local editor = Utility:Create("Frame", {
                    Parent = container, BackgroundTransparency = 1,
                    Position = UDim2.new(0, 12, 0, headerHeight + 4),
                    Size = UDim2.new(1, -24, 0, 132), ZIndex = 6
                })

                local hueGradient = ColorSequence.new({
                    ColorSequenceKeypoint.new(0, Color3.fromHSV(0, 1, 1)),
                    ColorSequenceKeypoint.new(0.17, Color3.fromHSV(0.17, 1, 1)),
                    ColorSequenceKeypoint.new(0.33, Color3.fromHSV(0.33, 1, 1)),
                    ColorSequenceKeypoint.new(0.5, Color3.fromHSV(0.5, 1, 1)),
                    ColorSequenceKeypoint.new(0.67, Color3.fromHSV(0.67, 1, 1)),
                    ColorSequenceKeypoint.new(0.83, Color3.fromHSV(0.83, 1, 1)),
                    ColorSequenceKeypoint.new(1, Color3.fromHSV(1, 1, 1))
                })

                local function createColorTrack(title, y, gradient)
                    local trackLabel = Utility:Create("TextLabel", {
                        Parent = editor, BackgroundTransparency = 1, Position = UDim2.fromOffset(0, y),
                        Size = UDim2.fromOffset(18, 22), Text = title, TextColor3 = Library.Theme.SubText,
                        Font = Enum.Font.GothamBold, TextSize = 10, ZIndex = 7
                    })
                    Utility:RegisterProperty(trackLabel, "TextColor3", "SubText")
                    local track = Utility:Create("TextButton", {
                        Parent = editor, BackgroundColor3 = Color3.new(1, 1, 1),
                        Position = UDim2.new(0, 24, 0, y + 5), Size = UDim2.new(1, -24, 0, 12),
                        Text = "", AutoButtonColor = false, BorderSizePixel = 0, ZIndex = 7
                    })
                    Utility:Create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = track})
                    local uiGradient = Utility:Create("UIGradient", {Parent = track, Color = gradient})
                    local marker = Utility:Create("Frame", {
                        Parent = track, BackgroundColor3 = Color3.new(1, 1, 1),
                        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 0, 0.5, 0),
                        Size = UDim2.fromOffset(4, 18), BorderSizePixel = 0, ZIndex = 8
                    })
                    Utility:Create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = marker})
                    Utility:Create("UIStroke", {Parent = marker, Color = Color3.new(0, 0, 0), Transparency = 0.35, Thickness = 1})
                    return track, marker, uiGradient
                end

                local hueTrack, hueMarker = createColorTrack("H", 0, hueGradient)
                local satTrack, satMarker, satGradient = createColorTrack("S", 30, ColorSequence.new(Color3.new(1,1,1), Color3.fromHSV(hue,1,1)))
                local valTrack, valMarker, valGradient = createColorTrack("V", 60, ColorSequence.new(Color3.new(0,0,0), Color3.fromHSV(hue,saturation,1)))

                local colorDisplay = Utility:Create("TextButton", {
                    Parent = editor,
                    BackgroundColor3 = currentColor,
                    Position = UDim2.new(0, 24, 0, 94),
                    Size = UDim2.new(1, -24, 0, 30),
                    Text = "",
                    TextColor3 = Color3.new(1, 1, 1),
                    Font = Enum.Font.GothamBold,
                    TextSize = 11,
                    AutoButtonColor = false,
                    ZIndex = 7
                })
                Utility:Create("UICorner", {CornerRadius = UDim.new(0, 7), Parent = colorDisplay})
                local previewStroke = Utility:Create("UIStroke", {Parent = colorDisplay, Color = Library.Theme.Stroke, Thickness = 1})
                Utility:RegisterProperty(previewStroke, "Color", "Stroke")

                local function refreshColor(fire)
                    currentColor = Color3.fromHSV(hue, saturation, value)
                    Library.Flags[flag] = currentColor
                    headerSwatch.BackgroundColor3 = currentColor
                    colorDisplay.BackgroundColor3 = currentColor
                    colorDisplay.Text = string.format("#%02X%02X%02X", math.floor(currentColor.R * 255 + 0.5), math.floor(currentColor.G * 255 + 0.5), math.floor(currentColor.B * 255 + 0.5))
                    local luminance = currentColor.R * 0.299 + currentColor.G * 0.587 + currentColor.B * 0.114
                    colorDisplay.TextColor3 = luminance > 0.62 and Color3.fromRGB(18, 18, 24) or Color3.new(1, 1, 1)
                    hueMarker.Position = UDim2.new(hue, 0, 0.5, 0)
                    satMarker.Position = UDim2.new(saturation, 0, 0.5, 0)
                    valMarker.Position = UDim2.new(value, 0, 0.5, 0)
                    satGradient.Color = ColorSequence.new(Color3.new(1,1,1), Color3.fromHSV(hue,1,1))
                    valGradient.Color = ColorSequence.new(Color3.new(0,0,0), Color3.fromHSV(hue,saturation,1))
                    if fire ~= false then
                        Utility:SafeCall(callback, currentColor)
                        for _, listener in ipairs(listeners) do Utility:SafeCall(listener, currentColor) end
                    end
                end

                local function bindTrack(track, setter)
                    local dragging = false
                    local dragInput = nil
                    local function update(input)
                        setter(math.clamp((input.Position.X - track.AbsolutePosition.X) / math.max(1, track.AbsoluteSize.X), 0, 1))
                        refreshColor(true)
                    end
                    Library:Connect(track.InputBegan, function(input)
                        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                            dragging = true
                            dragInput = input.UserInputType == Enum.UserInputType.Touch and input or nil
                            update(input)
                        end
                    end)
                    Library:Connect(UserInputService.InputChanged, function(input)
                        local pointerMove = input.UserInputType == Enum.UserInputType.MouseMovement
                            or (input.UserInputType == Enum.UserInputType.Touch and input == dragInput)
                        if dragging and pointerMove then update(input) end
                    end)
                    Library:Connect(UserInputService.InputEnded, function(input)
                        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = false end
                    end)
                end
                bindTrack(hueTrack, function(x) hue = x end)
                bindTrack(satTrack, function(x) saturation = x end)
                bindTrack(valTrack, function(x) value = x end)

                local function setExpanded(open)
                    expanded = open == true
                    Utility:Tween(headerArrow, TweenInfo.new(0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Rotation = expanded and 180 or 0})
                    Utility:Tween(container, TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                        Size = UDim2.new(1, 0, 0, expanded and (headerHeight + 142) or headerHeight)
                    })
                    task.delay(Library.ReducedMotion and 0 or 0.23, RefreshLayout)
                end
                Library:Connect(headerButton.MouseButton1Click, function()
                    setExpanded(not expanded)
                end)
                Library:Connect(colorDisplay.MouseButton1Click, function()
                    if Capabilities:SetClipboard(colorDisplay.Text) then
                        Library:Notify({Title = "Color copied", Content = colorDisplay.Text, Duration = 2})
                    end
                end)
                refreshColor(false)
                addElement({Holder = container, Text = name})
                local controller = finishController({
                    Type = "ColorPicker",
                    Set = function(self, color) hue, saturation, value = Color3.toHSV(color); refreshColor(true) end,
                    SetColor = function(self, color) self:Set(color) end,
                    Get = function() return currentColor end,
                    OnChanged = function(self, fn) table.insert(listeners, fn) end,
                    SetExpanded = function(self, open) if expanded ~= (open == true) then setExpanded(open) end end
                }, container, name, options.Tooltip)
                Library:RegisterOption(flag, controller, defaultColor)
                return controller
            end

            function Section:CreateGroup(options)
                if type(options) == "string" then options = {Name = options} end
                options = options or {}
                local name = tostring(options.Name or "Group")
                local expanded = options.Expanded ~= false
                local headerHeight = IsMobile and 38 or 42
                local container = Utility:Create("Frame", {
                    Name = "Group_" .. name, Parent = ContentContainer, BackgroundColor3 = Library.Theme.Secondary,
                    Size = UDim2.new(1, 0, 0, headerHeight), ClipsDescendants = true,
                    BorderSizePixel = 0, ZIndex = 5
                })
                Utility:RegisterProperty(container, "BackgroundColor3", "Secondary")
                Utility:RegisterMaterial(container, 0.42, 0.08)
                Utility:Create("UICorner", {Parent = container, CornerRadius = UDim.new(0, 8)})
                local groupStroke = Utility:Create("UIStroke", {Parent = container, Color = Library.Theme.Divider, Thickness = 1})
                Utility:RegisterProperty(groupStroke, "Color", "Divider")
                local header = Utility:Create("TextButton", {
                    Parent = container, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, headerHeight),
                    Text = "", AutoButtonColor = false, ZIndex = 6
                })
                local title = Utility:Create("TextLabel", {
                    Parent = header, BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 0),
                    Size = UDim2.new(1, -48, 1, 0), Text = name, TextColor3 = Library.Theme.Text,
                    Font = Enum.Font.GothamBold, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 7
                })
                Utility:RegisterProperty(title, "TextColor3", "Text")
                local chevron = Utility:Create("ImageLabel", {
                    Parent = header, BackgroundTransparency = 1, Position = UDim2.new(1, -28, 0.5, -7),
                    Size = UDim2.fromOffset(14, 14), Image = ICONS.ChevronDown,
                    ImageColor3 = Library.Theme.SubText, Rotation = expanded and 0 or -90, ZIndex = 7
                })
                Utility:RegisterProperty(chevron, "ImageColor3", "SubText")
                local body = Utility:Create("Frame", {
                    Parent = container, BackgroundTransparency = 1, Position = UDim2.fromOffset(0, headerHeight),
                    Size = UDim2.new(1, 0, 0, 0), Visible = expanded, ZIndex = 6
                })
                Utility:Create("UIPadding", {
                    Parent = body, PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8),
                    PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 8)
                })
                local bodyLayout = Utility:Create("UIListLayout", {Parent = body, Padding = UDim.new(0, 7), SortOrder = Enum.SortOrder.LayoutOrder})
                local function refresh()
                    local bodyHeight = expanded and bodyLayout.AbsoluteContentSize.Y + 12 or 0
                    body.Visible = expanded
                    body.Size = UDim2.new(1, 0, 0, bodyHeight)
                    Utility:Tween(container, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                        Size = UDim2.new(1, 0, 0, headerHeight + bodyHeight)
                    })
                    Utility:Tween(chevron, TweenInfo.new(0.2), {Rotation = expanded and 0 or -90})
                    RefreshLayout()
                end
                Library:Connect(bodyLayout:GetPropertyChangedSignal("AbsoluteContentSize"), refresh)
                addElement({Holder = container, Text = name})
                local group = finishController({Type = "Group"}, container, name, options.Tooltip)
                function group:SetExpanded(value) expanded = value == true refresh() return self end
                function group:Toggle() return self:SetExpanded(not expanded) end
                function group:IsExpanded() return expanded end
                function group:SetTitle(value) name = tostring(value); title.Text = name; self.Name = name return self end
                local function attach(method, value)
                    local controller = Section[method](Section, value)
                    if controller and controller.Holder then
                        controller.Holder.Parent = body
                        for _, element in ipairs(Section.Elements) do
                            if element.Holder == controller.Holder then element.NestedParentHolder = container break end
                        end
                        Library:Connect(controller.Holder:GetPropertyChangedSignal("Size"), refresh)
                        task.defer(refresh)
                    end
                    return controller
                end
                function group:CreateButton(value) return attach("CreateButton", value) end
                function group:CreateToggle(value) return attach("CreateToggle", value) end
                function group:CreateSlider(value) return attach("CreateSlider", value) end
                function group:CreateDropdown(value) return attach("CreateDropdown", value) end
                function group:CreateMultiDropdown(value) return attach("CreateMultiDropdown", value) end
                function group:CreateInput(value) return attach("CreateInput", value) end
                function group:CreateParagraph(value) return attach("CreateParagraph", value) end
                function group:CreateMetric(value) return attach("CreateMetric", value) end
                function group:CreateKeyPicker(value) return attach("CreateKeyPicker", value) end
                function group:CreateColorPicker(value) return attach("CreateColorPicker", value) end
                function group:CreateImage(value) return attach("CreateImage", value) end
                function group:CreateLabel(value) return attach("CreateLabel", value) end
                function group:CreateDivider(value) return attach("CreateDivider", value) end
                function group:CreateGroup(value) return attach("CreateGroup", value) end
                function group:CreateList(value) return attach("CreateList", value) end
                function group:CreateTable(value) return attach("CreateTable", value) end
                function group:CreatePlayerList(value) return attach("CreatePlayerList", value) end
                function group:CreateLogConsole(value) return attach("CreateLogConsole", value) end
                function group:CreateSkeleton(value) return attach("CreateSkeleton", value) end
                function group:CreateCatalog(value) return attach("CreateCatalog", value) end
                function group:CreateBossCard(value) return attach("CreateBossCard", value) end
                function group:CreateIslandCard(value) return attach("CreateIslandCard", value) end
                function group:CreateESPPresets(value) return attach("CreateESPPresets", value) end
                function group:CreateESPControls(value) return attach("CreateESPControls", value) end
                function group:CreateWorkflowPresets(value) return attach("CreateWorkflowPresets", value) end
                function group:CreateStrategyProfiles(value) return attach("CreateStrategyProfiles", value) end
                function group:CreateProgressCard(value) return attach("CreateProgressCard", value) end
                function group:CreateActivityFeed(value) return attach("CreateActivityFeed", value) end
                function group:CreateChecklist(value) return attach("CreateChecklist", value) end
                function group:CreateStatusBanner(value) return attach("CreateStatusBanner", value) end
                function group:CreateActionBar(value) return attach("CreateActionBar", value) end
                function group:CreateStatGrid(value) return attach("CreateStatGrid", value) end
                function group:CreateLeaderboard(value) return attach("CreateLeaderboard", value) end
                function group:CreateExecutionQueue(value) return attach("CreateExecutionQueue", value) end
                Library:Connect(header.MouseButton1Click, function() group:Toggle() end)
                task.defer(refresh)
                return group
            end

            function Section:CreateList(options)
                options = options or {}
                local name = tostring(options.Name or "List")
                local items = type(options.Items) == "table" and options.Items or {}
                local selected = options.Default
                local container = Utility:Create("Frame", {
                    Parent = ContentContainer, BackgroundColor3 = Library.Theme.Surface,
                    Size = UDim2.new(1, 0, 0, tonumber(options.Height) or 176),
                    BorderSizePixel = 0, ClipsDescendants = true, ZIndex = 5
                })
                Utility:RegisterProperty(container, "BackgroundColor3", "Surface")
                Utility:Create("UICorner", {Parent = container, CornerRadius = UDim.new(0, 7)})
                local stroke = Utility:Create("UIStroke", {Parent = container, Color = Library.Theme.Stroke, Thickness = 1})
                Utility:RegisterProperty(stroke, "Color", "Stroke")
                local title = Utility:Create("TextLabel", {
                    Parent = container, BackgroundTransparency = 1, Position = UDim2.fromOffset(10, 5),
                    Size = UDim2.new(1, -20, 0, 24), Text = name, TextColor3 = Library.Theme.Text,
                    Font = Enum.Font.GothamBold, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 6
                })
                Utility:RegisterProperty(title, "TextColor3", "Text")
                local list = Utility:Create("ScrollingFrame", {
                    Parent = container, BackgroundTransparency = 1, Position = UDim2.fromOffset(7, 32),
                    Size = UDim2.new(1, -14, 1, -39), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
                    ScrollBarThickness = 2, ScrollBarImageColor3 = Library.Theme.Accent, BorderSizePixel = 0, ZIndex = 6
                })
                Utility:RegisterProperty(list, "ScrollBarImageColor3", "Accent")
                Utility:Create("UIListLayout", {Parent = list, Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder})
                local controller
                local function parts(item)
                    if type(item) == "table" then return tostring(item.Label or item.Name or item.Value or "Item"), item.Value ~= nil and item.Value or item, item.Description end
                    return tostring(item), item, nil
                end
                local function render()
                    for _, child in ipairs(list:GetChildren()) do if child:IsA("GuiObject") then child:Destroy() end end
                    for index, item in ipairs(items) do
                        local labelText, value, description = parts(item)
                        local row = Utility:Create("TextButton", {
                            Parent = list, BackgroundColor3 = Library.Theme.Secondary,
                            BackgroundTransparency = value == selected and 0 or 0.24,
                            Size = UDim2.new(1, -4, 0, description and 44 or 34), Text = "",
                            AutoButtonColor = false, BorderSizePixel = 0, LayoutOrder = index, ZIndex = 7
                        })
                        Utility:RegisterProperty(row, "BackgroundColor3", value == selected and "Accent" or "Secondary")
                        Utility:Create("UICorner", {Parent = row, CornerRadius = UDim.new(0, 5)})
                        local label = Utility:Create("TextLabel", {
                            Parent = row, BackgroundTransparency = 1, Position = UDim2.fromOffset(9, description and 4 or 0),
                            Size = UDim2.new(1, -18, 0, description and 20 or 34), Text = labelText,
                            TextColor3 = Library.Theme.Text, Font = Enum.Font.Gotham, TextSize = 12,
                            TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 8
                        })
                        Utility:RegisterProperty(label, "TextColor3", "Text")
                        if description then
                            local detail = Utility:Create("TextLabel", {
                                Parent = row, BackgroundTransparency = 1, Position = UDim2.fromOffset(9, 22),
                                Size = UDim2.new(1, -18, 0, 16), Text = tostring(description), TextColor3 = Library.Theme.SubText,
                                Font = Enum.Font.Gotham, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 8
                            })
                            Utility:RegisterProperty(detail, "TextColor3", "SubText")
                        end
                        Library:Connect(row.MouseButton1Click, function()
                            selected = value
                            render()
                            Utility:SafeCall(options.Callback, value, item, index)
                        end)
                    end
                end
                addElement({Holder = container, Text = name})
                controller = finishController({Type = "List"}, container, name, options.Tooltip)
                function controller:SetItems(nextItems) items = type(nextItems) == "table" and nextItems or {} render() return self end
                function controller:GetItems() return items end
                function controller:Add(item) table.insert(items, item) render() return self end
                function controller:Remove(value)
                    for index, item in ipairs(items) do local _, itemValue = parts(item) if itemValue == value then table.remove(items, index) break end end
                    if selected == value then selected = nil end render() return self
                end
                function controller:Clear() table.clear(items) selected = nil render() return self end
                function controller:Select(value) selected = value render() return self end
                function controller:GetSelected() return selected end
                render()
                return controller
            end

            function Section:CreateTable(options)
                options = options or {}
                local name = tostring(options.Name or "Table")
                local columns = type(options.Columns) == "table" and options.Columns or {{Key = "value", Name = "Value"}}
                local rows = type(options.Rows) == "table" and options.Rows or {}
                local container = Utility:Create("Frame", {
                    Parent = ContentContainer, BackgroundColor3 = Library.Theme.Surface,
                    Size = UDim2.new(1, 0, 0, tonumber(options.Height) or 196), BorderSizePixel = 0, ClipsDescendants = true, ZIndex = 5
                })
                Utility:RegisterProperty(container, "BackgroundColor3", "Surface")
                Utility:Create("UICorner", {Parent = container, CornerRadius = UDim.new(0, 7)})
                local title = Utility:Create("TextLabel", {
                    Parent = container, BackgroundTransparency = 1, Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -20, 0, 24),
                    Text = name, TextColor3 = Library.Theme.Text, Font = Enum.Font.GothamBold, TextSize = 12,
                    TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 6
                })
                Utility:RegisterProperty(title, "TextColor3", "Text")
                local header = Utility:Create("Frame", {Parent = container, BackgroundColor3 = Library.Theme.Secondary, Position = UDim2.fromOffset(7, 30), Size = UDim2.new(1, -14, 0, 28), BorderSizePixel = 0, ZIndex = 6})
                Utility:RegisterProperty(header, "BackgroundColor3", "Secondary")
                Utility:Create("UICorner", {Parent = header, CornerRadius = UDim.new(0, 5)})
                local list = Utility:Create("ScrollingFrame", {
                    Parent = container, BackgroundTransparency = 1, Position = UDim2.fromOffset(7, 63), Size = UDim2.new(1, -14, 1, -70),
                    CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 2,
                    ScrollBarImageColor3 = Library.Theme.Accent, BorderSizePixel = 0, ZIndex = 6
                })
                Utility:RegisterProperty(list, "ScrollBarImageColor3", "Accent")
                Utility:Create("UIListLayout", {Parent = list, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder})
                local function cell(parent, text, index, count, bold)
                    local label = Utility:Create("TextLabel", {
                        Parent = parent, BackgroundTransparency = 1, Position = UDim2.new((index - 1) / count, 7, 0, 0),
                        Size = UDim2.new(1 / count, -12, 1, 0), Text = tostring(text or ""), TextColor3 = bold and Library.Theme.Text or Library.Theme.SubText,
                        Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham, TextSize = bold and 10 or 11,
                        TextTruncate = Enum.TextTruncate.AtEnd, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = parent.ZIndex + 1
                    })
                    Utility:RegisterProperty(label, "TextColor3", bold and "Text" or "SubText")
                end
                local function render()
                    for _, child in ipairs(header:GetChildren()) do if child:IsA("TextLabel") then child:Destroy() end end
                    for index, column in ipairs(columns) do cell(header, column.Name or column.Label or column.Key or index, index, #columns, true) end
                    for _, child in ipairs(list:GetChildren()) do if child:IsA("GuiObject") then child:Destroy() end end
                    for rowIndex, rowData in ipairs(rows) do
                        local row = Utility:Create("Frame", {Parent = list, BackgroundColor3 = Library.Theme.Secondary, BackgroundTransparency = 0.3, Size = UDim2.new(1, -4, 0, 30), BorderSizePixel = 0, LayoutOrder = rowIndex, ZIndex = 7})
                        Utility:RegisterProperty(row, "BackgroundColor3", "Secondary")
                        Utility:Create("UICorner", {Parent = row, CornerRadius = UDim.new(0, 4)})
                        for columnIndex, column in ipairs(columns) do
                            local key = column.Key or column.Field or columnIndex
                            cell(row, type(rowData) == "table" and rowData[key] or rowData, columnIndex, #columns, false)
                        end
                    end
                end
                addElement({Holder = container, Text = name})
                local controller = finishController({Type = "Table"}, container, name, options.Tooltip)
                function controller:SetRows(nextRows) rows = type(nextRows) == "table" and nextRows or {} render() return self end
                function controller:SetColumns(nextColumns) columns = type(nextColumns) == "table" and nextColumns or columns render() return self end
                function controller:AddRow(row) table.insert(rows, row) render() return self end
                function controller:Clear() table.clear(rows) render() return self end
                function controller:GetRows() return rows end
                render()
                return controller
            end

            function Section:CreatePlayerList(options)
                options = options or {}
                local listOptions = {}
                for key, value in pairs(options) do listOptions[key] = value end
                listOptions.Name = options.Name or "Players"
                local userCallback = options.Callback
                listOptions.Callback = function(player) Utility:SafeCall(userCallback, player) end
                local controller = self:CreateList(listOptions)
                controller.Type = "PlayerList"
                local function refreshPlayers()
                    local values = {}
                    for _, player in ipairs(Players:GetPlayers()) do
                        table.insert(values, {Label = player.DisplayName, Description = "@" .. player.Name, Value = player})
                    end
                    table.sort(values, function(a, b) return a.Label:lower() < b.Label:lower() end)
                    controller:SetItems(values)
                end
                Library:Connect(Players.PlayerAdded, function() task.defer(refreshPlayers) end)
                Library:Connect(Players.PlayerRemoving, function() task.defer(refreshPlayers) end)
                refreshPlayers()
                return controller
            end

            function Section:CreateLogConsole(options)
                options = options or {}
                local name = tostring(options.Name or "Console")
                local maxLines = math.max(10, tonumber(options.MaxLines) or 150)
                local entries = {}
                local container = Utility:Create("Frame", {
                    Parent = ContentContainer, BackgroundColor3 = Library.Theme.Main,
                    Size = UDim2.new(1, 0, 0, tonumber(options.Height) or 190), BorderSizePixel = 0, ClipsDescendants = true, ZIndex = 5
                })
                Utility:RegisterProperty(container, "BackgroundColor3", "Main")
                Utility:Create("UICorner", {Parent = container, CornerRadius = UDim.new(0, 7)})
                local title = Utility:Create("TextLabel", {Parent = container, BackgroundTransparency = 1, Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -78, 0, 24), Text = name, TextColor3 = Library.Theme.Text, Font = Enum.Font.Code, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 6})
                Utility:RegisterProperty(title, "TextColor3", "Text")
                local clearButton = Utility:Create("TextButton", {Parent = container, BackgroundTransparency = 1, Position = UDim2.new(1, -64, 0, 4), Size = UDim2.fromOffset(54, 24), Text = "Clear", TextColor3 = Library.Theme.SubText, Font = Enum.Font.GothamBold, TextSize = 10, AutoButtonColor = false, ZIndex = 7})
                Utility:RegisterProperty(clearButton, "TextColor3", "SubText")
                local output = Utility:Create("ScrollingFrame", {Parent = container, BackgroundColor3 = Library.Theme.Secondary, BackgroundTransparency = 0.25, Position = UDim2.fromOffset(7, 31), Size = UDim2.new(1, -14, 1, -38), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 2, ScrollBarImageColor3 = Library.Theme.Accent, BorderSizePixel = 0, ZIndex = 6})
                Utility:RegisterProperty(output, "BackgroundColor3", "Secondary")
                Utility:RegisterProperty(output, "ScrollBarImageColor3", "Accent")
                Utility:Create("UIPadding", {Parent = output, PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6)})
                Utility:Create("UIListLayout", {Parent = output, Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder})
                local function render()
                    for _, child in ipairs(output:GetChildren()) do if child:IsA("TextLabel") then child:Destroy() end end
                    for index, entry in ipairs(entries) do
                        local semantic = entry.Level == "Error" and "Error" or entry.Level == "Warn" and "Warn" or entry.Level == "Success" and "Success" or "SubText"
                        local line = Utility:Create("TextLabel", {Parent = output, BackgroundTransparency = 1, Size = UDim2.new(1, -4, 0, 16), AutomaticSize = Enum.AutomaticSize.Y, Text = "[" .. entry.Level .. "] " .. entry.Text, TextColor3 = Library.Theme[semantic], Font = Enum.Font.Code, TextSize = 11, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, LayoutOrder = index, ZIndex = 7})
                        Utility:RegisterProperty(line, "TextColor3", semantic)
                    end
                    task.defer(function() output.CanvasPosition = Vector2.new(0, math.max(0, output.AbsoluteCanvasSize.Y)) end)
                end
                addElement({Holder = container, Text = name})
                local controller = finishController({Type = "LogConsole"}, container, name, options.Tooltip)
                function controller:Write(text, level)
                    table.insert(entries, {Text = tostring(text), Level = tostring(level or "Info")})
                    while #entries > maxLines do table.remove(entries, 1) end
                    render() return self
                end
                function controller:Log(text) return self:Write(text, "Info") end
                function controller:Warn(text) return self:Write(text, "Warn") end
                function controller:Error(text) return self:Write(text, "Error") end
                function controller:Success(text) return self:Write(text, "Success") end
                function controller:Clear() table.clear(entries) render() return self end
                function controller:GetEntries() return entries end
                Library:Connect(clearButton.MouseButton1Click, function() controller:Clear() end)
                for _, entry in ipairs(options.Entries or {}) do controller:Write(entry.Text or entry[1] or entry, entry.Level or entry[2]) end
                return controller
            end

            function Section:CreateSkeleton(options)
                options = options or {}
                local lineCount = math.clamp(tonumber(options.Lines) or 3, 1, 8)
                local container = Utility:Create("Frame", {Parent = ContentContainer, BackgroundColor3 = Library.Theme.Surface, Size = UDim2.new(1, 0, 0, 22 + lineCount * 18), BorderSizePixel = 0, ZIndex = 5})
                Utility:RegisterProperty(container, "BackgroundColor3", "Surface")
                Utility:Create("UICorner", {Parent = container, CornerRadius = UDim.new(0, 7)})
                local bars = {}
                for index = 1, lineCount do
                    local bar = Utility:Create("Frame", {Parent = container, BackgroundColor3 = Library.Theme.Hover, BackgroundTransparency = 0.15, Position = UDim2.new(0, 10, 0, 10 + (index - 1) * 18), Size = UDim2.new(index == lineCount and 0.62 or 1, index == lineCount and -10 or -20, 0, 10), BorderSizePixel = 0, ZIndex = 6})
                    Utility:RegisterProperty(bar, "BackgroundColor3", "Hover")
                    Utility:Create("UICorner", {Parent = bar, CornerRadius = UDim.new(1, 0)})
                    table.insert(bars, bar)
                end
                addElement({Holder = container, Text = tostring(options.Name or "Loading placeholder")})
                local controller = finishController({Type = "Skeleton"}, container, options.Name or "Skeleton")
                local animationToken = 1
                task.spawn(function()
                    local bright = false
                    while animationToken == 1 and container.Parent and not Library.Unloaded do
                        bright = not bright
                        for _, bar in ipairs(bars) do Utility:Tween(bar, TweenInfo.new(0.55), {BackgroundTransparency = bright and 0.48 or 0.15}) end
                        task.wait(0.62)
                    end
                end)
                local destroy = controller.Destroy
                function controller:Destroy() animationToken = 0 destroy(self) end
                return controller
            end

            -- Search-first action catalog with ownership/cost/requirement badges,
            -- favorites, recent actions, and command-palette registration.
            function Section:CreateCatalog(options)
                options = options or {}
                local name = tostring(options.Name or "Item catalog")
                local items = type(options.Items) == "table" and options.Items or {}
                local query, filter = "", tostring(options.DefaultFilter or "All")
                local itemById = {}
                local height = tonumber(options.Height) or (Library.DeviceMode == "Phone" and 292 or 340)
                local container = Utility:Create("Frame", {
                    Name = "Catalog_" .. name, Parent = ContentContainer,
                    BackgroundColor3 = Library.Theme.Secondary, Size = UDim2.new(1, 0, 0, height),
                    ClipsDescendants = true, BorderSizePixel = 0, ZIndex = 5
                })
                Utility:RegisterProperty(container, "BackgroundColor3", "Secondary")
                Utility:RegisterMaterial(container, 0.34, 0.04)
                Utility:Create("UICorner", {Parent = container, CornerRadius = UDim.new(0, 9)})
                local catalogStroke = Utility:Create("UIStroke", {Parent = container, Color = Library.Theme.Divider, Thickness = 1})
                Utility:RegisterProperty(catalogStroke, "Color", "Divider")
                local search = Utility:Create("TextBox", {
                    Name = "CatalogSearch", Parent = container, BackgroundColor3 = Library.Theme.Surface,
                    Position = UDim2.fromOffset(8, 8), Size = UDim2.new(1, -16, 0, Library.DeviceMode == "Phone" and 34 or 38),
                    ClearTextOnFocus = false, PlaceholderText = tostring(options.Placeholder or "Search items, requirements, or aliases…"),
                    Text = "", TextColor3 = Library.Theme.Text, PlaceholderColor3 = Library.Theme.SubText,
                    Font = Enum.Font.Gotham, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left,
                    BorderSizePixel = 0, ZIndex = 7
                })
                Utility:RegisterProperty(search, "BackgroundColor3", "Surface")
                Utility:RegisterProperty(search, "TextColor3", "Text")
                Utility:RegisterProperty(search, "PlaceholderColor3", "SubText")
                Utility:Create("UICorner", {Parent = search, CornerRadius = UDim.new(0, 7)})
                Utility:Create("UIPadding", {Parent = search, PaddingLeft = UDim.new(0, 11), PaddingRight = UDim.new(0, 11)})
                local filterBar = Utility:Create("Frame", {
                    Parent = container, BackgroundTransparency = 1,
                    Position = UDim2.fromOffset(8, Library.DeviceMode == "Phone" and 48 or 52),
                    Size = UDim2.new(1, -16, 0, 26), ZIndex = 7
                })
                local filterLayout = Utility:Create("UIListLayout", {
                    Parent = filterBar, FillDirection = Enum.FillDirection.Horizontal,
                    Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder
                })
                local filterButtons = {}
                local resultsTop = Library.DeviceMode == "Phone" and 80 or 84
                local results = Utility:Create("ScrollingFrame", {
                    Name = "CatalogResults", Parent = container, BackgroundTransparency = 1,
                    Position = UDim2.fromOffset(8, resultsTop), Size = UDim2.new(1, -16, 1, -(resultsTop + 8)),
                    CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
                    ScrollBarThickness = 2, ScrollBarImageColor3 = Library.Theme.Accent,
                    BorderSizePixel = 0, ZIndex = 6
                })
                Utility:RegisterProperty(results, "ScrollBarImageColor3", "Accent")
                Utility:Create("UIListLayout", {Parent = results, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 7)})
                local empty = Utility:Create("TextLabel", {
                    Name = "CatalogEmpty", Parent = results, BackgroundTransparency = 1,
                    Size = UDim2.new(1, -4, 0, 64), Text = "No catalog items match this view",
                    TextColor3 = Library.Theme.SubText, Font = Enum.Font.Gotham,
                    TextSize = 11, Visible = false, ZIndex = 7
                })
                Utility:RegisterProperty(empty, "TextColor3", "SubText")

                local controller
                local catalogId = normalizeActionId(options.Id or name)
                local function itemId(item, index)
                    return catalogId .. "-" .. normalizeActionId(item.Id or item.Name or tostring(index))
                end
                local function itemTerms(item)
                    local aliases = item.Synonyms or item.Aliases or item.Tags or {}
                    if type(aliases) == "table" then aliases = table.concat(aliases, " ") end
                    local requirement = type(item.Requirement) == "function" and "dynamic requirement" or item.Requirement
                    return table.concat({
                        tostring(item.Name or ""), tostring(item.Description or ""),
                        tostring(item.Category or ""), tostring(item.Cost or ""),
                        tostring(requirement or ""), tostring(aliases or "")
                    }, " "):lower()
                end
                local function resolveOwned(item)
                    if type(item.Owned) == "function" then
                        local ok, value = pcall(item.Owned, item)
                        return ok and value == true
                    end
                    return item.Owned == true
                end
                local function requirementState(item)
                    if type(item.Requirement) == "function" then
                        local ok, allowed, reason = pcall(item.Requirement, item)
                        if not ok then return false, "Requirement error" end
                        return allowed ~= false, tostring(reason or (allowed == false and "Locked" or "Ready"))
                    end
                    if item.Requirement == false then return false, "Locked" end
                    return true, type(item.Requirement) == "string" and item.Requirement or ""
                end
                local function orderedItems()
                    local ordered = {}
                    if filter == "Recent" then
                        for _, recentId in ipairs(Window.RecentActions) do
                            if itemById[recentId] then table.insert(ordered, itemById[recentId]) end
                        end
                    else
                        for _, item in ipairs(items) do
                            local id = item._RenCatalogId
                            local include = filter == "All"
                                or (filter == "Favorites" and Window.Favorites[id])
                                or (filter == "Owned" and resolveOwned(item))
                            if include then table.insert(ordered, item) end
                        end
                    end
                    return ordered
                end
                local function refreshFilterVisuals()
                    for label, button in pairs(filterButtons) do
                        button.BackgroundTransparency = label == filter and 0.18 or 0.62
                    end
                end
                local function render()
                    for _, child in ipairs(results:GetChildren()) do if child.Name == "CatalogItem" then child:Destroy() end end
                    local shown = 0
                    for _, item in ipairs(orderedItems()) do
                        if query == "" or itemTerms(item):find(query, 1, true) then
                            shown = shown + 1
                            local id = item._RenCatalogId
                            local allowed, requirementText = requirementState(item)
                            local rowHeight = item.Description and tostring(item.Description) ~= "" and 82 or 64
                            local card = Utility:Create("TextButton", {
                                Name = "CatalogItem", Parent = results, BackgroundColor3 = Library.Theme.Surface,
                                Size = UDim2.new(1, -4, 0, rowHeight), Text = "", AutoButtonColor = false,
                                LayoutOrder = shown, BorderSizePixel = 0, ZIndex = 7
                            })
                            card:SetAttribute("CatalogId", id)
                            Utility:RegisterProperty(card, "BackgroundColor3", "Surface")
                            Utility:Create("UICorner", {Parent = card, CornerRadius = UDim.new(0, 7)})
                            local cardStroke = Utility:Create("UIStroke", {Parent = card, Color = allowed and Library.Theme.Divider or Library.Theme.Error, Thickness = 1, Transparency = 0.18})
                            Utility:RegisterProperty(cardStroke, "Color", allowed and "Divider" or "Error")
                            local title = Utility:Create("TextLabel", {
                                Parent = card, BackgroundTransparency = 1, Position = UDim2.fromOffset(11, 6),
                                Size = UDim2.new(1, -54, 0, 19), Text = tostring(item.Name or id),
                                TextColor3 = Library.Theme.Text, Font = Enum.Font.GothamBold,
                                TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 8
                            })
                            Utility:RegisterProperty(title, "TextColor3", "Text")
                            if item.Description and tostring(item.Description) ~= "" then
                                local description = Utility:Create("TextLabel", {
                                    Parent = card, BackgroundTransparency = 1, Position = UDim2.fromOffset(11, 25),
                                    Size = UDim2.new(1, -54, 0, 18), Text = tostring(item.Description),
                                    TextColor3 = Library.Theme.SubText, Font = Enum.Font.Gotham, TextSize = 9,
                                    TextTruncate = Enum.TextTruncate.AtEnd, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 8
                                })
                                Utility:RegisterProperty(description, "TextColor3", "SubText")
                            end
                            local badges = Utility:Create("Frame", {
                                Parent = card, BackgroundTransparency = 1, Position = UDim2.fromOffset(10, rowHeight - 25),
                                Size = UDim2.new(1, -54, 0, 18), ZIndex = 8
                            })
                            Utility:Create("UIListLayout", {Parent = badges, FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder})
                            createBadge(badges, resolveOwned(item) and "OWNED" or (item.Owned ~= nil and "NOT OWNED" or ""), resolveOwned(item) and "Success" or "SubText", 1)
                            createBadge(badges, item.Cost and ("COST  " .. tostring(item.Cost)) or "", "Warn", 2)
                            createBadge(badges, requirementText, allowed and "Accent2" or "Error", 3)
                            local star = Utility:Create("TextButton", {
                                Parent = card, BackgroundTransparency = 1, Position = UDim2.new(1, -42, 0, 0),
                                Size = UDim2.fromOffset(42, 42), Text = Window.Favorites[id] and "★" or "☆",
                                TextColor3 = Library.Theme.Warn, Font = Enum.Font.GothamBold, TextSize = 17, ZIndex = 10
                            })
                            Utility:RegisterProperty(star, "TextColor3", "Warn")
                            Library:Connect(star.MouseButton1Click, function()
                                Window:ToggleFavorite(id)
                                render()
                            end)
                            Library:Connect(card.MouseButton1Click, function()
                                local ok, err = Window:ExecuteCommand(id)
                                if not ok then Library:Notify({Title = "Action unavailable", Content = tostring(err), Duration = 3}) end
                                render()
                            end)
                            Library:Connect(card.MouseEnter, function() Utility:Tween(card, TweenInfo.new(0.12), {BackgroundColor3 = Library.Theme.Hover}) end)
                            Library:Connect(card.MouseLeave, function() Utility:Tween(card, TweenInfo.new(0.12), {BackgroundColor3 = Library.Theme.Surface}) end)
                        end
                    end
                    empty.Visible = shown == 0
                    refreshFilterVisuals()
                    return shown
                end
                for order, label in ipairs({"All", "Owned", "Favorites", "Recent"}) do
                    local button = Utility:Create("TextButton", {
                        Parent = filterBar, BackgroundColor3 = Library.Theme.Accent,
                        BackgroundTransparency = label == filter and 0.18 or 0.62,
                        Size = UDim2.fromOffset(label == "Favorites" and 72 or 54, 24), Text = label,
                        TextColor3 = Library.Theme.Text, Font = Enum.Font.GothamBold, TextSize = 9,
                        AutoButtonColor = false, LayoutOrder = order, BorderSizePixel = 0, ZIndex = 8
                    })
                    Utility:RegisterProperty(button, "BackgroundColor3", "Accent")
                    Utility:RegisterProperty(button, "TextColor3", "Text")
                    Utility:Create("UICorner", {Parent = button, CornerRadius = UDim.new(1, 0)})
                    filterButtons[label] = button
                    Library:Connect(button.MouseButton1Click, function() filter = label render() end)
                end
                local function indexItems()
                    table.clear(itemById)
                    for index, item in ipairs(items) do
                        item._RenCatalogId = itemId(item, index)
                        itemById[item._RenCatalogId] = item
                        Window:RegisterCommand({
                            Id = item._RenCatalogId, Name = item.Name, Description = item.Description,
                            Category = item.Category or name, Synonyms = item.Synonyms or item.Aliases or item.Tags,
                            Icon = item.Icon, Requirement = item.Requirement,
                            Callback = function() Utility:SafeCall(item.Callback or options.Callback, item, controller) end,
                            Data = item
                        })
                    end
                end
                controller = finishController({Type = "Catalog"}, container, name, options.Tooltip)
                function controller:SetItems(nextItems) items = type(nextItems) == "table" and nextItems or {} indexItems() render() return self end
                function controller:GetItems() return items end
                function controller:SetQuery(value) query = tostring(value or ""):lower(); search.Text = tostring(value or ""); render(); return self end
                function controller:SetFilter(value) filter = tostring(value or "All"); render(); return self end
                function controller:Refresh() render() return self end
                function controller:Activate(id) return Window:ExecuteCommand(id) end
                function controller:SetOwned(id, owned)
                    local key = tostring(id or "")
                    local item = itemById[key] or itemById[catalogId .. "-" .. normalizeActionId(key)]
                    if item then item.Owned = owned == true; render(); return true end
                    return false
                end
                function controller:ToggleFavorite(id) Window:ToggleFavorite(id); render(); return self end
                function controller:GetFavorites()
                    local favorites = {}
                    for _, item in ipairs(items) do if Window.Favorites[item._RenCatalogId] then table.insert(favorites, item) end end
                    return favorites
                end
                function controller:GetRecent()
                    local recent = {}
                    for _, id in ipairs(Window.RecentActions) do if itemById[id] then table.insert(recent, itemById[id]) end end
                    return recent
                end
                Library:Connect(search:GetPropertyChangedSignal("Text"), function() query = search.Text:lower(); render() end)
                indexItems()
                local allTerms = {}
                for _, item in ipairs(items) do table.insert(allTerms, itemTerms(item)) end
                addElement({Holder = container, Text = name .. " " .. table.concat(allTerms, " "), Synonyms = options.Synonyms})
                render()
                return controller
            end

            function Section:CreateBossCard(options)
                options = options or {}
                local context = {}
                for key, value in pairs(options) do context[key] = value end
                local height = Library.DeviceMode == "Phone" and 112 or 104
                local card = Utility:Create("Frame", {
                    Name = "BossCard_" .. tostring(context.Name or "Boss"), Parent = ContentContainer,
                    BackgroundColor3 = Library.Theme.Surface, Size = UDim2.new(1, 0, 0, height),
                    BorderSizePixel = 0, ZIndex = 5
                })
                Utility:RegisterProperty(card, "BackgroundColor3", "Surface")
                Utility:RegisterMaterial(card, 0.3, 0)
                Utility:Create("UICorner", {Parent = card, CornerRadius = UDim.new(0, 7)})
                local accent = Utility:Create("Frame", {Parent = card, BackgroundColor3 = Library.Theme.Error, Size = UDim2.new(0, 3, 1, 0), BorderSizePixel = 0, ZIndex = 6})
                Utility:RegisterProperty(accent, "BackgroundColor3", "Error")
                local dot = Utility:Create("Frame", {Parent = card, BackgroundColor3 = Library.Theme.Warn, Position = UDim2.fromOffset(12, 12), Size = UDim2.fromOffset(7, 7), BorderSizePixel = 0, ZIndex = 7})
                Utility:RegisterProperty(dot, "BackgroundColor3", "Warn")
                Utility:Create("UICorner", {Parent = dot, CornerRadius = UDim.new(1, 0)})
                local title = Utility:Create("TextLabel", {Parent = card, BackgroundTransparency = 1, Position = UDim2.fromOffset(25, 4), Size = UDim2.new(1, -36, 0, 21), Text = "Boss", TextColor3 = Library.Theme.Text, Font = Enum.Font.GothamBold, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 7})
                Utility:RegisterProperty(title, "TextColor3", "Text")
                local subtitle = Utility:Create("TextLabel", {Parent = card, BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 24), Size = UDim2.new(1, -24, 0, 16), Text = "", TextColor3 = Library.Theme.SubText, Font = Enum.Font.Gotham, TextSize = 9, TextTruncate = Enum.TextTruncate.AtEnd, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 7})
                Utility:RegisterProperty(subtitle, "TextColor3", "SubText")
                local badges = Utility:Create("Frame", {Parent = card, BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 43), Size = UDim2.new(1, -24, 0, 18), ZIndex = 7})
                Utility:Create("UIListLayout", {Parent = badges, FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder})
                local primary = Utility:Create("TextButton", {Parent = card, BackgroundColor3 = Library.Theme.Accent, Position = UDim2.new(1, -102, 1, -34), Size = UDim2.fromOffset(90, 24), Text = "Track", TextColor3 = Library.Theme.Text, Font = Enum.Font.GothamBold, TextSize = 9, AutoButtonColor = false, BorderSizePixel = 0, ZIndex = 8})
                Utility:RegisterProperty(primary, "BackgroundColor3", "Accent")
                Utility:RegisterProperty(primary, "TextColor3", "Text")
                Utility:Create("UICorner", {Parent = primary, CornerRadius = UDim.new(0, 6)})
                local secondary = Utility:Create("TextButton", {Parent = card, BackgroundColor3 = Library.Theme.SurfaceAlt, Position = UDim2.fromOffset(12, height - 34), Size = UDim2.fromOffset(76, 24), Text = "Details", TextColor3 = Library.Theme.SubText, Font = Enum.Font.GothamBold, TextSize = 9, AutoButtonColor = false, BorderSizePixel = 0, Visible = false, ZIndex = 8})
                Utility:RegisterProperty(secondary, "BackgroundColor3", "SurfaceAlt")
                Utility:RegisterProperty(secondary, "TextColor3", "SubText")
                Utility:Create("UICorner", {Parent = secondary, CornerRadius = UDim.new(0, 6)})
                local controller = finishController({Type = "BossCard"}, card, context.Name or "Boss", options.Tooltip)
                local function refresh()
                    if type(context.GetContext) == "function" then
                        local ok, latest = pcall(context.GetContext, context)
                        if ok and type(latest) == "table" then for key, value in pairs(latest) do context[key] = value end end
                    end
                    title.Text = tostring(context.Name or "Boss")
                    subtitle.Text = tostring(context.Description or context.Location or "No live context")
                    local state = tostring(context.Status or "Waiting"):lower()
                    local colorKey = ({active = "Success", waiting = "Warn", error = "Error", defeated = "SubText"})[state] or "Warn"
                    Library.Registry[dot]["BackgroundColor3"] = colorKey
                    dot.BackgroundColor3 = Library.Theme[colorKey]
                    for _, child in ipairs(badges:GetChildren()) do if child.Name == "Badge" then child:Destroy() end end
                    createBadge(badges, state:upper(), colorKey, 1)
                    createBadge(badges, context.Level and ("LV. " .. tostring(context.Level)) or "", "Accent2", 2)
                    createBadge(badges, context.Requirement and tostring(context.Requirement) or "", "Warn", 3)
                    createBadge(badges, context.Drop and tostring(context.Drop) or "", "Success", 4)
                    primary.Text = tostring(context.ActionText or "Track")
                    secondary.Text = tostring(context.SecondaryText or "Details")
                    secondary.Visible = type(context.SecondaryCallback) == "function"
                    controller.Name = tostring(context.Name or "Boss")
                    return controller
                end
                function controller:SetContext(values) for key, value in pairs(values or {}) do context[key] = value end return refresh() end
                function controller:GetContext() return context end
                function controller:RefreshContext() return refresh() end
                function controller:SetStatus(value, description) context.Status = value if description ~= nil then context.Description = description end return refresh() end
                Library:Connect(primary.MouseButton1Click, function() Window:MarkActionUsed(normalizeActionId("boss-" .. tostring(context.Name))); Utility:SafeCall(context.Callback, context, controller) end)
                Library:Connect(secondary.MouseButton1Click, function() Utility:SafeCall(context.SecondaryCallback, context, controller) end)
                Window:RegisterCommand({Id = "boss-" .. tostring(context.Name), Name = tostring(context.ActionText or "Track") .. " " .. tostring(context.Name or "boss"), Description = context.Description, Category = "Bosses", Synonyms = context.Synonyms or {"boss", "spawn", "track"}, Callback = function() Utility:SafeCall(context.Callback, context, controller) end})
                addElement({Holder = card, Text = table.concat({tostring(context.Name or "Boss"), tostring(context.Description or ""), tostring(context.Location or ""), tostring(context.Drop or "")}, " "), Synonyms = context.Synonyms})
                refresh()
                return controller
            end

            function Section:CreateIslandCard(options)
                options = options or {}
                local state = {}
                for key, value in pairs(options) do state[key] = value end
                local card = Utility:Create("Frame", {Name = "IslandCard_" .. tostring(state.Name or "Island"), Parent = ContentContainer, BackgroundColor3 = Library.Theme.Surface, Size = UDim2.new(1, 0, 0, Library.DeviceMode == "Phone" and 74 or 68), BorderSizePixel = 0, ZIndex = 5})
                Utility:RegisterProperty(card, "BackgroundColor3", "Surface")
                Utility:Create("UICorner", {Parent = card, CornerRadius = UDim.new(0, 7)})
                local stripe = Utility:Create("Frame", {Parent = card, BackgroundColor3 = Library.Theme.Accent2, Size = UDim2.new(0, 3, 1, 0), BorderSizePixel = 0, ZIndex = 6})
                Utility:RegisterProperty(stripe, "BackgroundColor3", "Accent2")
                local title = Utility:Create("TextLabel", {Parent = card, BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -102, 0, 20), Text = "Island", TextColor3 = Library.Theme.Text, Font = Enum.Font.GothamBold, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 7})
                Utility:RegisterProperty(title, "TextColor3", "Text")
                local detail = Utility:Create("TextLabel", {Parent = card, BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 27), Size = UDim2.new(1, -104, 0, 27), Text = "", TextColor3 = Library.Theme.SubText, Font = Enum.Font.Gotham, TextSize = 8, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 7})
                Utility:RegisterProperty(detail, "TextColor3", "SubText")
                local kindBadge = createBadge(card, "PERMANENT", "Accent2", 1)
                kindBadge.Position = UDim2.new(1, -88, 0, 6)
                local action = Utility:Create("TextButton", {Parent = card, BackgroundColor3 = Library.Theme.SurfaceAlt, Position = UDim2.new(1, -88, 1, -29), Size = UDim2.fromOffset(76, 22), Text = "Travel", TextColor3 = Library.Theme.Text, Font = Enum.Font.GothamBold, TextSize = 8, AutoButtonColor = false, BorderSizePixel = 0, ZIndex = 8})
                Utility:RegisterProperty(action, "BackgroundColor3", "SurfaceAlt")
                Utility:RegisterProperty(action, "TextColor3", "Text")
                Utility:Create("UICorner", {Parent = action, CornerRadius = UDim.new(0, 6)})
                local controller = finishController({Type = "IslandCard"}, card, state.Name or "Island", options.Tooltip)
                local kindColors = {Permanent = "Accent2", Raid = "Warn", Event = "Accent3"}
                local function refresh()
                    local kind = tostring(state.Kind or "Permanent")
                    kind = kind:gsub("^%l", string.upper)
                    if not kindColors[kind] then kind = "Permanent" end
                    local colorKey = kindColors[kind]
                    title.Text = tostring(state.Name or "Island")
                    detail.Text = tostring(state.Description or state.Requirement or "Always available")
                    kindBadge.Text = kind:upper()
                    kindBadge.TextColor3 = Library.Theme[colorKey]
                    kindBadge.BackgroundColor3 = Library.Theme[colorKey]
                    Library.Registry[kindBadge]["TextColor3"] = colorKey
                    Library.Registry[kindBadge]["BackgroundColor3"] = colorKey
                    Library.Registry[stripe]["BackgroundColor3"] = colorKey
                    stripe.BackgroundColor3 = Library.Theme[colorKey]
                    action.Text = tostring(state.ActionText or (kind == "Raid" and "Join" or "Travel"))
                    return controller
                end
                function controller:SetData(values) for key, value in pairs(values or {}) do state[key] = value end return refresh() end
                function controller:SetKind(value) state.Kind = value return refresh() end
                function controller:GetData() return state end
                Library:Connect(action.MouseButton1Click, function() Window:MarkActionUsed(normalizeActionId("island-" .. tostring(state.Name))); Utility:SafeCall(state.Callback, state, controller) end)
                Window:RegisterCommand({Id = "island-" .. tostring(state.Name), Name = tostring(state.ActionText or "Travel to") .. " " .. tostring(state.Name or "island"), Description = state.Description, Category = "Islands", Synonyms = state.Synonyms or {state.Kind or "permanent", "island", "travel"}, Callback = function() Utility:SafeCall(state.Callback, state, controller) end})
                addElement({Holder = card, Text = table.concat({tostring(state.Name or "Island"), tostring(state.Kind or "Permanent"), tostring(state.Description or ""), tostring(state.Requirement or "")}, " "), Synonyms = state.Synonyms})
                refresh()
                return controller
            end

            function Section:CreateESPPresets(options)
                options = options or {}
                local presets = options.Presets or {
                    Low = {MaxVisible = 12, UpdateRate = 1 / 20, Skeleton = false, Highlight = false, Description = "20 FPS updates, 12 nearest targets, expensive effects disabled"},
                    Balanced = {MaxVisible = 32, UpdateRate = 1 / 30, Skeleton = false, Highlight = false, Description = "30 FPS updates and up to 32 targets"},
                    High = {MaxVisible = 80, UpdateRate = 0, Skeleton = false, Description = "Frame-synced boxes for up to 80 targets"}
                }
                local names = {}
                for presetName in pairs(presets) do table.insert(names, presetName) end
                table.sort(names)
                local defaultPreset = options.Default or (presets.Balanced and "Balanced" or names[1])
                local group = self:CreateGroup({Name = options.Name or "ESP visibility", Expanded = options.Expanded ~= false, Tooltip = options.Tooltip})
                local function applyPreset(value)
                    local definition = presets[value]
                    if options.Engine and definition and options.Engine.SetOptions then options.Engine:SetOptions(definition) end
                    Utility:SafeCall(options.Callback, value, definition)
                end
                local function applyNearest(value)
                    if options.Engine and options.Engine.SetOption then options.Engine:SetOption("NearestOnly", value) end
                    Utility:SafeCall(options.NearestCallback, value)
                end
                local density = group:CreateDropdown({Name = "Density preset", Values = names, Default = defaultPreset, Flag = options.DensityFlag or "ESPDensity", Callback = applyPreset})
                local nearest = group:CreateToggle({Name = "Nearest only", Default = options.NearestOnly == true, Flag = options.NearestFlag or "ESPNearestOnly", Callback = applyNearest})
                local info = group:CreateParagraph({Title = "Preset behavior", Content = presets[defaultPreset] and presets[defaultPreset].Description or ""})
                density:OnChanged(function(value) if presets[value] then info:SetContent(presets[value].Description or "") end end)
                local controller = {Type = "ESPPresets", Holder = group.Holder, Group = group, Density = density, NearestOnly = nearest, Engine = options.Engine}
                function controller:SetPreset(value) density:Set(value) return self end
                function controller:SetNearestOnly(value) nearest:Set(value) return self end
                function controller:Get() return {Preset = density:Get(), NearestOnly = nearest:Get(), Definition = presets[density:Get()]} end
                function controller:Reset() density:Reset(); nearest:Reset(); return true end
                applyPreset(defaultPreset)
                applyNearest(options.NearestOnly == true)
                return controller
            end

            function Section:CreateESPControls(options)
                options = options or {}
                local engine = options.Engine
                local prefix = tostring(options.FlagPrefix or "RenESP")
                local defaults = engine and engine.Options or mergeEspTables(ESP_DEFAULTS, options.Defaults)
                local group = self:CreateGroup({Name = options.Name or "ESP renderer", Expanded = options.Expanded ~= false, Tooltip = options.Tooltip})
                local controls = {}
                local function apply(name, value)
                    if engine and engine.SetOption then engine:SetOption(name, value) end
                    Utility:SafeCall(options.Callback, name, value, engine)
                end
                local function toggle(name, label, default, tooltip)
                    local control = group:CreateToggle({Name = label, Default = default == true, Flag = prefix .. name, Tooltip = tooltip, Callback = function(value) apply(name, value) end})
                    controls[name] = control
                    return control
                end
                local function slider(name, label, minimum, maximum, step, default, tooltip, transform)
                    local control = group:CreateSlider({Name = label, Min = minimum, Max = maximum, Step = step, Default = default, Flag = prefix .. name, Tooltip = tooltip, Callback = function(value) apply(name, transform and transform(value) or value) end})
                    controls[name] = control
                    return control
                end
                local function color(name, label, default)
                    local control = group:CreateColorPicker({Name = label, Default = default, Flag = prefix .. name, Callback = function(value) apply(name, value) end})
                    controls[name] = control
                    return control
                end

                controls.Enabled = toggle("Enabled", "ESP enabled", defaults.Enabled, "Master renderer switch")
                controls.Box = toggle("Box", "Bounding box", defaults.Box, "Works on players, NPCs, models, parts, and attachments")
                controls.BoxStyle = group:CreateDropdown({Name = "Box style", Values = {"Corners", "Full", "None"}, Default = defaults.BoxStyle or "Corners", Flag = prefix .. "BoxStyle", Callback = function(value) apply("BoxStyle", value) end})
                controls.HealthSide = group:CreateDropdown({Name = "Health bar side", Values = {"Left", "Right"}, Default = defaults.HealthSide or "Left", Flag = prefix .. "HealthSide", Callback = function(value) apply("HealthSide", value) end})
                controls.TracerOrigin = group:CreateDropdown({Name = "Tracer origin", Values = {"Bottom", "Center", "Top"}, Default = defaults.TracerOrigin or "Bottom", Flag = prefix .. "TracerOrigin", Callback = function(value) apply("TracerOrigin", value) end})
                controls.Outline = toggle("Outline", "Box and line outlines", defaults.Outline)
                controls.ShowName = toggle("ShowName", "Name label", defaults.ShowName)
                controls.ShowDetails = toggle("ShowDetails", "Detail label", defaults.ShowDetails)
                controls.ShowDistance = toggle("ShowDistance", "Distance", defaults.ShowDistance)
                controls.HealthBar = toggle("HealthBar", "Health bar", defaults.HealthBar, "Uses Humanoid health, attributes, or a custom GetHealth callback")
                controls.HealthText = toggle("HealthText", "Health text", defaults.HealthText)
                controls.Highlight = toggle("Highlight", "3D highlight", defaults.Highlight)
                controls.Skeleton = toggle("Skeleton", "Skeleton", defaults.Skeleton, "Optional and only drawn when compatible rig parts or custom joints exist")
                controls.Tracer = toggle("Tracer", "Tracer line", defaults.Tracer)
                controls.VisibilityCheck = toggle("VisibilityCheck", "Wall detection", defaults.VisibilityCheck)
                controls.NearestOnly = toggle("NearestOnly", "Nearest target only", defaults.NearestOnly)
                controls.BoxThickness = slider("BoxThickness", "Box thickness", 0.5, 5, 0.1, defaults.BoxThickness or 1.5)
                controls.CornerScale = slider("CornerScale", "Corner length", 0.1, 0.5, 0.01, defaults.CornerScale or 0.26)
                controls.BoxTransparency = slider("BoxTransparency", "Box transparency", 0, 0.9, 0.05, defaults.BoxTransparency or 0)
                controls.HiddenTransparency = slider("HiddenTransparency", "Occluded transparency", 0, 0.9, 0.05, defaults.HiddenTransparency or 0.3)
                controls.OutlineThickness = slider("OutlineThickness", "Outline thickness", 0.5, 5, 0.1, defaults.OutlineThickness or 2)
                controls.OutlineTransparency = slider("OutlineTransparency", "Outline transparency", 0, 0.95, 0.05, defaults.OutlineTransparency or 0.08)
                controls.SkeletonThickness = slider("SkeletonThickness", "Skeleton thickness", 0.5, 5, 0.1, defaults.SkeletonThickness or 1.5)
                controls.TracerThickness = slider("TracerThickness", "Tracer thickness", 0.5, 5, 0.1, defaults.TracerThickness or 1)
                controls.NameSize = slider("NameSize", "Name text size", 8, 24, 1, defaults.NameSize or 14)
                controls.DetailsSize = slider("DetailsSize", "Detail text size", 8, 22, 1, defaults.DetailsSize or 11)
                controls.HealthBarWidth = slider("HealthBarWidth", "Health bar width", 2, 12, 1, defaults.HealthBarWidth or 5)
                controls.MaxDistance = slider("MaxDistance", "Maximum distance", 25, tonumber(options.MaxDistance) or 10000, 25, defaults.MaxDistance or 2500)
                controls.SkeletonMaxDistance = slider("SkeletonMaxDistance", "Skeleton distance", 25, tonumber(options.MaxSkeletonDistance) or 2500, 25, defaults.SkeletonMaxDistance or 350)
                controls.MaxVisible = slider("MaxVisible", "Maximum targets", 1, tonumber(options.MaxTargets) or 200, 1, defaults.MaxVisible or 64)
                local initialFps = defaults.UpdateRate and defaults.UpdateRate > 0 and math.clamp(math.floor(1 / defaults.UpdateRate + 0.5), 5, 144) or 60
                controls.UpdateRate = slider("UpdateRate", "Update FPS", 5, 144, 1, initialFps, "60 is smooth; lower values reduce work", function(value) return 1 / math.max(1, value) end)
                controls.Color = color("Color", "Base color", defaults.Color or ESP_DEFAULTS.Color)
                controls.SkeletonColor = color("SkeletonColor", "Skeleton color", defaults.SkeletonColor or defaults.Color or ESP_DEFAULTS.Color)
                controls.HighlightColor = color("HighlightColor", "Highlight color", defaults.HighlightColor or defaults.Color or ESP_DEFAULTS.Color)
                controls.TracerColor = color("TracerColor", "Tracer color", defaults.TracerColor or defaults.Color or ESP_DEFAULTS.Color)
                controls.DetailsColor = color("DetailsColor", "Detail text color", defaults.DetailsColor or ESP_DEFAULTS.DetailsColor)
                controls.NameColor = color("NameColor", "Name text color", defaults.NameColor or defaults.Color or ESP_DEFAULTS.Color)
                controls.OutlineColor = color("OutlineColor", "Outline color", defaults.OutlineColor or ESP_DEFAULTS.OutlineColor)
                controls.HealthBackgroundColor = color("HealthBackgroundColor", "Health background", defaults.HealthBackgroundColor or ESP_DEFAULTS.HealthBackgroundColor)
                controls.TextStrokeColor = color("TextStrokeColor", "Text stroke color", defaults.TextStrokeColor or ESP_DEFAULTS.TextStrokeColor)

                local controller = {Type = "ESPControls", Holder = group.Holder, Group = group, Controls = controls, Engine = engine}
                function controller:SetEngine(nextEngine) self.Engine = nextEngine engine = nextEngine return self end
                function controller:Set(name, value)
                    local control = controls[name]
                    if control and control.Set then control:Set(value) else apply(name, value) end
                    return self
                end
                function controller:Get(name)
                    local control = controls[name]
                    return control and control.Get and control:Get() or (engine and engine.Options[name])
                end
                function controller:Reset()
                    for _, control in pairs(controls) do if control.Reset then control:Reset() end end
                    return true
                end
                return controller
            end

            function Section:CreateWorkflowPresets(options)
                options = options or {}
                for key, definition in pairs(options.Presets or {}) do Library:RegisterWorkflowPreset(key, definition) end
                local catalogItems = {}
                for _, entry in ipairs(Library:GetWorkflowPresets()) do
                    local key, preset = entry.Key, entry.Definition
                    table.insert(catalogItems, {
                        Id = "workflow-" .. key, Name = preset.Name or key,
                        Description = preset.Description or "Apply this workflow strategy.",
                        Category = "Workflows", Synonyms = preset.Synonyms,
                        Requirement = preset.Requirement,
                        Callback = function()
                            local ok, err = Library:ApplyWorkflowPreset(key)
                            Utility:SafeCall(options.Callback, key, preset, ok, err)
                            if options.Notify ~= false then Library:Notify({Title = ok and "Workflow applied" or "Workflow failed", Content = ok and tostring(preset.Name or key) or tostring(err), Duration = 3}) end
                        end
                    })
                end
                return self:CreateCatalog({Name = options.Name or "Workflow presets", Items = catalogItems, Height = options.Height or (Library.DeviceMode == "Phone" and 270 or 310), Placeholder = "Search leveling, items, raids, performance…", Tooltip = options.Tooltip})
            end

            function Section:CreateStrategyProfiles(options)
                options = options or {}
                local group = self:CreateGroup({Name = options.Name or "Strategy profiles", Expanded = options.Expanded ~= false, Tooltip = options.Tooltip})
                local nameInput = group:CreateInput({Name = "Profile name", Placeholder = "Example: Fast raid", Default = options.DefaultName or ""})
                local profiles = Library:GetStrategyProfiles()
                local selected = profiles[1]
                local picker = group:CreateDropdown({Name = "Saved profile", Values = profiles, Default = selected, Searchable = true})
                local function refresh(preferred)
                    profiles = Library:GetStrategyProfiles()
                    picker:Refresh(profiles)
                    if preferred then picker:Set(preferred) end
                    Utility:SafeCall(options.OnProfilesChanged, profiles)
                end
                group:CreateButton({Name = "Save strategy", Description = "Save the selected feature flags under this name.", Callback = function()
                    local profileName = nameInput:Get()
                    local ok, err = Library:SaveStrategyProfile(profileName, options.Flags)
                    if ok then refresh(cleanConfigName(profileName)) end
                    Library:Notify({Title = ok and "Strategy saved" or "Save failed", Content = ok and cleanConfigName(profileName) or tostring(err), Duration = 3})
                end})
                group:CreateButton({Name = "Load selected strategy", Callback = function()
                    local profileName = picker:Get()
                    local ok, err = Library:LoadStrategyProfile(profileName)
                    Library:Notify({Title = ok and "Strategy loaded" or "Load failed", Content = ok and tostring(profileName) or tostring(err), Duration = 3})
                end})
                group:CreateButton({Name = "Delete selected strategy", Callback = function()
                    local profileName = picker:Get()
                    local ok, err = Library:DeleteStrategyProfile(profileName)
                    if ok then refresh() end
                    Library:Notify({Title = ok and "Strategy deleted" or "Delete failed", Content = ok and tostring(profileName) or tostring(err), Duration = 3})
                end})
                group.ProfileName = nameInput
                group.ProfilePicker = picker
                group.RefreshProfiles = function(self) refresh() return self end
                return group
            end

            function Section:CreateProgressCard(options)
                options = options or {}
                local name = tostring(options.Name or "Progress")
                local progress = math.clamp(tonumber(options.Progress) or 0, 0, 1)
                local status = tostring(options.Status or "Waiting")
                local card = Utility:Create("Frame", {
                    Name = "ProgressCard_" .. name, Parent = ContentContainer,
                    BackgroundColor3 = Library.Theme.Surface, Size = UDim2.new(1, 0, 0, 96),
                    BorderSizePixel = 0, ZIndex = 5
                })
                Utility:RegisterProperty(card, "BackgroundColor3", "Surface")
                Utility:RegisterMaterial(card, 0.3, 0)
                Utility:Create("UICorner", {Parent = card, CornerRadius = UDim.new(0, 7)})
                local cardStroke = Utility:Create("UIStroke", {Parent = card, Color = Library.Theme.Divider, Thickness = 1, Transparency = 0.72})
                Utility:RegisterProperty(cardStroke, "Color", "Divider")
                local dot = Utility:Create("Frame", {Parent = card, BackgroundColor3 = Library.Theme.Warn, Position = UDim2.fromOffset(12, 13), Size = UDim2.fromOffset(8, 8), BorderSizePixel = 0, ZIndex = 7})
                Utility:RegisterProperty(dot, "BackgroundColor3", "Warn")
                Utility:Create("UICorner", {Parent = dot, CornerRadius = UDim.new(1, 0)})
                local title = Utility:Create("TextLabel", {Parent = card, BackgroundTransparency = 1, Position = UDim2.fromOffset(28, 6), Size = UDim2.new(1, -92, 0, 20), Text = name, TextColor3 = Library.Theme.Text, Font = Enum.Font.GothamBold, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 7})
                Utility:RegisterProperty(title, "TextColor3", "Text")
                local percent = Utility:Create("TextLabel", {Parent = card, BackgroundTransparency = 1, Position = UDim2.new(1, -64, 0, 6), Size = UDim2.fromOffset(52, 20), Text = tostring(math.floor(progress * 100 + 0.5)) .. "%", TextColor3 = Library.Theme.Accent, Font = Enum.Font.GothamBold, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 7})
                Utility:RegisterProperty(percent, "TextColor3", "Accent")
                local detail = Utility:Create("TextLabel", {Parent = card, BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 29), Size = UDim2.new(1, -24, 0, 18), Text = tostring(options.Detail or "Waiting to start"), TextColor3 = Library.Theme.SubText, Font = Enum.Font.Gotham, TextSize = 9, TextTruncate = Enum.TextTruncate.AtEnd, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 7})
                Utility:RegisterProperty(detail, "TextColor3", "SubText")
                local track = Utility:Create("Frame", {Parent = card, BackgroundColor3 = Library.Theme.SurfaceAlt, Position = UDim2.fromOffset(12, 51), Size = UDim2.new(1, -24, 0, 5), BorderSizePixel = 0, ZIndex = 7})
                Utility:RegisterProperty(track, "BackgroundColor3", "SurfaceAlt")
                Utility:Create("UICorner", {Parent = track, CornerRadius = UDim.new(1, 0)})
                local fill = Utility:Create("Frame", {Parent = track, BackgroundColor3 = Library.Theme.Accent, Size = UDim2.new(progress, 0, 1, 0), BorderSizePixel = 0, ZIndex = 8})
                Utility:RegisterProperty(fill, "BackgroundColor3", "Accent")
                Utility:Create("UICorner", {Parent = fill, CornerRadius = UDim.new(1, 0)})
                local step = Utility:Create("TextLabel", {Parent = card, BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 61), Size = UDim2.new(0.5, -12, 0, 25), Text = tostring(options.Step or "Step 0 / 0"), TextColor3 = Library.Theme.Text, Font = Enum.Font.GothamMedium, TextSize = 9, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 7})
                Utility:RegisterProperty(step, "TextColor3", "Text")
                local metrics = Utility:Create("TextLabel", {Parent = card, BackgroundTransparency = 1, Position = UDim2.new(0.5, 0, 0, 61), Size = UDim2.new(0.5, -12, 0, 25), Text = tostring(options.Metrics or ""), TextColor3 = Library.Theme.SubText, Font = Enum.Font.Gotham, TextSize = 9, TextXAlignment = Enum.TextXAlignment.Right, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 7})
                Utility:RegisterProperty(metrics, "TextColor3", "SubText")
                local controller = finishController({Type = "ProgressCard"}, card, name, options.Tooltip)
                local statusColors = {active = "Success", waiting = "Warn", error = "Error", complete = "Success", paused = "Warn", idle = "SubText"}
                function controller:SetProgress(value, nextDetail)
                    progress = math.clamp(tonumber(value) or 0, 0, 1)
                    percent.Text = tostring(math.floor(progress * 100 + 0.5)) .. "%"
                    Utility:Tween(fill, TweenInfo.new(0.18), {Size = UDim2.new(progress, 0, 1, 0)})
                    if nextDetail ~= nil then detail.Text = tostring(nextDetail) end
                    return self
                end
                function controller:SetStatus(value, nextDetail)
                    status = tostring(value or "Idle")
                    local colorKey = statusColors[status:lower()] or "SubText"
                    Library.Registry[dot]["BackgroundColor3"] = colorKey
                    Utility:Tween(dot, TweenInfo.new(0.15), {BackgroundColor3 = Library.Theme[colorKey]})
                    if nextDetail ~= nil then detail.Text = tostring(nextDetail) end
                    return self
                end
                function controller:SetStep(current, total, label)
                    step.Text = label and tostring(label) or string.format("Step %s / %s", tostring(current or 0), tostring(total or 0))
                    return self
                end
                function controller:SetMetrics(value)
                    if type(value) == "table" then
                        local parts = {}
                        for key, item in pairs(value) do table.insert(parts, tostring(key) .. ": " .. tostring(item)) end
                        table.sort(parts)
                        metrics.Text = table.concat(parts, "  •  ")
                    else metrics.Text = tostring(value or "") end
                    return self
                end
                function controller:Complete(nextDetail) self:SetProgress(1, nextDetail or "Complete"); self:SetStatus("Complete"); return self end
                controller:SetStatus(status)
                addElement({Holder = card, Text = name .. " " .. tostring(options.Detail or ""), Synonyms = options.Synonyms})
                return controller
            end

            function Section:CreateActivityFeed(options)
                options = options or {}
                local name = tostring(options.Name or "Activity")
                local maxEntries = math.max(3, tonumber(options.MaxEntries) or 40)
                local entries, visuals = {}, {}
                local container = Utility:Create("Frame", {Name = "ActivityFeed_" .. name, Parent = ContentContainer, BackgroundColor3 = Library.Theme.Surface, Size = UDim2.new(1, 0, 0, tonumber(options.Height) or 210), BorderSizePixel = 0, ClipsDescendants = true, ZIndex = 5})
                Utility:RegisterProperty(container, "BackgroundColor3", "Surface")
                Utility:Create("UICorner", {Parent = container, CornerRadius = UDim.new(0, 8)})
                local title = Utility:Create("TextLabel", {Parent = container, BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -62, 0, 34), Text = name, TextColor3 = Library.Theme.Text, Font = Enum.Font.GothamBold, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 7})
                Utility:RegisterProperty(title, "TextColor3", "Text")
                local clear = Utility:Create("TextButton", {Parent = container, BackgroundTransparency = 1, Position = UDim2.new(1, -48, 0, 0), Size = UDim2.fromOffset(44, 34), Text = "Clear", TextColor3 = Library.Theme.SubText, Font = Enum.Font.GothamBold, TextSize = 9, ZIndex = 7})
                Utility:RegisterProperty(clear, "TextColor3", "SubText")
                local feed = Utility:Create("ScrollingFrame", {Name = "Entries", Parent = container, BackgroundColor3 = Library.Theme.Secondary, BackgroundTransparency = 0.22, Position = UDim2.fromOffset(8, 34), Size = UDim2.new(1, -16, 1, -42), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 2, ScrollBarImageColor3 = Library.Theme.Accent, BorderSizePixel = 0, ZIndex = 6})
                Utility:RegisterProperty(feed, "BackgroundColor3", "Secondary")
                Utility:RegisterProperty(feed, "ScrollBarImageColor3", "Accent")
                Utility:Create("UICorner", {Parent = feed, CornerRadius = UDim.new(0, 6)})
                Utility:Create("UIListLayout", {Parent = feed, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 3)})
                local controller = finishController({Type = "ActivityFeed"}, container, name, options.Tooltip)
                local colors = {Info = "Accent2", Active = "Success", Success = "Success", Warning = "Warn", Error = "Error", Waiting = "Warn"}
                local function render()
                    for _, child in ipairs(feed:GetChildren()) do if child.Name == "ActivityEntry" then child:Destroy() end end
                    for index, entry in ipairs(entries) do
                        local row = Utility:Create("Frame", {Name = "ActivityEntry", Parent = feed, BackgroundTransparency = 1, Size = UDim2.new(1, -4, 0, entry.Detail ~= "" and 40 or 28), LayoutOrder = index, ZIndex = 7})
                        local colorKey = colors[entry.Level] or "Accent2"
                        local rowDot = Utility:Create("Frame", {Parent = row, BackgroundColor3 = Library.Theme[colorKey], Position = UDim2.fromOffset(7, 10), Size = UDim2.fromOffset(7, 7), BorderSizePixel = 0, ZIndex = 8})
                        Utility:RegisterProperty(rowDot, "BackgroundColor3", colorKey)
                        Utility:Create("UICorner", {Parent = rowDot, CornerRadius = UDim.new(1, 0)})
                        local message = Utility:Create("TextLabel", {Parent = row, BackgroundTransparency = 1, Position = UDim2.fromOffset(22, 3), Size = UDim2.new(1, -82, 0, 19), Text = entry.Message, TextColor3 = Library.Theme.Text, Font = Enum.Font.GothamMedium, TextSize = 9, TextTruncate = Enum.TextTruncate.AtEnd, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 8})
                        Utility:RegisterProperty(message, "TextColor3", "Text")
                        local time = Utility:Create("TextLabel", {Parent = row, BackgroundTransparency = 1, Position = UDim2.new(1, -58, 0, 3), Size = UDim2.fromOffset(50, 19), Text = entry.Time, TextColor3 = Library.Theme.SubText, Font = Enum.Font.Gotham, TextSize = 8, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 8})
                        Utility:RegisterProperty(time, "TextColor3", "SubText")
                        if entry.Detail ~= "" then
                            local detail = Utility:Create("TextLabel", {Parent = row, BackgroundTransparency = 1, Position = UDim2.fromOffset(22, 21), Size = UDim2.new(1, -30, 0, 15), Text = entry.Detail, TextColor3 = Library.Theme.SubText, Font = Enum.Font.Gotham, TextSize = 8, TextTruncate = Enum.TextTruncate.AtEnd, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 8})
                            Utility:RegisterProperty(detail, "TextColor3", "SubText")
                        end
                    end
                    task.defer(function() if feed.Parent then feed.CanvasPosition = Vector2.new(0, math.max(0, feed.AbsoluteCanvasSize.Y)) end end)
                end
                function controller:Push(message, level, detail)
                    table.insert(entries, {Message = tostring(message), Level = tostring(level or "Info"), Detail = tostring(detail or ""), Time = string.format("%.1fs", os.clock())})
                    while #entries > maxEntries do table.remove(entries, 1) end
                    render()
                    return self
                end
                controller.Add = controller.Push
                function controller:Clear() table.clear(entries); render(); return self end
                function controller:GetEntries() return entries end
                Library:Connect(clear.MouseButton1Click, function() controller:Clear() end)
                addElement({Holder = container, Text = name .. " activity log timeline", Synonyms = options.Synonyms})
                for _, entry in ipairs(options.Entries or {}) do controller:Push(entry.Message or entry[1] or entry, entry.Level or entry[2], entry.Detail or entry[3]) end
                return controller
            end

            function Section:CreateChecklist(options)
                options = options or {}
                local name = tostring(options.Name or "Checklist")
                local items, itemById = {}, {}
                for index, raw in ipairs(options.Items or {}) do
                    local item = type(raw) == "table" and raw or {Name = tostring(raw)}
                    item.Id = normalizeActionId(item.Id or item.Name or index)
                    item.Name = tostring(item.Name or item.Id)
                    item.Status = tostring(item.Status or "Pending")
                    table.insert(items, item)
                    itemById[item.Id] = item
                end
                local height = 48 + math.max(1, #items) * 34
                local container = Utility:Create("Frame", {Name = "Checklist_" .. name, Parent = ContentContainer, BackgroundColor3 = Library.Theme.Surface, Size = UDim2.new(1, 0, 0, height), BorderSizePixel = 0, ClipsDescendants = true, ZIndex = 5})
                Utility:RegisterProperty(container, "BackgroundColor3", "Surface")
                Utility:Create("UICorner", {Parent = container, CornerRadius = UDim.new(0, 8)})
                local title = Utility:Create("TextLabel", {Parent = container, BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -82, 0, 38), Text = name, TextColor3 = Library.Theme.Text, Font = Enum.Font.GothamBold, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 7})
                Utility:RegisterProperty(title, "TextColor3", "Text")
                local progressLabel = Utility:Create("TextLabel", {Parent = container, BackgroundTransparency = 1, Position = UDim2.new(1, -72, 0, 0), Size = UDim2.fromOffset(60, 38), Text = "0 / 0", TextColor3 = Library.Theme.SubText, Font = Enum.Font.GothamBold, TextSize = 9, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 7})
                Utility:RegisterProperty(progressLabel, "TextColor3", "SubText")
                local body = Utility:Create("Frame", {Parent = container, BackgroundTransparency = 1, Position = UDim2.fromOffset(8, 38), Size = UDim2.new(1, -16, 0, math.max(1, #items) * 34), ZIndex = 6})
                Utility:Create("UIListLayout", {Parent = body, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4)})
                local controller = finishController({Type = "Checklist"}, container, name, options.Tooltip)
                local colors = {Pending = "SubText", Active = "Accent2", Done = "Success", Error = "Error", Waiting = "Warn"}
                local function render()
                    for _, child in ipairs(body:GetChildren()) do if child.Name == "ChecklistItem" then child:Destroy() end end
                    local done = 0
                    for index, item in ipairs(items) do
                        if item.Status == "Done" then done = done + 1 end
                        local row = Utility:Create("TextButton", {Name = "ChecklistItem", Parent = body, BackgroundColor3 = Library.Theme.Secondary, BackgroundTransparency = 0.18, Size = UDim2.new(1, 0, 0, 30), Text = "", AutoButtonColor = false, LayoutOrder = index, BorderSizePixel = 0, ZIndex = 7})
                        Utility:RegisterProperty(row, "BackgroundColor3", "Secondary")
                        Utility:Create("UICorner", {Parent = row, CornerRadius = UDim.new(0, 6)})
                        local colorKey = colors[item.Status] or "SubText"
                        local check = Utility:Create("TextLabel", {Parent = row, BackgroundColor3 = Library.Theme[colorKey], BackgroundTransparency = item.Status == "Done" and 0.1 or 0.72, Position = UDim2.fromOffset(7, 7), Size = UDim2.fromOffset(16, 16), Text = item.Status == "Done" and "✓" or (item.Status == "Error" and "!" or ""), TextColor3 = Library.Theme[colorKey], Font = Enum.Font.GothamBold, TextSize = 9, BorderSizePixel = 0, ZIndex = 8})
                        Utility:RegisterProperty(check, "BackgroundColor3", colorKey)
                        Utility:RegisterProperty(check, "TextColor3", colorKey)
                        Utility:Create("UICorner", {Parent = check, CornerRadius = UDim.new(1, 0)})
                        local label = Utility:Create("TextLabel", {Parent = row, BackgroundTransparency = 1, Position = UDim2.fromOffset(31, 0), Size = UDim2.new(1, -96, 1, 0), Text = item.Name, TextColor3 = item.Status == "Done" and Library.Theme.SubText or Library.Theme.Text, Font = Enum.Font.GothamMedium, TextSize = 9, TextTruncate = Enum.TextTruncate.AtEnd, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 8})
                        Utility:RegisterProperty(label, "TextColor3", item.Status == "Done" and "SubText" or "Text")
                        local state = Utility:Create("TextLabel", {Parent = row, BackgroundTransparency = 1, Position = UDim2.new(1, -62, 0, 0), Size = UDim2.fromOffset(54, 30), Text = item.Status, TextColor3 = Library.Theme[colorKey], Font = Enum.Font.GothamBold, TextSize = 8, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 8})
                        Utility:RegisterProperty(state, "TextColor3", colorKey)
                        Library:Connect(row.MouseButton1Click, function() controller:SetItemStatus(item.Id, item.Status == "Done" and "Pending" or "Done") end)
                    end
                    progressLabel.Text = string.format("%d / %d", done, #items)
                    controller.Progress = #items > 0 and done / #items or 0
                end
                function controller:SetItemStatus(id, nextStatus)
                    local item = itemById[normalizeActionId(id)]
                    if not item then return false end
                    item.Status = tostring(nextStatus or "Pending"):gsub("^%l", string.upper)
                    render()
                    Utility:SafeCall(options.Callback, item, self.Progress)
                    return true
                end
                function controller:GetItems() return items end
                function controller:GetProgress() return self.Progress or 0 end
                function controller:Reset() for _, item in ipairs(items) do item.Status = "Pending" end render() return true end
                addElement({Holder = container, Text = name .. " objectives steps checklist", Synonyms = options.Synonyms})
                render()
                return controller
            end

            function Section:CreateStatusBanner(options)
                options = options or {}
                local stateColors = {active = "Success", success = "Success", waiting = "Warn", warning = "Warn", error = "Error", info = "Accent2", idle = "SubText"}
                local status = tostring(options.Status or "Info"):lower()
                local height = options.ActionText and 72 or 62
                local container = Utility:Create("Frame", {
                    Name = "StatusBanner_" .. tostring(options.Title or "Status"), Parent = ContentContainer,
                    BackgroundColor3 = Library.Theme.Surface, Size = UDim2.new(1, 0, 0, height),
                    BorderSizePixel = 0, ClipsDescendants = true, ZIndex = 5
                })
                Utility:RegisterProperty(container, "BackgroundColor3", "Surface")
                Utility:Create("UICorner", {Parent = container, CornerRadius = UDim.new(0, 7)})
                local accent = Utility:Create("Frame", {Parent = container, BackgroundColor3 = Library.Theme.Accent2, Size = UDim2.new(0, 3, 1, 0), BorderSizePixel = 0, ZIndex = 6})
                Utility:RegisterProperty(accent, "BackgroundColor3", "Accent2")
                local dot = Utility:Create("Frame", {Parent = container, Position = UDim2.fromOffset(12, 13), Size = UDim2.fromOffset(7, 7), BackgroundColor3 = Library.Theme.Accent2, BorderSizePixel = 0, ZIndex = 7})
                Utility:RegisterProperty(dot, "BackgroundColor3", "Accent2")
                Utility:Create("UICorner", {Parent = dot, CornerRadius = UDim.new(1, 0)})
                local title = Utility:Create("TextLabel", {Parent = container, BackgroundTransparency = 1, Position = UDim2.fromOffset(25, 5), Size = UDim2.new(1, options.ActionText and -116 or -36, 0, 22), Text = tostring(options.Title or "Status"), TextColor3 = Library.Theme.Text, Font = Enum.Font.GothamBold, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 7})
                Utility:RegisterProperty(title, "TextColor3", "Text")
                local message = Utility:Create("TextLabel", {Parent = container, BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 27), Size = UDim2.new(1, options.ActionText and -116 or -24, 0, height - 34), Text = tostring(options.Content or options.Message or ""), TextColor3 = Library.Theme.SubText, Font = Enum.Font.Gotham, TextSize = 9, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 7})
                Utility:RegisterProperty(message, "TextColor3", "SubText")
                local action
                if options.ActionText then
                    action = Utility:Create("TextButton", {Parent = container, Position = UDim2.new(1, -98, 0.5, -14), Size = UDim2.fromOffset(86, 28), BackgroundColor3 = Library.Theme.SurfaceAlt, Text = tostring(options.ActionText), TextColor3 = Library.Theme.Text, Font = Enum.Font.GothamBold, TextSize = 9, AutoButtonColor = false, BorderSizePixel = 0, ZIndex = 8})
                    Utility:RegisterProperty(action, "BackgroundColor3", "SurfaceAlt")
                    Utility:RegisterProperty(action, "TextColor3", "Text")
                    Utility:Create("UICorner", {Parent = action, CornerRadius = UDim.new(0, 6)})
                end
                local controller = finishController({Type = "StatusBanner", Status = status}, container, options.Title or "Status", options.Tooltip)
                function controller:SetStatus(value)
                    status = tostring(value or "Info"):lower()
                    self.Status = status
                    local colorKey = stateColors[status] or "Accent2"
                    Library.Registry[accent]["BackgroundColor3"] = colorKey
                    Library.Registry[dot]["BackgroundColor3"] = colorKey
                    Utility:Tween(accent, TweenInfo.new(0.15), {BackgroundColor3 = Library.Theme[colorKey]})
                    Utility:Tween(dot, TweenInfo.new(0.15), {BackgroundColor3 = Library.Theme[colorKey]})
                    return self
                end
                function controller:SetTitle(value) title.Text = tostring(value or "") return self end
                function controller:SetContent(value) message.Text = tostring(value or "") return self end
                function controller:SetActionText(value) if action then action.Text = tostring(value or "") end return self end
                if action then
                    Library:Connect(action.MouseButton1Click, function() Utility:SafeCall(options.Callback, controller) end)
                    Library:Connect(action.MouseEnter, function() Utility:Tween(action, TweenInfo.new(0.12), {BackgroundColor3 = Library.Theme.Hover}) end)
                    Library:Connect(action.MouseLeave, function() Utility:Tween(action, TweenInfo.new(0.12), {BackgroundColor3 = Library.Theme.SurfaceAlt}) end)
                end
                controller:SetStatus(status)
                addElement({Holder = container, Text = tostring(options.Title or "Status") .. " " .. tostring(options.Content or options.Message or ""), Synonyms = options.Synonyms})
                return controller
            end

            function Section:CreateActionBar(options)
                options = options or {}
                local actions, byId, visuals = {}, {}, {}
                local container = Utility:Create("Frame", {Name = "ActionBar", Parent = ContentContainer, BackgroundColor3 = Library.Theme.Surface, Size = UDim2.new(1, 0, 0, 42), BorderSizePixel = 0, ZIndex = 5})
                Utility:RegisterProperty(container, "BackgroundColor3", "Surface")
                Utility:Create("UICorner", {Parent = container, CornerRadius = UDim.new(0, 7)})
                local body = Utility:Create("Frame", {Parent = container, BackgroundTransparency = 1, Position = UDim2.fromOffset(5, 5), Size = UDim2.new(1, -10, 1, -10), ZIndex = 6})
                local grid = Utility:Create("UIGridLayout", {Parent = body, CellPadding = UDim2.fromOffset(5, 0), CellSize = UDim2.new(1, 0, 1, 0), FillDirectionMaxCells = 1, SortOrder = Enum.SortOrder.LayoutOrder})
                local controller = finishController({Type = "ActionBar"}, container, options.Name or "Actions", options.Tooltip)
                local commandPrefix = "bar-" .. normalizeActionId(options.Id or options.Name or (Tab.Name .. "-" .. SectionName))
                local statusColors = {active = "Success", waiting = "Warn", error = "Error", idle = "SubText"}
                local function resize()
                    local count = math.max(1, #actions)
                    grid.FillDirectionMaxCells = count
                    grid.CellSize = UDim2.new(1 / count, -((count - 1) * 5) / count, 1, 0)
                end
                function controller:AddAction(value)
                    value = value or {}
                    local id = normalizeActionId(value.Id or value.Name)
                    if byId[id] then return byId[id] end
                    local definition = {Id = id, Name = tostring(value.Name or id), Callback = value.Callback, Enabled = value.Enabled ~= false, Status = tostring(value.Status or "Idle"):lower(), CommandId = commandPrefix .. "-" .. id}
                    table.insert(actions, definition)
                    byId[id] = definition
                    local button = Utility:Create("TextButton", {Name = "Action_" .. id, Parent = body, BackgroundColor3 = Library.Theme.SurfaceAlt, Text = definition.Name, TextColor3 = Library.Theme.Text, Font = Enum.Font.GothamBold, TextSize = 9, TextTruncate = Enum.TextTruncate.AtEnd, AutoButtonColor = false, BorderSizePixel = 0, LayoutOrder = #actions, ZIndex = 7})
                    Utility:RegisterProperty(button, "BackgroundColor3", "SurfaceAlt")
                    Utility:RegisterProperty(button, "TextColor3", "Text")
                    Utility:Create("UICorner", {Parent = button, CornerRadius = UDim.new(0, 6)})
                    local dot = Utility:Create("Frame", {Parent = button, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -4, 0, 4), Size = UDim2.fromOffset(6, 6), BackgroundColor3 = Library.Theme.SubText, BorderSizePixel = 0, Visible = false, ZIndex = 8})
                    Utility:RegisterProperty(dot, "BackgroundColor3", "SubText")
                    Utility:Create("UICorner", {Parent = dot, CornerRadius = UDim.new(1, 0)})
                    visuals[id] = {Button = button, Dot = dot}
                    Window:RegisterCommand({Id = definition.CommandId, Name = definition.Name, Description = value.Description or "Inline action", Category = options.Category or (Tab.Name .. " / " .. SectionName), Synonyms = value.Synonyms, Requirement = value.Requirement, Callback = function() if definition.Enabled then Utility:SafeCall(definition.Callback, definition, controller) end end})
                    Library:Connect(button.MouseButton1Click, function() if definition.Enabled then Window:ExecuteCommand(definition.CommandId) end end)
                    Library:Connect(button.MouseEnter, function() if definition.Enabled then Utility:Tween(button, TweenInfo.new(0.12), {BackgroundColor3 = Library.Theme.Hover}) end end)
                    Library:Connect(button.MouseLeave, function() Utility:Tween(button, TweenInfo.new(0.12), {BackgroundColor3 = Library.Theme.SurfaceAlt}) end)
                    resize()
                    self:SetEnabled(id, definition.Enabled)
                    self:SetStatus(id, definition.Status)
                    return definition
                end
                function controller:SetEnabled(id, value)
                    id = normalizeActionId(id)
                    local definition, visual = byId[id], visuals[id]
                    if not definition then return false end
                    definition.Enabled = value == true
                    visual.Button.TextTransparency = definition.Enabled and 0 or 0.55
                    visual.Button.BackgroundTransparency = definition.Enabled and 0 or 0.45
                    return true
                end
                function controller:SetStatus(id, value)
                    id = normalizeActionId(id)
                    local definition, visual = byId[id], visuals[id]
                    if not definition then return false end
                    definition.Status = tostring(value or "Idle"):lower()
                    local colorKey = statusColors[definition.Status] or "SubText"
                    visual.Dot.Visible = definition.Status ~= "idle"
                    Library.Registry[visual.Dot]["BackgroundColor3"] = colorKey
                    visual.Dot.BackgroundColor3 = Library.Theme[colorKey]
                    return true
                end
                function controller:Trigger(id)
                    local definition = byId[normalizeActionId(id)]
                    if not definition then return false, "Unknown action" end
                    return Window:ExecuteCommand(definition.CommandId)
                end
                function controller:GetActions() return actions end
                for _, action in ipairs(options.Actions or {}) do controller:AddAction(action) end
                resize()
                addElement({Holder = container, Text = tostring(options.Name or "Actions"), Synonyms = options.Synonyms})
                return controller
            end

            function Section:CreateStatGrid(options)
                options = options or {}
                local items, byId, visuals = {}, {}, {}
                local columns = math.clamp(tonumber(options.Columns) or 2, 1, 4)
                local container = Utility:Create("Frame", {Name = "StatGrid", Parent = ContentContainer, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 60), ZIndex = 5})
                local grid = Utility:Create("UIGridLayout", {Parent = container, CellPadding = UDim2.fromOffset(5, 5), CellSize = UDim2.new(1 / columns, -((columns - 1) * 5) / columns, 0, 58), FillDirectionMaxCells = columns, SortOrder = Enum.SortOrder.LayoutOrder})
                local controller = finishController({Type = "StatGrid"}, container, options.Name or "Statistics", options.Tooltip)
                local function resize()
                    container.Size = UDim2.new(1, 0, 0, math.max(1, math.ceil(#items / columns)) * 63 - 5)
                end
                function controller:Add(value)
                    value = value or {}
                    local id = normalizeActionId(value.Id or value.Name or (#items + 1))
                    if byId[id] then return byId[id] end
                    local item = {Id = id, Name = tostring(value.Name or id), Value = value.Value, Trend = tostring(value.Trend or value.Detail or ""), Color = value.Color or "Accent"}
                    table.insert(items, item); byId[id] = item
                    local card = Utility:Create("Frame", {Name = "Stat_" .. id, Parent = container, BackgroundColor3 = Library.Theme.Surface, BorderSizePixel = 0, LayoutOrder = #items, ZIndex = 6})
                    Utility:RegisterProperty(card, "BackgroundColor3", "Surface")
                    Utility:Create("UICorner", {Parent = card, CornerRadius = UDim.new(0, 7)})
                    local label = Utility:Create("TextLabel", {Parent = card, BackgroundTransparency = 1, Position = UDim2.fromOffset(10, 6), Size = UDim2.new(1, -20, 0, 16), Text = item.Name:upper(), TextColor3 = Library.Theme.SubText, Font = Enum.Font.GothamBold, TextSize = 8, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 7})
                    Utility:RegisterProperty(label, "TextColor3", "SubText")
                    local number = Utility:Create("TextLabel", {Parent = card, BackgroundTransparency = 1, Position = UDim2.fromOffset(10, 20), Size = UDim2.new(0.62, -10, 0, 28), Text = tostring(item.Value or "—"), TextColor3 = Library.Theme[item.Color] or Library.Theme.Accent, Font = Enum.Font.GothamBold, TextSize = 18, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 7})
                    Utility:RegisterProperty(number, "TextColor3", Library.Theme[item.Color] and item.Color or "Accent")
                    local trend = Utility:Create("TextLabel", {Parent = card, BackgroundTransparency = 1, Position = UDim2.new(0.62, 0, 0, 25), Size = UDim2.new(0.38, -10, 0, 18), Text = item.Trend, TextColor3 = Library.Theme.SubText, Font = Enum.Font.GothamMedium, TextSize = 8, TextXAlignment = Enum.TextXAlignment.Right, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 7})
                    Utility:RegisterProperty(trend, "TextColor3", "SubText")
                    visuals[id] = {Card = card, Value = number, Trend = trend}
                    resize()
                    return item
                end
                function controller:SetValue(id, value, trendText)
                    id = normalizeActionId(id)
                    local item, visual = byId[id], visuals[id]
                    if not item then return false end
                    item.Value = value; visual.Value.Text = tostring(value)
                    if trendText ~= nil then item.Trend = tostring(trendText); visual.Trend.Text = item.Trend end
                    return true
                end
                function controller:SetColor(id, colorKey)
                    id = normalizeActionId(id)
                    local item, visual = byId[id], visuals[id]
                    if not item or not Library.Theme[colorKey] then return false end
                    item.Color = colorKey; Library.Registry[visual.Value]["TextColor3"] = colorKey; visual.Value.TextColor3 = Library.Theme[colorKey]
                    return true
                end
                function controller:GetItems() return items end
                for _, item in ipairs(options.Items or {}) do controller:Add(item) end
                resize()
                addElement({Holder = container, Text = tostring(options.Name or "Statistics"), Synonyms = options.Synonyms})
                return controller
            end

            function Section:CreateLeaderboard(options)
                options = options or {}
                local entries = {}
                local height = tonumber(options.Height) or 210
                local container = Utility:Create("Frame", {Name = "Leaderboard", Parent = ContentContainer, BackgroundColor3 = Library.Theme.Surface, Size = UDim2.new(1, 0, 0, height), BorderSizePixel = 0, ClipsDescendants = true, ZIndex = 5})
                Utility:RegisterProperty(container, "BackgroundColor3", "Surface")
                Utility:Create("UICorner", {Parent = container, CornerRadius = UDim.new(0, 7)})
                local title = Utility:Create("TextLabel", {Parent = container, BackgroundTransparency = 1, Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -20, 0, 32), Text = tostring(options.Name or "Leaderboard"), TextColor3 = Library.Theme.Text, Font = Enum.Font.GothamBold, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 7})
                Utility:RegisterProperty(title, "TextColor3", "Text")
                local body = Utility:Create("ScrollingFrame", {Parent = container, BackgroundTransparency = 1, Position = UDim2.fromOffset(7, 32), Size = UDim2.new(1, -14, 1, -39), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 2, ScrollBarImageColor3 = Library.Theme.Accent, BorderSizePixel = 0, ZIndex = 6})
                Utility:RegisterProperty(body, "ScrollBarImageColor3", "Accent")
                Utility:Create("UIListLayout", {Parent = body, Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder})
                local controller = finishController({Type = "Leaderboard"}, container, options.Name or "Leaderboard", options.Tooltip)
                local function render()
                    table.sort(entries, function(a, b) return (tonumber(a.Score) or 0) > (tonumber(b.Score) or 0) end)
                    for index, entry in ipairs(entries) do
                        local highlighted = entry.Highlighted == true
                        local visual = visuals[entry]
                        if not visual then
                            local row = Utility:Create("Frame", {Name = "LeaderboardRow", Parent = body, BackgroundColor3 = Library.Theme.Secondary, BackgroundTransparency = 0.22, Size = UDim2.new(1, -3, 0, 32), BorderSizePixel = 0, LayoutOrder = index, ZIndex = 7})
                            Utility:RegisterProperty(row, "BackgroundColor3", "Secondary")
                            Utility:Create("UICorner", {Parent = row, CornerRadius = UDim.new(0, 6)})
                            local rank = Utility:Create("TextLabel", {Parent = row, BackgroundTransparency = 1, Position = UDim2.fromOffset(8, 0), Size = UDim2.fromOffset(24, 32), Text = tostring(index), TextColor3 = Library.Theme.Accent, Font = Enum.Font.GothamBold, TextSize = 10, ZIndex = 8})
                            Utility:RegisterProperty(rank, "TextColor3", "Accent")
                            local entryName = Utility:Create("TextLabel", {Parent = row, BackgroundTransparency = 1, Position = UDim2.fromOffset(36, 0), Size = UDim2.new(1, -126, 1, 0), Text = tostring(entry.Name or "Player"), TextColor3 = Library.Theme.Text, Font = Enum.Font.GothamMedium, TextSize = 9, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 8})
                            Utility:RegisterProperty(entryName, "TextColor3", "Text")
                            local score = Utility:Create("TextLabel", {Parent = row, BackgroundTransparency = 1, Position = UDim2.new(1, -86, 0, 0), Size = UDim2.fromOffset(76, 32), Text = tostring(entry.Score or 0), TextColor3 = Library.Theme.Accent2, Font = Enum.Font.GothamBold, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 8})
                            Utility:RegisterProperty(score, "TextColor3", "Accent2")
                            visual = {Row = row, Rank = rank, Name = entryName, Score = score}
                            visuals[entry] = visual
                        end
                        local rowKey = highlighted and "Hover" or "Secondary"
                        local rankKey = index <= 3 and "Accent" or "SubText"
                        local scoreKey = Library.Theme[entry.Color or "Accent2"] and (entry.Color or "Accent2") or "Accent2"
                        visual.Row.LayoutOrder = index
                        visual.Row.BackgroundTransparency = highlighted and 0 or 0.22
                        visual.Rank.Text = tostring(index)
                        visual.Name.Text = tostring(entry.Name or "Player")
                        visual.Score.Text = tostring(entry.Score or 0)
                        Library.Registry[visual.Row]["BackgroundColor3"] = rowKey
                        Library.Registry[visual.Rank]["TextColor3"] = rankKey
                        Library.Registry[visual.Score]["TextColor3"] = scoreKey
                        visual.Row.BackgroundColor3 = Library.Theme[rowKey]
                        visual.Rank.TextColor3 = Library.Theme[rankKey]
                        visual.Score.TextColor3 = Library.Theme[scoreKey]
                    end
                end
                function controller:SetEntries(values)
                    for _, visual in pairs(visuals) do visual.Row:Destroy() end
                    entries = {}; visuals = {}
                    for _, value in ipairs(values or {}) do table.insert(entries, value) end
                    render(); return self
                end
                function controller:Update(name, values)
                    local target
                    for _, entry in ipairs(entries) do if tostring(entry.Name) == tostring(name) then target = entry break end end
                    if not target then target = {Name = tostring(name)}; table.insert(entries, target) end
                    for key, value in pairs(values or {}) do target[key] = value end
                    render(); return target
                end
                function controller:Remove(name)
                    for index, entry in ipairs(entries) do
                        if tostring(entry.Name) == tostring(name) then
                            if visuals[entry] then visuals[entry].Row:Destroy(); visuals[entry] = nil end
                            table.remove(entries, index); render(); return true
                        end
                    end
                    return false
                end
                function controller:GetEntries() return entries end
                controller:SetEntries(options.Entries or {})
                addElement({Holder = container, Text = tostring(options.Name or "Leaderboard") .. " scores ranking", Synonyms = options.Synonyms})
                return controller
            end

            function Section:CreateExecutionQueue(options)
                options = options or {}
                local items, byId, visuals = {}, {}, {}
                local height = tonumber(options.Height) or 220
                local container = Utility:Create("Frame", {Name = "ExecutionQueue", Parent = ContentContainer, BackgroundColor3 = Library.Theme.Surface, Size = UDim2.new(1, 0, 0, height), BorderSizePixel = 0, ClipsDescendants = true, ZIndex = 5})
                Utility:RegisterProperty(container, "BackgroundColor3", "Surface")
                Utility:Create("UICorner", {Parent = container, CornerRadius = UDim.new(0, 7)})
                local title = Utility:Create("TextLabel", {Parent = container, BackgroundTransparency = 1, Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -20, 0, 32), Text = tostring(options.Name or "Execution queue"), TextColor3 = Library.Theme.Text, Font = Enum.Font.GothamBold, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 7})
                Utility:RegisterProperty(title, "TextColor3", "Text")
                local body = Utility:Create("ScrollingFrame", {Parent = container, BackgroundTransparency = 1, Position = UDim2.fromOffset(7, 32), Size = UDim2.new(1, -14, 1, -39), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 2, ScrollBarImageColor3 = Library.Theme.Accent, BorderSizePixel = 0, ZIndex = 6})
                Utility:RegisterProperty(body, "ScrollBarImageColor3", "Accent")
                Utility:Create("UIListLayout", {Parent = body, Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder})
                local controller = finishController({Type = "ExecutionQueue"}, container, options.Name or "Execution queue", options.Tooltip)
                local statusColors = {Pending = "SubText", Running = "Accent2", Done = "Success", Error = "Error", Paused = "Warn", Waiting = "Warn"}
                local function updateVisual(item, animate)
                    local visual = visuals[item.Id]
                    if not visual then return end
                    local colorKey = statusColors[item.Status] or "SubText"
                    visual.State.Text = item.Status
                    Library.Registry[visual.Dot]["BackgroundColor3"] = colorKey
                    Library.Registry[visual.State]["TextColor3"] = colorKey
                    Library.Registry[visual.Fill]["BackgroundColor3"] = colorKey
                    visual.Dot.BackgroundColor3 = Library.Theme[colorKey]
                    visual.State.TextColor3 = Library.Theme[colorKey]
                    visual.Fill.BackgroundColor3 = Library.Theme[colorKey]
                    local size = UDim2.new(math.clamp(tonumber(item.Progress) or 0, 0, 1), 0, 1, 0)
                    if animate then Utility:Tween(visual.Fill, TweenInfo.new(0.14), {Size = size}) else visual.Fill.Size = size end
                end
                local function render()
                    for _, child in ipairs(body:GetChildren()) do if child.Name == "QueueRow" then child:Destroy() end end
                    table.clear(visuals)
                    for index, item in ipairs(items) do
                        local colorKey = statusColors[item.Status] or "SubText"
                        local row = Utility:Create("TextButton", {Name = "QueueRow", Parent = body, BackgroundColor3 = Library.Theme.Secondary, BackgroundTransparency = 0.18, Size = UDim2.new(1, -3, 0, 42), Text = "", AutoButtonColor = false, BorderSizePixel = 0, LayoutOrder = index, ZIndex = 7})
                        Utility:RegisterProperty(row, "BackgroundColor3", "Secondary")
                        Utility:Create("UICorner", {Parent = row, CornerRadius = UDim.new(0, 6)})
                        local dot = Utility:Create("Frame", {Parent = row, Position = UDim2.fromOffset(9, 10), Size = UDim2.fromOffset(7, 7), BackgroundColor3 = Library.Theme[colorKey], BorderSizePixel = 0, ZIndex = 8})
                        Utility:RegisterProperty(dot, "BackgroundColor3", colorKey)
                        Utility:Create("UICorner", {Parent = dot, CornerRadius = UDim.new(1, 0)})
                        local name = Utility:Create("TextLabel", {Parent = row, BackgroundTransparency = 1, Position = UDim2.fromOffset(23, 3), Size = UDim2.new(1, -92, 0, 20), Text = tostring(item.Name), TextColor3 = Library.Theme.Text, Font = Enum.Font.GothamMedium, TextSize = 9, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 8})
                        Utility:RegisterProperty(name, "TextColor3", "Text")
                        local state = Utility:Create("TextLabel", {Parent = row, BackgroundTransparency = 1, Position = UDim2.new(1, -66, 0, 3), Size = UDim2.fromOffset(56, 20), Text = item.Status, TextColor3 = Library.Theme[colorKey], Font = Enum.Font.GothamBold, TextSize = 8, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 8})
                        Utility:RegisterProperty(state, "TextColor3", colorKey)
                        local track = Utility:Create("Frame", {Parent = row, Position = UDim2.fromOffset(23, 29), Size = UDim2.new(1, -33, 0, 3), BackgroundColor3 = Library.Theme.SurfaceAlt, BorderSizePixel = 0, ZIndex = 8})
                        Utility:RegisterProperty(track, "BackgroundColor3", "SurfaceAlt")
                        Utility:Create("UICorner", {Parent = track, CornerRadius = UDim.new(1, 0)})
                        local fill = Utility:Create("Frame", {Parent = track, Size = UDim2.new(math.clamp(tonumber(item.Progress) or 0, 0, 1), 0, 1, 0), BackgroundColor3 = Library.Theme[colorKey], BorderSizePixel = 0, ZIndex = 9})
                        Utility:RegisterProperty(fill, "BackgroundColor3", colorKey)
                        Utility:Create("UICorner", {Parent = fill, CornerRadius = UDim.new(1, 0)})
                        visuals[item.Id] = {Dot = dot, State = state, Fill = fill}
                        Library:Connect(row.MouseButton1Click, function() Utility:SafeCall(options.Callback, item, controller) end)
                    end
                end
                function controller:Add(value)
                    value = value or {}
                    local id = normalizeActionId(value.Id or value.Name or (#items + 1))
                    if byId[id] then return byId[id] end
                    local item = {Id = id, Name = tostring(value.Name or id), Status = tostring(value.Status or "Pending"):gsub("^%l", string.upper), Progress = math.clamp(tonumber(value.Progress) or 0, 0, 1)}
                    table.insert(items, item); byId[id] = item; render(); return item
                end
                function controller:SetStatus(id, status, progress)
                    local item = byId[normalizeActionId(id)]
                    if not item then return false end
                    item.Status = tostring(status or "Pending"):gsub("^%l", string.upper)
                    if progress ~= nil then item.Progress = math.clamp(tonumber(progress) or 0, 0, 1) end
                    updateVisual(item, true); return true
                end
                function controller:SetProgress(id, progress) local item = byId[normalizeActionId(id)]; if not item then return false end item.Progress = math.clamp(tonumber(progress) or 0, 0, 1); updateVisual(item, true); return true end
                function controller:Remove(id)
                    id = normalizeActionId(id); local item = byId[id]; if not item then return false end
                    byId[id] = nil; for index, candidate in ipairs(items) do if candidate == item then table.remove(items, index) break end end
                    render(); return true
                end
                function controller:GetItems() return items end
                function controller:Reset() for _, item in ipairs(items) do item.Status = "Pending"; item.Progress = 0; updateVisual(item, false) end return true end
                for _, item in ipairs(options.Items or {}) do controller:Add(item) end
                render()
                addElement({Holder = container, Text = tostring(options.Name or "Execution queue") .. " tasks jobs", Synonyms = options.Synonyms})
                return controller
            end


--[[ MODULE: 90_tabbox.part.lua ]]
-- Module fragment: tabbox and advanced controls
-- Generated from the working V7 baseline; edit this feature in isolation.
            -- TABBOX (minitabs)
            function Section:CreateTabbox()
                local tabboxContainer = Utility:Create("Frame", {
                    Parent = ContentContainer,
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, 0),
                    ZIndex = 5,
                    BorderSizePixel = 0
                })
                local buttonBar = Utility:Create("Frame", {
                    Parent = tabboxContainer,
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, 30),
                    ZIndex = 6
                })
                local buttonLayout = Utility:Create("UIListLayout", {
                    Parent = buttonBar,
                    FillDirection = Enum.FillDirection.Horizontal,
                    HorizontalAlignment = Enum.HorizontalAlignment.Left,
                    Padding = UDim.new(0, 4)
                })
                local contentArea = Utility:Create("Frame", {
                    Parent = tabboxContainer,
                    BackgroundTransparency = 1,
                    Position = UDim2.new(0, 0, 0, 34),
                    Size = UDim2.new(1, 0, 1, -34),
                    ZIndex = 6,
                    ClipsDescendants = true
                })
                local tabs = {}
                local activeTab = nil

                local function resize()
                    local totalHeight = 34 + (activeTab and activeTab.ContentSize or 0)
                    tabboxContainer.Size = UDim2.new(1, 0, 0, totalHeight)
                    RefreshLayout()
                end

                local tabbox = {
                    AddTab = function(self, tabName, contentBuilder)
                        local btn = Utility:Create("TextButton", {
                            Parent = buttonBar,
                            BackgroundColor3 = Library.Theme.Surface,
                            Size = UDim2.new(0, 80, 1, 0),
                            Text = tabName,
                            TextColor3 = Library.Theme.Text,
                            Font = Enum.Font.GothamBold,
                            TextSize = 12,
                            AutoButtonColor = false,
                            ZIndex = 7
                        })
                        Utility:RegisterProperty(btn, "BackgroundColor3", "Surface")
                        Utility:RegisterProperty(btn, "TextColor3", "Text")
                        Utility:Create("UICorner", {CornerRadius = UDim.new(0, 4), Parent = btn})
                        local content = Utility:Create("Frame", {
                            Parent = contentArea,
                            BackgroundTransparency = 1,
                            Size = UDim2.new(1, 0, 1, 0),
                            Visible = false,
                            ZIndex = 7
                        })
                        local tab = { Button = btn, Content = content, ContentSize = 0, Built = false }
                        table.insert(tabs, tab)
                        local function activate()
                            for _, t in ipairs(tabs) do
                                t.Content.Visible = false
                                t.Button.BackgroundColor3 = Library.Theme.Surface
                                t.Button.TextColor3 = Library.Theme.Text
                            end
                            content.Visible = true
                            btn.BackgroundColor3 = Library.Theme.Accent
                            btn.TextColor3 = Color3.new(1, 1, 1)
                            activeTab = tab
                            if contentBuilder and not tab.Built then
                                tab.Built = true
                                Utility:SafeCall(contentBuilder, content)
                            end
                            local list = content:FindFirstChildWhichIsA("UIListLayout")
                            if list then
                                tab.ContentSize = list.AbsoluteContentSize.Y
                            else
                                tab.ContentSize = content.AbsoluteSize.Y
                            end
                            resize()
                        end
                        Library:Connect(btn.MouseButton1Click, activate)
                        if #tabs == 1 then task.defer(activate) end
                        return content
                    end
                }
                addElement({Holder = tabboxContainer})
                return tabbox
            end

            return Section
        end

        return Tab
    end

    function Window:CreateDashboard(options)
        options = options or {}
        local dashboardTab = Window:CreateTab({
            Name = options.Name or "Overview",
            Icon = options.Icon or ICONS.Dashboard,
            IsOverview = options.IsNative == true
        })
        local heroHeight = IsMobile and 118 or 132
        local hero = Utility:Create("Frame", {
            Name = "DashboardHero", Parent = dashboardTab.Page,
            BackgroundColor3 = Library.Theme.Surface, BackgroundTransparency = 0,
            Position = UDim2.fromOffset(0, 0), Size = UDim2.new(1, -4, 0, heroHeight),
            BorderSizePixel = 0, ClipsDescendants = true, ZIndex = 3
        })
        Utility:RegisterProperty(hero, "BackgroundColor3", "Surface")
        Utility:RegisterMaterial(hero, 0.28, 0)
        Utility:Create("UICorner", {CornerRadius = UDim.new(0, 13), Parent = hero})
        local heroStroke = Utility:Create("UIStroke", {Parent = hero, Color = Library.Theme.Stroke, Thickness = 1})
        Utility:RegisterProperty(heroStroke, "Color", "Stroke")
        local heroGradient = Utility:Create("UIGradient", {Parent = hero, Rotation = 12})
        Utility:RegisterGradient(heroGradient, "SurfaceAlt", "Surface", "Main")
        local heroRail = Utility:Create("Frame", {
            Parent = hero, BackgroundColor3 = Library.Theme.Accent,
            Size = UDim2.new(1, 0, 0, 3), BorderSizePixel = 0, ZIndex = 4
        })
        Utility:RegisterProperty(heroRail, "BackgroundColor3", "Accent")
        local heroRailGradient = Utility:Create("UIGradient", {Parent = heroRail})
        Utility:RegisterGradient(heroRailGradient, "Accent", "Accent2", "Accent3")

        local avatar = Utility:Create("ImageLabel", {
            Parent = hero, BackgroundColor3 = Library.Theme.Main,
            Position = UDim2.fromOffset(20, 20), Size = UDim2.fromOffset(88, 88),
            Image = Utility:NormalizeAssetId(options.Avatar, ICONS.Profile),
            ScaleType = Enum.ScaleType.Crop, BorderSizePixel = 0, ZIndex = 5
        })
        Utility:RegisterProperty(avatar, "BackgroundColor3", "Main")
        Utility:Create("UICorner", {CornerRadius = UDim.new(0, 13), Parent = avatar})
        local avatarStroke = Utility:Create("UIStroke", {Parent = avatar, Color = Library.Theme.Accent, Thickness = 1})
        Utility:RegisterProperty(avatarStroke, "Color", "Accent")

        local greeting = Utility:Create("TextLabel", {
            Parent = hero, BackgroundTransparency = 1, Position = UDim2.fromOffset(128, 31),
            Size = UDim2.new(1, -156, 0, 30), Font = Enum.Font.GothamBold,
            Text = tostring(options.Greeting or ("Welcome, " .. (Plr.DisplayName or Plr.Name))),
            TextColor3 = Library.Theme.Text, TextSize = 22, TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 5
        })
        Utility:RegisterProperty(greeting, "TextColor3", "Text")
        local subtitle = Utility:Create("TextLabel", {
            Parent = hero, BackgroundTransparency = 1, Position = UDim2.fromOffset(128, 63),
            Size = UDim2.new(1, -156, 0, 22), Font = Enum.Font.Gotham,
            Text = tostring(options.Subtitle or ("Your control center · @" .. Plr.Name)),
            TextColor3 = Library.Theme.SubText, TextSize = 13,
            TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 5
        })
        Utility:RegisterProperty(subtitle, "TextColor3", "SubText")
        if not Utility:NormalizeAssetId(options.Avatar) then
            task.spawn(function()
                local ok, image = pcall(function()
                    return Players:GetUserThumbnailAsync(tonumber(options.UserId) or Plr.UserId, Enum.ThumbnailType.AvatarBust, Enum.ThumbnailSize.Size180x180)
                end)
                if ok and avatar.Parent then avatar.Image = image end
            end)
        end

        dashboardTab:SetHeader(hero, heroHeight + 12)
        dashboardTab:OnResponsive(function(mobile)
            heroHeight = mobile and 112 or 132
            hero.Size = UDim2.new(1, -4, 0, heroHeight)
            avatar.Position = mobile and UDim2.fromOffset(14, 20) or UDim2.fromOffset(20, 20)
            avatar.Size = mobile and UDim2.fromOffset(58, 58) or UDim2.fromOffset(88, 88)
            greeting.Position = mobile and UDim2.fromOffset(84, 24) or UDim2.fromOffset(128, 31)
            greeting.Size = mobile and UDim2.new(1, -98, 0, 26) or UDim2.new(1, -156, 0, 30)
            greeting.TextSize = mobile and 17 or 22
            subtitle.Position = mobile and UDim2.fromOffset(84, 51) or UDim2.fromOffset(128, 63)
            subtitle.Size = mobile and UDim2.new(1, -98, 0, 34) or UDim2.new(1, -156, 0, 22)
            subtitle.TextWrapped = mobile
            dashboardTab:SetHeader(hero, heroHeight + 12)
        end)

        local dashboard = {Tab = dashboardTab, Hero = hero, Cards = {}}
        function dashboard:AddCard(cardOptions)
            cardOptions = cardOptions or {}
            local section = dashboardTab:CreateSection({
                Name = cardOptions.Name or "Card",
                Side = cardOptions.Side or "Auto",
                Icon = cardOptions.Icon
            })
            if cardOptions.Description then
                section:CreateParagraph({Content = cardOptions.Description})
            end
            for _, metric in ipairs(cardOptions.Metrics or {}) do
                section:CreateMetric(metric)
            end
            if cardOptions.Action then
                section:CreateButton({
                    Name = cardOptions.Action.Name or "Open",
                    Description = cardOptions.Action.Description,
                    Icon = cardOptions.Action.Icon,
                    Callback = cardOptions.Action.Callback
                })
            end
            table.insert(self.Cards, section)
            return section
        end
        function dashboard:SetGreeting(text) greeting.Text = tostring(text) end
        function dashboard:SetSubtitle(text) subtitle.Text = tostring(text) end
        function dashboard:SetAvatar(asset) avatar.Image = Utility:NormalizeAssetId(asset, avatar.Image) end
        for _, card in ipairs(options.Cards or {}) do dashboard:AddCard(card) end
        return dashboard
    end

    -- Native Overview is always available directly above UI Settings. It is

--[[ MODULE: 91_native_settings.part.lua ]]
-- Module fragment: native overview and settings
-- Generated from the working V7 baseline; edit this feature in isolation.
    -- intentionally created after user-navigation plumbing but outside the
    -- scrollable tab list, so scripts cannot accidentally push it offscreen.
    local NativeOverview = Window:CreateDashboard({
        Name = "Overview",
        IsNative = true,
        Greeting = "Welcome, " .. (Plr.DisplayName or Plr.Name),
        Subtitle = "RenLib session · @" .. Plr.Name,
        Cards = {
            {
                Name = "RenCore launcher",
                Side = "Left",
                Icon = ICONS.Play,
                Description = "Close this RenLib session and return to the official RenCore script selector.",
                Action = {
                    Name = "Relaunch RenCore",
                    Description = "Unload this interface, then start the official RenCore loader.",
                    Icon = ICONS.Restore,
                    Callback = function()
                        Window:Dialog({
                            Title = "Relaunch RenCore?",
                            Content = "RenLib will close this interface and start the official RenCore selector.",
                            Actions = {
                                {Name = "Cancel"},
                                {Name = "Relaunch", Primary = true, Callback = function()
                                    Library:RelaunchRenCore(options.BeforeRelaunch)
                                end}
                            }
                        })
                    end
                }
            },
            {
                Name = "Session",
                Side = "Right",
                Icon = ICONS.Dashboard,
                Metrics = {
                    {Name = "Library", Value = "V" .. Library.Version, Detail = "Current RenLib release"},
                    {Name = "Device", Value = Library.DeviceMode, Detail = "Responsive layout mode"},
                    {Name = "Material", Value = Library.MaterialMode, Detail = "Current window material"}
                }
            }
        }
    })
    Window.OverviewTab = NativeOverview.Tab

    -- Create Settings Tab
    local SettingsTab = Window:CreateTab({
        Name = "UI Settings",
        Emoji = EMOJIS.Settings,
        IsSettings = true
    })
    Window.SettingsTab = SettingsTab

    task.defer(function()
        if not Library.Unloaded and not Window.ActiveTab and Window.OverviewTab then
            Window.OverviewTab:Activate()
        end
    end)

    local UISection = SettingsTab:CreateSection({ Name = "UI Controls", Side = "Left" })
    if not IsMobile then
        UISection:CreateLabel("Toggle UI Key: " .. Library.ToggleKey.Name)
        UISection:CreateButton({
            Name = "Change Toggle Key",
            Callback = function()
                Library:Notify({ Title = "Press Any Key", Content = "Press a key to set as toggle...", Emoji = "⌨️", Duration = 5 })
                local conn
                conn = Library:Connect(UserInputService.InputBegan, function(input)
                    if input.UserInputType == Enum.UserInputType.Keyboard then
                        Library.ToggleKey = input.KeyCode
                        Library:Notify({ Title = "Success", Content = "Toggle key set to: " .. input.KeyCode.Name, Emoji = EMOJIS.Success })
                        conn:Disconnect()
                    end
                end)
            end
        })
    else
        UISection:CreateLabel("Tap the floating RenCore button to toggle UI")
    end
    UISection:CreateButton({ Name = "Minimize UI", Icon = ICONS.Minimize, Callback = function() Window:Minimize() end })
    UISection:CreateButton({ Name = "Close UI", Icon = ICONS.Close, Callback = function() Window:Close() end })

    local AppearanceSection = SettingsTab:CreateSection({ Name = "Appearance & motion", Side = "Right" })
    AppearanceSection:CreateDropdown({
        Name = "Theme preset",
        Values = {"Midnight", "Nebula", "Celestial", "Rose", "Aurora", "Ember", "Prism Frost", "Moss Archive", "Velvet Latte"},
        Default = Library.ActiveTheme or "Midnight",
        Flag = "__RenLibTheme",
        Callback = function(theme)
            Library:ApplyThemePreset(theme)
        end
    })
    AppearanceSection:CreateDropdown({
        Name = "Window material",
        Values = {"Solid", "Frosted"},
        Default = Library.MaterialMode,
        Flag = "__RenLibMaterial",
        Callback = function(mode)
            Library:SetMaterialMode(mode)
        end
    })
    AppearanceSection:CreateSlider({
        Name = "Glass transparency",
        Min = 0,
        Max = 32,
        Step = 2,
        Default = Library.MaterialIntensity,
        Flag = "__RenLibFrostIntensity",
        CallbackMode = "Release",
        Callback = function(value) Library:SetMaterialIntensity(value) end
    })
    local ScaleSlider = AppearanceSection:CreateSlider({
        Name = "UI scale",
        Min = 100,
        Max = 150,
        Step = 5,
        Default = math.floor(Library.DPIScale * 100),
        Flag = "__RenLibScale",
        CallbackMode = "Release",
        Callback = function(scale)
            task.defer(function() Library:PreviewDPIScale(scale, 10) end)
        end
    })
    AppearanceSection:CreateButton({
        Name = "Reset UI size",
        Description = "Preview the safe 100% size with the same 10-second recovery.",
        Icon = ICONS.Restore,
        Callback = function()
            ScaleSlider:SetSilent(100)
            Library:PreviewDPIScale(100, 10)
        end
    })
    AppearanceSection:CreateToggle({
        Name = "Reduced motion",
        Default = Library.ReducedMotion,
        Flag = "__RenLibReducedMotion",
        Callback = function(enabled) Library:SetReducedMotion(enabled) end
    })
    AppearanceSection:CreateParagraph({
        Title = "Responsive by default",
        Content = "RenLib reflows from the UI's real visible width, so small scales and phones use one safe column. Frosted material is local to the RenLib window and never changes the game screen."
    })

    local UtilitySection = SettingsTab:CreateSection({ Name = "Utilities", Side = "Right" })
    UtilitySection:CreateButton({
        Name = "Keybind manager",
        Description = "Review, edit, or reset every registered shortcut in one place.",
        Icon = ICONS.Menu,
        Callback = function() Window:ShowKeybindManager() end
    })
    if options.ShowInfiniteYield == nil or options.ShowInfiniteYield then
        UtilitySection:CreateButton({
            Name = "Launch Infinite Yield",
            Description = "Fetch the current official EdgeIY source after confirmation.",
            Icon = ICONS.Play,
            Callback = function()
                Window:Dialog({
                    Title = "Launch Infinite Yield?",
                    Content = "This downloads and runs the current script directly from the official EdgeIY/infiniteyield repository.",
                    Actions = {
                        {Name = "Cancel"},
                        {Name = "Launch", Primary = true, Callback = function() Library:LaunchInfiniteYield() end}
                    }
                })
            end
        })
    end

    local ConfigSection = SettingsTab:CreateSection({ Name = "Configuration", Side = "Left" })
    ConfigSection:CreateParagraph({
        Title = Library.PersistenceAvailable and "Persistent storage" or "Session storage",
        Content = Library.PersistenceAvailable
            and "Configs are saved to the executor filesystem."
            or "This executor blocks file APIs. Configs still work, but reset when the Roblox client closes."
    })
    local configNames = Library:GetConfigList()
    local selectedConfig = configNames[1]
    local desiredConfigName = selectedConfig or "default"
    local ConfigDropdown, AutoloadStatus

    local function hasConfig(name, values)
        for _, item in ipairs(values or {}) do if item == name then return true end end
        return false
    end

    local function refreshConfigManager(preferred)
        configNames = Library:GetConfigList()
        local target
        if preferred and hasConfig(preferred, configNames) then
            target = preferred
        elseif hasConfig(selectedConfig, configNames) then
            target = selectedConfig
        else
            target = configNames[1]
        end
        if ConfigDropdown then
            ConfigDropdown:Refresh(configNames)
            selectedConfig = target
            if target then ConfigDropdown:Set(target) end
        else
            selectedConfig = target
        end
        if AutoloadStatus then
            AutoloadStatus:SetContent(Library:GetAutoloadConfigName() or "None")
        end
    end

    ConfigDropdown = ConfigSection:CreateDropdown({
        Name = "Saved configs",
        Values = configNames,
        Default = selectedConfig,
        Flag = "__RenLibConfigSelection",
        Callback = function(value) selectedConfig = value end
    })
    ConfigSection:CreateInput({
        Name = "Config name / rename target",
        Default = desiredConfigName,
        Placeholder = "default",
        Flag = "__RenLibConfigName",
        Callback = function(value) desiredConfigName = cleanConfigName(value) end
    })
    AutoloadStatus = ConfigSection:CreateParagraph({
        Title = "Current autoload",
        Content = Library:GetAutoloadConfigName() or "None"
    })
    ConfigSection:CreateButton({Name = "Save or overwrite", Callback = function()
        local ok, err = Library:SaveConfig(desiredConfigName)
        if ok then selectedConfig = desiredConfigName; refreshConfigManager(desiredConfigName) end
        local savedTitle = Library.PersistenceAvailable and "Config saved" or "Config saved for session"
        Library:Notify({Title = ok and savedTitle or "Save failed", Content = ok and desiredConfigName or tostring(err), Duration = 3})
    end})
    ConfigSection:CreateButton({Name = "Load selected", Callback = function()
        if not selectedConfig then
            Library:Notify({Title = "No config selected", Content = "Save or select a config first.", Duration = 3})
            return
        end
        local ok, err = Library:LoadConfig(selectedConfig)
        Library:Notify({Title = ok and "Config loaded" or "Load failed", Content = ok and selectedConfig or tostring(err), Duration = 3})
    end})
    ConfigSection:CreateButton({Name = "Rename selected", Callback = function()
        if not selectedConfig then
            Library:Notify({Title = "No config selected", Content = "Choose a saved config first.", Duration = 3})
            return
        end
        local oldName = selectedConfig
        local ok, err = Library:RenameConfig(oldName, desiredConfigName)
        if ok then selectedConfig = desiredConfigName; refreshConfigManager(desiredConfigName) end
        Library:Notify({Title = ok and "Config renamed" or "Rename failed", Content = ok and (oldName .. " → " .. desiredConfigName) or tostring(err), Duration = 3})
    end})
    ConfigSection:CreateButton({Name = "Set selected as autoload", Callback = function()
        if not selectedConfig then
            Library:Notify({Title = "No config selected", Content = "Choose a saved config first.", Duration = 3})
            return
        end
        local ok, err = Library:SetAutoloadConfig(selectedConfig)
        refreshConfigManager(selectedConfig)
        local autoloadTitle = Library.PersistenceAvailable and "Autoload set" or "Session autoload set"
        Library:Notify({Title = ok and autoloadTitle or "Autoload unavailable", Content = ok and selectedConfig or tostring(err), Duration = 3})
    end})
    ConfigSection:CreateButton({Name = "Delete selected", Icon = EMOJIS.Trash, Callback = function()
        if not selectedConfig then
            Library:Notify({Title = "No config selected", Content = "Choose a saved config first.", Duration = 3})
            return
        end
        local deleting = selectedConfig
        Window:Dialog({
            Title = "Delete " .. deleting .. "?",
            Content = "This permanently removes the saved config. Its autoload link will also be cleared.",
            Actions = {
                {Name = "Cancel"},
                {Name = "Delete", Primary = true, Callback = function()
                    local ok, err = Library:DeleteConfig(deleting)
                    if ok then selectedConfig = nil; refreshConfigManager() end
                    Library:Notify({Title = ok and "Config deleted" or "Delete failed", Content = ok and deleting or tostring(err), Duration = 3})
                end}
            }
        })
    end})
    ConfigSection:CreateButton({Name = "Clear autoload", Callback = function()
        local ok, err = Library:ClearAutoloadConfig()
        refreshConfigManager(selectedConfig)
        Library:Notify({Title = ok and "Autoload cleared" or "Clear failed", Content = ok and "No config will load automatically." or tostring(err), Duration = 3})
    end})
    ConfigSection:CreateButton({Name = "Refresh config list", Icon = EMOJIS.Refresh, Callback = function()
        refreshConfigManager(selectedConfig)
    end})

    Library:Connect(SettingsBtn.MouseButton1Click, function()
        if SettingsTab then
            SettingsTab:Activate()
        end
    end)

    function Window:SetSectionSpacing(value)
        local spacing = math.clamp(tonumber(value) or 5, 0, 24)
        self.ContentSpacing = spacing
        for _, tab in ipairs(self.Tabs) do
            for _, section in ipairs(tab.Sections or {}) do
                if section.SetSpacing then section:SetSpacing(spacing) end
            end
        end
        return self
    end

    function Window:SetSectionOutlines(value)
        for _, tab in ipairs(self.Tabs) do
            for _, section in ipairs(tab.Sections or {}) do
                if section.SetOutlineVisible then section:SetOutlineVisible(value) end
            end
        end
        return self
    end

    function Window:SetContentDensity(value)
        local name = tostring(value or "Compact")
        local spacing = ({Tight = 2, Compact = 5, Comfortable = 8})[name]
        if not spacing then return false, "Unknown density: " .. name end
        self.ContentDensity = name
        self:SetSectionSpacing(spacing)
        return true
    end

    Library.Window = Window
    return Window
end


--[[ MODULE: 99_lifecycle.part.lua ]]
-- Module fragment: unload and startup lifecycle
-- Generated from the working V7 baseline; edit this feature in isolation.
--// UNLOAD
function Library:Unload(reason)
    if self.Unloaded then return end
    self.Unloaded = true
    self.ScalePreview = nil
    for index = #self.ESPManagers, 1, -1 do
        local manager = self.ESPManagers[index]
        if manager and manager.Destroy then manager:Destroy() end
    end
    for index = #self.AddonOrder, 1, -1 do
        self:UnregisterAddon(self.AddonOrder[index])
    end
    for _, tween in pairs(self.ActiveTweens) do
        pcall(function() tween:Cancel() end)
    end
    for _, tween in pairs(self.LayoutTweens) do
        pcall(function() tween:Cancel() end)
    end
    for _, tween in pairs(self.VisibilityTweens) do
        pcall(function() tween:Cancel() end)
    end
    for _, conn in pairs(Library.Connections) do
        pcall(function() conn:Disconnect() end)
    end
    if Library.ScreenGui then
        Library.ScreenGui:Destroy()
    end
    table.clear(self.Connections)
    table.clear(self.Registry)
    table.clear(self.GradientRegistry)
    table.clear(self.MaterialRegistry)
    table.clear(self.MaterialDecorations)
    table.clear(self.BrandMarks)
    table.clear(self.Scales)
    table.clear(self.Options)
    table.clear(self.KeybindList)
    table.clear(self.KeybindDefaults)
    table.clear(self.PendingAutoloadFlags)
    table.clear(self.ESPManagers)
    table.clear(self.LayoutTweens)
    table.clear(self.VisibilityTweens)
    self.Window = nil
    self.KeybindManager = nil
    self.ScreenGui = nil
    if RuntimeEnvironment[RUNTIME_KEY] == self then RuntimeEnvironment[RUNTIME_KEY] = nil end
    print("[RenLib] Unloaded" .. (reason and (" (" .. tostring(reason) .. ")") or ""))
end

--// TOGGLE KEY (PC only)
local inputOk, inputErr = pcall(function()
    Library:Connect(UserInputService.InputBegan, function(input, gpe)
        if gpe then return end
        if input.KeyCode == Library.ToggleKey then
            if input.KeyCode == Enum.KeyCode.K
                and (UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)) then return end
            if Library.Window then Library.Window:Toggle() end
        end
    end)
end)
if not inputOk then
    warn("[RenLib] Input initialization failed: " .. tostring(inputErr))
end

local runtimeOk, runtimeErr = pcall(function()
    RuntimeEnvironment[RUNTIME_KEY] = Library
end)
if not runtimeOk then
    warn("[RenLib] Runtime registration failed: " .. tostring(runtimeErr))
end

local filesystemOk, filesystemReady = pcall(ensureConfigFolders)
if not filesystemOk then
    warn("[RenLib] Filesystem initialization failed: " .. tostring(filesystemReady))
elseif filesystemReady then
    local autoloadOk, autoloadErr = pcall(function()
        Library:PrepareAutoloadConfig()
    end)
    if not autoloadOk then
        warn("[RenLib] Autoload initialization failed: " .. tostring(autoloadErr))
    end
end

print("[RenLib] Loaded - Version " .. Library.Version .. " (" .. Library.DeviceMode .. ")")

return Library

    end)()
    Runtime.RenLib = RenLib
    local Window = RenLib:CreateWindow({
        Name = "Blox Fruit Script • Sea " .. tostring(Sea),
        Width = 940,
        Height = 640,
        Icon = "9080449299",
        ShowUserProfile = true,
        ProfileUserId = LocalPlayer.UserId,
        ProfileSubtitle = "Automation ready",
        EnableGlobalSearch = true,
        EnableSidebarResize = true,
        SidebarMode = "Dynamic",
        MaterialMode = "Frosted",
        MaterialIntensity = 18,
        ShowInfiniteYield = false,
        BeforeRelaunch = API.StopAll,
    })
    Runtime.Window = Window

    local function uniqueLevelEnemies()
        local output, seen = {}, {}
        for _, row in ipairs(LEVEL_DATA[Sea]) do
            if not seen[row.Enemy] then
                seen[row.Enemy] = true
                output[#output + 1] = row.Enemy
            end
        end
        table.sort(output)
        return output
    end

    local function toggle(section, name, key, tooltip)
        local control = section:CreateToggle({
            Name = name,
            Flag = key,
            Default = Settings[key],
            Tooltip = tooltip,
            Callback = function(value) API.Set(key, value) end,
        })
        Runtime.UIControls[key] = Runtime.UIControls[key] or {}
        table.insert(Runtime.UIControls[key], control)
        return control
    end

    local StatusTab = Window:CreateTab({Name = "Status & Server", Icon = "6031280882"})
    local PlayerStatus = StatusTab:CreateSection({Name = "Player status", Side = "Left"})
    local StatusIdentity = PlayerStatus:CreateParagraph({Title = "Account", Content = LocalPlayer.Name})
    local StatusProgress = PlayerStatus:CreateParagraph({Title = "Progress", Content = "Loading..."})
    local StatusAutomation = PlayerStatus:CreateParagraph({Title = "Automation", Content = "Idle"})
    local ServerStatus = StatusTab:CreateSection({Name = "Server", Side = "Right"})
    local StatusServer = ServerStatus:CreateParagraph({Title = "Current server", Content = game.JobId})
    ServerStatus:CreateButton({Name = "Copy server JobId", Callback = function() if type(setclipboard) == "function" then pcall(setclipboard, game.JobId) end end})
    ServerStatus:CreateInput({Name = "Server Job ID", Default = Settings.JoinJobId, Flag = "JoinJobId", Finished = true, Callback = function(value) API.Set("JoinJobId", value) end})
    ServerStatus:CreateButton({Name = "Join server by Job ID", Callback = function()
        local ok, err = joinServerJobId(Settings.JoinJobId)
        if not ok then RenLib:Notify({Title = "Join failed", Content = tostring(err), Duration = 5}) end
    end})
    ServerStatus:CreateButton({Name = "Rejoin server", Callback = function() TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer) end})
    ServerStatus:CreateButton({Name = "Hop to lowest players", Callback = function() local ok, err = hopServer(false); if not ok then RenLib:Notify({Title = "Server hop failed", Content = tostring(err), Duration = 5}) end end})
    ServerStatus:CreateButton({Name = "Hop to lowest ping", Callback = function() local ok, err = hopServer(true); if not ok then RenLib:Notify({Title = "Server hop failed", Content = tostring(err), Duration = 5}) end end})
    task.spawn(function()
        local started = os.clock()
        while Runtime.Alive do
            local data = LocalPlayer:FindFirstChild("Data")
            local level = data and data:FindFirstChild("Level")
            local target = Runtime.CurrentTarget
            pcall(StatusIdentity.SetContent, StatusIdentity, string.format("%s  •  %s", LocalPlayer.DisplayName, LocalPlayer.Name))
            pcall(StatusProgress.SetContent, StatusProgress, string.format("Sea %d  •  Level %s  •  fruits:%d chests:%d berries:%d", Sea, level and tostring(level.Value) or "?", (function() local n=0 for _ in pairs(WorldFruits) do n+=1 end return n end)(), (function() local n=0 for _ in pairs(Runtime.Chests) do n+=1 end return n end)(), (function() local n=0 for _ in pairs(Runtime.Berries) do n+=1 end return n end)()))
            pcall(StatusAutomation.SetContent, StatusAutomation, string.format("%s  •  target:%s  •  %s  •  recoveries:%d", Runtime.PickupKind or Runtime.CurrentMode, target and target.Name or "none", Runtime.CombatTransport, Runtime.RecoveryCount))
            pcall(StatusServer.SetContent, StatusServer, string.format("%d/%d players  •  uptime %dm  •  %s", #Players:GetPlayers(), Players.MaxPlayers, math.floor((os.clock() - started) / 60), game.JobId))
            task.wait(0.75)
        end
    end)

    local Farming = Window:CreateTab({Name = "Main Farm", Icon = "9080449299"})
    local MainFarm = Farming:CreateSection({Name = "Main farming", Side = "Left"})
    toggle(MainFarm, "Auto farm level", "AutoFarmLevel", "Uses the current sea level map and quests.")
    toggle(MainFarm, "Auto farm nearest", "AutoFarmNearest", "Useful for unlabelled waves and humanoid trial enemies.")
    MainFarm:CreateDropdown({
        Name = "Weapon category",
        Values = {"Melee", "Sword", "Blox Fruit", "Gun"},
        Default = Settings.WeaponCategory,
        Flag = "WeaponCategory",
        Callback = function(value) API.Set("WeaponCategory", value) end,
    })
    MainFarm:CreateDropdown({
        Name = "Attack cadence",
        Values = {"Normal Attack", "Fast Attack", "Super Fast Attack", "Instant"},
        Default = Settings.AttackMode,
        Flag = "AttackMode",
        Callback = function(value) API.Set("AttackMode", value) end,
    })
    toggle(MainFarm, "Accept level quests", "AcceptLevelQuests")

    local MobFarm = Farming:CreateSection({Name = "Mob and boss", Side = "Right"})
    MobFarm:CreateDropdown({
        Name = "Selected mob",
        Values = uniqueLevelEnemies(),
        Default = Settings.SelectedMob,
        Flag = "SelectedMob",
        Callback = function(value) API.Set("SelectedMob", value) end,
    })
    toggle(MobFarm, "Auto kill selected mob", "AutoKillMob")
    Runtime.BossDropdown = MobFarm:CreateDropdown({
        Name = "Selected boss",
        Values = currentBossNames(),
        Default = Settings.SelectedBoss,
        Flag = "SelectedBoss",
        Callback = function(value) API.Set("SelectedBoss", value) end,
    })
    toggle(MobFarm, "Auto farm selected boss", "AutoFarmBoss")
    toggle(MobFarm, "Accept boss quests", "AcceptBossQuests")
    toggle(MobFarm, "Auto farm all bosses", "AutoFarmAllBoss")
    toggle(MobFarm, "Auto refresh boss list", "AutoRefreshBossList", "Refreshes from both the sea metadata and newly spawned live boss models.")
    MobFarm:CreateButton({Name = "Refresh boss list now", Callback = function() Runtime.BossDropdown:Refresh(currentBossNames()) end})

    local Combat = Farming:CreateSection({Name = "Fixed anchor and hitbox", Side = "Left"})
    toggle(Combat, "Bring mobs", "BringMobs", "Freezes and brings same-name enemies to one fixed anchor.")
    toggle(Combat, "Fast target collector", "FastAttack")
    toggle(Combat, "Activate equipped tool", "ActivateTool")
    Combat:CreateSlider({Name = "Hitbox size", Min = 8, Max = 100, Step = 1, Default = Settings.HitboxSize, Flag = "HitboxSize", Callback = function(value) API.Set("HitboxSize", value) end})
    Combat:CreateSlider({Name = "Height above anchor", Min = 16, Max = 50, Step = 1, Default = Settings.Height, Flag = "CombatHeightV3", Tooltip = "The tokenized/legacy transports support the original above-mob farming position.", Callback = function(value) API.Set("Height", math.max(16, value)) end})
    Combat:CreateSlider({Name = "Tween speed", Min = 5, Max = 600, Step = 1, Default = Settings.TweenSpeed, Flag = "TweenSpeed", Tooltip = "Default 300 with the full proven 5–600 movement range.", Callback = function(value) API.Set("TweenSpeed", value) end})
    Combat:CreateInput({Name = "Exact tween speed", Default = tostring(Settings.TweenSpeed), Flag = "TweenSpeedExact", Numeric = true, Finished = true, Callback = function(value) API.Set("TweenSpeed", value) end})
    Combat:CreateButton({Name = "Stop every automation", Callback = API.StopAll})
    Combat:CreateButton({Name = "Force release character", Callback = forceReleaseAutomation})
    Combat:CreateButton({
        Name = "Show combat diagnostics",
        Callback = function()
            RenLib:Notify({
                Title = "Combat diagnostics",
                Content = string.format("%s | token:%s | attempts:%d | damage:%d | targets:%d | batch:%d | pickup:%s", Runtime.CombatTransport, Runtime.CombatToken and "yes" or "no", Runtime.AttackAttempts, Runtime.DamageRegistrations, #Runtime.FastTargets, Runtime.LastBatchSize, Runtime.PickupKind or "none"),
                Duration = 8,
            })
        end,
    })
    Combat:CreateButton({
        Name = "Show navigation diagnostics",
        Callback = function()
            local function positionText(value)
                local position = typeof(value) == "CFrame" and value.Position
                    or (typeof(value) == "Vector3" and value)
                if not position then return "none" end
                return string.format("%.0f,%.0f,%.0f", position.X, position.Y, position.Z)
            end
            local _, _, root = characterParts()
            RenLib:Notify({
                Title = "Navigation diagnostics",
                Content = string.format(
                    "mode:%s | player:%s | goal:%s | anchor:%s | target:%s | rejected:%d (%s)",
                    tostring(activeFarmMode() or "none"),
                    positionText(root and root.Position),
                    positionText(Runtime.MovementGoal),
                    positionText(Runtime.FarmAnchor),
                    Runtime.CurrentTarget and Runtime.CurrentTarget.Name or "none",
                    Runtime.NavigationRejectCount,
                    Runtime.LastRejectedNavigation or "none"
                ),
                Duration = 12,
            })
        end,
    })

    local Skills = Farming:CreateSection({Name = "Combat skills", Side = "Right"})
    toggle(Skills, "Use Z/X/C/V/F skills", "AutoCombatSkills", "Rotates only the enabled keys while an automation has a live target.")
    toggle(Skills, "Skill Z", "AutoSkillZ")
    toggle(Skills, "Skill X", "AutoSkillX")
    toggle(Skills, "Skill C", "AutoSkillC")
    toggle(Skills, "Skill V", "AutoSkillV")
    toggle(Skills, "Skill F", "AutoSkillF")

    local Material = Farming:CreateSection({Name = "Material farming", Side = "Right"})
    Material:CreateDropdown({
        Name = "Selected material",
        Values = MATERIAL_LISTS[Sea],
        Default = Settings.SelectedMaterial,
        Flag = "SelectedMaterial",
        Callback = function(value) API.Set("SelectedMaterial", value) end,
    })
    toggle(Material, "Auto farm material", "AutoFarmMaterial", "Uses the current material-to-enemy map and the same fixed-anchor combat path.")
    if Sea == 3 then toggle(Material, "Auto Elite Hunter", "AutoEliteHunter", "Accepts Elite Hunter quests and farms Diablo, Deandre, or Urban when replicated.") end

    local Stats = Window:CreateTab({Name = "Upgrade", Icon = "6031260800"})
    local StatsSection = Stats:CreateSection({Name = "Automatic stat allocation", Side = "Left"})
    StatsSection:CreateSlider({Name = "Points per request", Min = 1, Max = 1000, Step = 1, Default = Settings.StatsValue, Flag = "StatsValue", Callback = function(value) API.Set("StatsValue", value) end})
    StatsSection:CreateInput({Name = "Exact points per request", Default = tostring(Settings.StatsValue), Flag = "StatsValueExact", Numeric = true, Finished = true, Callback = function(value) API.Set("StatsValue", value) end})
    toggle(StatsSection, "Auto melee", "AutoMelee")
    toggle(StatsSection, "Auto defense", "AutoDefense")
    toggle(StatsSection, "Auto sword", "AutoSword")
    toggle(StatsSection, "Auto gun", "AutoGun")
    toggle(StatsSection, "Auto Blox Fruit", "AutoFruitStats")
    local UpgradeRace = Stats:CreateSection({Name = "Race and ability upgrades", Side = "Right"})
    UpgradeRace:CreateButton({Name = "Upgrade race V3", Callback = function() invokeComm("UpgradeRace", "Check"); invokeComm("UpgradeRace", "Buy") end})
    UpgradeRace:CreateButton({Name = "Buy Observation", Callback = function() invokeComm("KenTalk", "Buy") end})
    UpgradeRace:CreateButton({Name = "Buy Aura", Callback = function() invokeComm("BuyHaki", "Buso") end})
    UpgradeRace:CreateButton({Name = "Buy Skyjump", Callback = function() invokeComm("BuyHaki", "Geppo") end})
    UpgradeRace:CreateButton({Name = "Buy Flash Step", Callback = function() invokeComm("BuyHaki", "Soru") end})
    toggle(UpgradeRace, "Auto activate Observation", "AutoObservation")
    toggle(UpgradeRace, "Auto farm Observation", "AutoFarmObservation", "Keeps Observation active and positions near a live enemy to train dodges without attacking it.")

    local Fruits = Window:CreateTab({Name = "Raid & Fruit", Icon = "6034509993"})
    local FruitSection = Fruits:CreateSection({Name = "Fruit automation", Side = "Left"})
    local storeFruitValues = {"All Fruits"}
    for _, name in ipairs(FRUIT_NAMES) do storeFruitValues[#storeFruitValues + 1] = name end
    toggle(FruitSection, "Auto collect spawned fruits", "AutoCollectFruit", "Physically travels to every replicated fruit as a temporary pickup overlay, then resumes the previous farm.")
    Runtime.FruitStoreDropdown = FruitSection:CreateDropdown({
        Name = "Fruit to store",
        Values = storeFruitValues,
        Default = Settings.SelectedStoreFruit,
        Flag = "SelectedStoreFruit",
        Searchable = true,
        Callback = function(value) API.Set("SelectedStoreFruit", value) end,
    })
    toggle(FruitSection, "Auto store selected fruit", "AutoStoreFruit", "Converts display tool names to the canonical inventory ID and sends the actual Backpack tool instance. Choose All Fruits to drain every held fruit.")
    FruitSection:CreateButton({Name = "Store selected fruit now", Callback = storeHeldFruits})
    toggle(FruitSection, "Auto buy random fruit", "AutoRandomFruit", "Calls the exact Cousin/Buy transport immediately, then retries every two seconds while enabled; the server still controls price and cooldown.")
    FruitSection:CreateButton({Name = "Spin random fruit now", Callback = spinRandomFruit})
    local FruitSpinStatus = FruitSection:CreateParagraph({Title = "Fruit spin", Content = "Waiting for a request"})
    local FruitStoreStatus = FruitSection:CreateParagraph({Title = "Fruit storage", Content = "Waiting for a request"})
    task.spawn(function()
        while Runtime.Alive do
            pcall(FruitSpinStatus.SetContent, FruitSpinStatus, Runtime.LastFruitSpinResult or "Waiting for a request")
            pcall(FruitStoreStatus.SetContent, FruitStoreStatus, Runtime.LastFruitStoreResult or "Waiting for a request")
            task.wait(0.5)
        end
    end)
    local FruitStock = Fruits:CreateSection({Name = "Fruit stock", Side = "Right"})
    Runtime.FruitStockDropdown = FruitStock:CreateDropdown({
        Name = "Selected stock fruit",
        Values = FRUIT_NAMES,
        Default = Settings.SelectedStockFruit,
        Flag = "SelectedStockFruit",
        Searchable = true,
        Callback = function(value) API.Set("SelectedStockFruit", value) end,
    })
    toggle(FruitStock, "Auto buy selected stock fruit", "AutoBuyStockFruit", "Uses PurchaseRawFruit every four seconds; the server decides stock and affordability.")
    FruitStock:CreateButton({Name = "Buy selected stock fruit now", Callback = buySelectedStockFruit})
    local FruitStockStatus = FruitStock:CreateParagraph({Title = "Stock purchase", Content = "Waiting for a request"})
    task.spawn(function()
        while Runtime.Alive do
            pcall(FruitStockStatus.SetContent, FruitStockStatus, Runtime.LastFruitStockResult or "Waiting for a request")
            task.wait(0.5)
        end
    end)

    local Items = Window:CreateTab({Name = "Get Items & Mastery", Icon = "6031225818"})
    local ChestSection = Items:CreateSection({Name = "Chests", Side = "Left"})
    toggle(ChestSection, "Auto collect every chest", "AutoCollectChest", "Collects every tagged chest and resumes the enabled farm after each pickup route.")
    toggle(ChestSection, "Search the whole sea", "WholeSeaChestSweep", "Requests every named map sector through Roblox streaming without interrupting autofarm. If streaming requests are unavailable, it falls back to short physical sector visits.")
    local BerrySection = Items:CreateSection({Name = "Berries", Side = "Left"})
    toggle(BerrySection, "Auto collect berries", "AutoCollectBerries", "Uses BerryBush tags plus direct berry instances, sweeps every replicated bush, and returns to farming.")
    if Sea >= 2 then
        local RaidSection = Fruits:CreateSection({Name = "Raids", Side = "Right"})
        RaidSection:CreateDropdown({
            Name = "Raid chip",
            Values = {"Flame", "Ice", "Sand", "Dark", "Light", "Magma", "Quake", "Buddha", "Spider", "Rumble", "Phoenix", "Dough"},
            Default = Settings.SelectedRaidChip,
            Flag = "SelectedRaidChip",
            Callback = function(value) API.Set("SelectedRaidChip", value) end,
        })
        toggle(RaidSection, "Auto raid", "AutoRaid", "Selects the chip, uses replicated raid summon controls, follows the highest active island, and farms raid enemies.")
    end
    local ItemMaterials = Items:CreateSection({Name = "World materials", Side = "Right"})
    ItemMaterials:CreateDropdown({Name = "Selected material", Values = MATERIAL_LISTS[Sea], Default = Settings.SelectedMaterial, Flag = "ItemSelectedMaterial", Callback = function(value) API.Set("SelectedMaterial", value) end})
    toggle(ItemMaterials, "Auto farm selected material", "AutoFarmMaterial")
    if Sea == 3 then toggle(ItemMaterials, "Auto Elite Hunter", "AutoEliteHunter") end
    local Mastery = Items:CreateSection({Name = "Farm mastery", Side = "Right"})
    Mastery:CreateDropdown({Name = "Mastery weapon", Values = {"Blox Fruit", "Sword", "Gun", "Melee"}, Default = Settings.MasteryType, Flag = "MasteryType", Callback = function(value) API.Set("MasteryType", value) end})
    toggle(Mastery, "Auto farm mastery", "AutoFarmMastery", "Uses the selected weapon category with the normal multi-target combat pipeline.")
    toggle(Mastery, "Use mastery skills", "AutoCombatSkills")

    local ESPTab = Window:CreateTab({Name = "ESP", Icon = "6031075938"})
    local WorldESP = ESPTab:CreateSection({Name = "World ESP", Side = "Left"})
    toggle(WorldESP, "Island ESP", "IslandESP", "Uses the complete sea catalog plus extra live _WorldOrigin markers, with compact collision-managed labels.")
    toggle(WorldESP, "Fruit ESP", "FruitESP", "Labels and highlights every replicated world fruit.")
    toggle(WorldESP, "Chest ESP", "ChestESP", "Labels and highlights every cached chest, not only the current pickup.")
    toggle(WorldESP, "Berry ESP", "BerryESP", "Decluttered labels for BerryBush-tagged objects and direct berry instances.")
    toggle(WorldESP, "Player ESP", "PlayerESP", "Name labels plus through-wall outlines for other live player characters.")
    local ESPInfo = ESPTab:CreateSection({Name = "Scanner behavior", Side = "Right"})
    ESPInfo:CreateParagraph({Title = "Event maintained", Content = "Fruit, chest, berry, and island caches update from spawn/removal signals. ESP refreshes labels and distances without repeatedly scanning the whole workspace."})

    local Teleports = Window:CreateTab({Name = "Teleport", Icon = "6031094678"})
    local IslandTravel = Teleports:CreateSection({Name = "Travel to island", Side = "Left"})
    local islandValues = currentIslandNames()
    if Settings.SelectedIsland == "" and islandValues[1] then Settings.SelectedIsland = islandValues[1] end
    Runtime.IslandDropdown = IslandTravel:CreateDropdown({Name = "Choose island", Values = islandValues, Default = Settings.SelectedIsland, Flag = "SelectedIsland", Searchable = true, Callback = function(value) API.Set("SelectedIsland", value) end})
    IslandTravel:CreateButton({Name = "Tween to selected island", Callback = function() if not travelToSelectedIsland(false) then RenLib:Notify({Title = "Island unavailable", Content = "Refresh after the location is replicated.", Duration = 4}) end end})
    IslandTravel:CreateButton({Name = "Instant teleport to island", Callback = function() if not travelToSelectedIsland(true) then RenLib:Notify({Title = "Island unavailable", Content = "Refresh after the location is replicated.", Duration = 4}) end end})
    IslandTravel:CreateButton({Name = "Resume automation movement", Callback = resumeAutomationMovement})
    IslandTravel:CreateParagraph({Title = "Travel control", Content = "Manual island travel temporarily owns movement so farm and pickup loops cannot pull you back. Resume automation here, or enable a farming mode again."})
    IslandTravel:CreateButton({Name = "Refresh island list", Callback = function() Runtime.IslandDropdown:Refresh(currentIslandNames()) end})

    local Shops = Window:CreateTab({Name = "Shop", Icon = "6031260781"})
    local Styles = Shops:CreateSection({Name = "Basic fighting styles", Side = "Left"})
    local function buyButton(section, label, command)
        section:CreateButton({Name = label, Callback = function() invokeComm(command) end})
    end
    buyButton(Styles, "Buy Dark Step", "BuyBlackLeg")
    buyButton(Styles, "Buy Electric", "BuyElectro")
    buyButton(Styles, "Buy Water Kung Fu", "BuyFishmanKarate")
    local AdvancedStyles = Shops:CreateSection({Name = "Advanced fighting styles", Side = "Right"})
    buyButton(AdvancedStyles, "Buy Superhuman", "BuySuperhuman")
    buyButton(AdvancedStyles, "Buy Death Step", "BuyDeathStep")
    buyButton(AdvancedStyles, "Buy Sharkman Karate", "BuySharkmanKarate")
    buyButton(AdvancedStyles, "Buy Electric Claw", "BuyElectricClaw")
    buyButton(AdvancedStyles, "Buy Dragon Talon", "BuyDragonTalon")
    buyButton(AdvancedStyles, "Buy Godhuman", "BuyGodhuman")
    buyButton(AdvancedStyles, "Buy Sanguine Art", "BuySanguineArt")

    local Abilities = Shops:CreateSection({Name = "Abilities", Side = "Right"})
    Abilities:CreateButton({Name = "Buy Aura / Buso", Callback = function() invokeComm("BuyHaki", "Buso") end})
    Abilities:CreateButton({Name = "Buy Skyjump", Callback = function() invokeComm("BuyHaki", "Geppo") end})
    Abilities:CreateButton({Name = "Buy Flash Step", Callback = function() invokeComm("BuyHaki", "Soru") end})
    Abilities:CreateButton({Name = "Buy Observation", Callback = function() invokeComm("KenTalk", "Buy") end})
    local Services = Shops:CreateSection({Name = "Currency services", Side = "Left"})
    Services:CreateButton({Name = "Buy random fruit", Callback = spinRandomFruit})
    Services:CreateButton({Name = "Race reroll", Callback = function() invokeComm("BlackbeardReward", "Reroll", "1") end})
    Services:CreateButton({Name = "Stat refund", Callback = function() invokeComm("BlackbeardReward", "Refund", "1") end})

    local Travel = Teleports:CreateSection({Name = "Travel between seas", Side = "Right"})
    Travel:CreateButton({Name = "Travel to Sea 1", Callback = function() invokeComm("TravelMain") end})
    Travel:CreateButton({Name = "Travel to Sea 2", Callback = function() invokeComm("TravelDressrosa") end})
    Travel:CreateButton({Name = "Travel to Sea 3", Callback = function() invokeComm("TravelZou") end})

    local Codes = Shops:CreateSection({Name = "Codes", Side = "Right"})
    Codes:CreateInput({Name = "Code", Default = Settings.RedeemCode, Flag = "RedeemCode", Callback = function(value) API.Set("RedeemCode", value) end})
    Codes:CreateButton({
        Name = "Redeem code",
        Callback = function()
            if RedeemRemote and Settings.RedeemCode ~= "" then
                pcall(RedeemRemote.InvokeServer, RedeemRemote, Settings.RedeemCode)
            end
        end,
    })

    if Sea >= 2 then
        local Race = Window:CreateTab({Name = Sea == 3 and "Race & trials" or "Race", Icon = "6034287594"})
        local Ability = Race:CreateSection({Name = "Race ability", Side = "Left"})
        toggle(Ability, "Auto activate race V3", "AutoRaceV3")
        if Sea == 3 then toggle(Ability, "Auto activate race V4", "AutoRaceV4") end
        if Sea == 3 then
            local Trials = Race:CreateSection({Name = "V4 trial navigation", Side = "Right"})
            Trials:CreateParagraph({Title = "Sea 3 only", Content = "Trial destinations are resolved from live workspace landmarks, avoiding stale hard-coded coordinates."})
            toggle(Trials, "Auto farm nearest trial enemy", "AutoFarmNearest", "Works for Humanoid combat trials; movement and survival trials need race-specific state.")
            local function moveToLandmark(name)
                for _, instance in ipairs(workspace:GetDescendants()) do
                    if instance.Name == name then
                        local destination = instance:IsA("BasePart") and instance.CFrame
                            or (instance:IsA("Model") and instance:GetPivot())
                        if destination then Movement:Go(destination * CFrame.new(0, 5, 0)); return end
                    end
                end
                RenLib:Notify({Title = "Landmark unavailable", Content = name .. " is not currently replicated.", Duration = 5})
            end
            Trials:CreateButton({Name = "Move to Temple of Time", Callback = function() moveToLandmark("Temple of Time") end})
            Trials:CreateButton({Name = "Move to Ancient Clock", Callback = function() moveToLandmark("Ancient Clock") end})
            Trials:CreateButton({Name = "Move to Great Tree", Callback = function() moveToLandmark("Great Tree") end})
        end
    end

    local Events = Window:CreateTab({Name = "Sea Events", Icon = "6031094678"})
    if Sea == 3 then
        local Entity = Events:CreateSection({Name = "Fixed-anchor event enemy", Side = "Left"})
        Entity:CreateDropdown({
            Name = "Event enemy",
            Values = {"Shark", "Piranha", "Terrorshark", "Fish Crew Member", "Haunted Crew Member"},
            Default = Settings.SelectedEventEnemy,
            Flag = "SelectedEventEnemy",
            Callback = function(value) API.Set("SelectedEventEnemy", value) end,
        })
        toggle(Entity, "Auto farm event enemy", "AutoEventEnemy")
        toggle(Entity, "Auto position at Sea Beast", "AutoSeaBeast", "Uses the non-Humanoid Health/root model and works best with Blox Fruit combat skills.")
        Entity:CreateParagraph({Title = "Sea 3 scope", Content = "Humanoid event enemies keep fixed-anchor farming. Sea Beasts use separate positioning and skill casting; Leviathan boat/gate progression remains a distinct encounter."})
    elseif Sea == 2 then
        local Factory = Events:CreateSection({Name = "Factory enemies", Side = "Left"})
        Factory:CreateParagraph({Title = "Sea 2", Content = "Factory Staff can use the fixed-anchor mob farm; the Factory Core is not a Humanoid and needs its own damage transport."})
        Factory:CreateButton({Name = "Farm Factory Staff", Callback = function() API.Set("SelectedMob", "Factory Staff"); API.Set("AutoKillMob", true) end})
    else
        local FirstSeaEvents = Events:CreateSection({Name = "First Sea events", Side = "Left"})
        FirstSeaEvents:CreateButton({Name = "Farm The Saw", Callback = function() API.Set("SelectedBoss", "The Saw"); API.Set("AutoFarmBoss", true) end})
        FirstSeaEvents:CreateButton({Name = "Farm Saber Expert", Callback = function() API.Set("SelectedBoss", "Saber Expert"); API.Set("AutoFarmBoss", true) end})
        FirstSeaEvents:CreateParagraph({Title = "Sea scope", Content = "Maritime Sea Beast, terror, Leviathan, Mirage, and Prehistoric systems are only shown where those entities can exist."})
    end

    local Dojo = Window:CreateTab({Name = "Dojo Quest", Icon = "6034287594"})
    local DojoQuest = Dojo:CreateSection({Name = "Dragon Dojo", Side = "Left"})
    if Sea == 3 then
        toggle(DojoQuest, "Auto Dojo trainer", "AutoDojoTrainer", "Polls the replicated Dragon Hunter and Dragon Quest interactions.")
        DojoQuest:CreateButton({Name = "Talk to Dragon Hunter", Callback = function() invokeDojoRemote(DragonHunterRemote) end})
        DojoQuest:CreateButton({Name = "Interact with Dragon Quest", Callback = function() invokeDojoRemote(DragonQuestRemote) end})
        DojoQuest:CreateButton({Name = "Tween to Dojo Trainer", Callback = function()
            for _, instance in ipairs(workspace:GetDescendants()) do
                if instance.Name == "Dojo Trainer" then
                    local destination = instance:IsA("BasePart") and instance.CFrame or (instance:IsA("Model") and instance:GetPivot())
                    if destination then Movement:Go(destination * CFrame.new(0, 4, 0)); return end
                end
            end
        end})
    else
        DojoQuest:CreateParagraph({Title = "Third Sea feature", Content = "Dragon Dojo progression is available after travelling to the Third Sea."})
    end

    local Fishing = Window:CreateTab({Name = "Fishing", Icon = "6031225818"})
    local FishingMain = Fishing:CreateSection({Name = "Fishing automation", Side = "Left"})
    FishingMain:CreateDropdown({Name = "Fishing rod", Values = {"Fishing Rod", "Shark Rod", "Shell Rod", "Gold Rod", "Treasure Rod"}, Default = Settings.SelectedFishingRod, Flag = "SelectedFishingRod", Callback = function(value) API.Set("SelectedFishingRod", value) end})
    FishingMain:CreateDropdown({Name = "Bait", Values = {"Basic Bait", "Good Bait", "Kelp Bait", "Carnivore Bait", "Frozen Bait", "Epic Bait", "Abyssal Bait"}, Default = Settings.SelectedBait, Flag = "SelectedBait", Callback = function(value) API.Set("SelectedBait", value) end})
    toggle(FishingMain, "Auto fishing", "AutoFishing", "Equips the selected owned rod, activates it, and uses the replicated catch request when available.")
    toggle(FishingMain, "Auto buy selected bait", "AutoBuyBait", "Interacts with a replicated fishing NPC prompt when one is nearby.")
    toggle(FishingMain, "Auto fishing quest", "AutoFishingQuest", "Automatically interacts with nearby fishing quest prompts.")
    FishingMain:CreateButton({Name = "Interact with fishing NPC", Callback = interactFishingNPC})

    local LocalTab = Window:CreateTab({Name = "LocalPlayer", Icon = "6031075938"})
    local MovementLocal = LocalTab:CreateSection({Name = "Movement", Side = "Left"})
    MovementLocal:CreateSlider({Name = "WalkSpeed value", Min = 0, Max = 500, Step = 1, Default = Settings.WalkSpeed, Flag = "WalkSpeed", Callback = function(value) API.Set("WalkSpeed", value) end})
    MovementLocal:CreateInput({Name = "Exact WalkSpeed", Default = tostring(Settings.WalkSpeed), Flag = "WalkSpeedExact", Numeric = true, Finished = true, Callback = function(value) API.Set("WalkSpeed", value) end})
    toggle(MovementLocal, "Set WalkSpeed", "LockWalkSpeed")
    MovementLocal:CreateSlider({Name = "JumpPower value", Min = 0, Max = 500, Step = 1, Default = Settings.JumpPower, Flag = "JumpPower", Callback = function(value) API.Set("JumpPower", value) end})
    MovementLocal:CreateInput({Name = "Exact JumpPower", Default = tostring(Settings.JumpPower), Flag = "JumpPowerExact", Numeric = true, Finished = true, Callback = function(value) API.Set("JumpPower", value) end})
    toggle(MovementLocal, "Set JumpPower", "LockJumpPower")
    toggle(MovementLocal, "Walk on Water", "WalkOnWater", "Transparent local platform follows only detected terrain water and is enabled by default.")

    local PlayersLocal = LocalTab:CreateSection({Name = "Players, spectate and aim", Side = "Right"})
    local localPlayerNames = playerNames()
    if Settings.SelectedPlayer == "" and localPlayerNames[1] then Settings.SelectedPlayer = localPlayerNames[1] end
    Runtime.PlayerDropdown = PlayersLocal:CreateDropdown({Name = "Select Players", Values = localPlayerNames, Default = Settings.SelectedPlayer, Flag = "SelectedPlayer", Searchable = true, Callback = function(value) API.Set("SelectedPlayer", value) end})
    PlayersLocal:CreateButton({Name = "Refresh Player List", Callback = function() Runtime.PlayerDropdown:Refresh(playerNames()) end})
    toggle(PlayersLocal, "Teleport to Player", "TeleportToPlayer")
    toggle(PlayersLocal, "Spectate Choose Players", "SpectatePlayer")
    toggle(PlayersLocal, "Aimbot Cam Lock", "AimbotCamera")
    toggle(PlayersLocal, "Aimbot Skills", "AimbotSkills", "High-capability executors redirect Vector3/CFrame skill-remote targets; low-capability executors keep the rest of the tab working.")
    toggle(PlayersLocal, "Ignore Same Teams", "IgnoreSameTeams")
    toggle(PlayersLocal, "Accept Allies", "AcceptAllies")

    local InfiniteLocal = LocalTab:CreateSection({Name = "Infinite local abilities", Side = "Left"})
    toggle(InfiniteLocal, "Instance Mink V3 [ INF ]", "InfiniteMinkV3")
    toggle(InfiniteLocal, "Instance Energy [ INF ]", "InfiniteEnergy")
    toggle(InfiniteLocal, "Instance Soru [ INF ]", "InfiniteSoru", "Resets the local Soru closure state when getgc/getupvalues are available; safely no-ops on low-capability executors.")
    toggle(InfiniteLocal, "Instance Observation Range [ INF ]", "InfiniteObservationRange")

    local LocalActions = LocalTab:CreateSection({Name = "Character", Side = "Right"})
    LocalActions:CreateButton({Name = "Reset character", Callback = function() local model = character(); if model then model:BreakJoints() end end})
    toggle(LocalActions, "Anti AFK", "AntiAFK")

    local Misc = Window:CreateTab({Name = "Settings", Icon = "6031280882"})
    local RuntimeSection = Misc:CreateSection({Name = "Runtime and persistence", Side = "Left"})
    toggle(RuntimeSection, "Auto Buso", "AutoBuso")
    RuntimeSection:CreateParagraph({Title = "Automatic profile", Content = "Every toggle, dropdown, slider, and typed value is restored automatically. Filesystem executors persist across rejoins; lower-capability executors retain the profile for the current Roblox session."})
    RuntimeSection:CreateButton({Name = "Rejoin current server", Callback = function() TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer) end})
    RuntimeSection:CreateButton({Name = "Unload script", Callback = API.Destroy})

    local VisualSection = Misc:CreateSection({Name = "Local visuals", Side = "Right"})
    toggle(VisualSection, "Aggressive FPS boost", "AggressiveFPSBoost", "Fully toggleable: caches and restores modified local visual properties when switched off.")
    VisualSection:CreateToggle({
        Name = "Full bright",
        Flag = "FullBright",
        Default = Settings.FullBright,
        Callback = function(value)
            API.Set("FullBright", value)
            Lighting.Brightness = value and 3 or 1
            Lighting.GlobalShadows = not value
        end,
    })
    VisualSection:CreateToggle({
        Name = "Remove fog",
        Flag = "RemoveFog",
        Default = Settings.RemoveFog,
        Callback = function(value)
            API.Set("RemoveFog", value)
            Lighting.FogEnd = value and 1000000 or 100000
        end,
    })

end

function API.Destroy()
    if not Runtime.Alive then return end
    Runtime.Alive = false
    savePersistentSettings(true)
    Runtime.CurrentTarget = nil
    finishPickupOverlay()
    Movement:Cancel()
    clearFarmAnchor(true)
    restoreAggressiveFPSBoost()
    for _, connection in ipairs(Runtime.Connections) do pcall(connection.Disconnect, connection) end
    table.clear(Runtime.Connections)
    for body in pairs(Runtime.OwnedBodyMovers) do
        if body and body.Parent then pcall(body.Destroy, body) end
    end
    for instance in pairs(Runtime.ESPObjects) do destroyESPEntry(instance) end
    table.clear(Runtime.ESPObjects)
    clearStaticIslandParts()
    if Runtime.WaterPart then pcall(Runtime.WaterPart.Destroy, Runtime.WaterPart); Runtime.WaterPart = nil end
    restoreCharacterPhysics(true)
    if Runtime.Gui then pcall(Runtime.Gui.Destroy, Runtime.Gui) end
    if Runtime.RenLib then pcall(Runtime.RenLib.Unload, Runtime.RenLib) end
    if Environment.BloxFruitScript == API then Environment.BloxFruitScript = nil end
end

Environment.BloxFruitScript = API
if Settings.CreateUI then
    Runtime.UIHydrating = true
    local ok, err = pcall(makeRenLibUI)
    Runtime.UIHydrating = false
    if not ok then warn("BloxFruitScript UI:", err) end
end
return API
