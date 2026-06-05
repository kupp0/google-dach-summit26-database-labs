/*
===================================================================================
ALLOYDB AI: DATABASE & SCHEMA BOOTSTRAP
===================================================================================

This script initializes the foundation for the Semantic Search Demo.
It performs the following critical operations:

1. SCHEMA SETUP: Uses the default "public" schema for clean alignment with GDA.
2. EXTENSIONS: Enables Google ML, Vector, ScaNN, and AI Natural Language extensions.
3. TABLE DDL: Creates the `property_listings` table with:
   - Automatic Text Embeddings (using `gemini-embedding-001` via fully-qualified database trigger).
   - Placeholder for Image Embeddings (populated later via Python).
4. DATA LOAD: Inserts sample real estate data for Switzerland.
5. INDEXING: Creates high-performance ScaNN indexes.
   * NOTE: Uses MANUAL mode because the dataset is small (<10k rows).

PRE-REQUISITES:
- Ensure the Vertex AI API is enabled in your Google Cloud Project.
- Ensure the AlloyDB Service Account has "Vertex AI User" permissions.
===================================================================================
*/

-- 1. SCHEMA INITIALIZATION
-- ===================================================================================

DROP TABLE IF EXISTS "public"."property_listings" CASCADE;

-- 2. EXTENSION MANAGEMENT
-- ===================================================================================

-- Enable the Google ML Integration (Bridge to Vertex AI)
CREATE EXTENSION IF NOT EXISTS "google_ml_integration" WITH SCHEMA "public" CASCADE;

-- Enable pgvector (Base vector data type support)
CREATE EXTENSION IF NOT EXISTS "vector" WITH SCHEMA "public" CASCADE;

-- Enable AlloyDB ScaNN (High-performance vector indexing)
CREATE EXTENSION IF NOT EXISTS "alloydb_scann" WITH SCHEMA "public" CASCADE;

-- Enable Parameterized Views (Required for Toolbox)
CREATE EXTENSION IF NOT EXISTS "parameterized_views" WITH SCHEMA "public" CASCADE;

-- Enable Natural Language Support
-- Removed ALTER EXTENSION ... UPDATE as it requires superuser/owner privileges and is usually unnecessary for fresh setups
CREATE EXTENSION IF NOT EXISTS "alloydb_ai_nl" WITH SCHEMA "public" CASCADE;

-- VERIFICATION: Check integration status
SELECT "extname", "extversion" FROM "pg_catalog"."pg_extension" WHERE "extname" = 'google_ml_integration';
SHOW google_ml_integration.enable_model_support;

-- TEST: Sanity check the embedding connection to Gemini
SELECT "google_ml"."embedding"(
   'gemini-embedding-001',
   'Sanity check for Vertex AI connection'
) AS "test_vector";

-- 3. TABLE CREATION
-- ===================================================================================

CREATE TABLE "public"."property_listings" (
    "id" SERIAL PRIMARY KEY,
    "title" VARCHAR(255) NOT NULL,
    "description" TEXT,
    "price" DECIMAL(12, 2) NOT NULL,
    "bedrooms" INT,
    "city" VARCHAR(100),
    "image_gcs_uri" TEXT,
    "country" VARCHAR(100) DEFAULT 'Switzerland',
    "canton" VARCHAR(100),
    -- COLUMN A: Text Embeddings (Managed by Database)
    "description_embedding" VECTOR(3072) GENERATED ALWAYS AS (
      "google_ml"."embedding"('gemini-embedding-001', "description")
    ) STORED,
    -- COLUMN B: Image Embeddings (Managed by Application)
    "image_embedding" VECTOR(1408) 
);

-- 3.1 COLUMN METADATA COMMENTS
COMMENT ON COLUMN "public"."property_listings"."bedrooms" IS '<gemini>Examples: [''4'', ''6'', ''3''] | Distinct Values: 7 | Null Count: 0 |</gemini>';
COMMENT ON COLUMN "public"."property_listings"."canton" IS '<gemini>Examples: [''Solothurn'', ''Ticino'', ''Zug''] | Distinct Values: 27 | Null Count: 0 |</gemini>';
COMMENT ON COLUMN "public"."property_listings"."city" IS '<gemini>Examples: [''Stans'', ''Altdorf'', ''Kilchberg''] | Distinct Values: 89 | Null Count: 0 |</gemini>';
COMMENT ON COLUMN "public"."property_listings"."country" IS '<gemini>Examples: [''Switzerland''] | Distinct Values: 1 | Null Count: 0 |</gemini>';
COMMENT ON COLUMN "public"."property_listings"."description" IS '<gemini>Examples: [''The central rail crossroad of Switzerland. Reach anywhere fast. Modern functional apartment.'', ''Cozy retreat for weekend getaways or permanent living.''] | Distinct Values: 250 | Null Count: 0 |</gemini>';
COMMENT ON COLUMN "public"."property_listings"."id" IS '<gemini>Examples: [''75'', ''247'', ''13''] | Distinct Values: 250 | Null Count: 0 |</gemini>';
COMMENT ON COLUMN "public"."property_listings"."image_gcs_uri" IS '<gemini>Examples: [''https://storage.googleapis.com/property-images-data-agent-ai-powered-search-alloydb-1542/listings/10.jpg''] | Distinct Values: 250 | Null Count: 0 |</gemini>';
COMMENT ON COLUMN "public"."property_listings"."price" IS '<gemini>Examples: [''11878.00'', ''4869.00'', ''2792.00''] | Distinct Values: 189 | Null Count: 0 |</gemini>';
COMMENT ON COLUMN "public"."property_listings"."title" IS '<gemini>Examples: [''Rustic Studio in Landquart'', ''Renovated Villa in Herisau'', ''Quiet Home in Appenzell''] | Distinct Values: 248 | Null Count: 0 |</gemini>';
