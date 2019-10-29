local pageStatus =
{
    display     = 2,
    editing     = 3,
    saving      = 4,
    popupMenu   = 5,
    mainMenu    = 6,
}

local uiMsp =
{
    reboot = 68,
    eepromWrite = 250
}

local menuLine = 1
local pageCount = 1
local currentState = pageStatus.mainMenu
local requestTimeout = 80 -- 800ms request timeout
local currentPage = 1
local currentLine = 1
local saveTS = 0
local saveTimeout = 0
local saveRetries = 0
local saveMaxRetries = 0
local pageRequested = false
local telemetryScreenActive = false
local popupMenuActive = false
local lastRunTS = 0
local killEnterBreak = 0
local stopDisplay = true
local scrollPixelsY = 0

local Page = nil

local backgroundFill = TEXT_BGCOLOR or ERASE
local foregroundColor = LINE_COLOR or SOLID

local globalTextOptions = TEXT_COLOR or 0

local function getPageCount()
    pageCount = 0
    for i=1,#(PageFiles) do
        if (not PageFiles[i].requiredVersion) or (apiVersion == 0) or (apiVersion > 0 and PageFiles[i].requiredVersion < apiVersion) then
            pageCount = pageCount + 1
        end
    end
end

local function saveSettings(new)
    if Page.values then
        if Page.preSave then
            payload = Page.preSave(Page)
        else
            payload = {}
            for i=1,(Page.outputBytes or #Page.values) do
                payload[i] = Page.values[i]
            end
        end
        protocol.mspWrite(Page.write, payload)
        saveTS = getTime()
        if currentState == pageStatus.saving then
            saveRetries = saveRetries + 1
        else
            currentState = pageStatus.saving
            saveRetries = 0
            saveMaxRetries = protocol.saveMaxRetries or 2 -- default 2
            saveTimeout = protocol.saveTimeout or 150     -- default 1.5s
        end
    end
end

local function invalidatePages()
    Page = nil
    currentState = pageStatus.display
    saveTS = 0
    collectgarbage()
end

local function rebootFc()
    protocol.mspRead(uiMsp.reboot)
    invalidatePages()
end

local function eepromWrite()
    protocol.mspRead(uiMsp.eepromWrite)
end

local popupMenuList = {
    {
        t = "save page",
        f = saveSettings
    },
    {
        t = "reload",
        f = invalidatePages
    },
    {
        t = "reboot",
        f = rebootFc
    }
}

local function processMspReply(cmd,rx_buf)
    if cmd == nil or rx_buf == nil then
        return
    end
    if cmd == Page.write then
        if Page.eepromWrite then
            eepromWrite()
        else
            invalidatePages()
        end
        pageRequested = false
        return
    end
    if cmd == uiMsp.eepromWrite then
        if Page.reboot then
            rebootFc()
        end
        invalidatePages()
        return
    end
    if cmd ~= Page.read then
        return
    end
    if #(rx_buf) > 0 then
        Page.values = {}
        for i=1,#(rx_buf) do
            Page.values[i] = rx_buf[i]
        end

        for i=1,#(Page.fields) do
            if (#(Page.values) or 0) >= Page.minBytes then
                local f = Page.fields[i]
                if f.vals then
                    f.value = 0;
                    for idx=1, #(f.vals) do
                        local raw_val = (Page.values[f.vals[idx]] or 0)
                        raw_val = bit32.lshift(raw_val, (idx-1)*8)
                        f.value = bit32.bor(f.value, raw_val)
                    end
                    f.value = f.value/(f.scale or 1)
                end
            end
        end
        if Page.postLoad then
            Page.postLoad(Page)
        end
    end
end

local function incMax(val, inc, base)
    return ((val + inc + base - 1) % base) + 1
end

local function incPage(inc)
    currentPage = incMax(currentPage, inc, #(PageFiles))
    Page = nil
    currentLine = 1
    collectgarbage()
end

local function incLine(inc)
    currentLine = clipValue(currentLine + inc, 1, #(Page.fields))
end

local function incMainMenu(inc)
    menuLine = clipValue(menuLine + inc, 1, pageCount)
end

local function incPopupMenu(inc)
    popupMenuActive = clipValue(popupMenuActive + inc, 1, #(popupMenuList))
end

local function requestPage()
    if Page.read and ((Page.reqTS == nil) or (Page.reqTS + requestTimeout <= getTime())) then
        Page.reqTS = getTime()
        protocol.mspRead(Page.read)
    end
end

function drawScreenTitle(screen_title)
    if radio.resolution == lcdResolution.low then
        lcd.drawFilledRectangle(0, 0, LCD_W, 10)
        lcd.drawText(1,1,screen_title,INVERS)
    else
        lcd.drawFilledRectangle(0, 0, LCD_W, 30, TITLE_BGCOLOR)
        lcd.drawText(5,5,screen_title, MENU_TITLE_COLOR)
    end
end

local function drawScreen()
    local yMinLim = radio.yMinLimit or 0
    local yMaxLim = radio.yMaxLimit or LCD_H
    local currentLineY = Page.fieldLayout[currentLine].y
    local screen_title = Page.title
    drawScreenTitle("Betaflight / "..screen_title)
    if currentLineY <= Page.fieldLayout[1].y then
        scrollPixelsY = 0
    elseif currentLineY - scrollPixelsY <= yMinLim then
        scrollPixelsY = currentLineY - yMinLim
    elseif currentLineY - scrollPixelsY >= yMaxLim then
        scrollPixelsY = currentLineY - yMaxLim
    end
    for i=1,#(Page.labels) do
        local f = Page.labels[i]
        local textOptions = radio.textSize + globalTextOptions
        if (f.y - scrollPixelsY) >= yMinLim and (f.y - scrollPixelsY) <= yMaxLim then
            lcd.drawText(f.x, f.y - scrollPixelsY, f.t, textOptions)
        end
    end
    local val = "---"
    for i=1,#(Page.fields) do
        local f = Page.fields[i]
        local pos = Page.fieldLayout[i]
        local text_options = radio.textSize + globalTextOptions
        local heading_options = text_options
        local value_options = text_options
        if i == currentLine then
            value_options = text_options + INVERS
            if currentState == pageStatus.editing then
                value_options = value_options + BLINK
            end
        end 
        if f.value then
            if f.upd and Page.values then
                f.upd(Page)
            end
            val = f.value
            if f.table and f.table[f.value] then
                val = f.table[f.value]
            end
        end
        if (pos.y - scrollPixelsY) >= yMinLim and (pos.y - scrollPixelsY) <= yMaxLim then
            lcd.drawText(pos.x, pos.y - scrollPixelsY, val, value_options)
        end
    end
end

function clipValue(val,min,max)
    if val < min then
        val = min
    elseif val > max then
        val = max
    end
    return val
end

local function getCurrentField()
    return Page.fields[currentLine]
end

local function incValue(inc)
    local f = Page.fields[currentLine]
    local idx = f.i or currentLine
    local scale = (f.scale or 1)
    local mult = (f.mult or 1)
    f.value = clipValue(f.value + ((inc*mult)/scale), (f.min/scale) or 0, (f.max/scale) or 255)
    f.value = math.floor((f.value*scale)/mult + 0.5)/(scale/mult)
    for idx=1, #(f.vals) do
        Page.values[f.vals[idx]] = bit32.rshift(math.floor(f.value*scale + 0.5), (idx-1)*8)
    end
    if f.upd and Page.values then
        f.upd(Page)
    end
end

local function drawPopupMenu()
    local x = radio.MenuBox.x
    local y = radio.MenuBox.y
    local w = radio.MenuBox.w
    local h_line = radio.MenuBox.h_line
    local h_offset = radio.MenuBox.h_offset
    local h = #(popupMenuList) * h_line + h_offset*2

    lcd.drawFilledRectangle(x,y,w,h,backgroundFill)
    lcd.drawRectangle(x,y,w-1,h-1,foregroundColor)
    lcd.drawText(x+h_line/2,y+h_offset,"Menu:",globalTextOptions)

    for i,e in ipairs(popupMenuList) do
        local text_options = globalTextOptions
        if popupMenuActive == i then
            text_options = text_options + INVERS
        end
        lcd.drawText(x+radio.MenuBox.x_offset,y+(i-1)*h_line+h_offset,e.t,text_options)
    end
end

function run_ui(event)
    getPageCount()
    local now = getTime()
    -- if lastRunTS old than 500ms
    if lastRunTS + 50 < now then
        invalidatePages()
        if isTelemetryScript then
            currentState = pageStatus.display
        else
            currentState = pageStatus.mainMenu
        end
    end
    lastRunTS = now
    if (currentState == pageStatus.saving) then
        if (saveTS + saveTimeout < now) then
            if saveRetries < saveMaxRetries then
                saveSettings()
            else
                -- max retries reached
                currentState = pageStatus.display
                invalidatePages()
            end
        end
    end
    -- process send queue
    mspProcessTxQ()
    -- navigation
    if isTelemetryScript and event == EVT_VIRTUAL_MENU_LONG then -- telemetry script
        popupMenuActive = 1
        currentState = pageStatus.popupMenu
    elseif (not isTelemetryScript) and event == EVT_VIRTUAL_ENTER_LONG then -- standalone
        popupMenuActive = 1
        killEnterBreak = 1
        currentState = pageStatus.popupMenu
    -- menu is currently displayed
    elseif currentState == pageStatus.popupMenu then
        if event == EVT_VIRTUAL_EXIT then
            currentState = pageStatus.display
        elseif event == EVT_VIRTUAL_PREV then
            incPopupMenu(-1)
        elseif event == EVT_VIRTUAL_NEXT then
            incPopupMenu(1)
        elseif event == EVT_VIRTUAL_ENTER then
            if killEnterBreak == 1 then
                killEnterBreak = 0
            else
                currentState = pageStatus.display
                popupMenuList[popupMenuActive].f()
            end
        end
    -- normal page viewing
    elseif currentState <= pageStatus.display then
        if not isTelemetryScript and event == EVT_VIRTUAL_PREV_PAGE then
            incPage(-1)
            killEvents(event) -- X10/T16 issue: pageUp is a long press
        elseif (not isTelemetryScript and event == EVT_VIRTUAL_NEXT_PAGE) or (isTelemetryScript and event == EVT_VIRTUAL_MENU) then
            incPage(1)
        elseif event == EVT_VIRTUAL_PREV or event == EVT_VIRTUAL_PREV_REPT then
            incLine(-1)
        elseif event == EVT_VIRTUAL_NEXT or event == EVT_VIRTUAL_NEXT_REPT then
            incLine(1)
        elseif event == EVT_VIRTUAL_ENTER then
            local field = Page.fields[currentLine]
            local idx = field.i or currentLine
            if Page.values and Page.values[idx] and (field.ro ~= true) then
                currentState = pageStatus.editing
            end
        elseif event == EVT_VIRTUAL_EXIT then
            if isTelemetryScript then 
                return protocol.exitFunc();
            else
                stopDisplay = true
            end
        end
    -- editing value
    elseif currentState == pageStatus.editing then
        if event == EVT_VIRTUAL_EXIT or event == EVT_VIRTUAL_ENTER then
            currentState = pageStatus.display
        elseif event == EVT_VIRTUAL_INC or event == EVT_VIRTUAL_INC_REPT then
            incValue(1)
        elseif event == EVT_VIRTUAL_DEC or event == EVT_VIRTUAL_DEC_REPT then
            incValue(-1)
        end
    end
    local nextPage = currentPage
    while Page == nil do
        Page = assert(loadScript(SCRIPT_HOME.."/Pages/"..PageFiles[currentPage].script))()
        if Page.requiredVersion and apiVersion > 0 and Page.requiredVersion > apiVersion then
            incPage(1)
            if currentPage == nextPage then
                lcd.clear()
                lcd.drawText(radio.NoTelem[1], radio.NoTelem[2], "No Pages! API: " .. apiVersion, radio.NoTelem[4])
                return 1
            end
        end
    end
    if not Page.values and currentState == pageStatus.display then
        requestPage()
    end
    lcd.clear()
    if TEXT_BGCOLOR then
        lcd.drawFilledRectangle(0, 0, LCD_W, LCD_H, TEXT_BGCOLOR)
    end
    drawScreen()
    if protocol.rssi() == 0 then
        lcd.drawText(radio.NoTelem[1],radio.NoTelem[2],radio.NoTelem[3],radio.NoTelem[4])
    end
    if currentState == pageStatus.popupMenu then
        drawPopupMenu()
    elseif currentState == pageStatus.saving then
        lcd.drawFilledRectangle(radio.SaveBox.x,radio.SaveBox.y,radio.SaveBox.w,radio.SaveBox.h,backgroundFill)
        lcd.drawRectangle(radio.SaveBox.x,radio.SaveBox.y,radio.SaveBox.w,radio.SaveBox.h,SOLID)
        if saveRetries <= 0 then
            lcd.drawText(radio.SaveBox.x+radio.SaveBox.x_offset,radio.SaveBox.y+radio.SaveBox.h_offset,"Saving...",DBLSIZE + BLINK + (globalTextOptions))
        else
            lcd.drawText(radio.SaveBox.x+radio.SaveBox.x_offset,radio.SaveBox.y+radio.SaveBox.h_offset,"Retrying",DBLSIZE + (globalTextOptions))
        end
    end
    if currentState == pageStatus.mainMenu and (not isTelemetryScript) then
        if event == EVT_VIRTUAL_EXIT then
            return 2
        elseif event == EVT_VIRTUAL_NEXT then
            incMainMenu(1)
        elseif event == EVT_VIRTUAL_PREV then
            incMainMenu(-1)
        end
        lcd.clear()
        drawScreenTitle("Betaflight Config", 0, 0)
        local yMinLim = radio.yMinLimit
        local yMaxLim = radio.yMaxLimit
        local lineSpacing = 10
        if radio.resolution == lcdResolution.high then
            lineSpacing = 25
        end
        for i=1, #PageFiles do
            if (not PageFiles[i].requiredVersion) or (apiVersion == 0) or (apiVersion > 0 and PageFiles[i].requiredVersion < apiVersion) then
                local currentLineY = (menuLine-1)*lineSpacing + yMinLim + 1
                if currentLineY <= yMaxLim then
                    scrollPixelsY = 0
                elseif currentLineY - scrollPixelsY <= yMinLim then
                    scrollPixelsY = currentLineY - yMinLim
                elseif currentLineY - scrollPixelsY >= yMaxLim then
                    scrollPixelsY = currentLineY - yMaxLim
                end
                local attr = (menuLine == i and INVERS or 0)
                if event == EVT_VIRTUAL_ENTER and attr == INVERS then
                    invalidatePages()
                    currentPage = i
                    currentState = pageStatus.display
                end
                if ((i-1)*lineSpacing + yMinLim - scrollPixelsY) >= yMinLim and ((i-1)*lineSpacing + yMinLim - scrollPixelsY) <= yMaxLim then
                    lcd.drawText(6, (i-1)*lineSpacing + yMinLim - scrollPixelsY, PageFiles[i].title, attr)
                end
            end
        end
    end
    if stopDisplay and (not isTelemetryScript) then
        currentLine = 1
        currentState = pageStatus.mainMenu
        stopDisplay = false
        collectgarbage()
    end
    processMspReply(mspPollReply())
    return 0
end

return run_ui
