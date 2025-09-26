--[[ 
    CaoHUB.lua
    Complete Script Hub for Fish Game
    Features: AutoFishing, AutoSell, AutoFarm, FPSBoost, Webhook, Config Manager
    Branding: CaoHUB
    UI Library: WindUI
]]

-- // Services
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer

-- // Config System
local CONFIG_FOLDER = "CaoHUB/Configs"
if not isfolder("CaoHUB") then makefolder("CaoHUB") end
if not isfolder(CONFIG_FOLDER) then makefolder(CONFIG_FOLDER) end

local function SaveConfig(name, data)
    writefile(CONFIG_FOLDER.."/"..name..".json", HttpService:JSONEncode(data))
end

local function LoadConfig(name)
    local path = CONFIG_FOLDER.."/"..name..".json"
    if isfile(path) then
        return HttpService:JSONDecode(readfile(path))
    end
    return nil
end

local function DeleteConfig(name)
    local path = CONFIG_FOLDER.."/"..name..".json"
    if isfile(path) then
        delfile(path)
    end
end

local function ListConfigs()
    local files = listfiles(CONFIG_FOLDER)
    local list = {}
    for _,f in ipairs(files) do
        if f:sub(-5) == ".json" then
            table.insert(list, f:match("([^/\\]+)%.json$"))
        end
    end
    return list
end

-- // State
local State = {
    AutoFish = false,
    AutoSell = { Common=false, Uncommon=false, Rare=false, Epic=false, Legendary=false, Mythic=false, Secret=false },
    AutoFarm = { Enabled=false, Target=0, Locations={}, CurrentLocation=1, FishCaught=0 },
    FPSBoost = false,
    Webhook = { Enabled=false, SecretRealtime=true, URL="", FishCounter={Common=0,Uncommon=0,Rare=0,Epic=0,Legendary=0,Mythic=0,Secret=0} }
}

-- // Secret Fish Image Mapping (fill manually later)
local SecretFishImages = {
    ["Megalodon"] = "https://example.com/megalodon.png",
    ["Sharkzilla"] = "https://example.com/sharkzilla.png"
}

-- // Load UI Library (WindUI)
local Library = loadstring(game:HttpGet("https://pastebin.com/raw/4WhhZ5aG"))()
local Window = Library:Window({text = "CaoHUB - Fish Game"})

-- Tabs
local MainTab = Window:Tab({text = "Main"})
local FarmTab = Window:Tab({text = "AutoFarm"})
local PerfTab = Window:Tab({text = "Performance"})
local WebhookTab = Window:Tab({text = "Webhook"})
local ConfigTab = Window:Tab({text = "Configs"})

-- Notification helper
local function Notify(msg)
    Library:Notification({text = msg, duration = 5})
end
----------------------------------------------------
-- Part 2: AutoFishing + AutoSell (rarity-based)
----------------------------------------------------

-- // AutoFishing
MainTab:Toggle({text = "Auto Fish", flag = "AutoFish", callback = function(val)
    State.AutoFish = val
    Notify("AutoFishing " .. (val and "Enabled" or "Disabled"))
end})

-- contoh fungsi trigger pancing (harus disesuaikan sama remote event di game)
local function TriggerFish()
    -- asumsi ada remote event
    local args = {
        [1] = "Cast"
    }
    pcall(function()
        game:GetService("ReplicatedStorage").Remotes.Fishing:FireServer(unpack(args))
    end)
end

-- loop auto fish
task.spawn(function()
    while task.wait(1) do
        if State.AutoFish then
            TriggerFish()
        end
    end
end)

----------------------------------------------------
-- AutoSell by rarity
----------------------------------------------------
local AutoSellSection = MainTab:Section({text = "Auto Sell"})

local rarities = {"Common","Uncommon","Rare","Epic","Legendary","Mythic","Secret"}
for _,rarity in ipairs(rarities) do
    AutoSellSection:Toggle({text = "Sell "..rarity, flag = "Sell"..rarity, callback = function(val)
        State.AutoSell[rarity] = val
        Notify("AutoSell "..rarity.." "..(val and "Enabled" or "Disabled"))
    end})
end

-- fungsi jual ikan
local function SellFishByRarity(rarity)
    -- contoh remote jual, sesuaikan sama game
    local args = {
        [1] = "Sell",
        [2] = rarity
    }
    pcall(function()
        game:GetService("ReplicatedStorage").Remotes.SellFish:FireServer(unpack(args))
    end)
end

