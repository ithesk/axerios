-- =====================================================
-- CONFIGURACION FLEXIBLE PARA CUALQUIER LOCALIDAD
-- =====================================================

-- 1. Agregar campos de configuracion al workshop
ALTER TABLE workshops ADD COLUMN IF NOT EXISTS tax_name TEXT DEFAULT 'IVA';
ALTER TABLE workshops ADD COLUMN IF NOT EXISTS tax_rate DECIMAL(5,2) DEFAULT 0;
ALTER TABLE workshops ADD COLUMN IF NOT EXISTS currency_symbol TEXT DEFAULT '$';
ALTER TABLE workshops ADD COLUMN IF NOT EXISTS currency_code TEXT DEFAULT 'USD';
ALTER TABLE workshops ADD COLUMN IF NOT EXISTS country_code TEXT DEFAULT 'US';
ALTER TABLE workshops ADD COLUMN IF NOT EXISTS timezone TEXT DEFAULT 'America/New_York';
ALTER TABLE workshops ADD COLUMN IF NOT EXISTS address TEXT;

-- Comentarios para claridad
COMMENT ON COLUMN workshops.tax_name IS 'Nombre del impuesto (IVA, ITBIS, VAT, GST, etc.)';
COMMENT ON COLUMN workshops.tax_rate IS 'Tasa de impuesto por defecto (ej: 18.00 para 18%)';
COMMENT ON COLUMN workshops.currency_symbol IS 'Simbolo de moneda (RD$, $, €, etc.)';
COMMENT ON COLUMN workshops.currency_code IS 'Codigo ISO de moneda (DOP, USD, EUR, etc.)';

-- 2. Agregar token publico a quotes para links compartibles
ALTER TABLE quotes ADD COLUMN IF NOT EXISTS public_token TEXT UNIQUE;
ALTER TABLE quotes ADD COLUMN IF NOT EXISTS public_url TEXT;

-- Generar token automaticamente al crear cotizacion
CREATE OR REPLACE FUNCTION generate_quote_public_token()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.public_token IS NULL THEN
        NEW.public_token = encode(gen_random_bytes(16), 'hex');
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS quote_generate_token ON quotes;
CREATE TRIGGER quote_generate_token
    BEFORE INSERT ON quotes
    FOR EACH ROW
    EXECUTE FUNCTION generate_quote_public_token();

-- Actualizar quotes existentes que no tienen token
UPDATE quotes SET public_token = encode(gen_random_bytes(16), 'hex') WHERE public_token IS NULL;

-- 3. Crear indice para buscar por token publico
CREATE INDEX IF NOT EXISTS idx_quotes_public_token ON quotes(public_token);

-- 4. Funcion RPC para obtener cotizacion publica (sin autenticacion)
CREATE OR REPLACE FUNCTION get_public_quote(p_token TEXT)
RETURNS JSON AS $$
DECLARE
    v_quote RECORD;
    v_items JSON;
    v_workshop RECORD;
    v_order RECORD;
    v_customer RECORD;
