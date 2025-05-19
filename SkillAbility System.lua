--[[
Skill/Ability System for Roblox
Author: Vain_ie

--- HOW TO IMPLEMENT ---
1. Copy this script into a Script object in ServerScriptService in your Roblox game.
2. The system will automatically manage skills/abilities for all players.
3. To define new skills/abilities, add them to the SKILL_DEFINITIONS table.
4. To grant a skill to a player, call:
   GrantSkill(player, skillName)
5. To check if a player has a skill, call:
   HasSkill(player, skillName)
6. To use an ability (with cooldown), call:
   UseSkill(player, skillName)
7. To listen for skill usage or grant events, connect to the SkillEvent BindableEvent.
8. You can customize skill effects by overriding onSkillUsed(player, skillName) or connecting to SkillEvent.

--- END OF TUTORIAL ---

Credits: System created by Vain_ie

--- EXPLANATION OF EVERY SECTION ---
-- SKILL_DEFINITIONS: Table of all available skills/abilities, with properties like cooldown, description, etc.
-- playerSkills: Table storing each player's unlocked skills and cooldowns.
-- GrantSkill(player, skillName): Grants a skill to a player.
-- HasSkill(player, skillName): Checks if a player has a skill.
-- UseSkill(player, skillName): Attempts to use a skill (checks cooldown, fires event).
-- onSkillUsed(player, skillName): Called when a skill is used (override for custom effects).
-- SkillEvent: BindableEvent for listening to skill usage/grant events.
-- ConnectSkillEvent(callback): Connect to skill events for custom logic.
--- END OF EXPLANATION ---
]]

-- Skill/Ability System for Roblox
-- This script manages player skills/abilities, including granting, usage, cooldowns, and custom effects.

-- Table of all available skills/abilities
local SKILL_DEFINITIONS = {
    Dash = {
        Cooldown = 5, -- seconds
        Description = "Quickly dash forward."
    },
    Heal = {
        Cooldown = 10,
        Description = "Restore some health."
    },
    Fireball = {
        Cooldown = 8,
        Description = "Shoot a fireball."
    }
    -- Add more skills here
}

-- Table to store each player's unlocked skills and cooldowns
local playerSkills = {}

-- BindableEvent for skill usage/grant events
SkillEvent = Instance.new("BindableEvent")

-- Grant a skill to a player
function GrantSkill(player, skillName)
    if not SKILL_DEFINITIONS[skillName] then return false end
    playerSkills[player.UserId] = playerSkills[player.UserId] or {Skills = {}, Cooldowns = {}}
    playerSkills[player.UserId].Skills[skillName] = true
    SkillEvent:Fire("Granted", player, skillName)
    return true
end

-- Check if a player has a skill
function HasSkill(player, skillName)
    return playerSkills[player.UserId] and playerSkills[player.UserId].Skills[skillName] or false
end

-- Get remaining cooldown for a skill (in seconds)
function GetSkillCooldown(player, skillName)
    local cd = playerSkills[player.UserId] and playerSkills[player.UserId].Cooldowns[skillName]
    if not cd then return 0 end
    return math.max(0, cd - os.time())
end

-- Use a skill (checks cooldown, fires event, calls onSkillUsed)
function UseSkill(player, skillName, ...)
    if not HasSkill(player, skillName) then return false, "Skill not unlocked" end
    local def = SKILL_DEFINITIONS[skillName]
    if not def then return false, "Skill not defined" end
    if GetSkillCooldown(player, skillName) > 0 then return false, "Skill on cooldown" end
    -- Set cooldown
    playerSkills[player.UserId].Cooldowns[skillName] = os.time() + def.Cooldown
    -- Fire event and call effect
    SkillEvent:Fire("Used", player, skillName)
    onSkillUsed(player, skillName, ...)
    return true
end

-- === ADVANCED: PARTICLE SYSTEM & EXTERNAL ABILITY SCRIPT ENHANCEMENTS ===

