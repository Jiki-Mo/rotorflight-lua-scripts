local template = assert(rf2.loadScript(rf2.radio.template))()
local margin = template.margin
local indent = template.indent
local lineSpacing = template.lineSpacing
local tableSpacing = template.tableSpacing
local sp = template.listSpacing.field
local yMinLim = rf2.radio.yMinLimit
local x = margin
local y = yMinLim - lineSpacing
local inc = {
    x = function(val)
        x = x + val
        return x
    end,
    y = function(val)
        y = y + val
        return y
    end
}
local labels = {}
local fields = {}

local statusOptions = { [0] = "Disable", "Enable" }
local govMode = { [0] = "Ext Governor", "Esc Governor" }
local becVoltage = { [0] = "Disable", "7.5V", "8.0V", "8.5V", "12.0V" }
local motorDirection = { [0] = "CW", "CCW" }
local fanControl = { [0] = "Automatic", "Always On" }
local currentGain = {
    [0] = "-20",
    "-19",
    "-18",
    "-17",
    "-16",
    "-15",
    "-14",
    "-13",
    "-12",
    "-11",
    "-10",
    "-9",
    "-8",
    "-7",
    "-6",
    "-5",
    "-4",
    "-3",
    "-2",
    "-1",
    "0",
    "1",
    "2",
    "3",
    "4",
    "5",
    "6",
    "7",
    "8",
    "9",
    "10",
    "11",
    "12",
    "13",
    "14",
    "15",
    "16",
    "17",
    "18",
    "19",
    "20"
}
local thrProtocol = { [0] = "PWM", "DSHOT", "Serial Port" }
local teleProtocol = { [0] = "FLYROTOR", "SBUS2" }
local tblLed = {
    [0] = "CUSTOM",
    "BLACK",
    "RED",
    "GREEN",
    "BLUE",
    "YELLOW",
    "MAGENTA",
    "CYAN",
    "WHITE",
    "ORANGE",
    "GRAY",
    "MAROON",
    "DARK_GREEN",
    "NAVY",
    "PURPLE",
    "TEAL",
    "SILVER",
    "PINK",
    "GOLD",
    "BROWN",
    "LIGHT_BLUE",
    "FL_PINK",
    "FL_ORANGE",
    "FL_LIME",
    "FL_MINT",
    "FL_CYAN",
    "FL_PURPLE",
    "FL_HOT_PINK",
    "FL_LIGHT_YELLOW",
    "FL_AQUAMARINE",
    "FL_GOLD",
    "FL_DEEP_PINK",
    "FL_NEON_GREEN",
    "FL_ORANGE_RED"
}

local function getUInt(page, vals)
    local v = 0
    for idx = 1, #vals do
        local raw_val = page.values[vals[idx] + 2] or 0
        raw_val = bit32.lshift(raw_val, (idx - 1) * 8)
        v = bit32.bor(v, raw_val)
    end
    return v
end

local function getPageValue(page, index)
    return page.values[2 + index]
end