-- loop autosell
task.spawn(function()
    while task.wait(5) do
        for rarity,enabled in pairs(State.AutoSell) do
            if enabled then
                SellFishByRarity(rarity)
            end
        end
    end
end)
----------------------------------------------------
-- Part 3: AutoFarm (Saved Locations + Target + Looping)
----------------------------------------------------

local AutoFarmSection = FarmTab:Section({text = "Auto Farm"})

-- Toggle AutoFarm
AutoFarmSection:Toggle({text = "Enable AutoFarm", flag = "AutoFarm", callback = function(val)
    State.AutoFarm.Enabled = val
    Notify("AutoFarm " .. (val and "Enabled" or "Disabled"))
end})

-- Input Target Total Ikan
AutoFarmSection:Box({text = "Target Total Fish", flag = "TargetFish", type = "number", callback = function(val)
    State.AutoFarm.Target = tonumber(val) or 0
    Notify("AutoFarm Target set to "..State.AutoFarm.Target.." fish")
end})

-- Save 4 locations
for i=1,4 do
    AutoFarmSection:Button({text = "Save Location "..i, callback = function()
        local pos = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") and LocalPlayer.Character.HumanoidRootPart.Position
        if pos then
            State.AutoFarm.Locations[i] = {x=pos.X,y=pos.Y,z=pos.Z}
            Notify("Location "..i.." saved!")
        else
            Notify("Failed to save location "..i.." (character not found)")
        end
    end})
end

-- Fungsi teleport
local function TeleportToLocation(loc)
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(loc.x,loc.y,loc.z)
    end
end

-- Loop AutoFarm
task.spawn(function()
    while task.wait(2) do
        if State.AutoFarm.Enabled and State.AutoFarm.Target > 0 then
            -- cek progress
            if State.AutoFarm.FishCaught >= State.AutoFarm.Target then
                State.AutoFarm.FishCaught = 0 -- reset counter
                State.AutoFarm.CurrentLocation = State.AutoFarm.CurrentLocation + 1
                if State.AutoFarm.CurrentLocation > 4 then
                    State.AutoFarm.CurrentLocation = 1
                end
                local loc = State.AutoFarm.Locations[State.AutoFarm.CurrentLocation]
                if loc then
                    TeleportToLocation(loc)
                    Notify("Teleported to Location "..State.AutoFarm.CurrentLocation)
                end
            end
        end
    end
end)

-- Hook ke event tangkap ikan (contoh)
-- Panggil fungsi ini setiap kali ikan tertangkap
local function OnFishCaught(fishData)
    State.AutoFarm.FishCaught = State.AutoFarm.FishCaught + 1
    -- Juga update counter webhook
    local tier = fishData.Tier or "Common"
    if State.Webhook.FishCounter[tier] ~= nil then
        State.Webhook.FishCounter[tier] = State.Webhook.FishCounter[tier] + 1
    end
    -- Secret notif khusus (akan kita buat di Part 5)
end
----------------------------------------------------
-- Part 4: FPSBoost (Remove lagging visuals)
----------------------------------------------------

local PerfSection = PerfTab:Section({text = "Performance"})

PerfSection:Toggle({text = "Extreme FPS Boost", flag = "FPSBoost", callback = function(val)
    State.FPSBoost = val
    if val then
        Notify("Extreme FPS Boost Enabled")
        -- Hilangkan semua efek visual
        for _, v in ipairs(Workspace:GetDescendants()) do
            if v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Smoke") or v:IsA("Fire") or v:IsA("Sparkles") then
                v.Enabled = false
            elseif v:IsA("Decal") or v:IsA("Texture") then
                v.Transparency = 1
            elseif v:IsA("BasePart") then
                v.Material = Enum.Material.SmoothPlastic
                v.Reflectance = 0
            end
        end
        -- Matikan terrain water
        Workspace:FindFirstChildOfClass("Terrain").WaterReflectance = 0
        Workspace:FindFirstChildOfClass("Terrain").WaterTransparency = 1
        Workspace:FindFirstChildOfClass("Terrain").WaterWaveSize = 0
        Workspace:FindFirstChildOfClass("Terrain").WaterWaveSpeed = 0
        -- Turunkan lighting
        local Lighting = game:GetService("Lighting")
        Lighting.GlobalShadows = false
        Lighting.FogEnd = 9e9
        sethiddenproperty(Lighting,"Technology",Enum.Technology.Compatibility)
    else
        Notify("Extreme FPS Boost Disabled (some visuals may not restore)")
        -- Optional: bisa bikin restore basic visuals, tapi ga semua efek bisa balik
        local Lighting = game:GetService("Lighting")
        Lighting.GlobalShadows = true
    end
end})
----------------------------------------------------
-- Part 5: Webhook System
----------------------------------------------------

