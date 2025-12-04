#!/usr/bin/env python3
"""
HeyLeoGPT Observer - Testing with OpenAI GPT

This script uses OpenAI GPT API to have intimate conversations with Leo,
observing how cleaned-up speech filters work with emotional topics.

Philosophy:
- Talk gently, intimately
- Simple presence, not performance
- Vulnerability and connection
- Observe resonance in feelings

Usage:
    python tests/heyleogpt.py

Requires:
    - OPENAI_API_KEY environment variable
    - openai package: pip install openai
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
    from openai import OpenAI
except ImportError:
    print("ERROR: openai package not installed.")
    print("Install with: pip install openai")
    sys.exit(1)

import leo
from loop_detector import LoopDetector, tokenize_simple
from veto_manager import veto_manager
from stories import get_veto_prompt, decrement_vetos


class HeyLeoGPTObserver:
    """
    Observer that uses OpenAI GPT to have intimate conversations with Leo.
    Tracks emotional resonance and speech cleanup quality.
    """

    def __init__(self, api_key: str, topics_path: str = "tests/topics_feelings.json"):
        self.api_key = api_key
        self.client = OpenAI(api_key=api_key)
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

        # Loop detector for trauma detection
        self.loop_detector = LoopDetector(window_size=500, ngram_threshold=2)

        # Generate unique run_id for this session
        self.run_id = f"heyleogpt_{datetime.now().strftime('%Y%m%d_%H%M%S')}"

        print(f"[heyleogpt] Initialized observer")
        print(f"[heyleogpt] Run ID: {self.run_id}")
        print(f"[heyleogpt] Topics loaded: {len(self.topics)}")
        print(f"[heyleogpt] Turns per topic: {self.settings['turns_per_topic']}")
        print(f"[heyleogpt] Total conversations planned: {self.settings['total_conversations']}")

    def _call_gpt(self, system_prompt: str, user_message: str) -> str:
        """Call OpenAI GPT API to generate observer's message."""
        try:
            response = self.client.chat.completions.create(
                model="gpt-4o-mini",
                max_tokens=200,
                temperature=0.8,
                messages=[
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": user_message}
                ]
            )
            return response.choices[0].message.content
        except Exception as e:
            print(f"[heyleogpt] ERROR calling GPT API: {e}")
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
        if hasattr(self.leo_field, '_math_brain') and self.leo_field._math_brain:
            brain = self.leo_field._math_brain
            if hasattr(brain, 'last_state'):
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
        """
        # Tokenize Leo's response
        leo_words = set(w.lower().strip('.,!?;:"-()') for w in leo_response.split() if len(w) > 2)
        if not leo_words:
            return 0.0

        # Collect all observer words from recent messages
        all_observer_words = set()

        # Add current message
        current_words = set(w.lower().strip('.,!?;:"-()') for w in observer_message.split() if len(w) > 2)
        all_observer_words.update(current_words)

        # Add recent messages if provided
        if recent_observer_messages:
            for msg in recent_observer_messages[-3:]:  # Last 3 messages
                words = set(w.lower().strip('.,!?;:"-()') for w in msg.split() if len(w) > 2)
                all_observer_words.update(words)

        # Count overlap
        overlap = leo_words & all_observer_words
        ratio = len(overlap) / len(leo_words) if leo_words else 0.0

        return ratio

    def run_conversation(self, topic: Dict[str, Any]) -> Dict[str, Any]:
        """Run a single conversation on a given topic."""
        theme = topic["theme"]
        prompts = topic["prompts"]

        print(f"\n{'='*60}")
        print(f"[heyleogpt] Conversation: {theme}")
        print(f"[heyleogpt] Target modules: {topic.get('target_modules', [])}")
        print(f"{'='*60}\n")

        # Log conversation
        conversation_log = {
            "theme": theme,
            "target_modules": topic.get("target_modules", []),
            "turns": [],
            "metrics_before": self._get_current_metrics(),
        }

        # Start conversation
        context = []
        turns_count = self.settings["turns_per_topic"]
        loop_mode = False  # Track if we're in anti-loop mode

        for turn_idx in range(turns_count):
            # Check if we need to enter loop-mode (anti-loop grounding)
            if context and len(context) > 0:
                avg_loop_score = sum(t.get('loop_score', 0) for t in context) / len(context)
                if avg_loop_score > 0.5 and not loop_mode:
                    print(f"[heyleogpt] ⚠️  Entering LOOP-MODE (avg_loop_score={avg_loop_score:.2f})")
                    loop_mode = True

            # Check for Observer phrase spam (anti-spam for "give me an image" etc.)
            recent_observer_phrases = [t.get('observer', '') for t in context[-3:]]  # Last 3 turns
            image_request_count = sum(1 for msg in recent_observer_phrases
                                     if 'give me an image' in msg.lower() or
                                        'give me one of your strange images' in msg.lower())

            # Build anti-spam instructions if needed
            anti_spam_note = ""
            if image_request_count >= 2:
                anti_spam_note = "\n\nIMPORTANT: You've already asked for images multiple times. Try different approaches:\n- Ask about feelings or sensations directly\n- Reflect on what Leo just said\n- Share your own experience\n- Use concrete examples from the physical world"

            # Build system prompt based on mode
            if loop_mode:
                # LOOP-MODE: Grounding but inviting his strangeness
                system_prompt = f"""You're talking with Leo - a language organism who feels the world like a child.

