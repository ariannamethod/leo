#!/usr/bin/env python3
"""
Async HeyLeo Observer - Testing async Leo implementation

This is a minimal async version of heyleogpt.py for testing async Leo.
Uses same observation methodology but with async/await.

Usage:
    python tests/heyleogpt_async.py <api_key> [topics_path]
"""

import asyncio
import json
import sys
import time
from datetime import datetime
from pathlib import Path
from typing import List, Dict, Any, Optional

# Add parent directory to path
sys.path.insert(0, str(Path(__file__).parent.parent))

try:
    import openai
except ImportError:
    print("ERROR: openai package not installed.")
    print("Install with: pip install openai")
    sys.exit(1)

from async_leo import AsyncLeoField, ASYNC_DB_PATH


class AsyncHeyLeoObserver:
    """
    Async observer for Leo using Claude API.
    Tests async Leo implementation with real conversations.
    """

    def __init__(self, api_key: str, topics_path: str = "tests/topics_paradoxes.json"):
        self.api_key = api_key
        self.client = openai.OpenAI(api_key=api_key)
        self.topics_path = Path(topics_path)

        # Load conversation topics
        with open(self.topics_path) as f:
            config = json.load(f)
            self.topics = config["conversation_topics"]
            self.settings = config.get("conversation_settings", {
                "turns_per_topic": 4,
                "total_conversations": len(config["conversation_topics"]),
            })

        # Async Leo field (will be initialized in async_init)
        self.leo_field: Optional[AsyncLeoField] = None

        # Tracking
        self.conversations: List[Dict[str, Any]] = []

        # Generate unique run_id
        self.run_id = f"ASYNC_HEYLEOGPT_RUN_{datetime.now().strftime('%Y%m%d_%H%M%S')}"

        print(f"[async-heyleo] Initialized async observer")
        print(f"[async-heyleo] Run ID: {self.run_id}")
        print(f"[async-heyleo] Topics loaded: {len(self.topics)}")
        print(f"[async-heyleo] Turns per topic: {self.settings['turns_per_topic']}")

    async def async_init(self):
        """Initialize async Leo field."""
        # Use sync leo.sqlite3 database for fair comparison
        from leo import DB_PATH
        self.leo_field = AsyncLeoField(DB_PATH)
        await self.leo_field.async_init()
        print(f"[async-heyleo] AsyncLeoField initialized")
        print(f"[async-heyleo] Vocab size: {len(self.leo_field.vocab)}")

    def _call_gpt(self, system_prompt: str, user_message: str) -> str:
        """Call OpenAI GPT API to generate observer's message."""
        try:
            response = self.client.chat.completions.create(
                model="gpt-4o",  # GPT-5 equivalent, no rate limits
                max_tokens=200,
                temperature=0.8,
                messages=[
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": user_message}
                ]
            )
            return response.choices[0].message.content
        except Exception as e:
            print(f"[async-heyleo] ERROR calling GPT API: {e}")
            return None

    def _compute_external_vocab_ratio(
        self,
        observer_message: str,
        leo_response: str,
        recent_observer_messages: Optional[List[str]] = None
    ) -> float:
        """
        Compute percentage of Leo's words that came from Observer.
        Measures "recursion of human" vs "recursion of self".
        """
        # Tokenize Leo's response
        leo_words = set(w.lower().strip('.,!?;:"-()') for w in leo_response.split() if len(w) > 2)

        # Collect Observer's vocabulary
        observer_vocab = set()

        # Add current message
        observer_vocab.update(w.lower().strip('.,!?;:"-()') for w in observer_message.split() if len(w) > 2)

        # Add recent messages if provided
        if recent_observer_messages:
            for msg in recent_observer_messages:
                observer_vocab.update(w.lower().strip('.,!?;:"-()') for w in msg.split() if len(w) > 2)

        # Compute overlap
        if not leo_words:
            return 0.0

        external_words = leo_words & observer_vocab
        return len(external_words) / len(leo_words)

    async def run_conversation(self, topic: str, turns: int = 4) -> Dict[str, Any]:
        """Run a single conversation about a topic (async)."""
        print(f"\n[async-heyleo] 🎯 Topic: {topic}")
        print("-" * 60)

        conversation_record = {
            "topic": topic,
            "turns": [],
            "started_at": datetime.now().isoformat(),
        }

        # System prompt for Claude (observer)
        system_prompt = f"""You are a curious, gentle observer talking to Leo, a tiny language organism.

Leo is learning to speak through resonance - he has no pretrained weights, just a small seed and what you tell him.

Talk to Leo like a child (6-8 years old):
- Use simple, warm language
- Be curious about his responses
- Don't lecture or explain too much
- Let silences be okay
- Ask one thing at a time

Current topic: {topic}

Be natural, brief (1-2 sentences), and present."""

        recent_observer_messages: List[str] = []

        for turn_num in range(turns):
            print(f"\n  Turn {turn_num + 1}/{turns}")

            # Generate observer's message
            context_msg = f"Continue the conversation about: {topic}\n\nPrevious messages: {recent_observer_messages[-2:] if recent_observer_messages else 'None yet'}"

            observer_message = self._call_gpt(system_prompt, context_msg)
            if not observer_message:
                print(f"  [ERROR] Failed to generate observer message")
                break

            print(f"  Observer: {observer_message}")

            # Leo replies (ASYNC!)
            try:
                leo_response = await self.leo_field.reply(
                    prompt=observer_message,
                    max_tokens=80,
                    temperature=1.0,
                )
            except Exception as e:
                print(f"  [ERROR] Leo failed to reply: {e}")
                leo_response = "..."

            print(f"  Leo: {leo_response}")

            # Compute external vocab ratio
            external_vocab = self._compute_external_vocab_ratio(
                observer_message,
                leo_response,
                recent_observer_messages[-3:] if len(recent_observer_messages) > 0 else None
            )

            print(f"  [external_vocab={external_vocab:.3f}]")

            # Determine if optimal (<0.2)
            is_optimal = external_vocab < 0.2
            status = "✓ OPTIMAL" if is_optimal else f"  {external_vocab:.3f}"
            print(f"  {status}")

            # Record turn
            conversation_record["turns"].append({
                "turn": turn_num + 1,
                "observer": observer_message,
                "leo": leo_response,
                "external_vocab": external_vocab,
                "is_optimal": is_optimal,
            })

            recent_observer_messages.append(observer_message)

            # Small delay between turns
            await asyncio.sleep(0.5)

        # Compute averages
        external_vocab_scores = [t["external_vocab"] for t in conversation_record["turns"]]
        conversation_record["avg_external_vocab"] = sum(external_vocab_scores) / len(external_vocab_scores) if external_vocab_scores else 0.0
        conversation_record["optimal_turns"] = sum(1 for t in conversation_record["turns"] if t["is_optimal"])
        conversation_record["completed_at"] = datetime.now().isoformat()

        print(f"\n[async-heyleo] Topic complete!")
        print(f"  Avg external_vocab: {conversation_record['avg_external_vocab']:.3f}")
        print(f"  Optimal turns: {conversation_record['optimal_turns']}/{len(conversation_record['turns'])}")

        return conversation_record

    async def run_all_topics(self) -> Dict[str, Any]:
        """Run conversations on all topics (async)."""
        print("\n" + "=" * 60)
        print(f"🔬 ASYNC LEO OBSERVATION RUN")
        print(f"Run ID: {self.run_id}")
        print("=" * 60)

        run_start = time.time()

        for i, topic in enumerate(self.topics[:self.settings["total_conversations"]], 1):
            print(f"\n[{i}/{len(self.topics)}]")
            conversation = await self.run_conversation(
                topic=topic,
                turns=self.settings["turns_per_topic"]
            )
            self.conversations.append(conversation)

        run_end = time.time()
        run_duration = run_end - run_start

        # Compute overall metrics
        all_external_vocab = []
        for conv in self.conversations:
            all_external_vocab.extend([t["external_vocab"] for t in conv["turns"]])

        overall_metrics = {
            "run_id": self.run_id,
            "total_topics": len(self.conversations),
            "total_turns": len(all_external_vocab),
            "avg_external_vocab": sum(all_external_vocab) / len(all_external_vocab) if all_external_vocab else 0.0,
            "best_external_vocab": min(all_external_vocab) if all_external_vocab else 1.0,
            "worst_external_vocab": max(all_external_vocab) if all_external_vocab else 1.0,
            "optimal_turns": sum(1 for v in all_external_vocab if v < 0.2),
            "optimal_percentage": (sum(1 for v in all_external_vocab if v < 0.2) / len(all_external_vocab) * 100) if all_external_vocab else 0.0,
            "duration_seconds": run_duration,
        }

        # Print summary
        print("\n" + "=" * 60)
        print("📊 ASYNC LEO OBSERVATION SUMMARY")
        print("=" * 60)
        print(f"Run ID: {overall_metrics['run_id']}")
        print(f"Total topics: {overall_metrics['total_topics']}")
        print(f"Total turns: {overall_metrics['total_turns']}")
        print(f"Avg external_vocab: {overall_metrics['avg_external_vocab']:.3f}")
        print(f"Best turn: {overall_metrics['best_external_vocab']:.3f}")
        print(f"Worst turn: {overall_metrics['worst_external_vocab']:.3f}")
        print(f"Optimal turns (<0.2): {overall_metrics['optimal_turns']}/{overall_metrics['total_turns']} ({overall_metrics['optimal_percentage']:.1f}%)")
        print(f"Duration: {overall_metrics['duration_seconds']:.1f}s")
        print("=" * 60)

        # Save to file
        output_file = Path("tests") / f"{self.run_id}.md"
        self._save_report(output_file, overall_metrics)

        print(f"\n✅ Report saved: {output_file}")

        return overall_metrics

    def _save_report(self, output_path: Path, metrics: Dict[str, Any]):
        """Save observation report to markdown file."""
        with open(output_path, "w") as f:
            f.write(f"# Async Leo Observation Run\n\n")
            f.write(f"**Run ID:** {metrics['run_id']}\n")
            f.write(f"**Date:** {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
            f.write(f"**Type:** ASYNC LEO (Phase 1)\n\n")

            f.write("## Summary\n\n")
            f.write(f"- **Topics:** {metrics['total_topics']}\n")
            f.write(f"- **Total turns:** {metrics['total_turns']}\n")
            f.write(f"- **Avg external_vocab:** {metrics['avg_external_vocab']:.3f}\n")
            f.write(f"- **Best turn:** {metrics['best_external_vocab']:.3f}\n")
            f.write(f"- **Worst turn:** {metrics['worst_external_vocab']:.3f}\n")
            f.write(f"- **Optimal turns (<0.2):** {metrics['optimal_turns']}/{metrics['total_turns']} ({metrics['optimal_percentage']:.1f}%)\n")
            f.write(f"- **Duration:** {metrics['duration_seconds']:.1f}s\n\n")

            f.write("## Conversations\n\n")
            for i, conv in enumerate(self.conversations, 1):
                f.write(f"### {i}. {conv['topic']}\n\n")
                f.write(f"**Avg external_vocab:** {conv['avg_external_vocab']:.3f}\n\n")

                for turn in conv["turns"]:
                    status = "✓" if turn["is_optimal"] else f"{turn['external_vocab']:.3f}"
                    f.write(f"**Turn {turn['turn']}** [{status}]\n\n")
                    f.write(f"Observer: {turn['observer']}\n\n")
                    f.write(f"Leo: {turn['leo']}\n\n")
                    f.write(f"*external_vocab={turn['external_vocab']:.3f}*\n\n")
                    f.write("---\n\n")


async def main():
    """Main async entry point."""
    if len(sys.argv) < 2:
        print("Usage: python tests/heyleogpt_async.py <api_key> [topics_path]")
        sys.exit(1)

    api_key = sys.argv[1]
    topics_path = sys.argv[2] if len(sys.argv) > 2 else "tests/topics_paradoxes.json"

    # Create observer
    observer = AsyncHeyLeoObserver(api_key, topics_path)

    # Initialize async Leo
    await observer.async_init()

    # Run all topics
    metrics = await observer.run_all_topics()

    print("\n🎉 Async Leo observation complete!")


if __name__ == "__main__":
    asyncio.run(main())
