-- Consolidated baseline migration
-- Generated from historical migrations on 2026-02-28
CREATE EXTENSION IF NOT EXISTS pgcrypto;


-- ===== BEGIN 20250829160942_green_stream.sql =====
/*
  # Create Menu Management System

  1. New Tables
    - `menu_items`
      - `id` (uuid, primary key)
      - `name` (text)
      - `description` (text)
      - `base_price` (decimal)
      - `category` (text)
      - `popular` (boolean)
      - `image_url` (text, optional)
      - `created_at` (timestamp)
      - `updated_at` (timestamp)
    
    - `variations`
      - `id` (uuid, primary key)
      - `menu_item_id` (uuid, foreign key)
      - `name` (text)
      - `price` (decimal)
      - `created_at` (timestamp)
    
    - `add_ons`
      - `id` (uuid, primary key)
      - `menu_item_id` (uuid, foreign key)
      - `name` (text)
      - `price` (decimal)
      - `category` (text)
      - `created_at` (timestamp)

  2. Security
    - Enable RLS on all tables
    - Add policies for public read access
    - Add policies for authenticated admin access
*/

-- Create menu_items table
CREATE TABLE IF NOT EXISTS menu_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  description text NOT NULL,
  base_price decimal(10,2) NOT NULL,
  category text NOT NULL,
  popular boolean DEFAULT false,
  image_url text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create variations table
CREATE TABLE IF NOT EXISTS variations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  menu_item_id uuid REFERENCES menu_items(id) ON DELETE CASCADE,
  name text NOT NULL,
  price decimal(10,2) NOT NULL DEFAULT 0,
  created_at timestamptz DEFAULT now()
);

-- Create add_ons table
CREATE TABLE IF NOT EXISTS add_ons (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  menu_item_id uuid REFERENCES menu_items(id) ON DELETE CASCADE,
  name text NOT NULL,
  price decimal(10,2) NOT NULL DEFAULT 0,
  category text NOT NULL,
  created_at timestamptz DEFAULT now()
);

-- Enable RLS
ALTER TABLE menu_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE variations ENABLE ROW LEVEL SECURITY;
ALTER TABLE add_ons ENABLE ROW LEVEL SECURITY;

-- Create policies for public read access
CREATE POLICY "Anyone can read menu items"
  ON menu_items
  FOR SELECT
  TO public
  USING (true);

CREATE POLICY "Anyone can read variations"
  ON variations
  FOR SELECT
  TO public
  USING (true);

CREATE POLICY "Anyone can read add-ons"
  ON add_ons
  FOR SELECT
  TO public
  USING (true);

-- Create policies for authenticated admin access
CREATE POLICY "Authenticated users can manage menu items"
  ON menu_items
  FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);

CREATE POLICY "Authenticated users can manage variations"
  ON variations
  FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);

CREATE POLICY "Authenticated users can manage add-ons"
  ON add_ons
  FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);

-- Create updated_at trigger function
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ language 'plpgsql';

-- Create trigger for menu_items
CREATE TRIGGER update_menu_items_updated_at
  BEFORE UPDATE ON menu_items
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();
-- ===== END 20250829160942_green_stream.sql =====

-- ===== BEGIN 20250829162038_lucky_portal.sql =====
/*
  # Add availability field to menu items

  1. Changes
    - Add `available` boolean field to menu_items table
    - Set default value to true for existing items
    - Update trigger function to handle the new field

  2. Security
    - No changes to existing RLS policies needed
*/

-- Add availability field to menu_items table
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'menu_items' AND column_name = 'available'
  ) THEN
    ALTER TABLE menu_items ADD COLUMN available boolean DEFAULT true;
  END IF;
END $$;
-- ===== END 20250829162038_lucky_portal.sql =====

-- ===== BEGIN 20250901005107_calm_pine.sql =====
/*
  # Create Categories Management System

  1. New Tables
    - `categories`
      - `id` (text, primary key) - kebab-case identifier
      - `name` (text) - display name
      - `icon` (text) - emoji or icon
      - `sort_order` (integer) - for ordering categories
      - `active` (boolean) - whether category is active
      - `created_at` (timestamp)
      - `updated_at` (timestamp)

  2. Security
    - Enable RLS on categories table
    - Add policies for public read access
    - Add policies for authenticated admin access

  3. Data Migration
    - Insert existing categories from the current hardcoded list
*/

-- Create categories table
CREATE TABLE IF NOT EXISTS categories (
  id text PRIMARY KEY,
  name text NOT NULL,
  icon text NOT NULL DEFAULT '☕',
  sort_order integer NOT NULL DEFAULT 0,
  active boolean DEFAULT true,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Enable RLS
ALTER TABLE categories ENABLE ROW LEVEL SECURITY;

-- Create policies for public read access
CREATE POLICY "Anyone can read categories"
  ON categories
  FOR SELECT
  TO public
  USING (active = true);

-- Create policies for authenticated admin access
CREATE POLICY "Authenticated users can manage categories"
  ON categories
  FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);

-- Create updated_at trigger for categories
CREATE TRIGGER update_categories_updated_at
  BEFORE UPDATE ON categories
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- Insert existing categories
INSERT INTO categories (id, name, icon, sort_order, active) VALUES
  ('hot-coffee', 'Hot Coffee', '☕', 1, true),
  ('iced-coffee', 'Iced Coffee', '🧊', 2, true),
  ('non-coffee', 'Non-Coffee', '🫖', 3, true),
  ('food', 'Food & Pastries', '🥐', 4, true),
  ('dim-sum', 'Dim Sum', '🥟', 5, true)
ON CONFLICT (id) DO NOTHING;

-- Add foreign key constraint to menu_items table
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints
    WHERE constraint_name = 'menu_items_category_fkey'
  ) THEN
    ALTER TABLE menu_items 
    ADD CONSTRAINT menu_items_category_fkey 
    FOREIGN KEY (category) REFERENCES categories(id);
  END IF;
END $$;
-- ===== END 20250901005107_calm_pine.sql =====

-- ===== BEGIN 20250901125510_floating_sky.sql =====
/*
  # Create Payment Methods Management System

  1. New Tables
    - `payment_methods`
      - `id` (text, primary key) - method identifier (gcash, maya, bank-transfer)
      - `name` (text) - display name
      - `account_number` (text) - phone number or account number
      - `account_name` (text) - account holder name
      - `qr_code_url` (text) - QR code image URL
      - `active` (boolean) - whether method is active
      - `sort_order` (integer) - display order
      - `created_at` (timestamp)
      - `updated_at` (timestamp)

  2. Security
    - Enable RLS on payment_methods table
    - Add policies for public read access
    - Add policies for authenticated admin access

  3. Initial Data
    - Insert default payment methods
*/

-- Create payment_methods table
CREATE TABLE IF NOT EXISTS payment_methods (
  id text PRIMARY KEY,
  name text NOT NULL,
  account_number text NOT NULL,
  account_name text NOT NULL,
  qr_code_url text NOT NULL,
  active boolean DEFAULT true,
  sort_order integer NOT NULL DEFAULT 0,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Enable RLS
ALTER TABLE payment_methods ENABLE ROW LEVEL SECURITY;

-- Create policies for public read access
CREATE POLICY "Anyone can read active payment methods"
  ON payment_methods
  FOR SELECT
  TO public
  USING (active = true);

-- Create policies for authenticated admin access
CREATE POLICY "Authenticated users can manage payment methods"
  ON payment_methods
  FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);

-- Create updated_at trigger for payment_methods
CREATE TRIGGER update_payment_methods_updated_at
  BEFORE UPDATE ON payment_methods
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- Insert default payment methods
INSERT INTO payment_methods (id, name, account_number, account_name, qr_code_url, sort_order, active) VALUES
  ('gcash', 'GCash', '09XX XXX XXXX', 'food trip - abra', 'https://images.pexels.com/photos/8867482/pexels-photo-8867482.jpeg?auto=compress&cs=tinysrgb&w=300&h=300&fit=crop', 1, true),
  ('maya', 'Maya (PayMaya)', '09XX XXX XXXX', 'food trip - abra', 'https://images.pexels.com/photos/8867482/pexels-photo-8867482.jpeg?auto=compress&cs=tinysrgb&w=300&h=300&fit=crop', 2, true),
  ('bank-transfer', 'Bank Transfer', 'Account: 1234-5678-9012', 'food trip - abra', 'https://images.pexels.com/photos/8867482/pexels-photo-8867482.jpeg?auto=compress&cs=tinysrgb&w=300&h=300&fit=crop', 3, true)