--[[
    1. Particle System: Advanced Integration & Customization

    This section introduces a highly flexible particle system for skill effects, supporting:
      - Attachment to any character part (e.g., "RightHand", "Head", "HumanoidRootPart").
      - Custom particle emitter duration per effect.
      - Multiple emitters per skill, allowing for complex visual effects.
      - Backward compatibility: a string value for Particle still works for simple cases.

    --- HOW TO DEFINE PARTICLES IN SKILL_DEFINITIONS ---
    - To use a single emitter with default settings:
        Particle = "FireEmitter"
    - For advanced effects, use a table of emitter definitions:
        Particle = {
            {Name = "FireEmitter", Part = "RightHand", Duration = 1.5},
            {Name = "SmokeEmitter", Part = "LeftHand"}
        }
      - Name: The name of the ParticleEmitter object in ReplicatedStorage.
      - Part: (Optional) The name of the character part to attach to. Defaults to HumanoidRootPart, Head, or PrimaryPart.
      - Duration: (Optional) How long the emitter stays active (in seconds). Defaults to emitter's Lifetime or 2s.

    --- ADVANCED USAGE NOTES ---
    - You can combine multiple emitters for layered effects (e.g., fire + smoke).
    - Duration can be tuned per emitter for precise timing.
    - This system is modular: you can extend attachParticle for custom logic (e.g., color, size, dynamic parenting).
    - For performance, emitters are automatically cleaned up using Debris service.
    - This approach decouples visual effects from skill logic, making it easy to update visuals without changing core code.
]]
function playSkillParticle(player, skillName)
    local def = SKILL_DEFINITIONS[skillName]
    if not def or not def.Particle then return end
    local char = player.Character
    if not char then return end
    local function attachParticle(particleDef)
        local name = type(particleDef) == "string" and particleDef or particleDef.Name
        local partName = type(particleDef) == "table" and particleDef.Part or nil
        local duration = type(particleDef) == "table" and particleDef.Duration or nil
        local particleTemplate = ReplicatedStorage:FindFirstChild(name)
        if not particleTemplate then return end
        local attachTo = partName and char:FindFirstChild(partName) or char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Head") or char.PrimaryPart or char
        local particle = particleTemplate:Clone()
        particle.Parent = attachTo
        particle.Enabled = true
        local life = duration or (particle.Lifetime and particle.Lifetime.Max > 0 and particle.Lifetime.Max) or 2
        game:GetService("Debris"):AddItem(particle, life)
    end
    if type(def.Particle) == "table" then
        for _, p in ipairs(def.Particle) do
            attachParticle(p)
        end
    else
        attachParticle(def.Particle)
    end
end

-- 2. External Ability Script: Now supports passing extra arguments and context.
--    Ability ModuleScript should return a function: function(player, skillName, ...)
function runExternalAbility(player, skillName, ...)
    if not ABILITY_SCRIPT_FOLDER then return end
    local mod = ABILITY_SCRIPT_FOLDER:FindFirstChild(skillName)
    if not mod then return end
    local ok, abilityFunc = pcall(require, mod)
    if ok and type(abilityFunc) == "function" then
        abilityFunc(player, skillName, ...)
    end
end

-- 3. onSkillUsed: Now passes extra arguments to external scripts and supports callbacks.
function onSkillUsed(player, skillName, ...)
    print(player.Name .. " used skill: " .. skillName)
    playSkillParticle(player, skillName)
    runExternalAbility(player, skillName, ...)
    -- Example: built-in effects
    if skillName == "Heal" and player.Character and player.Character:FindFirstChild("Humanoid") then
        player.Character.Humanoid.Health = math.min(player.Character.Humanoid.MaxHealth, player.Character.Humanoid.Health + 25)
    end
    -- Add more built-in effects here
end

-- 4. UseSkill: Passes extra arguments to onSkillUsed and external scripts.
function UseSkill(player, skillName, ...)
    if not HasSkill(player, skillName) then return false, "Skill not unlocked" end
    local def = SKILL_DEFINITIONS[skillName]
    if not def then return false, "Skill not defined" end
    if GetSkillCooldown(player, skillName) > 0 then return false, "Skill on cooldown" end
    -- Set cooldown
    playerSkills[player.UserId].Cooldowns[skillName] = os.time() + def.Cooldown
    -- Fire event and call effect
    SkillEvent:Fire("Used", player, skillName)
    onSkillUsed(player, skillName, ...)
    return true
end

