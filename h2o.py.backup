#!/usr/bin/env python3
"""
H2O - Hydrogen Oxide
Минимальный компилятор и среда исполнения Python, заточенная под трансформеры.
Без лишнего говна, только то что нужно для Field4.
"""

import ast
import sys
import os
import types
import sqlite3
import shutil
import subprocess
from pathlib import Path
from typing import Any, Dict, List, Optional, Union
import threading
import time

# Путь к бинарнику H2O (если есть в репозитории)
FIELD_DIR = Path(__file__).parent
BIN_DIR = FIELD_DIR / "bin"
H2O_BINARY = BIN_DIR / "h2o" if (BIN_DIR / "h2o").exists() else None

class H2ORuntime:
    """Минимальная среда исполнения для трансформеров Field4"""
    
    def __init__(self):
        self.globals_dict = {
            '__builtins__': {
                'print': print,
                'len': len,
                'range': range,
                'enumerate': enumerate,
                'zip': zip,
                'map': map,
                'filter': filter,
                'sum': sum,
                'max': max,
                'min': min,
                'abs': abs,
                'round': round,
                'int': int,
                'float': float,
                'str': str,
                'bool': bool,
                'list': list,
                'dict': dict,
                'set': set,
                'tuple': tuple,
                'type': type,
                'isinstance': isinstance,
                'hasattr': hasattr,
                'getattr': getattr,
                'setattr': setattr,
                'delattr': delattr,
                'vars': vars,
                'dir': dir,
                'id': id,
                'hash': hash,
                'repr': repr,
                'ord': ord,
                'chr': chr,
                'hex': hex,
                'oct': oct,
                'bin': bin,
                'any': any,
                'all': all,
                'sorted': sorted,
                'reversed': reversed,
                'slice': slice,
                'divmod': divmod,
                'pow': pow,
                'eval': eval,
                'exec': exec,
                'compile': compile,
                '__import__': __import__,
                '__build_class__': __build_class__,
                'super': super,
                'property': property,
                'staticmethod': staticmethod,
                'classmethod': classmethod,
                'Exception': Exception,
                'ValueError': ValueError,
                'TypeError': TypeError,
                'KeyError': KeyError,
                'IndexError': IndexError,
                'AttributeError': AttributeError,
            },
            '__name__': '__h2o__',
            'math': self._create_math_module(),
            'random': self._create_random_module(),
            'time': self._create_time_module(),
            'requests': self._create_requests_module(),
            'sqlite3': self._create_sqlite_module(),
        }
        self.locals_dict = {}
        self.execution_stack = []
        self.transformer_context = {}
        
    def _create_math_module(self):
        """Минимальный math модуль для трансформеров"""
        import math
        return types.SimpleNamespace(
            sin=math.sin, cos=math.cos, tan=math.tan,
            exp=math.exp, log=math.log, sqrt=math.sqrt,
            pi=math.pi, e=math.e,
            tanh=math.tanh, sinh=math.sinh, cosh=math.cosh,
            atan2=math.atan2, pow=math.pow, fabs=math.fabs,
            floor=math.floor, ceil=math.ceil
        )
        
    def _create_random_module(self):
        """Минимальный random модуль"""
        import random
        return types.SimpleNamespace(
            random=random.random,
            randint=random.randint,
            choice=random.choice,
            shuffle=random.shuffle,
            seed=random.seed,
            uniform=random.uniform,
            gauss=random.gauss,
            normalvariate=random.normalvariate
        )
        
    def _create_time_module(self):
        """Минимальный time модуль"""
        return types.SimpleNamespace(
            time=time.time,
            sleep=time.sleep,
            perf_counter=time.perf_counter
        )
    
    def _create_requests_module(self):
        """Минимальный requests модуль для objectivity"""
        try:
            import requests
            return types.SimpleNamespace(
                get=requests.get,
                post=requests.post,
                put=requests.put,
                delete=requests.delete,
                Session=requests.Session,
                RequestException=requests.RequestException
            )
        except ImportError:
            # Заглушка если requests не установлен
            def mock_get(*args, **kwargs):
                class MockResponse:
                    status_code = 200
                    def json(self): return {}
                    def text(self): return ""
                return MockResponse()
            
            return types.SimpleNamespace(
                get=mock_get,
                post=mock_get,
                RequestException=Exception
            )
    
    def _create_sqlite_module(self):
        """Минимальный sqlite3 модуль"""
        import sqlite3
        return types.SimpleNamespace(
            connect=sqlite3.connect,
            Row=sqlite3.Row,
            Error=sqlite3.Error
        )