ON CONFLICT (id) DO NOTHING;
-- ===== END 20250901125510_floating_sky.sql =====

-- ===== BEGIN 20250901170000_orders.sql =====
/*
  Orders and Order Items

  - orders: stores customer/order-level info
  - order_items: line items linked to orders
  - RLS enabled with permissive policies for public insert/select (adjust as needed)
*/

-- Enable required extension for UUID if not already
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Orders table
CREATE TABLE IF NOT EXISTS orders (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_name text NOT NULL,
  contact_number text NOT NULL,
  service_type text NOT NULL CHECK (service_type IN ('dine-in','pickup','delivery')),
  address text,
  pickup_time text,
  party_size integer,
  dine_in_time timestamptz,
  payment_method text NOT NULL,
  reference_number text,
  notes text,
  total numeric(12,2) NOT NULL,
  status text NOT NULL DEFAULT 'pending',
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Order items table
CREATE TABLE IF NOT EXISTS order_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id uuid NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  item_id text NOT NULL,
  name text NOT NULL,
  variation jsonb,
  add_ons jsonb,
  unit_price numeric(12,2) NOT NULL,
  quantity integer NOT NULL CHECK (quantity > 0),
  subtotal numeric(12,2) NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Enable RLS
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_items ENABLE ROW LEVEL SECURITY;

-- Policies (adjust to your security model)
-- Allow anyone to insert an order
CREATE POLICY "Public can insert orders"
  ON orders FOR INSERT TO public WITH CHECK (true);

-- Allow anyone to view orders (consider restricting to authenticated/admin later)
CREATE POLICY "Public can select orders"
  ON orders FOR SELECT TO public USING (true);

-- Allow anyone to insert order items
CREATE POLICY "Public can insert order items"
  ON order_items FOR INSERT TO public WITH CHECK (true);

-- Allow anyone to view order items
CREATE POLICY "Public can select order items"
  ON order_items FOR SELECT TO public USING (true);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_orders_created_at ON orders(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_order_items_order_id ON order_items(order_id);



-- ===== END 20250901170000_orders.sql =====

-- ===== BEGIN 20250108000000_add_receipt_url.sql =====
/*
  Add receipt_url column to orders table for storing uploaded receipt image URLs
*/

-- Add receipt_url column to orders table
ALTER TABLE orders ADD COLUMN IF NOT EXISTS receipt_url text;

-- Add index for faster lookups if needed
CREATE INDEX IF NOT EXISTS idx_orders_receipt_url ON orders(receipt_url) WHERE receipt_url IS NOT NULL;

-- Add comment to document the column
COMMENT ON COLUMN orders.receipt_url IS 'URL of the payment receipt image uploaded to Cloudinary';


-- ===== END 20250108000000_add_receipt_url.sql =====

-- ===== BEGIN 20250101000000_add_discount_pricing_and_site_settings.sql =====
/*
  # Add Discount Pricing and Site Settings

  1. Menu Items Changes
    - Add `discount_price` (decimal, optional) - discounted price
    - Add `discount_start_date` (timestamp, optional) - when discount starts
    - Add `discount_end_date` (timestamp, optional) - when discount ends
    - Add `discount_active` (boolean) - whether discount is currently active

  2. New Tables
    - `site_settings`
      - `id` (text, primary key) - setting key
      - `value` (text) - setting value
      - `type` (text) - setting type (text, image, boolean, number)
      - `description` (text) - setting description
      - `updated_at` (timestamp)

  3. Security
    - Enable RLS on site_settings table
    - Add policies for public read access
    - Add policies for authenticated admin access
*/

-- Add discount pricing fields to menu_items table
DO $$
BEGIN
  -- Add discount_price column
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'menu_items' AND column_name = 'discount_price'
  ) THEN
    ALTER TABLE menu_items ADD COLUMN discount_price decimal(10,2);
  END IF;

  -- Add discount_start_date column
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'menu_items' AND column_name = 'discount_start_date'
  ) THEN
    ALTER TABLE menu_items ADD COLUMN discount_start_date timestamptz;
  END IF;

  -- Add discount_end_date column
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'menu_items' AND column_name = 'discount_end_date'
  ) THEN
    ALTER TABLE menu_items ADD COLUMN discount_end_date timestamptz;
  END IF;

  -- Add discount_active column
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'menu_items' AND column_name = 'discount_active'
  ) THEN
    ALTER TABLE menu_items ADD COLUMN discount_active boolean DEFAULT false;
  END IF;
END $$;

-- Create site_settings table
CREATE TABLE IF NOT EXISTS site_settings (
  id text PRIMARY KEY,
  value text NOT NULL,
  type text NOT NULL DEFAULT 'text',
  description text,
  updated_at timestamptz DEFAULT now()
);

-- Enable RLS
ALTER TABLE site_settings ENABLE ROW LEVEL SECURITY;

-- Create policies for public read access
CREATE POLICY "Anyone can read site settings"
  ON site_settings
  FOR SELECT
  TO public
  USING (true);

-- Create policies for authenticated admin access
CREATE POLICY "Authenticated users can manage site settings"
  ON site_settings
  FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);

-- Create updated_at trigger for site_settings
CREATE TRIGGER update_site_settings_updated_at
  BEFORE UPDATE ON site_settings
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- Insert default site settings
INSERT INTO site_settings (id, value, type, description) VALUES
  ('site_name', 'food trip - abra', 'text', 'The name of the cafe/restaurant'),
  ('site_logo', '/logo.jpg', 'image', 'The logo image URL for the site'),
  ('site_description', 'Welcome to food trip - abra', 'text', 'Short description of the cafe'),
  ('currency', 'PHP', 'text', 'Currency symbol for prices'),
  ('currency_code', 'PHP', 'text', 'Currency code for payments')
ON CONFLICT (id) DO NOTHING;

-- Create function to check if discount is active
CREATE OR REPLACE FUNCTION is_discount_active(
  discount_active boolean,
  discount_start_date timestamptz,
  discount_end_date timestamptz
)
RETURNS boolean AS $$
BEGIN
  -- If discount is not active, return false
  IF NOT discount_active THEN
    RETURN false;
  END IF;
  
  -- If no dates are set, return the discount_active value
  IF discount_start_date IS NULL AND discount_end_date IS NULL THEN
    RETURN discount_active;
  END IF;
  
  -- Check if current time is within the discount period
  RETURN (
    (discount_start_date IS NULL OR now() >= discount_start_date) AND
    (discount_end_date IS NULL OR now() <= discount_end_date)
  );
END;
$$ LANGUAGE plpgsql;

-- Create function to get effective price (discounted or regular)
CREATE OR REPLACE FUNCTION get_effective_price(
  base_price decimal,
  discount_price decimal,
  discount_active boolean,
  discount_start_date timestamptz,
  discount_end_date timestamptz
)
RETURNS decimal AS $$
BEGIN
  -- If discount is active and within date range, return discount price
  IF is_discount_active(discount_active, discount_start_date, discount_end_date) AND discount_price IS NOT NULL THEN
    RETURN discount_price;
  END IF;
  
  -- Otherwise return base price
  RETURN base_price;
END;
$$ LANGUAGE plpgsql;

-- Add computed columns for effective pricing (if supported by your Supabase version)
-- Note: These are comments as computed columns might not be available in all Supabase versions
-- You can implement this logic in your application instead

-- Create index for better performance on discount queries
CREATE INDEX IF NOT EXISTS idx_menu_items_discount_active ON menu_items(discount_active);
CREATE INDEX IF NOT EXISTS idx_menu_items_discount_dates ON menu_items(discount_start_date, discount_end_date);

-- ===== END 20250101000000_add_discount_pricing_and_site_settings.sql =====

-- ===== BEGIN 20250901015559_frosty_wildflower.sql =====
/*
  # Add Food Trip - Abra Menu Items

  1. New Menu Items
    - Bread category: Artisan breads including ciabatta, brioche, sourdough varieties
    - Biscotti category: Almond, mango almond, and biscotti bites
    - Soft Bread category: Pan de coco, cheese rolls, and various filled breads
    - Cookies category: Chocolate chip cookies
    - Banana Bread category: Plain and chocolate varieties
    - Cake category: Chocolate, carrot, and biscoff cheesecake
    - Others category: Artisan biscocho and butterscotch

  2. Features
    - Variations for items with multiple options (brioche, olive bread, etc.)
    - Special availability notes for sourdough and focaccia items
    - Proper categorization and pricing
    - High-quality bakery images from Pexels

  3. Categories
    - Updates existing food category items
    - Maintains existing coffee categories
*/

