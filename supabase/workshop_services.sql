-- Tabla de servicios/productos del taller
CREATE TABLE IF NOT EXISTS workshop_services (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    workshop_id UUID NOT NULL REFERENCES workshops(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    description TEXT,
    item_type TEXT NOT NULL DEFAULT 'service' CHECK (item_type IN ('service', 'part', 'other')),
    default_price DECIMAL(12,2) NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT true,
    use_count INTEGER NOT NULL DEFAULT 0,
    last_used_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),

    -- Evitar duplicados por taller
    UNIQUE(workshop_id, name)
);

-- Índices
CREATE INDEX idx_workshop_services_workshop ON workshop_services(workshop_id);
CREATE INDEX idx_workshop_services_active ON workshop_services(workshop_id, is_active);
CREATE INDEX idx_workshop_services_use_count ON workshop_services(workshop_id, use_count DESC);

-- RLS
ALTER TABLE workshop_services ENABLE ROW LEVEL SECURITY;

-- Política: usuarios solo ven servicios de su taller
CREATE POLICY "Users can view their workshop services"
ON workshop_services FOR SELECT
USING (
    workshop_id IN (
        SELECT workshop_id FROM profiles WHERE id = auth.uid()
    )
);

-- Política: usuarios pueden insertar servicios en su taller
CREATE POLICY "Users can insert services in their workshop"
ON workshop_services FOR INSERT
WITH CHECK (
    workshop_id IN (
        SELECT workshop_id FROM profiles WHERE id = auth.uid()
    )
);

-- Política: usuarios pueden actualizar servicios de su taller
CREATE POLICY "Users can update their workshop services"
ON workshop_services FOR UPDATE
USING (
    workshop_id IN (
        SELECT workshop_id FROM profiles WHERE id = auth.uid()
    )
);

-- Política: solo admin puede eliminar
CREATE POLICY "Admins can delete workshop services"
ON workshop_services FOR DELETE
USING (
    workshop_id IN (
        SELECT p.workshop_id FROM profiles p WHERE p.id = auth.uid() AND p.role = 'admin'
    )
);

-- Trigger para actualizar updated_at
CREATE OR REPLACE FUNCTION update_workshop_services_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER workshop_services_updated_at
    BEFORE UPDATE ON workshop_services
    FOR EACH ROW
    EXECUTE FUNCTION update_workshop_services_updated_at();

-- Función para incrementar uso de servicio
CREATE OR REPLACE FUNCTION increment_service_usage(service_id UUID)
RETURNS void AS $$
BEGIN
    UPDATE workshop_services
    SET use_count = use_count + 1,
        last_used_at = NOW()
    WHERE id = service_id;
END;
$$ LANGUAGE plpgsql;

-- Función para obtener servicios sugeridos (catálogo + historial)
CREATE OR REPLACE FUNCTION get_suggested_services(p_workshop_id UUID, p_limit INTEGER DEFAULT 10)
RETURNS TABLE (
    id UUID,
    name TEXT,
    item_type TEXT,
    default_price DECIMAL,
    source TEXT,
    use_count INTEGER
) AS $$
BEGIN
    RETURN QUERY
    -- Servicios del catálogo activos
    SELECT
        ws.id,
        ws.name,
        ws.item_type,
        ws.default_price,
        'catalog'::TEXT as source,
        ws.use_count
    FROM workshop_services ws
    WHERE ws.workshop_id = p_workshop_id
    AND ws.is_active = true

    UNION ALL

    -- Servicios más usados del historial (no en catálogo)
    SELECT
        gen_random_uuid() as id,
        qi.description as name,
        qi.item_type,
        AVG(qi.unit_price) as default_price,
        'history'::TEXT as source,
        COUNT(*)::INTEGER as use_count
    FROM quote_items qi
    JOIN quotes q ON qi.quote_id = q.id
    WHERE q.workshop_id = p_workshop_id
    AND NOT EXISTS (
        SELECT 1 FROM workshop_services ws
        WHERE ws.workshop_id = p_workshop_id
        AND LOWER(ws.name) = LOWER(qi.description)
    )
    GROUP BY qi.description, qi.item_type
    HAVING COUNT(*) >= 2

    ORDER BY use_count DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;
