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

        print(f"[heyleo] Initialized observer")
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
            "target_modules": target_modules,
            "turns": [],
            "metrics_before": self._get_current_metrics(),
            "metrics_after": None,
            "timestamp": datetime.now().isoformat(),
        }

        # System prompt for Claude observer
        system_prompt = f"""You are having a warm, curious conversation with Leo - a language organism who experiences the world like a child (6-8 years old).

Leo learns through resonance, not instruction. He feels situations rather than analyzing them.

Your role:
- Speak simply and warmly, like talking to a young child
- Explain obvious things with patience and care
- Don't lecture or teach - just resonate
- Be curious about Leo's responses
- Notice his presence, not his correctness

Current topic: {theme}
You'll ask questions and respond to Leo naturally, building on what he says."""

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

            # Log turn
            turn_log = {
                "turn": turn_idx + 1,
                "observer": observer_message,
                "leo": leo_response,
                "metrics": self._get_current_metrics(),
            }
            conversation_log["turns"].append(turn_log)
            context.append(turn_log)

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