-- Insert bread items
INSERT INTO menu_items (name, description, base_price, category, popular, available, image_url) VALUES
  ('Artisan Ciabatta', 'Traditional Italian bread with a crispy crust and airy interior, perfect for sandwiches or dipping', 180, 'food', false, true, 'https://images.pexels.com/photos/1775043/pexels-photo-1775043.jpeg?auto=compress&cs=tinysrgb&w=800'),
  ('Brioche', 'Rich, buttery French bread with a golden crust and tender crumb', 300, 'food', true, true, 'https://images.pexels.com/photos/4110256/pexels-photo-4110256.jpeg?auto=compress&cs=tinysrgb&w=800'),
  ('Olive Bread', 'Mediterranean-style bread infused with premium olives', 250, 'food', false, true, 'https://images.pexels.com/photos/4110007/pexels-photo-4110007.jpeg?auto=compress&cs=tinysrgb&w=800'),
  ('Sourdough Sandwich Loaf', 'Tangy sourdough perfect for sandwiches (Available Wednesday & Saturday)', 280, 'food', true, true, 'https://images.pexels.com/photos/4110251/pexels-photo-4110251.jpeg?auto=compress&cs=tinysrgb&w=800'),
  ('Sourdough Bread', 'Classic artisan sourdough with complex flavors (Available Wednesday & Saturday)', 280, 'food', true, true, 'https://images.pexels.com/photos/1775043/pexels-photo-1775043.jpeg?auto=compress&cs=tinysrgb&w=800'),
  ('Sourdough Olive Bread', 'Tangy sourdough with Mediterranean olives (Available Wednesday & Saturday)', 350, 'food', false, true, 'https://images.pexels.com/photos/4110007/pexels-photo-4110007.jpeg?auto=compress&cs=tinysrgb&w=800'),
  ('Sourdough Olive and Cheese Bread', 'Sourdough with olives and aged cheese (Available Wednesday & Saturday)', 350, 'food', false, true, 'https://images.pexels.com/photos/4110007/pexels-photo-4110007.jpeg?auto=compress&cs=tinysrgb&w=800'),
  ('Jalapeño and Cheddar Cheese Sourdough', 'Spicy jalapeños with sharp cheddar in tangy sourdough (Available Wednesday & Saturday)', 350, 'food', false, true, 'https://images.pexels.com/photos/4110251/pexels-photo-4110251.jpeg?auto=compress&cs=tinysrgb&w=800'),
  ('Focaccia', 'Italian flatbread with herbs and olive oil (Available Wednesday & Saturday)', 250, 'food', false, true, 'https://images.pexels.com/photos/4110256/pexels-photo-4110256.jpeg?auto=compress&cs=tinysrgb&w=800'),
  ('Baguette', 'Classic French bread with crispy crust (Available Saturday)', 180, 'food', false, true, 'https://images.pexels.com/photos/1775043/pexels-photo-1775043.jpeg?auto=compress&cs=tinysrgb&w=800')
ON CONFLICT (id) DO NOTHING;

-- Insert biscotti items
INSERT INTO menu_items (name, description, base_price, category, popular, available, image_url) VALUES
  ('Almond Biscotti', 'Traditional Italian twice-baked cookies with whole almonds, perfect with coffee', 275, 'food', true, true, 'https://images.pexels.com/photos/4110252/pexels-photo-4110252.jpeg?auto=compress&cs=tinysrgb&w=800'),
  ('Mango Almond Biscotti', 'Tropical twist on classic biscotti with dried mango and almonds', 300, 'food', false, true, 'https://images.pexels.com/photos/4110252/pexels-photo-4110252.jpeg?auto=compress&cs=tinysrgb&w=800'),
  ('Biscotti Bites', 'Mini biscotti perfect for sharing or a quick sweet treat', 100, 'food', false, true, 'https://images.pexels.com/photos/4110252/pexels-photo-4110252.jpeg?auto=compress&cs=tinysrgb&w=800')
ON CONFLICT (id) DO NOTHING;

-- Insert soft bread items
INSERT INTO menu_items (name, description, base_price, category, popular, available, image_url) VALUES
  ('Pan de Coco', 'Sweet Filipino bread filled with coconut strips', 45, 'food', true, true, 'https://images.pexels.com/photos/4110256/pexels-photo-4110256.jpeg?auto=compress&cs=tinysrgb&w=800'),
  ('Cheese Roll', 'Soft bread roll filled with creamy cheese', 50, 'food', true, true, 'https://images.pexels.com/photos/4110256/pexels-photo-4110256.jpeg?auto=compress&cs=tinysrgb&w=800'),
  ('Ham and Cheese', 'Classic combination of ham and cheese in soft bread', 50, 'food', false, true, 'https://images.pexels.com/photos/4110256/pexels-photo-4110256.jpeg?auto=compress&cs=tinysrgb&w=800'),
  ('Cheesy Tuna', 'Tuna salad with melted cheese in soft bread', 50, 'food', false, true, 'https://images.pexels.com/photos/4110256/pexels-photo-4110256.jpeg?auto=compress&cs=tinysrgb&w=800'),
  ('Chicken Floss', 'Soft bread topped with savory chicken floss', 55, 'food', false, true, 'https://images.pexels.com/photos/4110256/pexels-photo-4110256.jpeg?auto=compress&cs=tinysrgb&w=800'),
  ('Sausage Parmesan', 'Italian sausage with parmesan cheese in soft bread', 55, 'food', false, true, 'https://images.pexels.com/photos/4110256/pexels-photo-4110256.jpeg?auto=compress&cs=tinysrgb&w=800'),
  ('Bacon and Cheese', 'Crispy bacon with melted cheese in soft bread', 55, 'food', false, true, 'https://images.pexels.com/photos/4110256/pexels-photo-4110256.jpeg?auto=compress&cs=tinysrgb&w=800'),
  ('Cheese Ensaymada', 'Filipino brioche-style bread topped with cheese and sugar', 60, 'food', true, true, 'https://images.pexels.com/photos/4110256/pexels-photo-4110256.jpeg?auto=compress&cs=tinysrgb&w=800')
ON CONFLICT (id) DO NOTHING;

-- Insert cookies
INSERT INTO menu_items (name, description, base_price, category, popular, available, image_url) VALUES
  ('Chocolate Chip Cookies', 'Classic homemade cookies with premium chocolate chips, baked fresh daily', 300, 'food', true, true, 'https://images.pexels.com/photos/4110252/pexels-photo-4110252.jpeg?auto=compress&cs=tinysrgb&w=800')
ON CONFLICT (id) DO NOTHING;

-- Insert banana bread
INSERT INTO menu_items (name, description, base_price, category, popular, available, image_url) VALUES
  ('Banana Bread', 'Moist, flavorful banana bread made with ripe bananas', 325, 'food', true, true, 'https://images.pexels.com/photos/4110251/pexels-photo-4110251.jpeg?auto=compress&cs=tinysrgb&w=800'),
  ('Banana Bread with Hershey''s', 'Our signature banana bread loaded with Hershey''s chocolate chips', 375, 'food', true, true, 'https://images.pexels.com/photos/4110251/pexels-photo-4110251.jpeg?auto=compress&cs=tinysrgb&w=800')
ON CONFLICT (id) DO NOTHING;

-- Insert cakes
INSERT INTO menu_items (name, description, base_price, category, popular, available, image_url) VALUES
  ('Chocolate Cake', 'Rich, decadent chocolate cake perfect for celebrations', 1400, 'food', true, true, 'https://images.pexels.com/photos/291528/pexels-photo-291528.jpeg?auto=compress&cs=tinysrgb&w=800'),
  ('Carrot Cake', 'Moist carrot cake with cream cheese frosting and walnuts', 1600, 'food', false, true, 'https://images.pexels.com/photos/291528/pexels-photo-291528.jpeg?auto=compress&cs=tinysrgb&w=800'),
  ('Biscoff Cheesecake', 'Creamy cheesecake with Biscoff cookie crust and topping', 2500, 'food', true, true, 'https://images.pexels.com/photos/291528/pexels-photo-291528.jpeg?auto=compress&cs=tinysrgb&w=800')
ON CONFLICT (id) DO NOTHING;

