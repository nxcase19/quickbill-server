CREATE TABLE IF NOT EXISTS document_items (
  id SERIAL PRIMARY KEY,
  document_id INTEGER REFERENCES documents(id),
  line_no INTEGER,
  description TEXT,
  qty NUMERIC,
  unit_price NUMERIC,
  line_total NUMERIC
);
