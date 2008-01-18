
--[[
=head1 NAME

applets.Test.TestApplet - User Interface Tests

=head1 DESCRIPTION

This applets is used to test and demonstrate the jive.ui.* stuff.

=head1 FUNCTIONS

Applet related methods are described in L<jive.Applet>. 
TestApplet overrides the following methods:

=cut
--]]


-- stuff we use
local setmetatable, tonumber, tostring, type = setmetatable, tonumber, tostring, type

local io                     = require("io")
local oo                     = require("loop.simple")
local math                   = require("math")
local string                 = require("string")
local table                  = require("jive.utils.table")

local Applet                 = require("jive.Applet")
local Audio                  = require("jive.ui.Audio")
local Checkbox               = require("jive.ui.Checkbox")
local Choice                 = require("jive.ui.Choice")
local Framework              = require("jive.ui.Framework")
local Icon                   = require("jive.ui.Icon")
local Label                  = require("jive.ui.Label")
local Popup                  = require("jive.ui.Popup")
local RadioButton            = require("jive.ui.RadioButton")
local RadioGroup             = require("jive.ui.RadioGroup")
local SimpleMenu             = require("jive.ui.SimpleMenu")
local Slider                 = require("jive.ui.Slider")
local Surface                = require("jive.ui.Surface")
local Textarea               = require("jive.ui.Textarea")
local Textinput              = require("jive.ui.Textinput")
local Window                 = require("jive.ui.Window")
local Timer                  = require("jive.ui.Timer")
local SocketUdp              = require("jive.net.SocketUdp")
local SocketTcp              = require("jive.net.SocketTcp")
local socket                 = require("socket")
local ltn12                  = require("ltn12")

local log                    = require("jive.utils.log").addCategory("test", jive.utils.log.DEBUG)

local EVENT_KEY_PRESS        = jive.ui.EVENT_KEY_PRESS
local EVENT_CONSUME          = jive.ui.EVENT_CONSUME
local KEY_BACK               = jive.ui.KEY_BACK
local KEY_GO                 = jive.ui.KEY_GO

local FRAME_RATE             = jive.ui.FRAME_RATE

local srf = nil
local window = nil
local width, height = Framework:getScreenSize()

-- The main NetworkThread
local jnt = jnt

local CALAOS_UDP_PORT = 4545
local CALAOS_CLI_PORT = 4456
local TIMEOUT = 60
local calaosd_ip = nil
local calaos_user = ""
local calaos_pass = ""
local wrong_user = false
local _applet = nil

module(...)
oo.class(_M, Applet)



function startApplet(self)

        _applet = self

        if _applet:getSettings().calaos_user ~= nil or _applet:getSettings().calaos_user ~= "" then
                calaos_user = _applet:getSettings().calaos_user
        end
        if _applet:getSettings().calaos_pass ~= nil or _applet:getSettings().calaos_pass ~= "" then
                calaos_pass = _applet:getSettings().calaos_pass
        end

        -- Discover the calaosd server
        Discover()

        self.window = self:newWindow()
        self:tieAndShowWindow(self.window)
        return self.window
end

function free()
        if csocket then
                csocket:free()
        end
end

function displayName(self)
        return "Calaos Home"
end

Sprite = oo.class()

function Sprite:__init(sw, sh, ifile)
        local imgSprite = nil
        local obj = oo.rawnew(self)
        if imgSprite == nil then
                imgSprite = Surface:loadImage(ifile)
        end

        obj.sprite = Icon("logo", imgSprite)

        local spritew, spriteh = imgSprite:getSize()
        obj.width = spritew
        obj.height = spriteh

        obj.screen_width = sw
        obj.screen_height = sh

        obj.x = obj.screen_width / 2 - obj.width / 2
        obj.y = obj.screen_height / 2 - obj.height / 2

        return obj
end

local function Sprite_draw(self)
        local sprite = self.sprite
        sprite:setPosition(self.x, self.y)
end
local function Sprite_draw_pos(self, x, y)
        local sprite = self.sprite
        self.x = x
        self.y = y
        sprite:setPosition(self.x, self.y)
end

function newWindow(self, ...)
        window = Window("window", self:displayName())

        srf = Surface:newRGBA(width, height)
        srf:filledRectangle(0, 0, width, height, 0x00000000)
        self.bg = Icon("background", srf)

        local start_snd = Audio:loadSound("applets/Calaos/calaos_start.wav", 0)
