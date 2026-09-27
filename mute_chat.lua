-- mute_chat Addon
-- Mutes messages containing Asian (CJK) characters

local ADDON_NAME = "mute_chat"

-- 1. High-Performance Character Check
-- CJK/Asian characters in UTF-8 begin with leading bytes between 227 (0xE3) and 237 (0xED).
local function ContainsAsianCharacters(text)
    if type(text) ~= "string" then return false end
    for i = 1, #text do
        local b = string.byte(text, i)
        if b >= 227 and b <= 237 then
            return true
        end
    end
    return false
end

-- 2. Create Windows (Options & Log)
local OptionsFrame = CreateFrame("Frame", "MuteChatOptionsFrame", UIParent, "BasicFrameTemplate")
OptionsFrame:SetSize(250, 200)
OptionsFrame:SetPoint("CENTER")
OptionsFrame:Hide()
OptionsFrame:SetMovable(true)
OptionsFrame:EnableMouse(true)
OptionsFrame:RegisterForDrag("LeftButton")
OptionsFrame:SetScript("OnDragStart", OptionsFrame.StartMoving)
OptionsFrame:SetScript("OnDragStop", OptionsFrame.StopMovingOrSizing)
if OptionsFrame.TitleText then OptionsFrame.TitleText:SetText("Mute Chat Options") end
tinsert(UISpecialFrames, "MuteChatOptionsFrame") -- Allows Esc key to close

local LogFrame = CreateFrame("Frame", "MuteChatLogFrame", UIParent, "BasicFrameTemplate")
LogFrame:SetSize(520, 360)
LogFrame:SetPoint("CENTER")
LogFrame:Hide()
LogFrame:SetMovable(true)
LogFrame:EnableMouse(true)
LogFrame:RegisterForDrag("LeftButton")
LogFrame:SetScript("OnDragStart", LogFrame.StartMoving)
LogFrame:SetScript("OnDragStop", LogFrame.StopMovingOrSizing)
if LogFrame.TitleText then LogFrame.TitleText:SetText("Muted Chat Log") end
tinsert(UISpecialFrames, "MuteChatLogFrame") -- Allows Esc key to close

-- Dummy function to satisfy Blizzard ScrollBar templates expecting a ScrollFrame parent
LogFrame.SetVerticalScroll = function() end

-- 3. Log Frame Content & Scrollbar
local messageFrame = CreateFrame("ScrollingMessageFrame", "MuteChatMessageFrame", LogFrame)
messageFrame:SetPoint("TOPLEFT", LogFrame, "TOPLEFT", 15, -35)
messageFrame:SetPoint("BOTTOMRIGHT", LogFrame, "BOTTOMRIGHT", -36, 15)
messageFrame:SetFontObject("ChatFontNormal")
messageFrame:SetJustifyH("LEFT")
messageFrame:SetMaxLines(1000)
messageFrame:SetFading(false)
messageFrame:SetInsertMode("BOTTOM")

local scrollBar = CreateFrame("Slider", "MuteChatLogScrollBar", LogFrame, "UIPanelScrollBarTemplate")
scrollBar:SetPoint("TOPRIGHT", LogFrame, "TOPRIGHT", -10, -52)
scrollBar:SetPoint("BOTTOMRIGHT", LogFrame, "BOTTOMRIGHT", -10, 34)
scrollBar.scrollStep = 1

local isUpdatingScrollBar = false

local function UpdateScrollBar()
    if isUpdatingScrollBar then return end
    isUpdatingScrollBar = true

    local numMessages = (messageFrame.GetNumMessages and messageFrame:GetNumMessages()) or 0
    local currentOffset = (messageFrame.GetScrollOffset and messageFrame:GetScrollOffset()) or 0
    local maxOffset = math.max(0, numMessages - 1)

    scrollBar:SetMinMaxValues(0, maxOffset)
    local val = maxOffset - currentOffset
    if val < 0 then val = 0 end
    if val > maxOffset then val = maxOffset end
    scrollBar:SetValue(val)

    if maxOffset == 0 then
        scrollBar:Disable()
    else
        scrollBar:Enable()
    end
    isUpdatingScrollBar = false
end

