# Lab 2: Disneyland Agentic Codelab with Cloud Spanner & BigQuery

In this lab, you will build a zero-copy federated analytical "bridge" linking **Cloud Spanner** and **BigQuery**. This allows real-time analytic queries across transactional and warehouse data. Then, you'll deploy the **MCP Toolbox** to grant agentic AI tools the ability to query your transactional database in real-time.

---

## Objective
- Deploy Cloud Spanner, BigQuery dataset, and BigQuery Connection infrastructure using Terraform.
- Establish an external dataset mapping to automatically federate Cloud Spanner tables into BigQuery.
- Inject a rich Disneyland attraction dataset containing vector embeddings via Spanner Studio.
- Configure and verify the **MCP Toolbox** for agentic AI integration.
- Run verification federated queries in BigQuery Studio.

---

## Phase 1: Environment Setup

### 1. Create Workspace Directory
Run these commands to prepare a clean workspace:

```bash
# Create and enter a clean project directory
mkdir my-terraform-project && cd my-terraform-project

# Create the two required Terraform configuration files
touch main.tf outputs.tf
```

---

## Phase 2: Infrastructure Provisioning (Terraform)

### 1. Populate `main.tf`
Open `main.tf` in your editor (e.g., `nano main.tf`), paste the following configuration, and save:

```terraform
# ==============================================================================
# 0. Terraform Configuration & Variables
# ==============================================================================
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0"
    }
    time = {
      source  = "hashicorp/time"
      version = ">= 0.11.0"
    }
  }
}

variable "project_id" {
  description = "The Google Cloud Project ID"
  type        = string
}

provider "google" {
  project = var.project_id
  region  = "europe-west1"
}

# ==============================================================================
# 1. Enable Required APIs
# ==============================================================================
resource "google_project_service" "enabled_apis" {
  for_each = toset([
    "spanner.googleapis.com",
    "bigquery.googleapis.com",
    "bigqueryconnection.googleapis.com"
  ])
  project            = var.project_id
  service            = each.key
  disable_on_destroy = false
}

# ==============================================================================
# 2. Cloud Spanner Setup
# ==============================================================================
resource "google_spanner_instance" "disneyland" {
  name             = "disneyland"
  config           = "regional-europe-west1"
  display_name     = "Disneyland AI Agents"
  edition          = "ENTERPRISE"
  processing_units = 100
  depends_on       = [google_project_service.enabled_apis]
}

resource "google_spanner_database" "agent_lab" {
  instance            = google_spanner_instance.disneyland.name
  name                = "agent-lab"
  database_dialect    = "GOOGLE_STANDARD_SQL"
  deletion_protection = false
}

# ==============================================================================
# 3. BigQuery Setup & Connection
# ==============================================================================
resource "google_bigquery_dataset" "disney_dataset" {
  dataset_id = "disney"
  location   = "europe-west1"
  depends_on = [google_project_service.enabled_apis]
}

resource "google_bigquery_connection" "spanner_conn" {
  connection_id = "spanner_conn"
  location      = "europe-west1"
  friendly_name = "Spanner Connector"
  cloud_resource {}
  depends_on    = [google_project_service.enabled_apis]
}

# Mitigates GCP's global directory registration delay for new service accounts
resource "time_sleep" "wait_for_connection_sa" {
  create_duration = "15s"
  depends_on      = [google_bigquery_connection.spanner_conn]
}

# ==============================================================================
# 4. Authoritative IAM Admin Permissions (Simplified Integration)
# ==============================================================================
resource "google_project_iam_binding" "spanner_admin_bridge" {
  project = var.project_id
  role    = "roles/spanner.admin" # <-- Grants combined metadata schema + full database row read access
  members = ["serviceAccount:${google_bigquery_connection.spanner_conn.cloud_resource[0].service_account_id}"]
  
  depends_on = [time_sleep.wait_for_connection_sa]
}

# Holds final bridge linking to give global control plane caching time to sync
resource "time_sleep" "wait_for_iam" {
  create_duration = "45s"
  depends_on      = [google_project_iam_binding.spanner_admin_bridge]
}

# ==============================================================================
# 5. BigQuery External Dataset (The Spanner Bridge)
# ==============================================================================
resource "google_bigquery_dataset" "spanner_external_dataset" {
  dataset_id  = "disneyland_spanner_external"
  location    = "europe-west1"
  
  external_dataset_reference {
    external_source = "google-cloudspanner:/projects/${var.project_id}/instances/${google_spanner_instance.disneyland.name}/databases/${google_spanner_database.agent_lab.name}"
    connection      = google_bigquery_connection.spanner_conn.id
  }
  
  depends_on = [time_sleep.wait_for_iam]
}
```

### 2. Populate `outputs.tf`
Open `outputs.tf` in your editor, paste the following configuration, and save:

```terraform
output "spanner_instance_id" {
  value       = google_spanner_instance.disneyland.id
  description = "The fully qualified unique identifier for the Spanner Instance."
}

output "bq_spanner_connection_id" {
  value       = google_bigquery_connection.spanner_conn.id
  description = "The unique identification path for the BigQuery External Connection."
}

output "mcp_verify_command" {
  value       = "gcloud mcp-toolbox list-resources --project=${var.project_id} --location=europe-west1"
  description = "The terminal verification command for students to validate their Model Context Protocol service registry."
}
```
---

