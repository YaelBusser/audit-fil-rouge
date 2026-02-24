// ============================================================
// ShopTech — API REST / Routes Produits
// Fichier : routes/productRoutes.js
// Stack : Node.js + Express + pg (PostgreSQL)
// ============================================================

const express = require('express');
const router = express.Router();
const { Pool } = require('pg');

const pool = new Pool({
  host: 'localhost',
  port: 5432,
  database: 'shoptech_prod',
  user: 'shoptech_app',
  password: 'ShopTech2024!',       // [PROBLÈME 1] Mot de passe en dur dans le code source
  max: 5,
});

// -------------------------------------------------------
// GET /api/products — Liste des produits (page catalogue)
// -------------------------------------------------------
router.get('/products', async (req, res) => {
  try {
    // Récupérer tous les produits
    const products = await pool.query('SELECT * FROM products');   // [PROBLÈME 2] SELECT * sans pagination ni LIMIT

    // Pour chaque produit, récupérer ses catégories
    for (let i = 0; i < products.rows.length; i++) {              // [PROBLÈME 3] Requête N+1
      const categories = await pool.query(
        'SELECT name FROM categories WHERE id IN (SELECT category_id FROM product_categories WHERE product_id = ' + products.rows[i].id + ')'   // [PROBLÈME 4] Concaténation SQL → injection possible
      );
      products.rows[i].categories = categories.rows;
    }

    // Pour chaque produit, récupérer les avis
    for (let i = 0; i < products.rows.length; i++) {              // [PROBLÈME 3 bis] Deuxième boucle N+1
      const reviews = await pool.query(
        `SELECT * FROM reviews WHERE product_id = ${products.rows[i].id}`   // [PROBLÈME 4 bis] Template literal sans paramétrage
      );
      products.rows[i].reviews = reviews.rows;
    }

    res.json(products.rows);
  } catch (err) {
    console.log(err);                                              // [PROBLÈME 5] Log insuffisant (pas de stack trace, pas de contexte)
    res.status(500).json({ error: 'Erreur serveur' });
  }
});

// -------------------------------------------------------
// GET /api/products/:id — Détail d'un produit
// -------------------------------------------------------
router.get('/products/:id', async (req, res) => {
  try {
    const productId = req.params.id;    // Pas de validation du paramètre

    const product = await pool.query('SELECT * FROM products WHERE id = ' + productId);   // [PROBLÈME 4] Injection SQL

    if (product.rows.length === 0) {
      return res.status(404).json({ error: 'Produit non trouvé' });
    }

    // Récupérer les images
    const images = await pool.query(
      `SELECT url, alt_text FROM product_images WHERE product_id = ${productId}`
    );
    product.rows[0].images = images.rows;

    // Récupérer les avis (duplication du code ci-dessus)           // [PROBLÈME 6] Code dupliqué
    const reviews = await pool.query(
      `SELECT * FROM reviews WHERE product_id = ${productId}`
    );
    product.rows[0].reviews = reviews.rows;

    // Récupérer les produits similaires
    const similar = await pool.query(
      `SELECT * FROM products WHERE category_id = ${product.rows[0].category_id}`   // Pas de LIMIT
    );
    product.rows[0].similar = similar.rows;

    res.json(product.rows[0]);
  } catch (err) {
    console.log(err);
    res.status(500).json({ error: 'Erreur serveur' });
  }
});

// -------------------------------------------------------
// POST /api/products/search — Recherche produits
// -------------------------------------------------------
router.post('/products/search', async (req, res) => {
  try {
    const { query } = req.body;

    // Recherche par nom
    const results = await pool.query(
      `SELECT * FROM products WHERE name LIKE '%${query}%' OR description LIKE '%${query}%'`   // [PROBLÈME 4] Injection SQL via LIKE
    );

    res.json(results.rows);
  } catch (err) {
    console.log(err);
    res.status(500).json({ error: 'Erreur serveur' });
  }
});

// -------------------------------------------------------
// Fonction utilitaire — Calcul du prix avec promotion
// (utilisée nulle part actuellement)                              // [PROBLÈME 7] Code mort (fonction non appelée)
// -------------------------------------------------------
function calculateDiscountedPrice(price, discount) {
  if (discount > 0) {
    return price - (price * discount / 100);
  } else {
    return price;
  }
}

// Ancienne fonction de formatage (remplacée par le frontend)      // [PROBLÈME 7 bis] Code mort
function formatPrice(price) {
  return price.toFixed(2) + ' €';
}

// Ancien endpoint de debug, laissé en place                       // [PROBLÈME 8] Endpoint de debug en production
router.get('/products/debug/all', async (req, res) => {
  const result = await pool.query('SELECT * FROM products');
  const config = {
    dbHost: pool.options.host,
    dbName: pool.options.database,
    dbUser: pool.options.user,
    dbPassword: pool.options.password,                             // Expose le mot de passe BDD !
    nodeEnv: process.env.NODE_ENV,
  };
  res.json({ products: result.rows, config: config });
});

module.exports = router;
