# Lab 1: One Million Vectors, Zero Loops: Generating Embeddings at Scale with AlloyDB

In this lab, you will build a scalable Knowledge Base search database application. Instead of managing a complex ETL pipeline with custom Python scripts and loops to generate vector embeddings, you will use **AlloyDB AI** to handle embedding generation natively within the database using a single SQL command.

---

## Objective
- Provision an AlloyDB Cluster and enable AI extensions.
- Generate a high-scale synthetic dataset (100,000+ rows) instantly using SQL.
- Backfill vector embeddings for the entire dataset using **Batch Processing**.
- Set up **Real-Time Incremental Triggers** to auto-embed new data as it is inserted.
- Perform a **Hybrid Search** combining semantic vector lookups with SQL filters.

---

## Phase 1: Verify Database Flags

AlloyDB AI integration requires specific database flags to be enabled on the primary instance. In this summit environment, these flags have been **pre-configured** via Terraform during the infrastructure deployment. 

Before proceeding, let's verify that the flags are active.

### Verification via SQL (AlloyDB Studio)
Connect to your database cluster inside the **AlloyDB Studio** and execute these commands to verify the configurations:

```sql
-- Check that Google ML Model support is active
SHOW google_ml_integration.enable_model_support;
-- Expected Output: 'on'

-- Check that Faster Embedding Generation is active
SHOW google_ml_integration.enable_faster_embedding_generation;
-- Expected Output: 'on'
```

> [!TIP]
> **Self-Service Fix**: If either of these flags outputs `off`, you can quickly enable them yourself using this command in your Google Cloud Shell:
> ```bash
> gcloud alloydb instances update search-primary \
>   --cluster=search-cluster \
>   --region=europe-west1 \
>   --database-flags=google_ml_integration.enable_model_support=on,google_ml_integration.enable_faster_embedding_generation=on
> ```


---

## Phase 2: Schema Setup & Extension Activation

Log into your **AlloyDB Studio** using the database credentials (default user: `postgres`). Run the following DDL commands to register the required PostgreSQL extensions:

```sql
-- Enable pgvector and ML integration extensions
CREATE EXTENSION IF NOT EXISTS google_ml_integration CASCADE;
CREATE EXTENSION IF NOT EXISTS vector;
```

### Verify Extension Version
Ensure that `google_ml_integration` is at version **1.5.2 or higher**:
```sql
SELECT extversion FROM pg_extension WHERE extname = 'google_ml_integration';
```
> [!NOTE]
> If your version is lower, you can upgrade it by running:
> `ALTER EXTENSION google_ml_integration UPDATE;`

---

## Phase 3: Generate Synthetic Data at Scale

Instead of loading a heavy CSV, generate 50,000 rows of synthetic customer support articles instantly using SQL:

```sql
-- 1. Create the help_articles table
CREATE TABLE help_articles (
    id SERIAL PRIMARY KEY,
    title TEXT,
    category TEXT,
    product_version TEXT,
    content_body TEXT,
    embedding vector(768) -- 768 dimension for text-embedding-005
);

-- 2. Generate 50,000 rows of synthetic data
INSERT INTO help_articles (title, category, product_version, content_body)
SELECT
    'Help Article ' || i,
    CASE 
        WHEN i % 3 = 0 THEN 'Billing' 
        WHEN i % 3 = 1 THEN 'Technical' 
        ELSE 'General' 
    END,
    CASE 
        WHEN i % 2 = 0 THEN '2.0' 
        ELSE '1.0' 
    END,
    'This article covers common issues regarding ' || 
    CASE 
        WHEN i % 3 = 0 THEN 'payment failures, invoice disputes, and credit card updates.'
        WHEN i % 3 = 1 THEN 'connection timeouts, latency issues, and API errors.'
        ELSE 'account profile settings, password resets, and user roles.' 
    END
FROM generate_series(1, 100000) AS i;
```

Verify the row count:
```sql
SELECT count(*) FROM help_articles;
-- Output should be exactly 100000
```

---

## Phase 4: Zero-Loop "One-Shot" Vector Generation 💥🔥

Now, perform a bulk generation of embeddings for all 100,000 rows natively in the database. This process completely eliminates the need for complex, fragile external ETL loops, Kafka queues, or Python background workers!

> [!IMPORTANT]
> **The Operational Edge (Transactional Mode)**: By specifying `incremental_refresh_mode => 'transactional'`, AlloyDB automatically configures live database triggers. This transactional synchronization is exceptionally powerful for production-grade operational vector search applications, because any future DML writes are vectorized **automatically** inside the same transaction, guaranteeing your search index remains 100% synchronized with zero operational lag!

> [!TIP]
> **Performance Benchmark**: In standard summit environments, backfilling the entire **100,000 rows** dataset completes in just **230.9 seconds** (processing over **430 rows per second**)! This highlights the superior speed and efficiency of database-native batch processing over traditional external application-driven loops.

By leveraging database-native automatic embedding generation, you eliminate external scheduler loops and background pipeline infrastructure, drastically reducing code maintenance debt. AlloyDB natively manages optimal batch sizes and automatically recovers from transient model quota limit errors, reducing API token overhead and guaranteeing transactional data remains continuously in sync.

### 1. Grant Progress Management Permissions
```sql
GRANT INSERT, UPDATE, DELETE ON google_ml.embed_gen_progress TO postgres;
GRANT EXECUTE ON FUNCTION embedding TO postgres;
```

