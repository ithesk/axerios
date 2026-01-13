-- =============================================
-- MIGRACIÓN: Sistema de Owner (Responsable)
-- Ejecutar en Supabase SQL Editor
-- =============================================

-- 1. Agregar campos de owner a orders
ALTER TABLE orders
ADD COLUMN IF NOT EXISTS owner_user_id UUID REFERENCES profiles(id),
ADD COLUMN IF NOT EXISTS closed_by_user_id UUID REFERENCES profiles(id),
ADD COLUMN IF NOT EXISTS closed_at TIMESTAMPTZ;

-- 2. Migrar datos existentes: owner = created_by
UPDATE orders
SET owner_user_id = created_by
WHERE owner_user_id IS NULL AND created_by IS NOT NULL;

-- 3. Para órdenes sin created_by, asignar al primer admin del workshop
UPDATE orders o
SET owner_user_id = (
    SELECT p.id
    FROM profiles p
    WHERE p.workshop_id = o.workshop_id
    ORDER BY p.created_at ASC
    LIMIT 1
)
WHERE o.owner_user_id IS NULL;

-- 4. Crear índices para performance
CREATE INDEX IF NOT EXISTS idx_orders_owner ON orders(workshop_id, owner_user_id);
CREATE INDEX IF NOT EXISTS idx_orders_workshop_status ON orders(workshop_id, status, created_at DESC);

-- 5. Crear tabla order_events para auditoría completa
CREATE TABLE IF NOT EXISTS order_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    workshop_id UUID NOT NULL REFERENCES workshops(id) ON DELETE CASCADE,
    order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,

    -- Tipo de evento
    type TEXT NOT NULL CHECK (type IN (
        'created',           -- Orden creada
        'status_changed',    -- Cambio de estado
        'assigned',          -- Asignado por admin
        'taken',             -- Usuario tomó la orden
        'note_added',        -- Nota agregada
        'photo_added',       -- Foto agregada
        'quote_sent',        -- Cotización enviada
        'quote_approved',    -- Cotización aprobada
        'quote_rejected',    -- Cotización rechazada
        'delivered',         -- Entregado
        'reopened'           -- Reabierto (garantía)
    )),

    -- Actor (quien hizo la acción)
    actor_user_id UUID REFERENCES profiles(id),

    -- Para cambios de asignación
    from_user_id UUID REFERENCES profiles(id),
    to_user_id UUID REFERENCES profiles(id),

    -- Para cambios de estado
    from_status TEXT,
    to_status TEXT,

    -- Metadata adicional
    note TEXT,
    metadata JSONB DEFAULT '{}',

    created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- 6. Índices para order_events
