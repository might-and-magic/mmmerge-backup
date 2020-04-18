ExtraQuickSpells = {}

local function NewSpellSlots()
	local SpellSlots = {}
	for PlayerId, Player in Party.PlayersArray do
		SpellSlots[PlayerId] = {0, 0, 0, 0}
	end
	return SpellSlots
end
ExtraQuickSpells.NewSpellSlots = NewSpellSlots
ExtraQuickSpells.SpellSlots = NewSpellSlots()

local function CastSlotSpell(SlotNumber)
	if Game.CurrentPlayer < 0 or Game.CurrentScreen ~= 0 then
		return
	end

	local SpellSlots = ExtraQuickSpells.SpellSlots
	local Player = Party[Game.CurrentPlayer]
	local PlayerId = Party.PlayersIndexes[Game.CurrentPlayer]
	local SpellId = SpellSlots[PlayerId][SlotNumber]

	if SpellId == 0 then
		-- perform standart attack
		DoGameAction(23,0,0)
	elseif Player.RecoveryDelay > 0 then
		if PlayerId >= Party.count-1 then
			Game.CurrentPlayer = 0
		else
			Game.CurrentPlayer = PlayerId + 1
		end
	else
		CastQuickSpell(Game.CurrentPlayer, SpellId) -- from HardcodedTopicFunctions.lua
	end
end

local function SetSlotSpell(PlayerId, SlotNumber, SpellId)
	PlayerId = Party.PlayersIndexes[PlayerId]
	local SpellSlots = ExtraQuickSpells.SpellSlots
    if SpellSlots[PlayerId][SlotNumber] == SpellId then
		SpellSlots[PlayerId][SlotNumber] = 0
		Game.PlaySound(142)
	else
		SpellSlots[PlayerId][SlotNumber] = SpellId
		Party[Game.CurrentPlayer]:ShowFaceAnimation(const.FaceAnimation.SetQuickSpell)
	end
end

function GetSelectedSpellId()
	local PlayerId = Game.CurrentPlayer
	if PlayerId < 0 then
		return 0
	end

	local SpellId = mem.u4[0x517b1c]
	local SpellSchool = mem.u1[Party[PlayerId]["?ptr"] + 0x1c44]

	SpellId = SpellId + SpellSchool*11
	if SpellId > 0 and not Party[PlayerId].Spells[SpellId-1] then
		SpellId = 0
	end
	return SpellId
end

function ShowSlotSpellName(SlotNumber)
	local PlayerId = Party.PlayersIndexes[Game.CurrentPlayer]
	local SpellSlots = ExtraQuickSpells.SpellSlots
	local SpellId = SpellSlots[PlayerId][SlotNumber]
	if SpellId == 0 then
		Game.ShowStatusText(Game.GlobalTxt[72])
	else
		Game.ShowStatusText(Game.SpellsTxt[SpellId].Name)
	end
end

function events.GameInitialized2()
	for i = 1, 4 do
		CustomUI.CreateButton{
			IconUp = "stssu",
			IconDown = "stssd",
			Screen = 8,
			Layer = 0,
			X =	0,
			Y =	380 - i*50,
			Masked = true,
			Action = function() SetSlotSpell(Game.CurrentPlayer, i, GetSelectedSpellId()) end,
			MouseOverAction = function() ShowSlotSpellName(i, 1) end
		}
	end
end

-- default values:
local function DefaultKeybinds()
	local t = {}
	t[const.Keys.F5] = 1
	t[const.Keys.F6] = 2
	t[const.Keys.F7] = 3
	t[const.Keys.F8] = 4
	return t
end
ExtraQuickSpells.DefaultKeybinds = DefaultKeybinds
ExtraQuickSpells.KeyBinds = DefaultKeybinds()

---- events ----

function events.KeyDown(t)
	local Slot = ExtraQuickSpells.KeyBinds[t.Key]
	if Slot then
		t.Handled = true
		CastSlotSpell(Slot)
	end
end

-- save/load algorythm is in "MenuExtraSettings.lua"