--         start_snd:play()

        window:addWidget(self.bg)

        local logo = Sprite(width, height, "applets/Calaos/graphics/logo.png")
        window:addWidget(logo.sprite)

        -- Back key
        window:addListener(EVENT_KEY_PRESS, 
                function(evt)
                        if evt:getKeycode() == KEY_BACK then
                                window:hide()
                                return EVENT_CONSUME
                        elseif evt:getKeycode() == KEY_GO then
                                self.timer:stop()
                                self:calaosMainmenu()
                                return EVENT_CONSUME
                        end
                end
        )

        self.bg:addAnimation(
                function()
                        Sprite_draw(logo)
                end,
                FRAME_RATE
        )

        self.timer = Timer(5000,
                        function()
                                self:calaosMainmenu()
                        end, true)
        self.timer:start()

        return window
end

function calaosMainmenu(self)

        local window = Window("window", self:displayName())

        local menu = SimpleMenu("big_menu", {
                {
                        text = "My Home",
                        icon = Icon("image", Surface:loadImage("applets/Calaos/graphics/home_icon.png")),
                        sound = "WINDOWSHOW",
                        callback = function(event, ...)

                        end
                },
                {
                        text = "Multimedia",
                        icon = Icon("image", Surface:loadImage("applets/Calaos/graphics/media_icon.png")),
                        sound = "WINDOWSHOW",
                        callback = function(event, ...)

                        end
                },
                {
                        text = "Configuration",
                        icon = Icon("image", Surface:loadImage("applets/Calaos/graphics/config_icon.png")),
                        sound = "WINDOWSHOW",
                        callback = function(event, ...)

                        end
                },
                {
                        text = "A propos",
                        icon = Icon("image", Surface:loadImage("applets/Calaos/graphics/about_icon.png")),
                        sound = "WINDOWSHOW",
                        callback = function(event, ...)
                                local window = Window("window", self:displayName())
                                local about_msg = Textarea("help", "Applet Calaos Home for Jive remotes.\n\nwww.calaos.fr\nCopyright 2008 Calaos")
                                local logo = Sprite(width, height, "applets/Calaos/logo.png")
                                window:addWidget(logo.sprite)
                                window:addWidget(about_msg)

                                window:addListener(EVENT_KEY_PRESS, 
                                        function(evt)
                                                if evt:getKeycode() == KEY_BACK then
                                                        window:hide()
                                                        return EVENT_CONSUME
                                                elseif evt:getKeycode() == KEY_GO then
                                                        window:bumpRight()
                                                        return EVENT_CONSUME
                                                end
                                        end
                                )

                                self:tieAndShowWindow(window)
                        end
                }
        })

        if calaosd_ip == nil then
                local error_msg = Textarea("help", "Aucun serveur domotique Calaos trouvé sur le réseau...\n\nVeuillez vérifier les paramètres Wifi et/ou réseau de votre installation.")

                local ierror = Sprite(width, height, "applets/Calaos/graphics/no-server.png")
                window:addWidget(ierror.sprite)
                window:addWidget(error_msg)

                local s = Surface:newRGBA(width, height)
                s:filledRectangle(0, 0, width, height, 0x00000000)
                local bg = Icon("background", s)
                window:addWidget(bg)

                bg:addAnimation(
                        function()
                                Sprite_draw_pos(ierror, width / 2 - ierror.width / 2, 50)
                        end,
                        FRAME_RATE
                )

                window:addListener(EVENT_KEY_PRESS, 
                        function(evt)
                                if evt:getKeycode() == KEY_BACK then
                                        window:hide()
                                        return EVENT_CONSUME
                                elseif evt:getKeycode() == KEY_GO then
                                        window:bumpRight()
                                        return EVENT_CONSUME
                                end
                        end
                )
        else
                if wrong_user == false then
                        log:error("Calaos:DEBUG : login success2")
                        window:addWidget(menu)
                else
                        local window_user = Window("window", "Nom d'utilisateur")
                        local v = Textinput.textValue(calaos_user, 2, 50)
                        local input = Textinput("textinput", v,
                                        function(_, value)
                                                log:info("Calaos Username: ", value)

                                                calaos_user = tostring(value)
                                                _applet:getSettings().calaos_user = calaos_user
                                                _applet:storeSettings()

                                                window_user:playSound("WINDOWSHOW")
                                                window_user:hide()

                                                local window_pass = Window("window", "Mot de passe")

                                                local v = Textinput.textValue(calaos_pass, 2, 50)
                                                local input = Textinput("textinput", v,
                                                                function(_, value)
                                                                        log:info("Calaos Password: ", value)

                                                                        calaos_pass = tostring(value)
                                                                        _applet:getSettings().calaos_pass = calaos_pass
                                                                        _applet:storeSettings()

                                                                        window_pass:playSound("WINDOWSHOW")
                                                                        window_pass:hide(Window.transitionPushLeft)
                                                                        window_user:hide(Window.transitionPushLeft)

                                                                        -- reconnect
                                                                        CalaosConnect(function () self:calaosMainmenu() end,
                                                                                      function () self:calaosMainmenu() end)

                                                                        return true
                                                                end)

                                                window_pass:addWidget(Textarea("help", "Veuillez entrer votre mot de passe."))
                                                window_pass:addWidget(input)
                                                self:tieAndShowWindow(window_pass)

                                                return true
                                        end)

                        window_user:addWidget(Textarea("help", "Veuillez entrer votre nom d'utilisateur."))
                        window_user:addWidget(input)
                        self:tieAndShowWindow(window_user)

                        return window_user
                end
        end

        self:tieAndShowWindow(window)
        return window
