local moduleName = ...

local M = {}
_G[moduleName] = M 


local backlight = 0
local PCF_ADDRESS = 0x27 -- This is 100% correct for mine
-- For more info on i2c addresses and board revisions, check this out:
-- https://arduino-info.wikispaces.com/LCD-Blue-I2C -- Albert!

local LSRS = 0 --regselect
local LSRW = 1 --readwrite
local LSE  = 2 --enable
local LSLED= 3 --led backlight
local LSDAT= 4 --data

function write(data)
    i2c.start(0)
    i2c.address(0,PCF_ADDRESS,i2c.TRANSMITTER) 
    i2c.write(0,data)
	i2c.stop(0)
end

local function sendLcdToI2C(rs, e, data)
	local value = bit.lshift(rs, LSRS)
    value = value + bit.lshift(e, LSE)
    value = value + bit.lshift(data, LSDAT)
    value = value + backlight
	write(value)
end

local function sendLcdRaw(rs, data)
	sendLcdToI2C(rs, 1, data)
	sendLcdToI2C(rs, 0, data)
end

local function sendLcd(rs, data)
	local hignib = bit.rshift(bit.band(data, 0xF0),4)
	local lownib = bit.band(data, 0x0F)
	sendLcdRaw(rs, hignib)
	sendLcdRaw(rs, lownib)
end

function M.begin(pinSDA,pinSCL)
	i2c.setup(0,pinSDA,pinSCL,i2c.SLOW)

			--setup done, reset
    sendLcdRaw(0, 0x03)
    tmr.delay(4500)
    sendLcdRaw(0, 0x03)
    tmr.delay(4500)
    sendLcdRaw(0, 0x03)
    tmr.delay(4500)
			--4bit
    sendLcdRaw(0, 0x02)
	tmr.delay(150)
			--5x8 and 2line
	sendLcd(0, 0x28)
	tmr.delay(70)
			--dispoff
    sendLcdRaw(0, 0x08)
	tmr.delay(70)
			--entryset
    sendLcdRaw(0, 0x06)
	tmr.delay(70)
			--clear
    sendLcd(0, 0x01)
	tmr.delay(70)
			--dispon
    sendLcd(0, 0x0C)
	tmr.delay(70)
end

function M.write(ch)
    sendLcd(1, string.byte(ch, 1))
end

function M.print(s)
    for i = 1, #s do
        sendLcd(1, string.byte(s, i))
    end
end

M.ROW_OFFSETS = {0, 0x40, 0x14, 0x54}

function M.setCursor(col, row)
    local val = bit.bor(0x80, col, M.ROW_OFFSETS[row + 1])
    sendLcd(0, val)
end

function M.setBacklight(b)
    backlight = bit.lshift(b, LSLED)
    write(backlight)
end

return M
