// @ts-nocheck
// Supabase Edge Function: initiate-upi/index.ts
// Generates a UPI payment intent and creates a PENDING transaction

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    const { allocation_id, amount, student_name } = await req.json();

    if (!allocation_id || !amount) {
      return new Response(
        JSON.stringify({ error: "allocation_id and amount are required" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Generate a unique order ID
    const orderId = `ORACLE-${Date.now()}-${Math.random().toString(36).substring(2, 8).toUpperCase()}`;

    // ── MOCK UPI FLOW (replace with real gateway call in production) ──────────
    // In production, call Razorpay/Cashfree here to create a payment order.
    // For the hackathon demo, we generate a realistic UPI deep-link.
    const upiVpa = Deno.env.get("MERCHANT_UPI_VPA") ?? "oracle-school@upi";
    const merchantName = encodeURIComponent("ORACLE School Fees");
    const transactionNote = encodeURIComponent(`Fee Payment - ${orderId}`);
    const upiIntent = `upi://pay?pa=${upiVpa}&pn=${merchantName}&am=${amount}&tn=${transactionNote}&tr=${orderId}&cu=INR`;
    // ─────────────────────────────────────────────────────────────────────────

    // Create the PENDING transaction in the ledger
    const { data: transaction, error: txError } = await supabase
      .from("transactions")
      .insert({
        allocation_id,
        amount_paid: amount,
        payment_method: "UPI",
        payment_status: "PENDING",
        gateway_order_id: orderId,
        notes: `UPI initiated for ${student_name ?? "student"}`,
      })
      .select()
      .single();

    if (txError) throw txError;

    return new Response(
      JSON.stringify({
        success: true,
        transaction_id: transaction.id,
        order_id: orderId,
        upi_intent: upiIntent,
        // Deep links for popular UPI apps
        gpay_intent: upiIntent.replace("upi://", "gpay://"),
        phonepe_intent: `phonepe://pay?${upiIntent.split("?")[1]}`,
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : String(error);
    return new Response(
      JSON.stringify({ error: message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
