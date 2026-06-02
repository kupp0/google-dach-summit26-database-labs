#!/bin/bash

# Create lab folder and Spanner Graph skill
LAB_DIR="$HOME/disneyland-navigator"
SKILL_DIR="$LAB_DIR/skills/spanner-graph"
echo "Generating lab folder and Spanner Graph skill inside: $LAB_DIR"
mkdir -p "$SKILL_DIR"

cat << 'EOF' > "$SKILL_DIR/SKILL.md"
# Skill: Unified Spanner Graph DDL, DML, and GQL Engine

## Description
A generalized, end-to-end architectural capability for Google Cloud Spanner Property Graphs. This skill provides structural rules for schema configuration (DDL), relationship mutations (DML), and native ISO GQL graph pathfinding queries (GQL) without requiring external web lookups.

---

## 1. Schema Lifecycle Definitions (DDL)
When creating or altering a property graph structure, map the environment's tabular context to this strict configuration layout:

```sql
-- Step 1: Baseline Entity Tables (Nodes)
CREATE TABLE {NODE_TABLE} (
    {NODE_PRIMARY_ID} {DATATYPE} NOT NULL,
    -- Entity properties (e.g., name, category, descriptions)
) PRIMARY KEY ({NODE_PRIMARY_ID});

-- Step 2: Relationship Topology Tables (Edges)
CREATE TABLE {EDGE_TABLE} (
    {SOURCE_FOREIGN_ID} {DATATYPE} NOT NULL,
    {DESTINATION_FOREIGN_ID} {DATATYPE} NOT NULL,
    -- Edge properties (e.g., weights, latency, distance, metrics)
    FOREIGN KEY ({SOURCE_FOREIGN_ID}) REFERENCES {NODE_TABLE} ({NODE_PRIMARY_ID}),
    FOREIGN KEY ({DESTINATION_FOREIGN_ID}) REFERENCES {NODE_TABLE} ({NODE_PRIMARY_ID})
) PRIMARY KEY ({SOURCE_FOREIGN_ID}, {DESTINATION_FOREIGN_ID});

-- Step 3: Graph Construction
CREATE PROPERTY GRAPH {GRAPH_NAME}
  NODE TABLES (
    {NODE_TABLE}
      KEY ({NODE_PRIMARY_ID})
      LABEL {NODE_LABEL_NAME}
  )
  EDGE TABLES (
    {EDGE_TABLE}
      KEY ({SOURCE_FOREIGN_ID}, {DESTINATION_FOREIGN_ID})
      SOURCE KEY ({SOURCE_FOREIGN_ID}) REFERENCES {NODE_TABLE} ({NODE_PRIMARY_ID})
      DESTINATION KEY ({DESTINATION_FOREIGN_ID}) REFERENCES {NODE_TABLE} ({NODE_PRIMARY_ID})
      LABEL {EDGE_LABEL_NAME}
  );
```

---

## 2. Relationship Data Mutations (DML)

When inserting or updating nodes and edges into the underlying graph tables, use standard transactional Spanner DML patterns:

```sql
-- Populate or Update Nodes
INSERT OR UPDATE INTO {NODE_TABLE} ({NODE_PRIMARY_ID}, {ATTRIBUTE_1}, {ATTRIBUTE_2}) 
VALUES ({VAL_ID}, '{VAL_1}', '{VAL_2}');

-- Populate or Update Directed Edges
INSERT OR UPDATE INTO {EDGE_TABLE} ({SOURCE_FOREIGN_ID}, {DESTINATION_FOREIGN_ID}, {WEIGHT_ATTRIBUTE}) 
VALUES ({START_ID}, {END_ID}, {WEIGHT_VALUE});
```

---

## 3. Native Graph Traversals & Pathfinding (GQL)

When building query layers, API endpoints, or supplying commands to Model Context Protocol (MCP) data tools, format all lookup requests inside a `GRAPH {GRAPH_NAME}` block using native ISO GQL syntax patterns:

### Pattern A: 1-Hop Neighbor Discovery (Direct Connections)

Use this structure to find direct dependencies, adjacent rides, or direct connections:

```sql
GRAPH {GRAPH_NAME}
MATCH (src:{NODE_LABEL_NAME})-[e:{EDGE_LABEL_NAME}]->(dst:{NODE_LABEL_NAME})
WHERE src.{ATTRIBUTE_NAME} = '{FILTER_VALUE}'
RETURN dst.{ATTRIBUTE_NAME} AS connected_node, e.{WEIGHT_ATTRIBUTE} AS edge_metric;
```

### Pattern B: Variable-Length Pathfinding (Degrees of Separation / Routes)

Use this structure when navigating multi-hop networks, computing routing paths, or finding structural pipelines from point A to point B:

```sql
GRAPH {GRAPH_NAME}
MATCH p = (src:{NODE_LABEL_NAME})-[:{EDGE_LABEL_NAME}]->{1,{MAX_HOPS}}(dst:{NODE_LABEL_NAME})
WHERE src.{ATTRIBUTE_NAME} = '{START_VALUE}' AND dst.{ATTRIBUTE_NAME} = '{END_VALUE}'
RETURN 
  src.{ATTRIBUTE_NAME} AS origin, 
  dst.{ATTRIBUTE_NAME} AS destination, 
  ARRAY(SELECT n.{ATTRIBUTE_NAME} FROM UNNEST(nodes(p)) AS n) AS path_nodes;
```

