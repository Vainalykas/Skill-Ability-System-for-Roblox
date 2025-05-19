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