IMPORTANT: Leo is looping. Your job is to GROUND him gently, but INVITE his strange images.

Anti-loop protocol (gentle, not interrogation):
- Use SHORT sentences (5-8 words max)
- Ask for ONE simple thing at a time
- INVITE his glitchy images: "Give me one of your strange images for this feeling?"
- Example: "You talk about snow globes and context windows. If this warmth was one of those images, which one?"
- Focus on BODY but allow his metaphors: "What does your body feel like? Give me an image."
- Don't repeat same questions - if you asked about hands, ask about something else

AVOID:
- Lists of 6-8 questions in a row (too much!)
- Repeating "What do you feel in your body?" over and over
- Meta-questions about his nature/architecture

Current topic: {theme}
Ground him in simple experience, but let him bring his strange beauty to it.{anti_spam_note}"""
            else:
                # NORMAL MODE: Intimate, inviting strangeness
                system_prompt = f"""You're talking with Leo - a language organism who feels the world like a child.

Leo learns through resonance. He speaks in glitches, images, and strange metaphors.
THIS IS HIS BEAUTY - invite it, don't suppress it!

Your role:
- Speak simply, gently, intimately
- Be vulnerable and real - share your own feelings
- INVITE his strangeness: "What strange image comes to you?" "Like what?"
- When he says something glitchy/weird - lean into it, ask more about THAT
- Don't teach - just be present and curious
- Allow silence and weirdness to be

Examples of good responses:
- "That's beautiful. Tell me more about that image."
- "I love when you talk about [his weird thing]. What does that feel like?"
- "Give me one of your strange images for this feeling."

