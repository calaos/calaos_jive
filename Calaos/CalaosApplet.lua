
--[[

=head1 LICENSE

Copyright 2008 Calaos. All Rights Reserved.

http://www.calaos.fr

=cut
--]]


-- stuff we use
local setmetatable, tonumber, tostring, type, ipairs, pairs = setmetatable, tonumber, tostring, type, ipairs, pairs

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
local Group                  = require("jive.ui.Group")
local Timer                  = require("jive.ui.Timer")
local SocketUdp              = require("jive.net.SocketUdp")
local SocketTcp              = require("jive.net.SocketTcp")
local SocketHttp             = require("jive.net.SocketHttp")
local RequestHttp            = require("jive.net.RequestHttp")
local Tile                   = require("jive.ui.Tile")
local Font                   = require("jive.ui.Font")
local socket                 = require("socket")
local url                    = require("socket.url")
local ltn12                  = require("ltn12")

local log                    = require("jive.utils.log").addCategory("test", jive.utils.log.DEBUG)

local EVENT_KEY_PRESS        = jive.ui.EVENT_KEY_PRESS
local EVENT_CONSUME          = jive.ui.EVENT_CONSUME
local KEY_BACK               = jive.ui.KEY_BACK
local KEY_GO                 = jive.ui.KEY_GO
local WH_FILL                = jive.ui.WH_FILL
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
local cameraUpdateTime = 1000
local wrong_user = false
local _applet = nil

local _simpleCamTimer = nil

module(...)
oo.class(_M, Applet)


-- Helper function to split a string
--> took from http://lua-users.org/wiki/StringRecipes with some minor changes
function Split(str, delim, maxNb)

    -- Eliminate bad cases...
    if string.find(str, delim) == nil then
        return { str }
    end
    if maxNb == nil or maxNb < 1 then
        maxNb = 0    -- No limit
    end
    local result = {}
    local pat = "(.-)" .. delim .. "()"
    local nb = 0
    local lastPos
    for part, pos in string.gfind(str, pat) do
        nb = nb + 1
        result[nb] = part
        --Changed from original, here we also want the last one to be with all the last chars, including delimiters
        if nb == maxNb then result[nb] = string.sub(str, lastPos) break end
        lastPos = pos
    end
    -- Handle the last field
    if nb ~= maxNb then
        result[nb + 1] = string.sub(str, lastPos)
    end
    return result
end


function startApplet(self)

        _applet = self

        if _applet:getSettings().calaos_user ~= nil or _applet:getSettings().calaos_user ~= "" then
                calaos_user = _applet:getSettings().calaos_user
        end
        if _applet:getSettings().calaos_pass ~= nil or _applet:getSettings().calaos_pass ~= "" then
                calaos_pass = _applet:getSettings().calaos_pass
        end
        if _applet:getSettings().cameraUpdateTime ~= nil then
                cameraUpdateTime = _applet:getSettings().cameraUpdateTime
        end

        -- Discover the calaosd server
        Discover()

        self.window = self:newWindow()
        self:tieAndShowWindow(self.window)
        return self.window
end