-- 2. External Ability Script Support
-- To define an ability in a separate script, place a ModuleScript in ReplicatedStorage.Abilities with the skill name.
-- The module should return a function: function(player) ... end
local ABILITY_SCRIPT_FOLDER = ReplicatedStorage:FindFirstChild("Abilities")

function runExternalAbility(player, skillName)
    if not ABILITY_SCRIPT_FOLDER then return end
    local mod = ABILITY_SCRIPT_FOLDER:FindFirstChild(skillName)
    if not mod then return end
    local ok, abilityFunc = pcall(require, mod)
    if ok and type(abilityFunc) == "function" then
        abilityFunc(player)
    end
end

-- Enhanced onSkillUsed to support particles and external scripts
function onSkillUsed(player, skillName)
    print(player.Name .. " used skill: " .. skillName)
    -- Play particle effect if defined
    playSkillParticle(player, skillName)
    -- Run external ability script if present
    runExternalAbility(player, skillName)
    -- Example: built-in effects
    if skillName == "Heal" and player.Character and player.Character:FindFirstChild("Humanoid") then
        player.Character.Humanoid.Health = math.min(player.Character.Humanoid.MaxHealth, player.Character.Humanoid.Health + 25)
    end
    -- Add more built-in effects here
end

-- Connect to this event for custom skill logic (e.g., UI, effects)
function ConnectSkillEvent(callback)
    return SkillEvent.Event:Connect(callback)
end

-- Utility: Get all skills a player has
function GetPlayerSkills(player)
    local skills = {}
    if playerSkills[player.UserId] then
        for skill, _ in pairs(playerSkills[player.UserId].Skills) do
            table.insert(skills, skill)
        end
    end
    return skills
end

-- === ADVANCED: BINDING ABILITIES TO BUTTONS, CLASSES, ETC. ===

-- Table to store ability bindings for each player
local playerAbilityBindings = {}

-- Table to store class definitions and their default skills
local CLASS_DEFINITIONS = {
    Warrior = {"Dash", "Heal"},
    Mage = {"Fireball", "Heal"},
    -- Add more classes and their default skills here
}

-- Bind an ability to a button for a player
function BindAbilityToButton(player, skillName, buttonName)
    playerAbilityBindings[player.UserId] = playerAbilityBindings[player.UserId] or {}
    playerAbilityBindings[player.UserId][buttonName] = skillName
end

-- Get the ability bound to a button for a player
function GetAbilityForButton(player, buttonName)
    return playerAbilityBindings[player.UserId] and playerAbilityBindings[player.UserId][buttonName] or nil
end

-- Assign a class to a player and grant default skills
function AssignClass(player, className)
    local classSkills = CLASS_DEFINITIONS[className]
    if not classSkills then return false end
    for _, skill in ipairs(classSkills) do
        GrantSkill(player, skill)
    end
    player:SetAttribute("Class", className)
    return true
end

-- Get a player's class
function GetPlayerClass(player)
    return player:GetAttribute("Class")
end

-- Example: Use ability by button (e.g., from UI or input event)
function UseAbilityButton(player, buttonName)
    local skill = GetAbilityForButton(player, buttonName)
    if skill then
        return UseSkill(player, skill)
    else
        return false, "No ability bound to this button"
    end
end

-- Utility: Unbind an ability from a button
function UnbindAbilityFromButton(player, buttonName)
    if playerAbilityBindings[player.UserId] then
        playerAbilityBindings[player.UserId][buttonName] = nil
    end
end

-- Utility: Get all button bindings for a player
function GetAllAbilityBindings(player)
    return playerAbilityBindings[player.UserId] or {}
end

-- Listen for new players and initialize their bindings and class
local Players = game:GetService("Players")
Players.PlayerAdded:Connect(function(player)
    playerSkills[player.UserId] = {Skills = {}, Cooldowns = {}}
    playerAbilityBindings[player.UserId] = {}
    -- Optionally assign a default class
    -- AssignClass(player, "Warrior")
end)
Players.PlayerRemoving:Connect(function(player)
    playerSkills[player.UserId] = nil
    playerAbilityBindings[player.UserId] = nil
end)

-- === CUSTOMIZATION OPTIONS ===
-- By default, most features are disabled. Enable and customize by setting these options to true or providing your own functions.

