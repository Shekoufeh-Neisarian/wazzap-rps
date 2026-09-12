#!/bin/bash

# ============================================================
# WAZZAP - Rock Paper Scissors Protocol Engine
# ============================================================

SERVER_MODE=$(echo "${1:-ROCK}" | tr '[:lower:]' '[:upper:]')

CLIENT_NAME=""

ROUND=0
WINS=0
LOSSES=0
TIES=0


# ------------------------------------------------------------
# Logging
# Logs go to stderr, so they do NOT interfere with
# protocol messages sent to the network client.
# ------------------------------------------------------------

log() {
    echo "[$(date '+%H:%M:%S')] $*" >&2
}


# ------------------------------------------------------------
# Protocol error helper
# ------------------------------------------------------------

send_error() {
    echo "ERROR:$1:$2"
}


# ------------------------------------------------------------
# Validate server mode
# Allowed:
#   ROCK
#   PAPER
#   SCISSORS
#   RANDOM
# ------------------------------------------------------------

case "$SERVER_MODE" in
    ROCK|PAPER|SCISSORS|RANDOM)
        ;;
    *)
        log "[ERROR] Invalid server mode: $SERVER_MODE"
        echo "ERROR:SERVER_CONFIG:INVALID_MOVE"
        exit 1
        ;;
esac


# ------------------------------------------------------------
# Select server move
# If RANDOM mode is enabled, a new move is chosen per round.
# ------------------------------------------------------------

choose_server_move() {

    if [ "$SERVER_MODE" = "RANDOM" ]; then

        moves=("ROCK" "PAPER" "SCISSORS")

        index=$((RANDOM % 3))

        ROUND_SERVER_MOVE="${moves[$index]}"

    else

        ROUND_SERVER_MOVE="$SERVER_MODE"

    fi
}


# ------------------------------------------------------------
# Connection start
# ------------------------------------------------------------

log "[CONNECT] New client connected"
log "[SERVER] Mode: $SERVER_MODE"

echo "HELO:Server"


# ============================================================
# MAIN PROTOCOL LOOP
# ============================================================

while read -r line; do

    # Remove Windows carriage returns
    line=$(echo "$line" | tr -d '\r')

    # Ignore empty lines
    [ -z "$line" ] && continue

    log "[RX] $line"


    # --------------------------------------------------------
    # Split colon-separated protocol message
    # --------------------------------------------------------

    IFS=':' read -r cmd sender payload extra <<< "$line"

    cmd=$(echo "$cmd" | tr '[:lower:]' '[:upper:]')


    case "$cmd" in


        # ====================================================
        # HELO:Username
        # ====================================================

        HELO)

            if [ -z "$sender" ] || [ -n "$payload" ]; then

                send_error \
                    "INVALID_HELO" \
                    "Expected HELO:Username"

                log "[ERROR] Invalid HELO format"

                continue
            fi


            CLIENT_NAME="$sender"

            echo "HELO:$CLIENT_NAME"

            log "[HELO] Player registered: $CLIENT_NAME"
            ;;


        # ====================================================
        # PLAY:Username:MOVE
        # ====================================================

        PLAY)

            # Client must introduce itself first

            if [ -z "$CLIENT_NAME" ]; then

                send_error \
                    "HANDSHAKE_REQUIRED" \
                    "Send HELO:Username first"

                log "[ERROR] PLAY received before HELO"

                continue
            fi


            # Validate protocol structure

            if [ -z "$sender" ] || \
               [ -z "$payload" ] || \
               [ -n "$extra" ]; then

                send_error \
                    "INVALID_FORMAT" \
                    "Expected PLAY:Username:MOVE"

                log "[ERROR] Invalid PLAY format"

                continue
            fi


            # Verify username

            if [ "$sender" != "$CLIENT_NAME" ]; then

                send_error \
                    "USERNAME_MISMATCH" \
                    "$sender"

                log "[ERROR] Username mismatch: $sender"

                continue
            fi


            # Normalize player move

            PLAYER_MOVE=$(echo "$payload" |
                tr '[:lower:]' '[:upper:]')


            # Validate player move

            case "$PLAYER_MOVE" in

                ROCK|PAPER|SCISSORS)
                    ;;

                *)

                    send_error \
                        "INVALID_MOVE" \
                        "$payload"

                    log "[ERROR] Invalid move: $payload"

                    continue
                    ;;

            esac


            # ------------------------------------------------
            # Start new round
            # ------------------------------------------------

            ROUND=$((ROUND + 1))

            choose_server_move


            log "[ROUND] $ROUND"
            log "[PLAY] $CLIENT_NAME -> $PLAYER_MOVE"
            log "[SERVER MOVE] $ROUND_SERVER_MOVE"


            # =================================================
            # TIE
            # =================================================

            if [ "$PLAYER_MOVE" = "$ROUND_SERVER_MOVE" ]; then

                TIES=$((TIES + 1))

                echo \
