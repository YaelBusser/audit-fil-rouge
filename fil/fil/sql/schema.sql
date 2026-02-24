-- ============================================================
-- ShopTech — Schéma de base de données PostgreSQL
-- Fichier : schema.sql
-- Version : Production actuelle
-- ============================================================

-- Table des utilisateurs
CREATE TABLE users (
    id              SERIAL PRIMARY KEY,
    email           VARCHAR(255) NOT NULL,          -- Pas de contrainte UNIQUE !
    password        VARCHAR(255) NOT NULL,           -- Stocké en clair (cf. auth.js)
    first_name      VARCHAR(100),
    last_name       VARCHAR(100),
    phone           VARCHAR(20),
    address         TEXT,
    city            VARCHAR(100),
    postal_code     VARCHAR(10),
    country         VARCHAR(50) DEFAULT 'France',
    created_at      TIMESTAMP DEFAULT NOW(),
    updated_at      TIMESTAMP
    -- Pas d'index sur email → recherche lente à la connexion
);

-- Table des catégories
CREATE TABLE categories (
    id              SERIAL PRIMARY KEY,
    name            VARCHAR(100) NOT NULL,
    slug            VARCHAR(100),
    parent_id       INTEGER REFERENCES categories(id),
    description     TEXT,
    image_url       VARCHAR(500)
);

-- Table des produits (15 000 produits)
CREATE TABLE products (
    id              SERIAL PRIMARY KEY,
    name            VARCHAR(255) NOT NULL,
    slug            VARCHAR(255),
    description     TEXT,
    price           DECIMAL(10,2) NOT NULL,
    stock_quantity  INTEGER DEFAULT 0,
    category_id     INTEGER REFERENCES categories(id),
    brand           VARCHAR(100),
    weight          DECIMAL(8,2),
    image_url       VARCHAR(500),
    is_active       BOOLEAN DEFAULT true,
    created_at      TIMESTAMP DEFAULT NOW(),
    updated_at      TIMESTAMP
    -- Pas d'index sur category_id → jointures lentes
    -- Pas d'index sur is_active → filtrage lent
    -- Pas d'index sur name → recherche LIKE lente
);

-- Table de liaison produit-catégorie (relation N:N)
CREATE TABLE product_categories (
    product_id      INTEGER REFERENCES products(id),
    category_id     INTEGER REFERENCES categories(id),
    PRIMARY KEY (product_id, category_id)
    -- Pas d'index sur category_id seul → sous-requête lente
);

-- Table des images produit
CREATE TABLE product_images (
    id              SERIAL PRIMARY KEY,
    product_id      INTEGER REFERENCES products(id),
    url             VARCHAR(500) NOT NULL,
    alt_text        VARCHAR(255),
    sort_order      INTEGER DEFAULT 0
    -- Pas d'index sur product_id
);

-- Table des avis clients (très volumineuse : ~200 000 lignes)
CREATE TABLE reviews (
    id              SERIAL PRIMARY KEY,
    product_id      INTEGER REFERENCES products(id),
    user_id         INTEGER REFERENCES users(id),
    rating          INTEGER CHECK (rating BETWEEN 1 AND 5),
    title           VARCHAR(255),
    comment         TEXT,
    created_at      TIMESTAMP DEFAULT NOW()
    -- Pas d'index sur product_id → requêtes N+1 très lentes
    -- Pas d'index sur user_id
    -- Pas d'index sur created_at → tri lent
);

-- Table des commandes (~500 000 lignes cumulées)
CREATE TABLE orders (
    id              SERIAL PRIMARY KEY,
    user_id         INTEGER REFERENCES users(id),
    total_price     DECIMAL(10,2),
    status          VARCHAR(50) DEFAULT 'pending',  -- pending, confirmed, shipped, delivered, cancelled
    shipping_address TEXT,
    created_at      TIMESTAMP DEFAULT NOW(),
    updated_at      TIMESTAMP
    -- Pas d'index sur user_id → historique commandes lent
    -- Pas d'index sur status → filtrage lent
    -- Pas d'index sur created_at → tri et reporting lents
);

-- Table des lignes de commande
CREATE TABLE order_items (
    id              SERIAL PRIMARY KEY,
    order_id        INTEGER REFERENCES orders(id),
    product_id      INTEGER REFERENCES products(id),
    quantity        INTEGER NOT NULL,
    unit_price      DECIMAL(10,2) NOT NULL
    -- Pas d'index sur order_id → jointure lente
);

-- Table des sessions utilisateur (jamais purgée)
CREATE TABLE user_sessions (
    id              SERIAL PRIMARY KEY,
    user_id         INTEGER REFERENCES users(id),
    token           TEXT NOT NULL,
    ip_address      VARCHAR(45),
    user_agent      TEXT,
    created_at      TIMESTAMP DEFAULT NOW()
    -- Table jamais purgée → croissance illimitée
    -- Pas de colonne expires_at
);

-- ============================================================
-- STATISTIQUES DE LA BASE (extraites le 15/01/2025)
-- ============================================================
-- users           :    85 000 lignes   (~120 Mo)
-- products        :    15 000 lignes   (~45 Mo)
-- categories      :       350 lignes
-- product_categories:  22 000 lignes
-- product_images  :    45 000 lignes   (~15 Mo)
-- reviews         :   210 000 lignes   (~180 Mo)
-- orders          :   520 000 lignes   (~250 Mo)
-- order_items     : 1 800 000 lignes   (~400 Mo)
-- user_sessions   : 3 200 000 lignes   (~1.2 Go)  ← en croissance constante
-- ============================================================
-- Taille totale de la base : ~2.3 Go
-- ============================================================
