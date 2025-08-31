-- =================================================================
-- Segment 1: Keycloak-Integrated User Management System
-- =================================================================
-- This segment defines tables for storing user-related data that
-- complements the information managed by Keycloak.

-- Table: user_profiles
-- Stores extended profile information for users, linking back to Keycloak.
CREATE TABLE user_profiles (
    profile_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    -- The unique identifier from Keycloak. This is the core link.
    keycloak_user_id VARCHAR(255) NOT NULL UNIQUE,
    email VARCHAR(255) NOT NULL,
    phone VARCHAR(50),
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    date_of_birth DATE,
    gender ENUM('male', 'female', 'other', 'prefer_not_to_say'),
    avatar_url VARCHAR(2048),
    bio TEXT,
    -- User status, managed locally. E.g., for temporary deactivation.
    status ENUM('active', 'inactive', 'suspended') NOT NULL DEFAULT 'active',
    -- Timestamps for auditing and tracking record lifecycle.
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    -- Tracks when the local profile was last synced with Keycloak data.
    last_sync_at TIMESTAMP NULL
);

-- Indexes for user_profiles
-- Index on keycloak_user_id is created automatically by the UNIQUE constraint.
-- Index on email for fast lookups, as it's a common login/search field.
CREATE INDEX idx_user_profiles_email ON user_profiles(email);
-- Index on status for quickly filtering users by their activity status.
CREATE INDEX idx_user_profiles_status ON user_profiles(status);


-- Table: user_addresses
-- Stores multiple physical addresses for each user.
CREATE TABLE user_addresses (
    address_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    keycloak_user_id VARCHAR(255) NOT NULL,
    address_type ENUM('home', 'work', 'billing', 'shipping') NOT NULL,
    address_line1 VARCHAR(255) NOT NULL,
    address_line2 VARCHAR(255),
    city VARCHAR(100) NOT NULL,
    state VARCHAR(100),
    country VARCHAR(100) NOT NULL,
    postal_code VARCHAR(20) NOT NULL,
    is_default BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    -- Foreign key to link addresses to a user profile.
    -- ON DELETE CASCADE ensures that if a user is deleted, their addresses are also removed.
    CONSTRAINT fk_user_addresses_user_profiles
        FOREIGN KEY (keycloak_user_id) REFERENCES user_profiles(keycloak_user_id)
        ON DELETE CASCADE
);

-- Indexes for user_addresses
-- Index on keycloak_user_id for efficient retrieval of all addresses for a user.
CREATE INDEX idx_user_addresses_keycloak_user_id ON user_addresses(keycloak_user_id);


-- Table: user_business_data
-- Stores business-related information, including KYC details for vendors/merchants.
CREATE TABLE user_business_data (
    business_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    keycloak_user_id VARCHAR(255) NOT NULL,
    kyc_status ENUM('pending', 'approved', 'rejected', 'resubmit_required') NOT NULL DEFAULT 'pending',
    -- Storing documents as JSON can include URLs, file paths, or metadata.
    -- For security, actual files should be in secure storage (like S3), not the DB.
    kyc_documents_json JSON,
    tax_id VARCHAR(100),
    business_license VARCHAR(255),
    business_type VARCHAR(100),
    -- Notes for internal review during the verification process.
    verification_notes TEXT,
    verified_at TIMESTAMP NULL,
    verified_by VARCHAR(255), -- Could be a Keycloak ID of an admin
    -- Foreign key to link business data to a user profile.
    CONSTRAINT fk_user_business_data_user_profiles
        FOREIGN KEY (keycloak_user_id) REFERENCES user_profiles(keycloak_user_id)
        ON DELETE CASCADE
);

-- Indexes for user_business_data
-- Index on keycloak_user_id for quick access to a user's business info.
CREATE INDEX idx_user_business_data_keycloak_user_id ON user_business_data(keycloak_user_id);
-- Index on kyc_status to efficiently query users based on their verification status.
CREATE INDEX idx_user_business_data_kyc_status ON user_business_data(kyc_status);


-- Table: keycloak_user_sync
-- Logs synchronization attempts between the local database and Keycloak.
CREATE TABLE keycloak_user_sync (
    sync_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    keycloak_user_id VARCHAR(255) NOT NULL,
    last_sync_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    sync_status ENUM('success', 'failed') NOT NULL,
    -- Store error messages for debugging failed syncs.
    error_message TEXT,
    -- A JSON object detailing which attributes were updated during the sync.
    attributes_synced_json JSON
);

-- Indexes for keycloak_user_sync
-- Index for finding sync history for a specific user.
CREATE INDEX idx_keycloak_user_sync_keycloak_user_id ON keycloak_user_sync(keycloak_user_id);
-- Index for querying syncs by status, useful for monitoring and alerts.
CREATE INDEX idx_keycloak_user_sync_status ON keycloak_user_sync(sync_status);


-- Table: user_preferences
-- Stores user-specific settings and preferences.
CREATE TABLE user_preferences (
    preference_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    keycloak_user_id VARCHAR(255) NOT NULL,
    notification_email BOOLEAN NOT NULL DEFAULT TRUE,
    notification_sms BOOLEAN NOT NULL DEFAULT FALSE,
    notification_push BOOLEAN NOT NULL DEFAULT TRUE,
    language VARCHAR(10) NOT NULL DEFAULT 'en-US',
    currency VARCHAR(10) NOT NULL DEFAULT 'USD',
    timezone VARCHAR(50) NOT NULL DEFAULT 'UTC',
    theme ENUM('light', 'dark') NOT NULL DEFAULT 'light',
    marketing_consent BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    -- Foreign key to link preferences to a user profile.
    CONSTRAINT fk_user_preferences_user_profiles
        FOREIGN KEY (keycloak_user_id) REFERENCES user_profiles(keycloak_user_id)
        ON DELETE CASCADE
);

-- Indexes for user_preferences
-- Index for retrieving a user's preferences quickly.
CREATE INDEX idx_user_preferences_keycloak_user_id ON user_preferences(keycloak_user_id);


-- Table: shop_user_roles
-- Maps users to roles within a specific shop (multi-vendor context).
-- This is separate from Keycloak's global roles.
CREATE TABLE shop_user_roles (
    role_assignment_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    -- Assumes a `shops` table will be created. This is a forward declaration.
    -- The actual foreign key will be added later if the shops table is in another script.
    shop_id BIGINT UNSIGNED NOT NULL,
    keycloak_user_id VARCHAR(255) NOT NULL,
    -- Role name specific to the shop context, e.g., 'Shop Manager', 'Staff'.
    keycloak_role_name VARCHAR(100) NOT NULL,
    assigned_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    assigned_by VARCHAR(255), -- Keycloak ID of the user who assigned the role
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    -- A composite unique key to prevent assigning the same role to the same user in the same shop more than once.
    UNIQUE KEY uk_shop_user_role (shop_id, keycloak_user_id, keycloak_role_name)
);

-- Indexes for shop_user_roles
-- Index for finding all roles for a user across all shops.
CREATE INDEX idx_shop_user_roles_keycloak_user_id ON shop_user_roles(keycloak_user_id);
-- Index for finding all users and their roles for a specific shop.
CREATE INDEX idx_shop_user_roles_shop_id ON shop_user_roles(shop_id);


