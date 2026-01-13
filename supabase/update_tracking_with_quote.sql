-- =====================================================
-- ACTUALIZAR TRACKING PARA INCLUIR COTIZACION
-- =====================================================

-- Actualizar la funcion get_order_by_token para incluir datos de cotizacion
CREATE OR REPLACE FUNCTION get_order_by_token(p_token TEXT)
RETURNS JSON AS $$
DECLARE
    v_order RECORD;
    v_quote RECORD;
    v_quote_items JSON;
    v_workshop RECORD;
BEGIN
    -- Obtener orden por token
    SELECT o.*, c.name as customer_name, c.phone as customer_phone, c.email as customer_email
    INTO v_order
    FROM orders o
    LEFT JOIN customers c ON o.customer_id = c.id
    WHERE o.public_token = p_token;

    IF NOT FOUND THEN
        RETURN NULL;
    END IF;

    -- Obtener workshop
    SELECT w.name, w.phone, w.currency_symbol, w.currency_code, w.tax_name
    INTO v_workshop
    FROM workshops w
    WHERE w.id = v_order.workshop_id;

    -- Obtener cotizacion mas reciente si existe
    SELECT q.*
    INTO v_quote
    FROM quotes q
    WHERE q.order_id = v_order.id
    ORDER BY q.created_at DESC
    LIMIT 1;

    -- Si hay cotizacion, obtener items
    IF v_quote.id IS NOT NULL THEN
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
        INTO v_quote_items
        FROM quote_items qi
        WHERE qi.quote_id = v_quote.id;
    END IF;

    -- Retornar JSON completo
    RETURN json_build_object(
        'id', v_order.id,
        'order_number', v_order.order_number,
        'status', v_order.status,
        'device_type', v_order.device_type,
        'device_brand', v_order.device_brand,
        'device_model', v_order.device_model,
        'problem_description', v_order.problem_description,
        'created_at', v_order.created_at,
        'updated_at', v_order.updated_at,
        'workshop_name', v_workshop.name,
        'workshop_phone', v_workshop.phone,
        'currency_symbol', COALESCE(v_workshop.currency_symbol, '$'),
        'currency_code', COALESCE(v_workshop.currency_code, 'USD'),
        'tax_name', COALESCE(v_workshop.tax_name, 'IVA'),
        'customer_name', v_order.customer_name,
        'quote', CASE WHEN v_quote.id IS NOT NULL THEN json_build_object(
            'id', v_quote.id,
            'status', v_quote.status,
            'subtotal', v_quote.subtotal,
            'tax_rate', v_quote.tax_rate,
            'tax_amount', v_quote.tax_amount,
            'discount_amount', v_quote.discount_amount,
            'total', v_quote.total,
            'notes', v_quote.notes,
            'public_token', v_quote.public_token,
            'sent_at', v_quote.sent_at,
            'items', COALESCE(v_quote_items, '[]'::json)
        ) ELSE NULL END
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Funcion para aprobar cotizacion desde tracking publico
CREATE OR REPLACE FUNCTION approve_quote_from_tracking(p_order_token TEXT)
RETURNS BOOLEAN AS $$
DECLARE
    v_order_id UUID;
    v_quote_id UUID;
BEGIN
    -- Obtener order_id desde token
    SELECT id INTO v_order_id FROM orders WHERE public_token = p_order_token;
    IF NOT FOUND THEN RETURN FALSE; END IF;

    -- Obtener quote_id
    SELECT id INTO v_quote_id FROM quotes WHERE order_id = v_order_id AND status = 'sent' ORDER BY created_at DESC LIMIT 1;
    IF NOT FOUND THEN RETURN FALSE; END IF;

    -- Actualizar quote
    UPDATE quotes SET status = 'approved', responded_at = NOW(), updated_at = NOW() WHERE id = v_quote_id;

    -- Actualizar order status
    UPDATE orders SET status = 'approved', updated_at = NOW() WHERE id = v_order_id;

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Funcion para rechazar cotizacion desde tracking publico
CREATE OR REPLACE FUNCTION reject_quote_from_tracking(p_order_token TEXT)
RETURNS BOOLEAN AS $$
DECLARE
    v_order_id UUID;
    v_quote_id UUID;
BEGIN
    -- Obtener order_id desde token
    SELECT id INTO v_order_id FROM orders WHERE public_token = p_order_token;
    IF NOT FOUND THEN RETURN FALSE; END IF;

    -- Obtener quote_id
    SELECT id INTO v_quote_id FROM quotes WHERE order_id = v_order_id AND status = 'sent' ORDER BY created_at DESC LIMIT 1;
    IF NOT FOUND THEN RETURN FALSE; END IF;

    -- Actualizar quote
    UPDATE quotes SET status = 'rejected', responded_at = NOW(), updated_at = NOW() WHERE id = v_quote_id;

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