class H2OCompiler:
    """Компилятор Python кода для Nicole трансформеров"""
    
    def __init__(self, runtime: H2ORuntime):
        self.runtime = runtime
        self.compiled_cache = {}
        
    def compile_transformer_script(self, code: str, script_id: str) -> types.CodeType:
        """Компилирует скрипт трансформера"""
        if script_id in self.compiled_cache:
            return self.compiled_cache[script_id]
            
        try:
            # Парсим AST
            tree = ast.parse(code)
            
            # Оптимизируем для трансформеров
            tree = self._optimize_for_transformers(tree)
            
            # Компилируем в байт-код
            compiled = compile(tree, f"<transformer_{script_id}>", 'exec')
            
            self.compiled_cache[script_id] = compiled
            return compiled
            
        except Exception as e:
            raise H2OCompilationError(f"Ошибка компиляции трансформера {script_id}: {e}")
    
    def _optimize_for_transformers(self, tree: ast.AST) -> ast.AST:
        """Оптимизации специфичные для трансформеров Nicole"""
        
        class TransformerOptimizer(ast.NodeTransformer):
            def visit_FunctionDef(self, node):
                # Добавляем декораторы для трекинга метрик
                if node.name.startswith('attention_') or node.name.startswith('feed_forward_'):
                    # Оборачиваем функции трансформера в метрики
                    pass
                return self.generic_visit(node)
                
            def visit_For(self, node):
                # Оптимизируем циклы для матричных операций
                return self.generic_visit(node)
                
            def visit_ListComp(self, node):
                # Оптимизируем list comprehensions для векторных операций
                return self.generic_visit(node)
        
        optimizer = TransformerOptimizer()
        return optimizer.visit(tree)

class H2OExecutor:
    """Исполнитель скриптов трансформеров"""
    
    def __init__(self, runtime: H2ORuntime, compiler: H2OCompiler):
        self.runtime = runtime
        self.compiler = compiler
        self.active_transformers = {}
        self.execution_lock = threading.Lock()
        
    def execute_transformer(self, code: str, transformer_id: str, context: Dict[str, Any] = None) -> Any:
        """Исполняет скрипт трансформера в изолированной среде"""
        
        with self.execution_lock:
            try:
                # Компилируем код
                compiled_code = self.compiler.compile_transformer_script(code, transformer_id)
                
                # Создаем изолированное окружение
                execution_globals = self.runtime.globals_dict.copy()
                execution_locals = {}
                
                # Добавляем контекст трансформера
                if context:
                    execution_globals.update(context)
                    
                # Добавляем специальные функции для трансформеров
                execution_globals.update({
                    'transformer_id': transformer_id,
                    'h2o_log': lambda msg: self._log_transformer_action(transformer_id, msg),
                    'h2o_metric': lambda name, value: self._record_metric(transformer_id, name, value),
                    'h2o_reshape': self._reshape_transformer,
                    'h2o_evolve': self._evolve_transformer,
                    # КРИТИЧНО: добавляем globals() функцию для objectivity скриптов
                    'globals': lambda: execution_globals,
                    'locals': lambda: execution_locals,
                })
                
                # Исполняем код (ВАЖНО: только globals, чтобы переменные попадали туда)
                result = exec(compiled_code, execution_globals, execution_globals)
                
                # Сохраняем состояние трансформера
                self.active_transformers[transformer_id] = {
                    'globals': execution_globals,
                    'locals': execution_locals,  # Теперь тоже globals
                    'last_execution': time.time(),
                    'code': code
                }
                
                # Логируем что сохранилось
                user_vars = {k: v for k, v in execution_globals.items() 
                           if not k.startswith('__') and k not in ['transformer_id', 'h2o_log', 'h2o_metric', 'h2o_reshape', 'h2o_evolve', 'globals', 'locals', 'math', 'random', 'time', 'requests', 'sqlite3']}
                if user_vars:
                    self._log_transformer_action(transformer_id, f"Сохранены переменные: {list(user_vars.keys())}")
                
                return result
                
            except Exception as e:
                self._log_transformer_error(transformer_id, str(e))
                raise H2OExecutionError(f"Ошибка исполнения трансформера {transformer_id}: {e}")
    
    def _log_transformer_action(self, transformer_id: str, message: str):
        """Логирует действия трансформера"""
        print(f"[H2O:{transformer_id}] {message}")
        
    def _record_metric(self, transformer_id: str, metric_name: str, value: float):
        """Записывает метрики трансформера"""
        # Тут будет интеграция с Nicole для записи метрик
        pass
        
    def _reshape_transformer(self, transformer_id: str, new_architecture: Dict):
        """Изменяет архитектуру трансформера на лету"""
        # Тут будет логика изменения архитектуры
        pass
        
    def _evolve_transformer(self, transformer_id: str, evolution_params: Dict):
        """Эволюционирует трансформер"""
        # Тут будет логика эволюции
        pass
        
    def _log_transformer_error(self, transformer_id: str, error: str):
        """Логирует ошибки трансформера"""
        print(f"[H2O:ERROR:{transformer_id}] {error}")
        
    def kill_transformer(self, transformer_id: str):
        """Убивает трансформер и освобождает ресурсы"""
        if transformer_id in self.active_transformers:
            del self.active_transformers[transformer_id]
            self._log_transformer_action(transformer_id, "TERMINATED")
            
    def list_active_transformers(self) -> List[str]:
        """Возвращает список активных трансформеров"""
        return list(self.active_transformers.keys())

