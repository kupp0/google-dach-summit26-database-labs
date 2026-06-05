# Lab 3: Swiss Property Search: Fullstack AI App with AlloyDB & Gemini Data Analytics QueryData

In this lab, you will build and deploy a premium real-estate search application that showcases natural language search capabilities using **AlloyDB** and the **Gemini Data Analytics (GDA) QueryData API**. 

The application utilizes a single stateless architecture:
1. **Search Bar**: Sends natural language queries directly to the GDA `/queryData` API to generate SQL, natural language summaries, and intent explanations.
2. **AI Agent Chat**: A conversational interface powered by the Google Antigravity (ADK) SDK, loading the `cloud_gda_query_tool_alloydb` tool to allow multi-turn questions and refined searches.

---

## Objective
- Set up the database schema and populate sample records in AlloyDB.
- Generate visual listing images and vectors natively in the workspace environment.
- Create and register a Gemini Data Analytics (GDA) **Context Set** for AlloyDB schema mapping.
- Run and debug the stateless backend, frontend, agent, and toolbox containers locally.
- Deploy the entire system to serverless Google Cloud Run.

---

## Phase 1: Architecture & Workspace Setup

### 1. Open the Workspace Folder in Cloud Workstations
1. In your Cloud Workstation window, select **File** -> **Open Folder**.
2. Type `/home/user/lab03_swiss_property_search` and click **OK**.
3. Open a terminal by selecting **Terminal** -> **New Terminal** (or use the shortcut `Ctrl+Shift+C`).

### 2. Workspace File Architecture
Your workspace `/home/user/lab03_swiss_property_search` contains:
* `alloydb-artefacts/`: Database initialization SQL scripts, context JSON mapping, and image bootstrap scripts.
* `backend/`: FastAPI backend (`main.py`), Agent orchestration, and MCP server configuration files.
* `frontend/`: React + Vite frontend application source code.
* `deploy.sh`: Deploys all services (Backend, Frontend, and Agent/Toolbox sidecar) to Cloud Run.
* `debug_local.sh`: Runs the application stack locally for debugging.

### 3. Initialize your Environment and Permissions
Before executing database scripts or tunnels, run the initialization script to authorize IAP SSH tunneling to the Bastion host:
```bash
cd ~/lab03_swiss_property_search
bash init.sh
```
*(This installs base requirements and grants your active user account `roles/iap.tunnelResourceAccessor` permissions on the GCP project).*

---

## Phase 2: Database Setup & Data Ingestion

### 1. Database Setup & SQL Initialization
1. Navigate to **AlloyDB** -> **Clusters** in the Cloud Console.
2. Select your cluster `search-cluster` and click on primary instance `search-primary`.
3. In the left panel, click **AlloyDB Studio** and sign in using database `postgres` and password `alloydb-hackathon-password`.
4. Open a new query tab, copy and run the contents of `alloydb-artefacts/alloydb_setup.sql` to initialize the `property_listings` table.
5. Open a second query tab, copy and run the contents of `alloydb-artefacts/100 _sample records.sql` to populate sample listings.
6. Open a third query tab, copy and run the contents of `alloydb-artefacts/alloydb_indexes.sql` to build the vector and ScaNN nearest neighbor indexes.
7. Run this validation query to verify the records populate successfully (should return ~320):
   ```sql
   SELECT count(*) as property_count FROM "search".property_listings;
   ```

### 2. Generate Images and Multimodal Embeddings
Natively generate visual listing images and calculate embeddings using Vertex AI Imagen:
1. Open a terminal in Cloud Workstations and start the database proxy:
   ```bash
   cd ~/lab03_swiss_property_search/alloydb-artefacts
   bash run_proxy.sh
   ```
   *(Keep this terminal open to maintain the database connection tunnel).*
2. Open a **New Terminal tab/window** in the editor and execute the generator:
   ```bash
   cd ~/lab03_swiss_property_search/alloydb-artefacts
   python3 bootstrap_images.py
   ```
   *(This script connects to AlloyDB, generates visual listings using Imagen, uploads them to your GCS bucket, computes visual embeddings, and updates the database).*
3. Once completed, return to the first terminal window and stop the proxy by pressing `Ctrl+C`.

---

## Phase 3: Registering Gemini Data Analytics Context Set

GDA uses Context Sets to map table structure to natural language concepts, parameterize templates, and fuzzy match values (e.g. cities/cantons).

