CreateThread(function()
    while true do
        Wait(0)
        if NetworkIsPlayerActive(PlayerId()) then
            Wait(500)
            TriggerServerEvent('mvp_discordapi:verify_player')
            break
        end
    end
end)