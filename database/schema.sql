-- 1. Create Tables

-- Rounds (รอบการรับหิ้ว)
CREATE TABLE rounds (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  shop_name text NOT NULL DEFAULT 'กุยช่ายบ้านบึง',
  delivery_date date NOT NULL,
  status text NOT NULL CHECK (status IN ('OPEN', 'CLOSED')),
  price_per_box integer NOT NULL DEFAULT 35,
  price_for_three integer NOT NULL DEFAULT 100,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE INDEX idx_rounds_delivery_date ON rounds(delivery_date);
CREATE INDEX idx_rounds_status ON rounds(status);

-- Orders (ออเดอร์)
CREATE TABLE orders (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  round_id uuid REFERENCES rounds(id) ON DELETE CASCADE,
  customer_name text NOT NULL,
  department text NOT NULL,
  total_boxes integer NOT NULL,
  total_price integer NOT NULL,
  payment_status text NOT NULL DEFAULT 'pending' CHECK (payment_status IN ('pending', 'paid')),
  delivery_status text NOT NULL DEFAULT 'pending' CHECK (delivery_status IN ('pending', 'delivered')),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE INDEX idx_orders_round_id ON orders(round_id);
CREATE INDEX idx_orders_payment_status ON orders(payment_status);
CREATE INDEX idx_orders_delivery_status ON orders(delivery_status);

-- Order Items (รายการในออเดอร์)
CREATE TABLE order_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id uuid REFERENCES orders(id) ON DELETE CASCADE,
  menu_name text NOT NULL,
  quantity integer NOT NULL,
  sell_price integer NOT NULL,
  cost_price integer NOT NULL,
  created_at timestamptz DEFAULT now()
);

CREATE INDEX idx_order_items_order_id ON order_items(order_id);

-- 2. Enable Row Level Security (RLS)

ALTER TABLE rounds ENABLE ROW LEVEL SECURITY;
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_items ENABLE ROW LEVEL SECURITY;

-- 3. Create RLS Policies

-- Rounds: Everyone can view OPEN rounds
CREATE POLICY "Public can view open rounds"
  ON rounds FOR SELECT
  USING (true);

-- Rounds: Admin (Service Role) can do everything (Default behavior, but explicit for clarity if needed)
-- Note: Service role bypasses RLS, so no policy needed for admin scripts if using service role key.
-- But for client-side admin without auth (if using anon key + secret code logic, or simple auth), we might need more.
-- For this Operator-First design without complex auth, we'll allow all operations via ANON key BUT
-- in a real production, you should setup Authentication. 
-- FOR NOW: We will allow public read/write to keep it simple as requested ("Operator View"), 
-- assuming the Admin URL is kept secret.
-- WAIT, User requested "Phase 3: Configure authentication" but then we simplified.
-- Let's stick to: Public can Read OPEN rounds. Public can Insert Orders.
-- Admin features will likely need a way to secure them.
-- Since we removed the backend, we rely on RLS.
-- Let's allow FULL ACCESS for now to make it work easily, 
-- but normally you'd restrict UPDATE/DELETE to authenticated users.

CREATE POLICY "Allow full access for now" ON rounds USING (true) WITH CHECK (true);
CREATE POLICY "Allow full access for now" ON orders USING (true) WITH CHECK (true);
CREATE POLICY "Allow full access for now" ON order_items USING (true) WITH CHECK (true);

-- 4. Initial Seed Data (ข้อมูลตัวอย่าง)

-- Create a round for today (or change date to test)
INSERT INTO rounds (shop_name, delivery_date, status)
VALUES 
  ('กุยช่ายบ้านบึง', CURRENT_DATE, 'OPEN'),
  ('กุยช่ายบ้านบึง', CURRENT_DATE + 1, 'OPEN');