-- 1. ENABLE_SKILL_GRANTING: Allow players to be granted skills (default: false)
local ENABLE_SKILL_GRANTING = false
-- 2. ENABLE_SKILL_USAGE: Allow players to use skills (default: false)
local ENABLE_SKILL_USAGE = false
-- 3. ENABLE_COOLDOWNS: Enable cooldowns for skills (default: false)
local ENABLE_COOLDOWNS = false
-- 4. ENABLE_SKILL_EVENTS: Fire events on skill usage/grant (default: false)
local ENABLE_SKILL_EVENTS = false
-- 5. ENABLE_CLASSES: Allow class assignment and class-based skills (default: false)
local ENABLE_CLASSES = false
-- 6. ENABLE_ABILITY_BINDINGS: Allow binding abilities to buttons (default: false)
local ENABLE_ABILITY_BINDINGS = false
-- 7. ENABLE_DEFAULT_CLASS: Assign a default class to new players (default: false)
local ENABLE_DEFAULT_CLASS = false
-- 8. ENABLE_SKILL_DESCRIPTIONS: Use skill descriptions in UI (default: false)
local ENABLE_SKILL_DESCRIPTIONS = false
-- 9. ENABLE_SKILL_LEVELS: Allow skills to have levels (default: false)
local ENABLE_SKILL_LEVELS = false
-- 10. ENABLE_SKILL_XP: Allow skills to gain XP (default: false)
local ENABLE_SKILL_XP = false
-- 11. ENABLE_PASSIVE_ABILITIES: Allow passive abilities (default: false)
local ENABLE_PASSIVE_ABILITIES = false
-- 12. ENABLE_ACTIVE_ABILITIES: Allow active abilities (default: false)
local ENABLE_ACTIVE_ABILITIES = false
-- 13. ENABLE_SKILL_RESET: Allow players to reset their skills (default: false)
local ENABLE_SKILL_RESET = false
-- 14. ENABLE_SKILL_TREE: Enable skill tree UI/logic (default: false)
local ENABLE_SKILL_TREE = false
-- 15. ENABLE_SKILL_REQUIREMENTS: Allow skills to require other skills (default: false)
local ENABLE_SKILL_REQUIREMENTS = false
-- 16. ENABLE_SKILL_COSTS: Allow skills to cost points/currency (default: false)
local ENABLE_SKILL_COSTS = false
-- 17. ENABLE_SKILL_ICONS: Use icons for skills in UI (default: false)
local ENABLE_SKILL_ICONS = false
-- 18. ENABLE_SKILL_SHORTCUTS: Allow keyboard shortcuts for skills (default: false)
local ENABLE_SKILL_SHORTCUTS = false
-- 19. ENABLE_SKILL_COOLDOWN_UI: Show cooldowns in UI (default: false)
local ENABLE_SKILL_COOLDOWN_UI = false
-- 20. ENABLE_SKILL_SOUND: Play sound on skill use (default: false)
local ENABLE_SKILL_SOUND = false
-- 21. ENABLE_SKILL_ANIMATION: Play animation on skill use (default: false)
local ENABLE_SKILL_ANIMATION = false
-- 31. ENABLE_SKILL_ATTACK: Enable attack logic (damage, hit detection) on skill use (default: false)
local ENABLE_SKILL_ATTACK = false

