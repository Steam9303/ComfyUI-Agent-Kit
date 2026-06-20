# In-graph Claude nodes (Layer 3)

Three Claude nodes may be present after install. They look similar (two even share the display name
"Anthropic Claude") but differ in billing and purpose. Pick by how the graph is billed and what it needs.

## AnthropicClaudeNode — the workhorse (your own key)

- class_type: `AnthropicClaudeNode` | display: "Anthropic Claude" | category: `LLM/Anthropic`
- source: community node `anthropic-claude` (alexmunteanu). `pip install anthropic>=0.40.0`.
- billing: your own Anthropic API key via the `CLAUDE_API_KEY` env var.
- why it matters: 40+ built-in templates that rewrite a prompt for a SPECIFIC generative model — `FLUX`,
  `Ideogram 3`, `LTX 2.3` / `LTX 2 Pro`, `Wan 2.1 & 2.2`, `Nano Banana`, `Veo 3`, `Sora 2`, `Qwen Image`,
  `Seedream`, and more. Vision (pass images for context), extended thinking, seed-based caching.
- use it for: autonomous in-graph prompt enrichment and "does this image match the topic" gating in unattended
  pipelines.
- setup: `setx CLAUDE_API_KEY "sk-ant-..."` (Windows) / `export CLAUDE_API_KEY=...`, then restart ComfyUI so
  the env is picked up. Without the key the node errors, but it does not affect other generation.

## ClaudeNode — official partner node (Comfy.org credits)

- class_type: `ClaudeNode` | display: "Anthropic Claude" | category: `partner/text/Anthropic`
- source: official Comfy-Org partner/API node. `api_node: true`.
- billing: Comfy.org account credits (hidden `auth_token_comfy_org` / `api_key_comfy_org`), no own key.
- models: up to the latest Opus. Vision up to 20 images.
- use it for: a quick path when you do not want to manage an Anthropic key, and the account has credits.

## ClaudeCustomPrompt — simple generator

- class_type: `ClaudeCustomPrompt` | display: "Claude Prompt Generator" | category: `prompt generation`
- source: `comfyui_claude_prompt_generator` (PauldeLavallaz). API key passed as a string input on the node.
- use it for: a minimal "system prompt + user input -> prompt string" node when you do not want the larger
  community node.

## Do you even need one?

For everything done WITH Claude in the loop, write the prompt yourself — it is better than the node templates
and free. Reach for Layer 3 only when a graph runs WITHOUT you (e.g. a bot's unattended auto-hero step).