end

function skin(self, s)
        s.big_menu = {}
        s.big_menu.itemHeight = 68
end

-- Discovering process
local discover_socket
local function _discoverPacket()
        return "CALAOS_DISCOVER"
end

local function _discoverSink(chunk, err)
        if err then
                log:info("Calaos: Discover failed !")
        elseif chunk then
                log:info("Calaos: New calaosd found at address: " .. chunk.ip)
                calaosd_ip = chunk.ip
        end

        discover_socket:free()

        -- try to connect to calaosd
        if calaosd_ip then
                CalaosConnect()
        end
end

function Discover(self)
        discover_socket = SocketUdp(jnt, _discoverSink, "CalaosDiscoverSocket")

        --Send the discover packet on the network
        discover_socket:send(_discoverPacket, "255.255.255.255", CALAOS_UDP_PORT)
end

-- Some socket functions --------------
local csocket = nil
function CalaosConnect(good_login, false_login)
        if csocket == nil then
                csocket = SocketTcp(jnt, calaosd_ip, CALAOS_CLI_PORT, "CalaosCli")
        end

        if not csocket:connected() then
                local err = socket.skip(1, csocket:t_connect())

                if err then
                        log:error("Calaos: CalaosConnect: ", err)
                        csocket:close(err)
                        return
                end

                SendCommand("login " .. calaos_user .. " " .. calaos_pass,
                        function (chunk, err)
                                if err == 'closed' then
                                        wrong_user = true
                                        if false_login then
                                                false_login()
                                        end
                                else
                                        log:info("Calaos:DEBUG : login success")
                                        wrong_user = false
                                        if good_login then
                                                good_login()
                                        end
                                end
                        end
                )
        end
end