-- === DESCRIPTION OF EACH CUSTOMIZATION METHOD ===
-- 1. ENABLE_SKILL_GRANTING: If true, players can be granted new skills at runtime.
-- 2. ENABLE_SKILL_USAGE: If true, players can use skills (otherwise UseSkill returns false).
-- 3. ENABLE_COOLDOWNS: If true, skills have cooldowns; otherwise, they can be used repeatedly.
-- 4. ENABLE_SKILL_EVENTS: If true, SkillEvent will fire on skill usage/grant for UI or logging.
-- 5. ENABLE_CLASSES: If true, players can be assigned classes with default skills.
-- 6. ENABLE_ABILITY_BINDINGS: If true, players can bind skills to UI buttons or keys.
-- 7. ENABLE_DEFAULT_CLASS: If true, new players are assigned a default class (set in code).
-- 8. ENABLE_SKILL_DESCRIPTIONS: If true, skill descriptions are available for UI/tooltips.
-- 9. ENABLE_SKILL_LEVELS: If true, skills can have levels (e.g., stronger at higher level).
-- 10. ENABLE_SKILL_XP: If true, skills gain XP and can level up with use.
-- 11. ENABLE_PASSIVE_ABILITIES: If true, skills can be passive (always on effects).
-- 12. ENABLE_ACTIVE_ABILITIES: If true, skills can be active (require activation).
-- 13. ENABLE_SKILL_RESET: If true, players can reset their skills (e.g., respec).
-- 14. ENABLE_SKILL_TREE: If true, a skill tree UI/logic is enabled for progression.
-- 15. ENABLE_SKILL_REQUIREMENTS: If true, skills can require other skills to unlock.
-- 16. ENABLE_SKILL_COSTS: If true, skills cost points or currency to unlock/upgrade.
-- 17. ENABLE_SKILL_ICONS: If true, skills have icons for UI display.
-- 18. ENABLE_SKILL_SHORTCUTS: If true, skills can be activated with keyboard shortcuts.
-- 19. ENABLE_SKILL_COOLDOWN_UI: If true, cooldowns are shown in the UI.
-- 20. ENABLE_SKILL_SOUND: If true, a sound plays when a skill is used.
-- 21. ENABLE_SKILL_ANIMATION: If true, an animation plays when a skill is used.
-- 22. ENABLE_SKILL_PARTICLES: If true, particles are shown when a skill is used.
-- 23. ENABLE_SKILL_LOG: If true, skill usage is logged to the console or a file.
-- 24. ENABLE_SKILL_LIMITS: If true, players are limited in the number of skills they can have.
-- 25. ENABLE_SKILL_SHARING: If true, players can share skills with others.
-- 26. ENABLE_SKILL_UPGRADES: If true, skills can be upgraded for better effects.
-- 27. ENABLE_SKILL_DEBUFFS: If true, skills can apply debuffs to targets.
-- 28. ENABLE_SKILL_BUFFS: If true, skills can apply buffs to the user or allies.
-- 29. ENABLE_SKILL_COOLDOWN_REDUCTION: If true, effects can reduce skill cooldowns.
-- 30. ENABLE_SKILL_CUSTOM_EFFECTS: If true, each skill can have a custom effect function.

-- To enable a feature, set the corresponding variable to true at the top of this script.
-- To implement a feature, add your logic in the relevant section or override the provided functions.

-- === INTEGRATION GUIDE: HOW TO USE THIS SYSTEM IN EXISTING GAMES ===
-- 1. Place this script in ServerScriptService or a ModuleScript in your game.
-- 2. If using as a ModuleScript, require it and call its functions directly (e.g., local Skills = require(path.to.SkillAbilitySystem)).
-- 3. All main functions (GrantSkill, UseSkill, BindAbilityToButton, AssignClass, etc.) are global or can be returned from the module for easy access.
-- 4. To connect to skill events (for UI, effects, etc.), use ConnectSkillEvent(callback).
-- 5. To add new skills, simply add entries to SKILL_DEFINITIONS.
-- 6. To add new classes, add to CLASS_DEFINITIONS.
-- 7. To bind abilities to UI buttons, call BindAbilityToButton(player, skillName, buttonName) from your UI scripts.
-- 8. To use a skill from a button, call UseAbilityButton(player, buttonName) from your input/UI scripts.
-- 9. To extend or override behavior, you can redefine onSkillUsed or any utility function in your own scripts after loading this one.
-- 10. All customization options are at the top; enable only what you need for your game.
-- 11. The system is stateless for UI: you can call GetPlayerSkills, GetAllAbilityBindings, GetPlayerClass, etc. at any time.
-- 12. The system is compatible with other systems (e.g., inventory, combat) by calling its functions from anywhere in your codebase.
-- 13. You can use SkillEvent to trigger UI updates, sound, animation, or other effects in your own scripts.
-- 14. If you want to use this as a ModuleScript, wrap all functions in a table and return it at the end (see below for example).
-- 15. Example ModuleScript export:
--   local SkillSystem = { GrantSkill = GrantSkill, UseSkill = UseSkill, ... }
--   return SkillSystem
-- 16. All data is stored by player.UserId, so it works with Roblox's player lifecycle.
-- 17. You can easily save/load skills using DataStore by serializing playerSkills/playerAbilityBindings.
-- 18. The system is compatible with both classic and modern Roblox UI/input systems.
-- 19. You can add remote events for client-server communication if needed (for UI, mobile, etc.).
-- 20. The system is designed to be copy-paste friendly and modular for any Roblox game.

