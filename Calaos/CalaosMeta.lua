
--[[

Calaos Applet

--]]


local oo            = require("loop.simple")

local AppletMeta    = require("jive.AppletMeta")
local Surface       = require("jive.ui.Surface")
local Icon          = require("jive.ui.Icon")

local appletManager = appletManager
local jiveMain      = jiveMain

local debug         = require("jive.utils.log")

module(...)
oo.class(_M, AppletMeta)


function jiveVersion(meta)
	return 1, 1
end

function defaultSettings(meta)
        return {
                [ "calaos_user" ] = "",
                [ "calaos_pass" ] = ""
        }
end

function registerApplet(meta)

        local item = meta:menuItem('appletCalaos', 'home', "Calaos Home", function(applet, ...) applet:startApplet(meta) end, 800)
        jiveMain:addItem(item)

end


--[[

=head1 LICENSE

Copyright 2008 Calaos. All Rights Reserved.

http://www.calaos.fr

--]]

