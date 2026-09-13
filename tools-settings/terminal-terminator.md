# Make your terminator change a window/tab title with the SSH-connected hostname.

Add to ~/.bashrc, so Terminator would update the hostname:

```
update_terminator_title() {
    if [ -n "$SSH_CONNECTION" ]; then
        # Connected to a remote host
        echo -ne "\e]0;${USER}@${HOSTNAME}\a"
    else
        # Local session
        echo -ne "\e]0;${USER}@${HOSTNAME}: ${PWD}\a"
    fi
}
PROMPT_COMMAND="update_terminator_title; $PROMPT_COMMAND"
```

The `\e]0;... \a` sequence is an xterm control sequence that sets the window title.

The `if [ -n "$SSH_CONNECTION" ];` check ensures the title reflects the remote host only when an SSH connection is active.
