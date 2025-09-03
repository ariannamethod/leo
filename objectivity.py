#!/usr/bin/env python3
“””
objectivity.py - Dynamic Context Window Generator

Анализирует пользовательское сообщение и создает контекстное окно
на основе лингвистического анализа и метрик системы.
“””

import re
import asyncio
import requests
import wikipedia
import json
from typing import Dict, List, Tuple, Optional
from dataclasses import dataclass
from urllib.parse import quote

@dataclass
class ContextWindow:
“”“Контекстное окно с весами важности”””
content: str
source_type: str  # ‘wikipedia’, ‘google’, ‘reddit’, ‘logs’
relevance_score: float
tokens_count: int

class ObjectivityEngine:
def **init**(self, max_context_kb: int = 2, logs_db_path: str = “nicole.db”):
self.max_context_kb = max_context_kb * 1024  # Convert to bytes
self.logs_db_path = logs_db_path
self.wikipedia.set_lang(“ru”)  # Можно динамически менять

```
    # Паттерны для лингвистического анализа
    self.proper_noun_patterns = [
        r'\b[A-ZА-Я][a-zа-я]+\b',  # Слова с заглавной буквы
        r'\b[A-ZА-Я]{2,}\b',        # Аббревиатуры
    ]
    
    # Паттерны для smalltalk
    self.smalltalk_patterns = [
        r'\b(как дела|what\'?s up|привет|hello|how are you)\b',
        r'\b(лол|хахах|wtf|omg|блять|fuck)\b',
        r'\b(мем|trend|trending|viral)\b'
    ]

async def analyze_message(self, user_message: str, metrics: Dict) -> List[ContextWindow]:
    """
    Главная функция - анализирует сообщение и создает контекстные окна
    """
    # Лингвистический анализ
    linguistic_analysis = self._analyze_linguistics(user_message)
    
    # Принятие решения на основе анализа и метрик
    search_strategy = self._decide_search_strategy(
        linguistic_analysis, 
        metrics,
        user_message
    )
    
    # Выполнение поиска
    context_windows = []
    for strategy in search_strategy:
        if strategy == 'wikipedia':
            windows = await self._search_wikipedia(linguistic_analysis['proper_nouns'])
            context_windows.extend(windows)
        elif strategy == 'google':
            windows = await self._search_google(user_message)
            context_windows.extend(windows)
        elif strategy == 'reddit':
            windows = await self._search_reddit(user_message)
            context_windows.extend(windows)
        elif strategy == 'logs':
            windows = await self._search_logs(user_message)
            context_windows.extend(windows)
    
    # Обрезка до лимита размера
    return self._trim_to_limit(context_windows)

def _analyze_linguistics(self, text: str) -> Dict:
    """Лингвистический анализ текста"""
    analysis = {
        'proper_nouns': [],
        'is_smalltalk': False,
        'language': 'en' if re.search(r'[a-zA-Z]', text) else 'ru',
        'has_questions': '?' in text,
        'capitalized_words': []
    }
    
    # Поиск имен собственных
    for pattern in self.proper_noun_patterns:
        matches = re.findall(pattern, text)
        analysis['proper_nouns'].extend(matches)
    
    # Определение smalltalk
    for pattern in self.smalltalk_patterns:
        if re.search(pattern, text.lower()):
            analysis['is_smalltalk'] = True
            break
            
    return analysis

def _decide_search_strategy(self, linguistics: Dict, metrics: Dict, message: str) -> List[str]:
    """
    Решает какие источники использовать на основе лингвистики и метрик
    """
    strategies = []
    
    # Если есть имена собственные - обязательно википедия
    if linguistics['proper_nouns'] and not self._in_logs(linguistics['proper_nouns']):
        strategies.append('wikipedia')
    
    # Если smalltalk - Reddit за жаргоном
    if linguistics['is_smalltalk']:
        strategies.append('reddit')
    
    # На основе метрик
    perplexity = metrics.get('perplexity', 0)
    entropy = metrics.get('entropy', 0)
    resonance = metrics.get('resonance', 0)
    
    # Высокая perplexity = модель не уверена = нужен гугл
    if perplexity > 5.0:
        strategies.append('google')
    
    # Низкая энтропия = скучные ответы = нужен свежий контент
    if entropy < 2.0:
        strategies.append('reddit')
        
    # Низкий резонанс = плохо понимаем контекст = поиск в логах
    if resonance < 0.3:
        strategies.append('logs')
        
    # Если ничего не определили - дефолтный поиск
    if not strategies:
        strategies.append('google')
        
    return strategies

async def _search_wikipedia(self, proper_nouns: List[str]) -> List[ContextWindow]:
    """Поиск в Википедии по именам собственным"""
    windows = []
    
    for noun in proper_nouns[:3]:  # Максимум 3 термина
        try:
            # Поиск статьи
            page = wikipedia.page(noun)
            
            # Берем первые 500 символов
            summary = page.summary[:500]
            
            window = ContextWindow(
                content=f"Wikipedia: {noun}\n{summary}",
                source_type='wikipedia',
                relevance_score=0.9,  # Википедия очень релевантна для имен собственных
                tokens_count=len(summary.split())
            )
            windows.append(window)
            
        except Exception as e:
            # Если не найдено в википедии, пробуем гугл
            continue
            
    return windows

async def _search_google(self, query: str) -> List[ContextWindow]:
    """Простой поиск в Google (заглушка - нужен API ключ)"""
    # TODO: Интегрировать с Google Custom Search API
    # Пока возвращаем заглушку
    
    window = ContextWindow(
        content=f"Google search context for: {query}\n[Здесь будет результат поиска]",
        source_type='google',
        relevance_score=0.7,
        tokens_count=50
    )
    return [window]

async def _search_reddit(self, query: str) -> List[ContextWindow]:
    """Поиск на Reddit за жаргоном и трендами"""
    try:
        # Используем Reddit API (без авторизации, только публичное)
        url = f"https://www.reddit.com/search.json?q={quote(query)}&limit=3"
        headers = {'User-Agent': 'Nicole-Bot/1.0'}
        
        response = requests.get(url, headers=headers)
        data = response.json()
        
        windows = []
        for post in data.get('data', {}).get('children', [])[:2]:
            post_data = post['data']
            content = f"Reddit: {post_data.get('title', '')}\n{post_data.get('selftext', '')[:300]}"
            
            window = ContextWindow(
                content=content,
                source_type='reddit',
                relevance_score=0.6,
                tokens_count=len(content.split())
            )
            windows.append(window)
            
        return windows
        
    except Exception as e:
        return []

async def _search_logs(self, query: str) -> List[ContextWindow]:
    """Поиск в собственных логах Nicole"""
    # TODO: Интегрировать с базой данных логов
    # Семантический поиск по прошлым диалогам
    
    window = ContextWindow(
        content=f"From logs: Similar context for '{query}'",
        source_type='logs',
        relevance_score=0.8,
        tokens_count=30
    )
    return [window]

def _in_logs(self, terms: List[str]) -> bool:
    """Проверяет есть ли термины в логах"""
    # TODO: Реальная проверка в БД
    return False

def _trim_to_limit(self, windows: List[ContextWindow]) -> List[ContextWindow]:
    """Обрезает контекстные окна до лимита размера"""
    # Сортируем по релевантности
    windows.sort(key=lambda x: x.relevance_score, reverse=True)
    
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

def format_context_for_model(self, windows: List[ContextWindow]) -> str:
    """Форматирует контекстные окна для подачи в модель"""
    if not windows:
        return ""
        
    formatted = "=== CONTEXT WINDOW ===\n"
    for i, window in enumerate(windows):
        formatted += f"[{window.source_type.upper()}] {window.content}\n\n"
        
    formatted += "=== END CONTEXT ===\n"
    return formatted
```

# Пример использования

async def main():
engine = ObjectivityEngine()

```
# Тестовые метрики
test_metrics = {
    'perplexity': 3.2,
    'entropy': 4.1,
    'resonance': 0.6
}

# Тест с именем собственным
windows = await engine.analyze_message("I love Berlin", test_metrics)
context = engine.format_context_for_model(windows)
print("=== TEST 1: Proper noun ===")
print(context)

# Тест со smalltalk
windows = await engine.analyze_message("как дела бро, чё как?", test_metrics)
context = engine.format_context_for_model(windows)
print("\n=== TEST 2: Smalltalk ===")
print(context)
```

if **name** == “**main**”:
asyncio.run(main())