local WebhookSection = WebhookTab:Section({text = "Webhook Settings"})

-- Input Webhook URL
WebhookSection:Box({text = "Webhook URL", flag = "WebhookURL", type = "string", callback = function(val)
    State.Webhook.URL = val
    Notify("Webhook URL set")
end})

-- Toggle Webhook Summary
WebhookSection:Toggle({text = "Enable Summary (1h)", flag = "WebhookSummary", callback = function(val)
    State.Webhook.Enabled = val
    Notify("Webhook Summary " .. (val and "Enabled" or "Disabled"))
end})

-- Toggle Secret Realtime
WebhookSection:Toggle({text = "Enable Secret Realtime Notif", flag = "WebhookSecret", callback = function(val)
    State.Webhook.SecretRealtime = val
    Notify("Secret Realtime " .. (val and "Enabled" or "Disabled"))
end})

-- // Helper: Send Webhook
local function SendWebhook(payload)
    if not State.Webhook.URL or State.Webhook.URL == "" then return end
    local json = HttpService:JSONEncode(payload)
    pcall(function()
        HttpService:PostAsync(State.Webhook.URL, json, Enum.HttpContentType.ApplicationJson)
    end)
end

-- // Secret realtime notif
local function SendSecretNotif(fishData)
    if not State.Webhook.SecretRealtime then return end
    local embed = {
        title = "🎉 "..LocalPlayer.Name.." just caught a SECRET fish!",
        fields = {
            { name = "🐟 Fish Name", value = string.format("%s (%.2f kg)", fishData.Name or "Unknown", (fishData.Weight or 0)/1000) },
            { name = "✨ Tier", value = "SECRET" },
            { name = "💎 Rarity", value = fishData.RarityChance or "Unknown" },
            { name = "🔀 Mutations", value = (fishData.Mutations and #fishData.Mutations > 0) and table.concat(fishData.Mutations,", ") or "None" }
        },
        image = { url = SecretFishImages[fishData.Name] or "" }
    }
    SendWebhook({embeds={embed}})
end

-- // Summary loop (tiap 1 jam)
task.spawn(function()
    while task.wait(3600) do
        if State.Webhook.Enabled then
            local anyNew = false
            for _,v in pairs(State.Webhook.FishCounter) do
                if v > 0 then anyNew = true break end
            end
            if anyNew then
                local fields = {}
                for rarity,count in pairs(State.Webhook.FishCounter) do
                    table.insert(fields, {name=rarity, value=tostring(count), inline=true})
                end
                local embed = {
                    title = "📊 Fish Summary (last 1 hour)",
                    fields = fields,
                    color = 3447003
                }
                SendWebhook({embeds={embed}})
                -- reset counter
                for rarity,_ in pairs(State.Webhook.FishCounter) do
                    State.Webhook.FishCounter[rarity] = 0
                end
            end
        end
    end
end)

-- // Hook OnFishCaught untuk Secret Notif
local oldOnFishCaught = OnFishCaught
OnFishCaught = function(fishData)
    oldOnFishCaught(fishData)
    if fishData.Tier == "Secret" then
        SendSecretNotif(fishData)
    end
end
----------------------------------------------------
-- Part 6: Config Manager
----------------------------------------------------

local ConfigSection = ConfigTab:Section({text = "Manage Configs"})

-- Input nama config
local currentConfigName = "default"

ConfigSection:Box({text = "Config Name", flag = "ConfigName", type = "string", callback = function(val)
    currentConfigName = val
    Notify("Config name set to "..val)
end})

-- Save Config
ConfigSection:Button({text = "Save Config", callback = function()
    local data = State
    SaveConfig(currentConfigName, data)
    Notify("Config '"..currentConfigName.."' saved!")
end})

-- Load Config
ConfigSection:Button({text = "Load Config", callback = function()
    local data = LoadConfig(currentConfigName)
    if data then
        State = data
        Notify("Config '"..currentConfigName.."' loaded!")
    else
        Notify("Config '"..currentConfigName.."' not found")
    end
end})

-- Delete Config
ConfigSection:Button({text = "Delete Config", callback = function()
    DeleteConfig(currentConfigName)
    Notify("Config '"..currentConfigName.."' deleted!")
end})

-- List Configs
ConfigSection:Button({text = "List Configs", callback = function()
    local list = ListConfigs()
    if #list == 0 then
        Notify("No configs found")
    else
        Notify("Configs: "..table.concat(list,", "))
    end
end})

----------------------------------------------------
-- Closing
----------------------------------------------------

Notify("✅ CaoHUB Loaded Successfully!")
