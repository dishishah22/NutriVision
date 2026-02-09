from .gemini_client import GeminiClient
from .openrouter_client import OpenRouterClient

class AIRouter:
    def __init__(self, gemini_key, openrouter_key):
        self.gemini = GeminiClient(gemini_key)
        self.openrouter = OpenRouterClient(openrouter_key)

    def analyze_food(self, prompt, image_bytes):
        # 1. Try Gemini
        result, model = self.gemini.analyze_food(prompt, image_bytes)
        if result:
            return result, "gemini", model

        # 2. Try OpenRouter/Groq
        result, model = self.openrouter.analyze_food(prompt, image_bytes)
        if result:
            return result, self.openrouter.provider_name, model

        # 3. Fail gracefully (Return empty structure)
        return None, "none", None
