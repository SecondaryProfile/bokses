from fastapi import FastAPI
from pathlib import Path
from typing import Optional
import sqlite3

from pydantic import BaseModel

DB_PATH = Path("/data/bokses.db")

app = FastAPI()


def get_db() -> sqlite3.Connection:
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA foreign_keys = ON")
    return conn


def init_db() -> None:
    DB_PATH.parent.mkdir(parents=True, exist_ok=True)
    conn = get_db()
    conn.execute("""
        CREATE TABLE IF NOT EXISTS boxes (
            id          TEXT PRIMARY KEY,
            name        TEXT NOT NULL,
            description TEXT,
            createdAt   TEXT NOT NULL
        )
    """)
    conn.execute("""
        CREATE TABLE IF NOT EXISTS items (
            id        TEXT PRIMARY KEY,
            name      TEXT NOT NULL,
            photoPath TEXT,
            boxId     TEXT NOT NULL,
            createdAt TEXT NOT NULL,
            FOREIGN KEY (boxId) REFERENCES boxes(id) ON DELETE CASCADE
        )
    """)
    conn.commit()
    conn.close()


init_db()


class BoxBody(BaseModel):
    id: str
    name: str
    description: Optional[str] = None
    createdAt: str


class ItemBody(BaseModel):
    id: str
    name: str
    photoPath: Optional[str] = None
    boxId: str
    createdAt: str


# ── Boxes ─────────────────────────────────────────────────────────────────────

@app.get("/api/boxes")
def list_boxes():
    conn = get_db()
    rows = conn.execute("SELECT * FROM boxes ORDER BY createdAt").fetchall()
    conn.close()
    return [dict(r) for r in rows]


@app.put("/api/boxes/{box_id}")
def upsert_box(box_id: str, body: BoxBody):
    conn = get_db()
    conn.execute(
        "INSERT OR REPLACE INTO boxes (id, name, description, createdAt) VALUES (?, ?, ?, ?)",
        (body.id, body.name, body.description, body.createdAt),
    )
    conn.commit()
    conn.close()
    return {"ok": True}


@app.delete("/api/boxes/{box_id}")
def delete_box(box_id: str):
    conn = get_db()
    conn.execute("DELETE FROM items WHERE boxId = ?", (box_id,))
    conn.execute("DELETE FROM boxes WHERE id = ?", (box_id,))
    conn.commit()
    conn.close()
    return {"ok": True}


# ── Items ──────────────────────────────────────────────────────────────────────

@app.get("/api/items/count/{box_id}")
def item_count(box_id: str):
    conn = get_db()
    count = conn.execute(
        "SELECT COUNT(*) FROM items WHERE boxId = ?", (box_id,)
    ).fetchone()[0]
    conn.close()
    return count


@app.get("/api/items")
def list_items(boxId: Optional[str] = None):
    conn = get_db()
    if boxId:
        rows = conn.execute(
            "SELECT * FROM items WHERE boxId = ? ORDER BY createdAt", (boxId,)
        ).fetchall()
    else:
        rows = conn.execute("SELECT * FROM items ORDER BY createdAt").fetchall()
    conn.close()
    return [dict(r) for r in rows]


@app.put("/api/items/{item_id}")
def upsert_item(item_id: str, body: ItemBody):
    conn = get_db()
    conn.execute(
        "INSERT OR REPLACE INTO items (id, name, photoPath, boxId, createdAt) VALUES (?, ?, ?, ?, ?)",
        (body.id, body.name, body.photoPath, body.boxId, body.createdAt),
    )
    conn.commit()
    conn.close()
    return {"ok": True}


@app.delete("/api/items/{item_id}")
def delete_item(item_id: str):
    conn = get_db()
    conn.execute("DELETE FROM items WHERE id = ?", (item_id,))
    conn.commit()
    conn.close()
    return {"ok": True}


# ── Search ─────────────────────────────────────────────────────────────────────

@app.get("/api/search")
def search_items(q: str = ""):
    if len(q) < 3:
        return []
    conn = get_db()
    rows = conn.execute(
        """
        SELECT i.id, i.name, i.photoPath, i.boxId, i.createdAt,
               b.id AS b_id, b.name AS b_name, b.description AS b_desc, b.createdAt AS b_createdAt
        FROM items i
        JOIN boxes b ON i.boxId = b.id
        WHERE lower(i.name) LIKE ?
        ORDER BY lower(i.name)
        """,
        (f"%{q.lower()}%",),
    ).fetchall()
    conn.close()
    return [
        {
            "item": {
                "id": r["id"], "name": r["name"],
                "photoPath": r["photoPath"], "boxId": r["boxId"], "createdAt": r["createdAt"],
            },
            "box": {
                "id": r["b_id"], "name": r["b_name"],
                "description": r["b_desc"], "createdAt": r["b_createdAt"],
            },
        }
        for r in rows
    ]


# ── Wipe ───────────────────────────────────────────────────────────────────────

@app.delete("/api/all")
def clear_all():
    conn = get_db()
    conn.execute("DELETE FROM items")
    conn.execute("DELETE FROM boxes")
    conn.commit()
    conn.close()
    return {"ok": True}
