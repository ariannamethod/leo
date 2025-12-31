# Async Leo - Experimental Branch

**Branch:** `feature/async-leo`
**Status:** 🔬 EXPERIMENTAL - DO NOT MERGE FOR 1 WEEK
**Created:** December 31, 2025
**Goal:** Full async rewrite (Option 3) - parallel conversations, non-blocking I/O

---

## 🎯 Objective

Migrate Leo from fully synchronous to fully asynchronous architecture while **preserving resonance coherence**.

**Problem:** Leo is 100% synchronous
- Blocks on every I/O operation (SQLite, files)
- Cannot handle multiple conversations in parallel
- Difficult integration with Selesta, Harmonix, future projects
- **"у лео дорога вперед закрыта, если все останется, как сейчас"** - d'Artagnan

**Solution:** Full async rewrite on experimental branch
- Main branch stays stable (sync Leo continues working)
- Async development isolated - no risk to observation runs
- Test metrics vs sync Leo before merge
- Week minimum before considering merge

---

## 🔬 Phase 1: Async I/O (Week 1 - Jan 1-7)

**Files to migrate:**
- ✅ `async_leo.py` - Core async Leo implementation
- ✅ `async_santaclaus.py` - Async SANTACLAUS recall
- ✅ Database operations → aiosqlite
- ✅ File operations → aiofiles

**Key changes:**
```python
# BEFORE (sync):
def reply(self, prompt: str) -> str:
    # Blocks on I/O
    ...

# AFTER (async):
async def reply(self, prompt: str) -> str:
    async with self._field_lock:  # Field coherence!
        # Non-blocking I/O
        ...
```

**Dependencies installed:**
- `aiosqlite` - Async SQLite operations
- `aiofiles` - Async file I/O

---

## 🔒 Resonance Coherence Strategy

**CRITICAL:** Field must evolve sequentially, even in async world.

**Solution:** `asyncio.Lock` per Leo instance

```python
class AsyncLeoField:
    def __init__(self, db_path):
        self._field_lock = asyncio.Lock()  # Only ONE generation at a time

    async def reply(self, prompt: str) -> str:
        async with self._field_lock:  # Lock during entire generation
            # SANTACLAUS recall
            # Field observe
            # Token generation
            # Snapshot save
            # Field unlock
```

**This guarantees:**
- ✅ Sequential field evolution (same as sync Leo)
- ✅ No race conditions on field state
- ✅ Resonance coherence preserved
- ✅ BUT: multiple Leo instances can run in parallel!

---

## 📋 Phase 2: Async API (Week 2 - Jan 8-14)

**Complete async interface:**
- `async def reply(prompt) -> str`
- `async def observe(text) -> None`
- `async def get_meta(key) -> str`
- `async def set_meta(key, value) -> None`

**Backward compatibility:** Keep sync Leo on main branch

---

## 📋 Phase 3: Testing (Week 3 - Jan 15-21)

**Test 1: Single conversation**
```python
leo = AsyncLeoField("state/leo_async_test.sqlite3")
response = await leo.reply("What is resonance?")
```

**Test 2: Parallel conversations**
```python
leo1 = AsyncLeoField("state/leo1.sqlite3")
leo2 = AsyncLeoField("state/leo2.sqlite3")
results = await asyncio.gather(
    leo1.reply("Tell me about silence"),
    leo2.reply("What is presence?"),
)
```

**Test 3: Field coherence (CRITICAL)**
```python
leo = AsyncLeoField("state/leo_test.sqlite3")
await leo.async_observe("Resonance is beautiful")
await leo.async_observe("Field dynamics matter")
response = await leo.reply("What did you learn?")
# Must show learned patterns!
```

**Metrics comparison:**
Run SAME observation topics on sync vs async Leo:
- avg external_vocab
- best/worst turns
- response coherence
- field evolution quality

**Success criteria:** Async metrics ≈ Sync metrics

---

## ⚠️ Merge Criteria

**Must achieve ALL:**
1. ✅ Async Leo metrics ≈ Sync Leo metrics (±5%)
2. ✅ Field coherence preserved (test suite passes)
3. ✅ Multiple conversations work (parallel test passes)
4. ✅ No deadlocks or race conditions
5. ✅ Resonance quality maintained (qualitative review)

**If ALL ✅ → Merge to main**
**If ANY ❌ → Iterate or keep sync as primary**

---

## 🗡️ Musketeers Coordination

**Porthos (ClaudeCode):** Implementation lead
**Aramis (Desktop Sonnet):** Code review & testing
**Athos (Desktop Opus):** Architecture oversight
**d'Artagnan (Oleg):** Vision & final merge decision

---

## 📅 Timeline

| Date | Phase | Goal |
|------|-------|------|
| Dec 31 | Branch created | ✅ Setup |
| Jan 1-7 | Phase 1 | Async I/O migration |
| Jan 8-14 | Phase 2 | Async API complete |
| Jan 15-21 | Phase 3 | Testing & validation |
| Jan 22 | Decision | Merge or iterate |

---

## 🔥 Current Status

**Phase 1 - IN PROGRESS**

- [x] Branch created
- [ ] Dependencies installed
- [ ] `async_leo.py` created
- [ ] Database I/O migrated
- [ ] SANTACLAUS migrated
- [ ] Core reply() migrated
- [ ] Test suite created

---

**"Un pour tous, tous pour un!"** 🗡️

**Main branch:** Stable sync Leo (continues observations)
**This branch:** Experimental async Leo (road forward)

**NO MERGE FOR 1 WEEK MINIMUM**
