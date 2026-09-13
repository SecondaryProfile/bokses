enum AiProvider { gemini, claude, openai }

class AiProviderDef {
  final AiProvider provider;
  final String displayName;
  final String model;
  final String keyHint;
  final String getKeyUrl;
  final String description;

  const AiProviderDef({
    required this.provider,
    required this.displayName,
    required this.model,
    required this.keyHint,
    required this.getKeyUrl,
    required this.description,
  });
}

const kGeminiProvider = AiProviderDef(
  provider: AiProvider.gemini,
  displayName: 'Gemini',
  model: 'gemini-2.5-flash',
  keyHint: 'AIza...',
  getKeyUrl: 'aistudio.google.com/apikey',
  description: 'Google\'s AI Studio. Fast and low-cost for image recognition.',
);

const kClaudeProvider = AiProviderDef(
  provider: AiProvider.claude,
  displayName: 'Claude',
  model: 'claude-haiku-4-5',
  keyHint: 'sk-ant-...',
  getKeyUrl: 'console.anthropic.com/settings/keys',
  description: 'Anthropic\'s Claude. Fast and accurate for image recognition.',
);

const kOpenAiProvider = AiProviderDef(
  provider: AiProvider.openai,
  displayName: 'ChatGPT',
  model: 'gpt-4o-mini',
  keyHint: 'sk-...',
  getKeyUrl: 'platform.openai.com/api-keys',
  description: 'OpenAI\'s ChatGPT. Fast and low-cost for image recognition.',
);

const kAiProviders = [kGeminiProvider, kClaudeProvider, kOpenAiProvider];

AiProviderDef aiProviderDef(AiProvider provider) {
  return kAiProviders.firstWhere((p) => p.provider == provider);
}
