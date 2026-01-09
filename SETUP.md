# axer - Configuracion Inicial

## Requisitos
- Xcode 15.0+
- iOS 17.0+
- Cuenta en Supabase

## Configuracion de Supabase

### 1. Crear proyecto en Supabase
1. Ve a [supabase.com](https://supabase.com)
2. Crea un nuevo proyecto
3. Anota la URL y la Anon Key

### 2. Configurar variables en Xcode
1. Abre `axer.xcodeproj` en Xcode
2. Selecciona el target `axer`
3. Ve a Build Settings
4. Busca "User-Defined"
5. Modifica:
   - `SUPABASE_URL` = tu URL de Supabase
   - `SUPABASE_ANON_KEY` = tu Anon Key

### 3. Crear tablas en Supabase

Ejecuta este SQL en el SQL Editor de Supabase:

```sql
-- Tabla de talleres
CREATE TABLE workshops (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name TEXT NOT NULL,
    phone TEXT,
    currency TEXT DEFAULT 'DOP',
    order_prefix TEXT DEFAULT 'ORD',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Tabla de perfiles de usuario
CREATE TABLE profiles (
    id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
    workshop_id UUID REFERENCES workshops(id) ON DELETE SET NULL,
    full_name TEXT,
    role TEXT DEFAULT 'admin' CHECK (role IN ('admin', 'tecnico')),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Habilitar RLS
ALTER TABLE workshops ENABLE ROW LEVEL SECURITY;
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- Politica: Usuario solo ve su taller
CREATE POLICY "Users can view own workshop" ON workshops
    FOR SELECT USING (
        id IN (
            SELECT workshop_id FROM profiles WHERE id = auth.uid()
        )
    );

-- Politica: Usuario solo ve su perfil
CREATE POLICY "Users can view own profile" ON profiles
    FOR SELECT USING (id = auth.uid());

-- Politica: Usuario puede actualizar su perfil
CREATE POLICY "Users can update own profile" ON profiles
    FOR UPDATE USING (id = auth.uid());

-- Trigger para crear perfil automaticamente
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO profiles (id, full_name)
    VALUES (NEW.id, NEW.raw_user_meta_data->>'full_name');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- Bucket para fotos de ordenes
INSERT INTO storage.buckets (id, name, public)
VALUES ('order_photos', 'order_photos', false);
```

### 4. Habilitar Auth
1. En Supabase Dashboard, ve a Authentication
2. Configura Email Auth (habilitado por defecto)

## Estructura del Proyecto

```
axer/
├── App/                    # Entry point y navegacion principal
│   ├── axerApp.swift
│   ├── RootView.swift
│   └── MainTabView.swift
├── Core/                   # Logica central
│   ├── Session/           # Manejo de sesion
│   ├── Network/           # Supabase y conectividad
│   └── Navigation/        # Router
├── DesignSystem/          # Sistema de diseno
│   ├── Theme/            # Colores, tipografia, espaciado
│   └── Components/       # Componentes reutilizables
├── Features/              # Funcionalidades por modulo
│   ├── Auth/             # Login, registro
│   └── Home/             # Pantalla principal
└── Resources/             # Assets e Info.plist
```

## Ejecutar la App

1. Abre `axer.xcodeproj` en Xcode
2. Selecciona un simulador iOS 17+
3. Presiona Cmd+R para ejecutar

## Proximos Pasos (Etapa 1)

- [ ] Crear flujo de registro de taller
- [ ] Implementar onboarding
- [ ] Crear usuario admin automaticamente
