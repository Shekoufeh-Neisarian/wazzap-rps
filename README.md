# Wazzap — Network Rock Paper Scissors

A real-time network game project built primarily with Bash and Ncat on Kali Linux.

The project implements a custom application-layer protocol for Rock Paper Scissors, public TCP tunneling through Pinggy, a Wireshark Lua dissector, file-based multiplayer IPC, and a bonus two-player Tic-Tac-Toe game with a Python/Tkinter GUI client.

## Features

- Bash-based RPS game server
- Ncat TCP networking
- Custom text-based application protocol
- Fixed and random server moves
- Input validation and error handling
- Round counter and session scoreboard
- Public TCP access through Pinggy
- Custom Wireshark Lua dissector
- Two-player RPS matchmaking using `/tmp` IPC
- Two-player Tic-Tac-Toe server using Bash
- Shared game state with file-based IPC and `flock`
- Python/Tkinter Tic-Tac-Toe GUI
- Remote Tic-Tac-Toe support through Pinggy

## Repository Structure

```text
wazzap-rps/
├── game_logic.sh
├── rps_multiplayer.sh
├── rps_dissector.lua
├── tic_tac_toe/
│   ├── tic_tac_toe.sh
│   ├── start_ttt_server.sh
│   └── ttt_gui.py
├── screenshots/
├── report/
└── README.md
