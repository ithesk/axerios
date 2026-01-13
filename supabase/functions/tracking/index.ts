import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const url = new URL(req.url)
    const pathParts = url.pathname.split('/').filter(Boolean)

    // Expected paths:
    // GET /tracking/{token} - Get order data
    // POST /tracking/{token}/approve - Approve quote
    // POST /tracking/{token}/reject - Reject quote

    // Find 'tracking' in path and get parts after it
    const trackingIndex = pathParts.indexOf('tracking')
    const relevantParts = trackingIndex >= 0 ? pathParts.slice(trackingIndex + 1) : pathParts

    const token = relevantParts[0]
    const action = relevantParts[1] // 'approve' or 'reject'

    if (!token) {
      return new Response(
        JSON.stringify({ error: 'Token requerido' }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 }
      )
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, supabaseKey)

    // Handle approve/reject actions
    if (req.method === 'POST' && (action === 'approve' || action === 'reject')) {
      const rpcName = action === 'approve' ? 'approve_quote_from_tracking' : 'reject_quote_from_tracking'

      const { data, error } = await supabase.rpc(rpcName, { p_order_token: token })

      if (error) {
        console.error(`Error in ${rpcName}:`, error)
        return new Response(
          JSON.stringify({ error: `No se pudo ${action === 'approve' ? 'aprobar' : 'rechazar'} la cotizacion` }),
          { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 }
        )
      }

      if (!data) {
        return new Response(
          JSON.stringify({ error: 'Cotizacion no encontrada o ya procesada' }),
          { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 404 }
        )
      }

      return new Response(
        JSON.stringify({ success: true, action }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
      )
    }

    // Default: Get order data
    const { data, error } = await supabase.rpc('get_order_by_token', { p_token: token })

    if (error) {
      console.error('Error in get_order_by_token:', error)
      return new Response(
        JSON.stringify({ error: 'Token invalido' }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 404 }
      )
    }

    if (!data) {
      return new Response(
        JSON.stringify({ error: 'Orden no encontrada' }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 404 }
      )
    }

    return new Response(JSON.stringify(data), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200
    })

  } catch (error) {
    console.error('Server error:', error)
    return new Response(
      JSON.stringify({ error: 'Error del servidor' }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 500 }
    )
  }
})
