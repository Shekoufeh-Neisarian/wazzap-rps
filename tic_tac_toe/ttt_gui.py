import socket
import threading
import queue
import tkinter as tk
from tkinter import messagebox


class TicTacToeClient:
    def __init__(self, root):
        self.root = root
        self.root.title("Wazzap - Network Tic-Tac-Toe")

        # Compact size for Windows display scaling
        self.root.geometry("560x660")
        self.root.minsize(560, 660)
        self.root.resizable(False, False)

        # ====================================================
        # APPLICATION STATE
        # ====================================================

        self.sock = None
        self.connected = False

        self.username = ""
        self.symbol = ""
        self.opponent = ""

        self.my_turn = False
        self.board = "---------"

        self.messages = queue.Queue()

        # ====================================================
        # COLORS
        # ====================================================

        self.bg_main = "#f4f7fb"
        self.bg_card = "#ffffff"
        self.bg_board = "#d9e4f5"

        self.btn_empty = "#ffffff"
        self.btn_active = "#e8f0fe"

        self.color_x = "#1976d2"
        self.color_o = "#d32f2f"

        self.text_dark = "#1f2d3d"
        self.text_soft = "#4f5d75"

        self.green = "#2e7d32"
        self.orange = "#ef6c00"
        self.red = "#c62828"
        self.gray = "#607d8b"

        # Winner highlight
        self.winner_bg = "#a5d6a7"
        self.winner_active = "#81c784"

        self.root.configure(bg=self.bg_main)

        # ====================================================
        # TITLE
        # ====================================================

        title_frame = tk.Frame(
            root,
            bg=self.bg_main
        )
        title_frame.pack(pady=(8, 2))

        tk.Label(
            title_frame,
            text="Wazzap - Network Tic-Tac-Toe",
            font=("Arial", 19, "bold"),
            fg=self.text_dark,
            bg=self.bg_main
        ).pack()

        tk.Label(
            title_frame,
            text="Two-player GUI client over TCP",
            font=("Arial", 9),
            fg=self.text_soft,
            bg=self.bg_main
        ).pack(pady=(1, 0))

        # ====================================================
        # CONNECTION CARD
        # ====================================================

        self.connection_card = tk.Frame(
            root,
            bg=self.bg_card,
            bd=2,
            relief="groove",
            padx=10,
            pady=6
        )

        self.connection_card.pack(
            pady=6,
            padx=18,
            fill="x"
        )

        tk.Label(
            self.connection_card,
            text="Connection Settings",
            font=("Arial", 11, "bold"),
            fg=self.text_dark,
            bg=self.bg_card
        ).grid(
            row=0,
            column=0,
            columnspan=2,
            sticky="w",
            pady=(0, 4)
        )

        # ----------------------------------------------------
        # SERVER IP
        # ----------------------------------------------------

        tk.Label(
            self.connection_card,
            text="Server IP:",
            font=("Arial", 9),
            bg=self.bg_card,
            fg=self.text_dark
        ).grid(
            row=1,
            column=0,
            sticky="e",
            padx=6,
            pady=2
        )

        self.host_entry = tk.Entry(
            self.connection_card,
            width=24,
            font=("Arial", 9)
        )

        self.host_entry.insert(
            0,
            "10.10.10.129"
        )

        self.host_entry.grid(
            row=1,
            column=1,
            sticky="w",
            pady=2
        )

        # ----------------------------------------------------
        # PORT
        # ----------------------------------------------------

        tk.Label(
            self.connection_card,
            text="Port:",
            font=("Arial", 9),
            bg=self.bg_card,
            fg=self.text_dark
        ).grid(
            row=2,
            column=0,
            sticky="e",
            padx=6,
            pady=2
        )

        self.port_entry = tk.Entry(
            self.connection_card,
            width=24,
            font=("Arial", 9)
        )

        self.port_entry.insert(
            0,
            "12346"
        )

        self.port_entry.grid(
            row=2,
            column=1,
            sticky="w",
            pady=2
        )

        # ----------------------------------------------------
        # PLAYER NAME
        # ----------------------------------------------------

        tk.Label(
            self.connection_card,
            text="Player name:",
            font=("Arial", 9),
            bg=self.bg_card,
            fg=self.text_dark
        ).grid(
            row=3,
            column=0,
            sticky="e",
            padx=6,
            pady=2
        )

        self.name_entry = tk.Entry(
            self.connection_card,
            width=24,
            font=("Arial", 9)
        )

        self.name_entry.grid(
            row=3,
            column=1,
            sticky="w",
            pady=2
        )

        # ----------------------------------------------------
        # CONNECT BUTTON
        # ----------------------------------------------------

        self.connect_button = tk.Button(
            self.connection_card,
            text="Connect",
            width=18,
            font=("Arial", 9, "bold"),
            bg="#1565c0",
            fg="white",
            activebackground="#0d47a1",
            activeforeground="white",
            relief="raised",
            bd=3,
            cursor="hand2",
            command=self.connect_to_server
        )

        self.connect_button.grid(
            row=4,
            column=0,
            columnspan=2,
            pady=(6, 1)
        )

        # ====================================================
        # PLAYER INFORMATION CARD
        # ====================================================

        self.info_card = tk.Frame(
            root,
            bg=self.bg_card,
            bd=2,
            relief="groove",
            padx=10,
            pady=6
        )

        self.info_card.pack(
            pady=4,
            padx=18,
            fill="x"
        )

        self.player_label = tk.Label(
            self.info_card,
            text="You: -",
            font=("Arial", 10, "bold"),
            fg=self.text_dark,
            bg=self.bg_card
        )

        self.player_label.pack(
            anchor="w"
        )

        self.opponent_label = tk.Label(
            self.info_card,
            text="Opponent: -",
            font=("Arial", 9),
            fg=self.text_dark,
            bg=self.bg_card
        )

        self.opponent_label.pack(
            anchor="w",
            pady=(2, 0)
        )

        self.status_label = tk.Label(
            self.info_card,
            text="Not connected",
            font=("Arial", 9, "bold"),
            fg=self.orange,
            bg=self.bg_card,
            wraplength=470,
            justify="left"
        )

        self.status_label.pack(
            anchor="w",
            pady=(3, 0)
        )

        # ----------------------------------------------------
        # CELEBRATION EMOJI
        # ----------------------------------------------------

        self.celebration_label = tk.Label(
            self.info_card,
            text="",
            font=("Segoe UI Emoji", 18),
            fg=self.green,
            bg=self.bg_card
        )

        self.celebration_label.pack(
            pady=(2, 0)
        )

        # ====================================================
        # GAME BOARD TITLE
        # ====================================================

        tk.Label(
            root,
            text="Game Board",
            font=("Arial", 12, "bold"),
            fg=self.text_dark,
            bg=self.bg_main
        ).pack(
            pady=(5, 2)
        )

        # ====================================================
        # GAME BOARD
        # ====================================================

        board_outer = tk.Frame(
            root,
            bg=self.bg_board,
            bd=3,
            relief="ridge",
            padx=6,
            pady=6
        )

        board_outer.pack(
            pady=2
        )

        board_frame = tk.Frame(
            board_outer,
            bg=self.bg_board
        )

        board_frame.pack()

        self.buttons = []

        # Smaller board so everything fits on screen
        for row in range(3):
            board_frame.grid_rowconfigure(
                row,
                minsize=65
            )

        for column in range(3):
            board_frame.grid_columnconfigure(
                column,
                minsize=85
            )

        for i in range(9):

            button = tk.Button(
                board_frame,
                text="",
                font=("Arial", 21, "bold"),
                width=4,
                height=1,
                bg=self.btn_empty,
                fg=self.text_dark,
                disabledforeground=self.text_dark,
                activebackground=self.btn_active,
                relief="raised",
                bd=4,
                highlightthickness=1,
                highlightbackground="#9fb3d1",
                state="disabled",
                command=lambda pos=i: self.make_move(pos)
            )

            button.grid(
                row=i // 3,
                column=i % 3,
                padx=3,
                pady=3,
                sticky="nsew"
            )

            self.buttons.append(button)

        # ====================================================
        # NEW GAME BUTTON
        # ====================================================

        control_frame = tk.Frame(
            root,
            bg=self.bg_main
        )

        control_frame.pack(
            pady=(6, 2)
        )

        self.new_game_button = tk.Button(
            control_frame,
            text="New Game",
            width=16,
            font=("Arial", 9, "bold"),
            bg="#43a047",
            fg="white",
            activebackground="#2e7d32",
            activeforeground="white",
            relief="raised",
            bd=3,
            cursor="hand2",
            state="disabled",
            command=self.request_new_game
        )

        self.new_game_button.pack()

        # ====================================================
        # CONNECTION STATUS
        # ====================================================

        self.connection_status = tk.Label(
            root,
            text="● Offline",
            font=("Arial", 9, "bold"),
            fg=self.red,
            bg=self.bg_main
        )

        self.connection_status.pack(
            pady=(1, 3)
        )

        # ====================================================
        # WINDOW EVENTS
        # ====================================================

        self.root.protocol(
            "WM_DELETE_WINDOW",
            self.close
        )

        self.root.after(
            100,
            self.process_messages
        )

    # ========================================================
    # CONNECT TO SERVER
    # ========================================================

    def connect_to_server(self):

        if self.connected:
            return

        host = self.host_entry.get().strip()
        name = self.name_entry.get().strip()

        try:
            port = int(
                self.port_entry.get()
            )

        except ValueError:

            messagebox.showerror(
                "Error",
                "Port must be a number."
            )
            return

        if not name:

            messagebox.showerror(
                "Error",
                "Please enter your player name."
            )
            return

        try:

            self.sock = socket.socket(
                socket.AF_INET,
                socket.SOCK_STREAM
            )

            self.sock.connect(
                (host, port)
            )

            self.connected = True
            self.username = name

            self.connection_status.config(
                text="● Connected via TCP",
                fg=self.green
            )

            self.status_label.config(
                text="Connected. Joining game...",
                fg=self.green
            )

            # Disable connection controls
            self.connect_button.config(
                state="disabled"
            )

            self.host_entry.config(
                state="disabled"
            )

            self.port_entry.config(
                state="disabled"
            )

            self.name_entry.config(
                state="disabled"
            )

            # Hide connection settings after successful connect
            # This creates more room for the game board.
            self.connection_card.pack_forget()

            thread = threading.Thread(
                target=self.receive_loop,
                daemon=True
            )

            thread.start()

            self.send(
                f"JOIN:{self.username}"
            )

        except Exception as exc:

            messagebox.showerror(
                "Connection Error",
                str(exc)
            )

    # ========================================================
    # RECEIVE DATA
    # ========================================================

    def receive_loop(self):

        buffer = ""

        try:

            while self.connected:

                data = self.sock.recv(
                    4096
                )

                if not data:
                    break

                buffer += data.decode(
                    "utf-8",
                    errors="replace"
                )

                while "\n" in buffer:

                    line, buffer = buffer.split(
                        "\n",
                        1
                    )

                    line = line.rstrip(
                        "\r"
                    )

                    if line:
                        self.messages.put(
                            line
                        )

        except Exception as exc:

            if self.connected:

                self.messages.put(
                    f"LOCAL_ERROR:{exc}"
                )

        finally:

            self.connected = False

            self.messages.put(
                "LOCAL_DISCONNECTED"
            )

    # ========================================================
    # PROCESS MESSAGE QUEUE
    # ========================================================

    def process_messages(self):

        while not self.messages.empty():

            message = self.messages.get()

            self.handle_message(
                message
            )

        self.root.after(
            100,
            self.process_messages
        )

    # ========================================================
    # HANDLE SERVER MESSAGES
    # ========================================================

    def handle_message(self, message):

        # ----------------------------------------------------
        # INFORMATION MESSAGE
        # ----------------------------------------------------

        if message.startswith("INFO:"):
            return

        # ----------------------------------------------------
        # WELCOME
        # ----------------------------------------------------

        if message.startswith("WELCOME:"):

            parts = message.split(":")

            if len(parts) >= 3:

                self.symbol = parts[2]

                self.player_label.config(
                    text=(
                        f"You: {self.username} "
                        f"({self.symbol})"
                    )
                )

                self.status_label.config(
                    text="Waiting for opponent...",
                    fg=self.orange
                )

                self.new_game_button.config(
                    state="normal"
                )

            return

        # ----------------------------------------------------
        # WAIT FOR OPPONENT
        # ----------------------------------------------------

        if message.startswith("WAIT:"):

            self.status_label.config(
                text="Waiting for Player 2...",
                fg=self.orange
            )

            self.disable_board()

            return

        # ----------------------------------------------------
        # MATCH STARTED
        # ----------------------------------------------------

        if message.startswith("START:"):

            parts = message.split(":")

            if len(parts) >= 5:

                p1 = parts[1]
                p2 = parts[3]

                if self.username == p1:
                    self.opponent = p2
                else:
                    self.opponent = p1

                self.opponent_label.config(
                    text=(
                        f"Opponent: "
                        f"{self.opponent}"
                    )
                )

                self.status_label.config(
                    text="Match started.",
                    fg=self.green
                )

                self.celebration_label.config(
                    text=""
                )

            return

        # ----------------------------------------------------
        # BOARD UPDATE
        # ----------------------------------------------------

        if message.startswith("BOARD:"):

            self.board = message.split(
                ":",
                1
            )[1]

            self.update_board()

            return

        # ----------------------------------------------------
        # TURN UPDATE
        # ----------------------------------------------------

        if message.startswith("TURN:"):

            player = message.split(
                ":",
                1
            )[1]

            if player == self.username:

                self.my_turn = True

                self.status_label.config(
                    text=(
                        f"Your turn — "
                        f"you are {self.symbol}"
                    ),
                    fg=self.green
                )

                self.enable_available_cells()

            else:

                self.my_turn = False

                self.status_label.config(
                    text=f"{player}'s turn",
                    fg=self.orange
                )

                self.disable_board()

            return

        # ----------------------------------------------------
        # GAME RESULT
        # ----------------------------------------------------

        if message.startswith("RESULT:"):

            parts = message.split(":")

            result = parts[1]

            winner = (
                parts[2]
                if len(parts) > 2
                else ""
            )

            self.my_turn = False

            self.disable_board()

            # ------------------------------------------------
            # WIN
            # ------------------------------------------------

            if result == "WIN":

                self.highlight_winner()

                if winner == self.username:

                    text = "You win! 😄"

                    self.celebration_label.config(
                        text="😄  🏆  😄"
                    )

                else:

                    text = f"{winner} wins!"

                    self.celebration_label.config(
                        text="🏆  😄"
                    )

                self.status_label.config(
                    text=text,
                    fg=self.green
                )

                messagebox.showinfo(
                    "Game Over 😄",
                    text
                )

            # ------------------------------------------------
            # TIE
            # ------------------------------------------------

            elif result == "TIE":

                self.celebration_label.config(
                    text="🤝"
                )

                self.status_label.config(
                    text="Game ended in a tie.",
                    fg=self.gray
                )

                messagebox.showinfo(
                    "Game Over",
                    "It's a tie!"
                )

            return

        # ----------------------------------------------------
        # SERVER ERROR
        # ----------------------------------------------------

        if message.startswith("ERROR:"):

            self.status_label.config(
                text=message,
                fg=self.red
            )

            messagebox.showwarning(
                "Server Response",
                message
            )

            return

        # ----------------------------------------------------
        # LOCAL NETWORK ERROR
        # ----------------------------------------------------

        if message.startswith("LOCAL_ERROR:"):

            messagebox.showerror(
                "Network Error",
                message
            )

            return

        # ----------------------------------------------------
        # CONNECTION CLOSED
        # ----------------------------------------------------

        if message == "LOCAL_DISCONNECTED":

            self.connection_status.config(
                text="● Disconnected",
                fg=self.red
            )

            self.status_label.config(
                text="Connection closed.",
                fg=self.red
            )

            self.disable_board()

    # ========================================================
    # PLAYER MAKES MOVE
    # ========================================================

    def make_move(self, index):

        if not self.connected:
            return

        if not self.my_turn:
            return

        if self.board[index] != "-":
            return

        position = index + 1

        self.send(
            f"MOVE:{self.username}:{position}"
        )

        self.my_turn = False

        self.disable_board()

        self.status_label.config(
            text="Move sent. Waiting for opponent...",
            fg=self.orange
        )

    # ========================================================
    # REQUEST NEW GAME
    # ========================================================

    def request_new_game(self):

        if not self.connected:
            return

        self.celebration_label.config(
            text=""
        )

        self.reset_board_style()

        self.send(
            f"RESET:{self.username}"
        )

    # ========================================================
    # FIND WINNING LINE
    # ========================================================

    def get_winning_line(self):

        winning_lines = [
            (0, 1, 2),
            (3, 4, 5),
            (6, 7, 8),

            (0, 3, 6),
            (1, 4, 7),
            (2, 5, 8),

            (0, 4, 8),
            (2, 4, 6)
        ]

        for a, b, c in winning_lines:

            if (
                self.board[a] != "-"
                and self.board[a] == self.board[b]
                and self.board[b] == self.board[c]
            ):

                return (
                    a,
                    b,
                    c
                )

        return None

    # ========================================================
    # HIGHLIGHT WINNER
    # ========================================================

    def highlight_winner(self):

        winning_line = self.get_winning_line()

        if not winning_line:
            return

        for index in winning_line:

            self.buttons[index].config(
                bg=self.winner_bg,
                activebackground=self.winner_active,
                relief="sunken",
                bd=5
            )

    # ========================================================
    # RESET BOARD STYLE
    # ========================================================

    def reset_board_style(self):

        for button in self.buttons:

            button.config(
                relief="raised",
                bd=4
            )

    # ========================================================
    # UPDATE BOARD
    # ========================================================

    def update_board(self):

        self.reset_board_style()

        for i, cell in enumerate(
            self.board
        ):

            # Empty cell
            if cell == "-":

                self.buttons[i].config(
                    text="",
                    bg=self.btn_empty,
                    fg=self.text_dark,
                    disabledforeground=self.text_dark
                )

            # X
            elif cell == "X":

                self.buttons[i].config(
                    text="X",
                    bg="#e3f2fd",
                    fg=self.color_x,
                    disabledforeground=self.color_x
                )

            # O
            elif cell == "O":

                self.buttons[i].config(
                    text="O",
                    bg="#ffebee",
                    fg=self.color_o,
                    disabledforeground=self.color_o
                )

    # ========================================================
    # DISABLE BOARD
    # ========================================================

    def disable_board(self):

        for button in self.buttons:

            button.config(
                state="disabled"
            )

    # ========================================================
    # ENABLE EMPTY CELLS
    # ========================================================

    def enable_available_cells(self):

        for i, button in enumerate(
            self.buttons
        ):

            if self.board[i] == "-":

                button.config(
                    state="normal",
                    bg=self.btn_active,
                    cursor="hand2"
                )

            else:

                button.config(
                    state="disabled"
                )

    # ========================================================
    # SEND DATA
    # ========================================================

    def send(self, message):

        try:

            self.sock.sendall(
                (
                    message + "\n"
                ).encode(
                    "utf-8"
                )
            )

        except Exception as exc:

            messagebox.showerror(
                "Send Error",
                str(exc)
            )

    # ========================================================
    # CLOSE APPLICATION
    # ========================================================

    def close(self):

        self.connected = False

        try:

            if self.sock:

                self.sock.shutdown(
                    socket.SHUT_RDWR
                )

                self.sock.close()

        except Exception:
            pass

        self.root.destroy()


# ============================================================
# START APPLICATION
# ============================================================

if __name__ == "__main__":

    root = tk.Tk()

    app = TicTacToeClient(
        root
    )

    root.mainloop()