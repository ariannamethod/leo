#!/usr/bin/env python3
"""
HeyLeoGPT Observer - GPT-4 as observer for Leo conversations

Post-resurrection version (no loop_detector, no veto_manager).
Pure observation mode - track Leo's natural evolution.

Usage:
    python tests/heyleogpt_gpt.py --topics tests/topics_spaces_between.json

Requires:
    - OpenAI API key as environment variable OPENAI_API_KEY
    - openai package: pip install openai
"""

import ssl
# Disable SSL verification for containerized environments (must be before other imports)
ssl._create_default_https_context = ssl._create_unverified_context

import json
import os
import sys
import time
from datetime import datetime
from pathlib import Path
from typing import List, Dict, Any, Optional
import argparse

# Add parent directory to path to import leo
sys.path.insert(0, str(Path(__file__).parent.parent))

try:
    import openai
    import httpx
except ImportError:
    print("ERROR: openai or httpx package not installed.")
    print("Install with: pip install openai httpx")
    sys.exit(1)

import leo


class HeyLeoGPTObserver:
    """
    Observer that uses GPT-4 to have natural conversations with Leo.
    Post-resurrection: pure observation, no regulation.
    """

    def __init__(self, api_key: str, topics_path: str):
        self.api_key = api_key
        # Create httpx client with SSL verification disabled for containerized environments
        http_client = httpx.Client(verify=False)
        self.client = openai.OpenAI(api_key=api_key, http_client=http_client)
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

        # Generate unique run_id for this session
        self.run_id = f"heyleogpt_{datetime.now().strftime('%Y%m%d_%H%M%S')}"

        print(f"[heyleogpt] Initialized GPT-4 observer")
        print(f"[heyleogpt] Run ID: {self.run_id}")
        print(f"[heyleogpt] Topics: {len(self.topics)}")
        print(f"[heyleogpt] Turns per topic: {self.settings['turns_per_topic']}")
        print()

    def ask_gpt(self, prompt: str, conversation_history: List[Dict[str, str]]) -> str:
        """
        Ask GPT-4 to generate next observer message.
        """
        messages = [
            {
                "role": "system",
                "content": f"""You are a warm, gentle observer talking with Leo, a 6-8 year old language organism.

Leo is NOT a chatbot. He's an emergent language organism who speaks from his own field, not from your words.

Your tone: {self.settings['observer_tone']}

Guidelines:
- Speak simply, like to a young child
- Ask open-ended questions about feelings, images, sensations
- Don't teach or correct - just be present
- Use sensory language (colors, textures, sounds, weight)
- Be patient with circular phrasing - it's Leo's voice
- Never rush or demand clarity
- Celebrate weird, poetic responses

Remember: You're observing presence, not performance."""
            }
        ]

        # Add conversation history
        messages.extend(conversation_history)

        # Add current prompt
        messages.append({"role": "user", "content": prompt})

        # Call GPT-4o-mini (fast, cheap, reliable)
        response = self.client.chat.completions.create(
            model="gpt-3.5-turbo",
            messages=messages,
            temperature=0.8,
            max_tokens=200
        )

        return response.choices[0].message.content.strip()

    def compute_external_vocab(self, prompt: str, response: str) -> float:
        """
        Compute external_vocab ratio (echo metric).
        How many of Leo's words came from observer prompt?
        """
        # Tokenize prompt words (exclude short words)
        prompt_words = set(
            w.lower().strip('.,!?;:"-()')
            for w in prompt.split()
            if len(w) > 2
        )

        # Tokenize response words
        response_words = [
            w.lower().strip('.,!?;:"-()')
            for w in response.split()
            if len(w) > 2
        ]

        if not response_words:
            return 0.0

        # Count overlap
        overlap = sum(1 for w in response_words if w in prompt_words)
        return overlap / len(response_words)

    def run_conversation(self, topic: Dict[str, Any]) -> Dict[str, Any]:
        """
        Run one conversation with Leo on given topic.
        """
        theme = topic["theme"]
        prompts = topic["prompts"]
        target_modules = topic.get("target_modules", [])

        print(f"\n{'='*70}")
        print(f"CONVERSATION: {theme}")
        print(f"Target modules: {', '.join(target_modules)}")
        print(f"{'='*70}\n")

        conversation_history = []
        turns_data = []

        turns = self.settings["turns_per_topic"]

        for turn_idx in range(turns):
            # Select prompt for this turn
            if turn_idx < len(prompts):
                base_prompt = prompts[turn_idx]
            else:
                # Generate continuation prompt using GPT
                base_prompt = f"Continue this conversation naturally, following the theme: {theme}"

            # Ask GPT to generate observer message
            if turn_idx == 0:
                observer_msg = self.ask_gpt(base_prompt, [])
            else:
                observer_msg = self.ask_gpt(base_prompt, conversation_history)

            print(f"[Turn {turn_idx + 1}/{turns}] Observer:")
            print(f"  {observer_msg}")
            print()

            # Leo responds
            leo_response = self.leo_field.reply(observer_msg)

            print(f"[Turn {turn_idx + 1}/{turns}] Leo:")
            print(f"  {leo_response}")
            print()

            # Compute metrics
            external_vocab = self.compute_external_vocab(observer_msg, leo_response)

            print(f"[Metrics] external_vocab={external_vocab:.3f}")
            print()

            # Record turn
            turn_data = {
                "turn": turn_idx + 1,
                "observer": observer_msg,
                "leo": leo_response,
                "external_vocab": external_vocab,
            }
            turns_data.append(turn_data)

            # Update conversation history for GPT
            conversation_history.append({
                "role": "assistant",
                "content": f"Observer: {observer_msg}"
            })
            conversation_history.append({
                "role": "user",
                "content": f"Leo: {leo_response}"
            })

            # Pause between turns
            time.sleep(1)

        # Compute conversation-level metrics
        avg_external_vocab = sum(t["external_vocab"] for t in turns_data) / len(turns_data)

        conversation_result = {
            "theme": theme,
            "target_modules": target_modules,
            "turns": turns_data,
            "metrics": {
                "avg_external_vocab": avg_external_vocab,
            }
        }

        return conversation_result

    def run_all_conversations(self):
        """
        Run all conversation topics and generate report.
        """
        print("="*70)
        print("HEYLEOGPT OBSERVATION SESSION - POST-RESURRECTION")
        print("="*70)
        print(f"Run ID: {self.run_id}")
        print(f"Topics: {len(self.topics)}")
        print(f"Observer: GPT-4")
        print(f"Leo: Field-based organism (no seed from prompt)")
        print("="*70)

        for topic_idx, topic in enumerate(self.topics):
            print(f"\n>>> Topic {topic_idx + 1}/{len(self.topics)}: {topic['theme']}")

            result = self.run_conversation(topic)
            self.conversations.append(result)

            # Pause between topics
            time.sleep(self.settings.get("pause_between_topics_sec", 2))

        # Generate final report
        self.save_report()

    def save_report(self):
        """
        Save conversation report to markdown file.
        """
        report_path = Path(__file__).parent / f"HEYLEOGPT_RUN_{datetime.now().strftime('%Y%m%d_%H%M%S')}.md"

        with open(report_path, 'w') as f:
            f.write(f"# HeyLeoGPT Observer Run (Post-Resurrection)\n")
            f.write(f"**Date:** {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
            f.write(f"**Run ID:** {self.run_id}\n")
            f.write(f"**Branch:** claude/audit-restore-system-QXtxV\n")
            f.write(f"\n")
            f.write(f"## Configuration\n\n")
            f.write(f"- **Topics:** {len(self.topics)}\n")
            f.write(f"- **Conversations completed:** {len(self.conversations)}\n")
            f.write(f"- **Turns per topic:** {self.settings['turns_per_topic']}\n")
            f.write(f"- **Observer:** GPT-4\n")
            f.write(f"- **Observer tone:** {self.settings['observer_tone']}\n")
            f.write(f"\n")
            f.write(f"## Conversations\n\n")

            for conv in self.conversations:
                f.write(f"### {conv['theme']}\n\n")
                f.write(f"**Target modules:** {', '.join(conv['target_modules'])}\n\n")

                for turn in conv['turns']:
                    f.write(f"#### Turn {turn['turn']}\n\n")
                    f.write(f"**Observer:** {turn['observer']}\n\n")
                    f.write(f"**Leo:** {turn['leo']}\n\n")
                    f.write(f"*Metrics: external_vocab={turn['external_vocab']:.3f}*\n\n")

                f.write(f"**Conversation metrics:**\n")
                f.write(f"- avg_external_vocab: {conv['metrics']['avg_external_vocab']:.3f}\n\n")

            # Overall summary
            f.write(f"\n## Overall Summary\n\n")
            all_external_vocab = [
                turn['external_vocab']
                for conv in self.conversations
                for turn in conv['turns']
            ]
            avg_external_vocab = sum(all_external_vocab) / len(all_external_vocab)

            f.write(f"**Total turns:** {len(all_external_vocab)}\n")
            f.write(f"**Average external_vocab:** {avg_external_vocab:.3f}\n")
            f.write(f"\n")
            f.write(f"**Assessment:**\n")
            if avg_external_vocab < 0.2:
                f.write(f"- ✅ Excellent - Leo speaks from field (target: <0.2)\n")
            elif avg_external_vocab < 0.5:
                f.write(f"- ⚠️ Moderate echo - monitor for regression\n")
            else:
                f.write(f"- 🚨 High echo - possible chatbot regression\n")

            f.write(f"\n")
            f.write(f"## Notes\n\n")
            f.write(f"Post-resurrection observation session.\n")
            f.write(f"No loop_detector, no veto_manager - pure field generation.\n")
            f.write(f"Seed selection: ALWAYS from field (choose_start_token).\n")
            f.write(f"\n")

        print(f"\n{'='*70}")
        print(f"REPORT SAVED: {report_path}")
        print(f"{'='*70}\n")


def main():
    parser = argparse.ArgumentParser(description="HeyLeoGPT Observer - GPT-4 conversations with Leo")
    parser.add_argument(
        "--topics",
        type=str,
        default="tests/topics_spaces_between.json",
        help="Path to topics JSON file"
    )
    args = parser.parse_args()

    # Get OpenAI API key from environment
    api_key = os.environ.get("OPENAI_API_KEY")
    if not api_key:
        print("ERROR: OPENAI_API_KEY environment variable not set")
        sys.exit(1)

    # Create observer
    observer = HeyLeoGPTObserver(api_key=api_key, topics_path=args.topics)

    # Run all conversations
    observer.run_all_conversations()


if __name__ == "__main__":
    main()