-- Insert other items
INSERT INTO menu_items (name, description, base_price, category, popular, available, image_url) VALUES
  ('Artisan Biscocho', 'Traditional Filipino twice-baked bread, crispy and sweet', 110, 'food', false, true, 'https://images.pexels.com/photos/4110252/pexels-photo-4110252.jpeg?auto=compress&cs=tinysrgb&w=800'),
  ('Butterscotch', 'Rich butterscotch candy made with real butter and brown sugar', 75, 'food', false, true, 'https://images.pexels.com/photos/4110252/pexels-photo-4110252.jpeg?auto=compress&cs=tinysrgb&w=800')
ON CONFLICT (id) DO NOTHING;

-- Add variations for brioche
INSERT INTO variations (menu_item_id, name, price) VALUES
  ((SELECT id FROM menu_items WHERE name = 'Brioche'), 'Plain', 0),
  ((SELECT id FROM menu_items WHERE name = 'Brioche'), 'Almond', 50)
ON CONFLICT DO NOTHING;

-- Add variations for olive bread
INSERT INTO variations (menu_item_id, name, price) VALUES
  ((SELECT id FROM menu_items WHERE name = 'Olive Bread'), 'Plain', 0),
  ((SELECT id FROM menu_items WHERE name = 'Olive Bread'), 'Olives and Cheese', 50)
ON CONFLICT DO NOTHING;

-- Add variations for banana bread
INSERT INTO variations (menu_item_id, name, price) VALUES
  ((SELECT id FROM menu_items WHERE name = 'Banana Bread'), 'Plain', 0),
  ((SELECT id FROM menu_items WHERE name = 'Banana Bread with Hershey''s'), 'With Hershey''s Chocolate', 50)
ON CONFLICT DO NOTHING;
-- ===== END 20250901015559_frosty_wildflower.sql =====

-- ===== BEGIN 20250901155428_raspy_heart.sql =====
/*
  # Add Food Trip - Abra Menu Items

  1. New Menu Items
    - Platter category: Extra Small, Small, Medium, Large platters with dim sum assortments
    - NomBox Sets: Feast, Mid, Mini boxes with variety packs
    - Special Platters: Holiday, Trio, Siomai, Prawn, Hakaw platters
    - Individual Dim Sum Items: Various dumplings, bao, and traditional items

  2. Features
    - Auto-generated UUIDs for all items
    - Detailed descriptions with serving sizes and piece counts
    - Appropriate pricing for each platter size
    - High-quality dim sum images from Pexels
    - Proper categorization for easy browsing

  3. Categories
    - Updates menu with authentic dim sum and platter offerings
    - Maintains existing category structure
*/

-- Insert Platter Items
INSERT INTO menu_items (name, description, base_price, category, popular, available, image_url) VALUES
  ('Extra Small Platter', 'Perfect for small gatherings (3-5 pax) - 50 pieces total: 10 Pork Xiao Long Bao, 10 Molten Chocolate Xiao Long Bao, 10 Pan Fried Pork Dumpling, 10 Prawn Dumpling, 10 Pork & Shrimp Siomai', 998, 'dim-sum', true, true, 'https://images.pexels.com/photos/4518843/pexels-photo-4518843.jpeg?auto=compress&cs=tinysrgb&w=800'),
  
  ('Small Platter', 'Great for family meals (5-8 pax) - 60 pieces total: 10 Pork Xiao Long Bao, 14 Molten Chocolate Xiao Long Bao, 10 Pan Fried Pork Dumpling, 12 Prawn Dumpling, 14 Pork & Shrimp Siomai', 1100, 'dim-sum', true, true, 'https://images.pexels.com/photos/4518843/pexels-photo-4518843.jpeg?auto=compress&cs=tinysrgb&w=800'),
  
  ('Medium Platter', 'Perfect for parties (10-12 pax) - 80 pieces total: 14 Pork Xiao Long Bao, 16 Molten Chocolate Xiao Long Bao, 18 Pan Fried Pork Dumpling, 14 Prawn Dumpling, 18 Pork & Shrimp Siomai', 1500, 'dim-sum', true, true, 'https://images.pexels.com/photos/4518843/pexels-photo-4518843.jpeg?auto=compress&cs=tinysrgb&w=800'),
  
  ('Large Platter', 'Ultimate feast for large groups (15-18 pax) - 100 pieces total: 20 Pork Xiao Long Bao, 20 Molten Chocolate Xiao Long Bao, 20 Pan Fried Pork Dumpling, 20 Prawn Dumpling, 20 Pork & Shrimp Siomai', 1900, 'dim-sum', true, true, 'https://images.pexels.com/photos/4518843/pexels-photo-4518843.jpeg?auto=compress&cs=tinysrgb&w=800');

-- Insert NomBox Sets
INSERT INTO menu_items (name, description, base_price, category, popular, available, image_url) VALUES
  ('NomBox Feast', 'The ultimate dim sum experience - 24 pieces total: 3 Mongopao, 3 Brown Sugar Mantho, 3 Taro Balls, 3 Pork Xiao Long Bao, 3 Pork & Veggie, 3 Pork & Shrimp Siomai, 3 Hakaw, 3 Prawn Dumplings', 528, 'dim-sum', true, true, 'https://images.pexels.com/photos/5409751/pexels-photo-5409751.jpeg?auto=compress&cs=tinysrgb&w=800'),
  
  ('NomBox Mid', 'Perfect variety pack - 17 pieces total: 3 Mongopao, 2 Brown Sugar Mantho, 2 Taro Balls, 2 Pork Xiao Long Bao, 2 Pork & Veggie, 2 Pork Shrimp Siomai, 2 Hakaw, 2 Pork & Mushroom', 368, 'dim-sum', true, true, 'https://images.pexels.com/photos/5409751/pexels-photo-5409751.jpeg?auto=compress&cs=tinysrgb&w=800'),
  
  ('NomBox Mini', 'Great starter pack - 12 pieces total: 2 Mongopao, 2 Brown Sugar Mantho, 2 Pork Xiao Long Bao, 2 Pork & Veggie, 2 Pork Shrimp Siomai, 2 Hakaw', 238, 'dim-sum', false, true, 'https://images.pexels.com/photos/5409751/pexels-photo-5409751.jpeg?auto=compress&cs=tinysrgb&w=800');

-- Insert Special Platters
INSERT INTO menu_items (name, description, base_price, category, popular, available, image_url) VALUES
  ('Holiday Platter', 'Special festive assortment perfect for celebrations - 80 pieces of our finest dim sum selection', 1650, 'dim-sum', true, true, 'https://images.pexels.com/photos/4518843/pexels-photo-4518843.jpeg?auto=compress&cs=tinysrgb&w=800'),
  
  ('Trio Platter', 'Three classic favorites - 60 pieces total: 20 Siomai, 20 Hakaw, 20 Prawn Dumplings', 1200, 'dim-sum', false, true, 'https://images.pexels.com/photos/4518843/pexels-photo-4518843.jpeg?auto=compress&cs=tinysrgb&w=800'),
  
  ('Siomai Platter', 'For siomai lovers - 55 pieces of our signature pork and shrimp siomai', 998, 'dim-sum', false, true, 'https://images.pexels.com/photos/4518843/pexels-photo-4518843.jpeg?auto=compress&cs=tinysrgb&w=800'),
  
  ('Prawn Platter', 'Fresh prawn dumplings - 60 pieces of succulent prawn dumplings', 1200, 'dim-sum', false, true, 'https://images.pexels.com/photos/4518843/pexels-photo-4518843.jpeg?auto=compress&cs=tinysrgb&w=800'),
  
  ('Hakaw XS Platter', 'Delicate shrimp dumplings - 50 pieces of traditional hakaw', 1100, 'dim-sum', false, true, 'https://images.pexels.com/photos/4518843/pexels-photo-4518843.jpeg?auto=compress&cs=tinysrgb&w=800'),
  
  ('Hakaw Small Platter', 'More hakaw goodness - 60 pieces of our signature shrimp dumplings', 1300, 'dim-sum', false, true, 'https://images.pexels.com/photos/4518843/pexels-photo-4518843.jpeg?auto=compress&cs=tinysrgb&w=800');

