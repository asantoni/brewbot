# Brew Bot
## An ESP8266-based Kombucha Fermentation Monitor


### Features
* CO2 concentration sensor (MH-Z19, 0-2000 PPM calibrated)
* OLED screen (SSD1331 96x64)
* Wifi
* Simple web interface with mDNS (http://brewbot.local on your LAN)
* Data logging to an InfluxDB server (viewable with Grafana)
* 24-hour, 7-day, and 14-day graphs pulled from InfluxDB queries


### About

**Brew Bot** was my excuse to build a cool IoT thingy with the ESP8266 chip, which is a $2 system-on-a-chip with WiFi. I used the NodeMCU firmware, which provides an embedded Lua runtime with an event-driven, asynchronous programming model similar to NodeJS. (This makes network programming a little easier and less error prone.)

My first revision used a [MG811 CO2 gas sensor](http://sandboxelectronics.com/files/SEN-000007/MG811.pdf), but after a lot of head scratching, I realized my sensor was DOA. I switched to the MH-Z19 and I'd wholeheartedly recommend using that instead, as it's easier to interface with anyways.

Data is logged to an InfluxDB server, which can be viewed from Grafana. Grafana is a visualization web app that provides an easy GUI for building dashboards and interactive plots. I use it to monitor CO2 levels over time.

Some simple graphs are also presented directly on the device's OLED screen, rotating every 15 seconds. Rather than computing these on-device, the calculated data is obtained via an InfluxDB query for simplicity, consistency, and easy tweaking. (eg. If I want to plot the derivative of my data instead, it's just a tiny adjustment.)



### ESP8266 Tips

* There are many subtly incorrect examples about how to make a webserver with NodeMCU out there - Use callbacks diligently!
* The 5V output on the ESP8266 has a very low current limit, so be careful when trying to power peripherals off of it.
* The chip only has one UART, so if you start using the RX/TX pins to interface with a peripheral, you're going to lose your serial console. As a workaround, you can implement a telnet interface (see my code), or just disable that peripheral when you need an interactive serial console.
* Be careful with the size of HTTP responses. I had to use pagination and make multiple GET requests to InfluxDB to get that graph data because otherwise I'd run out of memory (only 32 kB of heap).



### License

The MIT License (MIT)
Copyright (c) 2016 Albert Santoni

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.



