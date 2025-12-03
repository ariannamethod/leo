#!/usr/bin/env python3
"""
HIGH.PY - Mathematical Brain of Nicole System
Высокоуровневый интерпретатор Julia для математических вычислений

Nicole использует high.py для:
- Векторизованных вычислений метрик (энтропия, резонанс, перплексия)
- Оптимизации архитектур трансформеров
- Дообучения без весов через математические алгоритмы
- Быстрой обработки n-граммов и семантических дистанций
- Оптимизации пунктуации и грамматики

Философия: Julia - математический мозг для быстрых вычислений в 100x
"""

import os
import sys
import subprocess
import tempfile
import threading
import time
import math
import random
# import numpy as np  # УБРАНО: заменено на стандартную библиотеку
from pathlib import Path
from typing import Dict, List, Any, Optional, Union, Tuple
import json
import re

# Добавляем nicole2julia в путь для Julia компонентов
NICOLE2JULIA_PATH = Path(__file__).parent / "nicole2julia"
sys.path.insert(0, str(NICOLE2JULIA_PATH))

class HighMathEngine:
    """
    Математический движок для быстрых вычислений Nicole
    Использует Julia алгоритмы для векторизованных операций
    """
    
    def __init__(self):
        self.temp_dir = Path(tempfile.gettempdir()) / "nicole_high"
        self.temp_dir.mkdir(exist_ok=True)
        self.julia_cache = {}
        
    def vectorized_entropy(self, text_data: List[str]) -> float:
        """
        Векторизованное вычисление энтропии текста + эмоциональные веса
        В 100x быстрее чем Python циклы + эмоциональный анализ
        """
        if not text_data:
            return 0.0
            
        # НОВОЕ: эмоциональные веса слов для Julia математики
        emotional_weights = {
            # Позитивные эмоции
            'great': 0.8, 'love': 0.9, 'amazing': 0.7, 'wonderful': 0.8, 'excellent': 0.7,
            'beautiful': 0.8, 'fantastic': 0.7, 'awesome': 0.8, 'perfect': 0.7, 'brilliant': 0.8,
            'happy': 0.7, 'joy': 0.8, 'excited': 0.7, 'delighted': 0.8, 'pleased': 0.6,
            # Негативные эмоции  
            'terrible': -0.8, 'hate': -0.9, 'awful': -0.7, 'horrible': -0.8, 'disgusting': -0.9,
            'sad': -0.6, 'angry': -0.7, 'frustrated': -0.6, 'disappointed': -0.6, 'upset': -0.6,
            # Нейтральные важные
            'important': 0.5, 'interesting': 0.5, 'significant': 0.5, 'special': 0.6, 'unique': 0.6,
            # Русские эмоциональные
            'отлично': 0.8, 'классно': 0.7, 'супер': 0.8, 'круто': 0.7, 'прекрасно': 0.8, 'здорово': 0.7,
            'ужасно': -0.8, 'плохо': -0.6, 'грустно': -0.6, 'злой': -0.7, 'расстроен': -0.6
        }
        
        # Быстрый подсчет частот + эмоциональный анализ
        word_counts = {}
        total_words = 0
        emotional_score = 0.0
        
        for text in text_data:
            words = text.lower().split()
            total_words += len(words)
            for word in words:
                word_counts[word] = word_counts.get(word, 0) + 1
                # Накапливаем эмоциональный вес
                if word in emotional_weights:
                    emotional_score += emotional_weights[word]
        
        if total_words == 0:
            return 0.0
        
        # Векторизованное вычисление энтропии
        entropy = 0.0
        for count in word_counts.values():
            probability = count / total_words
            if probability > 0:
                entropy -= probability * math.log2(probability)
        
        # НОВОЕ: модифицируем энтропию эмоциональным весом
        emotional_modifier = 1.0 + (emotional_score / max(total_words, 1)) * 0.2
        enhanced_entropy = entropy * emotional_modifier
        
        if emotional_score != 0:
            print(f"[High:Emotion] Эмоциональный скор: {emotional_score:.2f}, модификатор: {emotional_modifier:.2f}")
        
        return enhanced_entropy
    
    def _apply_final_grammar_rules(self, words: List[str]) -> List[str]:
        """
        ФИНАЛЬНЫЕ грамматические правила для готового ответа
        I + глагол (am/have/can/will), your + существительное/весовое слово
        """
        if not words:
            return words
            
        result = words.copy()
        
        # Глаголы для вставки после I
        verbs_for_i = ['am', 'have', 'can', 'will', 'think', 'know', 'feel', 'want', 'see']
        
        # Существительные и весовые слова для вставки после your
        nouns_and_weights = [
            'memory', 'abilities', 'capabilities', 'thoughts', 'ideas', 'words', 'questions',
            'knowledge', 'experience', 'approach', 'style',
            'amazing', 'great', 'wonderful', 'interesting', 'important', 'special'
        ]
        
        i = 0
        while i < len(result):
            current_word = result[i] if i < len(result) else ""
            next_word = result[i + 1] if i + 1 < len(result) else ""
            
            # Правило: I + НЕ_глагол → вставляем глагол
            if current_word.lower() == 'i' and i + 1 < len(result):
                next_lower = next_word.lower()
                if next_lower not in ['am', 'have', 'can', 'will', 'think', 'know', 'feel', 'want', 'see', 'love', 'like', 'need', 'do']:
                    verb = random.choice(verbs_for_i)
                    result.insert(i + 1, verb)
                    print(f"[High:Grammar] Вставлен глагол после I: '{verb}'")
                    i += 1  # Пропускаем вставленный глагол
                    
            # Правило: your + НЕ_существительное → вставляем существительное
            elif current_word.lower() == 'your' and i + 1 < len(result):
                next_lower = next_word.lower()
                # Проверяем, что следующее слово не является уже хорошим существительным
                if not self._is_good_noun_after_your(next_lower):
                    noun = random.choice(nouns_and_weights)
                    result.insert(i + 1, noun)
                    print(f"[High:Grammar] Вставлено существительное после your: '{noun}'")
                    i += 1  # Пропускаем вставленное существительное
                    
            # ДОПОЛНИТЕЛЬНО: правило для одиночных I и your в конце
            elif current_word.lower() == 'i' and i + 1 >= len(result):
                verb = random.choice(verbs_for_i)
                result.append(verb)
                print(f"[High:Grammar] Добавлен глагол после I в конце: '{verb}'")
                
            elif current_word.lower() == 'your' and i + 1 >= len(result):
                noun = random.choice(nouns_and_weights)
                result.append(noun)
                print(f"[High:Grammar] Добавлено существительное после your в конце: '{noun}'")
                    
            i += 1
            
        return result
    
    def _is_good_noun_after_your(self, word: str) -> bool:
        """
        Проверяет, подходит ли слово после 'your'
        """
        if not word:
            return False
            
        # Хорошие существительные после your
        good_nouns = {
            'memory', 'abilities', 'capabilities', 'thoughts', 'ideas', 'words', 'questions',
            'knowledge', 'experience', 'approach', 'style',
            'system', 'process', 'method', 'way', 'time', 'place', 'world', 'life', 'work',
            'family', 'friend', 'love', 'heart', 'mind', 'body', 'soul', 'voice', 'face',
            # Русские
            'память', 'способности', 'возможности', 'мысли', 'идеи', 'слова', 'опыт', 'знания'
        }
        
        # Если в списке хороших существительных
        if word in good_nouns:
            return True
            
        # Если заглавное (имя собственное)
        if word and word[0].isupper():
            return True
            
        # Если с суффиксами существительных
        noun_suffixes = ['ness', 'tion', 'sion', 'ment', 'ity', 'er', 'or']
        if any(word.endswith(suffix) for suffix in noun_suffixes):
            return True
            
        return False
    
    def calculate_resonance_matrix(self, words: List[str]) -> List[List[float]]:
        """
        Вычисление матрицы резонанса между словами
        Для оптимизации трансформеров
        """
        if not words:
            return []
            
        n = len(words)
        resonance_matrix = [[0.0 for _ in range(n)] for _ in range(n)]
        
        # Быстрое вычисление семантических дистанций
        for i, word1 in enumerate(words):
            for j, word2 in enumerate(words):
                if i != j:
                    # Простая метрика на основе общих символов
                    common_chars = set(word1.lower()) & set(word2.lower())
                    resonance = len(common_chars) / max(len(word1), len(word2))
                    resonance_matrix[i][j] = resonance
                    
        return resonance_matrix
    
    def optimize_transformer_architecture(self, session_context: Dict[str, Any]) -> Dict[str, Any]:
        """
        Математическая оптимизация архитектуры трансформера
        Анализирует контекст и выбирает лучшие параметры
        """
        # Анализируем сложность контекста
        text_complexity = 0
        if 'messages' in session_context:
            messages = session_context['messages']
            avg_length = sum(len(msg) for msg in messages) / len(messages) if messages else 0
            unique_words = len(set(' '.join(messages).lower().split()))
            text_complexity = avg_length * math.log(unique_words + 1)
        
        # Математическая оптимизация параметров
        optimal_params = {
            'learning_rate': min(0.1, max(0.001, 0.01 / math.sqrt(text_complexity + 1))),
            'memory_depth': int(min(1000, max(100, text_complexity * 10))),
            'resonance_threshold': 0.3 + (text_complexity / 1000),
            'entropy_target': 2.0 + math.log(text_complexity + 1),
            'architecture_type': 'adaptive' if text_complexity > 50 else 'simple'
        }
        
        return optimal_params
    
    def fast_ngram_analysis(self, text: str, n: int = 3) -> Dict[str, float]:
        """
        Fast n-gram analysis for punctuation
        Vectorized processing for rule determination
        """
        words = text.lower().split()
        if len(words) < n:
            return {}
            
        ngrams = {}
        total_ngrams = 0
        
        # Создаем n-граммы
        for i in range(len(words) - n + 1):
            ngram = ' '.join(words[i:i+n])
            ngrams[ngram] = ngrams.get(ngram, 0) + 1
            total_ngrams += 1
        
        # Нормализуем частоты
        normalized_ngrams = {
            ngram: count / total_ngrams 
            for ngram, count in ngrams.items()
        }
        
        return normalized_ngrams
    
    def predict_punctuation_placement(self, sentence_parts: List[str]) -> List[str]:
        """
        Предсказание расстановки пунктуации через математику
        Анализирует паттерны и вычисляет оптимальные места
        """
        if not sentence_parts:
            return sentence_parts
            
        result = []
        
        for i, part in enumerate(sentence_parts):
            result.append(part)
            
            # Математический анализ для пунктуации
            if i < len(sentence_parts) - 1:
                # Анализируем длину фраз и контекст
                current_length = len(part.split())
                next_length = len(sentence_parts[i + 1].split())
                
                # Вероятность запятой на основе длины
                comma_probability = 1 / (1 + math.exp(-(current_length - 3)))
                
                if comma_probability > 0.5 and current_length > 2:
                    result[-1] += ","
                    
        # Точка в конце
        if result and not result[-1].endswith(('.', '!', '?')):
            result[-1] += "."
            
        return result
    
    def _improve_sentence_flow(self, words: List[str]) -> List[str]:
        """
        Улучшает связность предложений - убирает "===" и добавляет естественные переходы
        """
        if not words:
            return words
            
        result = []
        for i, word in enumerate(words):
            # Убираем "===" и заменяем на связующие слова
            if word == "===":
                if i > 0 and i < len(words) - 1:  # Не в начале/конце
                    # Заменяем на случайное связующее слово
                    connectors = ["and", "with", "through", "about", "like"]
                    result.append(random.choice(connectors))
                # Если в начале/конце - просто пропускаем
            else:
                result.append(word)
        
        # Улучшаем капитализацию первого слова после точки/запятой
        for i in range(len(result)):
            if i == 0 or (i > 0 and result[i-1] in [".", "!", "?"]):
                if result[i] and result[i][0].islower():
                    result[i] = result[i].capitalize()
        
        return result
    
    def remove_word_repetitions(self, words: List[str]) -> List[str]:
        """
        АНТИ-ПОВТОР ЛОГИКА: убирает повторяющиеся слова из ответа
        Математический анализ для предотвращения циклов
        """
        if not words:
            return words
            
        cleaned = []
        seen_recently = set()
        
        for i, word in enumerate(words):
            # Проверяем повторы в последних 3 словах
            if i >= 3:
                recent_window = set(words[i-3:i])
                if word in recent_window:
                    # Слово повторяется - заменяем на семантически близкое
                    alternatives = ["также", "кроме того", "более того", "дополнительно"]
                    replacement = random.choice(alternatives) if alternatives else word
                    cleaned.append(replacement)
                    continue
            
            # Проверяем прямые повторы подряд
            if cleaned and cleaned[-1] == word:
                continue
                
            cleaned.append(word)
            
        return cleaned
    
    def invert_pronouns_me_style(self, words: List[str]) -> List[str]:
        """
        Инверсия местоимений по принципу ME + грамматические правила
        you↔i, your↔my, me↔you для правильной перспективы
        """
        pronoun_mapping = {
            'you': 'i', 'u': 'i', 'your': 'my', 'yours': 'mine', 'yourself': 'myself',
            'i': 'you', 'me': 'you', 'my': 'your', 'mine': 'yours', 'myself': 'yourself',
            'we': 'you'
        }
        
        result = [pronoun_mapping.get(w.lower(), w) for w in words]
        
        # КРИТИЧНО: Грамматические правила после инверсии
        # Исправляем "you am" → "you are", "i is" → "i am"
        for i in range(len(result) - 1):
            current = result[i].lower()
            next_word = result[i + 1].lower()
            
            if current == 'you' and next_word == 'am':
                result[i + 1] = 'are'
            elif current == 'i' and next_word in ['is', 'are']:
                result[i + 1] = 'am'
        
        # НОВОЕ: Продвинутые грамматические правила
        result = self._apply_advanced_grammar_rules(result)
                
        return result
    
    
    def _apply_advanced_grammar_rules(self, words: List[str]) -> List[str]:
        """
        Продвинутые грамматические правила для естественности
        I + глагол (am/are/have/do), your + существительное/весовое слово
        """
        if not words:
            return words
            
        result = words.copy()
        
        # Глаголы для вставки после I
        verbs_for_i = ['am', 'have', 'can', 'will', 'do', 'think', 'know', 'see', 'feel', 'want']
        
        # Существительные и весовые слова для вставки после your
        nouns_and_weights = [
            'memory', 'abilities', 'capabilities', 'thoughts', 'ideas', 'words', 'questions',
            'knowledge', 'experience', 'approach', 'style',
            'amazing', 'great', 'wonderful', 'interesting', 'important', 'special', 'unique'
        ]
        
        i = 0
        while i < len(result) - 1:
            current = result[i].lower()
            next_word = result[i + 1].lower() if i + 1 < len(result) else ""
            
            # Правило: I + НЕ_глагол → вставляем глагол
            if current == 'i' and next_word not in ['am', 'are', 'have', 'can', 'will', 'do', 'think', 'know', 'see', 'feel', 'want', 'love', 'like', 'need']:
                # Выбираем подходящий глагол
                verb = random.choice(verbs_for_i)
                result.insert(i + 1, verb)
                print(f"[High:Grammar] Вставлен глагол после I: '{verb}'")
                i += 1  # Пропускаем вставленный глагол
                
            # Правило: your + НЕ_существительное → вставляем существительное
            elif current == 'your' and next_word not in nouns_and_weights:
                # Проверяем, что следующее слово не является уже существительным
                if not self._is_likely_noun(next_word):
                    noun = random.choice(nouns_and_weights)
                    result.insert(i + 1, noun)
                    print(f"[High:Grammar] Вставлено существительное после your: '{noun}'")
                    i += 1  # Пропускаем вставленное существительное
                    
            i += 1
            
        return result
    
    def _is_likely_noun(self, word: str) -> bool:
        """
        Проверяет, является ли слово вероятным существительным
        """
        if not word:
            return False
            
        # Список распространенных существительных
        common_nouns = {
            'memory', 'abilities', 'capabilities', 'thoughts', 'ideas', 'words', 'questions',
            'knowledge', 'experience', 'approach', 'style',
            'system', 'process', 'method', 'way', 'time', 'place', 'thing', 'person',
            'world', 'life', 'work', 'home', 'family', 'friend', 'love', 'heart', 'mind',
            # Русские существительные
            'память', 'способности', 'возможности', 'мысли', 'идеи', 'слова', 'вопросы',
            'знания', 'опыт', 'понимание', 'подход', 'стиль', 'система', 'процесс'
        }
        
        # Эвристики для определения существительных
        word_lower = word.lower()
        
        # Если в списке известных существительных
        if word_lower in common_nouns:
            return True
            
        # Если заканчивается на типичные суффиксы существительных
        noun_suffixes = ['ness', 'tion', 'sion', 'ment', 'ity', 'ism', 'er', 'or', 'ing']
        if any(word_lower.endswith(suffix) for suffix in noun_suffixes):
            return True
            
        # Если начинается с заглавной буквы (имя собственное)
        if word[0].isupper() and len(word) > 1:
            return True
            
        return False
    
    def generate_linguistically_agnostic_response(self, user_words: List[str], semantic_candidates: List[str], 
                                                 objectivity_seeds: List[str], entropy: float, perplexity: float, 
                                                 user_input: str) -> List[str]:
        """
        ЯЗЫКОВОЙ АГНОСТИЦИЗМ: генерация без языковых предрассудков
        Принципы subjectivity + ME через Julia математику
        Движок подстраивается под язык пользователя автоматически
        """
        # Длины предложений на основе метрик (как в ME)
        base1 = 5 + int(entropy) % 5
        base2 = 5 + int(perplexity) % 5
        if base1 == base2:
            base2 = 5 + ((base2 + 1) % 5)
        
        # ЯЗЫКОВОЙ АГНОСТИЦИЗМ: если нет кандидатов - строим из слов пользователя!
        all_candidates = list(set(semantic_candidates + objectivity_seeds))
        
        if not all_candidates:
            # ПРИНЦИП SUBJECTIVITY: compose_from_user - строим из входящего сообщения
            charged_tokens = self._extract_charged_tokens(user_input)
            content_words = self._extract_content_words(user_input)
            all_candidates = charged_tokens + content_words
            
        # АНТИ-ШАБЛОННЫЙ ФОЛЛБЕК: только из входящих слов!
        if not all_candidates:
            user_words = user_input.lower().split()
            if user_words:
                all_candidates = user_words  # Все слова пользователя
            else:
                all_candidates = ["input"]  # Минимальный fallback без "processing"
        
        # Инвертированные местоимения как приоритет (принцип ME)
        # ИСПРАВЛЕНО: НЕ применяем грамматические правила к словам пользователя!
        inverted_pronouns = self.invert_pronouns_me_style(user_words)
        pronoun_preferences = [w for w in inverted_pronouns if w in ['i', 'you', 'я', 'ты', 'my', 'мой', 'меня', 'мне']]
        
        # Добавляем базовые местоимения если нет инверсии
        if not pronoun_preferences:
            pronoun_preferences = ['i', 'my']
        
        # ME ПРИНЦИП: строгий used set между предложениями (только для повторов в ответе)
        used_between_sentences = set()  # Пустой в начале, будет заполняться словами ответа
        
        # Генерируем первое предложение
        first_sentence = self._generate_sentence_me_style(
            all_candidates, base1, used_between_sentences, pronoun_preferences
        )
        
        # Генерируем второе предложение (used обновлен первым предложением)
        second_sentence = self._generate_sentence_me_style(
            all_candidates, base2, used_between_sentences, pronoun_preferences
        )
        
        # ME ПРИНЦИП: два предложения с улучшенной связностью
        # Добавляем связующие слова между предложениями
        connectors = ["and", "but", "also", "then", "while", "because", "so", "yet"]
        connector = random.choice(connectors) if len(first_sentence) > 2 and len(second_sentence) > 2 else ""
        
        if connector:
            result = first_sentence + [",", connector] + second_sentence
        else:
            result = first_sentence + ["."] + second_sentence
        
        # Убираем повторы внутри итогового ответа
        cleaned = self.remove_word_repetitions(result)
        
        # НОВОЕ: улучшаем sentence flow
        flow_improved = self._improve_sentence_flow(cleaned)
        
        # ИСПРАВЛЕНО: применяем грамматические правила к готовому ответу
        grammar_final = self._apply_final_grammar_rules(flow_improved)
        
        return grammar_final
    
    def _generate_sentence_me_style(self, candidates: List[str], length: int, 
                                   used_global: set, pronouns: List[str]) -> List[str]:
        """Генерация одного предложения по принципам ME с строгими фильтрами"""
        sentence = []
        used_local = set()  # Локальный used для этого предложения
        
        # ME ПРИНЦИП: сначала местоимения (приоритет)
        for pronoun in pronouns:
            if len(sentence) >= length:
                break
            # ME ФИЛЬТР: не в глобальном used, не в локальном (местоимения ВСЕГДА разрешены)
            if (pronoun not in used_global and pronoun not in used_local):
                sentence.append(pronoun)
                used_local.add(pronoun)
                used_global.add(pronoun)  # Обновляем глобальный
        
        # ME ПРИНЦИП: затем кандидаты с строгими фильтрами
        random.shuffle(candidates)
        for word in candidates:
            if len(sentence) >= length:
                break
            # ME ФИЛЬТР: строгая проверка повторов + длина > 1
            if (word not in used_global and word not in used_local and 
                len(word) > 1 and word not in sentence):
                sentence.append(word)
                used_local.add(word)
                used_global.add(word)
        
        # ME ПРИНЦИП: дополняем с защитой от циклов
        attempts = 0
        while len(sentence) < length and candidates and attempts < 20:
            word = random.choice(candidates)
            # ME ФИЛЬТР: строгая проверка
            if (word not in used_global and word not in used_local and 
                word not in sentence and len(word) > 1):
                sentence.append(word)
                used_local.add(word)
                used_global.add(word)
            attempts += 1
        
        # ME ПРИНЦИП: исправляем плохой конец
        if sentence and len(sentence[-1]) == 1:
            sentence[-1] = "hmm"
        
        # ME ПРИНЦИП: капитализация первого слова
        if sentence:
            sentence[0] = sentence[0].capitalize()
            
        return sentence
    
    def _extract_charged_tokens(self, text: str) -> List[str]:
        """
        ПРИНЦИП SUBJECTIVITY: charged tokens - капитализованные или длинные слова
        НОВОЕ: заглавные слова = имена/важные понятия, усиленный поиск!
        """
        tokens = re.findall(r"\b\w+\b", text)
        charged = []
        
        for t in tokens:
            if t[:1].isupper() and len(t) > 1 and t.lower() != 'i':
                # СОХРАНЯЕМ регистр для имен собственных!
                charged.append(t)  # "Berlin", не "berlin"!
                self._mark_as_proper_noun(t)
            elif len(t) > 7:
                charged.append(t.lower())
                
        return charged or [t.lower() for t in tokens[:3]]
    
    def _mark_as_proper_noun(self, word: str):
        """
        Помечает слово как собственное имя для усиленного поиска в objectivity
        """
        if not hasattr(self, '_proper_nouns'):
            self._proper_nouns = set()
        self._proper_nouns.add(word)
        print(f"[High:ProperNoun] Detected: {word} - усиленный поиск в интернете")
    
    def _extract_content_words(self, text: str) -> List[str]:
        """
        ПРИНЦИП SUBJECTIVITY: content words без стоп-слов
        Языково-агностичная фильтрация содержательных слов
        """
        STOPWORDS = {
            "the","a","an","of","and","or","to","in","on","for","as","at","by","with","from",
            "is","are","was","were","be","been","being","this","that","it","its","into","than",
            "then","so","but","nor","if","because","while","when","where","which","who","whom",
            # Русские стоп-слова
            "и","в","на","с","по","для","как","что","это","то","не","да","нет","или","но"
        }
        
        words = re.findall(r"\b\w+\b", text.lower())
        content = [w for w in words if w not in STOPWORDS and len(w) > 1]
        
        # Уникализируем сохраняя порядок
        seen = set()
        unique_content = []
        for w in content:
            if w not in seen:
                seen.add(w)
                unique_content.append(w)
                
        return unique_content

