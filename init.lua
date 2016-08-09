-- Brew Bot, a CO2 detecting fermentation monitor with the ESP8266
-- Author: Albert Santoni
-- Licensed under the MIT License

function setupWifi()

    wifi.setmode(wifi.STATION)
        
    -- wifi.sta.eventMonReg(wifi.STA_CONNECTING, function() printCorner("Connecting to \n" .. ssid) end)
    -- wifi.sta.eventMonReg(wifi.STA_FAIL, function() printCorner("Wifi failed :(") end)

    wifi.sta.eventMonReg(wifi.STA_GOTIP, function() 
        print("Got an IP. Starting inet services...") 
        printCorner(wifi.sta.getip())
            
        -- Telnet disabled for security by default:
        --startTelnetServer()
        startWebServer()
        startInfluxClient()
    
        -- Make brewbot.local work in your web browser!
        mdns.register("brewbot", {description='Kombucha CO2 Sensor',
                      service="http", port=80})

        print("Wifi/internet online and ready!")

    end)

    -- Configure which AP we're connecting to.
    wifi.sta.config(ssid,ssid_password)
    
    -- Start monitoring events
    wifi.sta.eventMonStart()
    
    -- Connect and auto-connect if we disconnect for any reason
    wifi.sta.autoconnect(1)
    
    -- Power savings
    wifi.sleeptype(wifi.DEEP_SLEEP)
        
end


-- Don't use the local keyword if you want to check
-- these values from an interactive prompt like telnet or serial!
gas_conc = 0
raw_data = ""

-- Put these in secrets.lua. They're read in from readConfiguration().
ssid = ""
ssid_password = ""
influxdb_post_url = ""
influxdb_14day_get_url = ""
influxdb_7day_get_url = ""
influxdb_24hour_get_url = ""
influxdb_auth_header = ""



-- Telnet server for debugging since
-- the ESP8266 only has one UART and we need 
-- it for the CO2 sensor!
function startTelnetServer()

    srv=net.createServer(net.TCP,180)
    srv:listen(23,function(c) 
      c:on("receive",function(c,d) 
          -- switch to telnet service
          node.output(function(s)
            if c ~= nil then c:send(s) end
          end,0)
          c:on("receive",function(c,d)
            if d:byte(1) == 4 then c:close() -- ctrl-d to exit
            else node.input(d) end
          end)
          c:on("disconnection",function(c)
            node.output(nil)
          end)
          print("Welcome to BrewBot")
          node.input("\r\n")
          return
      end) 
    end)
end

function startWebServer()
  local srv = net.createServer(net.TCP, 30)
    srv:listen(80,function(conn)
        
        conn:on("receive",function(conn,payload) 
            -- print(payload) 
            httpResponse = ""
            httpResponse = httpResponse .. "HTTP/1.1 200 OK\r\n"
            httpResponse = httpResponse .. "Content-type: text/html\r\n"
            httpResponse = httpResponse .. "Connection: close\r\n\r\n"
            httpResponse = httpResponse .. "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\" />\r\n"
            httpResponse = httpResponse .. gas_conc .. " PPM\r\n"
            conn:send(httpResponse)
            -- conn:send("HTTP/1.1 200 OK\r\n\r\nConnection: close\r\n\r\n<h1> Hello: " .. temperature .. " degrees Celsius</h1>\r\n\r\n")
            -- conn:send("<h1> Hello: " .. temperature .. " degrees Celsius</h1>")
        end)
        conn:on("sent", function(conn)
            conn:close()
        end) 
    end)
end

-- Receive data on the UART, from the CO2 sensor
function initializeMHZ19UART()

-- FIXME: The 5V output from the Weemos can't supply
--        enough current to the MH-Z19 - switch to 
--        using an external power supply, split the 5V power,
--        and power the Weemos via its 5V pin.

    -- uart.alt(1)  -- Use GPIO13 and GPIO15 (pins D7 and D8 on Weemos)
    uart.setup(0, 9600, 8, uart.PARITY_NONE, uart.STOPBITS_1, 0)
    
    -- Write a test string to the CO2 sensor
    -- MH-Z19 strings are always 9 bytes
    --uart.write(0, 0xFF) -- Start byte
    --uart.write(0, 0x01) -- Sensor number
    --uart.write(0, 0x86) -- Command 
    --uart.write(0, 0x00) -- Byte 3 - unused
    --uart.write(0, 0x00) -- Byte 4 - unused
    --uart.write(0, 0x00) -- Byte 5 - unused
    --uart.write(0, 0x00) -- Byte 6 - unused
    --uart.write(0, 0x00) -- Byte 7 - unused
    --uart.write(0, 0x79) -- "Check value" checksum?
    
    -- TODO: When I print to the uart, the response comes back
    --       via the USB serial.... hmmm...

    uart.on("data", 9, function(data) 
        raw_data = data

        if string.byte(data, 1) == 0xFF and
           string.byte(data, 2) == 0x86 then
             high_level_conc = string.byte(data, 3)
             low_level_conc = string.byte(data, 4)
             gas_conc = high_level_conc * 256 + low_level_conc
        end
        foo = data
    end, 0)
    
    uart.write(0, 0xFF, 0x01, 0x86,0x00,0x00,0x00,0x00,0x00, 0x79)
    
