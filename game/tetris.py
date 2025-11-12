"""A simple Tetris implementation using pygame."""
from __future__ import annotations

import random
from dataclasses import dataclass
from typing import Dict, Iterable, List, Optional, Sequence, Tuple

import pygame

GRID_WIDTH = 10
GRID_HEIGHT = 20
BLOCK_SIZE = 32
PLAY_WIDTH = GRID_WIDTH * BLOCK_SIZE
PLAY_HEIGHT = GRID_HEIGHT * BLOCK_SIZE
SIDE_PANEL_WIDTH = 220
WINDOW_SIZE = (PLAY_WIDTH + SIDE_PANEL_WIDTH, PLAY_HEIGHT)

DROP_EVENT = pygame.USEREVENT + 1

SHAPES: Dict[str, List[List[Tuple[int, int]]]] = {
    "I": [
        [(0, 1), (1, 1), (2, 1), (3, 1)],
        [(2, 0), (2, 1), (2, 2), (2, 3)],
    ],
    "J": [
        [(0, 0), (0, 1), (1, 1), (2, 1)],
        [(1, 0), (2, 0), (1, 1), (1, 2)],
        [(0, 1), (1, 1), (2, 1), (2, 2)],
        [(1, 0), (1, 1), (0, 2), (1, 2)],
    ],
    "L": [
        [(2, 0), (0, 1), (1, 1), (2, 1)],
        [(1, 0), (1, 1), (1, 2), (2, 2)],
        [(0, 1), (1, 1), (2, 1), (0, 2)],
        [(0, 0), (1, 0), (1, 1), (1, 2)],
    ],
    "O": [
        [(1, 0), (2, 0), (1, 1), (2, 1)],
    ],
    "S": [
        [(1, 0), (2, 0), (0, 1), (1, 1)],
        [(1, 0), (1, 1), (2, 1), (2, 2)],
    ],
    "T": [
        [(1, 0), (0, 1), (1, 1), (2, 1)],
        [(1, 0), (1, 1), (2, 1), (1, 2)],
        [(0, 1), (1, 1), (2, 1), (1, 2)],
        [(1, 0), (0, 1), (1, 1), (1, 2)],
    ],
    "Z": [
        [(0, 0), (1, 0), (1, 1), (2, 1)],
        [(2, 0), (1, 1), (2, 1), (1, 2)],
    ],
}

SHAPE_ORDER = list(SHAPES.keys())

COLORS: Dict[str, Tuple[int, int, int]] = {
    "I": (0, 240, 240),
    "J": (0, 0, 240),
    "L": (240, 160, 0),
    "O": (240, 240, 0),
    "S": (0, 240, 0),
    "T": (160, 0, 240),
    "Z": (240, 0, 0),
}

BACKGROUND_COLOR = (18, 18, 26)
GRID_COLOR = (45, 45, 60)
TEXT_COLOR = (220, 220, 220)