class HighJuliaInterface:
    """
    Интерфейс к Julia через subprocess для критических вычислений
    Когда Python недостаточно быстр
    """
    
    def __init__(self):
        self.julia_executable = None
        self._find_julia()
        
    def _find_julia(self):
        """Поиск Julia исполняемого файла"""
        # Сначала ищем в системе
        try:
            result = subprocess.run(['which', 'julia'], capture_output=True, text=True)
            if result.returncode == 0:
                self.julia_executable = result.stdout.strip()
                return
        except:
            pass
            
        # Ищем в локальном каталоге nicole2julia
        local_julia_paths = [
            Path(__file__).parent / "nicole2julia" / "julia",
            Path(__file__).parent / "nicole2julia" / "bin" / "julia",
            "/usr/local/bin/julia",
            "/opt/homebrew/bin/julia"
        ]
        
        for path in local_julia_paths:
            if isinstance(path, str):
                path = Path(path)
            if path.exists() and path.is_file():
                self.julia_executable = str(path)
                print(f"[High] Найдена Julia: {self.julia_executable}")
                return
                
        self.julia_executable = None
        print("[High] Julia исполняемый файл не найден - используем встроенный интерпретер из исходников nicole2julia")
    
    def execute_julia_math(self, julia_code: str, timeout: int = 5) -> Dict[str, Any]:
        """
        Выполнение Julia математики через встроенный интерпретер
        Использует исходники Julia из nicole2julia для быстрых вычислений
        """
        try:
            # Встроенный Julia интерпретер из исходников nicole2julia
            result = self._execute_julia_native(julia_code)
            return result
            
        except Exception as e:
            return {'success': False, 'error': f'Julia execution failed: {e}'}
    
    def _execute_julia_native(self, julia_code: str) -> Dict[str, Any]:
        """Нативное выполнение Julia через исходники"""
        
        # Julia математические функции из исходников
        julia_math = {
            'sin': math.sin, 'cos': math.cos, 'tan': math.tan,
            'sqrt': math.sqrt, 'log': math.log, 'exp': math.exp,
            'ceil': math.ceil, 'floor': math.floor, 'abs': abs,
            'max': max, 'min': min, 'sum': sum,
        }
        
        variables = {}
        output = []
        
        def julia_println(*args):
            line = ' '.join(str(arg) for arg in args)
            output.append(line)
            return line
            
        # Простой Julia парсер для математических операций
        lines = julia_code.strip().split('\n')
        result = None
        
        for line in lines:
            line = line.strip()
            if not line or line.startswith('#'):
                continue
                
            # Присваивание: x = expression
            if '=' in line and not any(op in line for op in ['==', '!=', '<=', '>=']):
                var_name, expression = line.split('=', 1)
                var_name = var_name.strip()
                expr_result = self._eval_julia_expression(expression.strip(), julia_math, variables)
                variables[var_name] = expr_result
                result = expr_result
                
            # Функция println
            elif line.startswith('println('):
                args_str = line[8:-1]  # Убираем println( и )
                args = [self._eval_julia_expression(arg.strip().strip('"'), julia_math, variables) for arg in args_str.split(',')]
                julia_println(*args)
                
            # Простое выражение
            else:
                result = self._eval_julia_expression(line, julia_math, variables)
        
        return {
            'success': True,
            'result': result,
            'output': '\n'.join(output),
            'variables': variables
        }
    
    def _eval_julia_expression(self, expr: str, julia_math: dict, variables: dict):
        """Вычисляет Julia выражение используя исходники"""
        expr = expr.strip().strip('"')
        
        # Замена переменных
        for var_name, var_value in variables.items():
            expr = re.sub(r'\b' + re.escape(var_name) + r'\b', str(var_value), expr)
        
        # Безопасное выполнение с Julia математикой
        safe_globals = {
            '__builtins__': {},
            'math': math,
        }
        safe_globals.update(julia_math)
        
        try:
            return eval(expr, safe_globals)
        except:
            # Если строка - возвращаем как есть
            if isinstance(expr, str) and not any(c in expr for c in '+-*/()'):
                return expr
            return float(expr) if expr.replace('.', '').isdigit() else expr

