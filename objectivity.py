import re
import requests
from urllib.parse import quote
from typing import List, Optional

USER_AGENT = "subjectivity/1.0 (+github.com/ariannamethod/subjectivity)"

def _looks_like_glossary(text: str) -> bool:
    """Detect glossary/definition-style text to filter out."""
    text_padded = " " + text.lower() + " "
    
    # Definition markers
    definition_markers = [
        " is a ", " is an ", " is the ", " was a ", " was an ", " are a ", " are an ",
        "notable people", "notable persons", "family name", "given name", "surname",
        "capital is", "is the capital", "capital of", "programming language",
        "population", "metropolitan areas", "disambiguation", "may refer to",
        "born in", "died in", "known for", "famous for", "best known",
    ]
    
    if any(marker in text_padded for marker in definition_markers):
        return True
        
    # Title-like patterns (mostly capitalized short phrases)
    words = re.findall(r"\b\w+\b", text)
    if 1 <= len(words) <= 4:
        caps_count = sum(1 for w in words if w[0].isupper())
        if caps_count >= len(words) - 1:
            # Avoid verb-less titles
            if not any(w.lower() in {"is", "are", "was", "were", "has", "have", "do", "does", "can", "will"} for w in words):
                return True
                
    return False

def _looks_conversational(text: str) -> bool:
    """Check if text sounds like natural conversation."""
    # Conversational markers
    conversational_words = {
        "you", "i", "we", "they", "how", "what", "why", "really", "actually",
        "maybe", "probably", "think", "feel", "like", "love", "hate", "want",
        "need", "should", "could", "would", "might", "seems", "sounds"
    }
    
    words = [w.lower() for w in re.findall(r"\b\w+\b", text)]
    conversational_count = sum(1 for w in words if w in conversational_words)
    
    # At least 1 conversational word in every 6 words
    if len(words) > 0 and conversational_count / len(words) >= 0.15:
        return True
        
    # Question forms
    if any(text.lower().startswith(q) for q in ["how ", "what ", "why ", "when ", "where "]):
        return True
        
    # Personal pronouns + verbs
    if any(w in words for w in ["you", "i"]) and any(w in words for w in ["are", "do", "can", "will", "should"]):
        return True
        
    return False

def _ddg_json(query: str) -> List[str]:
    """Fetch conversational snippets from DuckDuckGo API."""
    url = f"https://api.duckduckgo.com/?q={quote(query)}&format=json&no_html=1&no_redirect=1"
    snippets: List[str] = []
    
    try:
        response = requests.get(url, headers={"User-Agent": USER_AGENT}, timeout=4)
        if response.status_code != 200:
            return snippets
            
        data = response.json()
    except Exception:
        return snippets

    def add_snippet(text: Optional[str]):
        if not text:
            return
            
        # Clean up text
        text = re.sub(r"\s+", " ", text).strip()
        if len(text) < 10:  # Too short
            return
            
        # Filter out non-conversational content
        if _looks_like_glossary(text):
            return
            
        # Remove URLs and technical jargon
        if re.search(r"https?://", text):
            return
        if re.search(r"\b\d{4}-\d{2}-\d{2}\b", text):  # Dates
            return
        if text.count("(") + text.count(")") > 2:  # Too many parentheticals
            return
        if sum(ch.isdigit() for ch in text) > 8:  # Too many numbers
            return
            
        # Take only first complete sentence for brevity
        sentences = re.split(r"(?<=[.!?])\s+", text)
        if sentences:
            first_sentence = sentences[0].strip()
            
            # Must be conversational and reasonably sized
            if (3 <= len(first_sentence.split()) <= 20 and 
                _looks_conversational(first_sentence) and
                first_sentence not in snippets):
                snippets.append(first_sentence)

    # Extract from AbstractText
    add_snippet(data.get("AbstractText"))

    # Extract from RelatedTopics recursively
    def extract_from_topics(topics):
        for topic in topics or []:
            if isinstance(topic, dict):
                if "Text" in topic:
                    add_snippet(topic.get("Text"))
                if isinstance(topic.get("Topics"), list):
                    extract_from_topics(topic["Topics"])
                    
    extract_from_topics(data.get("RelatedTopics"))

    # Deduplicate and limit results
    unique_snippets = []
    seen = set()
    for snippet in snippets:
        key = snippet.lower()
        if key not in seen:
            seen.add(key)
            unique_snippets.append(snippet)
            
    return unique_snippets[:4]  # Limit to 4 best snippets


