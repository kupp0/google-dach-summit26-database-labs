# AlloyDB Database Setup & Seeding (Lab 3)

This directory contains the SQL files required to set up and seed the AlloyDB database for the Swiss Property Search application. 

By utilizing pre-built frontend images and pre-computed visual embeddings, you bypass the need for external python image-generation scripts.

## Database Seeding Workflow

To set up your database, execute the following SQL scripts in order using **AlloyDB Studio** or your preferred SQL client:

### 1. 🏗️ Table Schema & DDL
Execute the schema creation file:
* **File**: [alloydb_setup.sql](alloydb_setup.sql)
* **What it does**: Enables the `google_ml_integration`, `vector`, and `alloydb_scann` extensions, and creates the `property_listings` table.

### 2. 📥 Ingest Listing Records
Ingest the property records containing pre-computed image listings and visual vectors:
* **File**: [insert_listings.sql](insert_listings.sql)
* **What it does**: Seeds the database with 232 property records, including their titles, prices, local image paths (`/listings/{id}.jpg`), and pre-computed 1408-dimensional visual embeddings (`image_embedding`).

### 3. 💥 Bulk Backfill Text Embeddings
Generate the text embeddings for the property descriptions natively using AlloyDB AI's batch backfill procedure:
* **Query**:
  ```sql
  CALL ai.initialize_embeddings(
    model_id => 'gemini-embedding-001',
    table_name => 'property_listings',
    content_column => 'description',
    embedding_column => 'description_embedding',
    incremental_refresh_mode => 'transactional',
    batch_size => 50
  );
  ```
* **What it does**: Automatically generates 3072-dimensional text embeddings (`description_embedding`) for all 232 records in bulk using Vertex AI. The `incremental_refresh_mode => 'transactional'` parameter also configures live database triggers, ensuring any future inserts or updates are auto-vectorized in real time.

You can monitor the batch progress by running:
```sql
SELECT * FROM ai.embedding_progress_view;
```

### ⚡ 4. Create Vector Indexes
Execute the index creation script:
* **File**: [alloydb_indexes.sql](alloydb_indexes.sql)
* **What it does**: Registers the ScaNN vector search indexes for both text-based (`description_embedding`) and visual-based (`image_embedding`) cosine similarity lookups.