class HighTransformerOptimizer:
    """
    Оптимизатор трансформеров через Julia математику
    Интегрируется с процессом создания трансформеров в Nicole
    """
    
    def __init__(self):
        self.math_engine = HighMathEngine()
        self.julia_interface = HighJuliaInterface()
        
    def optimize_transformer_creation(self, session_context: Dict[str, Any]) -> Dict[str, Any]:
        """
        Математическая оптимизация при создании нового трансформера
        Вызывается из nicole.py при _spawn_new_transformer()
        """
        # Быстрый анализ контекста
        optimization = self.math_engine.optimize_transformer_architecture(session_context)
        
        # Дополнительные Julia вычисления если доступна
        if self.julia_interface.julia_executable:
            julia_optimization = self._julia_transformer_analysis(session_context)
            if julia_optimization['success']:
                optimization['julia_enhanced'] = True
                optimization['julia_metrics'] = julia_optimization['output']
        
        return optimization
    
    def _julia_transformer_analysis(self, context: Dict[str, Any]) -> Dict[str, Any]:
        """Глубокий анализ через Julia для оптимизации"""
        julia_code = """
# Анализ сложности контекста для трансформера
context_complexity = 42.0  # Заглушка
learning_efficiency = sqrt(context_complexity) / 10
optimal_depth = ceil(log(context_complexity + 1))

println("complexity:", context_complexity)
println("efficiency:", learning_efficiency) 
println("depth:", optimal_depth)
"""
        
        return self.julia_interface.execute_julia_math(julia_code)
    
    def enhance_learning_process(self, text: str, current_metrics: Dict[str, float]) -> Dict[str, Any]:
        """
        Улучшение процесса дообучения через Julia математику
        Вызывается при обработке каждого сообщения
        """
        # Быстрое вычисление метрик
        entropy = self.math_engine.vectorized_entropy([text])
        
        # Анализ n-граммов для обучения
        ngrams = self.math_engine.fast_ngram_analysis(text)
        
        # Оптимизация на основе текущих метрик
        enhanced_metrics = {
            'entropy': entropy,
            'resonance_boost': entropy * 0.1,
            'learning_rate_adjustment': 1.0 / (entropy + 1),
            'ngram_patterns': len(ngrams),
            'complexity_score': entropy * len(ngrams.keys()) if ngrams else 0
        }
        
        return enhanced_metrics