-- Insert Individual Dim Sum Items
INSERT INTO menu_items (name, description, base_price, category, popular, available, image_url) VALUES
  ('Pork Xiao Long Bao', 'Traditional soup dumplings filled with savory pork and rich broth', 180, 'dim-sum', true, true, 'https://images.pexels.com/photos/4518843/pexels-photo-4518843.jpeg?auto=compress&cs=tinysrgb&w=800'),
  
  ('Molten Chocolate Xiao Long Bao', 'Innovative dessert dumpling with warm molten chocolate center', 220, 'dim-sum', true, true, 'https://images.pexels.com/photos/4518843/pexels-photo-4518843.jpeg?auto=compress&cs=tinysrgb&w=800'),
  
  ('Pan Fried Pork Dumpling', 'Crispy bottom dumplings filled with seasoned pork', 160, 'dim-sum', false, true, 'https://images.pexels.com/photos/4518843/pexels-photo-4518843.jpeg?auto=compress&cs=tinysrgb&w=800'),
  
  ('Prawn Dumpling (Hakaw)', 'Translucent dumplings filled with fresh prawns and bamboo shoots', 180, 'dim-sum', true, true, 'https://images.pexels.com/photos/4518843/pexels-photo-4518843.jpeg?auto=compress&cs=tinysrgb&w=800'),
  
  ('Pork & Shrimp Siomai', 'Open-topped dumplings with pork, shrimp, and mushrooms', 160, 'dim-sum', true, true, 'https://images.pexels.com/photos/4518843/pexels-photo-4518843.jpeg?auto=compress&cs=tinysrgb&w=800'),
  
  ('Mongopao', 'Fluffy steamed buns with sweet mango filling', 140, 'dim-sum', false, true, 'https://images.pexels.com/photos/4518843/pexels-photo-4518843.jpeg?auto=compress&cs=tinysrgb&w=800'),
  
  ('Brown Sugar Mantho', 'Sweet steamed buns with rich brown sugar flavor', 120, 'dim-sum', false, true, 'https://images.pexels.com/photos/4518843/pexels-photo-4518843.jpeg?auto=compress&cs=tinysrgb&w=800'),
  
  ('Taro Balls', 'Chewy taro-flavored balls, a popular Taiwanese treat', 100, 'dim-sum', false, true, 'https://images.pexels.com/photos/4518843/pexels-photo-4518843.jpeg?auto=compress&cs=tinysrgb&w=800'),
  
  ('Pork & Veggie Dumpling', 'Healthy dumplings filled with pork and fresh vegetables', 150, 'dim-sum', false, true, 'https://images.pexels.com/photos/4518843/pexels-photo-4518843.jpeg?auto=compress&cs=tinysrgb&w=800'),
  
  ('Pork & Mushroom Dumpling', 'Savory dumplings with pork and shiitake mushrooms', 160, 'dim-sum', false, true, 'https://images.pexels.com/photos/4518843/pexels-photo-4518843.jpeg?auto=compress&cs=tinysrgb&w=800');

-- Update existing items to better match food trip - abra branding
UPDATE menu_items 
SET 
  name = 'Har Gow (Shrimp Dumplings)',
  description = 'Delicate translucent dumplings filled with fresh shrimp and bamboo shoots - a dim sum classic'
WHERE name = 'Har Gow (Shrimp Dumplings)';

UPDATE menu_items 
SET 
  name = 'Siu Mai (Pork & Shrimp Dumplings)',
  description = 'Traditional open-topped dumplings with seasoned pork, shrimp, and mushrooms'
WHERE name = 'Siu Mai (Pork & Shrimp Dumplings)';

UPDATE menu_items 
SET 
  name = 'Char Siu Bao (BBQ Pork Buns)',
  description = 'Fluffy steamed buns filled with sweet and savory Chinese BBQ pork'
WHERE name = 'Char Siu Bao (BBQ Pork Buns)';
-- ===== END 20250901155428_raspy_heart.sql =====

-- ===== BEGIN 20250902090000_inventory_management.sql =====
/*
  Add inventory fields and automatic availability management for menu items.
*/

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'menu_items' AND column_name = 'track_inventory'
  ) THEN
    ALTER TABLE menu_items
      ADD COLUMN track_inventory boolean NOT NULL DEFAULT false;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'menu_items' AND column_name = 'stock_quantity'
  ) THEN
    ALTER TABLE menu_items
      ADD COLUMN stock_quantity integer;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'menu_items' AND column_name = 'low_stock_threshold'
  ) THEN
    ALTER TABLE menu_items
      ADD COLUMN low_stock_threshold integer NOT NULL DEFAULT 0;
  END IF;
END $$;

-- Ensure non-negative stock values
ALTER TABLE menu_items
  ADD CONSTRAINT menu_items_stock_quantity_non_negative
  CHECK (stock_quantity IS NULL OR stock_quantity >= 0);

ALTER TABLE menu_items
  ADD CONSTRAINT menu_items_low_stock_threshold_non_negative
  CHECK (low_stock_threshold >= 0);

-- Keep availability in sync when tracking inventory
CREATE OR REPLACE FUNCTION sync_menu_item_availability()
RETURNS trigger AS $$
BEGIN
  IF COALESCE(NEW.track_inventory, false) THEN
    NEW.stock_quantity := GREATEST(COALESCE(NEW.stock_quantity, 0), 0);
    NEW.low_stock_threshold := GREATEST(COALESCE(NEW.low_stock_threshold, 0), 0);

    IF NEW.stock_quantity <= NEW.low_stock_threshold THEN
      NEW.available := false;
    ELSE
      NEW.available := true;
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_sync_menu_item_availability ON menu_items;
CREATE TRIGGER trg_sync_menu_item_availability
BEFORE INSERT OR UPDATE ON menu_items
FOR EACH ROW
EXECUTE FUNCTION sync_menu_item_availability();

-- Helper to decrement stock quantities in batch
CREATE OR REPLACE FUNCTION decrement_menu_item_stock(items jsonb)
RETURNS void AS $$
DECLARE
  entry jsonb;
  qty integer;
BEGIN
  IF items IS NULL THEN
    RETURN;
  END IF;

  FOR entry IN SELECT * FROM jsonb_array_elements(items)
  LOOP
    qty := GREATEST(COALESCE((entry->>'quantity')::integer, 0), 0);

    IF qty <= 0 THEN
      CONTINUE;
    END IF;

    UPDATE menu_items
    SET stock_quantity = GREATEST(COALESCE(stock_quantity, 0) - qty, 0)
    WHERE track_inventory = true
      AND id::text = entry->>'id';
  END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION decrement_menu_item_stock(jsonb) TO anon, authenticated;

-- ===== END 20250902090000_inventory_management.sql =====

-- ===== BEGIN 20250103000000_fix_availability_trigger.sql =====
/*
  Fix availability trigger to respect manual availability changes
  
  The previous trigger would always override the 'available' field when
  track_inventory was enabled, even if the admin manually set it.
  
  This updated trigger only auto-calculates availability when:
  1. track_inventory is true AND
  2. The stock_quantity or low_stock_threshold is being changed
  
  It preserves manual availability changes in other cases.
*/

-- Drop the old trigger
DROP TRIGGER IF EXISTS trg_sync_menu_item_availability ON menu_items;

-- Create improved availability sync function
CREATE OR REPLACE FUNCTION sync_menu_item_availability()
RETURNS trigger AS $$
BEGIN
  -- Only auto-calculate availability if tracking inventory
  IF COALESCE(NEW.track_inventory, false) THEN
    -- Ensure stock values are non-negative
    NEW.stock_quantity := GREATEST(COALESCE(NEW.stock_quantity, 0), 0);
    NEW.low_stock_threshold := GREATEST(COALESCE(NEW.low_stock_threshold, 0), 0);

    -- Check if stock-related fields changed
    -- If they did, auto-calculate availability
    IF OLD.stock_quantity IS DISTINCT FROM NEW.stock_quantity OR 
       OLD.low_stock_threshold IS DISTINCT FROM NEW.low_stock_threshold OR
       OLD.track_inventory IS DISTINCT FROM NEW.track_inventory THEN
      
      -- Auto-calculate based on stock
      IF NEW.stock_quantity <= NEW.low_stock_threshold THEN
        NEW.available := false;
      ELSE
        NEW.available := true;
      END IF;
    END IF;
    -- If stock fields didn't change, preserve the existing availability value
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Recreate the trigger
CREATE TRIGGER trg_sync_menu_item_availability
BEFORE INSERT OR UPDATE ON menu_items
FOR EACH ROW
EXECUTE FUNCTION sync_menu_item_availability();


-- ===== END 20250103000000_fix_availability_trigger.sql =====

-- ===== BEGIN 20250109000000_add_merchants.sql =====
-- Migration: Add Multi-Merchant Support
-- This migration transforms the single-restaurant app into a multi-merchant marketplace

