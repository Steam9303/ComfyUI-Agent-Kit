<#
.SYNOPSIS
  Install the ComfyUI + Claude kit: skills, MCP driver, in-graph Claude nodes, node-building skills,
  the official workflow-template library, and the auto-activation block.

.DESCRIPTION
  Idempotent. Re-running skips anything already in place. Third-party pieces (MCP package, node-building
  skills, workflow templates, ComfyUI Claude nodes) are fetched from their sources, not vendored here.

.PARAMETER ComfyUIPath
  Root of the ComfyUI install (the folder that contains a 'custom_nodes' directory). If given, the two
  Claude nodes are git-cloned into it. If omitted, the installer prints Manager instructions instead.

.PARAMETER TemplatesDir
  Where to sparse-clone the official workflow templates. Default: $HOME\comfyui-claude-kit-data\workflow_templates

.PARAMETER SkipTemplates
  Skip cloning the ~900MB template library.

.PARAMETER SkipNodes
  Skip installing the in-graph Claude nodes.

.EXAMPLE
  ./install.ps1 -ComfyUIPath "E:\ComfyUI\ComfyUI\ComfyUI"
#>
param(
  [string]$ComfyUIPath = "",
  [string]$TemplatesDir = "$env:USERPROFILE\comfyui-claude-kit-data\workflow_templates",
  [switch]$SkipTemplates,
  [switch]$SkipNodes
)

$ErrorActionPreference = "Stop"
$RepoRoot   = Split-Path -Parent $MyInvocation.MyCommand.Path
$SkillsDest = "$env:USERPROFILE\.claude\skills"
$ClaudeMd   = "$env:USERPROFILE\.claude\CLAUDE.md"

function Info($m){ Write-Host "  $m" -ForegroundColor Cyan }
function Ok($m)  { Write-Host "  [ok] $m" -ForegroundColor Green }
function Warn($m){ Write-Host "  [!]  $m" -ForegroundColor Yellow }
function Have($cmd){ return [bool](Get-Command $cmd -ErrorAction SilentlyContinue) }

Write-Host "`n=== ComfyUI + Claude kit installer ===`n" -ForegroundColor White

# --- 0. Prerequisites ---------------------------------------------------------
Write-Host "[0/6] Prerequisites" -ForegroundColor White
$miss = @()
foreach ($c in @("claude","node","npm","git","python")) {
  if (Have $c) { Ok "$c found" } else { Warn "$c MISSING"; $miss += $c }
}
if ($miss.Count) {
  Warn "Install the missing tools first: $($miss -join ', ')"
  Warn "  claude  -> Claude Code CLI   node/npm -> nodejs.org   git -> git-scm.com   python -> python.org"
  throw "Prerequisites missing."
}

# --- 1. Knowledge skill + client ---------------------------------------------
Write-Host "`n[1/6] Skill + client -> $SkillsDest\comfyui" -ForegroundColor White
New-Item -ItemType Directory -Force -Path "$SkillsDest\comfyui\workflows" | Out-Null
Copy-Item "$RepoRoot\skills\comfyui\SKILL.md"        "$SkillsDest\comfyui\SKILL.md"        -Force
Copy-Item "$RepoRoot\skills\comfyui\comfy_client.py" "$SkillsDest\comfyui\comfy_client.py" -Force
Ok "comfyui skill installed"

# --- 2. MCP driver (Layer 2) --------------------------------------------------
Write-Host "`n[2/6] MCP driver (comfyui-mcp)" -ForegroundColor White
& npm install -g comfyui-mcp 2>&1 | Out-Null
Ok "comfyui-mcp installed globally"
$already = $false
try { & claude mcp get comfyui *> $null; if ($LASTEXITCODE -eq 0) { $already = $true } } catch {}
if ($already) {
  Ok "MCP 'comfyui' already registered"
} else {
  & claude mcp add comfyui --scope user -- comfyui-mcp
  if ($LASTEXITCODE -eq 0) { Ok "MCP 'comfyui' registered (user scope)" }
  else { Warn "Could not auto-register MCP. Run manually: claude mcp add comfyui --scope user -- comfyui-mcp" }
}

# --- 3. Node-building skills (Layer 4) ---------------------------------------
Write-Host "`n[3/6] Node-building skills (comfyui-node-*)" -ForegroundColor White
$tmp = Join-Path $env:TEMP ("cnskills_" + [guid]::NewGuid().ToString("N").Substring(0,8))
& git clone --depth 1 https://github.com/jtydhr88/comfyui-custom-node-skills.git $tmp 2>&1 | Out-Null
$srcSkills = Join-Path $tmp "plugins\comfyui-custom-nodes\skills"
if (Test-Path $srcSkills) {
  Get-ChildItem $srcSkills -Directory | ForEach-Object {
    $dst = "$SkillsDest\$($_.Name)"
    if (Test-Path $dst) { Remove-Item $dst -Recurse -Force -ErrorAction SilentlyContinue }
    Copy-Item $_.FullName $dst -Recurse -Force
  }
  $n = (Get-ChildItem $srcSkills -Directory).Count
  Ok "$n node-building skills installed"
} else { Warn "Could not find skills in the cloned repo (layout changed?)" }
Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue

