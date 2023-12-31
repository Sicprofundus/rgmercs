-- Sample Basic Class Module
local mq                       = require('mq')
local RGMercsLogger            = require("rgmercs.utils.rgmercs_logger")
local RGMercUtils              = require("rgmercs.utils.rgmercs_utils")
local ICONS                    = require('mq.Icons')

local Module                   = { _version = '0.1a', name = "Chase", author = 'Derple' }
Module.__index                 = Module

Module.TempSettings            = {}
Module.TempSettings.CampZoneId = 0

Module.DefaultConfig           = {
    ['ChaseOn']          = { DisplayName = "Chase On", Tooltip = "Chase your Chase Target.", Default = false },
    ['ChaseDistance']    = { DisplayName = "Chase Distance", Tooltip = "How Far your Chase Target can get before you Chase.", Default = 25, Min = 5, Max = 100 },
    ['ChaseTarget']      = { DisplayName = "Chase Target", Tooltip = "Character you are Chasing", Type = "Custom", Default = "" },
    ['ReturnToCamp']     = { DisplayName = "Return To Camp", Tooltip = "Return to Camp After Combat (requires you to /rgl campon)", Default = (not RGMercConfig.Constants.RGTank:contains(mq.TLO.Me.Class.ShortName())) },
    ['MaintainCampfire'] = { DisplayName = "Maintain Campfire", Tooltip = "0: Off; 1: Regular Fellowship; 2: Empowered Fellowship; 36: Scaled Wolf", Default = 1, Min = 0, Max = 36 },
    ['RequireLoS']       = { DisplayName = "Require LOS", Tooltip = "Require LOS when using /nav", Default = RGMercConfig.Constants.RGCasters:contains(mq.TLO.Me.Class.ShortName()) },
}

local function getConfigFileName()
    local server = mq.TLO.EverQuest.Server()
    server = server:gsub(" ", "")
    return mq.configDir ..
        '/rgmercs/PCConfigs/' .. Module.name .. "_" .. server .. "_" .. RGMercConfig.Globals.CurLoadedChar .. '.lua'
end

function Module:SaveSettings(doBroadcast)
    mq.pickle(getConfigFileName(), self.settings)

    if doBroadcast then
        RGMercUtils.BroadcastUpdate(self.name, "SaveSettings")
    end
end

function Module:LoadSettings()
    RGMercsLogger.log_info("Chase Module Loading Settings for: %s.", RGMercConfig.Globals.CurLoadedChar)
    local settings_pickle_path = getConfigFileName()

    local config, err = loadfile(settings_pickle_path)
    if err or not config then
        RGMercsLogger.log_error("\ay[Basic]: Unable to load global settings file(%s), creating a new one!",
            settings_pickle_path)
        self.settings = {}
    else
        self.settings = config()
    end

    -- Setup Defaults
    for k, v in pairs(self.DefaultConfig) do
        self.settings[k] = self.settings[k] or v.Default
    end
end

function Module.New()
    RGMercsLogger.log_info("Chase Module Loaded.")
    local newModule = setmetatable({ settings = {} }, Module)

    newModule:LoadSettings()

    return newModule
end

function Module:ChaseOn(target)
    local chaseTarget = mq.TLO.Target

    if target then
        chaseTarget = mq.TLO.Spawn("pc =" .. target)
    end

    if chaseTarget.ID() > 0 and chaseTarget.Type() == "PC" then
        self.settings.ChaseOn = true
        self.settings.ChaseTarget = chaseTarget.CleanName()
        self:SaveSettings(true)
    else
        RGMercsLogger.log_warning("\ayWarning:\ax Not a valid chase target!")
    end
end

function Module:ChaseOff()
    self.settings.ChaseOn = false
    self.settings.ChaseTarget = nil
    self:SaveSettings(true)
    RGMercsLogger.log_warning("\ayNo longer chasing \at%s\ay.", self.settings.ChaseTarget or "None")
end

function Module:CampOn()
    self.settings.ReturnToCamp   = true
    self.TempSettings.AutoCampX  = mq.TLO.Me.X()
    self.TempSettings.AutoCampY  = mq.TLO.Me.Y()
    self.TempSettings.AutoCampZ  = mq.TLO.Me.Z()
    self.TempSettings.CampZoneId = mq.TLO.Zone.ID()
    RGMercsLogger.log_info("\ayCamping On: (X: \at%d\ay ; Y: \at%d\ay)", self.TempSettings.AutoCampX, self.TempSettings.AutoCampY)
end

function Module:CampOff()
    self.settings.ReturnToCamp = false
    self:SaveSettings(true)
end