-- Create merchants table
CREATE TABLE IF NOT EXISTS merchants (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  description text,
  logo_url text,
  cover_image_url text,
  category text NOT NULL, -- e.g., 'restaurant', 'cafe', 'bakery', 'fast-food'
  cuisine_type text, -- e.g., 'Filipino', 'Chinese', 'Italian', 'American'
  delivery_fee decimal(10,2) DEFAULT 0,
  minimum_order decimal(10,2) DEFAULT 0,
  estimated_delivery_time text, -- e.g., '30-45 mins'
  rating decimal(3,2) DEFAULT 0, -- 0-5 stars
  total_reviews integer DEFAULT 0,
  active boolean DEFAULT true,
  featured boolean DEFAULT false, -- Show on homepage
  address text,
  contact_number text,
  email text,
  opening_hours jsonb, -- Store opening hours as JSON
  payment_methods text[], -- Array of accepted payment methods
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Add merchant_id to menu_items
ALTER TABLE menu_items 
ADD COLUMN merchant_id uuid REFERENCES merchants(id) ON DELETE CASCADE;

-- Add merchant_id to categories
ALTER TABLE categories 
ADD COLUMN merchant_id uuid REFERENCES merchants(id) ON DELETE CASCADE;

-- Add merchant_id to orders
ALTER TABLE orders 
ADD COLUMN merchant_id uuid REFERENCES merchants(id) ON DELETE CASCADE;

-- Add merchant_id to payment_methods
ALTER TABLE payment_methods 
ADD COLUMN merchant_id uuid REFERENCES merchants(id) ON DELETE CASCADE;

-- Create indexes for better query performance
CREATE INDEX idx_menu_items_merchant_id ON menu_items(merchant_id);
CREATE INDEX idx_categories_merchant_id ON categories(merchant_id);
CREATE INDEX idx_orders_merchant_id ON orders(merchant_id);
CREATE INDEX idx_payment_methods_merchant_id ON payment_methods(merchant_id);
CREATE INDEX idx_merchants_active ON merchants(active);
CREATE INDEX idx_merchants_featured ON merchants(featured);
CREATE INDEX idx_merchants_category ON merchants(category);

-- Enable RLS
ALTER TABLE merchants ENABLE ROW LEVEL SECURITY;

-- Create policies for merchants
CREATE POLICY "Anyone can read active merchants"
  ON merchants
  FOR SELECT
  TO public
  USING (active = true);

CREATE POLICY "Authenticated users can manage merchants"
  ON merchants
  FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);

-- Create updated_at trigger for merchants
CREATE TRIGGER update_merchants_updated_at
  BEFORE UPDATE ON merchants
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- Insert a default merchant for existing data
-- This ensures existing menu items don't break
INSERT INTO merchants (name, description, category, cuisine_type, active, featured)
VALUES (
  'food trip - abra',
  'Our flagship restaurant offering a wide variety of delicious meals',
  'restaurant',
  'Filipino',
  true,
  true
);

-- Update existing menu items to belong to the default merchant
UPDATE menu_items 
SET merchant_id = (SELECT id FROM merchants WHERE name = 'food trip - abra' LIMIT 1)
WHERE merchant_id IS NULL;

-- Update existing categories to belong to the default merchant
UPDATE categories 
SET merchant_id = (SELECT id FROM merchants WHERE name = 'food trip - abra' LIMIT 1)
WHERE merchant_id IS NULL;

-- Update existing payment methods to belong to the default merchant
UPDATE payment_methods 
SET merchant_id = (SELECT id FROM merchants WHERE name = 'food trip - abra' LIMIT 1)
WHERE merchant_id IS NULL;

-- Make merchant_id NOT NULL after setting defaults
ALTER TABLE menu_items 
ALTER COLUMN merchant_id SET NOT NULL;

ALTER TABLE categories 
ALTER COLUMN merchant_id SET NOT NULL;

ALTER TABLE payment_methods 
ALTER COLUMN merchant_id SET NOT NULL;

-- Add comments for documentation
COMMENT ON TABLE merchants IS 'Stores information about different merchants/stores in the marketplace';
COMMENT ON COLUMN merchants.opening_hours IS 'JSON object with opening hours, e.g., {"monday": "09:00-22:00", "tuesday": "09:00-22:00"}';
COMMENT ON COLUMN merchants.payment_methods IS 'Array of accepted payment methods, e.g., ["gcash", "maya", "cash"]';


-- ===== END 20250109000000_add_merchants.sql =====

-- ===== BEGIN 20250901170500_orders_realtime.sql =====
-- Ensure realtime is enabled for orders and order_items tables
-- Depending on your project, Supabase may use the `supabase_realtime` publication

-- Create publication if it doesn't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime'
  ) THEN
    CREATE PUBLICATION supabase_realtime;
  END IF;
END $$;

-- Add tables to the publication
ALTER PUBLICATION supabase_realtime ADD TABLE orders;
ALTER PUBLICATION supabase_realtime ADD TABLE order_items;



-- ===== END 20250901170500_orders_realtime.sql =====

-- ===== BEGIN 20250901171000_orders_ip_rate_limit.sql =====
-- Add ip_address to orders and a trigger to prevent spam orders per IP (1 minute)

-- Add column if not exists
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'orders' AND column_name = 'ip_address'
  ) THEN
    ALTER TABLE orders ADD COLUMN ip_address text;
  END IF;
END $$;

-- Index for faster lookups
CREATE INDEX IF NOT EXISTS idx_orders_ip_created_at ON orders(ip_address, created_at DESC);

-- Create or replace function to enforce 1-minute cooldown per IP
CREATE OR REPLACE FUNCTION prevent_spam_orders_per_ip()
RETURNS trigger AS $$
DECLARE
  recent_count int;
BEGIN
  IF NEW.ip_address IS NULL OR length(trim(NEW.ip_address)) = 0 THEN
    -- If IP is missing, allow but you may choose to block instead
    RETURN NEW;
  END IF;

  SELECT COUNT(*) INTO recent_count
  FROM orders
  WHERE ip_address = NEW.ip_address
    AND created_at >= (now() - interval '60 seconds');

  IF recent_count > 0 THEN
    RAISE EXCEPTION 'Rate limit: Please wait 60 seconds before placing another order.' USING ERRCODE = 'check_violation';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Attach trigger
DROP TRIGGER IF EXISTS trg_prevent_spam_orders_per_ip ON orders;
CREATE TRIGGER trg_prevent_spam_orders_per_ip
BEFORE INSERT ON orders
FOR EACH ROW
EXECUTE FUNCTION prevent_spam_orders_per_ip();



-- ===== END 20250901171000_orders_ip_rate_limit.sql =====

-- ===== BEGIN 20250901171500_orders_ip_from_headers.sql =====
-- Populate orders.ip_address from PostgREST forwarded headers when not provided

-- Function to extract IP from request headers
CREATE OR REPLACE FUNCTION set_order_ip_from_headers()
RETURNS trigger AS $$
DECLARE
  headers jsonb;
  fwd text;
  realip text;
  chosen text;
BEGIN
  IF NEW.ip_address IS NOT NULL AND length(trim(NEW.ip_address)) > 0 THEN
    RETURN NEW;
  END IF;

  -- PostgREST exposes request headers via current_setting('request.headers', true)
  BEGIN
    headers := current_setting('request.headers', true)::jsonb;
  EXCEPTION WHEN others THEN
    headers := '{}'::jsonb;
  END;

  fwd := COALESCE(headers->>'x-forwarded-for', headers->>'x-real-ip');
  IF fwd IS NOT NULL AND length(trim(fwd)) > 0 THEN
    -- x-forwarded-for may be a comma-separated list; take the first
    chosen := split_part(fwd, ',', 1);
  END IF;

  IF chosen IS NULL OR length(trim(chosen)) = 0 THEN
    realip := headers->>'x-real-ip';
    chosen := realip;
  END IF;

  IF chosen IS NOT NULL AND length(trim(chosen)) > 0 THEN
    NEW.ip_address := trim(chosen);
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Ensure we set IP before enforcing rate limit (trigger order matters)
DROP TRIGGER IF EXISTS trg_prevent_spam_orders_per_ip ON orders;
DROP TRIGGER IF EXISTS trg_set_order_ip_from_headers ON orders;

CREATE TRIGGER trg_set_order_ip_from_headers
BEFORE INSERT ON orders
FOR EACH ROW
EXECUTE FUNCTION set_order_ip_from_headers();

CREATE TRIGGER trg_prevent_spam_orders_per_ip
BEFORE INSERT ON orders
FOR EACH ROW
EXECUTE FUNCTION prevent_spam_orders_per_ip();