-- jive-keep-open socket sink (Took from SocketHttp.lua)
-- our "keep-open" sink, added to the socket namespace so we can use it like any other
-- our version is non blocking
socket.sinkt["jive-keep-open"] = function(sock)
        local first = 0
        return setmetatable(
                {
                        getfd = function() return sock:getfd() end,
                        dirty = function() return sock:dirty() end
                },
                {
                        __call = function(self, chunk, err)
--                              log:debug("jive-keep-open sink(", chunk and #chunk, ", ", tostring(err), ", ", tostring(first), ")")
                                if chunk then
                                        local res, err
                                        -- if send times out, err is 'timeout' and first is updated.
                                        res, err, first = sock:send(chunk, first+1)
--                                      log:debug("jive-keep-open sent - first is ", tostring(first), " returning ", tostring(res), ", " , tostring(err))
                                        -- we return the err
                                        return res, err
                                else
                                        return 1
                                end
                        end
                }
        )
end

function SendCommand(cmd, callback)

        log:info("Calaos Network, sending: ", cmd)

        local source = function ()
                return cmd .. string.char(0x0D) .. string.char(0x0A)
        end

        -- using jive non blocking sink
        local sink = socket.sink('jive-keep-open', csocket.t_sock)

        local pump = function (NetworkThreadErr)

                if NetworkThreadErr then
                        log:error("Calaos: SendCommand.pump: ", NetworkThreadErr)
                        csocket:close(NetworkThreadErr)
                        return
                end

                local ret, err = ltn12.pump.step(source, sink)

                if err then
                        -- do nothing on timeout, we will be called again to send the rest of the data...
                        if err == 'timeout' then
                                return
                        end

                        -- handle any "real" error
                        log:error("Calaos: SendCommand.pump: ", err)
                        csocket:close(err)
                        return
                end

                csocket:t_removeWrite()

                -- We're done sending request, now read answer...
                csocket:t_addRead(_getRead_pump(callback), TIMEOUT)
        end

        csocket:t_addWrite(pump, TIMEOUT)
end

function _getRead_pump(sink)

        local source = function()

                local line, err = csocket.t_sock:receive('*l')
                if err then
                        return nil, err
                end

                if line == "" then
                        -- done receiving
                        return nil
                end

                log:info("Calaos Network, received: ", line)

                return line
        end

        local pump = function (NetworkThreadErr)

                if NetworkThreadErr then
                        log:error("Calaos: RecvCommand.pump: ", NetworkThreadErr)
                        csocket:close(NetworkThreadErr)
                        return
                end

                while true do
                        local ret, err = ltn12.pump.step(source, sink)

                        if err then

                                if err == 'timeout' then
                                        log:debug("Calaos: RecvCommand.pump - timeout")
                                        -- more next time
                                        return
                                end

                                log:error("Calaos: RecvCommand.pump:", err)
                                csocket:t_removeRead()
                                csocket:close(err)
                                return

                        elseif not ret then

                                -- we're done
                                csocket:t_removeRead()
                                return
                        end
                end
        end

        return pump
end

-- ------------------------------------










































































function menu(self, menuItem)

	log:info("menu")

	local group = RadioGroup()

	-- Menu	
	local menu = SimpleMenu("menu",
		{
			{ text = "Text input",
				sound = "WINDOWSHOW",
				callback = function(event, menuItem)
					self:textinputWindow(menuItem)
				end
			},
			{ text = "Timer stress",
				sound = "WINDOWSHOW",
				callback = function(event, menuItem)
					self:timerTestWindow(menuItem)
				end
			},
			{ 
				text = "Choice, and some more text so that this item scrolls.", 
				icon = Choice(
				       "choice", 
				       { "Off", "Low", "Medium", "High" },
				       function(obj, selectedIndex)
					       log:info(
							"Choice updated: ", 
							tostring(selectedIndex), 
							" - ",
							tostring(obj:getSelected())
						)
				       end	
			       )
			},
			{
				text = "RadioButton 1, and some more text so that this item scrolls", 
				icon = RadioButton(
					"radio", 
					group, 
					function()
						log:info("radio button 1 selected")
					end,
					true
				),
			},
			{
				text = "RadioButton 2", 
				icon = RadioButton(
					"radio", 
					group, 
					function()
						log:info("radio button 2 selected")
					end
				),
			},
			{
				text = "RadioButton 3", 
				icon = RadioButton(
					"radio", 
					group, 
					function()
						log:info("radio button 3 selected")
					end
				),
			},
			{
				text = "Checkbox", 
				icon = Checkbox(
					"checkbox",
					function(object, isSelected)
						log:info("checkbox updated: ", isSelected)
					end,
					true
				)
			},
			{ text = "Menu",
				sound = "WINDOWSHOW",
				callback = function(event, menuItem)
					self:menuWindow(menuItem)
				end },
			{ text = "Sorted Menu",
				sound = "WINDOWSHOW",
				callback = function(event, menuItem)
					self:sortedMenuWindow(menuItem)
				end },
			{ text = "Text UTF8",
				sound = "WINDOWSHOW",
				callback = function(event, menuItem)
					self:textWindow(menuItem, "applets/Test/test.txt")
				end },
			{ text = "Connecting Popup",
				sound = "WINDOWSHOW",
				callback = function(event, menuItem)
					self:connectingPopup(menuItem)
				end },
			{ text = "Slider",
				sound = "WINDOWSHOW",
				callback = function(event, menuItem)
					self:sliderWindow(menuItem)
				end },
			{ text = "Hex input",
				sound = "WINDOWSHOW",
				callback = function(event, menuItem)
					self:hexinputWindow(menuItem)
				end },
			{ text = "Time input",
				sound = "WINDOWSHOW",
				callback = function(event, menuItem)
					self:timeinputWindow(menuItem)
				end },
			{ text = "IP input",
				sound = "WINDOWSHOW",
				callback = function(event, menuItem)
					self:ipinputWindow(menuItem)
				end },
			{ text = "Image JPG",
				sound = "WINDOWSHOW",
				callback = function(event, menuItem)
						   local t = Timer(0, function()
									      log:warn("timer fired")
									      self:imageWindow(menuItem, "applets/Test/test.jpg")
								      end, true)
						   t:start()
				end },
			{ text = "Image PNG",
				sound = "WINDOWSHOW",
				callback = function(event, menuItem)
					self:imageWindow(menuItem, "applets/Test/test.png")
				end },
			{ text = "Image GIF",
				sound = "WINDOWSHOW",
				callback = function(event, menuItem)
					self:imageWindow(menuItem, "applets/Test/test.gif")
				end },
		})

	local window = Window("window", "This") -- is a really long title to test the bounding box")
	window:addWidget(menu)

	self:tieAndShowWindow(window)
	return window
end


function sortedMenuWindow(self, menuItem)
	local window = Window("window", menuItem.text)
	local menu = SimpleMenu("menu")
	menu:setComparator(menu.itemComparatorAlpha)

	local item = { text = "United States" }
	menu:addItem(item)
	menu:setSelectedItem(item)

	menu:addItem({ text = "Australia" })
	menu:addItem({ text = "France" })
	menu:addItem({ text = "Japan" })
	menu:addItem({ text = "Taiwan" })
	menu:addItem({ text = "Europe" })
	menu:addItem({ text = "Canada" })
	menu:addItem({ text = "China" })


	local interval = 1000
	local foo = Timer(interval,
			  function(self)
				  interval = interval + 1000
				  log:warn("self=", self, " interval=", interval)
				  self:setInterval(interval)
			  end)
	foo:start()

	window:addWidget(menu)
	self:tieAndShowWindow(window)
	return window
end


function menuWindow(self, menuItem)
	local window = Window("window", menuItem.text)
	local menu = SimpleMenu("menu")
	window:addWidget(menu)

	local items = {}
	for i=1,2000 do
		items[#items + 1] = { text = "Artist " .. i }
	end

	menu:setItems(items)

	self:tieAndShowWindow(window)
	return window
end


function textWindow(self, menuItem, filename)

	local window = Window("window", menuItem.text)

	filename = Framework:findFile(filename)
	local fh = io.open(filename, "rb")
	if fh == nil then
		-- FIXME error dialog
		window:addWidget(Textarea("textarea", "Cannot load text " .. filename))
		return window
	end

	local text = fh:read("*all")
	fh:close()

	local textarea = Textarea("textarea", text)

	window:addWidget(textarea)

	self:tieAndShowWindow(window)
	return window
end


function sliderWindow(self, menuItem)

	local window = Window("window", menuItem.text)

	local slider = Slider("slider", 1, 20, 5,
		function(slider, value, done)
			log:warn("slider value is ", value, " ", done)

			if done then
				window:playSound("WINDOWSHOW")
				window:hide(Window.transitionPushLeft)
			end
		end)

	local help = Textarea("help", "We can add some help text here.\n\nThis screen is for testing the slider.")

	window:addWidget(help)
	window:addWidget(slider)

	self:tieAndShowWindow(window)
	return window
end


function textinputWindow(self, menuItem)

	local window = Window("window", menuItem.text)

--	local v = Textinput.textValue("A test string which is so long it goes past the end of the window", 8)
	local v = Textinput.textValue("", 8, 10)
	local input = Textinput("textinput", v,
				function(_, value)
					log:warn("Input ", value)

					window:playSound("WINDOWSHOW")
					window:hide(Window.transitionPushLeft)
					return true
				end)

	window:addWidget(Textarea("softHelp", "A basic text input widget. Graphical improvements will come later."))
	window:addWidget(Label("softButton1", "Insert"))
	window:addWidget(Label("softButton2", "Delete"))

	window:addWidget(input)

	self:tieAndShowWindow(window)
	return window
end


function timeinputWindow(self, menuItem)
	local window = Window("window", menuItem.text)

	local v = Textinput.timeValue("00:00")
	local input = Textinput("textinput", v,
				function(_, value)
					log:warn("Input " .. value:getValue())

					window:playSound("WINDOWSHOW")
					window:hide(Window.transitionPushLeft)
					return true
				end)

	local help = Textarea("help", "Input of Time (24h)")

	window:addWidget(help)
	window:addWidget(input)

	self:tieAndShowWindow(window)
	return window
end

function hexinputWindow(self, menuItem)
	local window = Window("window", menuItem.text)

	local v = Textinput.hexValue("000000000000")
	local input = Textinput("textinput", v,
				function(_, value)
					log:warn("Input " .. value:getValue())

					window:playSound("WINDOWSHOW")
					window:hide(Window.transitionPushLeft)
					return true
				end)

	local help = Textarea("help", "Input of HEX numbers.")

	window:addWidget(help)
	window:addWidget(input)

	self:tieAndShowWindow(window)
	return window
end


function ipinputWindow(self, menuItem)
	local window = Window("window", menuItem.text)

	local v = Textinput.ipAddressValue("0.0.0.0")
	local input = Textinput("textinput", v,
				function(_, value)
					log:warn("Input " .. value:getValue())

					window:playSound("WINDOWSHOW")
					window:hide(Window.transitionPushLeft)
					return true
				end)

	local help = Textarea("help", "Input of IP addresses.")

	window:addWidget(help)
	window:addWidget(input)

	self:tieAndShowWindow(window)
	return window
end


function connectingPopup(self, menuItem)

	local popup = Popup("popupIcon")

	local icon = Icon("iconConnecting")
	local label = Label("text", "")

	popup:addWidget(icon)
	popup:addWidget(label)


	local state = 1
	popup:addTimer(4000, function()
				       if state == 1 then
					       label:setValue("\na long test string!")
				       elseif state == 2 then
					       label:setValue("\na very very very long test string!")
				       elseif state == 3 then
					       icon:setStyle("iconConnected")
					       label:setValue("Connected to\na test string!")
				       else
					       popup:hide()
				       end
				       state = state + 1
			       end)

	self:tieAndShowWindow(popup)
	return popup
end


function imageWindow(self, menuItem, filename)

	local window = Window("window")

	local image = Surface:loadImage(filename)
	if image == nil then
		-- FIXME error dialog
		window:addWidget(Textarea("textarea", "Cannot load image " .. filename))
		return window
	end

	-- size the image to fit the window
	local sw,sh = Framework:getScreenSize()
	log:warn("window size ", sw, " ", sh)
	local w,h = image:getSize()
	if w > sw or h > sh then
		local fw = sw / w
		local fh = sh / h
		if fw > fh then
			image = image:zoom(fh, fh)
		else
			image = image:zoom(fw, fw)
		end
	end
	log:debug("w = " .. w .. " h = " .. h)
	
	window:addWidget(Icon("image", image))
	window:addListener(EVENT_KEY_PRESS,
		function(event)
			window:hide()
			return EVENT_CONSUME
		end
	)

	self:tieAndShowWindow(window)
	return window
end


function timerTestWindow(self, instead)
	local popup = Popup("popupIcon")
	local icon = Icon("iconConnecting")
	local label = Label("text", "Timer test 1")

	popup:addWidget(icon)
	popup:addWidget(label)

	popup:addTimer(2000,
		function()
			self:timerTestWindow2()
		end)	

	if instead then
		popup:showInstead(Window.transitionFadeIn)
	else
		popup:show()
	end
end


function timerTestWindow2(self)
	local window = Popup("popupIcon")
	local icon = Icon("iconConnected")
	local label = Label("text", "Timer test 2")

	window:addWidget(icon)
	window:addWidget(label)

	window:addTimer(1000,
		function()
			self:timerTestWindow(true)
		end)	

	window:showInstead(Window.transitionFadeIn)
end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

