#!/usr/bin/env python3
"""
async_mathbrain.py — Async wrapper for MathBrain (body perception module)

Inherits from sync MathBrain and adds async file I/O for state persistence.
"""

from __future__ import annotations

import json
from pathlib import Path
from typing import Optional

# Async file I/O
import aiofiles

# Import sync MathBrain (we inherit from it)
from mathbrain import MathBrain, MathState


class AsyncMathBrain(MathBrain):
    """
    Async version of MathBrain.

    Inherits all logic from sync Math Brain, but overrides file I/O methods
    to use aiofiles for non-blocking persistence.

    Usage:
        brain = AsyncMathBrain(field, hidden_dim=16, lr=0.01, state_path=...)
        await brain.async_init()  # Load state
        quality = brain.predict(state)  # Sync prediction (in-memory)
        brain.train(state, quality)  # Sync training (in-memory)
        await brain.async_save_state()  # Async save
    """

    def __init__(
        self,
        field: any,  # AsyncLeoField
        hidden_dim: int = 16,
        lr: float = 0.01,
        state_path: Optional[Path] = None,
    ):
        """
        Initialize async MathBrain.

        Args:
            field: AsyncLeoField instance
            hidden_dim: Hidden layer dimension
            lr: Learning rate
            state_path: Path to save/load weights (JSON file)
        """
        # Call parent __init__ (creates MLP, sets up structure)
        super().__init__(field, hidden_dim=hidden_dim, lr=lr, state_path=state_path)

        # NOTE: We do NOT call _load_state() in __init__
        # because it's sync. Instead, call async_init() after creation.

    async def async_init(self) -> None:
        """
        Async initialization - loads state from file.

        Call this after __init__:
            brain = AsyncMathBrain(...)
            await brain.async_init()
        """
        await self.async_load_state()

    async def async_save_state(self) -> None:
        """Save weights to JSON (async)."""
        try:
            # Ensure directory exists (sync - fast operation)
            self.state_path.parent.mkdir(parents=True, exist_ok=True)

            # Extract weights as nested lists
            weights = {
                "in_dim": self.in_dim,
                "hidden_dim": self.hidden_dim,
                "observations": self.observations,
                "running_loss": self.running_loss,
                "parameters": [p.data for p in self.mlp.parameters()],
            }

            # Async write to JSON
            async with aiofiles.open(self.state_path, 'w') as f:
                await f.write(json.dumps(weights, indent=2))

        except Exception:
            # Silent fail — do not break Leo
            pass

    async def async_load_state(self) -> None:
        """Load weights from JSON if available (async)."""
        try:
            # Check if file exists (sync - fast operation)
            if not self.state_path.exists():
                return

            # Async read from JSON
            async with aiofiles.open(self.state_path, 'r') as f:
                content = await f.read()
                data = json.loads(content)

            # Validate dimensions match
            if data["in_dim"] != self.in_dim or data["hidden_dim"] != self.hidden_dim:
                # Dimension mismatch — start fresh
                return

            # Restore weights
            params = self.mlp.parameters()
            saved_params = data["parameters"]
            if len(params) != len(saved_params):
                return

            for p, val in zip(params, saved_params):
                p.data = val

            # Restore training stats
            self.observations = data.get("observations", 0)
            self.running_loss = data.get("running_loss", 0.0)

        except Exception:
            # Silent fail — start fresh
            pass

    # Override sync _save_state to call async version
    # (This is called by train() method)
    def _save_state(self) -> None:
        """
        Sync wrapper - does nothing.

        User must call await brain.async_save_state() manually
        after training, or integrate into async reply() flow.
        """
        # Do nothing - async saving handled separately
        pass

    def _load_state(self) -> None:
        """
        Sync wrapper - does nothing.

        State loading happens in async_init().
        """
        # Do nothing - async loading handled in async_init()
        pass


__all__ = ["AsyncMathBrain"]