-- ===== END 20250901171500_orders_ip_from_headers.sql =====

-- ===== BEGIN 20250901172000_orders_rate_limit_hardened.sql =====
-- Harden rate limit: also check contact_number, and do not allow missing identifiers

CREATE OR REPLACE FUNCTION prevent_spam_orders_per_ip()
RETURNS trigger AS $$
DECLARE
  recent_ip_count int := 0;
  recent_phone_count int := 0;
BEGIN
  -- Require at least one identifier: IP or contact number
  IF (NEW.ip_address IS NULL OR length(trim(NEW.ip_address)) = 0)
     AND (NEW.contact_number IS NULL OR length(trim(NEW.contact_number)) = 0) THEN
    RAISE EXCEPTION 'Rate limit: Missing identifiers. Please try again shortly.' USING ERRCODE = 'check_violation';
  END IF;

  -- Check by IP when available
  IF NEW.ip_address IS NOT NULL AND length(trim(NEW.ip_address)) > 0 THEN
    SELECT COUNT(*) INTO recent_ip_count
    FROM orders
    WHERE ip_address = NEW.ip_address
      AND created_at >= (now() - interval '60 seconds');
  END IF;

  -- Check by contact number when available
  IF NEW.contact_number IS NOT NULL AND length(trim(NEW.contact_number)) > 0 THEN
    SELECT COUNT(*) INTO recent_phone_count
    FROM orders
    WHERE contact_number = NEW.contact_number
      AND created_at >= (now() - interval '60 seconds');
  END IF;

  IF recent_ip_count > 0 OR recent_phone_count > 0 THEN
    RAISE EXCEPTION 'Rate limit: Please wait 60 seconds before placing another order.' USING ERRCODE = 'check_violation';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Recreate triggers to ensure correct order (set IP first, then rate-limit)
DROP TRIGGER IF EXISTS trg_prevent_spam_orders_per_ip ON orders;
CREATE TRIGGER trg_prevent_spam_orders_per_ip
BEFORE INSERT ON orders
FOR EACH ROW
EXECUTE FUNCTION prevent_spam_orders_per_ip();



-- ===== END 20250901172000_orders_rate_limit_hardened.sql =====

-- ===== BEGIN 20251016235616_make_payment_method_merchant_nullable.sql =====
-- Make merchant_id nullable in payment_methods table
-- This allows payment methods to be shared across all merchants

ALTER TABLE payment_methods 
ALTER COLUMN merchant_id DROP NOT NULL;

-- Add comment explaining the nullable merchant_id
COMMENT ON COLUMN payment_methods.merchant_id IS 'Merchant this payment method belongs to. NULL means available for all merchants.';

-- Update existing policies to handle NULL merchant_id
DROP POLICY IF EXISTS "Anyone can read active payment methods" ON payment_methods;

CREATE POLICY "Anyone can read active payment methods"
  ON payment_methods
  FOR SELECT
  TO public
  USING (active = true);

-- ===== END 20251016235616_make_payment_method_merchant_nullable.sql =====

-- ===== BEGIN 20251019000000_add_variation_groups.sql =====
/*
  # Add Variation Groups Support
  
  This migration adds support for grouped variations, allowing items to have
  multiple types of variations (e.g., Size, Temperature, Style).
  
  Changes:
  1. Add variation_group column to variations table
  2. Add sort_order column for ordering variations within groups
  3. Add required flag to indicate if customer must select from this group
  
  Examples:
  - Coffee:
    - Size (required): Small (+₱0), Medium (+₱20), Large (+₱40)
    - Temperature (required): Hot (+₱0), Iced (+₱10)
    - Milk Type (optional): Regular (+₱0), Oat (+₱20), Almond (+₱25)
  
  - Fries:
    - Size (required): Regular (+₱0), Large (+₱30)
    - Style (optional): Straight (+₱0), Curly (+₱15), Waffle (+₱20)
*/

-- Add variation_group column to variations table
DO $$
BEGIN
  -- Add variation_group column (defaults to 'default' for existing variations)
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'variations' AND column_name = 'variation_group'
  ) THEN
    ALTER TABLE variations ADD COLUMN variation_group text NOT NULL DEFAULT 'default';
  END IF;

  -- Add sort_order column for ordering variations within a group
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'variations' AND column_name = 'sort_order'
  ) THEN
    ALTER TABLE variations ADD COLUMN sort_order integer NOT NULL DEFAULT 0;
  END IF;
END $$;

-- Create a new table for variation group metadata
CREATE TABLE IF NOT EXISTS variation_groups (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  menu_item_id uuid REFERENCES menu_items(id) ON DELETE CASCADE,
  name text NOT NULL, -- e.g., "Size", "Temperature", "Style"
  required boolean DEFAULT true, -- If true, customer must select one option
  sort_order integer NOT NULL DEFAULT 0, -- Order of groups in UI
  created_at timestamptz DEFAULT now()
);

-- Create index for better query performance
CREATE INDEX IF NOT EXISTS idx_variation_groups_menu_item_id ON variation_groups(menu_item_id);
CREATE INDEX IF NOT EXISTS idx_variations_variation_group ON variations(variation_group);

-- Enable RLS on variation_groups table
ALTER TABLE variation_groups ENABLE ROW LEVEL SECURITY;

-- Create policies for variation_groups
CREATE POLICY "Anyone can read variation groups"
  ON variation_groups
  FOR SELECT
  TO public
  USING (true);

CREATE POLICY "Authenticated users can manage variation groups"
  ON variation_groups
  FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);

-- Update existing variations to have sort_order based on creation time
UPDATE variations 
SET sort_order = EXTRACT(EPOCH FROM created_at)::integer 
WHERE sort_order = 0;

-- Comment on new columns for documentation
COMMENT ON COLUMN variations.variation_group IS 'The group/type this variation belongs to (e.g., "Size", "Temperature", "Style")';
COMMENT ON COLUMN variations.sort_order IS 'Order of this variation within its group (lower numbers appear first)';
COMMENT ON TABLE variation_groups IS 'Metadata for variation groups, including whether selection is required';


-- ===== END 20251019000000_add_variation_groups.sql =====

-- ===== BEGIN 20260207103000_add_geospatial_delivery_pricing.sql =====
-- Add geospatial delivery pricing support for merchants and orders

