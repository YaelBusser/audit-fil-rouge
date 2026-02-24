// ============================================================
// ShopTech — Middleware d'authentification
// Fichier : middleware/auth.js
// ============================================================

const jwt = require('jsonwebtoken');

const JWT_SECRET = 'shoptech-secret-key-2024';    // [FAILLE 1] Secret JWT faible et en dur dans le code

// Vérifier le token JWT
function authenticateToken(req, res, next) {
  const token = req.headers['authorization'];      // [FAILLE 2] Pas d'extraction du "Bearer " prefix

  if (!token) {
    return res.status(401).json({ error: 'Token manquant' });
  }

  try {
    const decoded = jwt.verify(token, JWT_SECRET); // [FAILLE 3] Pas de vérification de l'algorithme → attaque "alg: none"
    req.user = decoded;
    next();
  } catch (err) {
    return res.status(403).json({ error: 'Token invalide' });
  }
}

// Générer un token à la connexion
function generateToken(user) {
  return jwt.sign(
    { id: user.id, email: user.email, role: user.role },
    JWT_SECRET
    // [FAILLE 4] Pas d'expiration (expiresIn manquant) → token valide indéfiniment
  );
}

// Route de login
async function login(req, res) {
  const { email, password } = req.body;

  // Recherche de l'utilisateur (dans le vrai code, appel BDD)
  // Pas de rate limiting sur la route login                       // [FAILLE 5] Brute force possible
  // Pas de protection contre le timing attack sur la comparaison

  const user = await findUserByEmail(email);

  if (!user || user.password !== password) {                       // [FAILLE 6] Comparaison en clair — pas de hash (bcrypt)
    return res.status(401).json({ error: 'Identifiants incorrects' });
  }

  const token = generateToken(user);
  res.json({ token: token, user: { id: user.id, email: user.email } });
}

module.exports = { authenticateToken, generateToken, login };