labels[#labels + 1] = { t = "ESC not ready, waiting...", x = x, y = inc.y(lineSpacing) }
labels[#labels + 1] = { t = "---", x = x + indent, y = inc.y(lineSpacing), bold = false }
labels[#labels + 1] = { t = "---", x = x + indent, y = inc.y(lineSpacing), bold = false }
labels[#labels + 1] = { t = "---", x = x + indent, y = inc.y(lineSpacing), bold = false }

-- Basic
labels[#labels + 1] = { t = "Basic",                x = x, y = inc.y(lineSpacing) }
fields[#fields + 1] = { t = "ESC Mode",             x = x + indent, y = inc.y(lineSpacing), sp = x + sp, min = 0, max = #govMode, vals = { 2 + 23 }, table = govMode }
fields[#fields + 1] = { t = "Cell Count [S]",       x = x + indent, y = inc.y(lineSpacing), sp = x + sp, min = 4, max = 14, vals = { 2 + 24 } }
fields[#fields + 1] = { t = "BEC Voltage",          x = x + indent, y = inc.y(lineSpacing), sp = x + sp, min = 0, max = #becVoltage, vals = { 2 + 27 }, tableIdxInc = -1, table = becVoltage }
fields[#fields + 1] = { t = "Motor direction",      x = x + indent, y = inc.y(lineSpacing), sp = x + sp, min = 0, max = #motorDirection, vals = { 2 + 29 }, tableIdxInc = -1, table = motorDirection }
fields[#fields + 1] = { t = "Soft start [S]",       x = x + indent, y = inc.y(lineSpacing), sp = x + sp, min = 5, max = 55, vals = { 2 + 35 } }
fields[#fields + 1] = { t = "Fan control",          x = x + indent, y = inc.y(lineSpacing), sp = x + sp, min = 0, max = #fanControl, vals = { 2 + 34 }, table = fanControl }

-- Advanced
labels[#labels + 1] = { t = "Advanced",             x = x, y = inc.y(lineSpacing) }
fields[#fields + 1] = { t = "Low voltage [V]",      x = x + indent, y = inc.y(lineSpacing), sp = x + sp, min = 28, max = 38, scale = 10, default = 30, decimals = 1, vals = { 2 + 25 } }
fields[#fields + 1] = { t = "Temperature [C]",      x = x + indent, y = inc.y(lineSpacing), sp = x + sp, min = 50, max = 135, default = 125, vals = { 2 + 26 } }
fields[#fields + 1] = { t = "Timing angle",         x = x + indent, y = inc.y(lineSpacing), sp = x + sp, min = 1, max = 10, default = 5, vals = { 2 + 28 } }
fields[#fields + 1] = { t = "Starting torque",      x = x + indent, y = inc.y(lineSpacing), sp = x + sp, min = 1, max = 15, default = 3, vals = { 2 + 30 } }
fields[#fields + 1] = { t = "Response speed",       x = x + indent, y = inc.y(lineSpacing), sp = x + sp, min = 1, max = 15, default = 5, vals = { 2 + 31 } }
fields[#fields + 1] = { t = "Buzzer volume",        x = x + indent, y = inc.y(lineSpacing), sp = x + sp, min = 1, max = 5, default = 2, vals = { 2 + 32 } }
fields[#fields + 1] = { t = "Current gain",         x = x + indent, y = inc.y(lineSpacing), sp = x + sp, min = 0, max = #currentGain, default = 20, vals = { 2 + 33 }, table = currentGain }

-- Esc Governor
labels[#labels + 1] = { t = "Esc Governor",         x = x, y = inc.y(lineSpacing) }
fields[#fields + 1] = { t = "Gov P-Gain",           x = x + indent, y = inc.y(lineSpacing), sp = x + sp, min = 1, max = 100, default = 45, vals = { 2 + 37, 2 + 36 } }
fields[#fields + 1] = { t = "Gov I-Gain",           x = x + indent, y = inc.y(lineSpacing), sp = x + sp, min = 1, max = 100, default = 35, vals = { 2 + 39, 2 + 38 } }
fields[#fields + 1] = { t = "Gov D-Gain",           x = x + indent, y = inc.y(lineSpacing), sp = x + sp, min = 0, max = 100, default = 0, vals = { 2 + 41, 2 + 40 } }
fields[#fields + 1] = { t = "Motor ERPM Max",       x = x + indent, y = inc.y(lineSpacing), sp = x + sp, min = 0, max = 1000000, default = 100000, mult = 100, vals = { 2 + 44, 2 + 43, 2 + 42 } }

-- Other
labels[#labels + 1] = { t = "Other",                x = x, y = inc.y(lineSpacing) }
fields[#fields + 1] = { t = "Throttle Protocol",    x = x + indent, y = inc.y(lineSpacing), sp = x + sp, min = 0, max = #thrProtocol, vals = { 2 + 45 }, table = thrProtocol }
fields[#fields + 1] = { t = "Tele Protocol",        x = x + indent, y = inc.y(lineSpacing), sp = x + sp, min = 0, max = #teleProtocol, vals = { 2 + 46 }, table = teleProtocol }
fields[#fields + 1] = { t = "LED color",            x = x + indent, y = inc.y(lineSpacing), sp = x + sp, min = 0, max = #tblLed, vals = { 2 + 47 }, table = tblLed }
fields[#fields + 1] = { t = "Motor temp sensor",    x = x + indent, y = inc.y(lineSpacing), sp = x + sp, min = 0, max = #statusOptions, vals = { 2 + 51 }, table = statusOptions }
fields[#fields + 1] = { t = "Motor temperture",     x = x + indent, y = inc.y(lineSpacing), sp = x + sp, min = 50, max = 175, default = 100, vals = { 2 + 52 } }
fields[#fields + 1] = { t = "Capacity Cut-off",     x = x + indent, y = inc.y(lineSpacing), sp = x + sp, min = 0, max = 10000, default = 0, mult = 100, vals = { 2 + 54, 2 + 53 } }

return {
    read              = 217, -- MSP_ESC_PARAMETERS
    write             = 218, -- MSP_SET_ESC_PARAMETERS
    eepromWrite       = false,
    reboot            = false,
    title             = "FLYROTOR Setup",
    minBytes          = 46,
    labels            = labels,
    fields            = fields,
    readOnly          = true,
    simulatorResponse = { 115, 0, 0, 1, 24, 231, 79, 190, 216, 78, 29, 169, 244, 1, 0, 0, 1, 0, 2, 0, 4, 76, 7, 148, 0, 6, 30, 125, 1, 15, 0, 3, 15, 1, 20, 0, 10, 0, 45, 0, 35, 0, 10, 0, 150, 0, 0, 0, 3, 0, 0, 0, 0, 100, 0, 0 },

    postRead          = function(self)
        if self.values[1] ~= 0x73 then -- FLYROTOR signature
            self.values = nil
            self.labels[1].t = "Invalid ESC detected"
            return -1
        end
        -- The read-only flag is set when the ESC is connected to an RX pin instead of a TX pin in half-duplex mode. Only supported by YGE.
        self.readOnly = bit32.band(self.values[2], 0x40) == 0x40
    end,

    postLoad          = function(self)
        -- MODLE
        local l = self.labels[1]
        l.t = "FLYROTOR " .. getUInt(self, { 3, 2 }) .. "A"
        -- SN
        l = self.labels[2]
        l.t = "SN: " .. string.format("%08X", getUInt(self, { 7, 6, 5, 4 })) .. string.format("%08X", getUInt(self, { 11, 10, 9, 8 }))

        -- HW version + IAP
        l = self.labels[3]
        l.t = "HW: " .. "1." .. getPageValue(self, 18) .. " - IAP: " .. getPageValue(self, 12) .. "." .. getPageValue(self, 13) .. "." .. getPageValue(self, 14)

        -- FW ver
        l = self.labels[4]
        l.t = "FW: " .. getPageValue(self, 15) .. "." .. getPageValue(self, 16) .. "." .. getPageValue(self, 17)

        -- enable 'Save Page'
        self.readOnly = false
    end,
}
