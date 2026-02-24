// ============================================================
// ShopTech — Configuration du serveur Express
// Fichier : server.js
// ============================================================

const express = require('express');
const cors = require('cors');
const app = express();

// --- Configuration CORS ---
app.use(cors({ origin: '*' }));             // [FAILLE 7] CORS ouvert à tous les domaines

// --- Parsing ---
app.use(express.json({ limit: '50mb' }));   // [FAILLE 8] Limite de payload trop élevée → risque de DoS

// --- Pas de headers de sécurité ---        // [FAILLE 9] Pas de Helmet / headers de sécurité
// Manquent : X-Content-Type-Options, X-Frame-Options,
//            Content-Security-Policy, Strict-Transport-Security

// --- Routes ---
const productRoutes = require('./routes/productRoutes');
const orderRoutes = require('./routes/orderRoutes');

app.use('/api', productRoutes);
app.use('/api', orderRoutes);

// --- Fichiers statiques ---
app.use('/uploads', express.static('uploads'));  // [FAILLE 10] Dossier uploads accessible publiquement sans contrôle

// --- Pas de rate limiting global ---       // Déjà mentionné dans auth.js

// --- Gestion d'erreurs ---
app.use((err, req, res, next) => {
  console.log(err);                          // Log basique
  res.status(500).json({
    error: err.message,                      // [FAILLE 11] Message d'erreur interne exposé au client
    stack: err.stack                          // [FAILLE 11 bis] Stack trace exposée en production !
  });
});

// --- Démarrage ---
const PORT = process.env.PORT || 3000;
app.listen(PORT, '0.0.0.0', () => {          // [FAILLE 12] Écoute sur 0.0.0.0 (toutes interfaces)
  console.log(`ShopTech API running on port ${PORT}`);
});
