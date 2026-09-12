#!/bin/bash

# ============================================================
# WAZZAP - Two-Player Rock Paper Scissors
# Multiplayer matchmaking using /tmp IPC
# ============================================================

STATE_DIR="/tmp/wazzap_rps_multi"
LOCK_FILE="$STATE_DIR/lock"

P1_NAME="$STATE_DIR/p1_joined"
P2_NAME="$STATE_DIR/p2_joined"

P1_MOVE="$STATE_DIR/p1_move"
P2_MOVE="$STATE_DIR/p2_move"

RESULT_P1="$STATE_DIR/result_p1"
RESULT_P2="$STATE_DIR/result_p2"

ROUND_FILE="$STATE_DIR/round"
VERSION_FILE="$STATE_DIR/result_version"

mkdir -p "$STATE_DIR"
touch "$LOCK_FILE"

exec 9>"$LOCK_FILE"

USERNAME=""
ROLE=""

LAST_RESULT_VERSION=0
WAIT_ANNOUNCED=0
MATCH_ANNOUNCED=0


# ============================================================
# Helpers
# ============================================================

log() {
    echo "[$(date '+%H:%M:%S')] $*" >&2
}

send_error() {
    echo "ERROR:$1:$2"
}

sanitize_name() {
    echo "$1" | tr -cd '[:alnum:]_-'
}


# ============================================================
# Initialize shared state
# ============================================================

init_state() {

    flock -x 9

    [ -f "$ROUND_FILE" ] || echo "0" > "$ROUND_FILE"
    [ -f "$VERSION_FILE" ] || echo "0" > "$VERSION_FILE"

    flock -u 9
}


# ============================================================
# Register Player 1 / Player 2
# ============================================================

register_player() {

    local requested

    requested=$(sanitize_name "$1")

    if [ -z "$requested" ]; then
        send_error "INVALID_USERNAME" "Username required"
        return
    fi

    flock -x 9

    local p1=""
    local p2=""

    [ -f "$P1_NAME" ] && p1=$(cat "$P1_NAME")
    [ -f "$P2_NAME" ] && p2=$(cat "$P2_NAME")

    if [ -z "$p1" ]; then

        echo "$requested" > "$P1_NAME"

        USERNAME="$requested"
        ROLE="P1"

    elif [ -z "$p2" ] && [ "$requested" != "$p1" ]; then

        echo "$requested" > "$P2_NAME"

        USERNAME="$requested"
        ROLE="P2"

    else

        flock -u 9

        send_error \
            "LOBBY_FULL" \
            "Two players already connected"

        return
    fi

    LAST_RESULT_VERSION=$(cat "$VERSION_FILE")

    flock -u 9

    echo "HELO:$USERNAME"

    log "[JOIN] $USERNAME registered as $ROLE"
}


# ============================================================
# Lobby monitoring
# ============================================================

poll_lobby() {

    [ -z "$USERNAME" ] && return

    flock -s 9

    local p1=""
    local p2=""

    [ -f "$P1_NAME" ] && p1=$(cat "$P1_NAME")
    [ -f "$P2_NAME" ] && p2=$(cat "$P2_NAME")


    # Detect lobby reset / opponent disconnect

    if [ "$ROLE" = "P1" ] && [ "$p1" != "$USERNAME" ]; then

        flock -u 9

        echo "INFO:Server:LOBBY_RESET"

        exit 0
    fi

    if [ "$ROLE" = "P2" ] && [ "$p2" != "$USERNAME" ]; then

        flock -u 9

        echo "INFO:Server:LOBBY_RESET"

        exit 0
    fi


    # Waiting for opponent

    if [ -z "$p1" ] || [ -z "$p2" ]; then

        if [ "$WAIT_ANNOUNCED" -eq 0 ]; then

            echo "INFO:Server:WAITING_FOR_OPPONENT"

            WAIT_ANNOUNCED=1
        fi

        flock -u 9

        return
    fi


    # Both players available

    if [ "$MATCH_ANNOUNCED" -eq 0 ]; then

        echo "INFO:Server:MATCH_READY:$p1:$p2"

        MATCH_ANNOUNCED=1

        WAIT_ANNOUNCED=0

        log "[MATCH] $p1 vs $p2"
    fi

    flock -u 9
}


