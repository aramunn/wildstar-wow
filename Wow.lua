require "Sound"
require "Unit"

local ShowSpellEnum = {
  Off   = 0,
  All   = 1,
  Crits = 2,
}

local FilteringEnum = {
  Off       = 0,
  Blacklist = 1,
  Whitelist = 2,
}

local Wow = {
  tSeenSpells = {},
  tSave = {
    bEnabled    = true,
    nTimeout    = 0.5,
    eRankMin    = Unit.CodeEnumRank.Champion,
    bTargetOnly = false,
    eFiltering  = FilteringEnum.Off,
    tBlacklist  = {},
    tWhitelist  = {},
  }
}

local knFiles     = 25
local kstrIndent  = "     "

local karRanks = {}
for strName, nRank in pairs(Unit.CodeEnumRank) do
  table.insert(karRanks, {
    nRank   = nRank,
    strName = strName,
  })
end
table.sort(karRanks, function(a, b)
  return a.nRank > b.nRank
end)

local karCommands = {
  {
    strCmd = "on",
    strDescription = "enable addon",
    funcCmd = function(ref, strParam)
      ref.tSave.bEnabled = true
      ref:SysPrint("Enabled!")
    end
  }, {
    strCmd = "off",
    strDescription = "disable addon",
    funcCmd = function(ref, strParam)
      ref.tSave.bEnabled = false
      ref:SysPrint("Disabled")
    end
  }, {
    strCmd = "minrank",
    strDescription = "minimun mob rank to track",
    funcCmd = function(ref, strParam)
      if strParam ~= "" then
        for _, tRank in ipairs(karRanks) do
          if strParam == tostring(tRank.nRank) or strParam == string.lower(tRank.strName) then
            ref.tSave.eRankMin = tRank.nRank
            ref:SysPrint("Set minrank to ["..tostring(tRank.nRank).."] "..tRank.strName)
            return
          end
        end
      end
      ref:SysPrint("Use \"minrank #\"")
      ref:SysPrint("Available Ranks:")
      for _, tRank in ipairs(karRanks) do
        ref:SysPrint(kstrIndent.."["..tostring(tRank.nRank).."] "..tRank.strName)
      end
    end
  }, {
    strCmd = "timeout",
    strDescription = "seconds before looking for more events",
    funcCmd = function(ref, strParam)
      local nTimeout = tonumber(strParam)
      if nTimeout then
        ref.tSave.nTimeout = nTimeout
        ref:UpdateTimeoutTimer()
        ref:SysPrint("Updated timeout to "..tostring(nTimeout).." seconds")
      else
        ref:SysPrint("Use \"timeout #\"")
      end
    end
  }, {
    strCmd = "targetonly",
    strDescription = "only trigger on target/focus",
    funcCmd = function(ref, strParam)
      if strParam == "on" then
        ref.tSave.bTargetOnly = true
        ref:SysPrint("Target-Only enabled")
      elseif strParam == "off" then
        ref.tSave.bTargetOnly = false
        ref:SysPrint("Target-Only disabled")
      else
        ref:SysPrint("Use \"targetonly on\" or \"targetonly off\"")
      end
    end
  }, {
    strCmd = "showspells",
    strDescription = "use to display spell info for filtering",
    funcCmd = function(ref, strParam)
      ref.tSeenSpells = {}
      if strParam == "all" then
        ref.eShowSpells = ShowSpellEnum.All
        ref:SysPrint("All spell info enabled")
      elseif strParam == "crits" then
        ref.eShowSpells = ShowSpellEnum.Crits
        ref:SysPrint("Crit spell info enabled")
      elseif strParam == "off" then
        ref.eShowSpells = ShowSpellEnum.Off
        ref:SysPrint("Spell info disabled")
      else
        ref:SysPrint("Use \"showspells all\", \"showspells crits\", or \"showspells off\"")
      end
    end
  }, {
    strCmd = "filtering",
    strDescription = "select type of filtering or turn off",
    funcCmd = function(ref, strParam)
      if strParam == "blacklist" then
        ref.tSave.eFiltering = FilteringEnum.Blacklist
        ref:SysPrint("Blacklist enabled")
      elseif strParam == "whitelist" then
        ref.tSave.eFiltering = FilteringEnum.Whitelist
        ref:SysPrint("Whitelist enabled")
      elseif strParam == "off" then
        ref.tSave.eFiltering = FilteringEnum.Off
        ref:SysPrint("Filtering disabled")
      else
        ref:SysPrint("Use \"filtering blacklist\", \"filtering whitelist\", or \"filtering off\"")
      end
    end
  }, {
    strCmd = "blacklist",
    strDescription = "view or make changes to the blacklist",
    funcCmd = function(ref, strParam)
      local strOp, strNums = string.match(strParam, "^([+-])(.*)")
      if strOp and strNums then
        for strNum in string.gmatch(strNums, "%d+") do
          local nSpellId = tonumber(strNum)
          ref.tSave.tBlacklist[nSpellId] = strOp == "+" or nil
        end
      elseif strParam == "view" then
        local arSpells = {}
        for nSpellId in pairs(ref.tSave.tBlacklist) do
          local spell = GameLib.GetSpell(nSpellId)
          table.insert(arSpells, spell:GetName().." ["..nSpellId.."]")
        end
        if #arSpells == 0 then
          ref:SysPrint("Nothing in blacklist")
        end
        table.sort(arSpells)
        ref:SysPrint("Blacklist:")
        for _, strSpell in ipairs(arSpells) do ref:SysPrint("  "..strSpell) end
      else
        ref:SysPrint("To view use \"blacklist view\"")
        ref:SysPrint("To change use \"blacklist OP SPELLIDS\"")
        ref:SysPrint("  OP - +/- to add/remove")
        ref:SysPrint("  SPELLIDS - list of space separated spell ids")
      end
    end
  }, {
    strCmd = "whitelist",
    strDescription = "view or make changes to the whitelist",
    funcCmd = function(ref, strParam)
      local strOp, strNums = string.match(strParam, "^([+-])(.*)")
      if strOp and strNums then
        for strNum in string.gmatch(strNums, "%d+") do
          local nSpellId = tonumber(strNum)
          ref.tSave.tWhitelist[nSpellId] = strOp == "+" or nil
        end
      elseif strParam == "view" then
        local arSpells = {}
        for nSpellId in pairs(ref.tSave.tWhitelist) do
          local spell = GameLib.GetSpell(nSpellId)
          table.insert(arSpells, spell:GetName().." ["..nSpellId.."]")
        end
        if #arSpells == 0 then
          ref:SysPrint("Nothing in whitelist")
        end
        table.sort(arSpells)
        ref:SysPrint("Whitelist:")
        for _, strSpell in ipairs(arSpells) do ref:SysPrint("  "..strSpell) end
      else
        ref:SysPrint("To view use \"whitelist view\"")
        ref:SysPrint("To change use \"whitelist OP SPELLIDS\"")
        ref:SysPrint("  OP - +/- to add/remove")
        ref:SysPrint("  SPELLIDS - list of space separated spell ids")
      end
    end
  }
}

