# Claude code instructions

## Install `uv`

https://docs.astral.sh/uv/getting-started/installation/

```
curl -LsSf https://astral.sh/uv/install.sh | sh
```

`uv` located in:

```
~$ which uv
/home/cc/.local/bin/uv
~$
```

## Install `claude`

https://docs.ollama.com/integrations/claude-code

```
curl -fsSL https://claude.ai/install.sh | bash
```

`claude` located in:

```
~$ which claude
/home/cc/.local/bin/claude
~$
```

Add local variables:

```
export ANTHROPIC_AUTH_TOKEN=ollama
export ANTHROPIC_API_KEY=""
export ANTHROPIC_BASE_URL=http://<ollama-host>:11434
export OLLAMA_API_KEY="bc1...Rc"
```

## Run `claude`

```
claude --model qwen3-coder:30b
```

## Install node.js

```
apt install nodejs npm -y
```

# Hints
Alt+Enter = a new line.



(SKILLs) bb@claude-code-dryrun:~/Documents/claude-code-projects/VAST$ uv venv
Using CPython 3.12.3 interpreter at: /usr/bin/python3
Creating virtual environment at: .venv
Activate with: source .venv/bin/activate
(SKILLs) bb@claude-code-dryrun:~/Documents/claude-code-projects/VAST$ source .venv/bin/activate
(VAST) bb@claude-code-dryrun:~/Documents/claude-code-projects/VAST$ claude --model glm-4.7-flash --dangerously-skip-permissions
