-- =====================================================
-- AVATAR STORAGE SETUP
-- =====================================================

-- 1. Agregar campo avatar_url a profiles
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS avatar_url TEXT;

-- 2. Crear bucket de storage para avatars (ejecutar en Supabase Dashboard > Storage)
-- INSERT INTO storage.buckets (id, name, public) VALUES ('avatars', 'avatars', true);

-- 3. Politicas de storage para avatars

-- Permitir a usuarios autenticados subir su propio avatar
CREATE POLICY "Users can upload own avatar"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
    bucket_id = 'avatars' AND
    (storage.foldername(name))[1] = auth.uid()::text
);

-- Permitir a usuarios autenticados actualizar su propio avatar
CREATE POLICY "Users can update own avatar"
ON storage.objects FOR UPDATE
TO authenticated
USING (
    bucket_id = 'avatars' AND
    (storage.foldername(name))[1] = auth.uid()::text
);

-- Permitir a usuarios autenticados eliminar su propio avatar
CREATE POLICY "Users can delete own avatar"
ON storage.objects FOR DELETE
TO authenticated
USING (
    bucket_id = 'avatars' AND
    (storage.foldername(name))[1] = auth.uid()::text
);

-- Permitir lectura publica de avatars
CREATE POLICY "Public can view avatars"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'avatars');

-- =====================================================
-- NOTA: Debes crear el bucket manualmente en Supabase:
-- 1. Ir a Storage en el Dashboard de Supabase
-- 2. Click en "New bucket"
-- 3. Nombre: avatars
-- 4. Marcar como "Public bucket"
-- 5. Click "Create bucket"
-- =====================================================