-- === VARIABLE NAME ALIASES FOR EASY RENAMING ===
-- Change these in one place to update variable names throughout the system.
local SKILL_DEFINITIONS_ALIAS = "SKILL_DEFINITIONS"
local PLAYER_SKILLS_ALIAS = "playerSkills"
local SKILL_EVENT_ALIAS = "SkillEvent"
local PLAYER_ABILITY_BINDINGS_ALIAS = "playerAbilityBindings"
local CLASS_DEFINITIONS_ALIAS = "CLASS_DEFINITIONS"

-- Usage example: Instead of using SKILL_DEFINITIONS directly, use _G[SKILL_DEFINITIONS_ALIAS]
-- For example: _G[SKILL_DEFINITIONS_ALIAS]["Dash"]

-- Set up global aliases for all main tables (for advanced users who want to rename everywhere)
_G[SKILL_DEFINITIONS_ALIAS] = SKILL_DEFINITIONS
_G[PLAYER_SKILLS_ALIAS] = playerSkills
_G[SKILL_EVENT_ALIAS] = SkillEvent
_G[PLAYER_ABILITY_BINDINGS_ALIAS] = playerAbilityBindings
_G[CLASS_DEFINITIONS_ALIAS] = CLASS_DEFINITIONS

-- To rename variables, just change the alias string above and use _G[ALIAS] in your custom code or extensions.
-- For example, to rename playerSkills to "PlayerSkillData", set PLAYER_SKILLS_ALIAS = "PlayerSkillData" and _G[PLAYER_SKILLS_ALIAS] = playerSkills
-- This makes it easy to integrate with other naming conventions or systems.

-- === GUI & ITEM INTEGRATION ===

--[[]
    SECTION OVERVIEW:
    This section outlines how the skill system can communicate with the game's GUI layer.
    By exposing specific hook functions, the core logic remains decoupled from the UI implementation.
    This allows for flexible UI updates, easier maintenance, and potential reuse across different projects.
]]

-- 1. GUI Integration

--[[]
    The following hooks are intended to be called from your UI scripts or connected via event listeners.
    They serve as an interface between the skill system and the user interface, ensuring that
    skill-related changes (like cooldowns, activations, or errors) are reflected visually for the player.
]]

-- UpdateSkillUI(player):
--   - Purpose: Refreshes the entire skill UI for the specified player.
--   - Typical Use: Call after learning a new skill, leveling up, or when skill states change.
--   - Implementation: Override this function in your UI script to redraw skill buttons, icons, etc.

-- ShowSkillCooldown(player, skillName, cooldown):
--   - Purpose: Updates the UI to display the cooldown timer for a specific skill.
--   - Typical Use: Call immediately after a skill is used to start the cooldown animation/timer.
--   - Implementation: Override to update progress bars, timers, or disable skill buttons.

-- ShowSkillActivated(player, skillName):
--   - Purpose: Visually indicates that a skill has been activated.
--   - Typical Use: Call when a skill is successfully triggered (e.g., highlight the skill button).
--   - Implementation: Override to play animations, flash icons, or provide feedback.

-- ShowSkillError(player, skillName, errorMsg):
--   - Purpose: Notifies the player of errors (e.g., skill on cooldown, insufficient resources).
--   - Typical Use: Call when a skill activation fails.
--   - Implementation: Override to display error messages, shake buttons, or show tooltips.

--[[]
    ADVANCED USAGE:
    - You can override these functions directly in your UI scripts for custom behavior.
    - Alternatively, connect them to a SkillEvent system to decouple logic and UI further.
    - Consider using observer/event patterns for scalability in larger projects.
    - For multiplayer games, ensure UI updates are client-specific and not broadcast globally.
]]
function UpdateSkillUI(player)
    -- Implement this in your UI script to refresh skill buttons, icons, etc.
end
function ShowSkillCooldown(player, skillName, cooldown)
    -- Implement this in your UI script to show cooldown timers
end
function ShowSkillActivated(player, skillName)
    -- Implement this in your UI script to highlight or animate the skill button
