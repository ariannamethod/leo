#!/usr/bin/env python3
"""
Nicole Objectivity - Dynamic Context Window Generator
Флюидная система создания контекстных окон через H2O скрипты.
Каждый поиск = уникальный скрипт, логируемый и адаптивный.

Обновления:
- Шаблоны используются только для первых сообщений (metrics['first_message'] == True)
- Wikipedia: язык ru/en, добавлены title и extract без ссылок (никаких URL). Wikipedia используется как знание для генерации/обучения, не как справочный бот.
- Reddit: реальный поиск по публичному JSON API (без ключей)
- Memory: FTS5-поиск (если доступно), fallback на LIKE; реальные выдержки вместо заглушек
- Seeds: частотный отбор без стоп-слов вместо random sample
- Контекст-окна включают title, флаг template_used; форматтер никогда не выводит URL для wikipedia
"""

import re
import asyncio
import requests
import json
import time
import random
import sys
import os
import sqlite3
from typing import Dict, List, Tuple, Optional
from dataclasses import dataclass
from urllib.parse import quote
from collections import defaultdict

# Добавляем путь для импорта наших модулей
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import h2o

USER_AGENT = "nicole-objectivity/1.0 (+github.com/ariannamethod/nicole)"

EN_STOPWORDS = {
    "the","a","an","and","or","but","if","then","else","when","while","for","to","of","in","on","at",
    "is","are","was","were","be","been","being","it","this","that","these","those","with","as","by",
    "from","about","into","over","after","before","between","through","during","without","within",
    "do","does","did","done","can","could","should","would","may","might","must","will","just","not"
}

RU_STOPWORDS = {
    "и","а","но","или","если","то","иначе","когда","пока","для","в","на","по","из","от","о","об","над","под",
    "после","до","между","через","во","при","без","со","это","тот","эта","те","эти","что","как","так","же",
    "бы","быть","есть","был","были","будет","мог","могут","должен","должны","может","можно","нельзя","просто","не"
}

def _now_ms() -> int:
    return int(time.time() * 1000)

@dataclass
class FluidContextWindow:
    """Флюидное контекстное окно"""
    content: str
    source_type: str  # 'wikipedia', 'web', 'reddit', 'memory'
    resonance_score: float
    entropy_boost: float
    tokens_count: int
    creation_time: float
    script_id: str  # ID скрипта который создал это окно
    title: Optional[str] = None
    url: Optional[str] = None
    template_used: bool = False
    meta: Optional[Dict[str, str]] = None

