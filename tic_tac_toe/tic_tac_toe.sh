#!/bin/bash

# ============================================================
# WAZZAP - Two-Player Network Tic-Tac-Toe Server
# Shared state via /tmp for ncat-spawned processes
# ============================================================

STATE_DIR="/tmp/wazzap_ttt"
STATE_FILE="$STATE_DIR/state"
LOCK_FILE="$STATE_DIR/lock"

mkdir -p "$STATE_DIR"
touch "$LOCK_FILE"

exec 9>"$LOCK_FILE"

USERNAME=""
SYMBOL=""
LAST_VERSION="-1"

log() {
    echo "[$(date '+%H:%M:%S')] $*" >&2
}

sanitize_name() {
    echo "$1" | tr -cd '[:alnum:]_-'
}

init_state() {
    flock -x 9

    if [ ! -f "$STATE_FILE" ]; then
        cat > "$STATE_FILE" <<EOF
P1=
P2=
BOARD=---------
TURN=X
STATUS=WAITING
WINNER=
VERSION=0
EOF
    fi

    flock -u 9
}

load_state() {
    P1=$(grep '^P1=' "$STATE_FILE" | cut -d= -f2-)
    P2=$(grep '^P2=' "$STATE_FILE" | cut -d= -f2-)
    BOARD=$(grep '^BOARD=' "$STATE_FILE" | cut -d= -f2-)
    TURN=$(grep '^TURN=' "$STATE_FILE" | cut -d= -f2-)
    STATUS=$(grep '^STATUS=' "$STATE_FILE" | cut -d= -f2-)
    WINNER=$(grep '^WINNER=' "$STATE_FILE" | cut -d= -f2-)
    VERSION=$(grep '^VERSION=' "$STATE_FILE" | cut -d= -f2-)
}

save_state() {
    cat > "$STATE_FILE.tmp.$$" <<EOF
P1=$P1
P2=$P2
BOARD=$BOARD
TURN=$TURN
STATUS=$STATUS
WINNER=$WINNER
VERSION=$VERSION
EOF

    mv "$STATE_FILE.tmp.$$" "$STATE_FILE"
}

winner_symbol() {
    local b="$1"

    local lines=(
        "0 1 2"
        "3 4 5"
        "6 7 8"
        "0 3 6"
        "1 4 7"
        "2 5 8"
        "0 4 8"
        "2 4 6"
    )

    for combo in "${lines[@]}"; do
        read -r a b1 c <<< "$combo"

        ca="${b:$a:1}"
        cb="${b:$b1:1}"
        cc="${b:$c:1}"

        if [ "$ca" != "-" ] &&
           [ "$ca" = "$cb" ] &&
           [ "$cb" = "$cc" ]; then

            echo "$ca"
            return
        fi
    done

    echo ""
}

emit_state() {
    flock -s 9
    load_state

    if [ "$VERSION" = "$LAST_VERSION" ]; then
        flock -u 9
        return
    fi

    LAST_VERSION="$VERSION"

    if [ "$STATUS" = "WAITING" ]; then

        echo "WAIT:Opponent"

    elif [ "$STATUS" = "ACTIVE" ]; then

        echo "START:$P1:X:$P2:O"
        echo "BOARD:$BOARD"

        if [ "$TURN" = "X" ]; then
            echo "TURN:$P1"
        else
            echo "TURN:$P2"
        fi

    elif [ "$STATUS" = "WIN" ]; then

        echo "BOARD:$BOARD"
        echo "RESULT:WIN:$WINNER"

    elif [ "$STATUS" = "TIE" ]; then

        echo "BOARD:$BOARD"
        echo "RESULT:TIE:None"
    fi

    flock -u 9
}

register_player() {
    local requested
    requested=$(sanitize_name "$1")

    if [ -z "$requested" ]; then
        echo "ERROR:INVALID_USERNAME:Use letters numbers underscore or hyphen"
        return 1
    fi

    flock -x 9
    load_state

    if [ -z "$P1" ]; then

        P1="$requested"
        USERNAME="$requested"
        SYMBOL="X"

        STATUS="WAITING"
        VERSION=$((VERSION + 1))

        save_state

    elif [ -z "$P2" ] && [ "$requested" != "$P1" ]; then

        P2="$requested"
        USERNAME="$requested"
        SYMBOL="O"

        STATUS="ACTIVE"
        BOARD="---------"
        TURN="X"
        WINNER=""
        VERSION=$((VERSION + 1))

        save_state

    else

        flock -u 9
        echo "ERROR:LOBBY_FULL:Two players already connected"
        return 1
    fi

    flock -u 9

    echo "WELCOME:$USERNAME:$SYMBOL"

    log "[JOIN] $USERNAME joined as $SYMBOL"

    return 0
}

