#!/usr/bin/env bash
# Install the ComfyUI + Claude kit: skills, MCP driver, in-graph Claude nodes, node-building skills,
# the official workflow-template library, and the auto-activation block.
# Idempotent. Third-party pieces are fetched from their sources, not vendored here.
#
# Usage:
#   ./install.sh [--comfyui-path PATH] [--templates-dir PATH] [--skip-templates] [--skip-nodes]
set -euo pipefail

COMFYUI_PATH=""
TEMPLATES_DIR="$HOME/comfyui-claude-kit-data/workflow_templates"
SKIP_TEMPLATES=0
SKIP_NODES=0
while [ $# -gt 0 ]; do
  case "$1" in
    --comfyui-path)  COMFYUI_PATH="$2"; shift 2;;
    --templates-dir) TEMPLATES_DIR="$2"; shift 2;;
    --skip-templates) SKIP_TEMPLATES=1; shift;;
    --skip-nodes)     SKIP_NODES=1; shift;;
    *) echo "unknown arg: $1"; exit 1;;
  esac
done

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
SKILLS_DEST="$HOME/.claude/skills"
CLAUDE_MD="$HOME/.claude/CLAUDE.md"

ok(){   echo "  [ok] $*"; }
warn(){ echo "  [!]  $*"; }
have(){ command -v "$1" >/dev/null 2>&1; }

echo; echo "=== ComfyUI + Claude kit installer ==="; echo

echo "[0/6] Prerequisites"
miss=()
for c in claude node npm git python3; do
  if have "$c"; then ok "$c found"; else warn "$c MISSING"; miss+=("$c"); fi
done
[ ${#miss[@]} -eq 0 ] || { warn "Install first: ${miss[*]}"; exit 1; }

echo; echo "[1/6] Skill + client -> $SKILLS_DEST/comfyui"
mkdir -p "$SKILLS_DEST/comfyui/workflows"
cp "$REPO_ROOT/skills/comfyui/SKILL.md"        "$SKILLS_DEST/comfyui/SKILL.md"
cp "$REPO_ROOT/skills/comfyui/comfy_client.py" "$SKILLS_DEST/comfyui/comfy_client.py"
ok "comfyui skill installed"

echo; echo "[2/6] MCP driver (comfyui-mcp)"
npm install -g comfyui-mcp >/dev/null 2>&1
ok "comfyui-mcp installed globally"
if claude mcp get comfyui >/dev/null 2>&1; then
  ok "MCP 'comfyui' already registered"
else
  claude mcp add comfyui --scope user -- comfyui-mcp && ok "MCP 'comfyui' registered (user scope)" \
    || warn "Register manually: claude mcp add comfyui --scope user -- comfyui-mcp"
fi

echo; echo "[3/6] Node-building skills (comfyui-node-*)"
tmp="$(mktemp -d)"
git clone --depth 1 https://github.com/jtydhr88/comfyui-custom-node-skills.git "$tmp" >/dev/null 2>&1
src_skills="$tmp/plugins/comfyui-custom-nodes/skills"
if [ -d "$src_skills" ]; then
  n=0
  for d in "$src_skills"/*/; do
    dst="$SKILLS_DEST/$(basename "$d")"
    rm -rf "$dst"; cp -R "$d" "$dst"; n=$((n+1))
  done
  ok "$n node-building skills installed"
else warn "skills not found in cloned repo (layout changed?)"; fi
rm -rf "$tmp"

echo; echo "[4/6] In-graph Claude nodes"
if [ "$SKIP_NODES" -eq 1 ]; then
  warn "skipped (--skip-nodes)"
elif [ -n "$COMFYUI_PATH" ] && [ -d "$COMFYUI_PATH/custom_nodes" ]; then
  cn="$COMFYUI_PATH/custom_nodes"
  while IFS='|' read -r name url; do
    if [ -d "$cn/$name" ]; then ok "$name already present"
    else git clone --depth 1 "$url" "$cn/$name" >/dev/null 2>&1 && ok "$name cloned" || warn "failed: $name"; fi
  done <<'EOF'
anthropic-claude|https://github.com/alexmunteanu/comfyui-anthropic-claude.git
comfyui_claude_prompt_generator|https://github.com/PauldeLavallaz/comfyui_claude_prompt_generator.git
EOF
  warn "These nodes may need: pip install 'anthropic>=0.40.0' (in ComfyUI's python env)"
  warn "Restart ComfyUI to load them."
else
  warn "No --comfyui-path given. Install via ComfyUI Manager: search 'anthropic claude' -> Install."
fi

echo; echo "[5/6] Workflow templates (source of truth)"
if [ "$SKIP_TEMPLATES" -eq 1 ]; then
  warn "skipped (--skip-templates)"
elif [ -d "$TEMPLATES_DIR/.git" ]; then
  ok "templates already cloned at $TEMPLATES_DIR (run 'git pull' to update)"
else
  mkdir -p "$(dirname "$TEMPLATES_DIR")"
  git clone --filter=blob:none --no-checkout https://github.com/Comfy-Org/workflow_templates.git "$TEMPLATES_DIR" >/dev/null 2>&1
  git -C "$TEMPLATES_DIR" sparse-checkout set templates blueprints >/dev/null 2>&1
  git -C "$TEMPLATES_DIR" checkout >/dev/null 2>&1
  if [ -f "$TEMPLATES_DIR/templates/index.json" ]; then
    python3 "$REPO_ROOT/tools/gen_quick_index.py" "$TEMPLATES_DIR/templates"
    ok "templates cloned + _quick_index.json built -> $TEMPLATES_DIR"
  else warn "template clone incomplete"; fi
fi

echo; echo "[6/6] Auto-activation block in CLAUDE.md"
marker="### ComfyUI media generation (auto-activation)"
if [ -f "$CLAUDE_MD" ] && grep -qF "$marker" "$CLAUDE_MD"; then
  ok "activation block already present"
else
  mkdir -p "$(dirname "$CLAUDE_MD")"
  sed "s|__TEMPLATES_DIR__|$TEMPLATES_DIR|g" "$REPO_ROOT/snippets/claude_md_activation.md" >> "$CLAUDE_MD"
  ok "activation block appended to $CLAUDE_MD"
fi

echo; echo "=== Done. Next steps ==="
echo "  1. Start ComfyUI. Confirm http://127.0.0.1:8188 answers."
echo "  2. In a Claude Code session, run the BOOTSTRAP once (docs/BOOTSTRAP.md)."
echo "  3. (Optional) Autonomous in-graph enrichment: export CLAUDE_API_KEY=sk-ant-... then restart ComfyUI."
echo