class H2OEngine:
    """Главный движок H2O"""
    
    def __init__(self):
        self.runtime = H2ORuntime()
        self.compiler = H2OCompiler(self.runtime)
        self.executor = H2OExecutor(self.runtime, self.compiler)
        self.session_id = None
        
    def start_session(self, session_id: str):
        """Запускает новую сессию"""
        self.session_id = session_id
        print(f"[H2O] Сессия {session_id} запущена")
        
    def run_transformer_script(self, code: str, transformer_id: str = None, context: Dict = None) -> Any:
        """Запускает скрипт трансформера"""
        if not transformer_id:
            transformer_id = f"transformer_{int(time.time() * 1000000)}"
            
        return self.executor.execute_transformer(code, transformer_id, context)
        
    def kill_all_transformers(self):
        """Убивает все активные трансформеры"""
        for transformer_id in self.executor.list_active_transformers():
            self.executor.kill_transformer(transformer_id)
            
    def end_session(self):
        """Завершает сессию"""
        if self.session_id:
            self.kill_all_transformers()
            print(f"[H2O] Сессия {self.session_id} завершена")
            self.session_id = None

# Исключения H2O
class H2OError(Exception):
    """Базовое исключение H2O"""
    pass

class H2OCompilationError(H2OError):
    """Ошибка компиляции"""
    pass

class H2OExecutionError(H2OError):
    """Ошибка исполнения"""
    pass

# Глобальный экземпляр H2O движка
h2o_engine = H2OEngine()

def run_script(code: str, transformer_id: str = None, context: Dict = None) -> Any:
    """Удобная функция для запуска скриптов"""
    return h2o_engine.run_transformer_script(code, transformer_id, context)

def test_h2o():
    """Тестирование H2O движка"""
    print("=== H2O ENGINE TEST ===")
    
    # Тест 1: Простой скрипт
    test_code1 = """
def simple_transformer():
    h2o_log("Простой трансформер запущен")
    return "Hello from transformer!"

result = simple_transformer()
h2o_log(f"Результат: {result}")
"""
    
    h2o_engine.start_session("test_session")
    
    try:
        run_script(test_code1, "test_transformer_1")
        print("✓ Тест 1 пройден")
    except Exception as e:
        print(f"✗ Тест 1 провален: {e}")
        
    # Тест 2: Математические операции
    test_code2 = """
import math

def math_transformer():
    h2o_log("Математический трансформер")
    values = [math.sin(i) for i in range(10)]
    h2o_metric("values_sum", sum(values))
    return values

result = math_transformer()
h2o_log(f"Математический результат: {len(result)} значений")
"""
    
    try:
        run_script(test_code2, "test_transformer_2")
        print("✓ Тест 2 пройден")
    except Exception as e:
        print("✗ Тест 2 провален:", e)
        
    # Показываем активные трансформеры
    active = h2o_engine.executor.list_active_transformers()
    print(f"Активные трансформеры: {active}")
    
    h2o_engine.end_session()
    print("=== H2O TEST COMPLETED ===")

if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "test":
        test_h2o()
    else:
        print("H2O Engine готов к работе")
        print("Для тестирования запустите: python h2o.py test")