end
function ShowSkillError(player, skillName, errorMsg)
    -- Implement this in your UI script to display error messages
end

-- Example: Connect to SkillEvent for UI updates
ConnectSkillEvent(function(eventType, player, skillName)
    if eventType == "Used" then
        ShowSkillActivated(player, skillName)
        ShowSkillCooldown(player, skillName, GetSkillCooldown(player, skillName))
    elseif eventType == "Granted" then
        UpdateSkillUI(player)
    end
end)
-- 2. Item Integration (Advanced & Professional Explanation)
--[[
    === ITEM INTEGRATION: ADVANCED USAGE ===

    This section demonstrates how to tightly integrate your skill/ability system with an item/inventory system.
    Items can be used to grant new skills, trigger abilities, or serve as requirements for skill usage.

    --- USAGE PATTERNS ---

    1. Granting Skills via Items:
        - When a player uses or acquires a specific item (e.g., a scroll, book, or artifact), you can grant them a new skill.
        - Example: GrantSkill(player, "Fireball") when the player uses a "FireballScroll" item.

    2. Triggering Skills via Items:
        - Items such as potions or consumables can directly activate a skill or ability.
        - Example: UseSkill(player, "Dash") when the player uses a "DashPotion".

    3. Item Requirements for Skills:
        - Skills can require the player to possess a specific item to be used (e.g., a "MagicWand" for casting spells).
        - Add a `RequiredItem` property to the skill definition:
            SKILL_DEFINITIONS["Fireball"].RequiredItem = "MagicWand"
        - The system will automatically check for the required item before allowing skill usage.

    --- INTEGRATION WITH INVENTORY SYSTEMS ---

    - The HasRequiredItem(player, skillName) function should be implemented to interface with your game's inventory logic.
    - Replace the placeholder code with a call to your inventory API (e.g., player:HasItem(itemName)).
    - This ensures that skills are only usable when the player has the necessary items, supporting advanced gameplay mechanics.

    --- EXAMPLES ---

    -- In your item script, you might use:
        if item.Name == "FireballScroll" then
            GrantSkill(player, "Fireball") -- Permanently grants the skill
        elseif item.Name == "DashPotion" then
            UseSkill(player, "Dash") -- Temporarily triggers the skill effect
        end

    -- To enforce item requirements for skills, simply add RequiredItem to the skill definition:
        SKILL_DEFINITIONS["Fireball"].RequiredItem = "MagicWand"

    -- The UseSkill function will automatically check for the required item and prevent usage if missing.

    --- BENEFITS ---

    - This approach allows for flexible, modular integration between your skill and item systems.
    - Supports advanced features such as consumable skill scrolls, equipment-based abilities, and item-gated powers.
    - Encourages clean separation of concerns: item logic in item scripts, skill logic in the skill system.

    --- CUSTOMIZATION ---

    - You can expand this integration to support item-based skill upgrades, temporary buffs, or cooldown reductions.
    - For more complex requirements (e.g., multiple items, item durability), extend HasRequiredItem accordingly.

    --- SUMMARY ---

    - Use GrantSkill and UseSkill in your item scripts to connect items and abilities.
    - Add RequiredItem to skill definitions for item-gated abilities.
    - Implement HasRequiredItem to connect with your inventory system.
    - This enables a professional, scalable item-skill integration for advanced Roblox games.
]]

-- Example: In your item script:
--   if item.Name == "FireballScroll" then
--       GrantSkill(player, "Fireball") -- Grant the Fireball skill permanently
--   elseif item.Name == "DashPotion" then
--       UseSkill(player, "Dash") -- Trigger the Dash skill effect immediately
--   end
-- You can also add item requirements to SKILL_DEFINITIONS (e.g., RequiredItem = "MagicWand") and the system will check for the item before allowing skill use.

-- Example: Check for required item before using a skill
function HasRequiredItem(player, skillName)
    local def = SKILL_DEFINITIONS[skillName]
    if not def or not def.RequiredItem then return true end
    --[[
        Checks if the player possesses the required item for a specific ability or action.
        This function should be implemented to verify the player's inventory for the item specified by `def.RequiredItem`.
        Replace the example code with your own inventory system logic.

        Example usage:
            return player:HasItem(def.RequiredItem)

        @param player The player object whose inventory will be checked.
        @param def A definition table containing the `RequiredItem` field.
        @return boolean Returns true if the player has the required item, false otherwise.
    ]]
    -- Implement your own inventory check here
    -- Example: return player:HasItem(def.RequiredItem)
    return true -- Replace with actual check
