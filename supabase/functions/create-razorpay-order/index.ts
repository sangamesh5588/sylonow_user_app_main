import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

function getBasicAuthHeader() {
  const keyId = Deno.env.get('RAZORPAY_KEY_ID');
  const keySecret = Deno.env.get('RAZORPAY_KEY_SECRET');

  if (!keyId || !keySecret) {
    throw new Error('Missing Razorpay credentials in function secrets');
  }

  const credentials = btoa(`${keyId}:${keySecret}`);
  return `Basic ${credentials}`;
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { status: 200, headers: corsHeaders });
  }

  if (req.method !== 'POST') {
    return new Response(JSON.stringify({ error: 'Method not allowed' }), {
      status: 405,
      headers: { 'Content-Type': 'application/json', ...corsHeaders },
    });
  }

  try {
    const body = await req.json();
    const amount = Number(body?.amount);
    const currency = (body?.currency ?? 'INR').toString();
    const receipt = (body?.receipt ?? '').toString();
    const notes = body?.notes ?? {};

    if (!Number.isFinite(amount) || amount <= 0) {
      return new Response(JSON.stringify({ error: 'Invalid amount' }), {
        status: 400,
        headers: { 'Content-Type': 'application/json', ...corsHeaders },
      });
    }

    if (!receipt) {
      return new Response(JSON.stringify({ error: 'Receipt is required' }), {
        status: 400,
        headers: { 'Content-Type': 'application/json', ...corsHeaders },
      });
    }

    const razorpayResponse = await fetch('https://api.razorpay.com/v1/orders', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: getBasicAuthHeader(),
      },
      body: JSON.stringify({
        amount: Math.round(amount),
        currency,
        receipt,
        notes,
      }),
    });

    const razorpayData = await razorpayResponse.json();

    if (!razorpayResponse.ok) {
      return new Response(
        JSON.stringify({
          error: 'Razorpay order creation failed',
          details: razorpayData,
        }),
        {
          status: razorpayResponse.status,
          headers: { 'Content-Type': 'application/json', ...corsHeaders },
        },
      );
    }

    return new Response(JSON.stringify(razorpayData), {
      status: 200,
      headers: { 'Content-Type': 'application/json', ...corsHeaders },
    });
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error instanceof Error ? error.message : 'Unexpected error' }),
      {
        status: 500,
        headers: { 'Content-Type': 'application/json', ...corsHeaders },
      },
    );
  }
});
