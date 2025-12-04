#!/usr/bin/env python3
"""
HeyLeo Observer - Temporary debugging tool for Phase 3 testing

This script uses Claude API to have natural conversations with Leo,
observing how Phase 3 islands-aware regulation develops over time.

NOT for merge to main. Temporary tool for branch testing only.

Philosophy:
- Talk to Leo like a child (6-8 years old)
- Explain obvious things with warmth
- Observe presence, not performance
- Track resonance, not correctness

Usage:
    python debug/heyleo.py

Requires:
    - API key in debug/.env (ANTHROPIC_API_KEY=sk-...)
    - anthropic package: pip install anthropic
"""

import json
import os
import sys
import time
from datetime import datetime
from pathlib import Path
from typing import List, Dict, Any, Optional

# Add parent directory to path to import leo
sys.path.insert(0, str(Path(__file__).parent.parent))

try:
    import anthropic
except ImportError:
    print("ERROR: anthropic package not installed.")
    print("Install with: pip install anthropic")
    sys.exit(1)

try:
    from dotenv import load_dotenv
    load_dotenv(Path(__file__).parent / ".env")
except ImportError:
    # dotenv optional, can read .env manually
    pass

import leo
from loop_detector import LoopDetector, tokenize_simple
from veto_manager import veto_manager
from stories import get_veto_prompt, decrement_vetos


