curl -s http://127.0.0.1:25413/traffic |
   jq -r 'to_entries[]
       | "\(.key): Tx \(.value.tx) bytes, Rx \(.value.rx) bytes"'

curl -s http://127.0.0.1:25413/online |
   jq -r 'to_entries[] | "User \(.key) has: \(.value) online connection(s)"'

curl -s -H "Accept: text/plain" http://127.0.0.1:25413/dump/streams