-- Override template's OnValueChanged immediately before calling SetValue
scrollBar:SetScript("OnValueChanged", function(self, value)
    if isUpdatingScrollBar then return end
    local minVal, maxVal = self:GetMinMaxValues()
    local targetOffset = math.floor(maxVal - value + 0.5)
    if targetOffset < 0 then targetOffset = 0 end

    if messageFrame.SetScrollOffset then
        messageFrame:SetScrollOffset(targetOffset)
    else
        local currentOffset = (messageFrame.GetScrollOffset and messageFrame:GetScrollOffset()) or 0
        local diff = targetOffset - currentOffset
        if diff > 0 then
            for _ = 1, diff do messageFrame:ScrollUp() end
        elseif diff < 0 then
            for _ = 1, -diff do messageFrame:ScrollDown() end
        end
    end
end)

if scrollBar.ScrollUpButton then
    scrollBar.ScrollUpButton:SetScript("OnClick", function()
        messageFrame:ScrollUp()
        UpdateScrollBar()
    end)
end

if scrollBar.ScrollDownButton then
    scrollBar.ScrollDownButton:SetScript("OnClick", function()
        messageFrame:ScrollDown()
        UpdateScrollBar()
    end)
end

scrollBar:SetMinMaxValues(0, 0)
scrollBar:SetValueStep(1)
scrollBar:SetValue(0)

messageFrame:EnableMouseWheel(true)
messageFrame:SetScript("OnMouseWheel", function(self, delta)
    if delta > 0 then
        if IsShiftKeyDown() then
            self:ScrollToTop()
        else
            self:ScrollUp()
        end
    elseif delta < 0 then
        if IsShiftKeyDown() then
            self:ScrollToBottom()
        else
            self:ScrollDown()
        end
    end
    UpdateScrollBar()
end)

LogFrame:SetScript("OnShow", function()
    UpdateScrollBar()
end)

local function AddToLog(timeStr, author, msg)
    messageFrame:AddMessage(string.format("[%s] |cff00ccff%s|r: %s", timeStr, author, msg))
    UpdateScrollBar()
end

-- 4. Options Frame Content
local enableCheckbox = CreateFrame("CheckButton", nil, OptionsFrame, "UICheckButtonTemplate")
enableCheckbox:SetPoint("TOPLEFT", 20, -35)
local chkText = enableCheckbox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
chkText:SetPoint("LEFT", enableCheckbox, "RIGHT", 5, 0)
chkText:SetText("Enable Chat Filter")
enableCheckbox:SetScript("OnClick", function(self)
    MuteChatDB.enabled = self:GetChecked()
end)

local logButton = CreateFrame("Button", nil, OptionsFrame, "GameMenuButtonTemplate")
logButton:SetSize(130, 26)
logButton:SetPoint("TOPLEFT", 20, -72)
logButton:SetText("Open Log")
logButton:SetScript("OnClick", function()
    if LogFrame:IsShown() then
        LogFrame:Hide()
    else
        LogFrame:Show()
    end
end)

local clearButton = CreateFrame("Button", nil, OptionsFrame, "GameMenuButtonTemplate")
clearButton:SetSize(130, 26)
clearButton:SetPoint("TOPLEFT", 20, -105)
clearButton:SetText("Clear Log")
clearButton:SetScript("OnClick", function()
    messageFrame:Clear()
    messageFrame:AddMessage("Log cleared.")
    UpdateScrollBar()
end)

local resetPosButton = CreateFrame("Button", nil, OptionsFrame, "GameMenuButtonTemplate")
resetPosButton:SetSize(130, 26)
resetPosButton:SetPoint("TOPLEFT", 20, -138)
resetPosButton:SetText("Reset Icon Pos")

-- 5. Floating Icon (Move Anywhere & Character Specific)
local minimapButton = CreateFrame("Button", "MuteChatMinimapButton", UIParent)
minimapButton:SetSize(32, 32)
minimapButton:SetFrameStrata("MEDIUM")
minimapButton:SetFrameLevel(8)
minimapButton:SetMovable(true)
minimapButton:SetClampedToScreen(true)
minimapButton:EnableMouse(true)

local icon = minimapButton:CreateTexture(nil, "BACKGROUND")
icon:SetTexture("Interface\\Icons\\Spell_Holy_Silence")
icon:SetSize(21, 21)
icon:SetPoint("CENTER", 0, 0)

