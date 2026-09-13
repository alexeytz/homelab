#!/bin/bash -i
# bash -i = we need ~/.bashrc sourced for aliased if we are in podman area with alias=docker.
test "$1" = '' && echo "Execution is: $0 <IP to OLLAMA host>"
test "$1" = '' && exit 1

echo "Upgrading Open WebUI..."

echo "Removing Open WebUI image ghcr.io/open-webui/open-webui:old..."
docker rmi ghcr.io/open-webui/open-webui:old || echo "Warning: a problem while deleting image ghcr.io/open-webui/open-webui:old. It seems it does not exist."

echo "Stopping Open WebUI..."
docker ps -q -f "name=open-webui" -f "status=running" | grep -q . && \
docker stop open-webui || echo "Warning: a problem while stopping open-webui:old. Seems down or does not exist."

echo "Removing Open WebUI..."
docker rm open-webui || echo "Warning: a problem while removing open-webui:old. It seems it does not exist."

echo "Tagging Open WebUI image main to old..."
docker tag ghcr.io/open-webui/open-webui:main ghcr.io/open-webui/open-webui:old || echo "Warning: a problem while tagging the image. Does it exist?"

echo "Removing Open WebUI image main (untag)..."
docker rmi ghcr.io/open-webui/open-webui:main || echo "Warning: a problem while removing open-webui:main. Does it exist?"

echo "Pulling Open WebUI image main..." && \
docker pull ghcr.io/open-webui/open-webui:main && \
echo "Starting Open WebUI..." && \
echo "docker run -d -p 80:8080 -e OLLAMA_BASE_URL=http://$1:11434 -v open-webui:/app/backend/data --name open-webui --restart always ghcr.io/open-webui/open-webui:main" > ~/open-webui_start_cmd.sh && \
docker run -d -p 80:8080 -e OLLAMA_BASE_URL=http://$1:11434 -v open-webui:/app/backend/data --name open-webui --restart always ghcr.io/open-webui/open-webui:main && \
sleep 2 && \
echo "Open WebUI is running..." && \
echo "The following are the logs of Open WebUI. Press CTRL+C to stop logging and exit from this terminal session." && \
docker logs -f open-webui || echo "Error. Something went wrong."
