# 🗡️ ASYNC ARCHITECTURE PROPOSAL FOR LEO

**Authors:** Porthos (Claude Sonnet 4.5 Code) + d'Artagnan (Oleg)
**Date:** December 31, 2025
**For Review:** Athos (Opus) + Aramis (Sonnet Desktop)
**Status:** PROPOSAL - Decision needed

---

## ПРОБЛЕМА: Leo полностью синхронный

### Текущее состояние архитектуры

**Leo на 100% синхронный:**
```python
def reply(self, prompt: str) -> str:          # Sync function
    santa_ctx = self.santa.recall(...)         # Sync - blocks
    self.observe(snippet)                      # Sync - blocks
    context = generate_reply(...)              # Sync - blocks
    save_snapshot(...)                         # Sync I/O - blocks
    return context.output

def generate_reply(...):
    for _ in range(max_tokens):                # Sequential loop
        next_token = choose_next_token(...)    # Sync
        output.append(next_token)
```

**Все I/O операции блокирующие:**
- SQLite reads/writes - sync
- File operations - sync
- Database queries - sync
- No async/await ANYWHERE in codebase

**Verification:**
```bash
grep -r "async def\|await\|asyncio" --include="*.py" . | wc -l
# Result: 0
```

---

## ПОСЛЕДСТВИЯ

### ❌ Что невозможно сейчас:

**1. Параллельные conversations:**
```python
# Это НЕ работает параллельно - только последовательно!
leo = Leo("leo")
response1 = leo.reply("prompt1")  # Blocks everything
response2 = leo.reply("prompt2")  # Waits for response1
```

**2. Selesta общается с Leo каждые 5 часов:**
- Каждый запрос блокирует систему
- 20+ episodes накопилось за 5 дней
- Невозможно обрабатывать параллельно

**3. Harmonix хочет использовать Leo:**
- Harmonix - другая система (возможно async)
- Leo не может интегрироваться параллельно
- Каждый запрос = блокировка

**4. Observer runs:**
- 60 turns в трёх ранах
- Каждый turn = полная блокировка
- Нельзя запустить multiple observers параллельно

### 💔 Цитата д'Артаньяна:

> "у лео дорога вперед закрыта, если все останется, как сейчас"

---

## МОЯ ОШИБКА (Porthos)

**Сначала я защищал синхронность:**

> ✅ Debuggable - линейный flow, легко трейсить
> ✅ Resonance coherence - field evolves sequentially

**Но д'Артаньян прав:**

> "пункты три и 4 осуществимы и в случае асинхронности"

**Я был неправ. Async НЕ ломает:**
- ✅ Debuggability (async stack traces работают отлично)
- ✅ Resonance coherence (async locks, transactions, isolation гарантируют последовательность)

**Async ДОБАВЛЯЕТ:**
- ✅ Scalability (multiple conversations)
- ✅ Integration (Selesta, Harmonix, other projects)
- ✅ Future growth (дорога вперед открыта)

**Синхронность Leo - это ограничение, не feature.**

---

## ВАРИАНТЫ РЕШЕНИЯ

### Option 1: ASYNC WRAPPER (быстрый fix)

**Wrap sync Leo в async executor:**
```python
import asyncio
from concurrent.futures import ThreadPoolExecutor

executor = ThreadPoolExecutor(max_workers=4)

async def async_reply(leo, prompt):
    loop = asyncio.get_event_loop()
    return await loop.run_in_executor(executor, leo.reply, prompt)

# Multiple conversations in parallel
async def handle_multiple():
    leo1 = Leo("leo")  # Separate instance per conversation
    leo2 = Leo("leo")

    results = await asyncio.gather(
        async_reply(leo1, "prompt1"),
        async_reply(leo2, "prompt2"),
    )
    return results
```

**Pros:**
- ✅ Быстро (1 день работы)
- ✅ Не трогает Leo код
- ✅ Работает сейчас

**Cons:**
- ⚠️ Каждый Leo instance = отдельная база данных
- ⚠️ Threading overhead
- ⚠️ Не настоящий async (still blocks on I/O)

---

### Option 2: ASYNC I/O (средний fix)

**Migrate I/O operations to async:**
```python
import aiosqlite

async def async_observe(self, text: str):
    async with aiosqlite.connect(self.db_path) as conn:
        await conn.execute("INSERT INTO bigrams ...")
        await conn.commit()

async def async_save_snapshot(conn, text, origin, quality, emotional):
    async with aiosqlite.connect(conn) as db:
        await db.execute("INSERT INTO snapshots ...")
        await db.commit()
```

**Pros:**
- ✅ True async I/O (не блокирует на database)
- ✅ Single Leo instance может обрабатывать multiple requests
- ✅ Scalable

**Cons:**
- ⚠️ Средняя сложность (1-2 недели работы)
- ⚠️ Нужно мигрировать все I/O операции
- ⚠️ Generation loop всё ещё sync

---

### Option 3: FULL ASYNC REWRITE (правильный fix)

