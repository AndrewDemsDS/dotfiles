-- This file will not be overwritten across dots-hyprland updates.
-- The file name is for the sake of organization and does not matter
-- See the corresponding files in ~/.config/hypr/hyprland for examples

hl.on("hyprland.start", function ()
    -- VMware guest clipboard/resize bridge (no-ops on bare metal)
    hl.exec_cmd("/usr/bin/vmware-user-suid-wrapper")
end)