function Module:DestoryCampfire()
    mq.TLO.Window("FellowshipWnd").DoOpen()
    mq.delay("3s", mq.TLO.Window("FellowshipWnd").Open())
    mq.TLO.Window("FellowshipWnd").Child("FP_Subwindows").SetCurrentTab(2)

    if mq.TLO.Me.Fellowship.Campfire() then
        if mq.TLO.Zone.ID() ~= mq.TLO.Me.Fellowship.CampfireZone.ID() then
            mq.TLO.Window("FellowshipWnd").Child("FP_DestroyCampsite").LeftMouseUp()
            mq.delay("5s", mq.TLO.Window("ConfirmationDialogBox").Open())

            if mq.TLO.Window("ConfirmationDialogBox").Open() then
                mq.TLO.Window("ConfirmationDialogBox").Child("Yes_Button").LeftMouseUp()
            end

            mq.delay("5s", mq.TLO.Me.Fellowship.Campfire() == nil)
        end
    end
    mq.TLO.Window("FellowshipWnd").DoClose()
end

function Module:Campfire(camptype)
    if camptype == -1 then
        self:DestoryCampfire()
        return
    end

    if mq.TLO.Zone.ID() == 33506 then return end

    if not mq.TLO.Me.Fellowship() or mq.TLO.Me.Fellowship.Campfire() then
        RGMercsLogger.log_info("\arNot in a fellowship or already have a campfire -- not putting one down.")
        return
    end

    if self.settings.MaintainCampfire then
        if mq.TLO.FindItemCount("Fellowship Campfire Materials") == 0 then
            self.settings.MaintainCampfire = 1
            self:SaveSettings(true)
            RGMercsLogger.log_info("Fellowship Campfire Materials Not Found. Setting to Regular Fellowship.")
        end
    end

    local spawnCount  = mq.TLO.SpawnCount("PC radius 50")()
    local fellowCount = 0

    for i = 1, spawnCount do
        local spawn = mq.TLO.NearestSpawn(i, "PC radius 50")

        if spawn() and mq.TLO.Me.Fellowship.Member(spawn.CleanName()) then
            fellowCount = fellowCount + 1
        end
    end

    if fellowCount >= 3 then
        mq.TLO.Window("FellowshipWnd").DoOpen()
        mq.delay("3s", mq.TLO.Window("FellowshipWnd").Open())
        mq.TLO.Window("FellowshipWnd").Child("FP_Subwindows").SetCurrentTab(2)

        if mq.TLO.Me.Fellowship.Campfire() then
            if mq.TLO.Zone.ID() ~= mq.TLO.Me.Fellowship.CampfireZone.ID() then
                mq.TLO.Window("FellowshipWnd").Child("FP_DestroyCampsite").LeftMouseUp()
                mq.delay("5s", mq.TLO.Window("ConfirmationDialogBox").Open())

                if mq.TLO.Window("ConfirmationDialogBox").Open() then
                    mq.TLO.Window("ConfirmationDialogBox").Child("Yes_Button").LeftMouseUp()
                end

                mq.delay("5s", mq.TLO.Me.Fellowship.Campfire() == nil)
            end
        end

        mq.TLO.Window("FellowshipWnd").Child("FP_RefreshList").LeftMouseUp()
        mq.delay("1s")
        mq.TLO.Window("FellowshipWnd").Child("FP_CampsiteKitList").Select(self.settings.MaintainCampfire or camptype)
        mq.delay("1s")
        mq.TLO.Window("FellowshipWnd").Child("FP_CreateCampsite").LeftMouseUp()
        mq.delay("5s", mq.TLO.Me.Fellowship.Campfire() ~= nil)
        mq.TLO.Window("FellowshipWnd").DoClose()

        RGMercsLogger.log_info("\agCampfire Dropped")
    else
        RGMercsLogger.log_info("\ayCan't create campfire. Only %d nearby. Setting MaintainCampfire to 0.", fellowCount)
        self.settings.MaintainCampfire = 0
    end
end

function Module:Render()
    ImGui.Text("Chase Module")
    ImGui.Text(string.format("Chase Distance: %d", self.settings.ChaseDistance))
    ImGui.Text(string.format("Chase LOS Required: %s", self.settings.LineOfSight and "On" or "Off"))

    local pressed
    local chaseSpawn = mq.TLO.Spawn("pc =" .. (self.settings.ChaseTarget or "NoOne"))

    if ImGui.CollapsingHeader("Config Options") then
        self.settings, pressed, _ = RGMercUtils.RenderSettings(self.settings, self.DefaultConfig)
        if pressed then
            self:SaveSettings(true)
        end
    end

    ImGui.Separator()

    if chaseSpawn and chaseSpawn.ID() > 0 then
        ImGui.Text(string.format("Chase Target: %s", self.settings.ChaseTarget))
        ImGui.Indent()
        ImGui.Text(string.format("Distance: %d", chaseSpawn.Distance()))
        ImGui.Text(string.format("ID: %d", chaseSpawn.ID()))
        ImGui.Text(string.format("LOS: "))
        if chaseSpawn.LineOfSight() then
            ImGui.PushStyleColor(ImGuiCol.Text, 0.3, 1.0, 0.3, 0.8)
        else
            ImGui.PushStyleColor(ImGuiCol.Text, 1.0, 0.3, 0.3, 0.8)
        end
        ImGui.SameLine()
        ImGui.Text(string.format("%s", chaseSpawn.LineOfSight() and ICONS.FA_EYE or ICONS.FA_EYE_SLASH))
        ImGui.PopStyleColor(1)
        ImGui.Unindent()
    else
        ImGui.Indent()
        ImGui.PushStyleColor(ImGuiCol.Text, 1.0, 0.3, 0.3, 0.8)
        ImGui.Text(string.format("Chase Target Invalid!"))
        ImGui.PopStyleColor(1)
        ImGui.Unindent()
    end

    ImGui.Separator()

    if self.settings.ReturnToCamp then
        ImGui.Text("Camp Location")
        ImGui.Indent()
        ImGui.Text(string.format("X: %d, Y: %d, Z: %d", self.TempSettings.AutoCampX, self.TempSettings.AutoCampY, self.TempSettings.AutoCampZ))
        ImGui.Unindent()
        if ImGui.SmallButton("Set New Camp Here") then
            self:CampOn()
        end
    end

    local state, pressed = RGMercUtils.RenderOptionToggle("##chase_om", "Chase On", self.settings.ChaseOn)
    if pressed then
        mq.cmdf("/rgl chase%s", state and "on" or "off")
    end