"STAT:Server:TIE:Round $ROUND - Both played $PLAYER_MOVE | Score W:$WINS L:$LOSSES T:$TIES"

                log \
"[RESULT] TIE | Score W:$WINS L:$LOSSES T:$TIES"


            # =================================================
            # PLAYER WINS
            # =================================================

            elif \
                [ "$PLAYER_MOVE" = "ROCK" ] && \
                [ "$ROUND_SERVER_MOVE" = "SCISSORS" ]; then

                WINS=$((WINS + 1))

                echo \
"STAT:Server:WIN:Round $ROUND - Rock crushes Scissors! | Score W:$WINS L:$LOSSES T:$TIES"

                log \
"[RESULT] WIN | Score W:$WINS L:$LOSSES T:$TIES"


            elif \
                [ "$PLAYER_MOVE" = "PAPER" ] && \
                [ "$ROUND_SERVER_MOVE" = "ROCK" ]; then

                WINS=$((WINS + 1))

                echo \
"STAT:Server:WIN:Round $ROUND - Paper covers Rock! | Score W:$WINS L:$LOSSES T:$TIES"

                log \
"[RESULT] WIN | Score W:$WINS L:$LOSSES T:$TIES"


            elif \
                [ "$PLAYER_MOVE" = "SCISSORS" ] && \
                [ "$ROUND_SERVER_MOVE" = "PAPER" ]; then

                WINS=$((WINS + 1))

                echo \
"STAT:Server:WIN:Round $ROUND - Scissors cuts Paper! | Score W:$WINS L:$LOSSES T:$TIES"

                log \
"[RESULT] WIN | Score W:$WINS L:$LOSSES T:$TIES"


            # =================================================
            # PLAYER LOSES
            # =================================================

            elif \
                [ "$ROUND_SERVER_MOVE" = "ROCK" ] && \
                [ "$PLAYER_MOVE" = "SCISSORS" ]; then

                LOSSES=$((LOSSES + 1))

                echo \
"STAT:Server:LOSE:Round $ROUND - Rock crushes Scissors! | Score W:$WINS L:$LOSSES T:$TIES"

                log \
"[RESULT] LOSE | Score W:$WINS L:$LOSSES T:$TIES"


            elif \
                [ "$ROUND_SERVER_MOVE" = "PAPER" ] && \
                [ "$PLAYER_MOVE" = "ROCK" ]; then

                LOSSES=$((LOSSES + 1))

                echo \
"STAT:Server:LOSE:Round $ROUND - Paper covers Rock! | Score W:$WINS L:$LOSSES T:$TIES"

                log \
"[RESULT] LOSE | Score W:$WINS L:$LOSSES T:$TIES"


            else

                LOSSES=$((LOSSES + 1))

                echo \
"STAT:Server:LOSE:Round $ROUND - Scissors cuts Paper! | Score W:$WINS L:$LOSSES T:$TIES"

                log \
"[RESULT] LOSE | Score W:$WINS L:$LOSSES T:$TIES"

            fi
            ;;


        # ====================================================
        # UNKNOWN COMMAND
        # ====================================================

        *)

            send_error \
                "INVALID_COMMAND" \
                "$cmd"

            log "[ERROR] Unknown command: $cmd"
            ;;

    esac

done


# ============================================================
# SESSION END
# ============================================================

log \
"[SUMMARY] Player: ${CLIENT_NAME:-Unknown} | Rounds: $ROUND | Wins: $WINS | Losses: $LOSSES | Ties: $TIES"

log "[DISCONNECT] Client disconnected"