# ============================================================
# Determine outcome
# ============================================================

evaluate_round() {

    flock -x 9

    # Wait until both files exist
    if [ ! -f "$P1_MOVE" ] || [ ! -f "$P2_MOVE" ]; then

        flock -u 9

        return
    fi


    local p1
    local p2
    local m1
    local m2
    local round
    local version

    p1=$(cat "$P1_NAME")
    p2=$(cat "$P2_NAME")

    m1=$(cat "$P1_MOVE")
    m2=$(cat "$P2_MOVE")

    round=$(cat "$ROUND_FILE")
    round=$((round + 1))


    local verdict1
    local verdict2
    local description


    # --------------------------------------------------------
    # Tie
    # --------------------------------------------------------

    if [ "$m1" = "$m2" ]; then

        verdict1="TIE"
        verdict2="TIE"

        description="Both played $m1"


    # --------------------------------------------------------
    # Player 1 wins
    # --------------------------------------------------------

    elif \
        { [ "$m1" = "ROCK" ] && [ "$m2" = "SCISSORS" ]; } || \
        { [ "$m1" = "PAPER" ] && [ "$m2" = "ROCK" ]; } || \
        { [ "$m1" = "SCISSORS" ] && [ "$m2" = "PAPER" ]; }; then

        verdict1="WIN"
        verdict2="LOSE"


        if [ "$m1" = "ROCK" ]; then
            description="Rock crushes Scissors"

        elif [ "$m1" = "PAPER" ]; then
            description="Paper covers Rock"

        else
            description="Scissors cuts Paper"
        fi


    # --------------------------------------------------------
    # Player 2 wins
    # --------------------------------------------------------

    else

        verdict1="LOSE"
        verdict2="WIN"


        if [ "$m2" = "ROCK" ]; then
            description="Rock crushes Scissors"

        elif [ "$m2" = "PAPER" ]; then
            description="Paper covers Rock"

        else
            description="Scissors cuts Paper"
        fi

    fi


    echo \
"STAT:Server:$verdict1:Round $round - $description | You:$m1 Opponent:$m2" \
        > "$RESULT_P1"


    echo \
"STAT:Server:$verdict2:Round $round - $description | You:$m2 Opponent:$m1" \
        > "$RESULT_P2"


    echo "$round" > "$ROUND_FILE"


    version=$(cat "$VERSION_FILE")
    version=$((version + 1))

    echo "$version" > "$VERSION_FILE"


    # Clean move files so next round can start
    rm -f "$P1_MOVE" "$P2_MOVE"


    log \
"[ROUND $round] $p1:$m1 vs $p2:$m2 -> $verdict1/$verdict2"


    flock -u 9
}


# ============================================================
# Submit move
# ============================================================

submit_move() {

    local sender="$1"
    local move="$2"


    if [ -z "$USERNAME" ]; then

        send_error \
            "HANDSHAKE_REQUIRED" \
            "Send HELO:Username first"

        return
    fi


    if [ "$sender" != "$USERNAME" ]; then

        send_error \
            "USERNAME_MISMATCH" \
            "$sender"

        return
    fi


    move=$(echo "$move" | tr '[:lower:]' '[:upper:]')


    case "$move" in

        ROCK|PAPER|SCISSORS)
            ;;

        *)

            send_error \
                "INVALID_MOVE" \
                "$move"

            return
            ;;

    esac


    flock -x 9


    if [ ! -f "$P1_NAME" ] || [ ! -f "$P2_NAME" ]; then

        flock -u 9

        send_error \
            "NO_OPPONENT" \
            "Waiting for second player"

        return
    fi


    local move_file

    if [ "$ROLE" = "P1" ]; then
        move_file="$P1_MOVE"
    else
        move_file="$P2_MOVE"
    fi


    if [ -f "$move_file" ]; then

        flock -u 9

        send_error \
            "MOVE_ALREADY_SUBMITTED" \
            "Wait for opponent"

        return
    fi


    echo "$move" > "$move_file"


    local round

    round=$(cat "$ROUND_FILE")
    round=$((round + 1))


    flock -u 9


    echo \