end

-- Modify UseSkill to check for required item
local _UseSkill = UseSkill
function UseSkill(player, skillName, ...)
    if not HasRequiredItem(player, skillName) then
        ShowSkillError(player, skillName, "Missing required item!")
        return false, "Missing required item"
    end
    return _UseSkill(player, skillName, ...)
end

-- === ANIMATION, SOUND, AND ATTACK LOGIC INTEGRATION ===
--[[]
    SECTION OVERVIEW:
    This section provides modular hooks for triggering animations, sounds, and attack logic when a skill is used.
    You can override these functions or connect them to your own systems for custom effects.
    Each skill can define Animation, Sound, and Attack properties in SKILL_DEFINITIONS for per-skill customization.

    --- HOW TO DEFINE ---
    In SKILL_DEFINITIONS, add:
        Animation = "AnimationIdOrName",
        Sound = "SoundIdOrName",
        Attack = function(player, skillName, ...)
            -- Custom attack logic (e.g., damage, hit detection)
        end
    Example:
        Fireball = {
            Cooldown = 8,
            Description = "Shoot a fireball.",
            Animation = "rbxassetid://12345678",
            Sound = "FireballSound",
            Attack = function(player, skillName, ...)
                -- Custom damage logic here
            end
        }
    ---
    You can also set global ENABLE_SKILL_ANIMATION, ENABLE_SKILL_SOUND, ENABLE_SKILL_ATTACK to true to enable these features for all skills.
]]

-- Play animation for a skill (override for custom animation system)
function playSkillAnimation(player, skillName)
    if not ENABLE_SKILL_ANIMATION then return end
    local def = SKILL_DEFINITIONS[skillName]
    if not def or not def.Animation then return end
    local char = player.Character
    if not char then return end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    local anim = Instance.new("Animation")
    anim.AnimationId = def.Animation
    local track = humanoid:LoadAnimation(anim)
    track:Play()
    -- Optionally clean up animation instance
    game:GetService("Debris"):AddItem(anim, 5)
end

-- Play sound for a skill (override for custom sound system)
function playSkillSound(player, skillName)
    if not ENABLE_SKILL_SOUND then return end
    local def = SKILL_DEFINITIONS[skillName]
    if not def or not def.Sound then return end
    local char = player.Character
    if not char then return end
    local soundTemplate = nil
    -- Try ReplicatedStorage first
    if ReplicatedStorage:FindFirstChild(def.Sound) then
        soundTemplate = ReplicatedStorage:FindFirstChild(def.Sound)
    end
    -- Fallback: try as SoundId
    if not soundTemplate then
        local sound = Instance.new("Sound")
        sound.SoundId = def.Sound
        sound.Parent = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Head") or char.PrimaryPart or char
        sound:Play()
        game:GetService("Debris"):AddItem(sound, 5)
        return
    end
    -- Clone and play template sound
    local sound = soundTemplate:Clone()
    sound.Parent = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Head") or char.PrimaryPart or char
    sound:Play()
    game:GetService("Debris"):AddItem(sound, 5)
end

-- Run attack logic for a skill (override for custom combat system)
function runSkillAttack(player, skillName, ...)
    if not ENABLE_SKILL_ATTACK then return end
    local def = SKILL_DEFINITIONS[skillName]
    if not def then return end
    if type(def.Attack) == "function" then
        def.Attack(player, skillName, ...)
    end
end

-- Enhanced onSkillUsed to support animation, sound, and attack logic
local _onSkillUsed = onSkillUsed
function onSkillUsed(player, skillName, ...)
    -- Play animation if enabled
    playSkillAnimation(player, skillName)
    -- Play sound if enabled
    playSkillSound(player, skillName)
    -- Run attack logic if enabled
    runSkillAttack(player, skillName, ...)
    -- Call original onSkillUsed for particles, external scripts, etc.
    if _onSkillUsed then _onSkillUsed(player, skillName, ...) end
end
