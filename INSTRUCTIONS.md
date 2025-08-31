# How to Run the Shop Platform System

This document provides instructions on how to set up and run the complete shop platform system using Docker.

## Prerequisites

Before you begin, ensure you have the following installed on your system:
- Docker
- Docker Compose

## 1. Environment Configuration

A `.env` file has been created in the root of the project. It contains the default credentials for the database and Keycloak. You can modify this file if needed.

```
# .env
MYSQL_DATABASE=shop_db
MYSQL_ROOT_PASSWORD=verysecretpassword
KEYCLOAK_ADMIN_USER=admin
KEYCLOAK_ADMIN_PASSWORD=admin
```

## 2. Build and Run the Services

Navigate to the `docker` directory and run the following command to build and start all the services in the background:

```bash
cd docker
docker-compose up --build -d
```

This will start three services:
- `shop_db`: The MySQL database.
- `shop_keycloak`: The Keycloak authentication service.
- `shop_backend`: The Django backend.

## 3. Keycloak Setup

Once the Keycloak service is running, you need to import the realm configuration.

1.  Open your web browser and navigate to the Keycloak admin console: `http://localhost:8080`.
2.  Log in with the credentials from your `.env` file (default: `admin`/`admin`).
3.  In the top-left corner, hover over the "master" realm name and click on "Create Realm".
4.  Select the "Import" option.
5.  Click on "Select file" and choose the `keycloak/realm-export.json` file from this project.
6.  Click "Create".

This will create the `shop-platform` realm with all the necessary clients and roles.

## 4. Database Migrations

Once the backend service is running, you need to apply the database migrations.

Open a new terminal and run the following command to execute the migrations inside the `shop_backend` container:

```bash
docker-compose -f docker/docker-compose.yml exec shop_backend python manage.py migrate
```

## 5. Running the Frontend Applications

The frontend applications are not containerized in this setup. You will need to run them locally.

### Admin Frontend

Open a new terminal:
```bash
cd frontend-admin
npm install
npm run dev
```
The admin portal will be available at `http://localhost:5173` (Vite's default port).

### Seller Frontend

Open another new terminal:
```bash
cd frontend-seller
npm install
npm run dev
```
The seller portal will be available at `http://localhost:5174` (or another port if 5173 is taken).

## Summary of URLs

- **Admin Portal**: `http://localhost:5173`
- **Seller Portal**: `http://localhost:5174`
- **Django Backend**: `http://localhost:8000`
- **Keycloak Admin Console**: `http://localhost:8080`

You have now successfully set up and run the entire shop platform system.