make_move() {
    local sender="$1"
    local position="$2"

    if [ -z "$USERNAME" ]; then
        echo "ERROR:NOT_JOINED:Send JOIN:Username first"
        return
    fi

    if [ "$sender" != "$USERNAME" ]; then
        echo "ERROR:USERNAME_MISMATCH:$sender"
        return
    fi

    if ! [[ "$position" =~ ^[1-9]$ ]]; then
        echo "ERROR:INVALID_POSITION:Choose 1-9"
        return
    fi

    flock -x 9
    load_state

    if [ "$STATUS" != "ACTIVE" ]; then
        flock -u 9
        echo "ERROR:GAME_NOT_ACTIVE:Waiting or game finished"
        return
    fi

    if [ "$TURN" != "$SYMBOL" ]; then
        flock -u 9
        echo "ERROR:NOT_YOUR_TURN:Wait for opponent"
        return
    fi

    idx=$((position - 1))

    cell="${BOARD:$idx:1}"

    if [ "$cell" != "-" ]; then
        flock -u 9
        echo "ERROR:CELL_OCCUPIED:$position"
        return
    fi

    BOARD="${BOARD:0:$idx}$SYMBOL${BOARD:$((idx + 1))}"

    winner=$(winner_symbol "$BOARD")

    if [ -n "$winner" ]; then

        STATUS="WIN"
        WINNER="$USERNAME"

    elif [[ "$BOARD" != *"-"* ]]; then

        STATUS="TIE"

    else

        if [ "$TURN" = "X" ]; then
            TURN="O"
        else
            TURN="X"
        fi
    fi

    VERSION=$((VERSION + 1))

    save_state

    log "[MOVE] $USERNAME ($SYMBOL) -> $position | $BOARD"

    flock -u 9
}

reset_game() {
    if [ -z "$USERNAME" ]; then
        echo "ERROR:NOT_JOINED:Join first"
        return
    fi

    flock -x 9
    load_state

    if [ -z "$P1" ] || [ -z "$P2" ]; then
        flock -u 9
        echo "ERROR:NO_OPPONENT:Two players required"
        return
    fi

    BOARD="---------"
    TURN="X"
    STATUS="ACTIVE"
    WINNER=""
    VERSION=$((VERSION + 1))

    save_state

    log "[RESET] New round requested by $USERNAME"

    flock -u 9
}

cleanup() {
    if [ -z "$USERNAME" ]; then
        exit
    fi

    flock -x 9
    load_state

    if [ "$USERNAME" = "$P1" ] || [ "$USERNAME" = "$P2" ]; then

        log "[DISCONNECT] $USERNAME left - lobby reset"

        cat > "$STATE_FILE" <<EOF
P1=
P2=
BOARD=---------
TURN=X
STATUS=WAITING
WINNER=
VERSION=$((VERSION + 1))
EOF
    fi

    flock -u 9
}

trap cleanup EXIT INT TERM

init_state

echo "INFO:Server:Two-player Tic-Tac-Toe ready"
echo "INFO:Protocol:JOIN:Username then MOVE:Username:1-9"

# ============================================================
# Main network loop
# read -t allows us to also poll for opponent state changes
# ============================================================

while true; do

    if read -r -t 0.25 line; then

        line=$(echo "$line" | tr -d '\r')

        [ -z "$line" ] && continue

        log "[RX] $line"

        IFS=':' read -r cmd sender payload extra <<< "$line"

        cmd=$(echo "$cmd" | tr '[:lower:]' '[:upper:]')

        case "$cmd" in

            JOIN)
                if [ -n "$payload" ]; then
                    echo "ERROR:INVALID_JOIN:Expected JOIN:Username"
                elif [ -n "$USERNAME" ]; then
                    echo "ERROR:ALREADY_JOINED:$USERNAME"
                else
                    register_player "$sender"
                fi
                ;;

            MOVE)
                make_move "$sender" "$payload"
                ;;

            RESET)
                reset_game
                ;;

            *)
                echo "ERROR:INVALID_COMMAND:$cmd"
                ;;
        esac
    fi

    if [ -n "$USERNAME" ]; then
        emit_state
    fi

done