@dataclass
class Tetromino:
    """Represents a tetromino piece in the Tetris game."""

    name: str
    rotation: int = 0
    position: Tuple[int, int] = (GRID_WIDTH // 2 - 2, 0)

    def cells(self) -> List[Tuple[int, int]]:
        """Return the absolute cell coordinates occupied by the tetromino."""
        offsets = SHAPES[self.name][self.rotation]
        px, py = self.position
        return [(px + ox, py + oy) for ox, oy in offsets]

    def moved(self, dx: int, dy: int) -> "Tetromino":
        """Return a copy of the tetromino moved by ``dx`` and ``dy`` cells."""
        px, py = self.position
        return Tetromino(self.name, self.rotation, (px + dx, py + dy))

    def rotated(self, direction: int) -> "Tetromino":
        """Return a copy of the tetromino rotated clockwise (1) or counter-clockwise (-1)."""
        rotations = SHAPES[self.name]
        return Tetromino(self.name, (self.rotation + direction) % len(rotations), self.position)


def create_board() -> List[List[Optional[str]]]:
    """Create an empty Tetris board."""
    return [[None for _ in range(GRID_WIDTH)] for _ in range(GRID_HEIGHT)]


def is_valid_position(board: Sequence[Sequence[Optional[str]]], piece: Tetromino) -> bool:
    """Check whether ``piece`` can be placed on ``board`` without collisions."""
    for x, y in piece.cells():
        if x < 0 or x >= GRID_WIDTH or y >= GRID_HEIGHT:
            return False
        if y >= 0 and board[y][x] is not None:
            return False
    return True


def lock_piece(board: List[List[Optional[str]]], piece: Tetromino) -> None:
    """Lock the ``piece`` into the ``board`` grid."""
    for x, y in piece.cells():
        if 0 <= y < GRID_HEIGHT:
            board[y][x] = piece.name


def clear_lines(board: List[List[Optional[str]]]) -> int:
    """Clear any full lines from the board and return the number of lines cleared."""
    remaining_rows = [row for row in board if None in row]
    cleared = GRID_HEIGHT - len(remaining_rows)
    while len(remaining_rows) < GRID_HEIGHT:
        remaining_rows.insert(0, [None for _ in range(GRID_WIDTH)])
    board[:] = remaining_rows
    return cleared


def next_bag(random_generator: random.Random) -> Iterable[str]:
    """Yield tetromino names in a random shuffled bag order."""
    bag = SHAPE_ORDER.copy()
    random_generator.shuffle(bag)
    yield from bag


def spawn_piece(queue: List[str], rng: random.Random) -> str:
    """Get the next piece from the queue, refilling it if necessary."""
    if not queue:
        queue.extend(next_bag(rng))
    return queue.pop(0)


def hard_drop(board: Sequence[Sequence[Optional[str]]], piece: Tetromino) -> Tetromino:
    """Instantly drop the piece to the lowest valid position."""
    dropped = piece
    while True:
        candidate = dropped.moved(0, 1)
        if not is_valid_position(board, candidate):
            return dropped
        dropped = candidate


def draw_board(surface: pygame.Surface, board: Sequence[Sequence[Optional[str]]]) -> None:
    for y, row in enumerate(board):
        for x, cell in enumerate(row):
            draw_cell(surface, x, y, COLORS[cell] if cell else None)


def draw_piece(surface: pygame.Surface, piece: Tetromino) -> None:
    for x, y in piece.cells():
        if y >= 0:
            draw_cell(surface, x, y, COLORS[piece.name])


def draw_cell(surface: pygame.Surface, x: int, y: int, color: Optional[Tuple[int, int, int]]) -> None:
    rect = pygame.Rect(x * BLOCK_SIZE, y * BLOCK_SIZE, BLOCK_SIZE, BLOCK_SIZE)
    pygame.draw.rect(surface, GRID_COLOR, rect, width=1)
    if color:
        inner = rect.inflate(-2, -2)
        pygame.draw.rect(surface, color, inner)


def draw_text(
    surface: pygame.Surface,
    font: pygame.font.Font,
    text: str,
    top_left: Tuple[int, int],
    *,
    color: Tuple[int, int, int] = TEXT_COLOR,
) -> pygame.Rect:
    rendered = font.render(text, True, color)
    rect = rendered.get_rect(topleft=top_left)
    surface.blit(rendered, rect)
    return rect


def render(
    window: pygame.Surface,
    board: Sequence[Sequence[Optional[str]]],
    piece: Tetromino,
    next_piece: str,
    score: int,
    level: int,
    lines_cleared: int,
) -> None:
    window.fill(BACKGROUND_COLOR)
    play_surface = window.subsurface(pygame.Rect(0, 0, PLAY_WIDTH, PLAY_HEIGHT))
    play_surface.fill(BACKGROUND_COLOR)
    draw_board(play_surface, board)
    draw_piece(play_surface, piece)

    panel_rect = pygame.Rect(PLAY_WIDTH, 0, SIDE_PANEL_WIDTH, PLAY_HEIGHT)
    panel = window.subsurface(panel_rect)
    panel.fill((26, 26, 38))

    heading_font = pygame.font.SysFont("arial", 24, bold=True)
    small_font = pygame.font.SysFont("arial", 18)

    draw_text(panel, heading_font, "Next", (20, 20))
    preview_surface = panel.subsurface(pygame.Rect(20, 60, BLOCK_SIZE * 4, BLOCK_SIZE * 4))
    preview_surface.fill((26, 26, 38))
    for x, y in SHAPES[next_piece][0]:
        draw_cell(preview_surface, x, y, COLORS[next_piece])

    stats_y = 160
    draw_text(panel, heading_font, "Score", (20, stats_y))
    draw_text(panel, small_font, f"{score}", (20, stats_y + 30))

    draw_text(panel, heading_font, "Level", (20, stats_y + 70))
    draw_text(panel, small_font, f"{level}", (20, stats_y + 100))

    draw_text(panel, heading_font, "Lines", (20, stats_y + 140))
    draw_text(panel, small_font, f"{lines_cleared}", (20, stats_y + 170))

    instructions = [
        "Controls:",
        "←/→ Move",
        "↑ Rotate",
        "↓ Soft drop",
        "Space Hard drop",
        "Esc Quit",
    ]
    inst_top = stats_y + 220
    for idx, line in enumerate(instructions):
        draw_text(panel, small_font, line, (20, inst_top + idx * 24))

    pygame.display.flip()


def game_over_screen(window: pygame.Surface, score: int) -> None:
    window.fill(BACKGROUND_COLOR)
    heading_font = pygame.font.SysFont("arial", 32, bold=True)
    small_font = pygame.font.SysFont("arial", 20)

    center_x = WINDOW_SIZE[0] // 2
    center_y = WINDOW_SIZE[1] // 2

    draw_text(window, heading_font, "Game Over", (center_x - 100, center_y - 60))
    draw_text(window, small_font, f"Final Score: {score}", (center_x - 90, center_y - 20))
    draw_text(window, small_font, "Press any key to exit", (center_x - 130, center_y + 20))
    pygame.display.flip()

    waiting = True
    while waiting:
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                waiting = False
            if event.type == pygame.KEYDOWN:
                waiting = False


def calculate_drop_interval(level: int) -> int:
    """Return the drop interval in milliseconds for the given level."""
    return max(100, 700 - (level - 1) * 60)


def update_level_and_score(score: int, lines_cleared: int, cleared_now: int) -> Tuple[int, int, int]:
    """Update score and level based on lines cleared."""
    scoring_table = {0: 0, 1: 100, 2: 300, 3: 500, 4: 800}
    score += scoring_table.get(cleared_now, 0)
    lines_cleared += cleared_now
    level = max(1, lines_cleared // 10 + 1)
    return score, lines_cleared, level


def settle_piece(
    board: List[List[Optional[str]]],
    current_piece: Tetromino,
    next_piece_name: str,
    queue: List[str],
    rng: random.Random,
    score: int,
    lines_cleared: int,
    level: int,
) -> Tuple[Tetromino, str, int, int, int, int, bool]:
    """Lock the current piece and spawn the next one.

    Returns the updated current piece, next piece name, score, lines, level, drop interval,
    and a flag indicating whether the game is over.
    """

    lock_piece(board, current_piece)
    cleared = clear_lines(board)
    score, lines_cleared, level = update_level_and_score(score, lines_cleared, cleared)
    drop_interval = calculate_drop_interval(level)

    current_piece = Tetromino(next_piece_name)
    next_piece_name = spawn_piece(queue, rng)
    game_over = not is_valid_position(board, current_piece)
    return current_piece, next_piece_name, score, lines_cleared, level, drop_interval, game_over


def main(seed: Optional[int] = None) -> None:
    """Run the Tetris game loop."""
    pygame.init()
    window = pygame.display.set_mode(WINDOW_SIZE)
    pygame.display.set_caption("Tetris")
    clock = pygame.time.Clock()

    rng = random.Random(seed)

    board = create_board()
    queue: List[str] = []
    current_piece = Tetromino(spawn_piece(queue, rng))
    next_piece_name = spawn_piece(queue, rng)

    score = 0
    lines_cleared = 0
    level = 1
    drop_interval = calculate_drop_interval(level)
    pygame.time.set_timer(DROP_EVENT, drop_interval)

    running = True
    while running:
        clock.tick(60)
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
            elif event.type == DROP_EVENT:
                moved = current_piece.moved(0, 1)
                if is_valid_position(board, moved):
                    current_piece = moved
                else:
                    (
                        current_piece,
                        next_piece_name,
                        score,
                        lines_cleared,
                        level,
                        drop_interval,
                        game_over,
                    ) = settle_piece(
                        board,
                        current_piece,
                        next_piece_name,
                        queue,
                        rng,
                        score,
                        lines_cleared,
                        level,
                    )
                    pygame.time.set_timer(DROP_EVENT, drop_interval)
                    if game_over:
                        running = False
                        break
            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    running = False
                elif event.key == pygame.K_LEFT:
                    moved = current_piece.moved(-1, 0)
                    if is_valid_position(board, moved):
                        current_piece = moved
                elif event.key == pygame.K_RIGHT:
                    moved = current_piece.moved(1, 0)
                    if is_valid_position(board, moved):
                        current_piece = moved
                elif event.key == pygame.K_DOWN:
                    moved = current_piece.moved(0, 1)
                    if is_valid_position(board, moved):
                        current_piece = moved
                elif event.key == pygame.K_UP:
                    rotated = current_piece.rotated(1)
                    if is_valid_position(board, rotated):
                        current_piece = rotated
                    else:
                        # wall kicks: try simple offsets
                        for dx in (-1, 1, -2, 2):
                            kicked = rotated.moved(dx, 0)
                            if is_valid_position(board, kicked):
                                current_piece = kicked
                                break
                elif event.key == pygame.K_SPACE:
                    current_piece = hard_drop(board, current_piece)
                    (
                        current_piece,
                        next_piece_name,
                        score,
                        lines_cleared,
                        level,
                        drop_interval,
                        game_over,
                    ) = settle_piece(
                        board,
                        current_piece,
                        next_piece_name,
                        queue,
                        rng,
                        score,
                        lines_cleared,
                        level,
                    )
                    pygame.time.set_timer(DROP_EVENT, drop_interval)
                    if game_over:
                        running = False
                        break
        # redraw
        render(window, board, current_piece, next_piece_name, score, level, lines_cleared)

    game_over_screen(window, score)
    pygame.quit()


if __name__ == "__main__":
    main()
