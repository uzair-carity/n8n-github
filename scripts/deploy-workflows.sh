#!/bin/bash

set -e

N8N_HOST=$1
API_KEY=$2
WORKFLOWS_DIR="workflows"

if [[ -z "$N8N_HOST" || -z "$API_KEY" ]]; then
  echo "Usage: $0 <N8N_HOST> <N8N_API_KEY>"
  exit 1
fi

echo "Deploying workflows to n8n: $N8N_HOST"
echo "Scanning folder: $WORKFLOWS_DIR"

for file in $WORKFLOWS_DIR/*.json; do
  if [[ ! -f "$file" ]]; then
    echo "No workflow JSON files found."
    exit 0
  fi

  name=$(jq -r '.name' "$file")

  if [[ "$name" == "null" ]]; then
    echo "Invalid workflow file: $file (no name found)"
    continue
  fi

  echo "Checking if workflow '$name' exists..."

  # Fetch all workflows
  response=$(curl -s -X GET "$N8N_HOST/api/v1/workflows" \
    -H "accept: application/json" \
    -H "X-N8N-API-KEY: $API_KEY")

  id=$(echo "$response" | jq -r --arg name "$name" '.data[] | select(.name == $name) | .id')

  # Filter the fields expected by the API
  filtered_workflow=$(jq '{name, nodes, connections, settings}' "$file")

  if [[ -n "$id" ]]; then
    echo "→ Updating existing workflow '$name' (ID: $id)..."
    curl -s -X PUT "$N8N_HOST/api/v1/workflows/$id" \
      -H "X-N8N-API-KEY: $API_KEY" \
      -H "Content-Type: application/json" \
      --data "$filtered_workflow"
  else
    echo "→ Creating new workflow '$name'..."
    curl -s -X POST "$N8N_HOST/api/v1/workflows" \
      -H "X-N8N-API-KEY: $API_KEY" \
      -H "Content-Type: application/json" \
      --data "$filtered_workflow"
  fi
done

##
echo "✅ Deployment complete."
