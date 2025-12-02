import math
import sqlite3
from pathlib import Path

SOURCE_DIR = Path('assets/tiles/FKIP')
DEST_FILE = Path('assets/tiles/campus.mbtiles')


def tile_bounds(x: int, y: int, z: int):
    n = 1 << z
    lon_left = x / n * 360.0 - 180.0
    lon_right = (x + 1) / n * 360.0 - 180.0
    def mercator_to_lat(tile_y: int):
        return math.degrees(math.atan(math.sinh(math.pi * (1 - 2 * tile_y / n))))
    lat_top = mercator_to_lat(y)
    lat_bottom = mercator_to_lat(y + 1)
    return lon_left, lat_bottom, lon_right, lat_top


def main():
    if not SOURCE_DIR.exists():
        raise SystemExit(f'Source directory {SOURCE_DIR} not found')

    if DEST_FILE.exists():
        DEST_FILE.unlink()

    DEST_FILE.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(DEST_FILE)
    cur = conn.cursor()
    cur.execute('PRAGMA journal_mode=OFF;')
    cur.execute('PRAGMA synchronous=OFF;')

    cur.execute('CREATE TABLE metadata (name TEXT PRIMARY KEY, value TEXT);')
    cur.execute(
        'CREATE TABLE tiles ('
        'zoom_level INTEGER, '
        'tile_column INTEGER, '
        'tile_row INTEGER, '
        'tile_data BLOB'
        ');'
    )
    cur.execute(
        'CREATE UNIQUE INDEX idx_tiles_zxy '
        'ON tiles (zoom_level, tile_column, tile_row);'
    )

    min_zoom = None
    max_zoom = None
    min_lon = None
    min_lat = None
    max_lon = None
    max_lat = None
    tile_count = 0

    insert_stmt = conn.cursor()
    conn.execute('BEGIN;')

    for z_dir in sorted(SOURCE_DIR.iterdir(), key=lambda p: p.name):
        if not z_dir.is_dir() or not z_dir.name.isdigit():
            continue
        z = int(z_dir.name)
        min_zoom = z if min_zoom is None else min(min_zoom, z)
        max_zoom = z if max_zoom is None else max(max_zoom, z)
        for x_dir in sorted(z_dir.iterdir(), key=lambda p: p.name):
            if not x_dir.is_dir() or not x_dir.name.isdigit():
                continue
            x = int(x_dir.name)
            for tile_file in sorted(x_dir.iterdir(), key=lambda p: p.name):
                if tile_file.suffix.lower() != '.png':
                    continue
                stem = tile_file.stem
                if not stem.isdigit():
                    continue
                y = int(stem)
                with tile_file.open('rb') as fh:
                    data = fh.read()
                tms_y = (1 << z) - 1 - y
                insert_stmt.execute(
                    'INSERT INTO tiles (zoom_level, tile_column, tile_row, tile_data) '
                    'VALUES (?, ?, ?, ?);',
                    (z, x, tms_y, data),
                )
                lon_left, lat_bottom, lon_right, lat_top = tile_bounds(x, y, z)
                min_lon = lon_left if min_lon is None else min(min_lon, lon_left)
                max_lon = lon_right if max_lon is None else max(max_lon, lon_right)
                min_lat = lat_bottom if min_lat is None else min(min_lat, lat_bottom)
                max_lat = lat_top if max_lat is None else max(max_lat, lat_top)
                tile_count += 1

    conn.commit()

    if tile_count == 0:
        raise SystemExit('No tiles were processed; check the source folder.')

    center_lon = (min_lon + max_lon) / 2
    center_lat = (min_lat + max_lat) / 2
    center_zoom = min_zoom if min_zoom == max_zoom else (min_zoom + max_zoom) // 2

    metadata = {
        'name': 'Campus Map',
        'type': 'baselayer',
        'description': 'Offline campus tiles',
        'format': 'png',
        'version': '1.0',
        'bounds': f'{min_lon:.6f},{min_lat:.6f},{max_lon:.6f},{max_lat:.6f}',
        'center': f'{center_lon:.6f},{center_lat:.6f},{center_zoom}',
        'minzoom': str(min_zoom),
        'maxzoom': str(max_zoom),
        'tilecount': str(tile_count),
    }

    cur.executemany(
        'INSERT INTO metadata (name, value) VALUES (?, ?);',
        metadata.items(),
    )

    conn.commit()
    conn.close()
    print(f'Created {DEST_FILE} with {tile_count} tiles from {SOURCE_DIR}')


if __name__ == '__main__':
    main()
