CREATE TABLE IF NOT EXISTS purchase_orders (
  id SERIAL PRIMARY KEY,
  account_id UUID NOT NULL,
  supplier_id UUID NULL,
  supplier_name TEXT NOT NULL,
  supplier_address TEXT,
  supplier_phone TEXT,
  supplier_tax_id TEXT,
  doc_no TEXT NOT NULL,
  doc_date DATE NOT NULL,
  subtotal NUMERIC DEFAULT 0,
  vat_enabled BOOLEAN DEFAULT true,
  vat_rate NUMERIC DEFAULT 0,
  total NUMERIC DEFAULT 0,
  status TEXT DEFAULT 'draft',
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP
);

CREATE TABLE IF NOT EXISTS purchase_order_items (
  id SERIAL PRIMARY KEY,
  purchase_order_id INTEGER REFERENCES purchase_orders(id),
  line_no INTEGER,
  description TEXT,
  qty NUMERIC,
  unit_price NUMERIC,
  line_total NUMERIC
);