## Phase 3: Deploying Infrastructure

Run these shell commands inside your `my-terraform-project` folder:

```bash
# 1. Initialize Terraform Providers
terraform init

# 2. Review the Execution Plan
terraform plan

# 3. Apply changes and deploy resources
terraform apply
```
*(Type `yes` when prompted to confirm the deployment).*

---

## Phase 4: Schema Creation & Data Injection

Once Terraform successfully completes the deployment, populate the transactional database:

1. Go to the **Cloud Spanner** page in the Google Cloud Console.
2. Click on your Spanner instance **`disneyland`**, and then select database **`agent-lab`**.
3. In the left sidebar, click **Spanner Studio**.
4. Open a new query tab, paste the SQL script below, and click **Run**:

```sql
-- 1. Create DisneylandPark Table
CREATE TABLE DisneylandPark (
  ParkID INT64 NOT NULL,
  Name STRING(255) NOT NULL,
  Location STRING(255) NOT NULL
) PRIMARY KEY (ParkID);

-- 2. Create Attraction Table (with Vector Embedding field)
CREATE TABLE Attraction (
  AttractionID INT64 NOT NULL GENERATED BY DEFAULT AS IDENTITY (BIT_REVERSED_POSITIVE),
  ParkID INT64 NOT NULL,
  Name STRING(255) NOT NULL,
  Land STRING(100) NOT NULL,
  Type STRING(50) NOT NULL,
  Description STRING(MAX),
  Embedding ARRAY<FLOAT32>(vector_length=>3072)
) PRIMARY KEY (AttractionID);

ALTER TABLE Attraction ADD CONSTRAINT FK_Park FOREIGN KEY (ParkID) REFERENCES DisneylandPark(ParkID);

-- 3. Create Path Table (for graph routing/navigation)
CREATE TABLE Path (
  SourceAttractionID INT64 NOT NULL,
  TargetAttractionID INT64 NOT NULL,
  DistanceMeters INT64 NOT NULL,
  CONSTRAINT FK_SourceAttraction FOREIGN KEY (SourceAttractionID) REFERENCES Attraction(AttractionID),
  CONSTRAINT FK_TargetAttraction FOREIGN KEY (TargetAttractionID) REFERENCES Attraction(AttractionID)
) PRIMARY KEY (SourceAttractionID, TargetAttractionID);

-- 4. Insert DisneylandPark Records
INSERT INTO DisneylandPark (ParkID, Name, Location) VALUES (1, 'Disneyland Park (Paris)', 'Paris, France');
INSERT INTO DisneylandPark (ParkID, Name, Location) VALUES (2, 'Walt Disney Studios Park', 'Paris, France');
INSERT INTO DisneylandPark (ParkID, Name, Location) VALUES (3, 'Disneyland Park (California)', 'Anaheim, USA');
INSERT INTO DisneylandPark (ParkID, Name, Location) VALUES (4, 'Disney California Adventure Park', 'Anaheim, USA');
INSERT INTO DisneylandPark (ParkID, Name, Location) VALUES (5, 'Tokyo Disneyland', 'Tokyo, Japan');

-- 5. Insert Attraction Records
INSERT INTO Attraction (AttractionID, ParkID, Name, Land, Type, Description) VALUES (1, 1, 'Disneyland Railroad Station', 'Main Street, U.S.A.', 'Transport', 'Board a vintage steam train for a scenic journey around the park.');
INSERT INTO Attraction (AttractionID, ParkID, Name, Land, Type, Description) VALUES (2, 1, 'Horse-Drawn Streetcars', 'Main Street, U.S.A.', 'Transport', 'Enjoy a nostalgic ride down Main Street in a turn-of-the-century streetcar.');
INSERT INTO Attraction (AttractionID, ParkID, Name, Land, Type, Description) VALUES (3, 1, 'Main Street Vehicles', 'Main Street, U.S.A.', 'Transport', 'Travel in style aboard a variety of vintage vehicles, like a fire engine or omnibus.');
INSERT INTO Attraction (AttractionID, ParkID, Name, Land, Type, Description) VALUES (4, 1, 'Liberty Arcade', 'Main Street, U.S.A.', 'Walkthrough', 'A covered walkway chronicling the creation of the Statue of Liberty.');
INSERT INTO Attraction (AttractionID, ParkID, Name, Land, Type, Description) VALUES (5, 1, 'Discovery Arcade', 'Main Street, U.S.A.', 'Walkthrough', 'A covered walkway showcasing scale models of futuristic inventions.');
INSERT INTO Attraction (AttractionID, ParkID, Name, Land, Type, Description) VALUES (6, 1, 'Dapper Dans Hair Cuts', 'Main Street, U.S.A.', 'Service', 'An old-fashioned barber shop offering traditional haircuts and shaves.');
INSERT INTO Attraction (AttractionID, ParkID, Name, Land, Type, Description) VALUES (7, 1, 'Big Thunder Mountain', 'Frontierland', 'Thrill Ride', 'A thrilling roller coaster that speeds through a haunted gold-mining town.');
INSERT INTO Attraction (AttractionID, ParkID, Name, Land, Type, Description) VALUES (8, 1, 'Phantom Manor', 'Frontierland', 'Dark Ride', 'A mysterious and spooky tour of a haunted mansion with ghostly residents.');
INSERT INTO Attraction (AttractionID, ParkID, Name, Land, Type, Description) VALUES (9, 1, 'Thunder Mesa Riverboat Landing', 'Frontierland', 'Boat Ride', 'A relaxing cruise on a majestic 19th-century paddle steamer.');
INSERT INTO Attraction (AttractionID, ParkID, Name, Land, Type, Description) VALUES (10, 1, 'Rustler Roundup Shootin Gallery', 'Frontierland', 'Game', 'Test your aim in this Wild West-themed shooting gallery.');
INSERT INTO Attraction (AttractionID, ParkID, Name, Land, Type, Description) VALUES (11, 1, 'Legends of the Wild West', 'Frontierland', 'Walkthrough', 'A scenic path through a frontier fort with encounters of famous Wild West figures.');
INSERT INTO Attraction (AttractionID, ParkID, Name, Land, Type, Description) VALUES (12, 1, 'River Rogue Keelboats', 'Frontierland', 'Boat Ride', 'A rustic keelboat voyage around Big Thunder Mountain and the Wilderness.');
INSERT INTO Attraction (AttractionID, ParkID, Name, Land, Type, Description) VALUES (13, 1, 'Pocahontas Indian Village', 'Frontierland', 'Playground', 'An outdoor play area for children, inspired by Native American culture.');
INSERT INTO Attraction (AttractionID, ParkID, Name, Land, Type, Description) VALUES (15, 1, 'Disneyland Railroad Station', 'Frontierland', 'Transport', 'Board the Disneyland Railroad from the heart of the Wild West.');
INSERT INTO Attraction (AttractionID, ParkID, Name, Land, Type, Description) VALUES (16, 1, 'The Chaparral Theater', 'Frontierland', 'Show', 'A large theater hosting spectacular live stage shows with Disney characters.');
INSERT INTO Attraction (AttractionID, ParkID, Name, Land, Type, Description) VALUES (17, 1, 'Pirates of the Caribbean', 'Adventureland', 'Boat Ride', 'A swashbuckling boat adventure through pirate-infested waters.');
INSERT INTO Attraction (AttractionID, ParkID, Name, Land, Type, Description) VALUES (18, 1, 'Indiana Jones and the Temple of Peril', 'Adventureland', 'Thrill Ride', 'A high-speed mine cart coaster through ancient jungle ruins.');
INSERT INTO Attraction (AttractionID, ParkID, Name, Land, Type, Description) VALUES (19, 1, 'Adventure Isle', 'Adventureland', 'Walkthrough', 'Explore a mysterious island full of caves, suspension bridges, and hidden treasures.');
INSERT INTO Attraction (AttractionID, ParkID, Name, Land, Type, Description) VALUES (20, 1, 'La Cabane des Robinson', 'Adventureland', 'Walkthrough', 'Climb the towering treehouse home of the Swiss Family Robinson.');
INSERT INTO Attraction (AttractionID, ParkID, Name, Land, Type, Description) VALUES (21, 1, 'Le Passage Enchanté dAladdin', 'Adventureland', 'Walkthrough', 'A walkthrough attraction depicting scenes from Disneys Aladdin.');
INSERT INTO Attraction (AttractionID, ParkID, Name, Land, Type, Description) VALUES (22, 1, 'La Plage des Pirates', 'Adventureland', 'Playground', 'A pirate-themed adventure playground for young buccaneers.');
INSERT INTO Attraction (AttractionID, ParkID, Name, Land, Type, Description) VALUES (23, 1, 'Le Château de la Belle au Bois Dormant', 'Fantasyland', 'Icon', 'The iconic Sleeping Beauty Castle, the centerpiece of Disneyland Park.');
INSERT INTO Attraction (AttractionID, ParkID, Name, Land, Type, Description) VALUES (24, 1, 'La Galerie de la Belle au Bois Dormant', 'Fantasyland', 'Walkthrough', 'Discover the story of Sleeping Beauty through stained glass and tapestries inside the castle.');
INSERT INTO Attraction (AttractionID, ParkID, Name, Land, Type, Description) VALUES (25, 1, 'La Tanière du Dragon', 'Fantasyland', 'Walkthrough', 'Venture into the dungeon beneath the castle to find a slumbering dragon.');
INSERT INTO Attraction (AttractionID, ParkID, Name, Land, Type, Description) VALUES (26, 1, 'its a small world', 'Fantasyland', 'Boat Ride', 'A gentle boat ride featuring singing dolls from all corners of the globe.');
INSERT INTO Attraction (AttractionID, ParkID, Name, Land, Type, Description) VALUES (27, 1, 'Peter Pans Flight', 'Fantasyland', 'Dark Ride', 'Soar over London and Never Land in a magical pirate galleon.');
INSERT INTO Attraction (AttractionID, ParkID, Name, Land, Type, Description) VALUES (28, 1, 'Blanche-Neige et les Sept Nains', 'Fantasyland', 'Dark Ride', 'Journey through the story of Snow White and the Seven Dwarfs.');
INSERT INTO Attraction (AttractionID, ParkID, Name, Land, Type, Description) VALUES (29, 1, 'Les Voyages de Pinocchio', 'Fantasyland', 'Dark Ride', 'Follow Pinocchio on his daring journey to become a real boy.');
INSERT INTO Attraction (AttractionID, ParkID, Name, Land, Type, Description) VALUES (30, 1, 'Dumbo the Flying Elephant', 'Fantasyland', 'Family Ride', 'Fly high above Fantasyland on your very own Dumbo.');
INSERT INTO Attraction (AttractionID, ParkID, Name, Land, Type, Description) VALUES (31, 1, 'Le Carrousel de Lancelot', 'Fantasyland', 'Family Ride', 'A classic carousel with beautifully decorated horses.');
INSERT INTO Attraction (AttractionID, ParkID, Name, Land, Type, Description) VALUES (32, 1, 'Mad Hatters Tea Cups', 'Fantasyland', 'Family Ride', 'Spin round and round in a giant teacup at a mad tea party.');
INSERT INTO Attraction (AttractionID, ParkID, Name, Land, Type, Description) VALUES (33, 1, 'Alices Curious Labyrinth', 'Fantasyland', 'Walkthrough', 'Get lost in a whimsical maze inspired by Alice in Wonderland.');
INSERT INTO Attraction (AttractionID, ParkID, Name, Land, Type, Description) VALUES (34, 1, 'Le Pays des Contes de Fées', 'Fantasyland', 'Boat Ride', 'A gentle boat trip through miniature scenes from classic Disney fairy tales.');
INSERT INTO Attraction (AttractionID, ParkID, Name, Land, Type, Description) VALUES (35, 1, 'Casey Jr. – le Petit Train du Cirque', 'Fantasyland', 'Family Ride', 'A charming little circus train that circles Storybook Land.');
INSERT INTO Attraction (AttractionID, ParkID, Name, Land, Type, Description) VALUES (36, 1, 'Disneyland Railroad Station', 'Fantasyland', 'Transport', 'Catch the steam train from the whimsical world of Fantasyland.');
INSERT INTO Attraction (AttractionID, ParkID, Name, Land, Type, Description) VALUES (37, 1, 'Meet Mickey Mouse', 'Fantasyland', 'Meet and Greet', 'Meet the one and only Mickey Mouse backstage at his theater.');
INSERT INTO Attraction (AttractionID, ParkID, Name, Land, Type, Description) VALUES (38, 1, 'Princess Pavilion', 'Fantasyland', 'Meet and Greet', 'Have a royal encounter with a Disney Princess in an enchanted setting.');
INSERT INTO Attraction (AttractionID, ParkID, Name, Land, Type, Description) VALUES (39, 1, 'Le théâtre du Château', 'Fantasyland', 'Show', 'An outdoor stage in front of the castle featuring musical performances.');
INSERT INTO Attraction (AttractionID, ParkID, Name, Land, Type, Description) VALUES (40, 1, 'Star Wars Hyperspace Mountain', 'Discoveryland', 'Thrill Ride', 'A high-speed roller coaster adventure through a Star Wars space battle.');
INSERT INTO Attraction (AttractionID, ParkID, Name, Land, Type, Description) VALUES (41, 1, 'Buzz Lightyear Laser Blast', 'Discoveryland', 'Interactive Ride', 'Help Buzz Lightyear defeat Emperor Zurg in this interactive space shooter.');
INSERT INTO Attraction (AttractionID, ParkID, Name, Land, Type, Description) VALUES (42, 1, 'Orbitron - Machines Volantes', 'Discoveryland', 'Family Ride', 'Pilot your own retro-futuristic spaceship as it orbits a giant planet model.');
INSERT INTO Attraction (AttractionID, ParkID, Name, Land, Type, Description) VALUES (43, 1, 'Star Tours: The Adventures Continue', 'Discoveryland', 'Simulator', 'A thrilling 3D motion-simulated space flight to different Star Wars planets.');
INSERT INTO Attraction (AttractionID, ParkID, Name, Land, Type, Description) VALUES (44, 1, 'Starport', 'Discoveryland', 'Meet and Greet', 'Encounter a mighty character from the Star Wars saga.');
INSERT INTO Attraction (AttractionID, ParkID, Name, Land, Type, Description) VALUES (45, 1, 'Discoveryland Theatre', 'Discoveryland', 'Show', 'A theater presenting seasonal shows and 3D film experiences.');
INSERT INTO Attraction (AttractionID, ParkID, Name, Land, Type, Description) VALUES (46, 1, 'Autopia', 'Discoveryland', 'Family Ride', 'Drive your own futuristic car along a winding track.');
INSERT INTO Attraction (AttractionID, ParkID, Name, Land, Type, Description) VALUES (47, 1, 'Les Mystères du Nautilus', 'Discoveryland', 'Walkthrough', 'Explore Captain Nemos legendary submarine from 20,000 Leagues Under the Sea.');
INSERT INTO Attraction (AttractionID, ParkID, Name, Land, Type, Description) VALUES (48, 1, 'Disneyland Railroad Station', 'Discoveryland', 'Transport', 'The final stop for the Disneyland Railroad, located in the land of tomorrow.');
INSERT INTO Attraction (AttractionID, ParkID, Name, Land, Type, Description) VALUES (49, 1, 'Arcade Alpha & Arcade Bêta', 'Discoveryland', 'Arcade', 'A video game arcade with a mix of classic and modern games.');
INSERT INTO Attraction (AttractionID, ParkID, Name, Land, Type, Description) VALUES (50, 1, 'Videopolis Theatre', 'Discoveryland', 'Show', 'A huge indoor venue for live shows, often with a nearby restaurant.');

-- 6. Insert Path Records
INSERT INTO Path (SourceAttractionID, TargetAttractionID, DistanceMeters) VALUES (1, 2, 70);
INSERT INTO Path (SourceAttractionID, TargetAttractionID, DistanceMeters) VALUES (1, 3, 60);
INSERT INTO Path (SourceAttractionID, TargetAttractionID, DistanceMeters) VALUES (2, 1, 70);
INSERT INTO Path (SourceAttractionID, TargetAttractionID, DistanceMeters) VALUES (2, 4, 80);
INSERT INTO Path (SourceAttractionID, TargetAttractionID, DistanceMeters) VALUES (2, 6, 50);
INSERT INTO Path (SourceAttractionID, TargetAttractionID, DistanceMeters) VALUES (3, 1, 60);
INSERT INTO Path (SourceAttractionID, TargetAttractionID, DistanceMeters) VALUES (3, 5, 80);
INSERT INTO Path (SourceAttractionID, TargetAttractionID, DistanceMeters) VALUES (3, 6, 50);
INSERT INTO Path (SourceAttractionID, TargetAttractionID, DistanceMeters) VALUES (4, 2, 80);
INSERT INTO Path (SourceAttractionID, TargetAttractionID, DistanceMeters) VALUES (4, 6, 40);
INSERT INTO Path (SourceAttractionID, TargetAttractionID, DistanceMeters) VALUES (4, 11, 140);
INSERT INTO Path (SourceAttractionID, TargetAttractionID, DistanceMeters) VALUES (4, 21, 120);
INSERT INTO Path (SourceAttractionID, TargetAttractionID, DistanceMeters) VALUES (5, 3, 80);
INSERT INTO Path (SourceAttractionID, TargetAttractionID, DistanceMeters) VALUES (5, 6, 40);
INSERT INTO Path (SourceAttractionID, TargetAttractionID, DistanceMeters) VALUES (5, 23, 100);
INSERT INTO Path (SourceAttractionID, TargetAttractionID, DistanceMeters) VALUES (5, 42, 100);
INSERT INTO Path (SourceAttractionID, TargetAttractionID, DistanceMeters) VALUES (6, 2, 50);
INSERT INTO Path (SourceAttractionID, TargetAttractionID, DistanceMeters) VALUES (6, 3, 50);
INSERT INTO Path (SourceAttractionID, TargetAttractionID, DistanceMeters) VALUES (6, 4, 40);
INSERT INTO Path (SourceAttractionID, TargetAttractionID, DistanceMeters) VALUES (6, 5, 40);
INSERT INTO Path (SourceAttractionID, TargetAttractionID, DistanceMeters) VALUES (7, 10, 100);
INSERT INTO Path (SourceAttractionID, TargetAttractionID, DistanceMeters) VALUES (7, 12, 60);
INSERT INTO Path (SourceAttractionID, TargetAttractionID, DistanceMeters) VALUES (7, 15, 80);
INSERT INTO Path (SourceAttractionID, TargetAttractionID, DistanceMeters) VALUES (8, 9, 70);
INSERT INTO Path (SourceAttractionID, TargetAttractionID, DistanceMeters) VALUES (8, 11, 90);
INSERT INTO Path (SourceAttractionID, TargetAttractionID, DistanceMeters) VALUES (9, 8, 70);
INSERT INTO Path (SourceAttractionID, TargetAttractionID, DistanceMeters) VALUES (9, 10, 60);
INSERT INTO Path (SourceAttractionID, TargetAttractionID, DistanceMeters) VALUES (10, 7, 100);
INSERT INTO Path (SourceAttractionID, TargetAttractionID, DistanceMeters) VALUES (10, 9, 60);
INSERT INTO Path (SourceAttractionID, TargetAttractionID, DistanceMeters) VALUES (10, 11, 50);
INSERT INTO Path (SourceAttractionID, TargetAttractionID, DistanceMeters) VALUES (11, 4, 140);
INSERT INTO Path (SourceAttractionID, TargetAttractionID, DistanceMeters) VALUES (11, 8, 90);
INSERT INTO Path (SourceAttractionID, TargetAttractionID, DistanceMeters) VALUES (11, 10, 50);
INSERT INTO Path (SourceAttractionID, TargetAttractionID, DistanceMeters) VALUES (12, 7, 60);
INSERT INTO Path (SourceAttractionID, TargetAttractionID, DistanceMeters) VALUES (13, 15, 110);
INSERT INTO Path (SourceAttractionID, TargetAttractionID, DistanceMeters) VALUES (13, 16, 90);
INSERT INTO Path (SourceAttractionID, TargetAttractionID, DistanceMeters) VALUES (15, 7, 80);
INSERT INTO Path (SourceAttractionID, TargetAttractionID, DistanceMeters) VALUES (15, 13, 110);
INSERT INTO Path (SourceAttractionID, TargetAttractionID, DistanceMeters) VALUES (16, 13, 90);
INSERT INTO Path (SourceAttractionID, TargetAttractionID, DistanceMeters) VALUES (16, 17, 150);
INSERT INTO Path (SourceAttractionID, TargetAttractionID, DistanceMeters) VALUES (17, 16, 150);
INSERT INTO Path (SourceAttractionID, TargetAttractionID, DistanceMeters) VALUES (17, 21, 80);
INSERT INTO Path (SourceAttractionID, TargetAttractionID, DistanceMeters) VALUES (17, 22, 60);
INSERT INTO Path (SourceAttractionID, TargetAttractionID, DistanceMeters) VALUES (18, 20, 130);
INSERT INTO Path (SourceAttractionID, TargetAttractionID, DistanceMeters) VALUES (19, 20, 50);
INSERT INTO Path (SourceAttractionID, TargetAttractionID, DistanceMeters) VALUES (19, 22, 70);
INSERT INTO Path (SourceAttractionID, TargetAttractionID, DistanceMeters) VALUES (20, 18, 130);
INSERT INTO Path (SourceAttractionID, TargetAttractionID, DistanceMeters) VALUES (20, 19, 50);
INSERT INTO Path (SourceAttractionID, TargetAttractionID, DistanceMeters) VALUES (20, 22, 40);
INSERT INTO Path (SourceAttractionID, TargetAttractionID, DistanceMeters) VALUES (21, 4, 120);
INSERT INTO Path (SourceAttractionID, TargetAttractionID, DistanceMeters) VALUES (21, 17, 80);
INSERT INTO Path (SourceAttractionID, TargetAttractionID, DistanceMeters) VALUES (21, 22, 50);
INSERT INTO Path (SourceAttractionID, TargetAttractionID, DistanceMeters) VALUES (22, 17, 60);
INSERT INTO Path (SourceAttractionID, TargetAttractionID, DistanceMeters) VALUES (22, 19, 70);
INSERT INTO Path (SourceAttractionID, TargetAttractionID, DistanceMeters) VALUES (22, 20, 40);
INSERT INTO Path (SourceAttractionID, TargetAttractionID, DistanceMeters) VALUES (22, 21, 50);
INSERT INTO Path (SourceAttractionID, TargetAttractionID, DistanceMeters) VALUES (22, 28, 160);
INSERT INTO Path (SourceAttractionID, TargetAttractionID, DistanceMeters) VALUES (23, 5, 100);
INSERT INTO Path (SourceAttractionID, TargetAttractionID, DistanceMeters) VALUES (23, 24, 20);
INSERT INTO Path (SourceAttractionID, TargetAttractionID, DistanceMeters) VALUES (23, 25, 30);
INSERT INTO Path (SourceAttractionID, TargetAttractionID, DistanceMeters) VALUES (23, 31, 60);
INSERT INTO Path (SourceAttractionID, TargetAttractionID, DistanceMeters) VALUES (24, 23, 20);
INSERT INTO Path (SourceAttractionID, TargetAttractionID, DistanceMeters) VALUES (25, 23, 30);
INSERT INTO Path (SourceAttractionID, TargetAttractionID, DistanceMeters) VALUES (26, 34, 70);
INSERT INTO Path (SourceAttractionID, TargetAttractionID, DistanceMeters) VALUES (26, 38, 80);
INSERT INTO Path (SourceAttractionID, TargetAttractionID, DistanceMeters) VALUES (26, 45, 180);
INSERT INTO Path (SourceAttractionID, TargetAttractionID, DistanceMeters) VALUES (27, 28, 40);
INSERT INTO Path (SourceAttractionID, TargetAttractionID, DistanceMeters) VALUES (27, 31, 50);
INSERT INTO Path (SourceAttractionID, TargetAttractionID, DistanceMeters) VALUES (28, 22, 160);
INSERT INTO Path (SourceAttractionID, TargetAttractionID, DistanceMeters) VALUES (28, 27, 40);
INSERT INTO Path (SourceAttractionID, TargetAttractionID, DistanceMeters) VALUES (28, 29, 40);
INSERT INTO Path (SourceAttractionID, TargetAttractionID, DistanceMeters) VALUES (29, 28, 40);
INSERT INTO Path (SourceAttractionID, TargetAttractionID, DistanceMeters) VALUES (29, 30, 40);
INSERT INTO Path (SourceAttractionID, TargetAttractionID, DistanceMeters) VALUES (30, 29, 40);
INSERT INTO Path (SourceAttractionID, TargetAttractionID, DistanceMeters) VALUES (30, 31, 60);
INSERT INTO Path (SourceAttractionID, TargetAttractionID, DistanceMeters) VALUES (31, 23, 60);
INSERT INTO Path (SourceAttractionID, TargetAttractionID, DistanceMeters) VALUES (31, 27, 50);
INSERT INTO Path (SourceAttractionID, TargetAttractionID, DistanceMeters) VALUES (31, 30, 60);
INSERT INTO Path (SourceAttractionID, TargetAttractionID, DistanceMeters) VALUES (32, 33, 50);
INSERT INTO Path (SourceAttractionID, TargetAttractionID, DistanceMeters) VALUES (33, 32, 50);
INSERT INTO Path (SourceAttractionID, TargetAttractionID, DistanceMeters) VALUES (33, 37, 90);
INSERT INTO Path (SourceAttractionID, TargetAttractionID, DistanceMeters) VALUES (34, 26, 70);
INSERT INTO Path (SourceAttractionID, TargetAttractionID, DistanceMeters) VALUES (34, 35, 50);
INSERT INTO Path (SourceAttractionID, TargetAttractionID, DistanceMeters) VALUES (35, 34, 50);
INSERT INTO Path (SourceAttractionID, TargetAttractionID, DistanceMeters) VALUES (35, 36, 60);
INSERT INTO Path (SourceAttractionID, TargetAttractionID, DistanceMeters) VALUES (36, 35, 60);
INSERT INTO Path (SourceAttractionID, TargetAttractionID, DistanceMeters) VALUES (36, 37, 70);
INSERT INTO Path (SourceAttractionID, TargetAttractionID, DistanceMeters) VALUES (37, 33, 90);
INSERT INTO Path (SourceAttractionID, TargetAttractionID, DistanceMeters) VALUES (37, 36, 70);
INSERT INTO Path (SourceAttractionID, TargetAttractionID, DistanceMeters) VALUES (38, 26, 80);
INSERT INTO Path (SourceAttractionID, TargetAttractionID, DistanceMeters) VALUES (38, 39, 40);
INSERT INTO Path (SourceAttractionID, TargetAttractionID, DistanceMeters) VALUES (39, 38, 40);
INSERT INTO Path (SourceAttractionID, TargetAttractionID, DistanceMeters) VALUES (39, 41, 130);
INSERT INTO Path (SourceAttractionID, TargetAttractionID, DistanceMeters) VALUES (40, 43, 90);
INSERT INTO Path (SourceAttractionID, TargetAttractionID, DistanceMeters) VALUES (40, 47, 50);
INSERT INTO Path (SourceAttractionID, TargetAttractionID, DistanceMeters) VALUES (41, 39, 130);
INSERT INTO Path (SourceAttractionID, TargetAttractionID, DistanceMeters) VALUES (41, 42, 60);
INSERT INTO Path (SourceAttractionID, TargetAttractionID, DistanceMeters) VALUES (41, 50, 70);
INSERT INTO Path (SourceAttractionID, TargetAttractionID, DistanceMeters) VALUES (42, 5, 100);
INSERT INTO Path (SourceAttractionID, TargetAttractionID, DistanceMeters) VALUES (42, 41, 60);
INSERT INTO Path (SourceAttractionID, TargetAttractionID, DistanceMeters) VALUES (42, 43, 70);
INSERT INTO Path (SourceAttractionID, TargetAttractionID, DistanceMeters) VALUES (43, 40, 90);
INSERT INTO Path (SourceAttractionID, TargetAttractionID, DistanceMeters) VALUES (43, 42, 70);
INSERT INTO Path (SourceAttractionID, TargetAttractionID, DistanceMeters) VALUES (43, 44, 30);
INSERT INTO Path (SourceAttractionID, TargetAttractionID, DistanceMeters) VALUES (44, 43, 30);
INSERT INTO Path (SourceAttractionID, TargetAttractionID, DistanceMeters) VALUES (45, 26, 180);
INSERT INTO Path (SourceAttractionID, TargetAttractionID, DistanceMeters) VALUES (45, 50, 40);
INSERT INTO Path (SourceAttractionID, TargetAttractionID, DistanceMeters) VALUES (46, 48, 100);
INSERT INTO Path (SourceAttractionID, TargetAttractionID, DistanceMeters) VALUES (47, 40, 50);
INSERT INTO Path (SourceAttractionID, TargetAttractionID, DistanceMeters) VALUES (48, 46, 100);
INSERT INTO Path (SourceAttractionID, TargetAttractionID, DistanceMeters) VALUES (48, 49, 60);
INSERT INTO Path (SourceAttractionID, TargetAttractionID, DistanceMeters) VALUES (49, 48, 60);
INSERT INTO Path (SourceAttractionID, TargetAttractionID, DistanceMeters) VALUES (49, 50, 50);
INSERT INTO Path (SourceAttractionID, TargetAttractionID, DistanceMeters) VALUES (50, 41, 70);
INSERT INTO Path (SourceAttractionID, TargetAttractionID, DistanceMeters) VALUES (50, 45, 40);
INSERT INTO Path (SourceAttractionID, TargetAttractionID, DistanceMeters) VALUES (50, 49, 50);
```

