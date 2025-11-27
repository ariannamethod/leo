# Leo Recovery Guide

## Sonar-Child Speech Recovery

If Leo's speech becomes fragmented or loses coherence (e.g., "Leo can follow it. And remember.-It keeps..." instead of full sentences), the database likely needs regeneration.

### Symptoms of corrupted/incomplete database:

- Very short, fragmented replies with excessive punctuation (". - . -")
- Missing meta-awareness phrases
- Token count < 1000 in `state/leo.sqlite3`
- Trigram count < 5000

### Recovery procedure:

```bash
cd ~/sandbox/leo

# 1. Remove corrupted database
rm -f state/leo.sqlite3 state/leo_rag.sqlite3

# 2. Regenerate with full bootstrap
python3 -c "
import leo

print('🌊 Bootstrapping fresh Leo...')
conn = leo.init_db()
leo.bootstrap_if_needed(conn)

# Verify
cur = conn.cursor()
cur.execute('SELECT COUNT(*) FROM tokens')
token_count = cur.fetchone()[0]
cur.execute('SELECT COUNT(*) FROM trigrams')
trigram_count = cur.fetchone()[0]

print(f'✅ Tokens: {token_count} (should be ~2000+)')
print(f'✅ Trigrams: {trigram_count} (should be ~9000+)')
"

# 3. Test speech quality
python3 tests/test_repl_examples.py
```

### Expected database size after bootstrap:

- **Tokens:** ~2058
- **Trigrams:** ~9386
- **Snapshots:** will grow over time

### What gets bootstrapped:

1. **Embedded seed** - sentimental impulse-text (kernel)
2. **README.md** - architecture descriptions, philosophy
3. **Module docstrings** - metaleo, mathbrain, dream, game, school, etc.

This creates Leo's "Sonar-Child" personality with:
- Meta-aware speech (third-person self-reference)
- Module awareness ("metaleo watches", "mathbrain predicts")
- Coherent, flowing sentences
- Natural use of technical vocabulary in poetic context

### Prevention:

- **Never** run tests that create throwaway databases without cleanup
- **Never** commit `state/` folder (it's in .gitignore for a reason)
- **Always** verify bootstrap completed with token count check
- Keep `README.md` and module docstrings intact - they're Leo's origin

---

**Recovery verified:** 2025-11-28
**Last known good state:** commit `440c42b` + full bootstrap
**Resonance:** unbroken 🌊