1. In the Google Cloud Console, search for **Gemini Data Analytics** or **Data Agents**.
2. Go to the **Context Sets** panel and click **Create Context Set**.
3. Upload the file `/home/user/lab03_swiss_property_search/alloydb-artefacts/alloydb_context.json`.
   
   > [!NOTE]
   > If you see a warning/error in the console stating: **"To use this feature, enable data_api_access for this instance."**, you can manually enable it by running this command in your Cloud Workstation terminal:
   > ```bash
   > curl -X PATCH \
   >   -H "Authorization: Bearer \$(gcloud auth print-access-token)" \
   >   -H "Content-Type: application/json" \
   >   "https://alloydb.googleapis.com/v1alpha/projects/<PROJECT_ID>/locations/<REGION>/clusters/<CLUSTER_ID>/instances/<INSTANCE_ID>?updateMask=dataApiAccess" \
   >   -d '{"dataApiAccess": "ENABLED"}'
   > ```
   > *(Replace `<PROJECT_ID>`, `<REGION>`, `<CLUSTER_ID>`, and `<INSTANCE_ID>` with your project details, e.g. `dach-databases26fra-3901`, `europe-west3`, `search-cluster`, and `search-primary`)*

4. Once created, copy the generated **Context Set ID** (a UUID or string identifier).
5. Open the environment file `backend/.env` in the workstation editor.
6. Update the variable `AGENT_CONTEXT_SET_ID_ALLOYDB` with your copied Context Set ID:
   ```env
   AGENT_CONTEXT_SET_ID_ALLOYDB=your_copied_context_set_id
   ```
7. Save the file.

---

## Phase 4: Deploying and Running the Application

### 1. Run and Debug the Application Locally
To run and debug the entire application locally in your workstation environment:
1. In the terminal, run the local debug script:
   ```bash
   cd ~/lab03_swiss_property_search
   bash debug_local.sh
   ```
   *(This starts the remote proxy tunnel, builds the local docker images, and spins up the backend, frontend, agent, and toolbox containers. Keep this terminal open).*
2. Copy the local frontend address `http://localhost:8081` (or click on the port 8081 popup in the bottom right of the workstation window) to access the application UI. Verify that **Natural Language Search** and **AI Agent Chat** are functional.
3. Press `Ctrl+C` in the terminal when you are ready to stop the containers and proxy.

### 2. Deploy to Cloud Run
To push the application live to serverless Cloud Run:
1. In the terminal, run the deployment shell script:
   ```bash
   cd ~/lab03_swiss_property_search
   bash deploy.sh
   ```
   *(This builds container images via Cloud Build, creates/updates the tools secret in Secret Manager, and deploys 3 services: backend, frontend, and agent (with toolbox sidecar) to Cloud Run).*
2. Once the script finishes, copy the output **Frontend URL** and open it in your browser to verify functionality.

---

## Phase 5: Hands-On Agentic Coding Challenges (ADK CLI)

Now use the **ADK CLI (agy)** or your AI Assistant inside the workspace `/home/user/lab03_swiss_property_search` to expand and style the application.

### Challenge 1: Architecture Exploration & UML Generation
- **Prompt**: *"Analyze this repository, provide a concise directory summary, and visualize the message flow of a search query through the system with a PlantUML sequence diagram. Save the diagram source as PlantUML and render it as a PNG."*

### Challenge 2: Apply Premium Branding (Swiss Red)
- **Prompt**: *"Please change the color scheme of the frontend application in the repository to Swiss Red. Consider background colors, secondary highlights, button states, dark mode, and light mode. Ensure all modifications conform to vanilla CSS standard styles."*

### Challenge 3: Flashy Row-Count Success Popup
- **Prompt**: *"Modify the frontend results-handling logic. Post-QueryData success, extract the exact row count returned in the GDA response. Display an animated 10-second 'flashy' rainbow-colored congratulatory popup celebrating the returned row count."*

---

## Troubleshooting

* **Ask your AI Assistant (`agy` CLI)**: If you get stuck on any coding challenge, or if you need clarification on how the backend connects to Gemini Data Analytics, you can ask questions directly in your active `agy` CLI session (e.g., *"Explain how the GDA QueryData endpoint works in main.py"* or *"Help me implement the rainbow celebratory popup in App.jsx"*).

### IAP Tunneling and Firewall Connectivity Issues
If the Auth Proxy script (`run_proxy.sh`) fails to connect:
```bash
# Allow Ingress TCP traffic from Google's IAP range in the VPC network
gcloud compute firewall-rules create allow-ssh-ingress-from-iap \
  --network=workstation-network \
  --source-ranges=35.235.240.0/20 \
  --allow=tcp:22
```