---

## Phase 5: Model Context Protocol (MCP) Toolbox Integration

> [!NOTE]
> **AI Agent Tooling Integration**:
> The **Model Context Protocol (MCP) Toolbox** provides a gateway for AI agents to securely execute real-time queries against transactional databases. In a production environment, this toolbox component is deployed as an automated service (e.g., inside a secure Cloud Run proxy) by your team's cloud administrators.
>
> Once the base infrastructure is deployed, agents can interact directly with your Cloud Spanner instance via the federated bridge. Let's verify this analytical bridge in the next step!

---

## Phase 6: Real-Time Bridge Verification Query

Validate that the zero-copy federated bridge is working correctly by executing a live query in BigQuery that fetches data directly from your Cloud Spanner transactional tables.

1. Go to the **BigQuery Studio** in the Google Cloud Console.
2. In the left Explorer sidebar, expand your project and you should see the **`disneyland_spanner_external`** dataset mapping all of your Spanner tables dynamically!
3. Open a new **SQL Query** tab.
4. Paste and run the query below (replace `YOUR_PROJECT_ID` with your actual project ID):

```sql
SELECT * 
FROM `YOUR_PROJECT_ID.disneyland_spanner_external.Attraction` 
LIMIT 5;
```

---

## Phase 7: Building the Agentic React Application using Gemini CLI

