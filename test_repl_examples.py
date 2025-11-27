#!/usr/bin/env python3
"""
Quick REPL examples to verify Leo speaks naturally without bootstrap leaks.
"""

from leo import LeoField, init_db

# Create temporary Leo instance
conn = init_db()
leo = LeoField(conn)

# Test prompts for README examples
test_prompts = [
    "Hello Leo, how are you?",
    "What is resonance?",
    "Tell me about language",
    "What makes you different?",
    "How do you feel about patterns?",
]

print("=" * 60)
print("LEO REPL EXAMPLES (for README)")
print("=" * 60)

for prompt in test_prompts:
    print(f"\n> {prompt}")
    reply = leo.reply(prompt, max_tokens=60)
    print(f"Leo: {reply}")

print("\n" + "=" * 60)

conn.close()