end

-- Receive data on the UART, from the CO2 sensor
function bind_uart()

    uart.on("data", 9, function(data) 
        raw_data = data

        if string.byte(data, 1) == 0xFF and
           string.byte(data, 2) == 0x86 then
             high_level_conc = string.byte(data, 3)
             low_level_conc = string.byte(data, 4)
             gas_conc = high_level_conc * 256 + low_level_conc
        end
        foo = data
    end, 0)
    
    uart.write(0, 0xFF, 0x01, 0x86,0x00,0x00,0x00,0x00,0x00, 0x79)
    
    -- Warning: Just running uart.on("data") to unregister causes a crash?
end
 
 
-- Poll the CO2 sensor via the UART interface.
function startCO2PollTimer()
    tmr.alarm(1, 1000, tmr.ALARM_AUTO, function()
        -- Ask the MH-Z19 for the CO2 concentration
        uart.write(0, 0xFF, 0x01, 0x86,0x00,0x00,0x00,0x00,0x00, 0x79)
    end)
end


-- Log our last CO2 concentration reading to InfluxDB every few seconds.
function startInfluxClient()
    tmr.alarm(2, 10000, tmr.ALARM_AUTO, function()
        -- Using task.post here for safety
        node.task.post(node.task.LOW_PRIORITY, function() 
            http.post(influxdb_post_url, influxdb_auth_header, 'co2_concentration,room=livingroom value=' .. gas_conc, 
                function(code, data) 
                    if code ~= 204 then
                        printCorner("Influx: " .. code) -- data
                    end 
            end)
        end)
    end)
end


-- Initialize the OLED display
function init_spi_display()

    -- Hardware SPI CLK  = GPIO14 (Huzzah) - IO 5 (ESP/D1 Mini)
    -- Hardware SPI MOSI = GPIO13 (Huzzah) - IO 7 (ESP/D1 Mini)
    -- Hardware SPI MISO = GPIO12 (not used)
    local cs = 1 -- GPIO5 (Huzzah) - IO 1 (ESP/D1 Mini)
    local dc = 2 -- GPIO4 (Huzzah) - IO 2 (ESP/D1 Mini)
    local res = 0 -- GPIO16 - IO 0 (ESP/D1 Mini)
    spi.setup(1, spi.MASTER, spi.CPOL_LOW, spi.CPHA_LOW, 8, 8)
    disp = ucg.ssd1331_18x96x64_uvis_hw_spi(cs, dc, res)

    -- disp:begin(ucg.FONT_MODE_TRANSPARENT)
    disp:begin(ucg.FONT_MODE_SOLID)
    disp:clearScreen()

    -- Fonts compiled in by default are:
    --  (run the test() function to see the list!)
    -- font_7x13B_tr
    -- font_helvB08_hr
    -- font_helvB10_hr
    -- font_helvB12_hr
    -- font_helvB18_hr
    -- font_ncenB24_tr
    -- font_ncenR12_tr
    -- font_ncenR14_hr
    disp:setFont(ucg.font_helvB08_hr);
    disp:setColor(255, 255, 255);
    disp:setColor(1, 0, 0,0);

    -- disp:setPrintPos(0, 64)
    -- disp:print("Hello!")
    printCorner("Brew Bot 1.0")

end


-- Prints a string to the center of the screen.
-- @param string String to draw on the screen.
function printCentered(string)
    local strWidth = disp:getStrWidth(string)
    local fontAscent = disp:getFontAscent()
    disp:setPrintPos(disp:getWidth()/2 - strWidth/2, 
                    disp:getHeight()/2 + fontAscent/2)
    disp:print(string)
end

-- Prints to the upper-left corner of the screen.
-- @param string String to draw on the screen.
function printCorner(string)
    local strWidth = disp:getStrWidth(string)
    local fontAscent = disp:getFontAscent()
    disp:setPrintPos(0, fontAscent)
    disp:print(string)