In this phase, you will launch the **Gemini CLI** directly from your Cloud Shell terminal and use it to build a complete React application. The application will utilize an **AGY SDK Agent** that queries your Spanner transactional database and leverages **Spanner Graph** capabilities to perform navigation and pathfinding across Disneyland Paris attractions.

### 1. Starting Gemini CLI in Cloud Shell

Run this command in your Google Cloud Shell terminal to launch an interactive session with Gemini using the latest architecture model:

```bash
gemini chat --model=gemini-3.1-pro-preview
```

#### Essential Gemini CLI Commands
Once inside the Gemini interactive shell, you can use the following slash commands to manage your session:

| Command | Action |
| :--- | :--- |
| `/list-sessions` | Shows a numbered list of your past session activities to resume. |
| `/resume latest` | Jumps back into your most recent active conversation. |
| `/exit` | Exits the Gemini CLI session and returns to your standard Cloud Shell prompt. |
| `/auth` | Re-authenticates or switches credentials (e.g., to use a specific API Key). |

---

### 2. Prompting Gemini to Generate the React Agentic Application

Paste the following developer prompt into the Gemini interactive chat session to initiate code generation:

```text
Goal: Build a fresh React application in a new directory to help navigate Disneyland Paris attractions.

Data Context: I have data and schema available in a Spanner instance called "disneyland" and a database called "agent-lab" in this project.

Instructions:
1. Show the planning phase of development first.
2. Test that the app can query data from Spanner without issues.
3. Leverage Spanner Graph capabilities (using the Attraction and Path tables) for pathfinding and navigation.
4. Use the AGY SDK to build a data agent equipped with these four specific tools:
   * `list_all_attractions`: Lists all available attractions.
   * `search_attractions_by_needs`: Finds attractions matching specific user needs or descriptions (using vector embeddings or keyword matching).
   * `find_shortest_path_between_two_attractions`: Finds optimized paths between two attractions using native Graph queries.
   * `find_attractions_near_another_attraction`: Finds all attractions closed to another one.
5. UI/UX: Design a beautiful, professional user interface featuring a premium Disneyland-themed color palette.
```

