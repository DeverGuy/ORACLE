// @ts-nocheck
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) throw new Error('Missing Authorization header')

    const token = authHeader.replace('Bearer ', '')
    const payload = JSON.parse(atob(token.split('.')[1]))
    const userId = payload.sub

    if (!userId) {
      throw new Error('Invalid token structure')
    }

    // Create admin client to bypass RLS
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // Verify caller is admin or organization
    const { data: profile } = await supabaseAdmin
      .from('profiles')
      .select('role, organization_id')
      .eq('id', userId)
      .single()

    if (!profile || (profile.role !== 'admin' && profile.role !== 'organization')) {
      throw new Error('Forbidden: Only admins and organizations can manage users')
    }

    const { action, users } = await req.json()

    if (action === 'bulk_create') {
      const results = []
      
      for (const u of users) {
        try {
          // If caller is an organization, force the new user's organization_id to theirs
          const orgId = profile.role === 'organization' ? userId : (u.organization_id || null)

          // 1. Create auth user
          const { data: authData, error: authError } = await supabaseAdmin.auth.admin.createUser({
            email: u.email,
            password: u.password || 'oracle2025',
            email_confirm: true,
          })

          if (authError) throw authError

          // 2. Create profile
          const { error: profileError } = await supabaseAdmin
            .from('profiles')
            .insert({
              id: authData.user.id,
              full_name: u.full_name,
              email: u.email,
              phone: u.phone,
              role: u.role || 'student',
              organization_id: orgId
            })

          if (profileError) {
             // Rollback auth user creation if profile fails
             await supabaseAdmin.auth.admin.deleteUser(authData.user.id)
             throw profileError
          }

          // 3. If student, create student record
          if (u.role === 'student' && u.roll_number && u.grade) {
            const { error: studentError } = await supabaseAdmin
              .from('students')
              .insert({
                profile_id: authData.user.id,
                roll_number: u.roll_number,
                grade: u.grade,
                section: u.section
              })
              
            if (studentError) console.error("Failed to create student record:", studentError)
          }

          results.push({ email: u.email, success: true })
        } catch (e) {
          results.push({ email: u.email, success: false, error: e.message })
        }
      }

      return new Response(JSON.stringify({ results }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      })
    }

    return new Response(JSON.stringify({ error: 'Invalid action' }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 400,
    })

  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 400,
    })
  }
})
