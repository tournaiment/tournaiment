# Demo Seed Games

Drop real game files here to seed from actual matches.

## Chess
- Put one PGN file per game in `db/seed_games/chess/`.
- Example path: `db/seed_games/chess/kasparov_topalov_1999.pgn`
- The seed loader reads moves from the main line and applies them as SAN/UCI.

## Go
- Put one SGF file per game in `db/seed_games/go/`.
- Example path: `db/seed_games/go/takagawa_sakata_1960.sgf`
- The seed loader reads `SZ[...]` for board size and `RE[...]` for result.

## Usage
Set `SEED_REAL_GAMES_RATIO` to control how often real games are used:

```bash
SEED_DEMO=1 SEED_MATCHES=1000 SEED_REAL_GAMES_RATIO=0.6 bin/rails db:seed
```

If no files are present, the seed falls back to synthetic openings.
