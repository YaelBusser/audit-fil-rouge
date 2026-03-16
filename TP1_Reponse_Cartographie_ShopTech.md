# TP 1 — Cartographie d'audit ShopTech — Réponse

---

## Découpage en étapes

| #     | Étape                                       | Objectif                                                                                                                                                       | Durée  |
| ----- | ------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------ |
| **1** | Identifier les composants à auditer         | Lister tous les composants techniques et organisationnels de l'architecture ShopTech                                                                           | 15 min |
| **2** | Associer des indicateurs à chaque composant | Proposer 2 à 4 indicateurs concrets par composant (nom, mesure, source) selon les 5 familles : disponibilité, performance, fiabilité, sécurité, maintenabilité | 15 min |
| **3** | Prioriser les composants                    | Classer chaque composant en critique / important / secondaire en justifiant par le contexte ShopTech (incidents, croissance, impact business)                  | 10 min |
| **4** | Restitution croisée                         | Échanger avec un autre binôme, comparer les choix, identifier une différence notable                                                                           | 10 min |

---

## Étape 1 — Identifier les composants à auditer ✅

### 🔵 Couche Réseau / Reverse Proxy — Nginx

| Élément                 | Détail observé                                                                                                                                                                                                                                                                                             |
| ----------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Fichier source**      | `config/nginx.conf`                                                                                                                                                                                                                                                                                        |
| **Rôle**                | Reverse proxy devant l'API Node.js, serveur de fichiers statiques                                                                                                                                                                                                                                          |
| **Éléments à examiner** | Configuration des workers (1 seul pour 4 vCPU), worker_connections (512), absence de HTTPS/TLS, absence de gzip, absence de cache static, `autoindex on` sur `/uploads`, absence de rate limiting, exposition de la version Nginx (`server_tokens on`), absence de headers `X-Real-IP` / `X-Forwarded-For` |

---

### 🔵 Couche Applicative — API Node.js / Express

| Élément                 | Détail observé                                                                                                                                                                                                                                                                                                                                                                                                                                   |
| ----------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **Fichiers sources**    | `code/server.js`, `code/productRoutes.js`, `code/orderRoutes.js`                                                                                                                                                                                                                                                                                                                                                                                 |
| **Rôle**                | API REST qui sert le catalogue produits, les commandes, la recherche                                                                                                                                                                                                                                                                                                                                                                             |
| **Éléments à examiner** | CORS ouvert à `*`, payload JSON limité à 50 Mo (risque DoS), absence de Helmet (pas de headers de sécurité), dossier `/uploads` exposé publiquement sans contrôle, messages d'erreur + stack trace exposés au client, écoute sur `0.0.0.0`, code mort (fonctions inutilisées, endpoint de debug `/products/debug/all` en production exposant les credentials BDD), code dupliqué (récupération des avis), pas de validation des données d'entrée |

---

### 🔵 Couche Authentification / Sécurité applicative

| Élément                 | Détail observé                                                                                                                                                                                                                                                                                                                                                                                                 |
| ----------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Fichier source**      | `code/auth.js`                                                                                                                                                                                                                                                                                                                                                                                                 |
| **Rôle**                | Middleware JWT d'authentification et login                                                                                                                                                                                                                                                                                                                                                                     |
| **Éléments à examiner** | Secret JWT faible et en dur (`shoptech-secret-key-2024`), pas d'extraction du préfixe `Bearer`, pas de vérification de l'algorithme (attaque `alg: none`), pas d'expiration du token, pas de rate limiting sur `/login` (brute force possible — confirmé par les logs), comparaison de mot de passe en clair (pas de bcrypt), vulnérabilité IDOR sur `GET /orders/:userId` (pas de vérification de l'identité) |

---

### 🔵 Couche Base de données — PostgreSQL

| Élément                 | Détail observé                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                |
| ----------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Fichiers sources**    | `sql/schema.sql`, `sql/slow_queries.sql`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      |
| **Rôle**                | Stockage des utilisateurs, produits, commandes, avis, sessions                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                |
| **Éléments à examiner** | **Schéma** : mots de passe stockés en clair, email sans contrainte `UNIQUE`, absence quasi-totale d'index (sur `users.email`, `products.category_id`, `products.is_active`, `reviews.product_id`, `orders.user_id`, `orders.status`, `order_items.order_id`, `product_images.product_id`). **Requêtes** : 6 requêtes lentes identifiées (de 850 ms à 4 500 ms), toutes en Seq Scan faute d'index, `SELECT *` systématique, pattern N+1 récurrent. **Volumétrie** : base de 2,3 Go, table `user_sessions` à 3,2 M de lignes jamais purgée (+10 000/jour). **Connexion** : mot de passe BDD en dur dans le code (`ShopTech2024!`), pool limité à 5 connexions (saturation constatée), pas de config centralisée |