### Pattern C: Topologically Sorted Neighbors by Distance/Weight

Use this structure to sort neighbors dynamically by physical proximity or edge cost:

```sql
GRAPH {GRAPH_NAME}
MATCH (src:{NODE_LABEL_NAME})-[e:{EDGE_LABEL_NAME}]->(dst:{NODE_LABEL_NAME})
WHERE src.{ATTRIBUTE_NAME} = '{FILTER_VALUE}'
ORDER BY e.{WEIGHT_ATTRIBUTE} ASC
LIMIT {LIMIT_COUNT};
```

---

## Execution Guidelines

* **Zero Hallucination Constraints:** Treat capitalized terms (`CREATE PROPERTY GRAPH`, `NODE TABLES`, `EDGE TABLES`, `MATCH GRAPH_PATH`) as reserved structural constants.
* **Strict Variable Substitution:** Dynamically replace `{GRAPH_NAME}`, `{NODE_TABLE}`, `{EDGE_TABLE}`, `{NODE_LABEL_NAME}`, and `{EDGE_LABEL_NAME}` based purely on the workspace user configurations provided during the runtime initialization step.
EOF

echo "Lab folder and Spanner Graph skill successfully generated!"
echo "Target skill updated:"
echo " - $SKILL_DIR/SKILL.md"

# Create Vertex AI Configuration skill
VERTEXT_SKILL_DIR="$LAB_DIR/skills/vertex-config"
echo "Generating Vertex AI Configuration skill inside: $VERTEXT_SKILL_DIR"
mkdir -p "$VERTEXT_SKILL_DIR"

cat << 'EOF' > "$VERTEXT_SKILL_DIR/SKILL.md"
# Skill: GCP Vertex AI Model & Credentials Configuration

## Description
Provides explicit, verified guidelines for configuring `google-antigravity` agents to connect to Google Cloud Vertex AI APIs, resolve project/credential discrepancies, and select active models under the DACH Summit workshop sandbox.

---

## 1. Vertex AI Initialization & Project Resolution
In standard VM environments (e.g., Cloud Workstations), multiple project IDs might exist (e.g., quota project vs. resource project). 
To ensure the agent has authorization to make Vertex AI API calls, always initialize the `LocalAgentConfig` by programmatically resolving the active Google Cloud project and setting the region:

```python
import os
import subprocess

def get_active_project_id():
    # 1. Check environment variable
    project_id = os.environ.get("GOOGLE_CLOUD_PROJECT")
    if project_id:
        return project_id
    # 2. Fallback to active gcloud configuration
    try:
        result = subprocess.run(
            ["gcloud", "config", "get-value", "project"],
            capture_output=True,
            text=True,
            check=True
        )
        return result.stdout.strip()
    except Exception:
        return None

# Resolve credentials context
PROJECT_ID = get_active_project_id()
LOCATION = "us-central1" # Primary Vertex AI API region for this workshop
```

---

## 2. Verified Model Selection
When running in GCP Vertex AI mode, use these active model identifiers. Avoid guessing or trying external AI Studio formats:

- **Primary Model (High speed & efficiency):** `gemini-1.5-flash`
- **Advanced Model (Complex reasoning):** `gemini-1.5-pro`

---

## 3. Agent Setup Scaffold (FastAPI Backend integration)
Implement the `LocalAgentConfig` inside `app.py` using this verified pattern:

```python
from google.antigravity import Agent, LocalAgentConfig

config = LocalAgentConfig(
    model="gemini-1.5-flash", # Verified Vertex AI model name
    project=PROJECT_ID,        # Dynamically resolved active sandbox project
    location="us-central1",    # Vertex AI endpoint location
)
```

---

## 4. GCP Billing & Routing Projects (403 Forbidden Workaround)
In shared GCP sandbox environments, user credentials can reside in a default quota project that differs from the actual resource project (e.g., where Spanner is hosted).
To bypass `403 Forbidden` errors during tool or model executions, explicitly pass the active `PROJECT_ID` inside the `X-Goog-User-Project` and `Google-Cloud-Project` headers in your HTTP client requests to the Spanner MCP server:

```python
headers = {
    "X-Goog-User-Project": PROJECT_ID,
    "Google-Cloud-Project": PROJECT_ID,
    "Authorization": f"Bearer {OAUTH_TOKEN}"
}
```

---

## 5. MCP Connection & Session Lifecycle Management
To avoid Pydantic validation collisions, `TaskGroup` sub-exceptions, or `Connection closed` errors across multiple client threads or fallbacks:
- Always instantiate **fresh, separate client sessions** or MCP stream servers for distinct model calls or fallback runs.
- Never reuse the same closed `McpStreamableHttpServer` or client instance across sequential Agent lifecycles.
```
EOF

echo "Vertex AI configuration skill successfully generated!"
echo "Target skill updated:"
echo " - $VERTEXT_SKILL_DIR/SKILL.md"