def _build_conversation_queries(message: str) -> List[str]:
    """Build queries focused on conversational responses."""
    message_clean = re.sub(r"\s+", " ", message.strip())
    
    # Base conversational queries
    queries = [
        f"how to respond to \"{message_clean}\"",
        f"what to say when someone says \"{message_clean}\"",
        f"conversation about {message_clean}",
        f"talking about {message_clean}",
    ]
    
    # Extract key entities for targeted queries
    # Capitalized words (proper nouns, names, places)
    entities = re.findall(r"\b([A-Z][a-z]+(?:\s+[A-Z][a-z]+){0,2})\b", message)
    # Acronyms
    entities += re.findall(r"\b([A-Z]{2,})\b", message)
    
    # Filter out common words
    entities = [e for e in entities if e not in {"I", "A", "The", "And", "Or", "But"}]
    
    # Add entity-specific conversational queries
    for entity in entities[:2]:  # Limit to avoid too many requests
        queries.extend([
            f"talking about {entity}",
            f"{entity} conversation topics",
            f"what to say about {entity}",
        ])
    
    # Extract question words for appropriate responses
    question_words = ["how", "what", "why", "when", "where", "who"]
    for qword in question_words:
        if qword in message.lower():
            queries.append(f"responding to {qword} questions")
            break
    
    # Deduplicate and truncate
    seen = set()
    unique_queries = []
    for query in queries:
        query_short = query[:100]  # Reasonable length limit
        if query_short not in seen:
            seen.add(query_short)
            unique_queries.append(query_short)
            
    return unique_queries[:6]  # Limit total queries


class Objectivity:
    """Retrieves conversational context from web sources only."""
    
    def context_window(self, message: str, _tokens_ignored: List[str]) -> str:
        """
        Fetch ONLY conversational web snippets for smalltalk.
        NO Wikipedia. NO definitions. NO glossary content.
        """
        conversational_snippets: List[str] = []

        # Prepare ignored tokens set
        ignored = {t.lower() for t in _tokens_ignored}

        # Remove ignored tokens from the message before building queries
        if ignored:
            pattern = r"\b(?:" + "|".join(re.escape(t) for t in ignored) + r")\b"
            message = re.sub(pattern, "", message, flags=re.IGNORECASE)

        message = re.sub(r"\s+", " ", message).strip()
        if not message:
            return ""

        # Build conversation-focused queries
        queries = _build_conversation_queries(message)

        # Filter out queries containing any ignored tokens
        queries = [
            q for q in queries
            if not any(token in q.lower() for token in ignored)
        ]
        if not queries:
            return ""

        # Fetch snippets from each query
        for query in queries:
            try:
                snippets = _ddg_json(query)
                for snippet in snippets:
                    if any(token in snippet.lower() for token in ignored):
                        continue
                    # Double-check it's conversational
                    if (_looks_conversational(snippet) and
                        not _looks_like_glossary(snippet) and
                        len(snippet.split()) >= 4):  # Minimum substance
                        
                        conversational_snippets.append(snippet)
                        
                        # Stop when we have enough good material
                        if len(conversational_snippets) >= 6:
                            break
                            
            except Exception:
                continue  # Skip failed queries
                
            if len(conversational_snippets) >= 6:
                break
        
        # Return joined snippets, each on its own line
        return "\n".join(conversational_snippets).strip()
