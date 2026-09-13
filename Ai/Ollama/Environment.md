# Ollama environment variable

# Set Ollama listening on all interfaces and define context window

```
systemctl edit ollama
```

```
### Anything between here and the comment below will become the contents of the>

[Service]
Environment="OLLAMA_HOST=0.0.0.0"
Environment="OLLAMA_CONTEXT_LENGTH=64000"

### Edits below this comment will be discarded
```