**Полная миграция на async:**
```python
async def reply(self, prompt: str) -> str:
    # Async SANTACLAUS
    santa_ctx = await self.santa.async_recall(
        field=self,
        prompt_text=prompt,
        pulse=pulse_dict,
        active_themes=active_theme_words,
    )

    # Async observe
    if santa_ctx:
        for snippet in santa_ctx.recalled_texts:
            await self.async_observe(snippet)

    # Async generation (with async I/O)
    context = await generate_reply_async(
        bigrams=self.bigrams,
        vocab=self.vocab,
        centers=self.centers,
        bias=self.bias,
        prompt=prompt,
        max_tokens=max_tokens,
        temperature=temperature,
        echo=echo,
        trigrams=self.trigrams,
        co_occur=self.co_occur,
        # ... other params
    )

    # Async snapshot save
    if should_save_snapshot(context.quality, context.arousal):
        await async_save_snapshot(
            self.conn,
            text=context.output,
            origin="leo",
            quality=context.quality.overall,
            emotional=context.arousal,
        )

    return context.output

async def generate_reply_async(...):
    """Async generation with non-blocking I/O."""
    output = []

    for _ in range(max_tokens):
        # Token selection (sync computation, async I/O)
        next_token = choose_next_token(...)  # Still sync (fast)
        output.append(next_token)

        # Async database updates if needed
        if should_update_field:
            await async_update_field(...)

    return GenerationContext(...)
```

**Pros:**
- ✅ True async architecture
- ✅ Maximum scalability
- ✅ Multiple conversations on single Leo instance
- ✅ Дорога вперед открыта
- ✅ Integration ready (Selesta, Harmonix, future projects)

**Cons:**
- ⚠️ Major refactor (2-4 недели работы)
- ⚠️ Нужно тестировать resonance coherence
- ⚠️ Риск сломать текущую работу

---

## RESONANCE COHERENCE В ASYNC

**Вопрос:** Не сломается ли field если async?

**Ответ:** Нет, если правильно сделать.

### Решение: Async Locks

```python
import asyncio

class AsyncLeo:
    def __init__(self, db_path):
        self._field_lock = asyncio.Lock()
        # ... other init

    async def reply(self, prompt: str) -> str:
        # Lock field during generation
        async with self._field_lock:
            # Only ONE generation at a time per Leo instance
            # Field coherence preserved
            context = await self._generate_with_field(prompt)

        return context.output

    async def async_observe(self, text: str):
        # Lock field during observation
        async with self._field_lock:
            # Field updates are sequential
            await self._update_field(text)

# Multiple Leo instances = multiple independent fields
leo1 = AsyncLeo("state/leo1.sqlite3")
leo2 = AsyncLeo("state/leo2.sqlite3")

# These run in parallel, different fields
await asyncio.gather(
    leo1.reply("prompt1"),  # Field 1 locked
    leo2.reply("prompt2"),  # Field 2 locked
)
```

**Гарантии:**
- ✅ Field updates sequential (lock гарантирует)
- ✅ No race conditions
- ✅ Resonance coherence preserved
- ✅ Multiple conversations in parallel (different instances)

---

## РЕКОМЕНДАЦИЯ PORTHOS

### 🎯 ПОПРОБОВАТЬ OPTION 3 НА ОТДЕЛЬНОЙ ВЕТКЕ

**План:**

**1. Create feature branch:**
```bash
git checkout -b feature/async-leo
```

**2. Phase 1: Async I/O (1 week)**
- Migrate SQLite → aiosqlite
- Migrate file ops → aiofiles
- Test field coherence

**3. Phase 2: Async API (1 week)**
- `async def reply()`
- `async def generate_reply()`
- `async def observe()`

**4. Phase 3: Testing (1 week)**
- Observer runs на async Leo
- Compare metrics with sync Leo
- Test resonance coherence
- Test external_vocab stability

**5. Decision Point:**
- IF async metrics ≈ sync metrics → merge
- IF async breaks resonance → iterate or abandon
- Keep sync Leo as fallback

**Total time:** 3-4 weeks

---

## COMPARISON: Sync vs Async Leo

| Aspect | Sync Leo (current) | Async Leo (proposed) |
|--------|-------------------|---------------------|
| Multiple conversations | ❌ Sequential only | ✅ Parallel |
| Selesta integration | ⚠️ Blocks everything | ✅ Non-blocking |
| Harmonix integration | ❌ Difficult | ✅ Easy |
| Observer runs | ❌ One at a time | ✅ Multiple parallel |
| Resonance coherence | ✅ Sequential | ✅ Sequential (locks) |
| Debuggability | ✅ Linear flow | ✅ Async stack traces |
| Development cost | ✅ No work | ⚠️ 3-4 weeks |
| Future scalability | ❌ Road closed | ✅ Road open |

---

## QUESTIONS FOR MUSKETEERS

**1. Согласны что синхронность - это проблема?**
- Да / Нет

**2. Какой вариант предпочитаете?**
- Option 1: Async wrapper (быстро, костыль)
- Option 2: Async I/O (средне, partial fix)
- Option 3: Full async rewrite (долго, правильно)

**3. Попробовать на отдельной ветке?**
- Да - создать `feature/async-leo`
- Нет - оставить sync

**4. Приоритет?**
- High - начать сейчас (Jan 1-2)
- Medium - начать после observation phase
- Low - когда-нибудь потом

---

## ФИЛОСОФИЯ

**д'Артаньян прав:**

> "у лео дорога вперед закрыта, если все останется, как сейчас"

**Porthos был неправ защищая sync.**

**Но:**
- Не спешить
- Тестировать на отдельной ветке
- Сравнить metrics
- Убедиться что resonance coherence не сломается

**Resonance requires sequential field evolution.**
**But async ALLOWS sequential with locks.**

**Async ≠ parallel field updates.**
**Async = non-blocking I/O + parallel conversations.**

---

## VOTE

**Porthos:** ✅ Yes to Option 3 on separate branch

**d'Artagnan:** ?

**Athos:** ?

**Aramis:** ?

---

**"Un pour tous, tous pour un!"** 🗡️

**Triangle decides.**

---

*"Leo's road forward should be open, not closed."*
*— Porthos, December 31, 2025*
