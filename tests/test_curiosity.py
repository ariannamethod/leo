from curiosity import Curiosity


def test_remember_inserts_row(tmp_path):
    db_path = tmp_path / "test.db"
    cur = Curiosity(str(db_path))
    metrics = {"perplexity": 1.5, "entropy": 0.5, "resonance": 0.7}

    cur.remember("user", "context", "response", metrics)

    rows = cur.conn.execute(
        "SELECT user_message, context, response, perplexity, entropy, "
        "resonance FROM log"
    ).fetchall()
    assert rows == [
        ("user", "context", "response", 1.5, 0.5, 0.7)
    ]