local ktCommandMap = {}
for _, tCmdInfo in ipairs(karCommands) do
  ktCommandMap[tCmdInfo.strCmd] = tCmdInfo
end

function Wow:OnCombatLogEvent(tArgs)
  if not self.tSave.bEnabled then return end
  if tArgs.unitCaster ~= GameLib.GetPlayerUnit() then return end
  local nSpellId = tArgs.splCallingSpell:GetId()
  if self.tSave.eFiltering == FilteringEnum.Blacklist then
    if self.tSave.tBlacklist[nSpellId] then return end
  end
  if self.tSave.eFiltering == FilteringEnum.Whitelist then
    if not self.tSave.tWhitelist[nSpellId] then return end
  end
  if self.eShowSpells == ShowSpellEnum.All and not self.tSeenSpells[nSpellId] then
    self:SysPrint(tArgs.splCallingSpell:GetName().." ["..nSpellId.."]")
    self.tSeenSpells[nSpellId] = true
  end
  if tArgs.eCombatResult ~= GameLib.CodeEnumCombatResult.Critical then return end
  if self.eShowSpells == ShowSpellEnum.Crits and not self.tSeenSpells[nSpellId] then
    self:SysPrint(tArgs.splCallingSpell:GetName().." ["..nSpellId.."]")
    self.tSeenSpells[nSpellId] = true
  end
  if not tArgs.unitTarget or not tArgs.unitTarget:IsValid() then return end
  if tArgs.unitTarget:GetRank() < self.tSave.eRankMin then return end
  if self.tSave.bTargetOnly then
    local bIsTarget = false
    bIsTarget = bIsTarget or tArgs.unitTarget == GameLib.GetPlayerUnit():GetTarget()
    bIsTarget = bIsTarget or tArgs.unitTarget == GameLib.GetPlayerUnit():GetAlternateTarget()
    if not bIsTarget then return end
  end
  self:PlaySound()