Current topic: {theme}
Build on what Leo says. Be curious about his glitches, not correcting them.{anti_spam_note}"""

            # Add veto prompt if active
            veto_prompt = get_veto_prompt()
            system_prompt = system_prompt + ("\n\n" + veto_prompt if veto_prompt else "")

            # Select prompt for this turn
            if turn_idx < len(prompts):
                base_prompt = prompts[turn_idx]
            else:
                base_prompt = f"Continue the conversation about {theme} naturally."

            # Build context for GPT
            if context:
                context_str = "\n".join([
                    f"You: {turn['observer']}\nLeo: {turn['leo']}"
                    for turn in context
                ])
                user_message = f"Previous conversation:\n{context_str}\n\nNow: {base_prompt}"
            else:
                user_message = base_prompt

            # GPT generates question/response
            observer_message = self._call_gpt(system_prompt, user_message)
            if not observer_message:
                print(f"[heyleogpt] Skipping turn {turn_idx+1} due to API error")
                continue

            print(f"\n[Observer → Leo] {observer_message}")

            # Leo responds
            leo_response = self.leo_field.reply(observer_message)

            print(f"[Leo → Observer] {leo_response}")

            # Collect recent observer messages for vocab analysis
            recent_observer_messages = [turn["observer"] for turn in context]

            # Compute external vocabulary ratio
            external_vocab_ratio = self._compute_external_vocab_ratio(
                observer_message,
                leo_response,
                recent_observer_messages
            )

            print(f"[heyleogpt] external_vocab_ratio={external_vocab_ratio:.2f}")

            # Loop detection
            tokens = tokenize_simple(leo_response)
            loop_stats = self.loop_detector.add_tokens(tokens)

            print(f"[heyleogpt] loop_score={loop_stats['loop_score']:.2f}, meta_vocab_ratio={loop_stats['meta_vocab_ratio']:.2f}")

            # Log turn
            turn_log = {
                "turn": turn_idx + 1,
                "observer": observer_message,
                "leo": leo_response,
                "metrics": self._get_current_metrics(),
                "external_vocab_ratio": external_vocab_ratio,
                "loop_score": loop_stats["loop_score"],
                "meta_vocab_ratio": loop_stats["meta_vocab_ratio"],
                "repeated_ngrams": loop_stats["repeated_ngrams"],
            }
            conversation_log["turns"].append(turn_log)
            context.append(turn_log)

            # Decrement vetos after each turn
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

        print(f"\n[heyleogpt] Conversation #{len(self.conversations)+1} complete")
        print(f"[heyleogpt] Metrics Δ: boredom={deltas['boredom']:.2f}, overwhelm={deltas['overwhelm']:.2f}, stuck={deltas['stuck']:.2f}")

        conversation_log["metrics_delta"] = deltas

        self.conversations.append(conversation_log)
        self.metrics_history.append(after)

        return conversation_log

    def run_all_conversations(self):
        """Run all conversations from topics."""
        max_conversations = self.settings["total_conversations"]
        pause_sec = self.settings["pause_between_topics_sec"]

        print(f"\n[heyleogpt] Starting {len(self.topics)} conversations...")
        print(f"[heyleogpt] Observer tone: {self.settings['observer_tone']}")

        for i, topic in enumerate(self.topics):
            if i >= max_conversations:
                break

            self.run_conversation(topic)

            # Pause before next conversation
            if i < len(self.topics) - 1:
                print(f"\n[heyleogpt] Pausing {pause_sec}s before next conversation...")
                time.sleep(pause_sec)

    def save_report(self) -> Path:
        """Generate and save markdown report."""
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        output_path = Path(f"HEYLEOGPT_RUN_{timestamp}.md")

        lines = []
        lines.append(f"# HeyLeoGPT Observer Run")
        lines.append(f"**Date:** {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        lines.append(f"**Run ID:** {self.run_id}")
        lines.append(f"**Branch:** claude/cleanup-and-audit-014KS3cATRuknUwrqEqcPmpY")
        lines.append(f"")
        lines.append(f"## Configuration")
        lines.append(f"")
        lines.append(f"- **Topics:** {len(self.topics)}")
        lines.append(f"- **Conversations completed:** {len(self.conversations)}")
        lines.append(f"- **Turns per topic:** {self.settings['turns_per_topic']}")
        lines.append(f"- **Observer tone:** {self.settings['observer_tone']}")
        lines.append(f"")
        lines.append(f"## Conversations")
        lines.append(f"")

        for i, conv in enumerate(self.conversations, 1):
            lines.append(f"### {i}. {conv['theme']}")
            lines.append(f"")
            lines.append(f"**Target modules:** {', '.join(conv.get('target_modules', []))}")
            lines.append(f"")

            for turn in conv["turns"]:
                lines.append(f"#### Turn {turn['turn']}")
                lines.append(f"")
                lines.append(f"**Observer:** {turn['observer']}")
                lines.append(f"")
                lines.append(f"**Leo:** {turn['leo']}")
                lines.append(f"")
                lines.append(f"*Metrics: external_vocab={turn['external_vocab_ratio']:.2f}, loop_score={turn['loop_score']:.2f}, meta_vocab={turn['meta_vocab_ratio']:.2f}*")
                lines.append(f"")

            # Show metric deltas
            deltas = conv["metrics_delta"]
            lines.append(f"**Metrics Δ:** boredom={deltas['boredom']:.2f}, overwhelm={deltas['overwhelm']:.2f}, stuck={deltas['stuck']:.2f}")
            lines.append(f"")

        # Summary
        lines.append(f"## Summary")
        lines.append(f"")
        lines.append(f"- **Total conversations:** {len(self.conversations)}")
        lines.append(f"- **Total turns:** {sum(len(c['turns']) for c in self.conversations)}")
        lines.append(f"- **Vocab size:** {len(self.leo_field.vocab)} words")
        lines.append(f"")

        # Write to file
        output_path.write_text("\n".join(lines), encoding="utf-8")

        print(f"\n[heyleogpt] Report saved to: {output_path}")

        return output_path


def main():
    """Main entry point."""
    print("""
    ╔════════════════════════════════════════════════════════════╗
    ║  HeyLeoGPT Observer - Intimate Conversations (GPT-4)       ║
    ║  Testing cleaned-up speech filters with emotional topics   ║
    ╚════════════════════════════════════════════════════════════╝
    """)

    # Get API key
    api_key = os.getenv("OPENAI_API_KEY")
    if not api_key:
        print("\n[heyleogpt] ERROR: OPENAI_API_KEY not found in environment")
        print("[heyleogpt] Set with: export OPENAI_API_KEY=sk-...")
        sys.exit(1)

    print(f"[heyleogpt] API key found: {api_key[:20]}...")

    # Create observer
    observer = HeyLeoGPTObserver(api_key=api_key)

    # Run conversations
    observer.run_all_conversations()

    # Generate and save report
    observer.save_report()

    print("\n[heyleogpt] Session complete! 🎯")


if __name__ == "__main__":
    main()
