
function events.GameInitialized2()

	local VarsToStore = {"UseMonsterBolster", "BolsterAmount", "ShowWeatherEffects", "InfinityView", "ImprovedPathfinding"}
	local RETURN = const.Keys.RETURN
	local ESCAPE = const.Keys.ESCAPE
	local KeyLabels = {}
	local QucikSpellsSlots = {}
	local ActiveText
	local SelectionStarted = false

	-- Setup special screens for interface manager
	local ExSetScr = 98
	const.Screens.ExtraSettings = ExSetScr
	CustomUI.NewScreen(ExSetScr)

	local ExSetScrKeys = 96
	const.Screens.ExtraKeybinds = ExSetScrKeys
	CustomUI.NewScreen(ExSetScrKeys)

	local function ExitExtSetScreen()
		Editor.UpdateVisibility(Game.InfinityView)
		if not Game.ShowWeatherEffects then
			CustomUI.ShowSFTAnim() -- stop current animation
		end

		SelectionStarted = false
		ActiveText = nil
		ExtraQuickSpells.KeyBinds = {}
		for k,v in pairs(QucikSpellsSlots) do
			v.Label.CStd = 0xFFFF -- white
			local Key = const.Keys[v.Key.Text]
			if Key then
				ExtraQuickSpells.KeyBinds[Key] = k
			end
		end

		Game.CurrentScreen = 2
	end

	-- simplify tumbler creation
	local Tumblers = {}
	local function ToggleTumbler(Tumbler)
		Tumbler.IUpSrc, Tumbler.IDwSrc = Tumbler.IDwSrc, Tumbler.IUpSrc
		Tumbler.IUpPtr, Tumbler.IDwPtr = Tumbler.IDwPtr, Tumbler.IUpPtr

		Game.NeedRedraw = true
		Game[Tumbler.VarName] = Tumbler.IUpSrc == "TmblrOn"
		Game.PlaySound(25)
	end

	local function OnOffTumbler(X, Y, VarName)
		local Tumbler = CustomUI.CreateButton{
			IconUp	 	= "TmblrOn",
			IconDown	= "TmblrOff",
			Screen		= ExSetScr,
			Layer		= 0,
			X		=	X,
			Y		=	Y,
			Action	=	ToggleTumbler}

		table.insert(Tumblers, Tumbler)
		Tumbler.VarName = VarName
	end

	-- Create elements
	CustomUI.CreateButton{
		IconUp	 	  = "ExtSetDw",
		IconDown	  = "ExtSetUp",
		IconMouseOver = "ExtSetUp",
		Screen		= {ExSetScr, ExSetScrKeys, 2},
		Layer		= 0,
		X		=	159,
		Y		=	25,
		Action	=	function(t)
			if Game.CurrentScreen == 2 then
				for k,v in pairs(Tumblers) do
					if Game[v.VarName] then
						v.IUpSrc = "TmblrOn"
						v.IDwSrc = "TmblrOff"
					else
						v.IUpSrc = "TmblrOff"
						v.IDwSrc = "TmblrOn"
					end
				end

				Game.CurrentScreen = ExSetScr
			else
				ExitExtSetScreen()
			end
			Game.PlaySound(412)
		end}

	local function BGOnESCAPE()
		if Keys.IsPressed(ESCAPE) then
			ExitExtSetScreen()
		end
		Game.Paused = true
		return true
	end

	CustomUI.CreateIcon{
		Icon = "ExSetScr",
		X = 0,
		Y = 0,
		Layer = 1,
		Condition = BGOnESCAPE,
		BlockBG = true,
		Screen = ExSetScr}

	OnOffTumbler(95, 175, VarsToStore[1])
	OnOffTumbler(95, 251, VarsToStore[3])
	OnOffTumbler(95, 288, VarsToStore[4])
	OnOffTumbler(95, 326, VarsToStore[5])

	local BolsterCX, BolsterCY = 103, 220

	-- Bolster amount text representation
	Game.BolsterAmount = Game.BolsterAmount or 100
	local BolAmText = CustomUI.CreateText{
		Text = tostring(Game.BolsterAmount) .. "%",
		Layer 	= 0,
		Screen	= ExSetScr,
		Width = 60,	Height = 10,
		X = BolsterCX + 40, Y = BolsterCY}

	BolAmText.R = 255
	BolAmText.G = 5
	BolAmText.B = 0

	-- Decrease bolster
	CustomUI.CreateButton{
		IconUp 			= "ar_lt_up",
		IconDown 		= "ar_lt_dn",
		IconMouseOver 	= "ar_lt_ht",
		Action = function(t)
			Game.PlaySound(24)
			Game.BolsterAmount = math.max(Game.BolsterAmount - 5, 0)
			BolAmText.Text = tostring(Game.BolsterAmount) .. "%"
		end,
		Layer 	= 0,
		Screen 	= ExSetScr,
		X = BolsterCX, Y = BolsterCY}

	-- Increase bolster
	CustomUI.CreateButton{
		IconUp 			= "ar_rt_up",
		IconDown 		= "ar_rt_dn",
		IconMouseOver 	= "ar_rt_ht",
		Action = function(t)
			Game.PlaySound(23)
			Game.BolsterAmount = math.min(Game.BolsterAmount + 5, 200)
			BolAmText.Text = tostring(Game.BolsterAmount) .. "%"
		end,
		Layer 	= 0,
		Screen 	= ExSetScr,
		X = BolsterCX + 20, Y = BolsterCY}

	---- Extra keybinds ----
	local NOKEY = "-NO KEY-"
	local function TextChooseKey(t, Key)
		if SelectionStarted then
			if ActiveText == t then
				t.CStd = 0xFFFF
				SelectionStarted = false
				ActiveText = nil
				KeyLabels[t].Text = Key and table.find(const.Keys, Key) or NOKEY
			elseif ActiveText then
				Game.PlaySound(27)
			end
		elseif t then
			SelectionStarted = true
			ActiveText = t
			t.CStd = 0xe664
		end
	end

	CustomUI.CreateIcon{
		Icon = "ExSetScrK",
		X = 0,
		Y = 0,
		Layer = 1,
		Condition = function()
				if Keys.IsPressed(RETURN) then
					if SelectionStarted then
						SelectionStarted = false
						ActiveText.CStd = 0xFFFF
						ActiveText = nil
					end
				elseif Keys.IsPressed(ESCAPE) and not SelectionStarted then
					ExitExtSetScreen()
				end
				return true
			end,
		BlockBG = true,
		Screen = ExSetScrKeys}

	for i = 1, 4 do
		local Label, Key

		Label = CustomUI.CreateText{Text = "Q. SPELL " .. i,
			X = 107, Y = 221 + (i-1)*28,
			AlignLeft = true,
			Action = TextChooseKey,
			Layer = 0,
			Screen = ExSetScrKeys,
			Font = Game.Lucida_fnt}

		Key = CustomUI.CreateText{Text = NOKEY,
			X = 227, Y = 221 + (i-1)*28,
			AlignLeft = true,
			Layer = 0,
			Screen = ExSetScrKeys,
			Font = Game.Lucida_fnt}

		KeyLabels[Label] = Key
		QucikSpellsSlots[i] = {Key = Key, Label = Label}
	end

	function events.KeyDown(t)
		if Game.CurrentScreen == ExSetScrKeys and SelectionStarted then
			TextChooseKey(ActiveText, t.Key)
		end
	end

	---- Switch extra screen ----
	CustomUI.CreateButton{
		IconUp 			= "ar_rt_up",
		IconDown 		= "ar_rt_dn",
		IconMouseOver 	= "ar_rt_ht",
		Action = function(t)
			Game.PlaySound(23)
			if Game.CurrentScreen == ExSetScr then
				Game.CurrentScreen = ExSetScrKeys
			else
				Game.CurrentScreen = ExSetScr
			end
		end,
		Layer 	= 0,
		Screen 	= {ExSetScr, ExSetScrKeys},
		X = 554, Y = 422}

	CustomUI.CreateButton{
		IconUp 			= "ar_lt_up",
		IconDown 		= "ar_lt_dn",
		IconMouseOver 	= "ar_lt_ht",
		Action = function(t)
			Game.PlaySound(24)
			if Game.CurrentScreen == ExSetScr then
				Game.CurrentScreen = ExSetScrKeys
			else
				Game.CurrentScreen = ExSetScr
			end
		end,
		Layer 	= 0,
		Screen 	= {ExSetScr, ExSetScrKeys},
		X = 69, Y = 422}

	-- events
	local function SaveQSKeybinds()
		vars.ExtraSettings.SpellSlots = ExtraQuickSpells.SpellSlots
		vars.ExtraSettings.QSKeybinds = ExtraQuickSpells.KeyBinds
	end

	local function LoadQSKeybinds()
		ExtraQuickSpells.SpellSlots = vars.ExtraSettings.SpellSlots or ExtraQuickSpells.NewSpellSlots()
		ExtraQuickSpells.KeyBinds = vars.ExtraSettings.QSKeybinds or ExtraQuickSpells.DefaultKeybinds()
		for k,v in pairs(QucikSpellsSlots) do
			local Key = table.find(ExtraQuickSpells.KeyBinds, k)
			if Key then
				v.Key.Text = table.find(const.Keys, Key) or NOKEY
			else
				v.Key.Text = NOKEY
			end
		end

		for k,v in pairs(ExtraQuickSpells.KeyBinds) do
			QucikSpellsSlots[v].Key.Text = table.find(const.Keys, k) or NOKEY
		end
	end

	function events.BeforeSaveGame()
		vars.ExtraSettings = vars.ExtraSettings or {}
		local ExSet = vars.ExtraSettings
		for k,v in pairs(VarsToStore) do
			ExSet[v] = Game[v]
		end
		SaveQSKeybinds()
	end

	function events.LoadMap(WasInGame)
		if not WasInGame then
			vars.ExtraSettings = vars.ExtraSettings or {}
			local ExSet = vars.ExtraSettings

			ExSet.BolsterAmount = ExSet.BolsterAmount or 100
			ExSet.InfinityView	= ExSet.InfinityView  or false
			for k,v in pairs(VarsToStore) do
				Game[v] = (ExSet[v] == nil) and true or ExSet[v]
			end
			LoadQSKeybinds()
		end
	end

end