---

### 3. Deep Dive: Spanner Graph Queries under the Hood

When the agent calls the pathfinding tools, it runs a native **Spanner Graph** query using the `GRAPH_TABLE` function on the property graph defined on the `Attraction` and `Path` tables.

For example, the tool `find_shortest_path_between_two_attractions` resolves under the hood to:

```sql
SELECT * 
FROM GRAPH_TABLE(DisneylandGraph
  MATCH (src:Attraction {Name: 'Phantom Manor'})
        -[p:Path*1..5]->
        (dest:Attraction {Name: 'Big Thunder Mountain'})
  RETURN 
    src.Name AS Source, 
    dest.Name AS Target, 
    SUM(p.DistanceMeters) AS TotalDistanceMeters
);
```

This zero-copy Spanner Graph structure enables instant pathfinding logic inside your AI agent without needing extra external graph databases or complex application-level traversal algorithms.

---

## Phase 8: Troubleshooting & Pro-Tips

* **IAM Permissions 403 Forbidden**: If you encounter `Caller is missing IAM permission spanner.databases.setIamPolicy` during resource deployment, ensure that your active gcloud user account has been granted the Spanner Admin (`roles/spanner.admin`) role as described in the prerequisites reference file.
* **Billing Account**: Cloud Spanner requires an active Google Cloud billing account. Make sure your target sandbox project has billing correctly enabled.
* **API Keys & Authentication**: If the AGY agent requires an API key to call external Vertex AI LLM services, you can generate one at the Google AI Studio platform or run within active GCP application credentials.
* **Time Propagation**: If BQ connections fail immediately upon setup, wait approximately 60 seconds for the Spanner IAM reader bindings to propagate globally.

---

## Clean Up

> [!WARNING]
> **Ongoing Costs**:
> To avoid incurring ongoing charges for the regional Spanner instance, destroy all provisioned infrastructure when you have completed the lab:
> `terraform destroy`
