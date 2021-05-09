-- Merge Settings

-- Load user-defined values
-- Use file MMMergeSettings.lua in Game root directory
function LoadUserMergeSettings ()
	print("Loading user settings from MMMergeSettings.lua")
	local f, errstr = loadfile("MMMergeSettings.lua")
	if f then f() else
		print("Cannot load user settings: " .. errstr)
	end
end

-- Initialize default Merge Settings
local function InitializeMergeSettings()

	-- Initialize tables
	Merge = Merge or {}
	Merge.Offsets = {}
	Merge.Settings = {}
	Merge.Settings.Logging = {}
	Merge.Settings.Base = {}
	Merge.Settings.Abuse = {}
	Merge.Settings.Attack = {}
	Merge.Settings.Character = {}
	Merge.Settings.Conversions = {}
	Merge.Settings.DimensionDoor = {}
	Merge.Settings.Promotions = {}
	Merge.Settings.Races = {}
	Merge.Settings.Skills = {}
	Merge.Settings.Stealing = {}

	-- Set version
	-- Version of the last Rodril's full pack
	Merge.PackVersion = Merge.PackVersion or "20210515"
	-- Version of the last Rodril's patch
	-- Merge.PatchVersion = Merge.PatchVersion or "20210515"
	-- Version of Community patch. Comment out for Base Merge
	-- Merge.CommunityVersion = Merge.CommunityVersion or "20201130-Comm"
	-- Set version to latest change
	Merge.Version = Merge.CommunityVersion or Merge.PatchVersion or Merge.PackVersion
	-- Full version string
	Merge.VersionFull = (Merge.CommunityVersion and Merge.CommunityVersion .. " based on " or "")
		.. (Merge.PatchVersion and Merge.PatchVersion .. " Patch of " or "")
		.. Merge.PackVersion .. " Pack"
	-- SaveGame compatibility. Raise when SaveGame format is changed.
	-- Version format: YYMMDDxx
	Merge.SaveGameFormatVersion = Merge.SaveGameFormatVersion or 20113000

	------------ Logging settings ------------

	-- Log File Name
	-- Note: if you add subdirectory into File Name, you have to create it first
	--Merge.Settings.Logging.LogFile = "Logs/MMMergeLog.txt"
	Merge.Settings.Logging.LogFile = "MMMergeLog.txt"

	-- Number of old Log Files to preserve [default: 2]
	Merge.Settings.Logging.OldLogsCount = 2

	-- Force immediate flush into log file
	--   0 - [default] don't force
	--   1 - force
	Merge.Settings.Logging.ForceFlush = 0

	-- Print times before log messages
	--   0 - [default] disabled
	--   1 - enabled
	Merge.Settings.Logging.PrintTimes = 0

	-- Print CPU times before log messages also, requires Logging.PrintTimes to be enabled
	--   0 - [default] disabled
	--   1 - enabled
	Merge.Settings.Logging.PrintOsClock = 0

	-- Print message source file before log messages
	--   0 - [default] disabled
	--   1 - enabled
	Merge.Settings.Logging.PrintSources = 0

	-- Print traceback of invalid log message formatting
	--   0 - [default] disable
	--   1 - enable
	Merge.Settings.Logging.PrintFormatTraceback = 0

	-- Log Level
	--    0 - disabled
	--    1 - fatal errors
	--    2 - [default] errors
	--    3 - warnings
	--    4 - informational
	--    5 - debug
	Merge.Settings.Logging.LogLevel = 2

	-- Debug settings (yet to be implemented)
	Merge.Settings.Logging.DebugScope = 0
	Merge.Settings.Logging.DebugFiles = {}

	-------------------------------------------------------
	------------ Default Merge Settings values ------------
	-------------------------------------------------------

	------------ Attack settings ------------

	-- Minimal delay of Melee Attack
	--    Hardcoded at 30
	Merge.Settings.Attack.MinimalMeleeAttackDelay = 30

	-- Minimal delay of Ranged Attack
	--    [base] value: 30
	--    [community default] value: 5
	--    [mm8] value: 0
	Merge.Settings.Attack.MinimalRangedAttackDelay = 5

	-- Minimal delay of Blaster Attack
	--    [base] value: 5
	--    [community default] value: 5
	--    [mm8] value: 0
	Merge.Settings.Attack.MinimalBlasterAttackDelay = 5

	------------ Character settings ------------

	-- Use enhanced autobiographies
	--    0 - [base] use 'Name - Class' style
	--    1 - [community default] use 'Name, the RaceAdj Class' style
	--    2 - use 'Name - Class (Race)' style
	Merge.Settings.Character.EnhancedAutobiographies = 1

	-- Force Zombie character to be of Undead race during Character creation
	--    0 - [base] don't force
	--    1 - [community default] force
	Merge.Settings.Character.ForceZombieToUndeadRace = 1

	-- Autolearn racial skills
	--   0 - [base] disable
	--   1 - [community default] enable
	Merge.Settings.Character.AutolearnRacialSkills = 1

	------------ Character conversions settings ------------

	-- Do not convert Character to Undead on Lich Class Promotion
	--    0 - [base] always convert
	--    1 - [community default] do not convert if race is of Undead kind
	--    2 - never convert
	Merge.Settings.Conversions.PreserveRaceOnLichPromotion = 1

	-- Do not change character voice when his race has been changed
	--    0 - [default] change voice to race default one
	--    1 - keep current voice
	Merge.Settings.Conversions.KeepVoiceOnRaceConversion = 0

	-- Do not change character voice when he was zombified
	--    0 - [default] change voice to race default one
	--    1 - keep current voice
	Merge.Settings.Conversions.KeepVoiceOnZombification = 0

	-- Chance of Zombie race character random zombification (out of 1000)
	--   Mind and Dark resistances and Luck effect reduce this chance
	--   Check is done ~ every 5 minutes
	--   0 disables random zombificaton
	--   [default]: 0
	--   [revamp]: 10
	Merge.Settings.Conversions.ZombieZombificationChance = 0

	------------ Promotions settings ------------

	-- Require Lich Jar for promotion to Master Necromancer
	--    0 - [default] do not require Lich Jar
	--    1 - require Lich Jar once
	--    2 - require Lich Jar for every promotion
	Merge.Settings.Promotions.LichJarForMasterNecromancer = 0

	------------ Races settings ------------

	-- Maximum race maturity
	--    0 - [default] no mature races
	--    1 - one extra level of maturity
	Merge.Settings.Races.MaxMaturity = 0

	------------ Skills settings ------------

	-- Include skill bonus from items in Bow GM damage bonus
	--    0 - [base][mm8] use base skill value
	--    1 - [community default] include skill bonus from items
	-- NOTE: mm8.exe start only; change doesn't work on MMMergeSetting.lua reload
	Merge.Settings.Skills.BowDamageIncludeItemsBonus = 1

	-- Increase event experience reward according to Learning factor
	-- Affects evt.Add("Experience", ...)
	--    0 - [base][mm8] do not increase event experience reward
	--    1 - increase event experience
	Merge.Settings.Skills.LearningIncreaseEvtExperience = 0

	-- Reduce training time by Learning mastery
	-- Additionally remove extra day added to training time
	--    0 - [base][mm8][community default] do not reduce training time
	--    1 - reduce training time by player's Learning skill mastery
	Merge.Settings.Skills.LearningReduceTrainingTime = 0

	------------ Stealing settings ------------
	-- Duration of ban from shop player has been caught in days
	--   default: 336
	Merge.Settings.Stealing.ShopBanDuration = 336

	-- Base fine for being caught
	--   default: 50
	Merge.Settings.Stealing.BaseFine = 50

	------------ Dimension Door settings ------------
	-- Restrict Dimension Door to already visited and starting maps
	Merge.Settings.DimensionDoor.RestrictMaps = true
end

if not Merge or not Merge.Settings then
	InitializeMergeSettings()
	LoadUserMergeSettings()
end

function events.BeforeSaveGame()
	-- Put SaveGameFormatVersion into the savegame
	vars.SaveGameFormatVersion = Merge.SaveGameFormatVersion
end

