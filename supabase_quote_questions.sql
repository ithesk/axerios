-- ============================================
-- SISTEMA DE PREGUNTAS EN COTIZACIONES
-- ============================================

-- 1. Crear tabla quote_questions
CREATE TABLE IF NOT EXISTS quote_questions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    quote_id UUID NOT NULL REFERENCES quotes(id) ON DELETE CASCADE,
    order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    workshop_id UUID NOT NULL REFERENCES workshops(id) ON DELETE CASCADE,

    -- Contenido
    question TEXT NOT NULL,
    answer TEXT,

    -- Quien pregunta/responde
    asked_by_customer BOOLEAN DEFAULT true,
    answered_by_user_id UUID REFERENCES profiles(id),

    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    answered_at TIMESTAMPTZ,

    -- Metadata
    is_read BOOLEAN DEFAULT false
);

-- 2. Indices para performance
CREATE INDEX IF NOT EXISTS idx_quote_questions_quote ON quote_questions(quote_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_quote_questions_order ON quote_questions(order_id);
CREATE INDEX IF NOT EXISTS idx_quote_questions_workshop ON quote_questions(workshop_id, is_read, created_at DESC);

-- 3. RLS - Row Level Security
ALTER TABLE quote_questions ENABLE ROW LEVEL SECURITY;

-- Usuarios del workshop pueden ver preguntas de su workshop
CREATE POLICY "Users can view their workshop questions" ON quote_questions
    FOR SELECT
    USING (
        workshop_id IN (
            SELECT workshop_id FROM profiles WHERE id = auth.uid()
        )
    );

-- Usuarios del workshop pueden insertar respuestas
CREATE POLICY "Users can answer questions" ON quote_questions
    FOR UPDATE
    USING (
        workshop_id IN (
            SELECT workshop_id FROM profiles WHERE id = auth.uid()
        )
    );

-- 4. Funcion para agregar pregunta desde tracking publico
CREATE OR REPLACE FUNCTION add_quote_question_from_tracking(
    p_order_token TEXT,
    p_question TEXT
)
RETURNS JSON AS $$
DECLARE
    v_order RECORD;
    v_quote RECORD;
    v_question_id UUID;
BEGIN
    -- Validar que la pregunta no esta vacia
    IF p_question IS NULL OR TRIM(p_question) = '' THEN
        RETURN json_build_object('success', false, 'error', 'La pregunta no puede estar vacia');
    END IF;

    -- Obtener orden por token
    SELECT id, workshop_id INTO v_order
    FROM orders
    WHERE public_token = p_order_token;

    IF NOT FOUND THEN
        RETURN json_build_object('success', false, 'error', 'Orden no encontrada');
    END IF;

    -- Obtener cotizacion activa (sent status)
    SELECT id INTO v_quote
    FROM quotes
    WHERE order_id = v_order.id AND status = 'sent'
    ORDER BY created_at DESC
    LIMIT 1;

    IF NOT FOUND THEN
        RETURN json_build_object('success', false, 'error', 'No hay cotizacion pendiente');
    END IF;

    -- Insertar pregunta
    INSERT INTO quote_questions (quote_id, order_id, workshop_id, question, asked_by_customer)
    VALUES (v_quote.id, v_order.id, v_order.workshop_id, TRIM(p_question), true)
    RETURNING id INTO v_question_id;

    RETURN json_build_object(
        'success', true,
        'question_id', v_question_id,
        'message', 'Pregunta enviada correctamente'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. Funcion para obtener preguntas de una cotizacion
CREATE OR REPLACE FUNCTION get_quote_questions(p_quote_id UUID)
RETURNS JSON AS $$
BEGIN
    RETURN (
        SELECT COALESCE(json_agg(
            json_build_object(
                'id', qq.id,
                'question', qq.question,
                'answer', qq.answer,
                'asked_by_customer', qq.asked_by_customer,
                'answered_by', p.full_name,
                'created_at', qq.created_at,
                'answered_at', qq.answered_at,
                'is_read', qq.is_read
            ) ORDER BY qq.created_at ASC
        ), '[]'::json)
        FROM quote_questions qq
        LEFT JOIN profiles p ON p.id = qq.answered_by_user_id
        WHERE qq.quote_id = p_quote_id
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 6. Funcion para responder pregunta
CREATE OR REPLACE FUNCTION answer_quote_question(
    p_question_id UUID,
    p_answer TEXT
)
RETURNS JSON AS $$
DECLARE
    v_user_id UUID;
BEGIN
    v_user_id := auth.uid();

    IF v_user_id IS NULL THEN
        RETURN json_build_object('success', false, 'error', 'No autenticado');
    END IF;

    UPDATE quote_questions
    SET
        answer = TRIM(p_answer),
        answered_by_user_id = v_user_id,
        answered_at = NOW(),
        is_read = true
    WHERE id = p_question_id
    AND workshop_id IN (SELECT workshop_id FROM profiles WHERE id = v_user_id);

    IF NOT FOUND THEN
        RETURN json_build_object('success', false, 'error', 'Pregunta no encontrada');
    END IF;

    RETURN json_build_object('success', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 7. Funcion para marcar preguntas como leidas
CREATE OR REPLACE FUNCTION mark_quote_questions_read(p_quote_id UUID)
RETURNS VOID AS $$
DECLARE
    v_user_id UUID;
BEGIN
    v_user_id := auth.uid();

    UPDATE quote_questions
    SET is_read = true
    WHERE quote_id = p_quote_id
    AND workshop_id IN (SELECT workshop_id FROM profiles WHERE id = v_user_id)
    AND is_read = false;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 8. Actualizar get_order_by_token para incluir preguntas
CREATE OR REPLACE FUNCTION get_order_by_token(p_token TEXT)
RETURNS JSON AS $$
DECLARE
    v_order RECORD;
    v_quote RECORD;
    v_quote_items JSON;
    v_quote_questions JSON;
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

    -- Si hay cotizacion, obtener items y preguntas
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

        -- Obtener preguntas
        SELECT json_agg(
            json_build_object(
                'id', qq.id,
                'question', qq.question,
                'answer', qq.answer,
                'created_at', qq.created_at,
                'answered_at', qq.answered_at
            ) ORDER BY qq.created_at ASC
        )
        INTO v_quote_questions
        FROM quote_questions qq
        WHERE qq.quote_id = v_quote.id;
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
            'items', COALESCE(v_quote_items, '[]'::json),
            'questions', COALESCE(v_quote_questions, '[]'::json)
        ) ELSE NULL END
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