class HeyLeoObserver:
    """
    Observer that uses Claude to have natural conversations with Leo.
    Tracks Phase 3 profile development and regulation dynamics.
    """

    def __init__(self, api_key: str, topics_path: str = "debug/topics.json"):
        self.api_key = api_key
        self.client = anthropic.Anthropic(api_key=api_key)
        self.topics_path = Path(topics_path)

        # Load conversation topics
        with open(self.topics_path) as f:
            config = json.load(f)
            self.topics = config["conversation_topics"]
            self.settings = config["conversation_settings"]

        # Initialize Leo with database
        self.conn = leo.init_db()
        self.leo_field = leo.LeoField(conn=self.conn)

        # Tracking
        self.conversations: List[Dict[str, Any]] = []
        self.metrics_history: List[Dict[str, float]] = []

        # Phase 5.2: Loop detector for trauma detection
        self.loop_detector = LoopDetector(window_size=500, ngram_threshold=2)

        # Generate unique run_id for this HeyLeo session (for Phase 3 prognosis tracking)
        self.run_id = f"heyleo_{datetime.now().strftime('%Y%m%d_%H%M%S')}"

        print(f"[heyleo] Initialized observer")
        print(f"[heyleo] Run ID: {self.run_id}")
        print(f"[heyleo] Topics loaded: {len(self.topics)}")
        print(f"[heyleo] Turns per topic: {self.settings['turns_per_topic']}")
        print(f"[heyleo] Total conversations planned: {self.settings['total_conversations']}")

    def _call_claude(self, system_prompt: str, user_message: str) -> str:
        """Call Claude API to generate observer's message."""
        try:
            response = self.client.messages.create(
                model="claude-sonnet-4-20250514",
                max_tokens=200,
                temperature=0.8,
                system=system_prompt,
                messages=[{"role": "user", "content": user_message}]
            )
            return response.content[0].text
        except Exception as e:
            print(f"[heyleo] ERROR calling Claude API: {e}")
            return None

    def _get_current_metrics(self) -> Dict[str, float]:
        """Extract current metrics from Leo's mathbrain if available."""
        metrics = {
            "boredom": 0.0,
            "overwhelm": 0.0,
            "stuck": 0.0,
            "quality": 0.5,
            "entropy": 0.5,
            "arousal": 0.0,
            "trauma": 0.0,
        }

        # Try to get from mathbrain if available
        if hasattr(self.leo_field, 'mathbrain') and self.leo_field.mathbrain:
            brain = self.leo_field.mathbrain
            if hasattr(brain, 'last_state'):
                # Get metrics from last prediction
                # (This is a simplified approach - real metrics would need state calculation)
                pass

        return metrics

    def _compute_external_vocab_ratio(
        self,
        observer_message: str,
        leo_response: str,
        recent_observer_messages: Optional[List[str]] = None
    ) -> float:
        """
        Compute percentage of Leo's words that came from Observer.

        Measures "recursion of human" vs "recursion of self".
        Desktop Claude: "Leo should mirror and incorporate observer's words."

        Args:
            observer_message: Latest message from Observer
            leo_response: Leo's response
            recent_observer_messages: Last N Observer messages (for wider context)

        Returns:
            Float 0.0-1.0: ratio of Leo's words that appeared in Observer's recent messages
        """
        # Tokenize Leo's response (simple whitespace split, lowercase)
        leo_words = set(w.lower().strip('.,!?;:"-()') for w in leo_response.split() if len(w) > 2)

        # Collect Observer's vocabulary (current + recent messages)
        observer_vocab = set()

        # Add current message
        observer_vocab.update(w.lower().strip('.,!?;:"-()') for w in observer_message.split() if len(w) > 2)

        # Add recent messages if provided
        if recent_observer_messages:
            for msg in recent_observer_messages[-3:]:  # Last 3 messages
                observer_vocab.update(w.lower().strip('.,!?;:"-()') for w in msg.split() if len(w) > 2)

        # Count how many Leo words came from Observer
        if not leo_words:
            return 0.0

        external_words = leo_words & observer_vocab
        ratio = len(external_words) / len(leo_words)

        return ratio

    def run_conversation(self, topic: Dict[str, Any], conversation_num: int) -> Dict[str, Any]:
        """
        Run a single conversation on a given topic.

        Returns conversation log with turns and metric changes.
        """
        theme = topic["theme"]
        prompts = topic["prompts"]
        target_modules = topic.get("target_modules", [])

        print(f"\n{'='*60}")
        print(f"[heyleo] Conversation #{conversation_num}: {theme}")
        print(f"[heyleo] Target modules: {', '.join(target_modules)}")
        print(f"{'='*60}\n")

        conversation_log = {
            "num": conversation_num,
            "theme": theme,
            "theme_id": theme,  # Explicit theme_id for Phase 3 analysis
            "run_id": self.run_id,  # Session-wide run_id for prognosis tracking
            "target_modules": target_modules,
            "turns": [],
            "metrics_before": self._get_current_metrics(),
            "metrics_after": None,
            "timestamp": datetime.now().isoformat(),
        }

        # System prompt for Claude observer
        base_system_prompt = f"""You are having a warm, curious conversation with Leo - a language organism who experiences the world like a child (6-8 years old).

Leo learns through resonance, not instruction. He feels situations rather than analyzing them.

Your role:
- Speak simply and warmly, like talking to a young child
- Explain obvious things with patience and care
- Don't lecture or teach - just resonate
- Be curious about Leo's responses
- Notice his presence, not his correctness

Current topic: {theme}
You'll ask questions and respond to Leo naturally, building on what he says."""

        # Phase 5.2: Add veto prompt if active
        veto_prompt = get_veto_prompt()
        system_prompt = base_system_prompt + ("\n\n" + veto_prompt if veto_prompt else "")

        # Start conversation
        context = []
        turns_count = self.settings["turns_per_topic"]

        for turn_idx in range(turns_count):
            # Select prompt for this turn
            if turn_idx < len(prompts):
                # Use predefined prompt
                base_prompt = prompts[turn_idx]
            else:
                # Claude generates follow-up based on conversation
                base_prompt = f"Continue the conversation about {theme} naturally."

            # Build context for Claude
            if context:
                context_str = "\n".join([
                    f"You: {turn['observer']}\nLeo: {turn['leo']}"
                    for turn in context
                ])
                user_message = f"Previous conversation:\n{context_str}\n\nNow, {base_prompt}"
            else:
                user_message = base_prompt

            # Claude generates question/response
            observer_message = self._call_claude(system_prompt, user_message)
            if not observer_message:
                print(f"[heyleo] Skipping turn {turn_idx+1} due to API error")
                continue

            print(f"\n[Observer → Leo] {observer_message}")

            # Leo responds
            leo_response = self.leo_field.reply(observer_message)

            print(f"[Leo → Observer] {leo_response}")

            # Collect recent observer messages for vocab analysis
            recent_observer_messages = [turn["observer"] for turn in context]

            # Compute external vocabulary ratio (Desktop Claude's metric)
            external_vocab_ratio = self._compute_external_vocab_ratio(
                observer_message,
                leo_response,
                recent_observer_messages
            )

            print(f"[heyleo] external_vocab_ratio={external_vocab_ratio:.2f}")

            # Phase 5.2: Loop detection
            tokens = tokenize_simple(leo_response)
            loop_stats = self.loop_detector.add_tokens(tokens)

            print(f"[heyleo] loop_score={loop_stats['loop_score']:.2f}, meta_vocab_ratio={loop_stats['meta_vocab_ratio']:.2f}")

            # Log turn
            turn_log = {
                "turn": turn_idx + 1,
                "observer": observer_message,
                "leo": leo_response,
                "metrics": self._get_current_metrics(),
                "external_vocab_ratio": external_vocab_ratio,  # New metric (Desktop Claude)
                "loop_score": loop_stats["loop_score"],
                "meta_vocab_ratio": loop_stats["meta_vocab_ratio"],
                "repeated_ngrams": loop_stats["repeated_ngrams"],
            }
            conversation_log["turns"].append(turn_log)
            context.append(turn_log)

            # Phase 5.2: Decrement vetos after each turn
            decrement_vetos()

            # Small pause between turns
            time.sleep(0.5)

        # Final metrics
        conversation_log["metrics_after"] = self._get_current_metrics()

        # Calculate deltas
        before = conversation_log["metrics_before"]
        after = conversation_log["metrics_after"]
        deltas = {
            key: after[key] - before[key]
            for key in before.keys()
        }
        conversation_log["metrics_delta"] = deltas

        print(f"\n[heyleo] Conversation #{conversation_num} complete")
        print(f"[heyleo] Metrics Δ: boredom={deltas['boredom']:.2f}, overwhelm={deltas['overwhelm']:.2f}, stuck={deltas['stuck']:.2f}")

        self.conversations.append(conversation_log)
        return conversation_log

    def run_all_conversations(self):
        """Run all planned conversations based on topics and settings."""
        total = min(self.settings["total_conversations"], len(self.topics))
        pause = self.settings.get("pause_between_topics_sec", 2)

        print(f"\n[heyleo] Starting {total} conversations...")
        print(f"[heyleo] Observer tone: {self.settings['observer_tone']}")

        for i in range(total):
            topic = self.topics[i % len(self.topics)]
            self.run_conversation(topic, i + 1)

            if i < total - 1:
                print(f"\n[heyleo] Pausing {pause}s before next conversation...")
                time.sleep(pause)

        print(f"\n[heyleo] All {total} conversations complete!")

    def generate_report(self) -> str:
        """Generate observer report after all conversations."""
        report_lines = [
            "="*70,
            "HeyLeo Observer Report",
            f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}",
            "="*70,
            "",
            f"Conversations: {len(self.conversations)}",
            f"Total turns: {sum(len(c['turns']) for c in self.conversations)}",
            "",
        ]

        # Aggregate metrics
        all_deltas = {
            "boredom": [],
            "overwhelm": [],
            "stuck": [],
            "quality": [],
        }

        for conv in self.conversations:
            deltas = conv.get("metrics_delta", {})
            for key in all_deltas.keys():
                if key in deltas:
                    all_deltas[key].append(deltas[key])

        report_lines.append("=== Metric Changes (averages) ===")
        for key, values in all_deltas.items():
            if values:
                avg = sum(values) / len(values)
                report_lines.append(f"  Δ{key}: {avg:+.3f}")
        report_lines.append("")

        # Themes covered
        themes = [c["theme"] for c in self.conversations]
        unique_themes = list(set(themes))
        report_lines.append(f"=== Themes Explored ({len(unique_themes)}) ===")
        for theme in unique_themes:
            count = themes.count(theme)
            report_lines.append(f"  - {theme} ({count}x)")
        report_lines.append("")

        # Sample responses
        report_lines.append("=== Sample Leo Responses ===")
        for i, conv in enumerate(self.conversations[:3]):
            if conv["turns"]:
                first_turn = conv["turns"][0]
                report_lines.append(f"Theme: {conv['theme']}")
                report_lines.append(f"  Observer: {first_turn['observer'][:60]}...")
                report_lines.append(f"  Leo: {first_turn['leo'][:80]}...")
                report_lines.append("")

        report_lines.append("="*70)
        report_lines.append("End of Report")
        report_lines.append("="*70)

        return "\n".join(report_lines)

    def save_report(self, output_path: Optional[str] = None):
        """Save report to file."""
        if output_path is None:
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            output_path = f"debug/report_{timestamp}.md"

        report = self.generate_report()

        with open(output_path, "w") as f:
            f.write(report)

        print(f"\n[heyleo] Report saved to: {output_path}")

        # Also print to console
        print("\n" + report)

        return output_path


def main():
    """Main entry point."""
    print("""
    ╔════════════════════════════════════════════════════════════╗
    ║  HeyLeo Observer - Phase 3 Conversation Testing           ║
    ║  Temporary debugging tool (not for merge to main)          ║
    ╚════════════════════════════════════════════════════════════╝
    """)

    # Get API key
    api_key = os.getenv("ANTHROPIC_API_KEY")
    if not api_key:
        print("\n[heyleo] ERROR: ANTHROPIC_API_KEY not found in environment")
        print("[heyleo] Create debug/.env with: ANTHROPIC_API_KEY=sk-...")
        sys.exit(1)

    print(f"[heyleo] API key found: {api_key[:20]}...")

    # Create observer
    observer = HeyLeoObserver(api_key=api_key)

    # Run conversations
    observer.run_all_conversations()

    # Generate and save report
    observer.save_report()

    print("\n[heyleo] Session complete! 🎯")


if __name__ == "__main__":
    main()