-- Table: user_activity_log
-- A crucial table for security and auditing, tracking user actions.
CREATE TABLE user_activity_log (
    activity_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    keycloak_user_id VARCHAR(255),
    activity_type VARCHAR(100) NOT NULL, -- e.g., 'login', 'update_profile', 'create_product'
    resource_type VARCHAR(100), -- e.g., 'product', 'order'
    resource_id VARCHAR(255), -- The ID of the affected resource
    ip_address VARCHAR(45) NOT NULL, -- Supports both IPv4 and IPv6
    user_agent VARCHAR(512),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for user_activity_log
-- Index for retrieving all activities for a specific user.
CREATE INDEX idx_user_activity_log_keycloak_user_id ON user_activity_log(keycloak_user_id);
-- Index for searching activities by type, useful for monitoring specific actions.
CREATE INDEX idx_user_activity_log_activity_type ON user_activity_log(activity_type);
-- Index on timestamp for time-based queries and reports.
CREATE INDEX idx_user_activity_log_created_at ON user_activity_log(created_at);

-- =================================================================
-- Segment 2: Multi-Vendor Shop Management System
-- =================================================================
-- This segment defines the tables necessary for operating a
-- multi-vendor marketplace, where each shop is a distinct entity.

-- Table: shops
-- The central table for storing information about each vendor's shop.
CREATE TABLE shops (
    shop_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    -- The Keycloak user ID of the shop owner.
    owner_id VARCHAR(255) NOT NULL,
    shop_name VARCHAR(255) NOT NULL,
    -- A URL-friendly version of the shop name. Must be unique.
    shop_slug VARCHAR(255) NOT NULL UNIQUE,
    city VARCHAR(100),
    state VARCHAR(100),
    country VARCHAR(100),
    address TEXT,
    zip_code VARCHAR(20),
    phone VARCHAR(50),
    email VARCHAR(255),
    description TEXT,
    logo_url VARCHAR(2048),
    banner_url VARCHAR(2048),
    -- The approval status of the shop, controlled by platform admins.
    status ENUM('pending', 'approved', 'suspended', 'rejected') NOT NULL DEFAULT 'pending',
    approval_date TIMESTAMP NULL,
    approved_by VARCHAR(255), -- Keycloak ID of the admin who approved it
    -- Commission rate for sales from this shop. Can be overridden from a category default.
    commission_rate DECIMAL(5, 2) NOT NULL DEFAULT 10.00,
    minimum_payout_amount DECIMAL(10, 2) NOT NULL DEFAULT 50.00,
    shop_type VARCHAR(100), -- e.g., 'Retail', 'Handmade', 'Services'
    business_license VARCHAR(255),
    tax_id VARCHAR(100),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    -- Foreign key linking a shop to its owner in the user_profiles table.
    -- ON DELETE RESTRICT prevents deleting a user who owns a shop, ensuring business logic is handled first.
    CONSTRAINT fk_shops_owner
        FOREIGN KEY (owner_id) REFERENCES user_profiles(keycloak_user_id)
        ON DELETE RESTRICT
);

-- Indexes for shops
-- Index on owner_id to quickly find all shops owned by a user.
CREATE INDEX idx_shops_owner_id ON shops(owner_id);
-- Index on shop_slug is created automatically by the UNIQUE constraint.
-- Index on status for efficient filtering of shops by their status (e.g., finding all pending shops).
CREATE INDEX idx_shops_status ON shops(status);
-- Full-text index for searching shop names and descriptions. Crucial for user-facing search functionality.
CREATE FULLTEXT INDEX ft_shops_name_description ON shops(shop_name, description);


-- Table: shop_categories
-- Defines the categories that shops can be assigned to.
CREATE TABLE shop_categories (
    category_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    category_name VARCHAR(255) NOT NULL UNIQUE,
    description TEXT,
    -- Allows overriding the default platform commission rate for shops in this category.
    commission_rate_override DECIMAL(5, 2) NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);


-- Table: shop_category_assignments
-- A junction table to link shops to one or more categories (many-to-many relationship).
CREATE TABLE shop_category_assignments (
    assignment_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    shop_id BIGINT UNSIGNED NOT NULL,
    category_id BIGINT UNSIGNED NOT NULL,
    assigned_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    -- Foreign key to the shops table.
    CONSTRAINT fk_shop_category_assignments_shop
        FOREIGN KEY (shop_id) REFERENCES shops(shop_id)
        ON DELETE CASCADE,
    -- Foreign key to the shop_categories table.
    CONSTRAINT fk_shop_category_assignments_category
        FOREIGN KEY (category_id) REFERENCES shop_categories(category_id)
        ON DELETE CASCADE,
    -- Ensures a shop cannot be assigned to the same category twice.
    UNIQUE KEY uk_shop_category (shop_id, category_id)
);


-- Table: shop_policies
-- Stores various policy documents for a shop.
CREATE TABLE shop_policies (
    policy_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    shop_id BIGINT UNSIGNED NOT NULL,
    return_policy TEXT,
    shipping_policy TEXT,
    privacy_policy TEXT,
    terms_of_service TEXT,
    refund_policy TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    -- A shop should only have one set of policies.
    UNIQUE KEY uk_shop_policies_shop_id (shop_id),
    -- Foreign key to the shops table.
    CONSTRAINT fk_shop_policies_shop
        FOREIGN KEY (shop_id) REFERENCES shops(shop_id)
        ON DELETE CASCADE
);


-- Table: shop_settings
-- A key-value store for shop-specific settings.
CREATE TABLE shop_settings (
    setting_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    shop_id BIGINT UNSIGNED NOT NULL,
    setting_key VARCHAR(100) NOT NULL,
    setting_value TEXT NOT NULL,
    setting_type VARCHAR(50), -- e.g., 'string', 'number', 'boolean', 'json'
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    -- Foreign key to the shops table.
    CONSTRAINT fk_shop_settings_shop
        FOREIGN KEY (shop_id) REFERENCES shops(shop_id)
        ON DELETE CASCADE,
    -- Ensures a setting key is unique for each shop.
    UNIQUE KEY uk_shop_setting (shop_id, setting_key)
);


-- Table: shop_staff
-- Manages staff members for a shop and their roles/permissions.
CREATE TABLE shop_staff (
    staff_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    shop_id BIGINT UNSIGNED NOT NULL,
    -- The Keycloak user ID of the staff member.
    user_id VARCHAR(255) NOT NULL,
    role ENUM('manager', 'staff', 'viewer') NOT NULL,
    -- JSON field for granular permissions, offering flexibility beyond simple roles.
    permissions_json JSON,
    hired_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    status ENUM('active', 'inactive') NOT NULL DEFAULT 'active',

    -- Foreign key to the shops table.
    CONSTRAINT fk_shop_staff_shop
        FOREIGN KEY (shop_id) REFERENCES shops(shop_id)
        ON DELETE CASCADE,
    -- Foreign key to the user_profiles table.
    CONSTRAINT fk_shop_staff_user
        FOREIGN KEY (user_id) REFERENCES user_profiles(keycloak_user_id)
        ON DELETE CASCADE,
    -- Ensures a user can only have one role per shop.
    UNIQUE KEY uk_shop_staff (shop_id, user_id)
);


-- Table: shop_statistics
-- Stores aggregated statistics for each shop to improve performance on dashboards.
-- This data would be updated periodically by a background job.
CREATE TABLE shop_statistics (
    stat_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    shop_id BIGINT UNSIGNED NOT NULL,
    total_products INT UNSIGNED NOT NULL DEFAULT 0,
    total_orders INT UNSIGNED NOT NULL DEFAULT 0,
    total_revenue DECIMAL(15, 2) NOT NULL DEFAULT 0.00,
    average_rating DECIMAL(3, 2) NOT NULL DEFAULT 0.00,
    total_reviews INT UNSIGNED NOT NULL DEFAULT 0,
    last_calculated_at TIMESTAMP NOT NULL,

    -- A shop should only have one row of statistics.
    UNIQUE KEY uk_shop_statistics_shop_id (shop_id),
    -- Foreign key to the shops table.
    CONSTRAINT fk_shop_statistics_shop
        FOREIGN KEY (shop_id) REFERENCES shops(shop_id)
        ON DELETE CASCADE
);

-- =================================================================
-- Segment 3: Comprehensive Product Management System
-- =================================================================
-- This segment covers everything related to products, including
-- categories, variants, attributes, inventory, and reviews.

-- Table: categories
-- Defines product categories in a hierarchical structure.
CREATE TABLE categories (
    category_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    -- Self-referencing foreign key for creating category trees (e.g., Electronics > Laptops).
    parent_category_id BIGINT UNSIGNED,
    category_name VARCHAR(255) NOT NULL,
    -- URL-friendly name, important for SEO and clean URLs.
    category_slug VARCHAR(255) NOT NULL UNIQUE,
    description TEXT,
    image_url VARCHAR(2048),
    -- Optional commission rate that overrides shop or platform defaults for products in this category.
    commission_rate_override DECIMAL(5, 2),
    sort_order INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    -- Foreign key to itself to establish the parent-child relationship.
    CONSTRAINT fk_categories_parent
        FOREIGN KEY (parent_category_id) REFERENCES categories(category_id)
        ON DELETE SET NULL -- If a parent is deleted, children become top-level categories.
);

-- Indexes for categories
-- Index for efficiently finding child categories.
CREATE INDEX idx_categories_parent_category_id ON categories(parent_category_id);
-- Index on is_active for quickly filtering active/inactive categories.
CREATE INDEX idx_categories_is_active ON categories(is_active);


-- Table: products
-- The main table for storing core product information.
CREATE TABLE products (
    product_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    shop_id BIGINT UNSIGNED NOT NULL,
    category_id BIGINT UNSIGNED NOT NULL,
    product_name VARCHAR(255) NOT NULL,
    -- Slug should be unique within a shop for clean product URLs.
    product_slug VARCHAR(255) NOT NULL,
    description TEXT,
    short_description VARCHAR(512),
    -- Stock Keeping Unit, should be unique per shop.
    sku VARCHAR(100),
    brand VARCHAR(100),
    status ENUM('draft', 'active', 'inactive', 'archived') NOT NULL DEFAULT 'draft',
    featured BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    -- Foreign key to the shops table.
    CONSTRAINT fk_products_shop
        FOREIGN KEY (shop_id) REFERENCES shops(shop_id)
        ON DELETE CASCADE,
    -- Foreign key to the categories table.
    CONSTRAINT fk_products_category
        FOREIGN KEY (category_id) REFERENCES categories(category_id)
        ON DELETE RESTRICT, -- Prevent deleting a category that still has products.
    -- Ensures a product slug is unique for a given shop.
    UNIQUE KEY uk_product_shop_slug (shop_id, product_slug),
    -- Ensures SKU is unique for a given shop.
    UNIQUE KEY uk_product_shop_sku (shop_id, sku)
);

-- Indexes for products
-- Indexes for filtering products by shop, category, and status.
CREATE INDEX idx_products_shop_id ON products(shop_id);
CREATE INDEX idx_products_category_id ON products(category_id);
CREATE INDEX idx_products_status ON products(status);
-- Full-text index for powerful product search.
CREATE FULLTEXT INDEX ft_products_name_desc ON products(product_name, description, short_description);


-- Table: product_variants
-- Stores different versions of a product (e.g., size, color).
CREATE TABLE product_variants (
    variant_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    product_id BIGINT UNSIGNED NOT NULL,
    variant_name VARCHAR(255), -- e.g., "Red, Large"
    sku VARCHAR(100),
    price DECIMAL(10, 2) NOT NULL,
    compare_price DECIMAL(10, 2), -- The "before" price for sales
    cost_price DECIMAL(10, 2), -- For internal profit calculation
    weight DECIMAL(10, 2), -- For shipping calculations
    dimensions_json JSON, -- e.g., {"height": 10, "width": 5, "depth": 2}
    barcode VARCHAR(100),
    is_default BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    -- Foreign key to the products table.
    CONSTRAINT fk_product_variants_product
        FOREIGN KEY (product_id) REFERENCES products(product_id)
        ON DELETE CASCADE,
    -- Variant SKU should be unique for a given product.
    UNIQUE KEY uk_variant_product_sku (product_id, sku)
);

-- Indexes for product_variants
CREATE INDEX idx_product_variants_product_id ON product_variants(product_id);
CREATE INDEX idx_product_variants_sku ON product_variants(sku);


-- Table: product_attributes
-- Defines reusable attributes like 'Color', 'Size', 'Material'.
CREATE TABLE product_attributes (
    attribute_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    attribute_name VARCHAR(100) NOT NULL UNIQUE,
    attribute_type ENUM('text', 'number', 'boolean', 'select') NOT NULL DEFAULT 'text',
    is_required BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);


-- Table: product_attribute_values
-- Assigns specific attribute values to products.
CREATE TABLE product_attribute_values (
    value_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    product_id BIGINT UNSIGNED NOT NULL,
    attribute_id BIGINT UNSIGNED NOT NULL,
    attribute_value VARCHAR(255) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    -- Foreign keys to link values to products and attributes.
    CONSTRAINT fk_product_attribute_values_product
        FOREIGN KEY (product_id) REFERENCES products(product_id)
        ON DELETE CASCADE,
    CONSTRAINT fk_product_attribute_values_attribute
        FOREIGN KEY (attribute_id) REFERENCES product_attributes(attribute_id)
        ON DELETE CASCADE,
    -- A product should only have one value for a given attribute.
    UNIQUE KEY uk_product_attribute (product_id, attribute_id)
);


-- Table: product_images
-- Stores images for products and their variants.
CREATE TABLE product_images (
    image_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    product_id BIGINT UNSIGNED NOT NULL,
    -- An image can be linked to a specific variant (e.g., a red shirt).
    variant_id BIGINT UNSIGNED,
    image_url VARCHAR(2048) NOT NULL,
    alt_text VARCHAR(255),
    sort_order INT NOT NULL DEFAULT 0,
    is_primary BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    -- Foreign keys to products and variants.
    CONSTRAINT fk_product_images_product
        FOREIGN KEY (product_id) REFERENCES products(product_id)
        ON DELETE CASCADE,
    CONSTRAINT fk_product_images_variant
        FOREIGN KEY (variant_id) REFERENCES product_variants(variant_id)
        ON DELETE SET NULL
);

-- Indexes for product_images
CREATE INDEX idx_product_images_product_id ON product_images(product_id);
CREATE INDEX idx_product_images_variant_id ON product_images(variant_id);


-- Table: product_inventory
-- Tracks stock levels for each product variant.
CREATE TABLE product_inventory (
    inventory_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    -- Each variant has its own inventory record.
    variant_id BIGINT UNSIGNED NOT NULL,
    quantity_available INT NOT NULL DEFAULT 0,
    -- Quantity reserved in open carts or pending orders.
    quantity_reserved INT NOT NULL DEFAULT 0,
    reorder_level INT,
    supplier_info_json JSON,
    last_updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    -- A variant can only have one inventory record.
    UNIQUE KEY uk_product_inventory_variant_id (variant_id),
    CONSTRAINT fk_product_inventory_variant
        FOREIGN KEY (variant_id) REFERENCES product_variants(variant_id)
        ON DELETE CASCADE
);


-- Table: product_reviews_summary
-- Denormalized table to hold aggregated review data for fast retrieval on product pages.
CREATE TABLE product_reviews_summary (
    summary_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    product_id BIGINT UNSIGNED NOT NULL,
    average_rating DECIMAL(3, 2) NOT NULL DEFAULT 0.00,
    total_reviews INT UNSIGNED NOT NULL DEFAULT 0,
    -- e.g., {"1": 10, "2": 5, "3": 20, "4": 50, "5": 100}
    rating_distribution_json JSON,
    last_updated_at TIMESTAMP NOT NULL,

    -- A product can only have one review summary.
    UNIQUE KEY uk_product_reviews_summary_product_id (product_id),
    CONSTRAINT fk_product_reviews_summary_product
        FOREIGN KEY (product_id) REFERENCES products(product_id)
        ON DELETE CASCADE
);

-- =================================================================
-- Segment 4: Comprehensive Order Management and Tracking System
-- =================================================================
-- This segment defines the tables for managing customer orders,
-- payments, shipping, and tracking from creation to delivery.

-- Table: orders
-- The primary table for storing order information.
CREATE TABLE orders (
    order_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    -- The Keycloak user ID of the customer who placed the order.
    customer_id VARCHAR(255) NOT NULL,
    -- A user-friendly, unique order identifier.
    order_number VARCHAR(50) NOT NULL UNIQUE,
    -- The current state of the order in the fulfillment pipeline.
    status ENUM('pending', 'processing', 'shipped', 'delivered', 'cancelled', 'refunded', 'failed') NOT NULL DEFAULT 'pending',
    -- Using DECIMAL for all financial values is crucial to avoid floating-point errors.
    subtotal DECIMAL(12, 2) NOT NULL,
    tax_amount DECIMAL(12, 2) NOT NULL DEFAULT 0.00,
    shipping_amount DECIMAL(12, 2) NOT NULL DEFAULT 0.00,
    discount_amount DECIMAL(12, 2) NOT NULL DEFAULT 0.00,
    total_amount DECIMAL(12, 2) NOT NULL,
    currency VARCHAR(10) NOT NULL,
    order_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    shipped_date TIMESTAMP NULL,
    delivered_date TIMESTAMP NULL,
    cancelled_date TIMESTAMP NULL,
    notes TEXT,

    -- Foreign key linking to the customer's profile.
    -- ON DELETE NO ACTION prevents deleting a customer with existing orders, forcing a manual review.
    CONSTRAINT fk_orders_customer
        FOREIGN KEY (customer_id) REFERENCES user_profiles(keycloak_user_id)
        ON DELETE NO ACTION
);

-- Indexes for orders
-- Index for finding all orders by a specific customer.
CREATE INDEX idx_orders_customer_id ON orders(customer_id);
-- Index on status for efficient querying of orders based on their current state (e.g., all 'processing' orders).
CREATE INDEX idx_orders_status ON orders(status);
-- Index on order_date for time-based reporting and analysis.
CREATE INDEX idx_orders_order_date ON orders(order_date);


-- Table: order_items
-- Stores the individual items included in an order.
CREATE TABLE order_items (
    item_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    order_id BIGINT UNSIGNED NOT NULL,
    product_id BIGINT UNSIGNED NOT NULL,
    variant_id BIGINT UNSIGNED NOT NULL,
    shop_id BIGINT UNSIGNED NOT NULL,
    quantity INT UNSIGNED NOT NULL,
    unit_price DECIMAL(10, 2) NOT NULL,
    total_price DECIMAL(12, 2) NOT NULL,
    -- Commission details are stored at the time of sale for historical accuracy.
    commission_rate DECIMAL(5, 2) NOT NULL,
    commission_amount DECIMAL(10, 2) NOT NULL,
    -- Status of the individual item, which could differ from the main order status.
    status ENUM('pending', 'shipped', 'delivered', 'cancelled', 'refunded') NOT NULL DEFAULT 'pending',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    -- Foreign keys linking the item to the order, product, variant, and shop.
    CONSTRAINT fk_order_items_order
        FOREIGN KEY (order_id) REFERENCES orders(order_id)
        ON DELETE CASCADE,
    CONSTRAINT fk_order_items_product
        FOREIGN KEY (product_id) REFERENCES products(product_id)
        ON DELETE RESTRICT,
    CONSTRAINT fk_order_items_variant
        FOREIGN KEY (variant_id) REFERENCES product_variants(variant_id)
        ON DELETE RESTRICT,
    CONSTRAINT fk_order_items_shop
        FOREIGN KEY (shop_id) REFERENCES shops(shop_id)
        ON DELETE RESTRICT
);

-- Indexes for order_items
CREATE INDEX idx_order_items_order_id ON order_items(order_id);
CREATE INDEX idx_order_items_product_id ON order_items(product_id);
CREATE INDEX idx_order_items_shop_id ON order_items(shop_id);


-- Table: order_addresses
-- Stores the billing and shipping addresses for an order.
CREATE TABLE order_addresses (
    address_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    order_id BIGINT UNSIGNED NOT NULL,
    address_type ENUM('billing', 'shipping') NOT NULL,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    company VARCHAR(255),
    address_line1 VARCHAR(255) NOT NULL,
    address_line2 VARCHAR(255),
    city VARCHAR(100) NOT NULL,
    state VARCHAR(100),
    country VARCHAR(100) NOT NULL,
    postal_code VARCHAR(20) NOT NULL,
    phone VARCHAR(50),

    -- An order should have only one of each address type.
    UNIQUE KEY uk_order_address_type (order_id, address_type),
    CONSTRAINT fk_order_addresses_order
        FOREIGN KEY (order_id) REFERENCES orders(order_id)
        ON DELETE CASCADE
);


-- Table: order_status_history
-- Logs every status change for an order, providing a full audit trail.
CREATE TABLE order_status_history (
    history_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    order_id BIGINT UNSIGNED NOT NULL,
    status VARCHAR(50) NOT NULL,
    changed_by VARCHAR(255), -- User ID of who made the change (customer or admin)
    changed_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    notes TEXT,
    notification_sent BOOLEAN NOT NULL DEFAULT FALSE,

    CONSTRAINT fk_order_status_history_order
        FOREIGN KEY (order_id) REFERENCES orders(order_id)
        ON DELETE CASCADE
);

-- Indexes for order_status_history
CREATE INDEX idx_order_status_history_order_id ON order_status_history(order_id);


-- Table: order_tracking
-- Stores shipping and tracking information for an order.
CREATE TABLE order_tracking (
    tracking_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    order_id BIGINT UNSIGNED NOT NULL,
    carrier VARCHAR(100),
    tracking_number VARCHAR(255),
    tracking_url VARCHAR(2048),
    status VARCHAR(100), -- Status from the carrier API
    location VARCHAR(255), -- Last known location from carrier
    estimated_delivery DATE,
    last_updated_at TIMESTAMP,

    -- An order can have multiple tracking numbers if items are shipped separately.
    UNIQUE KEY uk_order_tracking_number (order_id, tracking_number),
    CONSTRAINT fk_order_tracking_order
        FOREIGN KEY (order_id) REFERENCES orders(order_id)
        ON DELETE CASCADE
);


-- Table: order_payments
-- Logs payment attempts and transactions for an order.
CREATE TABLE order_payments (
    payment_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    order_id BIGINT UNSIGNED NOT NULL,
    payment_method VARCHAR(100),
    transaction_id VARCHAR(255), -- From the payment gateway
    amount DECIMAL(12, 2) NOT NULL,
    status ENUM('pending', 'completed', 'failed', 'refunded') NOT NULL,
    -- Store the raw response from the gateway for auditing and debugging.
    gateway_response_json JSON,
    processed_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_order_payments_order
        FOREIGN KEY (order_id) REFERENCES orders(order_id)
        ON DELETE CASCADE
);

-- Indexes for order_payments
CREATE INDEX idx_order_payments_transaction_id ON order_payments(transaction_id);


-- Table: order_refunds
-- Manages refund requests and processing.
CREATE TABLE order_refunds (
    refund_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    order_id BIGINT UNSIGNED NOT NULL,
    -- A refund can be for a specific item or the whole order (nullable).
    item_id BIGINT UNSIGNED,
    refund_amount DECIMAL(12, 2) NOT NULL,
    reason TEXT,
    status ENUM('pending', 'approved', 'processed', 'rejected') NOT NULL,
    processed_by VARCHAR(255), -- Admin user ID
    processed_at TIMESTAMP,
    notes TEXT,

    CONSTRAINT fk_order_refunds_order
        FOREIGN KEY (order_id) REFERENCES orders(order_id)
        ON DELETE CASCADE,
    CONSTRAINT fk_order_refunds_item
        FOREIGN KEY (item_id) REFERENCES order_items(item_id)
        ON DELETE SET NULL
);

-- Indexes for order_refunds
CREATE INDEX idx_order_refunds_status ON order_refunds(status);


-- Table: shipping_zones
-- Defines shipping regions and their associated rates.
CREATE TABLE shipping_zones (
    zone_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    zone_name VARCHAR(255) NOT NULL,
    -- JSON array of country codes, e.g., ["US", "CA"].
    countries_json JSON,
    -- Flexible JSON structure to define different shipping rates (e.g., by weight, flat rate).
    shipping_rates_json JSON,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- =================================================================
-- Segment 5: Financial Transaction Management and Commission Tracking
-- =================================================================
-- This segment handles all financial aspects, including transactions,
-- commission calculation, and payouts to vendors. Accuracy and
-- auditability are the highest priorities here.

-- Table: payment_methods
-- Defines the available payment methods and their configurations.
CREATE TABLE payment_methods (
    method_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    method_name VARCHAR(100) NOT NULL, -- e.g., 'Stripe', 'PayPal', 'Cash on Delivery'
    method_type ENUM('card', 'wallet', 'bank', 'cod') NOT NULL,
    gateway_name VARCHAR(100),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    -- For storing API keys, webhook secrets, etc.
    -- SECURITY NOTE: This data is highly sensitive and must be encrypted at rest.
    -- In a production environment, consider using a dedicated secrets manager.
    configuration_json JSON,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for payment_methods
CREATE INDEX idx_payment_methods_is_active ON payment_methods(is_active);


-- Table: transactions
-- A central ledger for every financial transaction on the platform.
CREATE TABLE transactions (
    transaction_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    -- Can be linked to an order, but not all transactions are (e.g., wallet top-up).
    order_id BIGINT UNSIGNED,
    -- The user initiating or receiving the transaction.
    user_id VARCHAR(255),
    transaction_type ENUM('payment', 'refund', 'commission', 'payout', 'wallet_deposit', 'wallet_withdrawal') NOT NULL,
    amount DECIMAL(15, 2) NOT NULL,
    currency VARCHAR(10) NOT NULL,
    status ENUM('pending', 'completed', 'failed', 'cancelled') NOT NULL,
    -- The unique ID from the payment gateway for external reference.
    gateway_transaction_id VARCHAR(255),
    -- Raw response from the gateway for auditing and dispute resolution.
    gateway_response_json JSON,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    processed_at TIMESTAMP,

    -- Foreign keys to orders and users.
    CONSTRAINT fk_transactions_order
        FOREIGN KEY (order_id) REFERENCES orders(order_id)
        ON DELETE SET NULL,
    CONSTRAINT fk_transactions_user
        FOREIGN KEY (user_id) REFERENCES user_profiles(keycloak_user_id)
        ON DELETE SET NULL
);

-- Indexes for transactions
CREATE INDEX idx_transactions_order_id ON transactions(order_id);
CREATE INDEX idx_transactions_user_id ON transactions(user_id);
CREATE INDEX idx_transactions_type_status ON transactions(transaction_type, status);
CREATE INDEX idx_transactions_gateway_id ON transactions(gateway_transaction_id);


-- Table: commissions
-- Records the commission earned by the platform for each order item.
CREATE TABLE commissions (
    commission_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    order_id BIGINT UNSIGNED NOT NULL,
    shop_id BIGINT UNSIGNED NOT NULL,
    item_id BIGINT UNSIGNED NOT NULL,
    commission_rate DECIMAL(5, 2) NOT NULL,
    -- The base amount on which the commission is calculated.
    gross_amount DECIMAL(12, 2) NOT NULL,
    commission_amount DECIMAL(10, 2) NOT NULL,
    -- Any additional fixed fees for the platform.
    platform_fee DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
    -- The final amount due to the shop owner (gross - commission - fee).
    net_amount DECIMAL(12, 2) NOT NULL,
    -- Status indicating if the commission is available for payout.
    status ENUM('pending', 'cleared', 'paid_out', 'disputed') NOT NULL DEFAULT 'pending',
    calculated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_commissions_order
        FOREIGN KEY (order_id) REFERENCES orders(order_id)
        ON DELETE CASCADE,
    CONSTRAINT fk_commissions_shop
        FOREIGN KEY (shop_id) REFERENCES shops(shop_id)
        ON DELETE CASCADE,
    CONSTRAINT fk_commissions_item
        FOREIGN KEY (item_id) REFERENCES order_items(item_id)
        ON DELETE CASCADE
);

-- Indexes for commissions
CREATE INDEX idx_commissions_shop_id_status ON commissions(shop_id, status);
CREATE INDEX idx_commissions_order_id ON commissions(order_id);


-- Table: payouts
-- Manages payout requests from shop owners.
CREATE TABLE payouts (
    payout_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    shop_id BIGINT UNSIGNED NOT NULL,
    payout_amount DECIMAL(15, 2) NOT NULL,
    currency VARCHAR(10) NOT NULL,
    status ENUM('pending', 'processing', 'completed', 'failed') NOT NULL,
    payout_method VARCHAR(100),
    -- Stores bank account, PayPal email, etc.
    -- SECURITY NOTE: This data must be encrypted at rest.
    bank_details_json JSON,
    requested_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    processed_at TIMESTAMP,
    -- Reference number from the payment processor for the payout transaction.
    reference_number VARCHAR(255),

    CONSTRAINT fk_payouts_shop
        FOREIGN KEY (shop_id) REFERENCES shops(shop_id)
        ON DELETE RESTRICT
);

-- Indexes for payouts
CREATE INDEX idx_payouts_shop_id_status ON payouts(shop_id, status);


-- Table: payout_transactions
-- A junction table linking a single payout to the multiple commissions it covers.
CREATE TABLE payout_transactions (
    payout_transaction_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    payout_id BIGINT UNSIGNED NOT NULL,
    commission_id BIGINT UNSIGNED NOT NULL,
    amount DECIMAL(12, 2) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_payout_transactions_payout
        FOREIGN KEY (payout_id) REFERENCES payouts(payout_id)
        ON DELETE CASCADE,
    CONSTRAINT fk_payout_transactions_commission
        FOREIGN KEY (commission_id) REFERENCES commissions(commission_id)
        ON DELETE CASCADE,
    UNIQUE KEY uk_payout_commission (payout_id, commission_id)
);


-- Table: invoices
-- For generating invoices, typically for shop fees or subscriptions.
CREATE TABLE invoices (
    invoice_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    shop_id BIGINT UNSIGNED NOT NULL,
    invoice_number VARCHAR(50) NOT NULL UNIQUE,
    billing_period_start DATE NOT NULL,
    billing_period_end DATE NOT NULL,
    subtotal DECIMAL(12, 2) NOT NULL,
    tax_amount DECIMAL(12, 2) NOT NULL,
    total_amount DECIMAL(12, 2) NOT NULL,
    status ENUM('draft', 'sent', 'paid', 'overdue', 'void') NOT NULL,
    generated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    due_date DATE,
    paid_at TIMESTAMP,

    CONSTRAINT fk_invoices_shop
        FOREIGN KEY (shop_id) REFERENCES shops(shop_id)
        ON DELETE CASCADE
);

-- Indexes for invoices
CREATE INDEX idx_invoices_shop_id_status ON invoices(shop_id, status);


-- Table: financial_reports
-- Stores pre-generated reports for performance.
CREATE TABLE financial_reports (
    report_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    report_type VARCHAR(100) NOT NULL, -- e.g., 'monthly_sales', 'tax_summary'
    -- Can be for a specific shop or platform-wide (nullable).
    shop_id BIGINT UNSIGNED,
    report_data_json JSON NOT NULL,
    period_start DATE NOT NULL,
    period_end DATE NOT NULL,
    generated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_financial_reports_shop
        FOREIGN KEY (shop_id) REFERENCES shops(shop_id)
        ON DELETE SET NULL
);


-- Table: wallet_transactions
-- A ledger for a user's internal wallet.
CREATE TABLE wallet_transactions (
    wallet_transaction_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id VARCHAR(255) NOT NULL,
    transaction_type ENUM('deposit', 'withdrawal', 'payment', 'refund_credit') NOT NULL,
    amount DECIMAL(12, 2) NOT NULL,
    balance_after DECIMAL(12, 2) NOT NULL,
    description VARCHAR(255),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_wallet_transactions_user
        FOREIGN KEY (user_id) REFERENCES user_profiles(keycloak_user_id)
        ON DELETE CASCADE
);

-- Indexes for wallet_transactions
CREATE INDEX idx_wallet_transactions_user_id ON wallet_transactions(user_id);

-- =================================================================
-- Segment 6: Comprehensive Review and Rating System
-- =================================================================
-- This segment provides the tables needed for a robust system
-- where customers can review products and shops, with moderation
-- and response capabilities.

-- Table: reviews
-- The core table for storing customer reviews of products.
CREATE TABLE reviews (
    review_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    product_id BIGINT UNSIGNED NOT NULL,
    -- Linking to order_item_id ensures the review is for a specific purchased item.
    order_item_id BIGINT UNSIGNED NOT NULL,
    customer_id VARCHAR(255) NOT NULL,
    shop_id BIGINT UNSIGNED NOT NULL,
    rating TINYINT UNSIGNED NOT NULL, -- Rating from 1 to 5.
    title VARCHAR(255),
    review_text TEXT,
    -- A crucial flag to indicate if the reviewer actually purchased the item.
    is_verified_purchase BOOLEAN NOT NULL DEFAULT FALSE,
    status ENUM('pending', 'approved', 'rejected') NOT NULL DEFAULT 'pending',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    -- A customer should only be able to review a specific purchased item once.
    UNIQUE KEY uk_review_order_item (order_item_id),
    CONSTRAINT fk_reviews_product
        FOREIGN KEY (product_id) REFERENCES products(product_id)
        ON DELETE CASCADE,
    CONSTRAINT fk_reviews_order_item
        FOREIGN KEY (order_item_id) REFERENCES order_items(item_id)
        ON DELETE CASCADE,
    CONSTRAINT fk_reviews_customer
        FOREIGN KEY (customer_id) REFERENCES user_profiles(keycloak_user_id)
        ON DELETE CASCADE,
    CONSTRAINT fk_reviews_shop
        FOREIGN KEY (shop_id) REFERENCES shops(shop_id)
        ON DELETE CASCADE,
    -- Ensures the rating value is within the valid range.
    CONSTRAINT chk_rating CHECK (rating >= 1 AND rating <= 5)
);

-- Indexes for reviews
CREATE INDEX idx_reviews_product_id_status ON reviews(product_id, status);
CREATE INDEX idx_reviews_shop_id_status ON reviews(shop_id, status);
CREATE INDEX idx_reviews_customer_id ON reviews(customer_id);


-- Table: review_images
-- Allows users to attach images to their reviews.
CREATE TABLE review_images (
    image_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    review_id BIGINT UNSIGNED NOT NULL,
    image_url VARCHAR(2048) NOT NULL,
    alt_text VARCHAR(255),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_review_images_review
        FOREIGN KEY (review_id) REFERENCES reviews(review_id)
        ON DELETE CASCADE
);


-- Table: review_responses
-- Allows shop owners or admins to respond to customer reviews.
CREATE TABLE review_responses (
    response_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    review_id BIGINT UNSIGNED NOT NULL,
    -- The user (shop owner, staff, admin) who is responding.
    responder_id VARCHAR(255) NOT NULL,
    response_text TEXT NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    -- Only one response per review is allowed.
    UNIQUE KEY uk_review_response (review_id),
    CONSTRAINT fk_review_responses_review
        FOREIGN KEY (review_id) REFERENCES reviews(review_id)
        ON DELETE CASCADE,
    CONSTRAINT fk_review_responses_responder
        FOREIGN KEY (responder_id) REFERENCES user_profiles(keycloak_user_id)
        ON DELETE CASCADE
);


-- Table: review_votes
-- Captures "helpful" or "not helpful" votes on reviews from other users.
CREATE TABLE review_votes (
    vote_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    review_id BIGINT UNSIGNED NOT NULL,
    user_id VARCHAR(255) NOT NULL,
    vote_type ENUM('helpful', 'not_helpful') NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_review_votes_review
        FOREIGN KEY (review_id) REFERENCES reviews(review_id)
        ON DELETE CASCADE,
    CONSTRAINT fk_review_votes_user
        FOREIGN KEY (user_id) REFERENCES user_profiles(keycloak_user_id)
        ON DELETE CASCADE,
    -- A user can only vote once per review.
    UNIQUE KEY uk_review_user_vote (review_id, user_id)
);


-- Table: shop_reviews
-- For reviews about the shop itself, separate from product reviews.
CREATE TABLE shop_reviews (
    shop_review_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    shop_id BIGINT UNSIGNED NOT NULL,
    customer_id VARCHAR(255) NOT NULL,
    -- Link to an order to verify the customer has experience with the shop.
    order_id BIGINT UNSIGNED NOT NULL,
    rating TINYINT UNSIGNED NOT NULL,
    title VARCHAR(255),
    review_text TEXT,
    status ENUM('pending', 'approved', 'rejected') NOT NULL DEFAULT 'pending',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_shop_reviews_shop
        FOREIGN KEY (shop_id) REFERENCES shops(shop_id)
        ON DELETE CASCADE,
    CONSTRAINT fk_shop_reviews_customer
        FOREIGN KEY (customer_id) REFERENCES user_profiles(keycloak_user_id)
        ON DELETE CASCADE,
    CONSTRAINT fk_shop_reviews_order
        FOREIGN KEY (order_id) REFERENCES orders(order_id)
        ON DELETE CASCADE,
    -- A customer can review a shop based on a specific order only once.
    UNIQUE KEY uk_shop_customer_order_review (shop_id, customer_id, order_id),
    CONSTRAINT chk_shop_rating CHECK (rating >= 1 AND rating <= 5)
);

-- Indexes for shop_reviews
CREATE INDEX idx_shop_reviews_shop_id_status ON shop_reviews(shop_id, status);


-- Table: rating_summaries
-- Denormalized table for high-performance retrieval of aggregated rating data.
CREATE TABLE rating_summaries (
    summary_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    -- Can be for a product or a shop.
    product_id BIGINT UNSIGNED,
    shop_id BIGINT UNSIGNED,
    average_rating DECIMAL(3, 2) NOT NULL DEFAULT 0.00,
    total_reviews INT UNSIGNED NOT NULL DEFAULT 0,
    rating_1_count INT UNSIGNED NOT NULL DEFAULT 0,
    rating_2_count INT UNSIGNED NOT NULL DEFAULT 0,
    rating_3_count INT UNSIGNED NOT NULL DEFAULT 0,
    rating_4_count INT UNSIGNED NOT NULL DEFAULT 0,
    rating_5_count INT UNSIGNED NOT NULL DEFAULT 0,
    last_updated_at TIMESTAMP NOT NULL,

    -- Ensure either product_id or shop_id is set, but not both.
    CONSTRAINT chk_summary_target CHECK (
        (product_id IS NOT NULL AND shop_id IS NULL) OR
        (product_id IS NULL AND shop_id IS NOT NULL)
    ),
    -- Create unique keys to ensure only one summary row per product or shop.
    UNIQUE KEY uk_rating_summary_product (product_id),
    UNIQUE KEY uk_rating_summary_shop (shop_id)
);


-- Table: review_moderation
-- Creates an audit trail for all moderation actions on reviews.
CREATE TABLE review_moderation (
    moderation_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    review_id BIGINT UNSIGNED NOT NULL,
    moderator_id VARCHAR(255) NOT NULL, -- Keycloak ID of the admin/moderator
    action ENUM('approve', 'reject', 'flag', 'edit') NOT NULL,
    reason TEXT,
    moderated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_review_moderation_review
        FOREIGN KEY (review_id) REFERENCES reviews(review_id)
        ON DELETE CASCADE,
    CONSTRAINT fk_review_moderation_moderator
        FOREIGN KEY (moderator_id) REFERENCES user_profiles(keycloak_user_id)
        ON DELETE NO ACTION
);

-- Indexes for review_moderation
CREATE INDEX idx_review_moderation_review_id ON review_moderation(review_id);
CREATE INDEX idx_review_moderation_moderator_id ON review_moderation(moderator_id);

-- =================================================================
-- Segment 7: Flexible Coupon and Discount Management System
-- =================================================================
-- This segment provides a flexible system for creating and managing
-- various types of discounts, coupons, and promotional campaigns.
-- It includes robust tracking to prevent abuse and analyze performance.

-- Table: coupons
-- The central table for defining individual discount coupons.
CREATE TABLE coupons (
    coupon_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    -- A coupon can be platform-wide (shop_id is NULL) or shop-specific.
    shop_id BIGINT UNSIGNED,
    coupon_code VARCHAR(100) NOT NULL UNIQUE,
    coupon_name VARCHAR(255),
    description TEXT,
    discount_type ENUM('percentage', 'fixed_amount', 'free_shipping') NOT NULL,
    -- The value of the discount (e.g., 10.0 for 10%, or 25.00 for $25).
    discount_value DECIMAL(10, 2) NOT NULL,
    minimum_order_amount DECIMAL(12, 2),
    maximum_discount_amount DECIMAL(12, 2), -- Useful for percentage discounts.
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    starts_at TIMESTAMP,
    expires_at TIMESTAMP,
    -- Total number of times the coupon can be used across all customers.
    usage_limit INT UNSIGNED,
    -- How many times a single customer can use this coupon.
    usage_limit_per_customer INT UNSIGNED,
    created_by VARCHAR(255), -- Keycloak ID of the admin/shop owner who created it.
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_coupons_shop
        FOREIGN KEY (shop_id) REFERENCES shops(shop_id)
        ON DELETE CASCADE
);

-- Indexes for coupons
CREATE INDEX idx_coupons_shop_id ON coupons(shop_id);
CREATE INDEX idx_coupons_is_active_dates ON coupons(is_active, starts_at, expires_at);


-- Table: coupon_usage
-- Logs every instance a coupon is successfully used in an order.
CREATE TABLE coupon_usage (
    usage_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    coupon_id BIGINT UNSIGNED NOT NULL,
    user_id VARCHAR(255) NOT NULL,
    order_id BIGINT UNSIGNED NOT NULL,
    discount_amount DECIMAL(12, 2) NOT NULL,
    used_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_coupon_usage_coupon
        FOREIGN KEY (coupon_id) REFERENCES coupons(coupon_id)
        ON DELETE CASCADE,
    CONSTRAINT fk_coupon_usage_user
        FOREIGN KEY (user_id) REFERENCES user_profiles(keycloak_user_id)
        ON DELETE CASCADE,
    CONSTRAINT fk_coupon_usage_order
        FOREIGN KEY (order_id) REFERENCES orders(order_id)
        ON DELETE CASCADE,
    -- An order can only have one usage record for a specific coupon.
    UNIQUE KEY uk_coupon_order (coupon_id, order_id)
);

-- Indexes for coupon_usage
CREATE INDEX idx_coupon_usage_user_id ON coupon_usage(user_id);


-- Table: discount_policies
-- For creating complex, rule-based discounts (e.g., "Buy 2, Get 1 Free").
CREATE TABLE discount_policies (
    policy_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    shop_id BIGINT UNSIGNED NOT NULL,
    policy_name VARCHAR(255) NOT NULL,
    policy_type ENUM('bulk_purchase', 'category_wide', 'customer_group') NOT NULL,
    -- JSON to define the rules, e.g., {"min_quantity": 3, "category_id": 12}.
    conditions_json JSON NOT NULL,
    -- JSON to define the discount, e.g., {"type": "percentage", "value": 15}.
    discount_json JSON NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    -- Priority to resolve conflicts if multiple policies apply. Higher number = higher priority.
    priority INT NOT NULL DEFAULT 0,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_discount_policies_shop
        FOREIGN KEY (shop_id) REFERENCES shops(shop_id)
        ON DELETE CASCADE
);


-- Table: promotional_campaigns
-- Manages marketing campaigns that might include multiple coupons or discounts.
CREATE TABLE promotional_campaigns (
    campaign_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    -- Can be a platform-wide or shop-specific campaign.
    shop_id BIGINT UNSIGNED,
    campaign_name VARCHAR(255) NOT NULL,
    campaign_type VARCHAR(100), -- e.g., 'Summer Sale', 'New Customer Offer'
    start_date DATE,
    end_date DATE,
    budget DECIMAL(15, 2),
    -- JSON to define the target audience, e.g., {"countries": ["US", "CA"], "min_purchase_history": 5}.
    target_audience_json JSON,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_promotional_campaigns_shop
        FOREIGN KEY (shop_id) REFERENCES shops(shop_id)
        ON DELETE CASCADE
);


-- Table: campaign_coupons
-- A junction table to link coupons to a promotional campaign.
CREATE TABLE campaign_coupons (
    campaign_coupon_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    campaign_id BIGINT UNSIGNED NOT NULL,
    coupon_id BIGINT UNSIGNED NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_campaign_coupons_campaign
        FOREIGN KEY (campaign_id) REFERENCES promotional_campaigns(campaign_id)
        ON DELETE CASCADE,
    CONSTRAINT fk_campaign_coupons_coupon
        FOREIGN KEY (coupon_id) REFERENCES coupons(coupon_id)
        ON DELETE CASCADE,
    UNIQUE KEY uk_campaign_coupon (campaign_id, coupon_id)
);


-- Table: customer_discount_eligibility
-- Stores pre-calculated eligibility for specific customers for complex discounts.
CREATE TABLE customer_discount_eligibility (
    eligibility_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    customer_id VARCHAR(255) NOT NULL,
    discount_policy_id BIGINT UNSIGNED NOT NULL,
    is_eligible BOOLEAN NOT NULL DEFAULT FALSE,
    calculated_at TIMESTAMP NOT NULL,

    CONSTRAINT fk_customer_discount_eligibility_customer
        FOREIGN KEY (customer_id) REFERENCES user_profiles(keycloak_user_id)
        ON DELETE CASCADE,
    CONSTRAINT fk_customer_discount_eligibility_policy
        FOREIGN KEY (discount_policy_id) REFERENCES discount_policies(policy_id)
        ON DELETE CASCADE,
    UNIQUE KEY uk_customer_policy (customer_id, discount_policy_id)
);


-- Table: discount_usage_analytics
-- Denormalized table for tracking the performance of coupons and discounts over time.
CREATE TABLE discount_usage_analytics (
    analytics_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    coupon_id BIGINT UNSIGNED,
    date DATE NOT NULL,
    usage_count INT UNSIGNED NOT NULL,
    total_discount_amount DECIMAL(15, 2) NOT NULL,
    -- A metric to estimate the sales generated by the discount.
    revenue_impact DECIMAL(15, 2) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_discount_usage_analytics_coupon
        FOREIGN KEY (coupon_id) REFERENCES coupons(coupon_id)
        ON DELETE SET NULL,
    UNIQUE KEY uk_coupon_date (coupon_id, date)
);

-- =================================================================
-- Segment 8: Comprehensive Analytics and Reporting
-- =================================================================
-- This segment focuses on collecting data for business intelligence.
-- It includes tables for raw event tracking and pre-aggregated
-- reports to ensure high performance for analytical queries.

-- Table: analytics_events
-- The raw event stream, capturing every significant user interaction.
CREATE TABLE analytics_events (
    event_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id VARCHAR(255),
    session_id VARCHAR(255),
    event_type VARCHAR(100) NOT NULL, -- e.g., 'page_view', 'add_to_cart', 'search'
    -- Flexible JSON to store event-specific data.
    event_data_json JSON,
    product_id BIGINT UNSIGNED,
    shop_id BIGINT UNSIGNED,
    order_id BIGINT UNSIGNED,
    ip_address VARCHAR(45),
    user_agent VARCHAR(512),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    -- Foreign keys are nullable as not all events relate to these entities.
    CONSTRAINT fk_analytics_events_user
        FOREIGN KEY (user_id) REFERENCES user_profiles(keycloak_user_id)
        ON DELETE SET NULL,
    CONSTRAINT fk_analytics_events_product
        FOREIGN KEY (product_id) REFERENCES products(product_id)
        ON DELETE SET NULL,
    CONSTRAINT fk_analytics_events_shop
        FOREIGN KEY (shop_id) REFERENCES shops(shop_id)
        ON DELETE SET NULL,
    CONSTRAINT fk_analytics_events_order
        FOREIGN KEY (order_id) REFERENCES orders(order_id)
        ON DELETE SET NULL
);

-- Indexes for analytics_events
-- Time-series index is crucial for analytical queries.
CREATE INDEX idx_analytics_events_created_at ON analytics_events(created_at);
-- Index for filtering events by type.
CREATE INDEX idx_analytics_events_event_type ON analytics_events(event_type);
-- Index for tracing all events within a user session.
CREATE INDEX idx_analytics_events_session_id ON analytics_events(session_id);


-- Table: daily_sales_reports
-- Pre-aggregated daily sales data for fast reporting.
CREATE TABLE daily_sales_reports (
    report_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    report_date DATE NOT NULL,
    -- Can be for a specific shop or platform-wide (NULL).
    shop_id BIGINT UNSIGNED,
    total_orders INT UNSIGNED NOT NULL,
    total_revenue DECIMAL(15, 2) NOT NULL,
    total_commission DECIMAL(15, 2) NOT NULL,
    average_order_value DECIMAL(15, 2) NOT NULL,
    new_customers INT UNSIGNED NOT NULL,
    returning_customers INT UNSIGNED NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    UNIQUE KEY uk_daily_sales_report_date_shop (report_date, shop_id)
);


-- Table: product_analytics
-- Aggregated daily analytics for each product.
CREATE TABLE product_analytics (
    analytics_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    product_id BIGINT UNSIGNED NOT NULL,
    date DATE NOT NULL,
    views INT UNSIGNED NOT NULL DEFAULT 0,
    clicks INT UNSIGNED NOT NULL DEFAULT 0,
    add_to_cart INT UNSIGNED NOT NULL DEFAULT 0,
    purchases INT UNSIGNED NOT NULL DEFAULT 0,
    revenue DECIMAL(15, 2) NOT NULL DEFAULT 0.00,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_product_analytics_product
        FOREIGN KEY (product_id) REFERENCES products(product_id)
        ON DELETE CASCADE,
    UNIQUE KEY uk_product_analytics_date (product_id, date)
);


-- Table: shop_performance
-- Aggregated daily performance metrics for each shop.
CREATE TABLE shop_performance (
    performance_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    shop_id BIGINT UNSIGNED NOT NULL,
    date DATE NOT NULL,
    orders_count INT UNSIGNED NOT NULL,
    revenue DECIMAL(15, 2) NOT NULL,
    commission_paid DECIMAL(15, 2) NOT NULL,
    average_rating DECIMAL(3, 2) NOT NULL,
    -- Average time to respond to customer inquiries.
    response_time_hours DECIMAL(10, 2),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_shop_performance_shop
        FOREIGN KEY (shop_id) REFERENCES shops(shop_id)
        ON DELETE CASCADE,
    UNIQUE KEY uk_shop_performance_date (shop_id, date)
);


-- Table: user_behavior_analytics
-- Aggregated daily analytics on user behavior.
CREATE TABLE user_behavior_analytics (
    behavior_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id VARCHAR(255) NOT NULL,
    date DATE NOT NULL,
    pages_viewed INT UNSIGNED NOT NULL,
    time_spent_minutes INT UNSIGNED NOT NULL,
    products_viewed INT UNSIGNED NOT NULL,
    searches_made INT UNSIGNED NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_user_behavior_analytics_user
        FOREIGN KEY (user_id) REFERENCES user_profiles(keycloak_user_id)
        ON DELETE CASCADE,
    UNIQUE KEY uk_user_behavior_date (user_id, date)
);


-- Table: platform_metrics
-- High-level, platform-wide metrics aggregated daily.
CREATE TABLE platform_metrics (
    metric_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    metric_date DATE NOT NULL UNIQUE,
    total_users INT UNSIGNED NOT NULL,
    active_users INT UNSIGNED NOT NULL,
    total_shops INT UNSIGNED NOT NULL,
    active_shops INT UNSIGNED NOT NULL,
    total_orders INT UNSIGNED NOT NULL,
    total_revenue DECIMAL(18, 2) NOT NULL,
    platform_commission DECIMAL(18, 2) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);


-- Table: custom_reports
-- Allows users to save the configuration for custom reports they build.
CREATE TABLE custom_reports (
    report_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    report_name VARCHAR(255) NOT NULL,
    report_type VARCHAR(100) NOT NULL,
    -- JSON defining the filters, dimensions, and metrics for the report.
    filters_json JSON NOT NULL,
    created_by VARCHAR(255) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    last_run_at TIMESTAMP,

    CONSTRAINT fk_custom_reports_user
        FOREIGN KEY (created_by) REFERENCES user_profiles(keycloak_user_id)
        ON DELETE CASCADE
);


-- Table: report_schedules
-- Schedules the automatic generation and delivery of reports.
CREATE TABLE report_schedules (
    schedule_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    report_id BIGINT UNSIGNED NOT NULL,
    frequency ENUM('daily', 'weekly', 'monthly') NOT NULL,
    -- JSON array of email addresses or user IDs to receive the report.
    recipients_json JSON NOT NULL,
    next_run_at TIMESTAMP NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_report_schedules_report
        FOREIGN KEY (report_id) REFERENCES custom_reports(report_id)
        ON DELETE CASCADE
);

-- =================================================================
-- Triggers for Automated Analytics Aggregation
-- =================================================================

DELIMITER $$

-- Trigger: trg_after_order_item_insert
-- Purpose: Updates product and shop analytics after a new order item is created.
CREATE TRIGGER trg_after_order_item_insert
AFTER INSERT ON order_items
FOR EACH ROW
BEGIN
    -- Update product analytics for the purchased product
    INSERT INTO product_analytics (product_id, date, purchases, revenue)
    VALUES (NEW.product_id, CURDATE(), NEW.quantity, NEW.total_price)
    ON DUPLICATE KEY UPDATE
        purchases = purchases + NEW.quantity,
        revenue = revenue + NEW.total_price;

    -- Update shop performance for the relevant shop
    INSERT INTO shop_performance (shop_id, date, orders_count, revenue, commission_paid, average_rating)
    VALUES (NEW.shop_id, CURDATE(), 1, NEW.total_price, NEW.commission_amount, 0)
    ON DUPLICATE KEY UPDATE
        orders_count = orders_count + 1,
        revenue = revenue + NEW.total_price,
        commission_paid = commission_paid + NEW.commission_amount;
END$$

-- Trigger: trg_after_order_insert
-- Purpose: Updates the platform-wide metrics after a new order is created.
CREATE TRIGGER trg_after_order_insert
AFTER INSERT ON orders
FOR EACH ROW
BEGIN
    -- Update platform-wide metrics
    INSERT INTO platform_metrics (metric_date, total_users, active_users, total_shops, active_shops, total_orders, total_revenue, platform_commission)
    VALUES (CURDATE(), 0, 0, 0, 0, 1, NEW.total_amount, 0)
    ON DUPLICATE KEY UPDATE
        total_orders = total_orders + 1,
        total_revenue = total_revenue + NEW.total_amount;
END$$


-- Trigger: trg_after_user_profile_insert
-- Purpose: Updates platform metrics when a new user registers.
CREATE TRIGGER trg_after_user_profile_insert
AFTER INSERT ON user_profiles
FOR EACH ROW
BEGIN
    INSERT INTO platform_metrics (metric_date, total_users, active_users, total_shops, active_shops, total_orders, total_revenue, platform_commission)
    VALUES (CURDATE(), 1, 1, 0, 0, 0, 0, 0)
    ON DUPLICATE KEY UPDATE
        total_users = total_users + 1,
        active_users = active_users + 1; -- Assuming new user is active
END$$


-- Trigger: trg_after_shop_insert
-- Purpose: Updates platform metrics when a new shop is created.
CREATE TRIGGER trg_after_shop_insert
AFTER INSERT ON shops
FOR EACH ROW
BEGIN
    INSERT INTO platform_metrics (metric_date, total_users, active_users, total_shops, active_shops, total_orders, total_revenue, platform_commission)
    VALUES (CURDATE(), 0, 0, 1, IF(NEW.status = 'approved', 1, 0), 0, 0, 0)
    ON DUPLICATE KEY UPDATE
        total_shops = total_shops + 1,
        active_shops = active_shops + IF(NEW.status = 'approved', 1, 0);
END$$

DELIMITER ;

-- =================================================================
-- Segment 9: Multi-Channel Notification System
-- =================================================================
-- This segment provides the infrastructure for a robust notification
-- system that can deliver messages across various channels like
-- email, SMS, and push notifications.

-- Table: notification_templates
-- Stores reusable templates for different types of notifications.
CREATE TABLE notification_templates (
    template_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    template_name VARCHAR(255) NOT NULL UNIQUE,
    template_type ENUM('email', 'sms', 'push', 'in_app') NOT NULL,
    -- For email templates, this would be the subject line. Can use placeholders.
    subject_template VARCHAR(512),
    -- The main content of the notification. Can use placeholders like {{username}}.
    body_template TEXT NOT NULL,
    -- A JSON array of variable names used in the template for validation. e.g., ["username", "order_id"]
    variables_json JSON,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);


-- Table: notifications
-- The central log of all notifications sent or scheduled to be sent.
CREATE TABLE notifications (
    notification_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id VARCHAR(255) NOT NULL,
    template_id BIGINT UNSIGNED,
    -- The general category of the notification, e.g., 'order_confirmation', 'new_review'.
    notification_type VARCHAR(100) NOT NULL,
    -- Final rendered title/subject.
    title VARCHAR(512),
    -- Final rendered message body.
    message TEXT NOT NULL,
    -- Any additional data to be sent, especially for push or in-app notifications (e.g., deep link URL).
    data_json JSON,
    -- The channels this notification should be sent through, e.g., ["email", "push"].
    channels_json JSON NOT NULL,
    priority ENUM('low', 'medium', 'high') NOT NULL DEFAULT 'medium',
    status ENUM('pending', 'sent', 'delivered', 'failed', 'read') NOT NULL DEFAULT 'pending',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    sent_at TIMESTAMP,
    read_at TIMESTAMP,

    CONSTRAINT fk_notifications_user
        FOREIGN KEY (user_id) REFERENCES user_profiles(keycloak_user_id)
        ON DELETE CASCADE,
    CONSTRAINT fk_notifications_template
        FOREIGN KEY (template_id) REFERENCES notification_templates(template_id)
        ON DELETE SET NULL
);

-- Indexes for notifications
CREATE INDEX idx_notifications_user_id_status ON notifications(user_id, status);
CREATE INDEX idx_notifications_type ON notifications(notification_type);


-- Table: notification_preferences
-- Stores user-specific choices about which notifications they want to receive.
-- This is a duplicate of the user_preferences table in the first segment, but focused on notification types.
-- A more normalized approach would be to have a single table. This is provided as requested.
CREATE TABLE notification_preferences (
    preference_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id VARCHAR(255) NOT NULL,
    -- The type of notification, linking to notifications.notification_type.
    notification_type VARCHAR(100) NOT NULL,
    email_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    sms_enabled BOOLEAN NOT NULL DEFAULT FALSE,
    push_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    in_app_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT fk_notification_preferences_user
        FOREIGN KEY (user_id) REFERENCES user_profiles(keycloak_user_id)
        ON DELETE CASCADE,
    UNIQUE KEY uk_user_notification_type (user_id, notification_type)
);


-- Table: notification_logs
-- A detailed log for each delivery attempt on each channel for a notification.
CREATE TABLE notification_logs (
    log_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    notification_id BIGINT UNSIGNED NOT NULL,
    channel ENUM('email', 'sms', 'push', 'in_app') NOT NULL,
    status ENUM('success', 'failed', 'deferred') NOT NULL,
    -- Stores the response from the delivery service (e.g., SMTP server, push gateway).
    response_data_json JSON,
    attempted_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    delivered_at TIMESTAMP,

    CONSTRAINT fk_notification_logs_notification
        FOREIGN KEY (notification_id) REFERENCES notifications(notification_id)
        ON DELETE CASCADE
);

-- Indexes for notification_logs
CREATE INDEX idx_notification_logs_notification_id ON notification_logs(notification_id);


-- Table: push_subscriptions
-- Stores the necessary endpoints and keys for sending web push notifications.
CREATE TABLE push_subscriptions (
    subscription_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id VARCHAR(255) NOT NULL,
    -- The unique endpoint URL provided by the browser's push service.
    endpoint VARCHAR(2048) NOT NULL UNIQUE,
    p256dh_key VARCHAR(255) NOT NULL,
    auth_key VARCHAR(255) NOT NULL,
    user_agent VARCHAR(512),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_push_subscriptions_user
        FOREIGN KEY (user_id) REFERENCES user_profiles(keycloak_user_id)
        ON DELETE CASCADE
);

-- Indexes for push_subscriptions
CREATE INDEX idx_push_subscriptions_user_id ON push_subscriptions(user_id);


-- Table: email_campaigns
-- Manages bulk email marketing campaigns.
CREATE TABLE email_campaigns (
    campaign_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    campaign_name VARCHAR(255) NOT NULL,
    template_id BIGINT UNSIGNED NOT NULL,
    -- JSON defining the target audience (e.g., all users in a country, or users who bought a specific product).
    target_audience_json JSON,
    scheduled_at TIMESTAMP,
    status ENUM('draft', 'scheduled', 'sending', 'sent', 'cancelled') NOT NULL DEFAULT 'draft',
    created_by VARCHAR(255),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_email_campaigns_template
        FOREIGN KEY (template_id) REFERENCES notification_templates(template_id)
        ON DELETE RESTRICT
);


-- Table: notification_queues
-- A dedicated queue table to manage the sending of notifications asynchronously.
CREATE TABLE notification_queues (
    queue_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    notification_id BIGINT UNSIGNED NOT NULL,
    channel ENUM('email', 'sms', 'push', 'in_app') NOT NULL,
    priority INT NOT NULL DEFAULT 10,
    scheduled_at TIMESTAMP NOT NULL,
    attempts INT UNSIGNED NOT NULL DEFAULT 0,
    max_attempts INT UNSIGNED NOT NULL DEFAULT 3,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_notification_queues_notification
        FOREIGN KEY (notification_id) REFERENCES notifications(notification_id)
        ON DELETE CASCADE
);

-- Indexes for notification_queues
-- Index to help the queue processor find the next job to run.
CREATE INDEX idx_notification_queues_scheduled_at_priority ON notification_queues(scheduled_at, priority);


-- =================================================================
-- Segment 10: Comprehensive Audit Logging and Security Monitoring
-- =================================================================
-- This final segment establishes a robust framework for security
-- and compliance. It includes detailed logging for all critical
-- actions, data changes, and security-related events, with
-- automated triggers to ensure a complete audit trail.

-- Table: audit_logs
-- A general-purpose log for high-level user actions.
CREATE TABLE audit_logs (
    log_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id VARCHAR(255),
    action VARCHAR(255) NOT NULL, -- e.g., 'create_product', 'update_shop_policy'
    resource_type VARCHAR(100),
    resource_id VARCHAR(255),
    -- Storing before and after states is crucial for forensic analysis.
    old_values_json JSON,
    new_values_json JSON,
    ip_address VARCHAR(45) NOT NULL,
    user_agent VARCHAR(512),
    timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_audit_logs_user
        FOREIGN KEY (user_id) REFERENCES user_profiles(keycloak_user_id)
        ON DELETE SET NULL
);

-- Indexes for audit_logs
CREATE INDEX idx_audit_logs_user_id ON audit_logs(user_id);
CREATE INDEX idx_audit_logs_resource ON audit_logs(resource_type, resource_id);
CREATE INDEX idx_audit_logs_timestamp ON audit_logs(timestamp);


-- Table: security_logs
-- Specifically for security-sensitive events.
CREATE TABLE security_logs (
    log_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id VARCHAR(255),
    event_type ENUM('login', 'logout', 'failed_login', 'password_change', 'suspicious_activity', 'permission_change') NOT NULL,
    ip_address VARCHAR(45) NOT NULL,
    user_agent VARCHAR(512),
    success BOOLEAN NOT NULL,
    failure_reason VARCHAR(255),
    timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_security_logs_user
        FOREIGN KEY (user_id) REFERENCES user_profiles(keycloak_user_id)
        ON DELETE SET NULL
);

-- Indexes for security_logs
CREATE INDEX idx_security_logs_event_type_success ON security_logs(event_type, success);
CREATE INDEX idx_security_logs_user_id ON security_logs(user_id);
CREATE INDEX idx_security_logs_ip_address ON security_logs(ip_address);


-- Table: data_change_logs
-- A low-level, trigger-populated log of all changes to critical tables.
CREATE TABLE data_change_logs (
    change_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    table_name VARCHAR(100) NOT NULL,
    record_id VARCHAR(255) NOT NULL,
    operation ENUM('INSERT', 'UPDATE', 'DELETE') NOT NULL,
    changed_by VARCHAR(255), -- User ID from the application context
    old_data_json JSON,
    new_data_json JSON,
    changed_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for data_change_logs
CREATE INDEX idx_data_change_logs_table_record ON data_change_logs(table_name, record_id);


-- Table: login_history
-- A detailed history of all login attempts for forensic analysis.
CREATE TABLE login_history (
    login_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id VARCHAR(255) NOT NULL,
    ip_address VARCHAR(45) NOT NULL,
    user_agent VARCHAR(512),
    -- GeoIP lookup data stored for mapping login locations.
    location_json JSON,
    login_method VARCHAR(50), -- e.g., 'password', 'google_oauth', 'keycloak_sso'
    success BOOLEAN NOT NULL,
    failure_reason VARCHAR(255),
    attempted_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_login_history_user
        FOREIGN KEY (user_id) REFERENCES user_profiles(keycloak_user_id)
        ON DELETE CASCADE
);

-- Indexes for login_history
CREATE INDEX idx_login_history_user_id ON login_history(user_id);
CREATE INDEX idx_login_history_ip_address ON login_history(ip_address);


-- Table: api_access_logs
-- Logs all requests made to your platform's API.
CREATE TABLE api_access_logs (
    log_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id VARCHAR(255),
    endpoint VARCHAR(512) NOT NULL,
    method VARCHAR(10) NOT NULL,
    request_data_json JSON,
    response_status INT,
    response_time_ms INT,
    ip_address VARCHAR(45),
    timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for api_access_logs
CREATE INDEX idx_api_access_logs_endpoint ON api_access_logs(endpoint);
CREATE INDEX idx_api_access_logs_user_id ON api_access_logs(user_id);


-- Table: security_incidents
-- A table for tracking and managing security incidents.
CREATE TABLE security_incidents (
    incident_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    incident_type VARCHAR(100) NOT NULL, -- e.g., 'data_breach', 'dos_attack', 'account_takeover'
    severity ENUM('low', 'medium', 'high', 'critical') NOT NULL,
    description TEXT NOT NULL,
    affected_users_json JSON,
    detected_at TIMESTAMP NOT NULL,
    resolved_at TIMESTAMP,
    resolution_notes TEXT
);


-- Table: system_backups
-- Logs metadata about system backups for disaster recovery planning.
CREATE TABLE system_backups (
    backup_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    backup_type ENUM('full', 'incremental', 'database', 'filesystem') NOT NULL,
    file_path VARCHAR(2048) NOT NULL,
    file_size BIGINT UNSIGNED,
    backup_started_at TIMESTAMP NOT NULL,
    backup_completed_at TIMESTAMP,
    status ENUM('in_progress', 'completed', 'failed') NOT NULL,
    checksum VARCHAR(255) -- e.g., SHA256 hash to verify integrity
);


-- Table: compliance_reports
-- Stores generated reports for compliance audits (e.g., GDPR, PCI-DSS).
CREATE TABLE compliance_reports (
    report_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    report_type VARCHAR(100) NOT NULL,
    period_start DATE NOT NULL,
    period_end DATE NOT NULL,
    report_data_json JSON NOT NULL,
    generated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- =================================================================
-- Triggers for Automated Data Change Logging & Security Monitoring
-- =================================================================

DELIMITER $$

-- Trigger: trg_user_profiles_after_update
-- Purpose: Logs changes to the user_profiles table.
CREATE TRIGGER trg_user_profiles_after_update
AFTER UPDATE ON user_profiles
FOR EACH ROW
BEGIN
    INSERT INTO data_change_logs (table_name, record_id, operation, old_data_json, new_data_json)
    VALUES (
        'user_profiles',
        OLD.profile_id,
        'UPDATE',
        JSON_OBJECT(
            'email', OLD.email,
            'phone', OLD.phone,
            'first_name', OLD.first_name,
            'last_name', OLD.last_name,
            'status', OLD.status
        ),
        JSON_OBJECT(
            'email', NEW.email,
            'phone', NEW.phone,
            'first_name', NEW.first_name,
            'last_name', NEW.last_name,
            'status', NEW.status
        )
    );
END$$

-- Trigger: trg_shops_after_update
-- Purpose: Logs changes to sensitive fields in the shops table.
CREATE TRIGGER trg_shops_after_update
AFTER UPDATE ON shops
FOR EACH ROW
BEGIN
    -- Only log if sensitive data has changed
    IF OLD.status <> NEW.status OR OLD.commission_rate <> NEW.commission_rate OR OLD.owner_id <> NEW.owner_id THEN
        INSERT INTO data_change_logs (table_name, record_id, operation, old_data_json, new_data_json)
        VALUES (
            'shops',
            OLD.shop_id,
            'UPDATE',
            JSON_OBJECT(
                'status', OLD.status,
                'commission_rate', OLD.commission_rate,
                'owner_id', OLD.owner_id
            ),
            JSON_OBJECT(
                'status', NEW.status,
                'commission_rate', NEW.commission_rate,
                'owner_id', NEW.owner_id
            )
        );
    END IF;
END$$

-- Trigger: trg_products_after_insert
-- Purpose: Logs the creation of new products.
CREATE TRIGGER trg_products_after_insert
AFTER INSERT ON products
FOR EACH ROW
BEGIN
    INSERT INTO data_change_logs (table_name, record_id, operation, new_data_json)
    VALUES (
        'products',
        NEW.product_id,
        'INSERT',
        JSON_OBJECT(
            'product_name', NEW.product_name,
            'shop_id', NEW.shop_id,
            'category_id', NEW.category_id,
            'status', NEW.status
        )
    );
END$$

-- Trigger: trg_orders_after_update
-- Purpose: Logs significant status changes in orders to the main audit log.
CREATE TRIGGER trg_orders_after_update
AFTER UPDATE ON orders
FOR EACH ROW
BEGIN
    -- Log only when the status changes, as this is a key event in the order lifecycle.
    IF OLD.status <> NEW.status THEN
        INSERT INTO audit_logs (user_id, action, resource_type, resource_id, old_values_json, new_values_json, ip_address)
        VALUES (
            NEW.customer_id,
            'update_order_status',
            'order',
            NEW.order_id,
            JSON_OBJECT('status', OLD.status),
            JSON_OBJECT('status', NEW.status),
            '::1' -- IP address should be captured from the application context
        );
    END IF;
END$$

-- Trigger: trg_payouts_after_update
-- Purpose: Logs changes to payout status, a critical financial event.
CREATE TRIGGER trg_payouts_after_update
AFTER UPDATE ON payouts
FOR EACH ROW
BEGIN
    IF OLD.status <> NEW.status THEN
        INSERT INTO data_change_logs (table_name, record_id, operation, old_data_json, new_data_json)
        VALUES (
            'payouts',
            OLD.payout_id,
            'UPDATE',
            JSON_OBJECT('status', OLD.status, 'amount', OLD.payout_amount),
            JSON_OBJECT('status', NEW.status, 'amount', NEW.payout_amount, 'processed_at', NEW.processed_at)
        );
    END IF;
END$$

-- Trigger: trg_after_failed_login
-- Purpose: Detects potential brute-force attacks by logging suspicious activity.
CREATE TRIGGER trg_after_failed_login
AFTER INSERT ON login_history
FOR EACH ROW
BEGIN
    DECLARE failed_count INT;
    -- Check for failed logins from the same IP in the last 5 minutes.
    IF NEW.success = 0 THEN
        SELECT COUNT(*)
        INTO failed_count
        FROM login_history
        WHERE ip_address = NEW.ip_address
          AND success = 0
          AND attempted_at > (NOW() - INTERVAL 5 MINUTE);

        -- If more than 5 failed attempts, log a security event.
        IF failed_count > 5 THEN
            INSERT INTO security_logs (user_id, event_type, ip_address, user_agent, success, failure_reason)
            VALUES (NEW.user_id, 'suspicious_activity', NEW.ip_address, NEW.user_agent, 0, 'Multiple failed login attempts detected.');
        END IF;
    END IF;
END$$

DELIMITER ;
