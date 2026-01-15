-- ============================================
-- TRIGGERS PARA PUSH NOTIFICATIONS - AXER v2
-- ============================================
-- Esta versión usa una tabla app_config en lugar de ALTER DATABASE
-- ============================================

-- PASO 1: Crear tabla de configuración
CREATE TABLE IF NOT EXISTS app_config (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL
);

-- Seguridad: solo backend puede leer
ALTER TABLE app_config ENABLE ROW LEVEL SECURITY;

-- PASO 2: Insertar configuración
INSERT INTO app_config (key, value) VALUES
    ('supabase_url', 'https://sllehrkityhutialtztl.supabase.co'),
    ('supabase_service_role_key', '***REMOVED***')
ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;


-- ============================================
-- FUNCIÓN HELPER: Obtener config
-- ============================================
CREATE OR REPLACE FUNCTION get_app_config(config_key TEXT)
RETURNS TEXT AS $$
DECLARE
    config_value TEXT;
BEGIN
    SELECT value INTO config_value FROM app_config WHERE key = config_key;
    RETURN config_value;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================
-- TRIGGER 1: CAMBIO DE STATUS DE ORDEN
-- ============================================

CREATE OR REPLACE FUNCTION notify_order_status_change()
RETURNS TRIGGER AS $$
DECLARE
    v_status_text TEXT;
    v_supabase_url TEXT;
    v_service_key TEXT;
BEGIN
    IF OLD.status IS DISTINCT FROM NEW.status AND NEW.owner_user_id IS NOT NULL THEN

        v_supabase_url := get_app_config('supabase_url');
        v_service_key := get_app_config('supabase_service_role_key');

        IF v_supabase_url IS NULL OR v_service_key IS NULL THEN
            RAISE WARNING 'Push config not set in app_config table';
            RETURN NEW;
        END IF;

        v_status_text := CASE NEW.status
            WHEN 'received' THEN 'Recibida'
            WHEN 'diagnosing' THEN 'En diagnóstico'
            WHEN 'quoted' THEN 'Cotizada'
            WHEN 'approved' THEN 'Aprobada'
            WHEN 'in_repair' THEN 'En reparación'
            WHEN 'ready' THEN 'Lista para entregar'
            WHEN 'delivered' THEN 'Entregada'
            ELSE NEW.status
        END;

        PERFORM net.http_post(
            url := v_supabase_url || '/functions/v1/send-push-notification',
            headers := jsonb_build_object(
                'Content-Type', 'application/json',
                'Authorization', 'Bearer ' || v_service_key
            ),
            body := jsonb_build_object(
                'user_id', NEW.owner_user_id,
                'title', 'Orden #' || COALESCE(NEW.order_number::TEXT, NEW.id::TEXT),
                'body', 'Estado: ' || v_status_text,
                'data', jsonb_build_object(
                    'type', 'order_status',
                    'order_id', NEW.id::TEXT
                )
            )
        );
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS order_status_change_trigger ON orders;
CREATE TRIGGER order_status_change_trigger
    AFTER UPDATE ON orders
    FOR EACH ROW
    EXECUTE FUNCTION notify_order_status_change();


-- ============================================
-- TRIGGER 2: ORDEN ASIGNADA A TÉCNICO
-- ============================================

CREATE OR REPLACE FUNCTION notify_order_assigned()
RETURNS TRIGGER AS $$
DECLARE
    v_supabase_url TEXT;
    v_service_key TEXT;
BEGIN
    IF OLD.owner_user_id IS DISTINCT FROM NEW.owner_user_id AND NEW.owner_user_id IS NOT NULL THEN

        v_supabase_url := get_app_config('supabase_url');
        v_service_key := get_app_config('supabase_service_role_key');

        IF v_supabase_url IS NULL OR v_service_key IS NULL THEN
            RETURN NEW;
        END IF;

        PERFORM net.http_post(
            url := v_supabase_url || '/functions/v1/send-push-notification',
            headers := jsonb_build_object(
                'Content-Type', 'application/json',
                'Authorization', 'Bearer ' || v_service_key
            ),
            body := jsonb_build_object(
                'user_id', NEW.owner_user_id,
                'title', 'Nueva orden asignada',
                'body', 'Te han asignado la orden #' || COALESCE(NEW.order_number::TEXT, NEW.id::TEXT),
                'data', jsonb_build_object(
                    'type', 'order_assigned',
                    'order_id', NEW.id::TEXT
                )
            )
        );
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS order_assigned_trigger ON orders;
CREATE TRIGGER order_assigned_trigger
    AFTER UPDATE ON orders
    FOR EACH ROW
    EXECUTE FUNCTION notify_order_assigned();


-- ============================================
-- TRIGGER 3: RESPUESTA A COTIZACIÓN
-- ============================================

CREATE OR REPLACE FUNCTION notify_quote_response()
RETURNS TRIGGER AS $$
DECLARE
    v_order_owner_id UUID;
    v_order_number TEXT;
    v_response_text TEXT;
    v_supabase_url TEXT;
    v_service_key TEXT;
BEGIN
    IF OLD.status IS DISTINCT FROM NEW.status AND NEW.status IN ('approved', 'rejected') THEN

        v_supabase_url := get_app_config('supabase_url');
        v_service_key := get_app_config('supabase_service_role_key');

        IF v_supabase_url IS NULL OR v_service_key IS NULL THEN
            RETURN NEW;
        END IF;

        SELECT owner_user_id, order_number::TEXT
        INTO v_order_owner_id, v_order_number
        FROM orders
        WHERE id = NEW.order_id;

        IF v_order_owner_id IS NOT NULL THEN
            v_response_text := CASE NEW.status
                WHEN 'approved' THEN 'aprobó'
                WHEN 'rejected' THEN 'rechazó'
            END;

            PERFORM net.http_post(
                url := v_supabase_url || '/functions/v1/send-push-notification',
                headers := jsonb_build_object(
                    'Content-Type', 'application/json',
                    'Authorization', 'Bearer ' || v_service_key
                ),
                body := jsonb_build_object(
                    'user_id', v_order_owner_id,
                    'title', 'Cotización respondida',
                    'body', 'El cliente ' || v_response_text || ' la cotización de orden #' || COALESCE(v_order_number, NEW.order_id::TEXT),
                    'data', jsonb_build_object(
                        'type', 'quote_response',
                        'order_id', NEW.order_id::TEXT
                    )
                )
            );
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS quote_response_trigger ON quotes;
CREATE TRIGGER quote_response_trigger
    AFTER UPDATE ON quotes
    FOR EACH ROW
    EXECUTE FUNCTION notify_quote_response();


-- ============================================
-- VERIFICAR CONFIGURACIÓN
-- ============================================
DO $$
DECLARE
    v_url TEXT;
    v_key TEXT;
BEGIN
    SELECT value INTO v_url FROM app_config WHERE key = 'supabase_url';
    SELECT value INTO v_key FROM app_config WHERE key = 'supabase_service_role_key';

    IF v_url IS NULL OR v_url = 'https://TU_PROJECT_ID.supabase.co' THEN
        RAISE NOTICE '⚠️  Actualiza supabase_url en app_config';
    ELSE
        RAISE NOTICE '✅ supabase_url configurado';
    END IF;

    IF v_key IS NULL OR v_key = 'TU_SERVICE_ROLE_KEY_AQUI' THEN
        RAISE NOTICE '⚠️  Actualiza supabase_service_role_key en app_config';
    ELSE
        RAISE NOTICE '✅ service_role_key configurado';
    END IF;
END $$;
