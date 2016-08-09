-- Brew Bot, a CO2 detecting fermentation monitor with the ESP8266
-- Author: Albert Santoni
-- Licensed under the MIT License


print("Did you disconnect the CO2 sensor power rail? DO IT otherwise you can't send commands (UART breaks)")
print("Waiting 5 seconds before bootup...")

-- You can cancel this with tmr.stop(0)
tmr.alarm(0,5000,0,function() 
    require("brewbot")
    startup()
end)



