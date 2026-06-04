# Lab 3: Swiss Property Search: Fullstack AI App with AlloyDB & Gemini Agent Platform (formerly VertexAI)

In this track, you will build and deploy a premium real-estate search application that showcases three different ways to execute AI-powered semantic and relational searches. The entire project was vibe-coded from scratch using Gemini and uses **AlloyDB**, **Gemini Agent Platform (formerly VertexAI)**, and **Gemini Data Analytics Query Data Tool** as its core backend.

---

## Objective
- Ingest property listings and automate the generation of multimodal image embeddings natively in AlloyDB.
- Deploy the frontend client and backend query services (FastAPI, MCP Server, Agent) to Cloud Run.
- Configure a Vertex AI Search Data Store to index and query records from AlloyDB.
- Complete hands-on **ADK CLI Coding Challenges** to modify, style, and enhance the application in real-time.

---

## Phase 1: Architecture & Workspace Setup

### 1. Open the Workspace Folder in Cloud Workstations
1. In your Cloud Workstation window, select **File** -> **Open Folder**.
2. Type `/home/user/lab03_swiss_property_search` and click **OK**.
3. Open a terminal by selecting **Terminal** -> **New Terminal** (or use the shortcut `Ctrl+Shift+C`).

### 2. Workspace File Architecture
Your workspace `/home/user/lab03_swiss_property_search` contains:
* `alloydb-artefacts/`: Database initialization SQL scripts and python bootstrap scripts.
* `backend/`: FastAPI backend (`main.py`), Agent orchestration, and MCP server config files.
* `frontend/`: React + Vite + Tailwind CSS frontend application source code.
* `deploy.sh`: Builds and deploys all services to Cloud Run.
* `debug_local.sh`: Tunnels to AlloyDB for local debugging/runs.

### 3. Initialize your Environment and Permissions
Before executing database scripts or tunnels, run the initialization script to authorize IAP SSH tunneling to the Bastion host:
```bash
cd ~/lab03_swiss_property_search
bash init.sh
```
*(This installs base requirements and grants your active user account `roles/iap.tunnelResourceAccessor` permissions on the GCP project).*

---

## Phase 2: Database Setup & Data Ingestion

### 1. Insert Schema & Sample Records
1. Navigate to **AlloyDB** -> **Clusters** in the Cloud Console.
2. Select your cluster `search-cluster` and click on primary instance `search-primary`.
3. In the left panel, click **AlloyDB Studio** and sign in using database `postgres` and password `alloydb-hackathon-password`.
4. Open a new query tab, copy and run the contents of `alloydb-artefacts/alloydb_setup.sql` to initialize the `property_listings` table.
5. Open a second query tab, copy and run the contents of `alloydb-artefacts/100 _sample records.sql` to populate sample listings.

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
   *(This script connects to AlloyDB, generates visual listings using Imagen, uploads them to your GCS bucket, computes visual embeddings, and updates the database. All python dependencies were installed in Phase 1).*
3. Once completed, return to the first terminal window and stop the proxy by pressing `Ctrl+C`.

### 3. Create Vector Indexes & Natural Language Querying (NLQ)
1. Return to **AlloyDB Studio**.
2. Run this query to verify data population (the result should be ~118):
   ```sql
   SELECT count(*) as property_count FROM "search".property_listings;
   ```
3. Copy and run the contents of `alloydb-artefacts/alloydb_indexes.sql` to build ScaNN approximate nearest neighbor indexes.
4. Copy and run the contents of `alloydb-artefacts/alloydb_ai_nl_setup.sql` to register the natural language query translation interface.

---

## Phase 3: Deploying and Running the Application

### 1. Verify Local Environment Configuration
The backend environment configuration file `backend/.env` is generated automatically when you run `bash init.sh` in Phase 1.

1. Open `/home/user/lab03_swiss_property_search/backend/.env` in Code-OSS to verify its contents.
2. Confirm that `GCP_PROJECT_ID` and `INSTANCE_CONNECTION_NAME` have been resolved correctly to your project's AlloyDB cluster.

### 2. Deploy to Cloud Run
1. In the terminal, run the deployment shell script:
   ```bash
   cd ~/lab03_swiss_property_search
   bash deploy.sh
   ```
   *(This builds Docker images via Cloud Build and deploys 4 services: backend query api, MCP toolbox server, agent engine, and frontend UI to Cloud Run).*
2. Once the script finishes, copy the output **Frontend URL** and open it in your browser. Verify that **AlloyDB NL** and **Semantic Search** are functional.

---

## Phase 4: Integrating Vertex AI Search (Data Store)

Wire up the third search modality by indexing AlloyDB records directly into Vertex AI Search:

1. Navigate to **Vertex AI Search -> Data Stores** in the Cloud Console.
2. Click **Create data store** and select **AlloyDB** as the data source.
3. Configure the source connection settings:
   - **Project ID**: Your active GCP Project ID.
   - **Location ID**: `europe-west1` (or your active resource region).
   - **Cluster ID**: `search-cluster`
   - **Database ID**: `postgres`
   - **Table ID**: `search.property_listings`
4. Click **Continue**, select location `global`, and set the Data Store Name to `property-listings-ds`.
5. **Important**: Click the "Edit" link below the name field and change the Data Store ID to exactly `property-listings-ds`. Click **Create**.
6. Navigate to **Apps** in the Gen App Builder console, click **Create App**, select **Custom search (general)**.
7. Enter `search-app` and `company` for the names, click continue, check the box next to `property-listings-ds`, and click create.
8. Once documents are indexed, return to your deployed application and test the **Vertex AI Search** tab!

---

## Phase 5: Hands-On Agentic Coding Challenges (ADK CLI)

Now use the **ADK CLI (agy)** or your AI Assistant inside the workspace `/home/user/lab03_swiss_property_search` to expand and style the application.

### Challenge 1: Architecture Exploration & UML Generation
- **Prompt**: *"Analyze this repository, provide a concise directory summary, and visualize the message flow of a search query through the system with a PlantUML sequence diagram. Save the diagram source as PlantUML and render it as a PNG."*

### Challenge 2: Apply Premium Branding (Swiss Red)
- **Prompt**: *"Please change the color scheme of the frontend application in the repository to Swiss Red. Consider background colors, secondary highlights, button states, dark mode, and light mode. Ensure all modifications conform to vanilla CSS standard styles."*

### Challenge 3: Flashy Row-Count Success Popup
- **Prompt**: *"Modify the frontend results-handling logic. Post-QueryData success, extract the exact row count returned in the API response. Display an animated 10-second 'flashy' rainbow-colored congratulatory popup celebrating the returned row count."*

---

## Troubleshooting

### IAP Tunneling and Firewall Connectivity Issues
If the Auth Proxy script (`run_proxy.sh`) fails to connect:
```bash
# Allow Ingress TCP traffic from Google's IAP range in the VPC network
gcloud compute firewall-rules create allow-ssh-ingress-from-iap \
  --network=workstation-network \
  --source-ranges=35.235.240.0/20 \
  --allow=tcp:22
```
