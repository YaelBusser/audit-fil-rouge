// ============================================================
// ShopTech — API REST / Routes Commandes
// Fichier : routes/orderRoutes.js
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
  password: 'ShopTech2024!',       // [Même mot de passe dupliqué — pas de config centralisée]
  max: 5,
});

// -------------------------------------------------------
// POST /api/orders — Créer une commande
// -------------------------------------------------------
router.post('/orders', async (req, res) => {
  try {
    const { userId, items } = req.body;
    // Pas de validation des données d'entrée                     // [PROBLÈME 9] Aucune validation (userId, items, quantités, prix)

    let totalPrice = 0;

    // Calculer le prix total côté serveur
    for (let i = 0; i < items.length; i++) {
      const product = await pool.query(                           // [PROBLÈME 3] Encore une requête N+1
        `SELECT price FROM products WHERE id = ${items[i].productId}`
      );
      totalPrice = totalPrice + product.rows[0].price * items[i].quantity;
      // Arrondi flottant non géré → risque de prix à 29.990000000001 // [PROBLÈME 10] Calcul flottant sur des montants
    }

    // Insérer la commande
    const order = await pool.query(
      `INSERT INTO orders (user_id, total_price, status, created_at)
       VALUES (${userId}, ${totalPrice}, 'pending', NOW())
       RETURNING id`                                              // [PROBLÈME 4] Pas de requête paramétrée
    );

    // Insérer les lignes de commande
    for (let i = 0; i < items.length; i++) {
      await pool.query(                                           // [PROBLÈME 3] N+1 pour les inserts aussi
        `INSERT INTO order_items (order_id, product_id, quantity, unit_price)
         VALUES (${order.rows[0].id}, ${items[i].productId}, ${items[i].quantity}, ${items[i].unitPrice})`
      );
    }
    // Pas de transaction (BEGIN/COMMIT) pour garantir l'atomicité  // [PROBLÈME 11] Pas de transaction → commande partielle possible

    res.status(201).json({ orderId: order.rows[0].id, total: totalPrice });
  } catch (err) {
    console.log('Erreur commande:', err.message);
    res.status(500).json({ error: 'Erreur serveur' });
  }
});

// -------------------------------------------------------
// GET /api/orders/:userId — Historique commandes d'un utilisateur
// -------------------------------------------------------
router.get('/orders/:userId', async (req, res) => {
  try {
    const userId = req.params.userId;
    // Pas de vérification que l'utilisateur connecté = userId     // [PROBLÈME 12] IDOR — un utilisateur peut voir les commandes d'un autre

    const orders = await pool.query(
      `SELECT * FROM orders WHERE user_id = ${userId} ORDER BY created_at DESC`
    );

    // Pour chaque commande, récupérer les lignes
    for (let i = 0; i < orders.rows.length; i++) {                // [PROBLÈME 3] Requête N+1 (encore)
      const items = await pool.query(
        `SELECT oi.*, p.name, p.image_url
         FROM order_items oi
         JOIN products p ON p.id = oi.product_id
         WHERE oi.order_id = ${orders.rows[i].id}`
      );
      orders.rows[i].items = items.rows;
    }

    res.json(orders.rows);
  } catch (err) {
    console.log(err);
    res.status(500).json({ error: 'Erreur serveur' });
  }
});

module.exports = router;