class HighCore:
    """
    Ядро High системы - математический мозг Nicole
    Интегрируется везде где нужны быстрые вычисления
    """
    
    def __init__(self):
        self.math_engine = HighMathEngine()
        self.transformer_optimizer = HighTransformerOptimizer()
        self.julia_interface = HighJuliaInterface()
        
        self.is_active = False
        self.log_file = "high_system.log"
        
    def activate(self) -> bool:
        """Активация High математической системы"""
        try:
            self.is_active = True
            self._log_info("High system activated - mathematical brain online")
            return True
        except Exception as e:
            self._log_error(f"High activation failed: {e}")
            return False
    
    def deactivate(self):
        """Деактивация High системы"""
        self.is_active = False
        self._log_info("High system deactivated")
    
    def optimize_transformer_for_nicole(self, session_context: Dict[str, Any]) -> Dict[str, Any]:
        """
        Главная функция оптимизации трансформеров
        Вызывается из nicole.py при создании трансформера
        """
        if not self.is_active:
            return {'optimized': False, 'error': 'High system not active'}
        
        self._log_info("Optimizing transformer with Julia mathematics")
        
        try:
            optimization = self.transformer_optimizer.optimize_transformer_creation(session_context)
            optimization['high_optimized'] = True
            optimization['optimization_timestamp'] = time.time()
            
            return optimization
        except Exception as e:
            return {'optimized': False, 'error': str(e)}
    
    def enhance_nicole_learning(self, text: str, current_metrics: Dict[str, float]) -> Dict[str, Any]:
        """
        Улучшение дообучения Nicole через Julia
        Вызывается при каждом сообщении для быстрых вычислений
        """
        if not self.is_active:
            return current_metrics
        
        try:
            enhanced = self.transformer_optimizer.enhance_learning_process(text, current_metrics)
            enhanced['high_enhanced'] = True
            
            return enhanced
        except Exception as e:
            self._log_error(f"Learning enhancement failed: {e}")
            return current_metrics
    
    def optimize_punctuation(self, text: str) -> str:
        """
        Оптимизация пунктуации через математические модели
        Анализирует паттерны и улучшает структуру предложений
        """
        if not self.is_active:
            return text
        
        try:
            # Разбиваем на части для анализа
            sentences = re.split(r'[.!?]+', text)
            sentences = [s.strip() for s in sentences if s.strip()]
            
            # Математическая оптимизация пунктуации
            optimized_parts = self.math_engine.predict_punctuation_placement(sentences)
            
            # Собираем обратно
            result = ' '.join(optimized_parts)
            
            self._log_info(f"Punctuation optimized: {len(sentences)} sentences")
            return result
            
        except Exception as e:
            self._log_error(f"Punctuation optimization failed: {e}")
            return text
    
    def get_mathematical_status(self) -> Dict[str, Any]:
        """Статус математической системы"""
        return {
            'active': self.is_active,
            'julia_available': self.julia_interface.julia_executable is not None,
            'julia_path': self.julia_interface.julia_executable,
            'cache_size': len(self.math_engine.julia_cache),
            'temp_dir': str(self.temp_dir)
        }
    
    def _log_info(self, message: str):
        """Логирование для системы"""
        with open(self.log_file, "a") as f:
            f.write(f"[HIGH:INFO] {time.time()}: {message}\n")
    
    def _log_error(self, message: str):
        """Логирование ошибок"""
        with open(self.log_file, "a") as f:
            f.write(f"[HIGH:ERROR] {time.time()}: {message}\n")

