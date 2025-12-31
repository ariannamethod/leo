#!/usr/bin/env python3
"""
async_modules.py — Async module aliases for Leo

Phase 2.1: Simple async wrappers for remaining modules.
These modules currently use sync I/O but will be migrated to async in future.

For now, they work with async Leo by being called from within async context.
"""

from __future__ import annotations

# Re-export sync modules as async-compatible (Phase 2.1)
# These work because they're called from within async Leo's context
# Future: Migrate SQLite operations to aiosqlite

# MetaLeo - in-memory only, no I/O
from metaleo import MetaLeo as AsyncMetaLeo, MetaConfig

# FlowTracker - SQLite I/O (to be migrated)
from gowiththeflow import FlowTracker as AsyncFlowTracker

# Trauma - SQLite I/O (to be migrated)
from trauma import TraumaState, run_trauma as async_run_trauma

# Overthinking - in-memory only, no I/O
from overthinking import (
    OverthinkingConfig,
    PulseSnapshot,
    run_overthinking as async_run_overthinking,
)

# Game - SQLite I/O (game.sqlite3, to be migrated)
from game import GameEngine as AsyncGameEngine, GameTurn

# School - SQLite I/O (to be migrated)
from school import School as AsyncSchool, SchoolConfig

# Dream - SQLite I/O (to be migrated)
from dream import init_dream as async_init_dream

__all__ = [
    # MetaLeo
    "AsyncMetaLeo",
    "MetaConfig",
    # FlowTracker
    "AsyncFlowTracker",
    # Trauma
    "TraumaState",
    "async_run_trauma",
    # Overthinking
    "OverthinkingConfig",
    "PulseSnapshot",
    "async_run_overthinking",
    # Game
    "AsyncGameEngine",
    "GameTurn",
    # School
    "AsyncSchool",
    "SchoolConfig",
    # Dream
    "async_init_dream",
]
