#!/bin/bash
# https://blog.mdminhazulhaque.io/extract-patch-file-configmap

URL="https://raw.githubusercontent.com/daytonaio/samples-index/main/index.json"

# parse the arguments for --url
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    -u|--url)
      URL="$2"
      shift
      shift
      ;;
    *)
      shift
      ;;
  esac
done

# error if no url is provided
if [[ -z "$URL" ]]; then
  echo "ERROR: no url provided"
  exit 1
fi

kubectl -n watkins get configmap watkins-dashboard -o go-template='{{index .data "configuration.json"}}' | \
    jq --arg url "$URL" '.workspaceTemplatesIndexUrl = $url' > configuration.json

# trap the exit signal to delete configuration.json when the script exits
trap 'rm -f configuration.json' EXIT

echo "Replacing: $(kubectl -n watkins get configmap watkins-dashboard -o go-template='{{index .data "configuration.json"}}' | jq -r .workspaceTemplatesIndexUrl)"
echo "With: $URL"

kubectl -n watkins create configmap watkins-dashboard --from-file=configuration.json=configuration.json --dry-run=client -o yaml | \
    kubectl -n watkins patch configmaps watkins-dashboard --type merge --patch-file /dev/stdin

# restart the watkins-dashboard pod
kubectl -n watkins rollout restart deployment watkins-dashboard
kubectl -n watkins rollout status deployment watkins-dashboard --watch