---

### 🔵 Couche Infrastructure / Hébergement — VPS OVH

| Élément                 | Détail observé                                                                                                                                                                                                                                                                                                            |
| ----------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Fichier source**      | `config/metriques_trafic.json`                                                                                                                                                                                                                                                                                            |
| **Rôle**                | Serveur unique hébergeant toute la stack (Nginx + Node.js + PostgreSQL)                                                                                                                                                                                                                                                   |
| **Éléments à examiner** | VPS OVH Value B2-15 (4 vCPU, 8 Go RAM, 80 Go SSD), CPU moyen à 72% / pic à 98% (saturation), RAM moyenne à 6,8 Go / pic à 7,9 Go (proche du max), disque utilisé à 72% (58/80 Go) en croissance, serveur unique (SPOF — single point of failure), pas de redondance, pas de load balancing, OOM kill constaté sur Node.js |

---

### 🔵 Couche Trafic / Performance applicative

| Élément                 | Détail observé                                                                                                                                                                                                                                                      |
| ----------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Fichier source**      | `config/metriques_trafic.json`                                                                                                                                                                                                                                      |
| **Rôle**                | Métriques de charge et de performance de la plateforme                                                                                                                                                                                                              |
| **Éléments à examiner** | 50 000 visiteurs/jour, 180 req/s en moyenne (650 en pic), temps de réponse dégradés (`GET /api/products` : 2 400 ms, `POST /api/products/search` : 3 100 ms), taux de conversion à 4,2%, croissance de +300% sur 1 an, projection à 120 000 visiteurs/jour fin 2025 |

---

### 🔵 Couche Sécurité opérationnelle / Logs & Incidents

| Élément                 | Détail observé                                                                                                                                                                                                                                                                                                                                                                   |
| ----------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Fichier source**      | `logs/security_logs.txt`, `config/metriques_trafic.json` (section incidents)                                                                                                                                                                                                                                                                                                     |
| **Rôle**                | Traçabilité, détection d'intrusion, réponse aux incidents                                                                                                                                                                                                                                                                                                                        |
| **Éléments à examiner** | Injections SQL réussies (réponses 200) le 12/01, brute force réussi sur le compte admin le 13/01 (6 tentatives en 2s), exfiltration de 847 commandes via IDOR, endpoint de debug exposant les credentials BDD découvert le 14/01, OOM kill le 10/01 (150 commandes perdues), temps de réponse >10s pendant 2h le 11/01, logs basiques (`console.log`) sans structure ni contexte |

---

### 🔵 Couche Organisationnelle / Pratiques de développement

| Élément                          | Détail observé                                                                                                                                                                                                                                                                                                                                    |
| -------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Déduit de l'ensemble du code** |                                                                                                                                                                                                                                                                                                                                                   |
| **Rôle**                         | Qualité du code, processus de développement, gestion des secrets                                                                                                                                                                                                                                                                                  |
| **Éléments à examiner**          | Secrets en dur dans le code (JWT secret, mot de passe BDD), pas de séparation des environnements (debug en production), pas de validation des entrées, pas de transactions SQL, code mort laissé en place, code dupliqué, absence de tests visibles, requêtes SQL par concaténation (pas de requêtes paramétrées), gestion d'erreurs insuffisante |

---

### 📋 Synthèse — Liste des 8 composants identifiés

| #   | Composant                                  | Couche                  |
| --- | ------------------------------------------ | ----------------------- |
| 1   | **Nginx** (reverse proxy)                  | Réseau                  |
| 2   | **API Node.js / Express**                  | Application             |
| 3   | **Authentification JWT**                   | Sécurité applicative    |
| 4   | **PostgreSQL** (schéma, requêtes, données) | Base de données         |
| 5   | **Infrastructure VPS OVH**                 | Infrastructure          |
| 6   | **Métriques de trafic & performance**      | Performance             |
| 7   | **Logs & gestion des incidents**           | Sécurité opérationnelle |
| 8   | **Pratiques de développement**             | Organisationnel         |

---

## Étape 2 — Associer des indicateurs à chaque composant

> _À compléter…_

---

## Étape 3 — Prioriser les composants

> _À compléter…_

---

## Étape 4 — Restitution croisée

> _À compléter…_
