import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const MSG91_AUTHKEY = Deno.env.get("MSG91_AUTH_TOKEN") || Deno.env.get("MSG91_AUTHKEY") || "";

const supabaseAdmin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
  auth: { autoRefreshToken: false, persistSession: false },
});

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Content-Type": "application/json",
};

function errorResponse(message: string, status = 400) {
  return new Response(JSON.stringify({ error: message }), { status, headers: corsHeaders });
}

// ─── MSG91: Server-side verify the JWT access-token ───────────────────────
// The Flutter OTPWidget SDK handles OTP send/verify client-side.
// This function only confirms the resulting JWT is genuine before creating a session.
async function verifyAccessToken(accessToken: string): Promise<void> {
  const resp = await fetch("https://control.msg91.com/api/v5/widget/verifyAccessToken", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ authkey: MSG91_AUTHKEY, "access-token": accessToken }),
  });

  const data = await resp.json();
  console.log("msg91 verifyAccessToken response:", JSON.stringify(data));

  if (data?.type !== "success" && data?.type !== "Success") {
    throw new Error(data?.message || "MSG91 access-token invalid");
  }
}

// ─── Find or create Supabase user by phone ────────────────────────────────
async function findOrCreateUser(normalizedPhone: string): Promise<string> {
  const cleanPhone = normalizedPhone.replace(/\D/g, "");

  // Paginated search
  const findUserPaginating = async (): Promise<string | null> => {
    let page = 1;
    const perPage = 1000;

    while (true) {
      const { data: listData, error: listErr } = await supabaseAdmin.auth.admin.listUsers({
        page,
        perPage,
      });

      if (listErr) {
        console.error("listUsers error on page", page, listErr);
        break;
      }

      const users = listData.users;
      if (!users || users.length === 0) break;

      const found = users.find((u: { id: string; phone?: string | null }) => {
        if (!u.phone) return false;
        const uClean = u.phone.replace(/\D/g, "");
        return uClean === cleanPhone || uClean.endsWith(cleanPhone) || cleanPhone.endsWith(uClean);
      });

      if (found) return found.id;
      if (users.length < perPage) break;
      page++;
    }
    return null;
  };

  let userId = await findUserPaginating();

  if (userId) {
    console.log("msg91-auth: Found existing user", userId);
    return userId;
  }

  // Create new user
  const { data: createData, error: createErr } = await supabaseAdmin.auth.admin.createUser({
    phone: normalizedPhone,
    phone_confirm: true,
    user_metadata: { app_type: "customer" },
  });

  if (createErr) {
    if (createErr.status === 422 || createErr.message?.includes("already registered")) {
      // Race condition — try one more time
      userId = await findUserPaginating();
    } else {
      throw createErr;
    }
  } else {
    userId = createData.user.id;
    console.log("msg91-auth: Created new user", userId);
  }

  if (!userId) throw new Error("Could not identify User ID after exhaustive search.");
  return userId;
}

// ─── Create a Supabase session for a given userId ─────────────────────────
async function createSession(userId: string, normalizedPhone: string) {
  const tempPassword = crypto.randomUUID();

  await supabaseAdmin.auth.admin.updateUserById(userId, { password: tempPassword });

  const { data: signInData, error: signInError } = await supabaseAdmin.auth.signInWithPassword({
    phone: normalizedPhone,
    password: tempPassword,
  });

  if (signInError || !signInData.session) {
    throw new Error("Failed to create session: " + (signInError?.message || "unknown error"));
  }

  return signInData.session;
}

// ─── Sync user_profiles (customer app only) ───────────────────────────────
async function syncUserProfile(userId: string, normalizedPhone: string) {
  await supabaseAdmin.from("user_profiles").upsert(
    { auth_user_id: userId, app_type: "customer", phone_number: normalizedPhone },
    { onConflict: "auth_user_id" }
  );
}

// ─── Main handler ─────────────────────────────────────────────────────────
// Expected body: { msg91_access_token: string, phone: string }
// The Flutter OTPWidget SDK verified OTP client-side and produced the access-token.
// This function validates that token server-side, then creates a Supabase session.
Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders, status: 204 });
  }

  try {
    const body = await req.json();
    const { msg91_access_token, phone } = body;

    if (!msg91_access_token || !phone) {
      return errorResponse("Missing msg91_access_token or phone");
    }

    // 1. Server-side verify the JWT returned by the Flutter OTP Widget SDK
    await verifyAccessToken(msg91_access_token);

    // 2. Find or create Supabase user
    const normalizedPhone = phone.startsWith("+") ? phone : `+${phone}`;
    const userId = await findOrCreateUser(normalizedPhone);

    // 3. Create Supabase session
    const session = await createSession(userId, normalizedPhone);

    // 4. Sync user_profiles
    await syncUserProfile(userId, normalizedPhone);

    return new Response(
      JSON.stringify({
        refresh_token: session.refresh_token,
        user: { id: userId, phone: normalizedPhone },
      }),
      { status: 200, headers: corsHeaders }
    );
  } catch (err) {
    console.error("msg91-auth: FATAL", err);
    return new Response(
      JSON.stringify({ error: "Auth failed", details: String(err) }),
      { status: 500, headers: corsHeaders }
    );
  }
});
