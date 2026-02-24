-- ============================================================
-- ShopTech — Requêtes SQL lentes identifiées en production
-- Fichier : slow_queries.sql
-- Source : pg_stat_statements (top 6 requêtes par temps cumulé)
-- Relevé du 15/01/2025
-- ============================================================


-- ============================================================
-- REQUÊTE 1 : Page catalogue — Liste des produits actifs
-- Temps moyen : 2 400 ms | Appels/jour : ~12 000
-- ============================================================

SELECT * FROM products WHERE is_active = true ORDER BY created_at DESC;

-- EXPLAIN ANALYZE :
-- Sort  (cost=1250.30..1288.50 rows=15280 width=320) (actual time=2380.1..2410.5 rows=14200 loops=1)
--   Sort Key: created_at DESC
--   Sort Method: external merge  Disk: 4520kB
--   ->  Seq Scan on products  (cost=0.00..580.00 rows=15280 width=320) (actual time=0.02..45.8 rows=14200 loops=1)
--         Filter: (is_active = true)
--         Rows Removed by Filter: 800
-- Planning Time: 0.12 ms
-- Execution Time: 2435.2 ms
--
-- DIAGNOSTIC : Seq Scan (pas d'index sur is_active ni created_at)
--              Sort sur disque (work_mem insuffisant pour 15K lignes)
--              SELECT * ramène toutes les colonnes (dont description TEXT volumineuse)


-- ============================================================
-- REQUÊTE 2 : Page produit — Avis d'un produit
-- Temps moyen : 850 ms | Appels/jour : ~45 000
-- ============================================================

SELECT * FROM reviews WHERE product_id = 1234 ORDER BY created_at DESC;

-- EXPLAIN ANALYZE :
-- Sort  (cost=8520.10..8525.30 rows=2080 width=280) (actual time=842.3..848.1 rows=14 loops=1)
--   Sort Key: created_at DESC
--   ->  Seq Scan on reviews  (cost=0.00..7850.00 rows=2080 width=280) (actual time=0.03..838.5 rows=14 loops=1)
--         Filter: (product_id = 1234)
--         Rows Removed by Filter: 209986
-- Planning Time: 0.08 ms
-- Execution Time: 852.4 ms
--
-- DIAGNOSTIC : Seq Scan sur 210 000 lignes pour en retourner 14
--              Index manquant sur product_id (critique)
--              SELECT * inutile (le frontend n'affiche que rating, title, comment, created_at)


-- ============================================================
-- REQUÊTE 3 : Historique commandes d'un utilisateur
-- Temps moyen : 1 200 ms | Appels/jour : ~8 000
-- ============================================================

SELECT * FROM orders WHERE user_id = 5678 ORDER BY created_at DESC;

-- EXPLAIN ANALYZE :
-- Sort  (cost=15200.50..15210.80 rows=4120 width=180) (actual time=1185.2..1195.4 rows=6 loops=1)
--   Sort Key: created_at DESC
--   ->  Seq Scan on orders  (cost=0.00..13500.00 rows=4120 width=180) (actual time=0.04..1180.1 rows=6 loops=1)
--         Filter: (user_id = 5678)
--         Rows Removed by Filter: 519994
-- Planning Time: 0.10 ms
-- Execution Time: 1198.6 ms
--
-- DIAGNOSTIC : Seq Scan sur 520 000 lignes pour en retourner 6
--              Index manquant sur user_id
--              Un index composite (user_id, created_at DESC) serait optimal


-- ============================================================
-- REQUÊTE 4 : Recherche produit par nom (barre de recherche)
-- Temps moyen : 3 100 ms | Appels/jour : ~25 000
-- ============================================================

SELECT * FROM products WHERE name LIKE '%casque%' OR description LIKE '%casque%';

-- EXPLAIN ANALYZE :
-- Seq Scan on products  (cost=0.00..1200.00 rows=150 width=320) (actual time=0.05..3085.2 rows=42 loops=1)
--   Filter: ((name ~~ '%casque%') OR (description ~~ '%casque%'))
--   Rows Removed by Filter: 14958
-- Planning Time: 0.15 ms
-- Execution Time: 3098.7 ms
--
-- DIAGNOSTIC : LIKE avec wildcard en début (%casque%) empêche l'utilisation d'un index B-tree
--              Solution : index GIN avec pg_trgm ou migration vers recherche full-text (tsvector)


-- ============================================================
-- REQUÊTE 5 : Dashboard admin — Chiffre d'affaires du mois
-- Temps moyen : 4 500 ms | Appels/jour : ~200
-- ============================================================

SELECT SUM(total_price) as revenue,
       COUNT(*) as order_count,
       AVG(total_price) as avg_order
FROM orders
WHERE status = 'delivered'
  AND created_at >= '2025-01-01'
  AND created_at < '2025-02-01';

-- EXPLAIN ANALYZE :
-- Aggregate  (cost=14200.00..14200.01 rows=1 width=64) (actual time=4480.5..4480.5 rows=1 loops=1)
--   ->  Seq Scan on orders  (cost=0.00..14100.00 rows=8500 width=8) (actual time=0.03..4350.2 rows=8200 loops=1)
--         Filter: ((status = 'delivered') AND (created_at >= '2025-01-01') AND (created_at < '2025-02-01'))
--         Rows Removed by Filter: 511800
-- Planning Time: 0.20 ms
-- Execution Time: 4502.1 ms
--
-- DIAGNOSTIC : Seq Scan sur 520K lignes, filtre combiné status + date
--              Index composite (status, created_at) recommandé
--              Ou table de reporting pré-agrégée (matérialized view)


-- ============================================================
-- REQUÊTE 6 : Purge inexistante — Sessions utilisateur
-- Volume : 3 200 000 lignes, croissance ~10 000/jour
-- ============================================================

-- Aucune requête de purge n'existe.
-- La table user_sessions grossit indéfiniment.
-- Impact : ralentissement des sauvegardes, espace disque (+1.2 Go),
-- et requêtes sur la table de plus en plus lentes.

-- Requête de purge suggérée (non implémentée) :
-- DELETE FROM user_sessions WHERE created_at < NOW() - INTERVAL '30 days';

-- ============================================================
-- RÉSUMÉ DES INDEX MANQUANTS IDENTIFIÉS
-- ============================================================
-- CREATE INDEX idx_products_is_active ON products(is_active) WHERE is_active = true;
-- CREATE INDEX idx_products_category_id ON products(category_id);
-- CREATE INDEX idx_products_name_trgm ON products USING gin(name gin_trgm_ops);
-- CREATE INDEX idx_reviews_product_id ON reviews(product_id);
-- CREATE INDEX idx_orders_user_id_created ON orders(user_id, created_at DESC);
-- CREATE INDEX idx_orders_status_created ON orders(status, created_at);
-- CREATE INDEX idx_order_items_order_id ON order_items(order_id);
-- CREATE INDEX idx_users_email ON users(email);
-- CREATE UNIQUE INDEX idx_users_email_unique ON users(email);