CREATE INDEX IF NOT EXISTS idx_order_events_order ON order_events(order_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_order_events_workshop ON order_events(workshop_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_order_events_actor ON order_events(actor_user_id, created_at DESC);

-- 7. RLS para order_events
ALTER TABLE order_events ENABLE ROW LEVEL SECURITY;

-- Lectura: usuarios del workshop pueden ver eventos de su workshop
CREATE POLICY "Users can view their workshop events" ON order_events
    FOR SELECT
    USING (
        workshop_id IN (
            SELECT workshop_id FROM profiles WHERE id = auth.uid()
        )
    );

-- Escritura: usuarios del workshop pueden insertar eventos
CREATE POLICY "Users can insert events in their workshop" ON order_events
    FOR INSERT
    WITH CHECK (
        workshop_id IN (
            SELECT workshop_id FROM profiles WHERE id = auth.uid()
        )
    );

-- 8. Migrar historial existente a order_events
INSERT INTO order_events (workshop_id, order_id, type, actor_user_id, from_status, to_status, note, created_at)
SELECT
    o.workshop_id,
    h.order_id,
    'status_changed',
    h.changed_by,
    h.old_status,
    h.new_status,
    h.note,
    h.changed_at
FROM order_status_history h
JOIN orders o ON o.id = h.order_id
ON CONFLICT DO NOTHING;

-- 9. Función RPC: change_order_status
-- Valida permisos y aplica autopiloto
CREATE OR REPLACE FUNCTION change_order_status(
    p_order_id UUID,
    p_new_status TEXT,
    p_note TEXT DEFAULT NULL,
    p_assign_to_user_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_order RECORD;
    v_user_id UUID;
    v_user_role TEXT;
    v_workshop_user_count INT;
    v_new_owner_id UUID;
    v_old_status TEXT;
BEGIN
    -- Obtener usuario actual
    v_user_id := auth.uid();

    -- Obtener orden actual
    SELECT o.*, p.role as owner_role
    INTO v_order
    FROM orders o
    LEFT JOIN profiles p ON p.id = o.owner_user_id
    WHERE o.id = p_order_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Orden no encontrada');
    END IF;

    -- Obtener rol del usuario actual
    SELECT role INTO v_user_role FROM profiles WHERE id = v_user_id;

    -- Validar permisos: owner o admin pueden cambiar estado
    IF v_order.owner_user_id != v_user_id AND v_user_role != 'admin' THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Solo el responsable o un admin puede cambiar el estado',
            'owner_id', v_order.owner_user_id
        );
    END IF;

    -- Guardar estado anterior
    v_old_status := v_order.status;

    -- Contar usuarios en el workshop
    SELECT COUNT(*) INTO v_workshop_user_count
    FROM profiles WHERE workshop_id = v_order.workshop_id;

    -- Determinar nuevo owner según autopiloto
    IF p_assign_to_user_id IS NOT NULL THEN
        -- Asignación explícita
        v_new_owner_id := p_assign_to_user_id;
    ELSIF v_workshop_user_count = 1 THEN
        -- Solo 1 usuario: siempre es el owner
        v_new_owner_id := v_user_id;
    ELSE
        -- Múltiples usuarios: mantener owner actual o asignar al que cambia
        -- (el cliente puede pedir asignación explícita via p_assign_to_user_id)
        v_new_owner_id := COALESCE(v_order.owner_user_id, v_user_id);
    END IF;

    -- Actualizar orden
    UPDATE orders SET
        status = p_new_status,
        owner_user_id = v_new_owner_id,
        updated_at = now(),
        -- Campos especiales según estado
        delivered_at = CASE WHEN p_new_status = 'delivered' THEN now() ELSE delivered_at END,
        closed_by_user_id = CASE WHEN p_new_status = 'delivered' THEN v_user_id ELSE closed_by_user_id END,
        closed_at = CASE WHEN p_new_status = 'delivered' THEN now() ELSE closed_at END
    WHERE id = p_order_id;

    -- Registrar evento
    INSERT INTO order_events (
        workshop_id, order_id, type, actor_user_id,
        from_status, to_status, from_user_id, to_user_id, note
    ) VALUES (
        v_order.workshop_id, p_order_id, 'status_changed', v_user_id,
        v_old_status, p_new_status,
        v_order.owner_user_id, v_new_owner_id,
        p_note
    );

    RETURN jsonb_build_object(
        'success', true,
        'order_id', p_order_id,
        'old_status', v_old_status,
        'new_status', p_new_status,
        'new_owner_id', v_new_owner_id
    );
END;
$$;

-- 10. Función RPC: take_order
-- Permite a un usuario tomar una orden
CREATE OR REPLACE FUNCTION take_order(p_order_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_order RECORD;
    v_user_id UUID;
    v_old_owner_id UUID;
BEGIN
    v_user_id := auth.uid();

    -- Obtener orden
    SELECT * INTO v_order FROM orders WHERE id = p_order_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Orden no encontrada');
    END IF;

    -- Validar que el usuario pertenece al workshop
    IF NOT EXISTS (
        SELECT 1 FROM profiles
        WHERE id = v_user_id AND workshop_id = v_order.workshop_id
    ) THEN
        RETURN jsonb_build_object('success', false, 'error', 'No perteneces a este taller');
    END IF;

    -- Guardar owner anterior
    v_old_owner_id := v_order.owner_user_id;

    -- Actualizar owner
    UPDATE orders SET
        owner_user_id = v_user_id,
        updated_at = now()
    WHERE id = p_order_id;

    -- Registrar evento
    INSERT INTO order_events (
        workshop_id, order_id, type, actor_user_id,
        from_user_id, to_user_id
    ) VALUES (
        v_order.workshop_id, p_order_id, 'taken', v_user_id,
        v_old_owner_id, v_user_id
    );

    RETURN jsonb_build_object(
        'success', true,
        'order_id', p_order_id,
        'new_owner_id', v_user_id
    );
END;
$$;

-- 11. Función RPC: assign_order (solo admin)
CREATE OR REPLACE FUNCTION assign_order(
    p_order_id UUID,
    p_to_user_id UUID,
    p_note TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_order RECORD;
    v_user_id UUID;
    v_user_role TEXT;
    v_old_owner_id UUID;
BEGIN
    v_user_id := auth.uid();

    -- Verificar que es admin
    SELECT role INTO v_user_role FROM profiles WHERE id = v_user_id;
    IF v_user_role != 'admin' THEN
        RETURN jsonb_build_object('success', false, 'error', 'Solo admins pueden asignar órdenes');
    END IF;

    -- Obtener orden
    SELECT * INTO v_order FROM orders WHERE id = p_order_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Orden no encontrada');
    END IF;

    -- Validar que el usuario destino pertenece al workshop
    IF NOT EXISTS (
        SELECT 1 FROM profiles
        WHERE id = p_to_user_id AND workshop_id = v_order.workshop_id
    ) THEN
        RETURN jsonb_build_object('success', false, 'error', 'Usuario no pertenece al taller');
    END IF;

    v_old_owner_id := v_order.owner_user_id;

    -- Actualizar owner
    UPDATE orders SET
        owner_user_id = p_to_user_id,
        updated_at = now()
    WHERE id = p_order_id;

    -- Registrar evento
    INSERT INTO order_events (
        workshop_id, order_id, type, actor_user_id,
        from_user_id, to_user_id, note
    ) VALUES (
        v_order.workshop_id, p_order_id, 'assigned', v_user_id,
        v_old_owner_id, p_to_user_id, p_note
    );

    RETURN jsonb_build_object(
        'success', true,
        'order_id', p_order_id,
        'new_owner_id', p_to_user_id
    );
END;
$$;

-- 12. Función helper: get_workshop_users
CREATE OR REPLACE FUNCTION get_workshop_users(p_workshop_id UUID)
RETURNS TABLE (
    id UUID,
    full_name TEXT,
    role TEXT,
    avatar_url TEXT
)
LANGUAGE sql
SECURITY DEFINER
AS $$
    SELECT id, full_name, role, avatar_url
    FROM profiles
    WHERE workshop_id = p_workshop_id
    ORDER BY
        CASE WHEN role = 'admin' THEN 0 ELSE 1 END,
        full_name;
$$;

-- =============================================
-- FIN DE MIGRACIÓN
-- =============================================