function free()
        calaosd_ip = nil
        if csocket then
                csocket:free()
                csocket = nil
        end
        wrong_user = false
        _applet = nil
        srf = nil
        window = nil
        cameraUpdateTime = 1000

        clearCameraPool()
        if _simpleCamTimer then
                _simpleCamTimer:stop()
                _simpleCamTimer = nil
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
                        style = "big_item",
                        text = "My Home\nGérer sa maison",
                        icon = Icon("image", Surface:loadImage("applets/Calaos/graphics/home_icon.png")),
                        sound = "WINDOWSHOW",
                        callback = function(event, ...)
                                self:calaosHomemenu()
                        end
                },
                {
                        style = "big_item",
                        text = "Media\nVisualiser ses caméras de surveillance",
                        icon = Icon("image", Surface:loadImage("applets/Calaos/graphics/media_icon.png")),
                        sound = "WINDOWSHOW",
                        callback = function(event, ...)
                                self:calaosMediamenu()
                        end
                },
                {
                        style = "big_item",
                        text = "Configuration\nConfiguration de l'applet",
                        icon = Icon("image", Surface:loadImage("applets/Calaos/graphics/config_icon.png")),
                        sound = "WINDOWSHOW",
                        callback = function(event, ...)
                                local config_window = Window("window", "", "albumtitle")
                                config_window:setTitleWidget(Group("albumtitle", {
                                        text = Label("text", "Calaos Home Applet\nConfiguration"),
                                        icon = Icon("icon", Surface:loadImage("applets/Calaos/graphics/config_icon.png")) }))

                                local menu = SimpleMenu("menu", {
                                {
                                        text = "Vitesse de rafraichissement des caméras",
                                        sound = "WINDOWSHOW",
                                        callback = function(event, ...)
                                                local window = Window("window", "", "albumtitle")
                                                window:setTitleWidget(Group("albumtitle", {
                                                        text = Label("text", "Configuration\nVitesse de rafraichissement des caméras"),
                                                        icon = Icon("icon", Surface:loadImage("applets/Calaos/graphics/config_icon.png")) }))
                                                local label = Label("text", "Valeur: " .. tostring(cameraUpdateTime) .. " ms")

                                                local slider = Slider("slider", 1, 50, (cameraUpdateTime * 50) / 4950,
                                                        function(slider, value, done)
                                                                log:warn("slider value is ", value, " ", done)
                                                                label:setValue("Valeur: " .. tostring((value * 4950) / 50 - 50) .. " ms")

                                                                if done then
                                                                        window:playSound("WINDOWSHOW")
                                                                        window:hide(Window.transitionPushLeft)

                                                                        cameraUpdateTime = (value * 4950) / 50 - 50

                                                                        _applet:getSettings().cameraUpdateTime = cameraUpdateTime
                                                                        _applet:storeSettings()
                                                                end
                                                        end)

                                                local help = Textarea("help", "We can add some help text here.\n\nThis screen is for testing the slider.")

                                                window:addWidget(help)
                                                window:addWidget(slider)
                                                window:addWidget(label)

                                                window:focusWidget(slider)

                                                self:tieAndShowWindow(window)
                                        end
                                } } )

                                config_window:addWidget(menu)
                                self:tieAndShowWindow(config_window)
                        end
                },
                {
                        style = "big_item",
                        text = "A propos\nA propos de l'applet Calaos",
                        icon = Icon("image", Surface:loadImage("applets/Calaos/graphics/about_icon.png")),
                        sound = "WINDOWSHOW",
                        callback = function(event, ...)
                                self:CSendCommand("version ?",
                                        function (chunk, err)
                                                local window = Window("window", self:displayName())
                                                local t = Split(url.unescape(chunk), " ")
                                                local about_msg = Textarea("help", "Calaos Home applet for Jive remotes.\nCalaos server version " .. t[2] .. "\n\nwww.calaos.fr\nCopyright 2008 Calaos")
                                                local logo = Sprite(width, height, "applets/Calaos/graphics/logo.png")
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
                                )
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


function calaosHomemenu(self)

        --get home infos and populate the main room menu
        self:CSendCommand("home ?",
                function (chunk, err)
                        local window = Window("window", "Calaos Home")
                        local menu = SimpleMenu("big_menu")

                        local t = Split(chunk, " ")
                        table.remove(t, 1)
                        for i,v in ipairs(t) do
                                local t = Split(url.unescape(v), ":")
                                local nb = tonumber(t[2])
                                local room_type = t[1]
                                menu:addItem({
                                        style = "big_item",
                                        text = _getRealRoomName(room_type),
                                        icon = Icon("image", Surface:loadImage(_getRealPicture(room_type))),
                                        sound = "WINDOWSHOW",
                                        callback = function(event, ...)

                                                local names = {}

                                                --get room infos
                                                self:CSendCommand("home get " .. t[1],
                                                        function (chunk, err)
                                                                local t = Split(chunk, " ")

                                                                local cpt = 0
                                                                for i = 3, #t, 2 do
                                                                        cpt = cpt + 1
                                                                        local tinfo = Split(url.unescape(t[i]), ":", 3)
                                                                        names[cpt] = url.unescape(tinfo[3])
                                                                end

                                                                -- if we have multiple rooms for one romm_type, show a new room
                                                                -- selection menu
                                                                if nb > 1 then
                                                                        local window = Window("window", "", "albumtitle")
                                                                        window:setTitleWidget(Group("albumtitle", {
                                                                                        text = Label("text", "Type de pièce:\n" .. _getRealRoomName(room_type)),
                                                                                        icon = Icon("icon", Surface:loadImage(_getRealPicture(room_type))) }))
                                                                        local menu = SimpleMenu("menu")

                                                                        for i = 1, #names do
                                                                                menu:addItem({
                                                                                        text = names[i],
                                                                                        sound = "WINDOWSHOW",
                                                                                        callback = function(event, item)
                                                                                                self:calaosRoommenu(room_type, names[i], i - 1)
                                                                                        end
                                                                                })
                                                                        end

                                                                        window:addWidget(menu)
                                                                        self:tieAndShowWindow(window)
                                                                else
                                                                        self:calaosRoommenu(room_type, names[1], 0)
                                                                end

                                                        end
                                                )
                                        end
                                })
                        end

                        window:addWidget(menu)
                        self:tieAndShowWindow(window)

                end
        )
end

-- Show the Room menu: List all available items
function calaosRoommenu(self, room_type, room_name, room_id)

        local window = Window("window", "", "albumtitle")
        window:setTitleWidget(Group("albumtitle", {
                text = Label("text", "Vous êtes dans:\n" .. room_name),
                icon = Icon("icon", Surface:loadImage(_getRealPicture(room_type))) }))
        local menu = SimpleMenu("io_menu")

        -- get room infos
        self:CSendCommand("room " .. room_type .. " get " .. tostring(room_id),
                function (chunk, err)
                        local t = Split(chunk, " ")

                        for i = 3, #t do
                                local o = Split(url.unescape(t[i]), ":", 2)
                                local iotype = o[1]
                                local io_id = o[2]

                                if iotype == nil or iotype == "" or io_id == nil or io_id == "" then
                                        return
                                end

                                self:addCSendCommand(iotype .. " " .. io_id .. " get",
                                        function (chunk, err)
                                                local t = Split(chunk, " ")
                                                local iname = nil
                                                local itype = nil
                                                local gtype = nil
                                                local state = nil

                                                for i = 2, #t do
                                                        local o = Split(url.unescape(t[i]), ":", 2)

                                                        if o[1] == "name" then iname = o[2] end
                                                        if o[1] == "type" then itype = o[2] end
                                                        if o[1] == "gtype" then gtype = o[2] end
                                                        if o[1] == "state" then state = o[2] end
                                                end

                                                if itype == "scenario" then
                                                        self:_addIOScenario(window, room_type, room_name, room_id, menu, io_id, iname, itype)
                                                end
                                                if itype == "WODigital" then
                                                        self:_addIOWODigital(window, room_type, room_name, room_id, menu, io_id, iname, gtype, state, itype)
                                                end
                                                if itype == "WONeon" or itype == "WODali" or itype == "X10Output" then
                                                        self:_addIODimmer(window, room_type, room_name, room_id, menu, io_id, iname, gtype, state, itype)
                                                end
                                                if itype == "WODAliRVB" then
                                                        self:_addIODimmerRGB(window, room_type, room_name, room_id, menu, io_id, iname, gtype, state, itype)
                                                end
                                                if itype == "WOVolet" then
                                                        self:_addIOShutter(window, room_type, room_name, room_id, menu, io_id, iname, gtype, state, itype)
                                                end
                                                if itype == "WOVoletSmart" then
                                                        self:_addIOShutter(window, room_type, room_name, room_id, menu, io_id, iname, gtype, state, itype)
                                                end
                                        end
                                )
                        end

                        -- run all the jobs
                        self:runJobList()
                end
        )

        window:addWidget(menu)
        self:tieAndShowWindow(window)
end

function _addIOScenario(self, old_window, room_type, room_name, room_id, menu, id, name, itype)

        menu:addItem({
                text = name,
                icon = Icon("image", Surface:loadImage("applets/Calaos/graphics/icon_scenario_small.png")),
                sound = "WINDOWSHOW",
                callback = function(event, item)
                        local window = Window("window", "", "albumtitle")
                        window:setTitleWidget(Group("albumtitle", {
                                text = Label("text", "Pièce:\n" .. room_name .. "\n" .. name),
                                icon = Icon("icon", Surface:loadImage(_getRealPicture(room_type))) }))
                        local menu = SimpleMenu("menu")

                        menu:addItem({
                                text = "Lancer",
                                sound = "PLAYBACK",
                                callback = function(event, item)
                                        self:CSendCommand("input " .. id .. " set true",
                                                function (chunk, err)
                                                        window:hide()
                                                        old_window:hide()
                                                        self:calaosRoommenu(room_type, room_name, room_id)
                                                end
                                        )
                                end
                        })

                        window:addWidget(menu)
                        self:tieAndShowWindow(window)
                end
        })
end

function _addIOWODigital(self, old_window, room_type, room_name, room_id, menu, id, name, gtype, state, itype)

        local icon_file = "applets/Calaos/graphics/"

        if gtype == "light" then
                if state == "true" then
                        icon_file = icon_file .. "icon_light_on.png"
                else
                        icon_file = icon_file .. "icon_light_off.png"
                end
        else
                if state == "true" then
                        icon_file = icon_file .. "icon_tor_on.png"
                else
                        icon_file = icon_file .. "icon_tor_off.png"
                end
        end

        menu:addItem({
                text = name,
                icon = Icon("image", Surface:loadImage(icon_file)),
                sound = "WINDOWSHOW",
                callback = function(event, item)
                        local window = Window("window", "", "albumtitle")
                        window:setTitleWidget(Group("albumtitle", {
                                text = Label("text", "Pièce:\n" .. room_name .. "\n" .. name),
                                icon = Icon("icon", Surface:loadImage(_getRealPicture(room_type))) }))
                        local menu = SimpleMenu("menu")

                        menu:addItem({
                                text = "Allumer",
                                sound = "PLAYBACK",
                                callback = function(event, item)
                                        self:CSendCommand("output " .. id .. " set true",
                                                function (chunk, err)
                                                        window:hide()
                                                        old_window:hide()
                                                        self:calaosRoommenu(room_type, room_name, room_id)
                                                end
                                        )
                                end
                        })

                        menu:addItem({
                                text = "Eteindre",
                                sound = "PLAYBACK",
                                callback = function(event, item)
                                        self:CSendCommand("output " .. id .. " set false",
                                                function (chunk, err)
                                                        window:hide()
                                                        old_window:hide()
                                                        self:calaosRoommenu(room_type, room_name, room_id)
                                                end
                                        )
                                end
                        })

                        if gtype ~= "light" then
                                menu:addItem({
                                        text = "Donner une impulsion",
                                        sound = "PLAYBACK",
                                        callback = function(event, item)
                                                self:CSendCommand("output " .. id .. " set impulse%20200",
                                                        function (chunk, err)
                                                                window:hide()
                                                                old_window:hide()
                                                                self:calaosRoommenu(room_type, room_name, room_id)
                                                        end
                                                )
                                        end
                                })
                        end

                        window:addWidget(menu)
                        self:tieAndShowWindow(window)
                end
        })
end

function _addIODimmer(self, old_window, room_type, room_name, room_id, menu, id, name, gtype, state, itype)

        local icon_file = "applets/Calaos/graphics/"

        if state == "true" then
                icon_file = icon_file .. "icon_light_on.png"
        else
                icon_file = icon_file .. "icon_light_off.png"
        end

        menu:addItem({
                text = name,
                icon = Icon("image", Surface:loadImage(icon_file)),
                sound = "WINDOWSHOW",
                callback = function(event, item)
                        local window = Window("window", "", "albumtitle")
                        window:setTitleWidget(Group("albumtitle", {
                                text = Label("text", "Pièce:\n" .. room_name .. "\n" .. name),
                                icon = Icon("icon", Surface:loadImage(_getRealPicture(room_type))) }))
                        local menu = SimpleMenu("menu")

                        menu:addItem({
                                text = "Allumer",
                                sound = "PLAYBACK",
                                callback = function(event, item)
                                        self:CSendCommand("output " .. id .. " set true",
                                                function (chunk, err)
                                                        window:hide()
                                                        old_window:hide()
                                                        self:calaosRoommenu(room_type, room_name, room_id)
                                                end
                                        )
                                end
                        })

                        menu:addItem({
                                text = "Eteindre",
                                sound = "PLAYBACK",
                                callback = function(event, item)
                                        self:CSendCommand("output " .. id .. " set false",
                                                function (chunk, err)
                                                        window:hide()
                                                        old_window:hide()
                                                        self:calaosRoommenu(room_type, room_name, room_id)
                                                end
                                        )
                                end
                        })

                        menu:addItem({
                                text = "Varier",
                                sound = "PLAYBACK",
                                callback = function(event, item)
                                        self:_ShowSlider(room_name, room_type, name, state, id, room_id, window, old_window, "set")
                                end
                        })

                        window:addWidget(menu)
                        self:tieAndShowWindow(window)
                end
        })
end

function _ShowSlider(self, room_name, room_type, name, state, id, room_id, window, old_window, cmd)

        local swindow = Window("window", "", "albumtitle")

        swindow:setTitleWidget(
                Group("albumtitle", {
                        text = Label("text", "Pièce:\n" .. room_name .. "\n" .. name),
                        icon = Icon("icon", Surface:loadImage(_getRealPicture(room_type)))
                })
        )

        log:info("Calaos:DEBUG: state = ", state)

        local slider = Slider("slider", 0, 50, tonumber(state) / 2,
                function(slider, value, done)
                        if done then
                                log:info("Calaos:DEBUG: New value = ", value)
                                self:CSendCommand("output " .. id .. " set " .. cmd .. "%20" .. value * 2,
                                        function (chunk, err)
                                                swindow:playSound("WINDOWSHOW")
                                                swindow:hide()
                                                window:hide()
                                                old_window:hide()
                                                self:calaosRoommenu(room_type, room_name, room_id)
                                        end
                                )
                        end
                end)

        local help = Textarea("help", "Déplacez le curseur pour choisir une nouvelle valeur, et appuyez sur Ok pour valider.")

        swindow:addWidget(help)
        swindow:addWidget(slider)
        self:tieAndShowWindow(swindow)

end

function _addIODimmerRGB(self, old_window, room_type, room_name, room_id, menu, id, name, gtype, state, itype)

        local icon_file = "applets/Calaos/graphics/"

        if state == "true" then
                icon_file = icon_file .. "icon_light_on.png"
        else
                icon_file = icon_file .. "icon_light_off.png"
        end

        menu:addItem({
                text = name,
                icon = Icon("image", Surface:loadImage(icon_file)),
                sound = "WINDOWSHOW",
                callback = function(event, item)
                        local window = Window("window", "", "albumtitle")
                        window:setTitleWidget(Group("albumtitle", {
                                text = Label("text", "Pièce:\n" .. room_name .. "\n" .. name),
                                icon = Icon("icon", Surface:loadImage(_getRealPicture(room_type))) }))
                        local menu = SimpleMenu("menu")

                        menu:addItem({
                                text = "Allumer",
                                sound = "PLAYBACK",
                                callback = function(event, item)
                                        self:CSendCommand("output " .. id .. " set true",
                                                function (chunk, err)
                                                        window:hide()
                                                        old_window:hide()
                                                        self:calaosRoommenu(room_type, room_name, room_id)
                                                end
                                        )
                                end
                        })

                        menu:addItem({
                                text = "Eteindre",
                                sound = "PLAYBACK",
                                callback = function(event, item)
                                        self:CSendCommand("output " .. id .. " set false",
                                                function (chunk, err)
                                                        window:hide()
                                                        old_window:hide()
                                                        self:calaosRoommenu(room_type, room_name, room_id)
                                                end
                                        )
                                end
                        })

                        menu:addItem({
                                text = "Varier rouge",
                                sound = "PLAYBACK",
                                callback = function(event, item)
                                        self:_ShowSlider(room_name, room_type, name, state, id, room_id, window, old_window, "set_red")
                                end
                        })

                        menu:addItem({
                                text = "Varier vert",
                                sound = "PLAYBACK",
                                callback = function(event, item)
                                        self:_ShowSlider(room_name, room_type, name, state, id, room_id, window, old_window, "set_green")
                                end
                        })

                        menu:addItem({
                                text = "Varier bleu",
                                sound = "PLAYBACK",
                                callback = function(event, item)
                                        self:_ShowSlider(room_name, room_type, name, state, id, room_id, window, old_window, "set_blue")
                                end
                        })

                        window:addWidget(menu)
                        self:tieAndShowWindow(window)
                end
        })
end

function _addIOShutter(self, old_window, room_type, room_name, room_id, menu, id, name, gtype, state, itype)

        local icon_file = "applets/Calaos/graphics/"

        if state == "true" then
                icon_file = icon_file .. "icon_shutter_on.png"
        else
                icon_file = icon_file .. "icon_shutter.png"
        end

        menu:addItem({
                text = name,
                icon = Icon("image", Surface:loadImage(icon_file)),
                sound = "WINDOWSHOW",
                callback = function(event, item)
                        local window = Window("window", "", "albumtitle")
                        window:setTitleWidget(Group("albumtitle", {
                                text = Label("text", "Pièce:\n" .. room_name .. "\n" .. name),
                                icon = Icon("icon", Surface:loadImage(_getRealPicture(room_type))) }))
                        local menu = SimpleMenu("menu")

                        menu:addItem({
                                text = "Monter",
                                sound = "PLAYBACK",
                                callback = function(event, item)
                                        self:CSendCommand("output " .. id .. " set up",
                                                function (chunk, err)
                                                        window:hide()
                                                        old_window:hide()
                                                        self:calaosRoommenu(room_type, room_name, room_id)
                                                end
                                        )
                                end
                        })

                        menu:addItem({
                                text = "Descendre",
                                sound = "PLAYBACK",
                                callback = function(event, item)
                                        self:CSendCommand("output " .. id .. " set down",
                                                function (chunk, err)
                                                        window:hide()
                                                        old_window:hide()
                                                        self:calaosRoommenu(room_type, room_name, room_id)
                                                end
                                        )
                                end
                        })

                        menu:addItem({
                                text = "Stopper",
                                sound = "PLAYBACK",
                                callback = function(event, item)
                                        self:CSendCommand("output " .. id .. " set stop",
                                                function (chunk, err)
                                                        window:hide()
                                                        old_window:hide()
                                                        self:calaosRoommenu(room_type, room_name, room_id)
                                                end
                                        )
                                end
                        })

                        if itype == "WOVoletSmart" then
                                menu:addItem({
                                text = "Fixer position",
                                sound = "PLAYBACK",
                                callback = function(event, item)
                                        self:_ShowSlider(room_name, room_type, name, state, id, room_id, window, old_window)
                                end
                        })
                        end

                        window:addWidget(menu)
                        self:tieAndShowWindow(window)
                end
        })
end

function calaosMediamenu(self)
        local window = Window("window", "Calaos Media")
        local menu = SimpleMenu("big_menu")

        self:CSendCommand("camera ?",
                function (chunk, err)
                        local t = Split(chunk, " ")
                        local nb = tonumber(t[2])

                        clearCameraPool()

                        -- timer to return to home screen after a while, moslty to avoid battery comsuption
                        local _returnTimer = Timer(1000 * 60, -- 1 min
                                function ()
                                        window:hide()
                                        clearCameraPool()
                                end,
                                true)
                        _returnTimer:start()

                        for i = 0, nb - 1 do
                                self:addCSendCommand("camera get " .. tostring(i),
                                        function (chunk, err)
                                                local t = Split(chunk, " ")
                                                local cname = nil
                                                local jpeg_url = nil
                                                local ptz = false

                                                for i = 3, #t do
                                                        local o = Split(url.unescape(t[i]), ":", 2)

                                                        if o[1] == "name" then cname = o[2] end
                                                        if o[1] == "jpeg_url" then jpeg_url = o[2] end
                                                        if o[1] == "ptz" then ptz = o[2] end
                                                end

                                                local item = {
                                                        text = cname,
                                                        icon = Icon("image", Surface:loadImage("applets/Calaos/graphics/no-cam.png")),
                                                        sound = "WINDOWSHOW",
                                                        callback =
                                                                function(event, item)
                                                                        _returnTimer:stop()

                                                                        -- Show the fullscreen camera
                                                                        local cwindow = Window("window", "Calaos Media", "albumtitle")

                                                                        cwindow:setTitleWidget(Group("albumtitle", {
                                                                                text = Label("text", "Calaos Media:\n" .. cname),
                                                                                icon = Icon("icon", Surface:loadImage("applets/Calaos/graphics/icon_cam.png")) }))

                                                                        local srf = Surface:newRGBA(width, height)
                                                                        srf:filledRectangle(0, 0, width, height, 0x00000000)
                                                                        local bg = Icon("background", srf)

                                                                        cwindow:addWidget(bg)

                                                                        local cambg = Sprite(width, height, "applets/Calaos/graphics/cambg.png")
                                                                        cwindow:addWidget(cambg.sprite)

                                                                        bg:addAnimation(
                                                                                function()
                                                                                        Sprite_draw(cambg)
                                                                                end,
                                                                                FRAME_RATE
                                                                        )

                                                                        -- Back/Ok key
                                                                        cwindow:addListener(EVENT_KEY_PRESS, 
                                                                                function(evt)
                                                                                        if evt:getKeycode() == KEY_BACK then
                                                                                                cwindow:hide()
                                                                                                window:hide()
                                                                                                if _simpleCamTimer then
                                                                                                        _simpleCamTimer:stop()
                                                                                                        _simpleCamTimer = nil
                                                                                                end
                                                                                                self:calaosMediamenu()
                                                                                        elseif evt:getKeycode() == KEY_GO then
                                                                                                cwindow:bumpRight()
                                                                                        end
                                                                                end
                                                                        )

                                                                        -- timer to return to home screen after a while, moslty to avoid battery comsuption
                                                                        local _returnTimer = Timer(1000 * 60, -- 1 min
                                                                                function ()
                                                                                        cwindow:hide()
                                                                                        window:hide()
                                                                                        if _simpleCamTimer then
                                                                                                _simpleCamTimer:stop()
                                                                                                _simpleCamTimer = nil
                                                                                        end
                                                                                end,
                                                                                true)
                                                                        _returnTimer:start()

                                                                        _simpleCamTimer = Timer(cameraUpdateTime,
                                                                                function()
                                                                                        local req = RequestHttp(
                                                                                                        function(chunk, err)
                                                                                                                if chunk then
                                                                                                                        local srf = Surface:loadImageData(chunk, #chunk)
--                                                                                                                         srf = srf:zoom(56, 56)

                                                                                                                        local w,h = srf:getSize()
                                                                                                                        if w < h then
                                                                                                                                srf = srf:rotozoom(0, 154 / w, 1)
                                                                                                                        else
                                                                                                                                srf = srf:rotozoom(0, 154 / h, 1)
                                                                                                                        end

                                                                                                                        -- Draw the camera image
                                                                                                                        srf:blit(cambg.sprite:getImage(), 19, 19)
                                                                                                                end
                                                                                                        end,
                                                                                                        'GET',
                                                                                                        jpeg_url)

                                                                                        local uri = req:getURI()
                                                                                        local http = SocketHttp(jnt, uri.host, uri.port, uri.host)

                                                                                        -- fetch image
                                                                                        http:fetch(req)
                                                                                end)
                                                                        _simpleCamTimer:start()

                                                                        self:tieAndShowWindow(cwindow)
                                                                end
                                                }

                                                menu:addItem(item)
                                                addCameraPool(menu, item, jpeg_url, i - 1)
                                        end
                                )
                        end

                        -- run all the jobs
                        self:runJobList(startCameraPool)
                end
        )

        -- Back/Ok key
        window:addListener(EVENT_KEY_PRESS,
                function(evt)
                        if evt:getKeycode() == KEY_BACK or
                           evt:getKeycode() == KEY_GO then
                                clearCameraPool()
                        end
                end
        )

        window:addWidget(menu)
        self:tieAndShowWindow(window)
end

local camPool = { }
local _camCurrent = 1
local _camTimer = nil
function clearCameraPool()
        camPool = { }
        _camCurrent = 1
end

function addCameraPool(menu, item, url, index)
        table.insert(camPool, { menu, item, url, index } )
end

function startCameraPool()

        if #camPool > 0 then

                local t = camPool[_camCurrent]
                local menu = t[1]
                local item = t[2]
                local jpeg_url = t[3]
                local index = t[4]

                local req = RequestHttp(
                                function(chunk, err)
                                        if chunk then
                                                local srf = Surface:loadImageData(chunk, #chunk)
--                                                 srf = srf:zoom(56, 56)

                                                local w,h = srf:getSize()
                                                if w < h then
                                                        srf = srf:rotozoom(0, 56 / w, 1)
                                                else
                                                        srf = srf:rotozoom(0, 56 / h, 1)
                                                end

                                                -- update item image
                                                item.icon = Icon("image", srf)
                                                menu:replaceIndex(item, index)
                                                menu:reLayout()

                                                if _camCurrent == 1 then
                                                        _camTimer = Timer(cameraUpdateTime,
                                                                function()
                                                                        startCameraPool()
                                                                end,
                                                                true)
                                                        _camTimer:start()
                                                else
                                                        startCameraPool()
                                                end
                                        end
                                end,
                                'GET',
                                jpeg_url)

                local uri = req:getURI()
                local http = SocketHttp(jnt, uri.host, uri.port, uri.host)

                -- fetch image
                http:fetch(req)

                _camCurrent = _camCurrent + 1
                if _camCurrent > #camPool then
                        _camCurrent = 1
                end
        end
end

-- Some skins re-definition
function skin(self, s)

        local TEXT_COLOR = { 0xE7, 0xE7, 0xE7 }
        local TEXT_SH_COLOR = { 0x37, 0x37, 0x37 }

        local SELECT_COLOR = { 0x00, 0x00, 0x00 }
        local SELECT_SH_COLOR = { }

        local fontpath = "fonts/"
        local FONT_13px = Font:load(fontpath .. "FreeSans.ttf", 14)
        local FONT_15px = Font:load(fontpath .. "FreeSans.ttf", 16)

        local FONT_BOLD_13px = Font:load(fontpath .. "FreeSansBold.ttf", 14)
        local FONT_BOLD_15px = Font:load(fontpath .. "FreeSansBold.ttf", 16)
        local FONT_BOLD_18px = Font:load(fontpath .. "FreeSansBold.ttf", 20)
        local FONT_BOLD_20px = Font:load(fontpath .. "FreeSansBold.ttf", 22)
        local FONT_BOLD_22px = Font:load(fontpath .. "FreeSansBold.ttf", 24)
        local FONT_BOLD_200px = Font:load(fontpath .. "FreeSansBold.ttf", 200)

        s.big_menu = {}
        s.big_menu.padding = { 4, 2, 4, 2 }
        s.big_menu.itemHeight = 68
        s.big_menu.fg = {0xbb, 0xbb, 0xbb }
        s.big_menu.font = FONT_BOLD_200px

        s.io_menu = {}
        s.io_menu.padding = { 4, 2, 4, 2 }
        s.io_menu.itemHeight = 34
        s.io_menu.fg = {0xbb, 0xbb, 0xbb }
        s.io_menu.font = FONT_BOLD_200px

        s.big_item = {}
        s.big_item.order = { "icon", "text" }
        s.big_item.padding = { 9, 6, 6, 6 }
        s.big_item.text = {}
        s.big_item.text.w = WH_FILL
        s.big_item.text.padding = { 6, 8, 8, 8 }
        s.big_item.text.align = "top-left"
        s.big_item.text.font = FONT_13px
        s.big_item.text.lineHeight = 16
        s.big_item.text.line = {
                {
                        font = FONT_BOLD_13px,
                        height = 17
                }
        }
        s.big_item.text.fg = TEXT_COLOR
        s.big_item.text.sh = TEXT_SH_COLOR

        local imgpath = "applets/DefaultSkin/images/"
        local selectionBox =
                Tile:loadTiles({
                                       imgpath .. "menu_album_selection.png",
                                       imgpath .. "menu_album_selection_tl.png",
                                       imgpath .. "menu_album_selection_t.png",
                                       imgpath .. "menu_album_selection_tr.png",
                                       imgpath .. "menu_album_selection_r.png",
                                       imgpath .. "menu_album_selection_br.png",
                                       imgpath .. "menu_album_selection_b.png",
                                       imgpath .. "menu_album_selection_bl.png",
                                       imgpath .. "menu_album_selection_l.png"
                               })

        -- defines a new style that inherrits from an existing style
        local function _uses(parent, value)
                local style = {}
                setmetatable(style, { __index = parent })

                for k,v in pairs(value or {}) do
                        if type(v) == "table" and type(parent[k]) == "table" then
                                -- recursively inherrit from parent style
                                style[k] = _uses(parent[k], v)
                        else
                                style[k] = v
                        end
                end

                return style
        end

        s.selected.big_item = _uses(s.big_item, {
                              bgImg = selectionBox,
                              text = {
                                      fg = SELECT_COLOR,
                                      sh = SELECT_SH_COLOR
                              }
                      })
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

-- Connect and send Wrapper
function CSendCommand(self, cmd, callback)
        -- start the connection process if needed
        CalaosConnect(function () self:CSendCommand(cmd, callback) end,
                      function () self:calaosMainmenu() end)

        SendCommand(cmd, callback)
end

-- Add a command to the joblist
local _jobList = { }
function addCSendCommand(self, cmd, callback)
        table.insert(_jobList, { cmd, callback })
end

function clearJobList()
        _jobList = {}
end

function runJobList(self, callback_end)

        if #_jobList > 0 then
                local t = _jobList[1]
                local cmd = t[1]
                local callback = t[2]
                table.remove(_jobList, 1)
                self:CSendCommand(cmd,
                        function (chunk, err)
                                if callback then callback(chunk, err) end

                                -- run the next job
                                self:runJobList(callback_end)
                        end
                )
        else
                if callback_end then
                        callback_end()
                end
        end
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

-- Utility function to get the real name for a room
function _getRealRoomName(room)

        if room == "lounge" or room == "salon" then
                return "Salon"
        end
        if room == "chambre" or room == "bedroom" then
                return "Chambre"
        end
        if room == "cuisine" or room == "kitchen" then
                return "Cuisine"
        end
        if room == "bureau" or room == "office" then
                return "Bureau"
        end
        if room == "sam" or room == "diningroom" then
                return "Salle à manger"
        end
        if room == "cave" or room == "cellar" then
                return "Cave"
        end
        if room == "divers" or room == "various" or room == "misc" then
                return "Divers"
        end
        if room == "exterieur" or room == "outside" then
                return "Exterieur"
        end
        if room == "sdb" or room == "bathroom" then
                return "Salle de bain"
        end
        if room == "hall" or room == "couloir" or room == "corridor" then
                return "Couloir"
        end

        return room
end

function _getRealPicture(room)
        local pict = "applets/Calaos/graphics/mini-"

        if room == "lounge" or room == "salon" then
                return pict .. "lounge.png"
        end
        if room == "chambre" or room == "bedroom" then
                return pict .. "empty.png"
        end
        if room == "cuisine" or room == "kitchen" then
                return pict .. "empty.png"
        end
        if room == "bureau" or room == "office" then
                return pict .. "empty.png"
        end
        if room == "sam" or room == "diningroom" then
                return pict .. "empty.png"
        end
        if room == "cave" or room == "cellar" then
                return pict .. "empty.png"
        end
        if room == "divers" or room == "various" or room == "misc" then
                return pict .. "empty.png"
        end
        if room == "exterieur" or room == "outside" then
                return pict .. "empty.png"
        end
        if room == "sdb" or room == "bathroom" then
                return pict .. "empty.png"
        end
        if room == "hall" or room == "couloir" or room == "corridor" then
                return pict .. "empty.png"
        end

        return pict .. "empty.png"
end




