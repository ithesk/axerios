# ETAPA 0 — Fundaciones del Proyecto
## Objetivo
Dejar lista la base técnica para construir rápido sin rehacer arquitectura.

## Alcance funcional
- App SwiftUI arranca y conecta con Supabase
- Manejo de sesión
- Estructura limpia del proyecto
- Design System base (azul friendly)

## Ajustes técnicos — SwiftUI
- Arquitectura: MVVM
- Carpetas:
  - App/
  - Core/ (Auth, Network, Session)
  - DesignSystem/
  - Features/
- NavigationStack + Router simple
- SessionStore (ObservableObject)
- NetworkMonitor (online/offline)

## Ajustes técnicos — Supabase
- Proyecto creado
- Auth habilitado (email/password)
- Postgres activo
- Storage bucket: `order_photos`
- Variables:
  - SUPABASE_URL
  - SUPABASE_ANON_KEY

## UI / Diseño
- Color primario: Azul
- Botón primario grande
- Cards con bordes suaves
- Tipografía clara (SF Pro)

## Resultado esperado
- App abre
- Login funcional
- Sesión persistente


# ETAPA 1 — Creación de Taller y Cuenta Admin
## Objetivo
Permitir que una tienda cree su taller y entre al sistema en menos de 2 minutos.

## Flujo
1) Welcome
2) Crear cuenta
3) Onboarding rápido
4) Home

## Alcance funcional
- Crear taller
- Crear usuario admin
- Configuración mínima inicial

## Ajustes técnicos — SwiftUI
- Vistas:
  - WelcomeView
  - SignUpWorkshopView
  - OnboardingView
  - HomeView
- Validaciones simples
- Guardar workshop activo en SessionStore

## Ajustes técnicos — Supabase
Tablas:
- workshops(id, name, phone, currency, order_prefix)
- profiles(id, workshop_id, full_name, role)

RLS:
- Usuario solo accede a su workshop

Trigger:
- Al crear usuario → crear profile

## Resultado esperado
- 1 taller creado
- 1 admin activo
- Acceso al Home

# ETAPA 2 — Gestión de Usuarios (Admin + Técnicos)
## Objetivo
Que un taller tenga varias cuentas sin fricción (ej: 1 admin + 2 técnicos).

## Flujo
1) Admin entra a "Equipo"
2) Genera invitación
3) Técnico se une con link o código
4) Técnico crea su cuenta

## Alcance funcional
- Roles: Admin / Técnico
- Invitación por link o código
- Expiración de invitaciones

## Ajustes técnicos — SwiftUI
- TeamView (lista de usuarios)
- InviteUserView
- JoinWorkshopView
- CreateAccountForInviteView

## Ajustes técnicos — Supabase
Tablas:
- invites(id, workshop_id, role, token, expires_at, used_at)

Edge Functions:
- create_invite
- validate_invite
- accept_invite

RLS:
- Solo admin puede crear/ver invites

## Resultado esperado
- Taller con múltiples usuarios
- Técnicos operativos en minutos

# ETAPA 3 — Clientes y Órdenes (Recepción)
## Objetivo
Registrar reparaciones rápido sin perder información.

## Flujo
1) Buscar cliente
2) Crear cliente si no existe
3) Crear orden paso a paso
4) Confirmación

## Alcance funcional
- Clientes
- Órdenes
- Fotos del equipo
- Búsqueda rápida

## Ajustes técnicos — SwiftUI
- NuevaOrdenView (wizard)
- Cámara integrada
- Optimistic UI
- Botón flotante “Nueva Orden”

## Ajustes técnicos — Supabase
Tablas:
- customers
- orders
- order_photos
- order_notes

Edge Function:
- next_order_number(workshop_id)

Storage:
- order_photos/{workshop_id}/{order_id}/

## Resultado esperado
- Crear orden < 60 segundos
- Buscar por teléfono o IMEI

# ETAPA 4 — Estados y Operación Diaria
## Objetivo
Que el taller no pierda el control del flujo de reparaciones.

## Estados MVP
- Recibido
- En diagnóstico
- Cotizado
- Aprobado
- En reparación
- Listo
- Entregado

## Alcance funcional
- Cambiar estado
- Historial de estados
- Notas internas

## Ajustes técnicos — SwiftUI
- StatusBar (chips)
- Timeline de historial
- Acción rápida “Cambiar estado”

## Ajustes técnicos — Supabase
Tabla:
- order_status_history

Regla:
- Cada cambio inserta historial

Índices:
- orders(status, created_at)

## Resultado esperado
- Flujo claro
- Auditoría básica

# ETAPA 4 — Estados y Operación Diaria
## Objetivo
Que el taller no pierda el control del flujo de reparaciones.

## Estados MVP
- Recibido
- En diagnóstico
- Cotizado
- Aprobado
- En reparación
- Listo
- Entregado

## Alcance funcional
- Cambiar estado
- Historial de estados
- Notas internas

## Ajustes técnicos — SwiftUI
- StatusBar (chips)
- Timeline de historial
- Acción rápida “Cambiar estado”

## Ajustes técnicos — Supabase
Tabla:
- order_status_history

Regla:
- Cada cambio inserta historial

Índices:
- orders(status, created_at)

## Resultado esperado
- Flujo claro
- Auditoría básica

# ETAPA 5 — Cotización Simple
## Objetivo
Poder cobrar y validar valor del sistema.

## Alcance funcional
- Crear cotización
- Ítems simples
- Aprobar/Rechazar
- Total automático

## Ajustes técnicos — SwiftUI
- QuoteEditorView
- Plantillas rápidas
- Botón “Marcar aprobada”

## Ajustes técnicos — Supabase
Tablas:
- quotes
- quote_items

Reglas:
- 1 cotización activa por orden

## Resultado esperado
- Taller cotiza sin Excel
- Flujo avanza a reparación

# ETAPA 6 — Seguimiento del Cliente (Tracking)
## Objetivo
Reducir llamadas y aumentar valor percibido.

## Flujo
1) Sistema genera link público
2) Cliente abre link
3) Ve estado actual

## Alcance funcional
- Tracking sin cuenta
- Link regenerable
- Vista pública segura

## Ajustes técnicos — SwiftUI
- Botón “Compartir seguimiento”
- Regenerar token

## Ajustes técnicos — Supabase
Campos:
- orders.public_token

Edge Function:
- create_or_rotate_public_token

Endpoint público:
- /t/{token}

## Resultado esperado
- Menos soporte
- Feature vendible

# ETAPA 7 — Piloto y Validación Comercial
## Objetivo
Probar si la idea es rentable.

## Alcance
- 1–3 talleres reales
- Uso diario
- Feedback rápido

## Ajustes técnicos
- Logs
- Backups
- Optimización de consultas
- UI polish

## Métrica clave
- Taller usa app todos los días
- Acepta pagar mensualidad

## Resultado esperado
- Decisión: escalar o ajustar