"INFO:Server:MOVE_ACCEPTED:Round:$round"


    log \
"[MOVE] $USERNAME ($ROLE) -> $move"


    evaluate_round
}


# ============================================================
# Deliver result to this client
# ============================================================

poll_result() {

    [ -z "$USERNAME" ] && return


    flock -s 9


    local version

    version=$(cat "$VERSION_FILE")


    if [ "$version" -gt "$LAST_RESULT_VERSION" ]; then

        local result_file


        if [ "$ROLE" = "P1" ]; then
            result_file="$RESULT_P1"
        else
            result_file="$RESULT_P2"
        fi


        if [ -f "$result_file" ]; then

            cat "$result_file"

            LAST_RESULT_VERSION="$version"
        fi

    fi


    flock -u 9
}


# ============================================================
# Cleanup when a player disconnects
# ============================================================

cleanup() {

    [ -z "$USERNAME" ] && return


    flock -x 9


    local registered=""


    if [ "$ROLE" = "P1" ] && [ -f "$P1_NAME" ]; then
        registered=$(cat "$P1_NAME")

    elif [ "$ROLE" = "P2" ] && [ -f "$P2_NAME" ]; then
        registered=$(cat "$P2_NAME")
    fi


    if [ "$registered" = "$USERNAME" ]; then

        log \
"[DISCONNECT] $USERNAME left - resetting multiplayer lobby"


        rm -f \
            "$P1_NAME" \
            "$P2_NAME" \
            "$P1_MOVE" \
            "$P2_MOVE" \
            "$RESULT_P1" \
            "$RESULT_P2"


        echo "0" > "$ROUND_FILE"


        local version

        version=$(cat "$VERSION_FILE")
        version=$((version + 1))

        echo "$version" > "$VERSION_FILE"

    fi


    flock -u 9
}


trap cleanup EXIT INT TERM


# ============================================================
# Start session
# ============================================================

init_state

echo "HELO:Server"
echo "INFO:Server:RPS_MULTIPLAYER_READY"


# ============================================================
# Main loop
# ============================================================

while true; do

    if read -r -t 0.25 line; then

        line=$(echo "$line" | tr -d '\r')

        [ -z "$line" ] && continue


        log "[RX] $line"


        IFS=':' read -r cmd sender payload extra <<< "$line"

        cmd=$(echo "$cmd" | tr '[:lower:]' '[:upper:]')


        case "$cmd" in


            HELO)

                if [ -n "$payload" ]; then

                    send_error \
                        "INVALID_HELO" \
                        "Expected HELO:Username"

                elif [ -n "$USERNAME" ]; then

                    send_error \
                        "ALREADY_REGISTERED" \
                        "$USERNAME"

                else

                    register_player "$sender"

                fi
                ;;


            PLAY)

                if [ -z "$payload" ] || [ -n "$extra" ]; then

                    send_error \
                        "INVALID_FORMAT" \
                        "Expected PLAY:Username:MOVE"

                else

                    submit_move \
                        "$sender" \
                        "$payload"

                fi
                ;;


            *)

                send_error \
                    "INVALID_COMMAND" \
                    "$cmd"
                ;;

        esac

    fi


    poll_lobby
    poll_result

    # Synchronization polling loop
    sleep 0.10

done
