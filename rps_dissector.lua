-- ============================================================
-- WAZZAP - Rock Paper Scissors Wireshark Dissector
-- Custom application-layer protocol on TCP port 12345
-- ============================================================

local rps = Proto("rps", "Rock Paper Scissors Protocol")

-- Basic protocol fields
local f_command     = ProtoField.string("rps.command", "Command")
local f_player      = ProtoField.string("rps.player", "Player / Sender")
local f_move        = ProtoField.string("rps.move", "Move")
local f_verdict     = ProtoField.string("rps.verdict", "Verdict")
local f_description = ProtoField.string("rps.description", "Description")
local f_error_type  = ProtoField.string("rps.error_type", "Error Type")
local f_raw         = ProtoField.string("rps.raw", "Raw Message")

-- Enhanced scoreboard fields
local f_round       = ProtoField.uint32("rps.round", "Round")
local f_wins        = ProtoField.uint32("rps.wins", "Wins")
local f_losses      = ProtoField.uint32("rps.losses", "Losses")
local f_ties        = ProtoField.uint32("rps.ties", "Ties")

rps.fields = {
    f_command,
    f_player,
    f_move,
    f_verdict,
    f_description,
    f_error_type,
    f_raw,
    f_round,
    f_wins,
    f_losses,
    f_ties
}

function rps.dissector(buffer, pinfo, tree)

    if buffer:len() == 0 then
        return
    end

    local data = buffer():string()

    pinfo.cols.protocol = "RPS"

    local root = tree:add(
        rps,
        buffer(),
        "Rock Paper Scissors Protocol"
    )

    -- One TCP segment may contain multiple newline-delimited messages
    for line in data:gmatch("[^\r\n]+") do

        local msg_tree = root:add(
            rps,
            buffer(),
            "RPS Message"
        )

        msg_tree:add(f_raw, buffer(), line)

        local command_raw = line:match("^([^:]+)")

        if command_raw then

            -- Normalize command for case-insensitive recognition
            local command = string.upper(command_raw)

            msg_tree:add(f_command, buffer(), command)

            -- =====================================================
            -- HELO:Username
            -- =====================================================
            if command == "HELO" then

                local player =
                    line:match("^[^:]+:([^:]+)$")

                if player then
                    msg_tree:add(f_player, buffer(), player)

                    pinfo.cols.info =
                        "HELO - " .. player
                end


            -- =====================================================
            -- PLAY:Username:MOVE
            -- =====================================================
            elseif command == "PLAY" then

                local player, move =
                    line:match(
                        "^[^:]+:([^:]+):([^:]+)$"
                    )

                if player and move then

                    msg_tree:add(f_player, buffer(), player)
                    msg_tree:add(f_move, buffer(), move)

                    pinfo.cols.info =
                        "PLAY - " ..
                        player ..
                        " -> " ..
                        move
                end


            -- =====================================================
            -- STAT:Server:VERDICT:Description
            -- =====================================================
            elseif command == "STAT" then

                local sender, verdict, description =
                    line:match(
                        "^[^:]+:([^:]+):([^:]+):(.+)$"
                    )

                if sender and verdict and description then

                    msg_tree:add(
                        f_player,
                        buffer(),
                        sender
                    )

                    msg_tree:add(
                        f_verdict,
                        buffer(),
                        verdict
                    )

                    msg_tree:add(
                        f_description,
                        buffer(),
                        description
                    )

                    -- Extract enhanced game-state information
                    local round =
                        description:match(
                            "Round%s+(%d+)"
                        )

                    local wins, losses, ties =
                        description:match(
                            "Score%s+W:(%d+)%s+L:(%d+)%s+T:(%d+)"
                        )

                    if round then
                        msg_tree:add(
                            f_round,
                            tonumber(round)
                        )
                    end

                    if wins then
                        msg_tree:add(
                            f_wins,
                            tonumber(wins)
                        )
                    end

                    if losses then
                        msg_tree:add(
                            f_losses,
                            tonumber(losses)
                        )
                    end

                    if ties then
                        msg_tree:add(
                            f_ties,
                            tonumber(ties)
                        )
                    end

                    pinfo.cols.info =
                        "STAT - " ..
                        verdict ..
                        " - Round " ..
                        (round or "?") ..
                        " | W:" ..
                        (wins or "?") ..
                        " L:" ..
                        (losses or "?") ..
                        " T:" ..
                        (ties or "?")
                end


            -- =====================================================
            -- ERROR:Type:Description
            -- =====================================================
            elseif command == "ERROR" then

                local error_type, description =
                    line:match(
                        "^[^:]+:([^:]+):(.+)$"
                    )

                if error_type and description then

                    msg_tree:add(
                        f_error_type,
                        buffer(),
                        error_type
                    )

                    msg_tree:add(
                        f_description,
                        buffer(),
                        description
                    )

                    pinfo.cols.info =
                        "ERROR - " .. error_type
                end
            end
        end
    end
end

-- Register this protocol for TCP port 12345
local tcp_port = DissectorTable.get("tcp.port")
tcp_port:add(12345, rps)
