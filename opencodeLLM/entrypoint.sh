#!/bin/bash
# Fix ownership on Docker volume mount points (mounted as root)
chown -R agent:agent \
    /home/agent/.cache \
    /home/agent/.local \
    /home/agent/.config \
    2>/dev/null

exec gosu agent "$@"
