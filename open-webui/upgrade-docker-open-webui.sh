#!/bin/bash
echo "Upgrading Open WebUI..." && \
echo "Stopping Open WebUI..." && \
docker stop open-webui && \
echo "Removing Open WebUI..." && \
docker rm open-webui && \
echo "Removing Open WebUI image ghcr.io/open-webui/open-webui:old..." && \
docker rmi ghcr.io/open-webui/open-webui:old && \
echo "Tagging Open WebUI image main to old..." && \
docker tag ghcr.io/open-webui/open-webui:main ghcr.io/open-webui/open-webui:old && \
echo "Removing Open WebUI image main (untag)..." && \
docker rmi ghcr.io/open-webui/open-webui:main && \
echo "Pulling Open WebUI image main..." && \
docker pull ghcr.io/open-webui/open-webui:main && \
echo "Starting Open WebUI..." && \
docker run -d -p 3000:8080 -e OLLAMA_BASE_URL=http://192.168.69.11:11434 -v open-webui:/app/backend/data --name open-webui --restart always ghcr.io/open-webui/open-webui:main && \
sleep 2 && \
echo "Open WebUI is running..." && \
echo "Following are the logs of Open WebUI. Press CTRL+C to stop logging and exit from this terminal session." && \
docker logs open-webui -f