class NicoleObjectivity:
    """Система объективности Nicole - создает контекстные окна через флюидные скрипты"""
    
    def __init__(self, max_context_kb: int = 2):
        self.max_context_kb = max_context_kb * 1024
        self.h2o_engine = h2o.h2o_engine
        self.script_counter = 0
        
        # Паттерны для анализа (как у Клода, но расширенные)
        self.proper_noun_patterns = [
            r'\b[A-ZА-Я][a-zа-я]+\b',  # Имена собственные
            r'\b[A-ZА-Я]{2,}\b',        # Аббревиатуры
        ]
        
        self.technical_patterns = [
            r'\b(python|javascript|neural|AI|quantum|blockchain)\b',
            r'\b(programming|coding|algorithm|database)\b',
        ]
        
        self.location_patterns = [
            r'\b(Berlin|London|Moscow|Paris|Tokyo|New York)\b',
            r'\b(Берлин|Лондон|Москва|Париж|город|страна)\b',
        ]

        # Простой кеш результатов по нормализованному запросу (TTL 2 мин)
        self._cache: Dict[str, Tuple[float, List[FluidContextWindow]]] = {}
        self._cache_ttl = 120.0

    def _lang_heuristic(self, text: str) -> str:
        # Простая эвристика: преобладающий алфавит
        latin = len(re.findall(r'[A-Za-z]', text))
        cyr = len(re.findall(r'[А-Яа-я]', text))
        if cyr > latin:
            return 'ru'
        return 'en'

    def _ensure_memory_schema(self):
        try:
            conn = sqlite3.connect('nicole_memory.db')
            cur = conn.cursor()
            # Основная таблица (если отсутствует)
            cur.execute("""
            CREATE TABLE IF NOT EXISTS conversations (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              timestamp REAL DEFAULT (strftime('%s','now')),
              user_input TEXT,
              nicole_output TEXT
            )
            """)
            # FTS5 (если доступно)
            try:
                cur.execute("""
                CREATE VIRTUAL TABLE IF NOT EXISTS conversations_fts
                USING fts5(user_input, nicole_output, tokenize = 'porter');
                """)
                # первичное заполнение если пусто
                cur.execute("SELECT count(*) FROM conversations_fts")
                count = cur.fetchone()[0]
                if count == 0:
                    cur.execute("INSERT INTO conversations_fts(rowid, user_input, nicole_output) SELECT id, user_input, nicole_output FROM conversations WHERE user_input IS NOT NULL OR nicole_output IS NOT NULL")
            except sqlite3.Error:
                # FTS5 может быть не собран — ок
                pass

            conn.commit()
            conn.close()
        except Exception:
            pass

    def _cache_get(self, key: str) -> Optional[List[FluidContextWindow]]:
        item = self._cache.get(key)
        if not item:
            return None
        ts, value = item
        if (time.time() - ts) > self._cache_ttl:
            self._cache.pop(key, None)
            return None
        return value

    def _cache_set(self, key: str, value: List[FluidContextWindow]):
        self._cache[key] = (time.time(), value)

    async def create_dynamic_context(self, user_message: str, metrics: Dict) -> List[FluidContextWindow]:
        """Создает динамические контекстные окна через флюидные скрипты"""
        print(f"[Objectivity] Анализируем: '{user_message}'")
        
        # Лингвистический анализ
        analysis = self._analyze_message(user_message)
        print(f"[Objectivity] Анализ: {analysis}")
        
        # Строго ограничиваем шаблоны первыми сообщениями
        first_message = bool(metrics.get('first_message', False))
        print(f"[Objectivity] first_message={first_message}")

        # Проверка кеша (не кешируем, если first_message — нужно прогреть контекст)
        cache_key = None if first_message else f"{analysis['language']}::{user_message.strip().lower()}"
        if cache_key:
            cached = self._cache_get(cache_key)
            if cached is not None:
                print("[Objectivity] Отдаем из кеша")
                return self._trim_to_limit(cached)

        # Решаем стратегию поиска
        search_strategies = self._decide_search_strategy(analysis, metrics)
        print(f"[Objectivity] Стратегии: {search_strategies}")
        
        # Создаем флюидные скрипты для каждой стратегии
        context_windows: List[FluidContextWindow] = []
        for strategy in search_strategies:
            script_id = f"objectivity_{strategy}_{_now_ms()}_{self.script_counter}"
            self.script_counter += 1
            
            try:
                script_result = await self._generate_and_run_script(
                    strategy, user_message, analysis, script_id, first_message
                )
                if script_result:
                    context_windows.extend(script_result)
            except Exception as e:
                print(f"[Objectivity:ERROR] Ошибка скрипта {script_id}: {e}")
        
        # Трим и кеш
        trimmed = self._trim_to_limit(context_windows)
        if cache_key:
            self._cache_set(cache_key, trimmed)
        return trimmed
    
    def _analyze_message(self, text: str) -> Dict:
        """Анализирует сообщение пользователя"""
        analysis = {
            'proper_nouns': [],
            'technical_terms': [],
            'locations': [],
            'is_smalltalk': False,
            'language': 'en' if re.search(r'[a-zA-Z]', text) else 'ru',
            'has_questions': '?' in text,
            'word_count': len(text.split())
        }
        
        # Более стабильный детект языка
        analysis['language'] = self._lang_heuristic(text)

        # Ищем имена собственные
        for pattern in self.proper_noun_patterns:
            matches = re.findall(pattern, text)
            analysis['proper_nouns'].extend(matches)
        
        # Ищем технические термины
        for pattern in self.technical_patterns:
            matches = re.findall(pattern, text, re.IGNORECASE)
            analysis['technical_terms'].extend(matches)
            
        # Ищем локации
        for pattern in self.location_patterns:
            matches = re.findall(pattern, text, re.IGNORECASE)
            analysis['locations'].extend(matches)
        
        # Определяем smalltalk
        smalltalk_words = ['hello', 'hi', 'how', 'what', 'привет', 'как', 'что']
        if any(word in text.lower() for word in smalltalk_words) and len(text.split()) < 10:
            analysis['is_smalltalk'] = True
            
        return analysis
    
    def _decide_search_strategy(self, analysis: Dict, metrics: Dict) -> List[str]:
        """Решает какие стратегии поиска использовать"""
        strategies = []
        
        # Имена собственные и локации → Wikipedia
        if analysis['proper_nouns'] or analysis['locations']:
            strategies.append('wikipedia')
            
        # Технические термины → веб/реддит
        if analysis['technical_terms']:
            strategies.append('reddit')
            strategies.append('wikipedia')
            
        # Smalltalk → память системы
        if analysis['is_smalltalk']:
            strategies.append('memory')
        
        # На основе метрик Nicole
        perplexity = metrics.get('perplexity', 0)
        entropy = metrics.get('entropy', 0)
        resonance = metrics.get('resonance', 0)
        
        # Высокая перплексия → внешний контекст
        if perplexity > 3.0:
            strategies.append('reddit')
            
        # Низкая энтропия → нужно разнообразие
        if entropy < 2.0:
            strategies.append('wikipedia')
            
        # Низкий резонанс → память
        if resonance < 0.4:
            strategies.append('memory')
        
        # Приоритизируем: wikipedia > reddit > memory
        order = {'wikipedia': 0, 'reddit': 1, 'memory': 2}
        strategies = sorted(list(set(strategies)), key=lambda s: order.get(s, 99))
        strategies = strategies[:2]  # максимум 2 стратегии
        return strategies if strategies else ['memory']
    
    async def _generate_and_run_script(self, strategy: str, user_message: str, 
                                       analysis: Dict, script_id: str,
                                       first_message: bool) -> List[FluidContextWindow]:
        """Генерирует и запускает флюидный скрипт для поиска"""
        if strategy == 'wikipedia':
            return await self._wikipedia_script(user_message, analysis, script_id, first_message)
        elif strategy == 'web':
            return await self._web_search_script(user_message, analysis, script_id, first_message)
        elif strategy == 'reddit':
            return await self._reddit_script(user_message, analysis, script_id, first_message)
        elif strategy == 'memory':
            return await self._memory_script(user_message, analysis, script_id, first_message)
        else:
            return []
    
    def _wiki_endpoint_for_lang(self, lang: str) -> str:
        lang = 'ru' if lang == 'ru' else 'en'
        return f"https://{lang}.wikipedia.org/api/rest_v1/page/summary"

    async def _wikipedia_script(self, message: str, analysis: Dict, script_id: str, first_message: bool) -> List[FluidContextWindow]:
        """Флюидный скрипт для Wikipedia поиска (без ссылок)"""
        try:
            # Генерируем и запускаем флюидный скрипт (для логов/метрик)
            script = f"""
# Флюидный Wikipedia скрипт {script_id} (no URLs)
import requests
import json
import re

def search_wikipedia_fluid():
    search_terms = {analysis['proper_nouns'] + analysis['locations']}
    results = []
    for term in search_terms[:3]:
        try:
            url = "{self._wiki_endpoint_for_lang(analysis['language'])}/" + term.replace(" ", "_")
            response = requests.get(url, timeout=4, headers={{"User-Agent": "{USER_AGENT}"}})
            if response.status_code == 200:
                data = response.json()
                extract = (data.get('extract') or '')[:600]
                title = data.get('title') or term
                if extract:
                    results.append({{
                        'term': term,
                        'title': title,
                        'content': extract,
                        'source': 'wikipedia'
                    }})
        except Exception as e:
            h2o_log(f"Wikipedia ошибка для {{term}}: {{e}}")
            continue
    h2o_log(f"Wikipedia результаты: {{len(results)}} найдено")
    h2o_metric('wikipedia_results_count', len(results))
    return results

_ = search_wikipedia_fluid()
"""
            self.h2o_engine.run_transformer_script(script, script_id)

            # Реальные результаты (вне H2O, чтобы вернуть окна)
            windows: List[FluidContextWindow] = []
            terms = (analysis['proper_nouns'] + analysis['locations']) or [message.strip()]
            terms = list(dict.fromkeys(terms))[:3]
            base = self._wiki_endpoint_for_lang(analysis['language'])

            for term in terms:
                try:
                    url = f"{base}/{quote(term.replace(' ', '_'))}"
                    resp = requests.get(url, timeout=4, headers={"User-Agent": USER_AGENT})
                    if resp.status_code != 200:
                        continue
                    data = resp.json()
                    extract = (data.get('extract') or '')[:800]
                    if not extract and not first_message:
                        # Никаких шаблонов после первых сообщений
                        continue

                    title = data.get('title') or term
                    content = extract if extract else f"[no extract available]"
                    template_used = not bool(extract)

                    window = FluidContextWindow(
                        content=f"Wikipedia: {title}\n{content}",
                        source_type='wikipedia',
                        resonance_score=0.9 if extract else 0.6,
                        entropy_boost=0.3,
                        tokens_count=len(content.split()),
                        creation_time=time.time(),
                        script_id=script_id,
                        title=title,
                        url=None,              # никаких ссылок
                        template_used=template_used
                    )
                    windows.append(window)
                except Exception as e:
                    print(f"[Objectivity] Wikipedia ошибка: {e}")

            return windows

        except Exception as e:
            print(f"[Objectivity] Ошибка Wikipedia скрипта: {e}")
            return []
    
    async def _web_search_script(self, message: str, analysis: Dict, script_id: str, first_message: bool) -> List[FluidContextWindow]:
        """Флюидный скрипт для веб-поиска (по умолчанию выключено)"""
        if first_message:
            window = FluidContextWindow(
                content=f"Web search context for: {message}\n[web provider disabled by default]",
                source_type='web',
                resonance_score=0.55,
                entropy_boost=0.35,
                tokens_count=20,
                creation_time=time.time(),
                script_id=script_id,
                title="Web Search (disabled)",
                url=None,
                template_used=True
            )
            return [window]
        return []
    
    async def _reddit_script(self, message: str, analysis: Dict, script_id: str, first_message: bool) -> List[FluidContextWindow]:
        """Флюидный скрипт для Reddit поиска (публичный JSON, без ключей)"""
        query = message.strip()
        try:
            # Логи/метрики в H2O
            script = f"""
# Флюидный Reddit скрипт {script_id}
import requests, json
def reddit_search_fluid():
    url = "https://www.reddit.com/search.json"
    params = {{"q": {json.dumps(query)}, "limit": 3, "sort": "relevance", "t": "year"}}
    headers = {{"User-Agent": "{USER_AGENT}"}}
    try:
        r = requests.get(url, params=params, headers=headers, timeout=5)
        h2o_metric("reddit_status", r.status_code)
    except Exception as e:
        h2o_log(f"Reddit ошибка: {{e}}")
reddit_search_fluid()
"""
            self.h2o_engine.run_transformer_script(script, script_id)

            # Реальный вызов
            r = requests.get(
                "https://www.reddit.com/search.json",
                params={"q": query, "limit": 3, "sort": "relevance", "t": "year"},
                headers={"User-Agent": USER_AGENT},
                timeout=6,
            )
            windows: List[FluidContextWindow] = []
            if r.status_code == 200:
                data = r.json()
                posts = (data.get("data") or {}).get("children") or []
                for p in posts[:3]:
                    d = p.get("data") or {}
                    title = d.get("title") or "Reddit"
                    url = f"https://www.reddit.com{d.get('permalink', '')}" if d.get("permalink") else d.get("url_overridden_by_dest") or None
                    text = (d.get("selftext") or "")[:600]
                    if not text:
                        text = (d.get("title") or "")[:600]
                    if not text and not first_message:
                        continue
                    content = text if text else "[no text available]"
                    window = FluidContextWindow(
                        content=f"Reddit: {title}\n{content}",
                        source_type='reddit',
                        resonance_score=0.7 if content else 0.55,
                        entropy_boost=0.5,
                        tokens_count=len(content.split()),
                        creation_time=time.time(),
                        script_id=script_id,
                        title=title,
                        url=url,              # для Reddit URL допустим
                        template_used=not bool(text)
                    )
                    windows.append(window)
            else:
                if first_message:
                    windows.append(
                        FluidContextWindow(
                            content=f"Reddit trends for: {message}\n[unavailable]",
                            source_type='reddit',
                            resonance_score=0.55,
                            entropy_boost=0.45,
                            tokens_count=10,
                            creation_time=time.time(),
                            script_id=script_id,
                            title="Reddit",
                            url=None,
                            template_used=True
                        )
                    )
            return windows
        except Exception as e:
            print(f"[Objectivity] Reddit ошибка: {e}")
            if first_message:
                return [FluidContextWindow(
                    content=f"Reddit trends for: {message}\n[error]",
                    source_type='reddit',
                    resonance_score=0.5,
                    entropy_boost=0.45,
                    tokens_count=8,
                    creation_time=time.time(),
                    script_id=script_id,
                    title="Reddit",
                    url=None,
                    template_used=True
                )]
            return []
    
    async def _memory_script(self, message: str, analysis: Dict, script_id: str, first_message: bool) -> List[FluidContextWindow]:
        """Флюидный скрипт для поиска в памяти Nicole"""
        try:
            # Создаем схему (если нужно)
            self._ensure_memory_schema()

            # Логи/метрики через H2O
            script = f"""
# Флюидный Memory скрипт {script_id}
import sqlite3
def search_memory_fluid():
    try:
        conn = sqlite3.connect('nicole_memory.db')
        cursor = conn.cursor()
        cursor.execute("SELECT count(*) FROM conversations")
        total = cursor.fetchone()[0]
        h2o_metric('memory_total', total)
        conn.close()
    except Exception as e:
        h2o_log(f"Memory ошибка: {{e}}")
search_memory_fluid()
"""
            self.h2o_engine.run_transformer_script(script, script_id)
            
            # Реальный поиск
            conn = sqlite3.connect('nicole_memory.db')
            conn.row_factory = sqlite3.Row
            cur = conn.cursor()

            query_words = [w for w in re.findall(r'\w{3,}', message.lower())][:4]
            query = " ".join(query_words) if query_words else message

            windows: List[FluidContextWindow] = []
            used_fts = False
            try:
                # Пробуем FTS5
                cur.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='conversations_fts'")
                if cur.fetchone():
                    used_fts = True
                    cur.execute("""
                        SELECT highlight(conversations_fts, 0, '[', ']') AS u_h,
                               highlight(conversations_fts, 1, '[', ']') AS n_h
                        FROM conversations_fts
                        WHERE conversations_fts MATCH ?
                        LIMIT 3
                    """, (query,))
                    rows = cur.fetchall()
                    for r in rows:
                        user_h = r['u_h'] or ''
                        nicole_h = r['n_h'] or ''
                        snippet = (nicole_h or user_h)
                        snippet = re.sub(r'\s+', ' ', snippet)[:600]
                        if not snippet and not first_message:
                            continue
                        content = snippet if snippet else "[no memory snippet]"
                        windows.append(
                            FluidContextWindow(
                                content=f"Memory: {content}",
                                source_type='memory',
                                resonance_score=0.8 if snippet else 0.6,
                                entropy_boost=0.2,
                                tokens_count=len(content.split()),
                                creation_time=time.time(),
                                script_id=script_id,
                                title="Nicole Memory",
                                url=None,
                                template_used=not bool(snippet)
                            )
                        )
            except Exception:
                used_fts = False

            if not used_fts:
                # Fallback LIKE
                for w in query_words[:3] or [message]:
                    cur.execute("""
                    SELECT user_input, nicole_output FROM conversations
                    WHERE LOWER(user_input) LIKE ? OR LOWER(nicole_output) LIKE ?
                    ORDER BY timestamp DESC LIMIT 2
                    """, (f'%{w}%', f'%{w}%'))
                    rows = cur.fetchall()
                    for r in rows:
                        snippet = (r['nicole_output'] or r['user_input'] or '')[:600]
                        if not snippet and not first_message:
                            continue
                        content = snippet if snippet else "[no memory snippet]"
                        windows.append(
                            FluidContextWindow(
                                content=f"Memory: {content}",
                                source_type='memory',
                                resonance_score=0.7 if snippet else 0.55,
                                entropy_boost=0.2,
                                tokens_count=len(content.split()),
                                creation_time=time.time(),
                                script_id=script_id,
                                title="Nicole Memory",
                                url=None,
                                template_used=not bool(snippet)
                            )
                        )

            conn.close()
            return windows
            
        except Exception as e:
            print(f"[Objectivity] Ошибка Memory скрипта: {e}")
            if first_message:
                return [FluidContextWindow(
                    content=f"Memory context for: {message}\n[error]",
                    source_type='memory',
                    resonance_score=0.5,
                    entropy_boost=0.2,
                    tokens_count=10,
                    creation_time=time.time(),
                    script_id=script_id,
                    title="Nicole Memory",
                    url=None,
                    template_used=True
                )]
            return []
    
    def _trim_to_limit(self, windows: List[FluidContextWindow]) -> List[FluidContextWindow]:
        """Обрезает до лимита размера"""
        # Сортируем по резонансу, затем по отсутствию шаблона
        windows.sort(key=lambda x: (x.resonance_score, not x.template_used), reverse=True)
        
        total_size = 0
        result = []
        
        for window in windows:
            window_size = len(window.content.encode('utf-8'))
            if total_size + window_size <= self.max_context_kb:
                result.append(window)
                total_size += window_size
            else:
                break
                
        return result
    
    def format_context_for_nicole(self, windows: List[FluidContextWindow]) -> str:
        """Форматирует контекст для Nicole"""
        if not windows:
            return ""
            
        formatted = "=== OBJECTIVITY CONTEXT ===\n"
        for window in windows:
            header = f"[{window.source_type.upper()}:{window.script_id}]"
            if window.title:
                header += f" {window.title}"
            # Никогда не выводим URL для wikipedia
            if window.source_type != 'wikipedia' and window.url:
                header += f" ({window.url})"
            if window.template_used:
                header += " [template]"
            formatted += f"{header}\n{window.content}\n\n"
        formatted += "=== END OBJECTIVITY ===\n"
        return formatted
    
    def extract_response_seeds(self, context: str, target_percent: float = 0.15) -> List[str]:
        """Извлекает семена для ответа: частотные ключевые токены без стоп-слов"""
        if not context:
            return []
        lang = self._lang_heuristic(context)
        stopwords = RU_STOPWORDS if lang == 'ru' else EN_STOPWORDS

        words = re.findall(r'\b[\w-]{3,}\b', context.lower())
        counts = defaultdict(int)
        for w in words:
            if w in stopwords:
                continue
            counts[w] += 1
        if not counts:
            return []

        # Сортируем по частоте и длине (как proxy «важности»)
        ranked = sorted(counts.items(), key=lambda kv: (kv[1], len(kv[0])), reverse=True)
        max_count = max(counts.values())
        top_n = max(3, min(20, int(len(words) * target_percent)))
        seeds = [w for (w, c) in ranked[:top_n] if c >= 1 and c >= max(1, max_count // 4)]
        return seeds or [w for (w, _) in ranked[:top_n]]

# Глобальный экземпляр
nicole_objectivity = NicoleObjectivity()

async def test_objectivity():
    """Тест системы объективности"""
    print("=== NICOLE OBJECTIVITY TEST ===")
    
    test_cases = [
        ("Tell me about Berlin", {'perplexity': 2.0, 'entropy': 3.0, 'resonance': 0.5, 'first_message': True}),
        ("How does Python work?", {'perplexity': 4.0, 'entropy': 2.0, 'resonance': 0.3, 'first_message': False}),
        ("Привет, как дела?", {'perplexity': 1.0, 'entropy': 1.5, 'resonance': 0.8, 'first_message': False}),
    ]
    
    for message, metrics in test_cases:
        print(f"\n--- Тест: '{message}' ---")
        
        windows = await nicole_objectivity.create_dynamic_context(message, metrics)
        context = nicole_objectivity.format_context_for_nicole(windows)
        seeds = nicole_objectivity.extract_response_seeds(context)
        
        print(f"Контекстных окон: {len(windows)}")
        print(f"Семена ответа: {seeds}")
        print(f"Контекст:\n{context[:400]}...")
        
    print("\n=== OBJECTIVITY TEST COMPLETED ===")

if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "test":
        asyncio.run(test_objectivity())
    else:
        print("Nicole Objectivity System готова")
        print("Для тестирования: python3 nicole_objectivity.py test")