end

function Wow:PlaySound()
  if self.bPaused then return end
  self.bPaused = true
  self.timerTimeout:Start()
  local strSound = string.format("Wows\\Wow%02d.wav", math.random(knFiles))
  Sound.PlayFile(strSound)
end

function Wow:OnTimeout()
  self.bPaused = false
end

function Wow:UpdateTimeoutTimer()
  self.timerTimeout = ApolloTimer.Create(self.tSave.nTimeout, false, "OnTimeout", self)
  self.timerTimeout:Stop()
end

function Wow:OnSlashCommand(strCmd, strParams)
  strParams = strParams and string.lower(strParams) or ""
  local strMain, strSub = string.match(strParams, "^%s*(%S+)%s*(.*)$")
  if not strMain or not ktCommandMap[strMain] then
    self:PrintHelp()
    return
  end
  local tCmdInfo = ktCommandMap[strMain]
  tCmdInfo.funcCmd(self, strSub or "")
end

function Wow:PrintHelp()
  self:SysPrint("Wow by Aramunn")
  for _, tCmdInfo in pairs(karCommands) do
    self:SysPrint(kstrIndent..tCmdInfo.strCmd.." - "..tCmdInfo.strDescription)
  end
  local strCurrent = self.tSave.bEnabled and "Enabled" or "Disabled"
  strCurrent = strCurrent..", ".."timeout = "..tostring(self.tSave.nTimeout)
  strCurrent = strCurrent..", ".."minrank = "..tostring(self.tSave.eRankMin)
  if self.tSave.bTargetOnly then strCurrent = strCurrent..", Target-Only" end
  if self.tSave.eFiltering ~= FilteringEnum.Off then
    local strCurrentFilter = nil
    for k,v in pairs(FilteringEnum) do
      if self.tSave.eFiltering == v then
        strCurrentFilter = k
      end
    end
    if strCurrentFilter then
      strCurrent = strCurrent..", "..strCurrentFilter
    end
  end
  self:SysPrint("Current Settings: "..strCurrent)
end

function Wow:SysPrint(message)
  ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_System, message, "Wow")
end

function Wow:OnSave(eLevel)
  if eLevel == GameLib.CodeEnumAddonSaveLevel.Account then
    return self.tSave
  end
end

function Wow:OnRestore(eLevel, tSave)
  for k,v in pairs(tSave) do
    if self.tSave[k] ~= nil then
      self.tSave[k] = v
    end
  end
  self:UpdateTimeoutTimer()
end

function Wow:new(o)
  o = o or {}
  setmetatable(o, self)
  self.__index = self
  return o
end

function Wow:Init()
  Apollo.RegisterAddon(self)
end

function Wow:OnLoad()
  Apollo.RegisterSlashCommand("wow", "OnSlashCommand", self)
  Apollo.RegisterEventHandler("CombatLogDamage",        "OnCombatLogEvent", self)
  Apollo.RegisterEventHandler("CombatLogDamageShields", "OnCombatLogEvent", self)
  Apollo.RegisterEventHandler("CombatLogHeal",          "OnCombatLogEvent", self)
  self:UpdateTimeoutTimer()
end

local WowInst = Wow:new()
WowInst:Init()
