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

### 1. Nginx
*   **Disponibilité (Uptime) :** Pourcentage de temps où le proxy court en ligne. *Source : Pingdom, StatusCake.*
*   **Performance (Temps de réponse) :** Temps de traitement moyen. *Source : Logs d'accès Nginx (`$request_time`).*
*   **Sécurité (HTTPS/TLS) :** Score de sécurisation TLS. *Source : Qualys SSL Labs.*

### 2. API Node.js / Express
*   **Fiabilité (Taux d'erreur) :** Proportion de réponses HTTP 5xx. *Source : Logs applicatifs ou APM (ex: Datadog/New Relic).*
*   **Performance (Latence) :** Temps de traitement par endpoint. *Source : APM.*
*   **Sécurité (Dette de dépendances) :** Nombre de vulnérabilités dans les paquets liés. *Source : `npm audit` / Snyk.*

### 3. Authentification JWT
*   **Sécurité (Tentatives de connexion) :** Nombre d'échecs de login pour détecter le brute force. *Source : Logs applicatifs.*
*   **Sécurité (Expiration) :** Durée de vie des tokens émis. *Source : Code ou configuration JWT.*

### 4. PostgreSQL
*   **Performance (Slow Queries) :** Pourcentage des requêtes excédant 500ms. *Source : Extension `pg_stat_statements`.*
*   **Fiabilité (Saturation du Pool) :** Nbre de connexions actives / Limite max. *Source : `pg_stat_activity`.*
*   **Maintenabilité (Taille de base) :** Volume de données et taux d'index inutilisés. *Source : Vues système pg_catalog.*

### 5. Infrastructure VPS OVH
*   **Performance (Usage CPU/RAM) :** Moyenne et pics d'utilisation. *Source : htop, Prometheus, ou espace client OVH.*
*   **Fiabilité (Espace Disque) :** Stockage restant. *Source : Systémique (`df -h`).*
*   **Disponibilité (OOM Kills) :** Fréquence d'arrêts brutaux de processus par l'OS. *Source : `/var/log/syslog`.*

### 6. Métriques de trafic & performance
*   **Performance (RPS) :** Requêtes par seconde supportées (moyenne et pic). *Source : Load Balancer / APM.*

### 7. Logs & gestion des incidents
*   **Sécurité/Maintenabilité (MTTD) :** Temps moyen de détection (attaques/crash). *Source : Outil de ticketing.*
*   **Sécurité/Maintenabilité (MTTR) :** Temps moyen de résolution. *Source : Plateforme ITSM (ex: Jira).*

### 8. Pratiques de développement
*   **Maintenabilité (Dette Technique) :** Code Coverage, Code Smells. *Source : SonarQube.*
*   **Sécurité (Secrets Exposés) :** Quantité de credentials découverts (SAST/TruffleHog). *Source : GitGuardian.*

---

## Étape 3 — Prioriser les composants

| Priorité | Composant | Justification de l'audit (Contexte ShopTech) |
| :--- | :--- | :--- |
| **CRITIQUE (P1)** | **Infrastructure VPS OVH** | VPS saturé (CPU à 98%, RAM presque au max) sans redondance (SPOF) = Risque majeur de d'arrêt complet du service. |
| **CRITIQUE (P1)** | **PostgreSQL** | Les lenteurs (requêtes N+1 et sans index) aggravent la saturation du VPS et les connexions échouent (bottleneck majeur des performances). |
| **CRITIQUE (P1)** | **API Node.js & Auth JWT** | Les vulnérabilités IDOR et l'absence de protection brute-force/rate limiting causent d'ores et déjà des fuites de données clients avérées. |
| **IMPORTANT (P2)** | **Nginx** | Une bonne configuration (Cache, Rate Limit, HTTPS) soulagerait la charge de l'API et l'infrastructure sous-jacente face à l'accroissement du trafic. |
| **IMPORTANT (P2)** | **Logs & gestion des incidents** | Sans bonne visibilité, les attaques et crashs futurs risquent de passer encore inaperçus sans remontée d'alerte claire. |
| **SECONDAIRE (P3)** | **Pratiques de développement** | Important sur le long terme (code propre, CI/CD), mais prioritaire de stabiliser le serveur et sécuriser l'API en urgence. |
| **SECONDAIRE (P3)** | **Métriques Trafic/Perf** | Doit être audité par la suite pour s'assurer que les KPIs commerciaux ne sont plus impactés, mais pas un composant d'infrastructure direct. |

---

## Étape 4 — Restitution croisée

### 📝 Retour de l'échange avec le binôme voisin (Lino et Nathan)

**1. Ce que nous avions oublié :**
*   **Indicateur sur Nginx :** Nous n'avions pas pensé à mesurer spécifiquement le taux d'erreurs 502/504 renvoyées par Nginx (qui indiquerait une perte de connexion avec l'API Node.js). Le binôme B l'avait bien identifié comme essentiel pour la fiabilité.

**2. Différences dans les priorités :**
*   **Priorité accordée à Nginx :** Nathan et Lino ont classés Nginx en **CRITIQUE (P1)**, arguant qu'il est le point d'entrée unique et que le manque de "Rate Limiting" est la cause directe des crashs de l'API sous la charge. Nous l'avions mis en P2, privilégiant la réparation de l'infrastructure VPS et de la BDD.

**3. Différence notable à partager en plénière :**
*   **Le dilemme de l'urgence vs l'importance :** Doit-on d'abord corriger la vulnérabilité de sécurité qui laisse fuiter les données (IDOR / Authentification P1 pour nous), ou d'abord stabiliser le serveur qui s'effondre sous la charge (Nginx P1 pour eux) ? C'est le point de débat principal que nous souhaitons remonter.
