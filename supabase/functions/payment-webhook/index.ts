// Supabase Edge Function: payment-webhook/index.ts
// Handles incoming payment gateway webhooks AND the hackathon mock-confirm endpoint

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { crypto } from "https://deno.land/std@0.168.0/crypto/mod.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
  );

  const url = new URL(req.url);

  // ── MOCK CONFIRM endpoint (hackathon demo only) ──────────────────────────
  // POST /payment-webhook/mock-confirm  { transaction_id, status: "SUCCESS"|"FAILED" }
  if (url.pathname.endsWith("/mock-confirm")) {
    const { transaction_id, status } = await req.json();

    const { data, error } = await supabase
      .from("transactions")
      .update({
        payment_status: status,
        reference_number: `MOCK-UTR-${Date.now()}`,
        verified_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      })
      .eq("id", transaction_id)
      .select()
      .single();

    if (error) {
      return new Response(JSON.stringify({ error: error.message }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // The DB trigger (trg_recalculate_after_transaction) automatically
    // calls recalculate_allocation_status(), which updates the allocation.
    // Supabase Realtime will broadcast the change to all subscribed Flutter clients.

    return new Response(JSON.stringify({ success: true, transaction: data }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  // ── PRODUCTION GATEWAY WEBHOOK ────────────────────────────────────────────
  // Verify HMAC signature from the gateway
  const gatewaySecret = Deno.env.get("GATEWAY_WEBHOOK_SECRET");
  const signature = req.headers.get("x-razorpay-signature") ?? req.headers.get("x-webhook-signature");
  const body = await req.text();

  if (gatewaySecret && signature) {
    const key = await crypto.subtle.importKey(
      "raw",
      new TextEncoder().encode(gatewaySecret),
      { name: "HMAC", hash: "SHA-256" },
      false,
      ["sign"]
    );
    const mac = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(body));
    const expectedSig = Array.from(new Uint8Array(mac))
      .map((b) => b.toString(16).padStart(2, "0"))
      .join("");

    if (expectedSig !== signature) {
      return new Response("Unauthorized", { status: 401 });
    }
  }

  const payload = JSON.parse(body);

  // Normalize across gateway formats (Razorpay / Cashfree)
  const orderId = payload?.payload?.payment?.entity?.order_id ?? payload?.order_id;
  const paymentStatus = (payload?.event === "payment.captured" || payload?.txStatus === "SUCCESS")
    ? "SUCCESS" : "FAILED";
  const utrNumber = payload?.payload?.payment?.entity?.id ?? payload?.referenceId ?? `GW-${Date.now()}`;

  if (!orderId) {
    return new Response(JSON.stringify({ error: "Unknown gateway payload format" }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const { error } = await supabase
    .from("transactions")
    .update({
      payment_status: paymentStatus,
      reference_number: utrNumber,
      gateway_response: payload,
      verified_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    })
    .eq("gateway_order_id", orderId);

  if (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  return new Response(JSON.stringify({ received: true }), {
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
});
