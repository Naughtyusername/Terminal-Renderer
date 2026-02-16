package terminal_renderer

import "core:os"
import "core:sys/posix"

Cell :: struct {
	ch:    rune, // Unicode character (@ for player, # for wall, etc.)
	fg:    Color, // Foreground color
	bg:    Color, // Background color
	style: Style, // Bold, italic, underline, etc.
}

Color :: struct {
	r, g, b: u8, // alpha or do we not use those in terminals?
}

Style :: bit_set[Style_Flag;u8]
Style_Flag :: enum u8 {
	Bold,
	Italic,
	Underline,
	Reverse, // Swap fg/bg
	Blink, // Please dont use this
}

Buffer :: struct {
	width:  int,
	height: int,
	cells:  []Cell, // width * height flat array
}

// Helper to access cells
get_cell :: proc(buf: ^Buffer, x, y: int) -> ^Cell {
	assert(x >= 0 && x < buf.width && y >= 0 && y < buf.height)
	return &buf.cells[y * buf.width + x]
}

set_cell :: proc(buf: ^Buffer, x, y: int, ch: rune, fg, bg: Color) {
	cell := get_cell(buf, x, y)
	cell.ch = ch
	cell.fg = fg
	cell.bg = bg
}

clear_buffer :: proc(buf: ^Buffer, ch: rune = ' ', fg, bg: Color) {
	for &cell in buf.cells {
		cell.ch = ch
		cell.fg = fg
		cell.bg = bg
        cell.style = {}
	}
}

Terminal :: struct {
    width:         int,
    height:        int,
    // Double buffering
    front:        Buffer, // What's currently on screen
    back:         Buffer, // What we're drawing to

    // Terminal I/O
    //stdin_fd:        posix.FD,
    //stdout_fd:       posix.FD,
    stdin_fd:     int, // 0 for stdin, 1 for stdout, 2 for stderr

    // State
    cursor_vis:   bool,
    mouse_mode:   bool,
    orig_term:    posix.termios,  // Original terminal settings ( restore on exit )
}

enable_raw_mode :: proc(term: ^Terminal) {
    // Get current terminal settings
    posix.tcgetattr(posix.FD(0), &term.orig_term) // 0 = stdin

    // Copy and modify
    raw := term.orig_term

    // Disable:
    // - ECHO (don't show typed chars)
    // - ICANON (no line buffering)
    // - ISIG ( no Ctrl+C signal )
    // - IEXTEN ( no Ctrl+V literal next )
    // Local flags
    raw.c_lflag -= {.ECHO, .ICANON, .ISIG, .IEXTEN}

    // Input flags
    // Disable input processing (CRLF conversion)
    raw.c_iflag -= {.IXON, .ICRNL, .INPCK, .ISTRIP}

    // Output flags
    // Disable output processing (\n -> \r\n)
    raw.c_oflag -= {.OPOST}

    // Control flags
    // Set read to return immediately with any input
    raw.c_cc[.VMIN] = 0   // Min chars to read
    raw.c_cc[.VTIME] = 0  // Timeout in 0.1s (0 = no timeout)

    // Apply settings
    posix.tcsetattr(posix.FD(0), .TCSAFLUSH, &raw)
}

disable_raw_mode :: proc(term: ^Terminal) {
    // Restore original settings
    posix.tcsetattr(posix.FD(0), .TCSAFLUSH, &term.orig_term)
}

// Critical Always restore terminal on exit!
main :: proc() {
    term := init_terminal()
    defer cleanup_terminal(&term) // Restores cooked mode

    // Game ioop...
}
// If you don't restore and the program crashes, your terminal will be unsuable (no echo, weird input)

// ANSI Escape Codes
