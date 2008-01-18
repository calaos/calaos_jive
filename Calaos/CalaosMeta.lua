
--[[
=head1 NAME

applets.Test.TestMeta - Test meta-info

=head1 DESCRIPTION

See L<applets.Test.TestApplet>.

=head1 FUNCTIONS

See L<jive.AppletMeta> for a description of standard applet meta functions.

=cut
--]]


local oo            = require("loop.simple")

local AppletMeta    = require("jive.AppletMeta")

local appletManager = appletManager
local jiveMain      = jiveMain


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
	
	jiveMain:addItem(meta:menuItem('appletCalaos', 'home', "Calaos Home", function(applet, ...) applet:startApplet(meta) end, 800))
        jiveMain:loadSkin("Calaos", "skin")

end


--[[

=head1 LICENSE

Copyright 2008 Calaos. All Rights Reserved.

=cut
--]]