local border = minimapButton:CreateTexture(nil, "OVERLAY")
border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
border:SetSize(56, 56)
border:SetPoint("TOPLEFT", 0, 0)

local dragEndTime = 0

minimapButton:RegisterForDrag("LeftButton")
minimapButton:SetScript("OnDragStart", function(self)
    self:StartMoving()
end)

minimapButton:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    dragEndTime = GetTime()
    local point, _, relativePoint, xOfs, yOfs = self:GetPoint()
    if type(MuteChatDB) ~= "table" then
        MuteChatDB = {}
    end
    MuteChatDB.position = {
        point = point,
        relativePoint = relativePoint,
        x = xOfs,
        y = yOfs,
    }
end)

minimapButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
minimapButton:SetScript("OnClick", function(self, button)
    -- Prevent click action immediately after dragging
    if (GetTime() - dragEndTime) < 0.15 then return end

    if button == "LeftButton" then
        if IsShiftKeyDown() then
            -- Shift + Left Click: opens/toggles log
            if LogFrame:IsShown() then
                LogFrame:Hide()
            else
                LogFrame:Show()
            end
        else
            -- Normal Left Click: opens/toggles options
            if OptionsFrame:IsShown() then
                OptionsFrame:Hide()
            else
                OptionsFrame:Show()
            end
        end
    elseif button == "RightButton" then
        MuteChatDB.enabled = not MuteChatDB.enabled
        enableCheckbox:SetChecked(MuteChatDB.enabled)
        print("|cff00ffffMuteChat:|r " .. (MuteChatDB.enabled and "|cff00ff00Enabled|r" or "|cffff0000Disabled|r"))
    end
end)

minimapButton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText("Mute Chat", 1, 1, 1)
    GameTooltip:AddLine("Left-Click: Open Options", 0.9, 0.9, 0.9)
    GameTooltip:AddLine("Shift + Left-Click: Open Log", 0.9, 0.9, 0.9)
    GameTooltip:AddLine("Right-Click: Toggle On/Off", 0.9, 0.9, 0.9)
    GameTooltip:AddLine("Drag: Move Anywhere", 0.6, 0.6, 0.6)
    GameTooltip:Show()
end)
minimapButton:SetScript("OnLeave", function() GameTooltip:Hide() end)

local function RestorePosition()
    if MuteChatDB and MuteChatDB.position and type(MuteChatDB.position) == "table" and MuteChatDB.position.point then
        minimapButton:ClearAllPoints()
        minimapButton:SetPoint(
            MuteChatDB.position.point,
            UIParent,
            MuteChatDB.position.relativePoint or MuteChatDB.position.point,
            MuteChatDB.position.x or 0,
            MuteChatDB.position.y or 0
        )
    else
        minimapButton:ClearAllPoints()
        minimapButton:SetPoint("TOPRIGHT", Minimap, "TOPLEFT", -10, 0)
    end
end

resetPosButton:SetScript("OnClick", function()
    if type(MuteChatDB) == "table" then
        MuteChatDB.position = nil
    end
    RestorePosition()
    print("|cff00ffffMuteChat:|r Icon position reset.")
end)

-- 6. Addon Initialization & Data Persistence
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", function(self, event, addon)
    if addon == ADDON_NAME then
        if type(MuteChatDB) ~= "table" then
            MuteChatDB = { enabled = true }
        end
        if MuteChatDB.enabled == nil then
            MuteChatDB.enabled = true
        end
        enableCheckbox:SetChecked(MuteChatDB.enabled)
        RestorePosition()
    end
end)

-- 7. Hooking the Chat Filter
local function ChatFilter(self, event, msg, author, ...)
    if not MuteChatDB.enabled then return false end
    if type(msg) == "string" and ContainsAsianCharacters(msg) then
        AddToLog(date("%H:%M:%S"), author, msg)
        return true -- Returning true intercepts and mutes the message
    end
    return false
end

-- Hook all relevant chat channels
local chatEvents = {
    "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_CHANNEL", "CHAT_MSG_GUILD", 
    "CHAT_MSG_WHISPER", "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER", 
    "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER", "CHAT_MSG_INSTANCE_CHAT"
}
for _, event in ipairs(chatEvents) do
    ChatFrame_AddMessageEventFilter(event, ChatFilter)
end