-- Merchant location and dynamic delivery pricing config
ALTER TABLE merchants
  ADD COLUMN IF NOT EXISTS latitude double precision,
  ADD COLUMN IF NOT EXISTS longitude double precision,
  ADD COLUMN IF NOT EXISTS formatted_address text,
  ADD COLUMN IF NOT EXISTS osm_place_id text,
  ADD COLUMN IF NOT EXISTS base_delivery_fee numeric(10,2),
  ADD COLUMN IF NOT EXISTS delivery_fee_per_km numeric(10,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS min_delivery_fee numeric(10,2),
  ADD COLUMN IF NOT EXISTS max_delivery_fee numeric(10,2),
  ADD COLUMN IF NOT EXISTS max_delivery_distance_km numeric(10,2);

-- Keep old data working by mirroring delivery_fee into base_delivery_fee
UPDATE merchants
SET base_delivery_fee = delivery_fee
WHERE base_delivery_fee IS NULL;

-- Sensible defaults for new config fields
ALTER TABLE merchants
  ALTER COLUMN base_delivery_fee SET DEFAULT 0,
  ALTER COLUMN delivery_fee_per_km SET DEFAULT 0,
  ALTER COLUMN max_delivery_distance_km SET DEFAULT 20;

ALTER TABLE merchants
  ADD CONSTRAINT merchants_delivery_fee_per_km_non_negative CHECK (delivery_fee_per_km >= 0),
  ADD CONSTRAINT merchants_base_delivery_fee_non_negative CHECK (base_delivery_fee >= 0),
  ADD CONSTRAINT merchants_min_delivery_fee_non_negative CHECK (min_delivery_fee IS NULL OR min_delivery_fee >= 0),
  ADD CONSTRAINT merchants_max_delivery_fee_non_negative CHECK (max_delivery_fee IS NULL OR max_delivery_fee >= 0),
  ADD CONSTRAINT merchants_max_delivery_distance_non_negative CHECK (max_delivery_distance_km IS NULL OR max_delivery_distance_km >= 0),
  ADD CONSTRAINT merchants_delivery_fee_bounds CHECK (
    min_delivery_fee IS NULL OR max_delivery_fee IS NULL OR min_delivery_fee <= max_delivery_fee
  );

CREATE INDEX IF NOT EXISTS idx_merchants_lat_lng ON merchants(latitude, longitude);

-- Persist delivery quote snapshot on orders
ALTER TABLE orders
  ADD COLUMN IF NOT EXISTS delivery_latitude double precision,
  ADD COLUMN IF NOT EXISTS delivery_longitude double precision,
  ADD COLUMN IF NOT EXISTS distance_km numeric(10,3),
  ADD COLUMN IF NOT EXISTS delivery_fee numeric(10,2),
  ADD COLUMN IF NOT EXISTS delivery_fee_breakdown jsonb;

-- Great-circle distance helper
CREATE OR REPLACE FUNCTION public.haversine_km(
  lat1 double precision,
  lon1 double precision,
  lat2 double precision,
  lon2 double precision
)
RETURNS numeric
LANGUAGE sql
IMMUTABLE
STRICT
AS $$
  SELECT round(
    (
      6371 * 2 * asin(
        sqrt(
          power(sin(radians((lat2 - lat1) / 2)), 2) +
          cos(radians(lat1)) * cos(radians(lat2)) * power(sin(radians((lon2 - lon1) / 2)), 2)
        )
      )
    )::numeric,
    3
  );
$$;

-- Server-side quote calculator (single merchant)
CREATE OR REPLACE FUNCTION public.calculate_delivery_quote(
  p_merchant_id uuid,
  p_delivery_latitude double precision,
  p_delivery_longitude double precision
)
RETURNS TABLE (
  merchant_id uuid,
  distance_km numeric,
  delivery_fee numeric,
  is_deliverable boolean,
  breakdown jsonb
)
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
  m merchants%ROWTYPE;
  v_distance_km numeric;
  v_base_fee numeric;
  v_per_km_fee numeric;
  v_raw_fee numeric;
  v_final_fee numeric;
  v_is_deliverable boolean;
BEGIN
  SELECT *
  INTO m
  FROM merchants
  WHERE id = p_merchant_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Merchant not found: %', p_merchant_id;
  END IF;

  IF m.latitude IS NULL OR m.longitude IS NULL THEN
    merchant_id := m.id;
    distance_km := NULL;
    delivery_fee := NULL;
    is_deliverable := false;
    breakdown := jsonb_build_object(
      'reason', 'merchant_location_missing',
      'base_delivery_fee', m.base_delivery_fee,
      'delivery_fee_per_km', m.delivery_fee_per_km,
      'max_delivery_distance_km', m.max_delivery_distance_km
    );
    RETURN NEXT;
    RETURN;
  END IF;

  v_distance_km := public.haversine_km(m.latitude, m.longitude, p_delivery_latitude, p_delivery_longitude);
  v_base_fee := COALESCE(m.base_delivery_fee, m.delivery_fee, 0);
  v_per_km_fee := COALESCE(m.delivery_fee_per_km, 0);
  v_raw_fee := v_base_fee + (v_distance_km * v_per_km_fee);

  v_final_fee := v_raw_fee;

  IF m.min_delivery_fee IS NOT NULL THEN
    v_final_fee := GREATEST(v_final_fee, m.min_delivery_fee);
  END IF;

  IF m.max_delivery_fee IS NOT NULL THEN
    v_final_fee := LEAST(v_final_fee, m.max_delivery_fee);
  END IF;

  v_final_fee := round(v_final_fee, 2);
  v_is_deliverable := (m.max_delivery_distance_km IS NULL OR v_distance_km <= m.max_delivery_distance_km);

  merchant_id := m.id;
  distance_km := v_distance_km;
  delivery_fee := CASE WHEN v_is_deliverable THEN v_final_fee ELSE NULL END;
  is_deliverable := v_is_deliverable;
  breakdown := jsonb_build_object(
    'base_delivery_fee', v_base_fee,
    'delivery_fee_per_km', v_per_km_fee,
    'raw_fee', round(v_raw_fee, 2),
    'min_delivery_fee', m.min_delivery_fee,
    'max_delivery_fee', m.max_delivery_fee,
    'max_delivery_distance_km', m.max_delivery_distance_km,
    'distance_km', v_distance_km,
    'rounded_fee', v_final_fee
  );

  RETURN NEXT;
END;
$$;

GRANT EXECUTE ON FUNCTION public.haversine_km(double precision, double precision, double precision, double precision) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.calculate_delivery_quote(uuid, double precision, double precision) TO anon, authenticated;

-- ===== END 20260207103000_add_geospatial_delivery_pricing.sql =====

-- ===== BEGIN 20260207162000_set_default_delivery_fee_per_km.sql =====
-- Set per-km delivery fee baseline to 4 and backfill unset merchants

ALTER TABLE merchants
  ALTER COLUMN delivery_fee_per_km SET DEFAULT 4;

UPDATE merchants
SET delivery_fee_per_km = 4
WHERE delivery_fee_per_km IS NULL OR delivery_fee_per_km = 0;

-- ===== END 20260207162000_set_default_delivery_fee_per_km.sql =====

-- ===== BEGIN 20260207170000_add_promotions.sql =====
/*
  # Add Promotions Carousel Management

  1. New Tables
    - `promotions`
      - `id` (uuid, primary key)
      - `title` (text)
      - `subtitle` (text)
      - `cta_text` (text)
      - `cta_link` (text)
      - `banner_image_url` (text)
      - `active` (boolean)
      - `sort_order` (integer)
      - `created_at` (timestamp)
      - `updated_at` (timestamp)

  2. Security
    - Enable RLS on promotions table
    - Public read for active promotions
    - Authenticated users can manage promotions
*/

CREATE TABLE IF NOT EXISTS promotions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  subtitle text,
  cta_text text,
  cta_link text,
  banner_image_url text,
  active boolean NOT NULL DEFAULT true,
  sort_order integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_promotions_active_sort
  ON promotions(active, sort_order, created_at);

ALTER TABLE promotions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone can read active promotions" ON promotions;
CREATE POLICY "Anyone can read active promotions"
  ON promotions
  FOR SELECT
  TO public
  USING (active = true);

DROP POLICY IF EXISTS "Authenticated users can manage promotions" ON promotions;
CREATE POLICY "Authenticated users can manage promotions"
  ON promotions
  FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);

DROP TRIGGER IF EXISTS update_promotions_updated_at ON promotions;
CREATE TRIGGER update_promotions_updated_at
  BEFORE UPDATE ON promotions
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

INSERT INTO promotions (title, subtitle, cta_text, cta_link, banner_image_url, active, sort_order)
VALUES
  ('Spicy Zone', 'Up to 40% OFF', 'Order Now', '/', 'https://images.pexels.com/photos/1640777/pexels-photo-1640777.jpeg?auto=compress&cs=tinysrgb&w=1400', true, 1),
  ('Weekend Bundle', 'Free delivery on orders above ₱499', 'Shop Deals', '/', 'https://images.pexels.com/photos/4551832/pexels-photo-4551832.jpeg?auto=compress&cs=tinysrgb&w=1400', true, 2)
ON CONFLICT DO NOTHING;

-- ===== END 20260207170000_add_promotions.sql =====

-- ===== BEGIN 20250830082821_peaceful_cliff.sql =====
/*
  # Create storage bucket for menu item images

  1. Storage Setup
    - Create 'menu-images' bucket for storing menu item images
    - Set bucket to be publicly accessible for reading
    - Allow authenticated users to upload images

  2. Security
    - Public read access for menu images
    - Authenticated upload access only
    - File size and type restrictions via policies
*/

-- Create storage bucket for menu images
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'menu-images',
  'menu-images',
  true,
  5242880, -- 5MB limit
  ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif']
) ON CONFLICT (id) DO NOTHING;

-- Allow public read access to menu images
CREATE POLICY "Public read access for menu images"
ON storage.objects
FOR SELECT
TO public
USING (bucket_id = 'menu-images');

-- Allow authenticated users to upload menu images
CREATE POLICY "Authenticated users can upload menu images"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'menu-images');

-- Allow authenticated users to update menu images
CREATE POLICY "Authenticated users can update menu images"
ON storage.objects
FOR UPDATE
TO authenticated
USING (bucket_id = 'menu-images');

-- Allow authenticated users to delete menu images
CREATE POLICY "Authenticated users can delete menu images"
ON storage.objects
FOR DELETE
TO authenticated
USING (bucket_id = 'menu-images');
-- ===== END 20250830082821_peaceful_cliff.sql =====