BEGIN
    -- Obtener cotizacion por token
    SELECT q.*, w.name as workshop_name, w.phone as workshop_phone,
           w.tax_name, w.tax_rate as workshop_tax_rate,
           w.currency_symbol, w.currency_code
    INTO v_quote
    FROM quotes q
    JOIN workshops w ON q.workshop_id = w.id
    WHERE q.public_token = p_token;

    IF NOT FOUND THEN
        RETURN NULL;
    END IF;

    -- Obtener items de la cotizacion
    SELECT json_agg(
        json_build_object(
            'id', qi.id,
            'description', qi.description,
            'item_type', qi.item_type,
            'quantity', qi.quantity,
            'unit_price', qi.unit_price,
            'total_price', qi.total_price
        ) ORDER BY qi.sort_order
    )
    INTO v_items
    FROM quote_items qi
    WHERE qi.quote_id = v_quote.id;

    -- Obtener info de la orden
    SELECT o.order_number, o.device_type, o.device_brand, o.device_model,
           o.problem_description, o.status
    INTO v_order
    FROM orders o
    WHERE o.id = v_quote.order_id;

    -- Obtener info del cliente
    SELECT c.name, c.phone, c.email
    INTO v_customer
    FROM customers c
    JOIN orders o ON o.customer_id = c.id
    WHERE o.id = v_quote.order_id;

    -- Retornar JSON completo
    RETURN json_build_object(
        'id', v_quote.id,
        'status', v_quote.status,
        'subtotal', v_quote.subtotal,
        'tax_rate', v_quote.tax_rate,
        'tax_amount', v_quote.tax_amount,
        'tax_name', v_quote.tax_name,
        'discount_amount', v_quote.discount_amount,
        'total', v_quote.total,
        'notes', v_quote.notes,
        'terms', v_quote.terms,
        'sent_at', v_quote.sent_at,
        'expires_at', v_quote.expires_at,
        'items', COALESCE(v_items, '[]'::json),
        'workshop', json_build_object(
            'name', v_quote.workshop_name,
            'phone', v_quote.workshop_phone,
            'currency_symbol', v_quote.currency_symbol,
            'currency_code', v_quote.currency_code
        ),
        'order', json_build_object(
            'number', v_order.order_number,
            'device_type', v_order.device_type,
            'device_brand', v_order.device_brand,
            'device_model', v_order.device_model,
            'problem', v_order.problem_description,
            'status', v_order.status
        ),
        'customer', json_build_object(
            'name', v_customer.name,
            'phone', v_customer.phone,
            'email', v_customer.email
        )
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. Funcion RPC para aprobar/rechazar cotizacion publicamente
CREATE OR REPLACE FUNCTION respond_to_quote(p_token TEXT, p_response TEXT)
RETURNS BOOLEAN AS $$
DECLARE
    v_quote_id UUID;
BEGIN
    -- Validar response
    IF p_response NOT IN ('approved', 'rejected') THEN
        RAISE EXCEPTION 'Response must be approved or rejected';
    END IF;

    -- Obtener quote id
    SELECT id INTO v_quote_id FROM quotes WHERE public_token = p_token;

    IF NOT FOUND THEN
        RETURN FALSE;
    END IF;

    -- Actualizar estado
    UPDATE quotes
    SET status = p_response,
        responded_at = NOW(),
        updated_at = NOW()
    WHERE id = v_quote_id
    AND status = 'sent';  -- Solo si esta en estado enviado

    RETURN FOUND;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 6. Politica para permitir lectura publica de quotes por token
CREATE POLICY "Public can view quotes by token" ON quotes
    FOR SELECT
    USING (public_token IS NOT NULL);

-- 7. Vista para configuracion regional presets (opcional, para UI)
CREATE TABLE IF NOT EXISTS regional_presets (
    id SERIAL PRIMARY KEY,
    country_code TEXT NOT NULL UNIQUE,
    country_name TEXT NOT NULL,
    currency_code TEXT NOT NULL,
    currency_symbol TEXT NOT NULL,
    tax_name TEXT NOT NULL,
    default_tax_rate DECIMAL(5,2) NOT NULL DEFAULT 0,
    timezone TEXT NOT NULL
);

-- Insertar presets comunes
INSERT INTO regional_presets (country_code, country_name, currency_code, currency_symbol, tax_name, default_tax_rate, timezone)
VALUES
    ('DO', 'Republica Dominicana', 'DOP', 'RD$', 'ITBIS', 18.00, 'America/Santo_Domingo'),
    ('MX', 'Mexico', 'MXN', '$', 'IVA', 16.00, 'America/Mexico_City'),
    ('US', 'Estados Unidos', 'USD', '$', 'Sales Tax', 0.00, 'America/New_York'),
    ('ES', 'Espana', 'EUR', '€', 'IVA', 21.00, 'Europe/Madrid'),
    ('CO', 'Colombia', 'COP', '$', 'IVA', 19.00, 'America/Bogota'),
    ('AR', 'Argentina', 'ARS', '$', 'IVA', 21.00, 'America/Argentina/Buenos_Aires'),
    ('CL', 'Chile', 'CLP', '$', 'IVA', 19.00, 'America/Santiago'),
    ('PE', 'Peru', 'PEN', 'S/', 'IGV', 18.00, 'America/Lima'),
    ('PR', 'Puerto Rico', 'USD', '$', 'IVU', 11.50, 'America/Puerto_Rico')
ON CONFLICT (country_code) DO NOTHING;