### 2. Initialize Embeddings Call
Run the native bulk initialization:
```sql
CALL ai.initialize_embeddings(
  model_id => 'text-embedding-005',
  table_name => 'help_articles',
  content_column => 'content_body',
  embedding_column => 'embedding',
  incremental_refresh_mode => 'transactional'
);
```

### 3. Monitor Real-Time Embedding Progress
Since backfilling 100,000 rows is a large operational task, you can monitor the real-time progress, elapsed time, and estimated completion time of the bulk generation by querying the built-in **`ai.embedding_progress_view`**:

```sql
SELECT * FROM ai.embedding_progress_view;
```
*This returns columns detailing percentage completed, total rows processed, success rates, and any transient errors encountered.*

### 4. Performance Tuning & Batch Sizing (Optional)
By default, AlloyDB groups records into batches of **50** to optimize API calls to Vertex AI. However, you can tune the performance by explicitly specifying a custom `batch_size`:

- **Increasing Speed**: To speed up the process for large tables, you can specify a larger batch size (e.g., `batch_size => 100`).
- **Handling 4MB Size Limits**: If your content columns contain heavy text blocks and you encounter an error like `AutoEmbeddingGeneration: Request size is greater than 4MB`, reduce the batch size to prevent exceeding the 4MB Vertex AI payload limit:

```sql
CALL ai.initialize_embeddings(
  model_id => 'text-embedding-005',
  table_name => 'help_articles',
  content_column => 'content_body',
  embedding_column => 'embedding',
  incremental_refresh_mode => 'transactional',
  batch_size => 25 -- Reduced batch size to handle large text payloads
);
```

### 5. Verify Population
Confirm the embeddings are fully populated once the monitoring progress reaches 100%:
```sql
SELECT id, left(content_body, 30), substring(embedding::text, 1, 30) AS vector_partial 
FROM help_articles 
LIMIT 5;
```

---

## Phase 5: Verify Real-Time Triggers

Because `incremental_refresh_mode` was set to `'transactional'`, AlloyDB automatically configures internal triggers to auto-embed new records immediately.

Let's test this zero-loop automation:
```sql
-- Insert a new row without providing an embedding vector
INSERT INTO help_articles (title, category, product_version, content_body)
VALUES ('New Scaling Guide', 'Technical', '2.0', 'How to scale AlloyDB to millions of transactions.');

-- Check immediately if the vector was auto-generated
SELECT embedding 
FROM help_articles 
WHERE title = 'New Scaling Guide';
```

---

## Phase 6: Flexing Context / Hybrid Search

We will perform a **Hybrid Search** that combines semantic context understanding (vector similarity) with structured relational logic (SQL filters).

Query to find **Billing** issues relating to "Invoice did not go through" specifically for **Product Version 2.0**:

```sql
SELECT
  title,
  left(content_body, 100) AS content_snippet,
  1 - (embedding <=> embedding('text-embedding-005', 'Invoice did not go through')::vector) AS relevance
FROM help_articles
WHERE category = 'Billing'        -- Structured business filter
  AND product_version = '2.0'     -- Structured version filter
ORDER BY relevance DESC
LIMIT 5;
```

---

## Phase 7: High-Scale Optimization with ScaNN Index (Cloud Next 2026)

While traditional indexes (like `HNSW` or `IVFFlat`) are standard, AlloyDB AI introduces native support for Google's state-of-the-art **ScaNN (Scalable Nearest Neighbors)** index. ScaNN is built specifically for ultra-fast vector search at massive scale (millions of rows), delivering up to **double the Queries Per Second (QPS)** and higher recall accuracy.

### 1. Create a ScaNN Index
Run the following command to build a ScaNN index on the embedding vector column:
```sql
CREATE INDEX help_articles_scann_idx 
ON help_articles 
USING scann (embedding vector_cosine_ops)
WITH (num_leaves = 500);
```
> [!NOTE]
> `num_leaves` controls the number of clusters built by the ScaNN quantization algorithm. For 50,000 to 1,000,000 rows, `500` to `1000` leaves is recommended for optimal indexing speed and query recall.

### 2. Leverage Next-Gen AlloyDB AI Search Features
By using AlloyDB AI, you automatically inherit latest enhancements showcased at **Cloud Next 2026**:
- **Dynamic Pre-Filtering & Pruning**: During hybrid queries (Phase 6), AlloyDB's optimizer performs standard relational query pruning (e.g., resolving `WHERE category = 'Billing'`) *before* scoring vector spaces, restricting ScaNN calculations only to matching rows.
- **Hardware-Accelerated Real-time Inference**: The integration between `google_ml_integration` and Vertex AI leverages hardware-accelerated TPUs and GPUs on Google Cloud automatically, ensuring zero-overhead batch predictions and instant triggers.

---

## Verification & Troubleshooting

> [!TIP]
> **Confirming Index Usage**:
> To verify that your queries are successfully using the ScaNN index instead of performing slow sequential scans, prefix your query with `EXPLAIN ANALYZE`:
> `EXPLAIN ANALYZE SELECT ... ORDER BY relevance DESC;`

> [!WARNING]
> **Model ID Consistency**:
> Ensure that the `model_id` used in `ai.initialize_embeddings` (`text-embedding-005`) matches the model name in your query `SELECT` statement's `embedding(...)` function. Dim mismatch or space mismatches will result in irrelevant search rankings.