# --- 4. In-graph Claude nodes (Layer 3) --------------------------------------
Write-Host "`n[4/6] In-graph Claude nodes" -ForegroundColor White
if ($SkipNodes) {
  Warn "skipped (-SkipNodes)"
} elseif ($ComfyUIPath -and (Test-Path (Join-Path $ComfyUIPath "custom_nodes"))) {
  $cn = Join-Path $ComfyUIPath "custom_nodes"
  $nodes = @(
    @{ name="anthropic-claude"; url="https://github.com/alexmunteanu/comfyui-anthropic-claude.git" },
    @{ name="comfyui_claude_prompt_generator"; url="https://github.com/PauldeLavallaz/comfyui_claude_prompt_generator.git" }
  )
  foreach ($nd in $nodes) {
    $dest = Join-Path $cn $nd.name
    if (Test-Path $dest) { Ok "$($nd.name) already present" }
    else {
      & git clone --depth 1 $nd.url $dest 2>&1 | Out-Null
      if (Test-Path $dest) { Ok "$($nd.name) cloned" } else { Warn "failed: $($nd.name)" }
    }
  }
  Warn "These nodes may need: pip install anthropic>=0.40.0  (in ComfyUI's python env)"
  Warn "Restart ComfyUI to load them (Desktop: close + reopen the app)."
} else {
  Warn "No -ComfyUIPath given. Install the nodes via ComfyUI Manager instead:"
  Warn "  Manager -> Custom Nodes Manager -> search 'anthropic claude' -> Install"
  Warn "  (also 'claude prompt generator' by PauldeLavallaz, optional)"
}

# --- 5. Workflow templates ----------------------------------------------------
Write-Host "`n[5/6] Workflow templates (source of truth)" -ForegroundColor White
if ($SkipTemplates) {
  Warn "skipped (-SkipTemplates)"
} elseif (Test-Path (Join-Path $TemplatesDir ".git")) {
  Ok "templates already cloned at $TemplatesDir (run 'git pull' to update)"
} else {
  New-Item -ItemType Directory -Force -Path (Split-Path $TemplatesDir) | Out-Null
  & git clone --filter=blob:none --no-checkout https://github.com/Comfy-Org/workflow_templates.git $TemplatesDir 2>&1 | Out-Null
  & git -C $TemplatesDir sparse-checkout set templates blueprints 2>&1 | Out-Null
  & git -C $TemplatesDir checkout 2>&1 | Out-Null
  if (Test-Path (Join-Path $TemplatesDir "templates\index.json")) {
    & python "$RepoRoot\tools\gen_quick_index.py" (Join-Path $TemplatesDir "templates")
    Ok "templates cloned + _quick_index.json built -> $TemplatesDir"
  } else { Warn "template clone incomplete" }
}

# --- 6. Auto-activation block in CLAUDE.md -----------------------------------
Write-Host "`n[6/6] Auto-activation block in CLAUDE.md" -ForegroundColor White
$marker = "### ComfyUI media generation (auto-activation)"
$existing = ""
if (Test-Path $ClaudeMd) { $existing = Get-Content $ClaudeMd -Raw }
if ($existing -match [regex]::Escape($marker)) {
  Ok "activation block already present"
} else {
  $snippet = Get-Content "$RepoRoot\snippets\claude_md_activation.md" -Raw
  $snippet = $snippet.Replace("__TEMPLATES_DIR__", $TemplatesDir)
  Add-Content -Path $ClaudeMd -Value "`n$snippet"
  Ok "activation block appended to $ClaudeMd"
}

# --- Done ---------------------------------------------------------------------
Write-Host "`n=== Done. Next steps ===" -ForegroundColor White
Info "1. Start ComfyUI (Desktop: open the app). Confirm http://127.0.0.1:8188 answers."
Info "2. In a Claude Code session, run the BOOTSTRAP once (docs/BOOTSTRAP.md): Claude detects your"
Info "   paths / GPUs / models via health_check and fills the machine block in the skill."
Info "3. (Optional) For autonomous in-graph prompt enrichment, set your key and restart ComfyUI:"
Info "      setx CLAUDE_API_KEY `"sk-ant-...`""
Write-Host ""