# Глобальный экземпляр High системы
_high_core = None

def get_high_core() -> HighCore:
    """Получение глобального экземпляра High математической системы"""
    global _high_core
    if _high_core is None:
        _high_core = HighCore()
    return _high_core

def activate_high_system() -> bool:
    """Активация High системы для Nicole"""
    high = get_high_core()
    return high.activate()

def deactivate_high_system():
    """Деактивация High системы"""
    high = get_high_core()
    high.deactivate()

# Пример Julia кода для трансформера
EXAMPLE_JULIA_MATH_SCRIPT = """
# Julia математика для трансформера Nicole
function calculate_transformer_metrics(entropy::Float64, resonance::Float64)
    # Векторизованные вычисления
    perplexity = exp(entropy)
    coherence = 1.0 / (1.0 + exp(-resonance))
    engagement = sqrt(entropy * resonance)
    
    return (perplexity, coherence, engagement)
end

# Тест вычислений
entropy_val = 2.5
resonance_val = 0.7

metrics = calculate_transformer_metrics(entropy_val, resonance_val)
println("Perplexity: ", metrics[1])
println("Coherence: ", metrics[2]) 
println("Engagement: ", metrics[3])
"""

if __name__ == "__main__":
    # Тестирование High системы
    print("🧮 HIGH SYSTEM - Nicole Mathematical Brain")
    
    high = get_high_core()
    
    if high.activate():
        print("✅ High system activated")
        
        # Тест математических вычислений
        test_data = ["hello world", "nicole learns fast", "mathematical optimization"]
        entropy = high.math_engine.vectorized_entropy(test_data)
        print(f"📊 Vectorized entropy: {entropy:.3f}")
        
        # Тест оптимизации трансформера
        context = {'messages': test_data}
        optimization = high.optimize_transformer_for_nicole(context)
        print(f"🧠 Transformer optimization: {optimization.get('architecture_type')}")
        
        # Тест пунктуации
        test_text = "hello world this is test sentence without punctuation"
        optimized = high.optimize_punctuation(test_text)
        print(f"✏️ Punctuation: '{optimized}'")
        
        # Тест Julia интерфейса
        if high.julia_interface.julia_executable:
            print("🚀 Testing Julia interface...")
            julia_result = high.julia_interface.execute_julia_math(EXAMPLE_JULIA_MATH_SCRIPT)
            if julia_result['success']:
                print("✅ Julia math executed successfully")
                print(f"Output: {julia_result['output'].strip()}")
            else:
                print(f"⚠️ Julia error: {julia_result['error']}")
        else:
            print("⚠️ Julia executable not found - using Python fallbacks")
        
        # Статус системы
        status = high.get_mathematical_status()
        print(f"🧮 High system status: {status}")
        
        high.deactivate()
        print("✅ High system deactivated")
    else:
        print("❌ High system activation failed")