end

function Module:OnDeath()
    if self.settings.ChaseTarget then
        RGMercsLogger.log_info("\awNOTICE:\ax You're dead. I'm not chasing %s anymore.", self.settings.ChaseTarget)
    end
    self:ChaseOff()
end

function Module:ShouldFollow()
    local me = mq.TLO.Me
    local assistSpawn = RGMercConfig:GetAssistSpawn()

    return not mq.TLO.MoveTo.Moving() and
        (not me.Casting.ID() or me.Class.ShortName():lower() == "brd") and
        (RGMercUtils.GetXTHaterCount() == 0 or (assistSpawn() and assistSpawn.Distance() > self.settings.ChaseDistance))
end

function Module:GiveTime(combat_state)
    if mq.TLO.Me.Dead() and self.settings.ChaseOn then
        RGMercsLogger.log_warning("\awNOTICE:\ax You're dead. I'm not chasing \am%s\ax anymore.",
            self.settings.ChaseTarget)
        self.settings.ChaseOn = false
        self:SaveSettings()
        return
    end

    if not self:ShouldFollow() then return end

    if RGMercUtils.DoCamp() then
        RGMercUtils.AutoCampCheck(self.settings, self.TempSettings)
    end

    if self.settings.ChaseOn and not self.settings.ChaseTarget then
        self.settings.ChaseOn = false
        RGMercsLogger.log_warning("\awNOTICE:\ax \ayChase Target is invalid. Turning Chase Off!")
    end

    if self.settings.ChaseOn and self.settings.ChaseTarget then
        local chaseSpawn = mq.TLO.Spawn("pc =" .. self.settings.ChaseTarget)

        if not chaseSpawn or chaseSpawn.Dead() or not chaseSpawn.ID() then
            RGMercsLogger.log_warning("\awNOTICE:\ax Chase Target \am%s\ax is dead or not found in zone - Pausing...",
                self.settings.ChaseTarget)
            --self.settings.ChaseOn = false
            --self:SaveSettings()
            return
        end

        if mq.TLO.Me.Dead() then return end
        if chaseSpawn.Distance() < self.settings.ChaseDistance then return end

        local Nav = mq.TLO.Nav

        -- Use MQ2Nav with moveto as a failover if we have a mesh. We'll use a nav
        -- command if the mesh is loaded and we have a path. If we don't have a path
        -- we'll use a moveto. This will hopefully get us over spots of the mesh that
        -- are missing with minimal issues.
        if Nav.MeshLoaded() then
            if not Nav.Active() then
                if Nav.PathExists("id " .. chaseSpawn.ID()) then
                    mq.cmdf("/squelch /nav id %d | log=critical distance %d lineofsight=%s", chaseSpawn.ID(),
                        self.settings.ChaseDistance, self.settings.RequireLoS and "on" or "off")
                else
                    -- Assuming no line of site problems.
                    -- Moveto underwater style until 20 units away
                    mq.cmdf("/squelch /moveto id %d uw mdist %d", chaseSpawn.ID(), self.settings.ChaseDistance)
                end
            end
        elseif chaseSpawn.Distance() > self.settings.ChaseDistance and chaseSpawn.Distnance() < 400 then
            -- If we don't have a mesh we're using afollow as legacy RG behavior.
            mq.cmdf("/squelch /afollow spawn %d", chaseSpawn.ID())
            mq.cmdf("/squelch /afollow %d", self.settings.ChaseDistance)

            mq.delay("2s")

            if chaseSpawn.Distance() < self.settings.ChaseDistance then
                mq.cmdf("/squelch /afollow off")
            end
        end
    end

    if RGMercUtils.DoBuffCheck() and not RGMercConfig:GetSettings().PriorityHealing then
        if mq.TLO.Me.Fellowship.CampfireZone() and mq.TLO.Zone.ID() == self.TempSettings.CampZoneId and self.settings.MaintainCampfire then
            self:Campfire()
        end
    end
end

function Module:Shutdown()
    RGMercsLogger.log_info("Chase Module UnLoaded.")
end

return Module