end

-- Reads your configuration from secrets.lua
function readConfiguration()
    require("secrets")
end


-- Draws a 14 day graph of CO2 levels
function draw14DayGraph()
    disp:clearScreen()
    fetchHistoricalData(influxdb_14day_get_url, 0, function() 
        printCentered("14 day")
    end)
end

-- Draws a 7 day graph of CO2 levels
function draw7DayGraph()
    disp:clearScreen()
    fetchHistoricalData(influxdb_7day_get_url, 0, function() 
        printCentered("7 day")
    end)
end

 -- Draws a 24 hour graph of CO2 levels
function draw24HourGraph()
    disp:clearScreen()
    fetchHistoricalData(influxdb_24hour_get_url, 0, function() 
        printCentered("24 hour")
    end)
end

-- Main loop 
function displayLoop()

    mode = 0;
    local numModes = 4;

    disp:clearScreen()
    printCentered(gas_conc .. " PPM")
            
    tmr.alarm(3, 15000, tmr.ALARM_AUTO, function()
        if mode == 0 then
            disp:clearScreen()
            printCentered(gas_conc .. " PPM")
        elseif mode == 1 then 
            draw14DayGraph() 
        elseif mode == 2 then
            draw7DayGraph()
        elseif mode == 3 then 
            draw24HourGraph()
        end
        
        mode = (mode + 1) % numModes
    end)
end

function startScreenDrawLoop()
    tmr.alarm(3, 5000, tmr.ALARM_AUTO, function()
        printCentered(gas_conc .. " PPM")
    end)
end


-- Fetch historical data from InfluxDB and graph it on the OLED screen.
-- @param url The InfluxDB URL to fetch data from. Includes the query! (string)
-- @param offset Pagination offset (int)
-- @param finishedCallback A callback function to call once complete (function object)
function fetchHistoricalData(url, offset, finishedCallback)
   local QUERY_LIMIT = 16
   local SCREEN_HEIGHT = 64
   local SCREEN_WIDTH = 96
   local MAX_DATA_POINTS = 84
   local CO2_MAX_CONCENTRATION = 2000.0
   
   -- 14 days * 24 hours / 4 hours per data point = 84
   http.get(url .. "OFFSET%20" .. offset, influxdb_auth_header, 
        function(code, data) 
            if code == 200 then
                            
                local data = cjson.decode(data)
                -- for k,v in pairs(data["results"][1]["series"][1]["values"]) do print(k,v) end
                
                local lastPixelY = SCREEN_HEIGHT-1
                -- Print the date range at the top?
                
                local dataCount = 0
                for k,v in pairs(data["results"][1]["series"][1]["values"]) do
                    -- print(k, v[1], v[2])
                    
                    local pixelY = SCREEN_HEIGHT-math.floor(v[2] / CO2_MAX_CONCENTRATION * SCREEN_HEIGHT)
                    -- print(offset+k, pixelY)
                    --disp:drawPixel(offset+k, pixelY)
                    
                    disp:setColor(30, 30, 128)
                    disp:drawLine(offset+k, SCREEN_HEIGHT, 
                                  offset+k, pixelY)

                    
                    disp:setColor(80, 80, 256)
                    disp:drawPixel(offset+k, pixelY)
                    
                    lastPixelY = pixelY
                    dataCount = dataCount + 1
                end
                
                if offset + dataCount < MAX_DATA_POINTS then
                    node.task.post(node.task.LOW_PRIORITY, function() 
                        fetchHistoricalData(url, offset + QUERY_LIMIT, finishedCallback)
                    end)
               else
                    finishedCallback()
               end
            else
                -- print(code, data)
                finishedCallback()
            end
    end)
end


-- Initialize all the peripherals and start the main loop.
function startup()

    -- To inhibit startup, in the 5 second waiting period either run:
    --   file.remove("init.lua")
    --   or abort=true
    print('In startup')
    if abort == true then
        print("Startup aborted")
        return
    end

    readConfiguration()
    initializeMHZ19UART()
    -- bind_uart()
    startCO2PollTimer()
    
    init_spi_display()

    -- Webserver + Influx client are started when we get an IP. See this function:
    setupWifi()

    displayLoop()

end

print("Did you disconnect the CO2 sensor power rail? DO IT otherwise you can't send commands (UART breaks)")
print("Waiting 5 seconds before bootup...")
tmr.alarm(0,5000,0,startup)



