import { createClient } from "npm:@supabase/supabase-js@2";

const ADMIN_ID = "0c997ebb-4ac2-4879-9b70-ae410581dea8";
const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Content-Type": "application/json",
};

function reply(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: cors });
}
function cleanEmail(value: unknown) {
  return String(value ?? "").trim().toLowerCase();
}
function cleanText(value: unknown) {
  return String(value ?? "").trim();
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return reply({ error: "Método não permitido." }, 405);

  try {
    const url = Deno.env.get("SUPABASE_URL") ?? "";
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? Deno.env.get("SUPABASE_PUBLISHABLE_KEY") ?? "";
    const secretKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? Deno.env.get("SUPABASE_SECRET_KEY") ?? "";
    if (!url || !anonKey || !secretKey) {
      return reply({ error: "Configuração segura do Supabase incompleta. Verifique as variáveis da Edge Function." }, 500);
    }

    const authHeader = req.headers.get("Authorization") ?? "";
    const token = authHeader.replace(/^Bearer\s+/i, "");
    if (!token) return reply({ error: "Faça login como administrador para continuar." }, 401);

    const callerClient = createClient(url, anonKey, {
      auth: { persistSession: false, autoRefreshToken: false },
      global: { headers: { Authorization: `Bearer ${token}` } },
    });
    const { data: callerData, error: callerError } = await callerClient.auth.getUser(token);
    const caller = callerData?.user;
    if (callerError || !caller || caller.id !== ADMIN_ID || caller.app_metadata?.role !== "admin") {
      return reply({ error: "Somente o administrador pode gerenciar instrutores." }, 403);
    }

    const admin = createClient(url, secretKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const body = await req.json();
    const action = cleanText(body.action);
    const id = cleanText(body.id);

    if (action === "create") {
      const full_name = cleanText(body.full_name);
      const phone = cleanText(body.phone);
      const email = cleanEmail(body.email);
      const password = String(body.password ?? "");
      if (!full_name || !phone || !email || !password) return reply({ error: "Preencha nome, telefone, e-mail e senha." }, 400);
      if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) return reply({ error: "Informe um e-mail válido." }, 400);
      if (password.length < 8) return reply({ error: "A senha precisa ter pelo menos 8 caracteres." }, 400);

      const { data: duplicate } = await admin.from("raul_kite_instructors").select("id").ilike("email", email).maybeSingle();
      if (duplicate) return reply({ error: "Já existe um instrutor cadastrado com esse e-mail." }, 409);

      const { data: created, error: createError } = await admin.auth.admin.createUser({
        email,
        password,
        email_confirm: true,
        user_metadata: { full_name },
        app_metadata: { role: "instructor", owner_id: ADMIN_ID },
      });
      if (createError || !created.user) {
        const message = createError?.message?.toLowerCase().includes("already")
          ? "Este e-mail já está cadastrado no sistema."
          : "Não foi possível criar a conta de acesso. Verifique o e-mail e tente novamente.";
        return reply({ error: message }, 400);
      }

      const { data: row, error: insertError } = await admin.from("raul_kite_instructors").insert({
        owner_id: ADMIN_ID,
        auth_user_id: created.user.id,
        full_name,
        phone,
        email,
        is_active: true,
      }).select("id,auth_user_id,full_name,phone,email,is_active,created_at").single();

      if (insertError) {
        await admin.auth.admin.deleteUser(created.user.id);
        return reply({ error: insertError.code === "23505" ? "Já existe um instrutor com esse e-mail." : "A conta foi criada, mas não foi possível salvar o cadastro. Tente novamente." }, 400);
      }
      return reply({ instructor: row });
    }

    if (!id) return reply({ error: "Identificador do instrutor não informado." }, 400);
    const { data: current, error: lookupError } = await admin.from("raul_kite_instructors")
      .select("id,auth_user_id,full_name,phone,email,is_active")
      .eq("id", id).eq("owner_id", ADMIN_ID).maybeSingle();
    if (lookupError || !current) return reply({ error: "Instrutor não encontrado." }, 404);

    if (action === "update") {
      const full_name = cleanText(body.full_name);
      const phone = cleanText(body.phone);
      const email = cleanEmail(body.email);
      const password = String(body.password ?? "");
      if (!full_name || !phone || !email) return reply({ error: "Nome, telefone e e-mail são obrigatórios." }, 400);
      if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) return reply({ error: "Informe um e-mail válido." }, 400);
      if (password && password.length < 8) return reply({ error: "A nova senha precisa ter pelo menos 8 caracteres." }, 400);
      const { data: duplicate } = await admin.from("raul_kite_instructors").select("id").ilike("email", email).neq("id", id).maybeSingle();
      if (duplicate) return reply({ error: "Outro instrutor já utiliza esse e-mail." }, 409);

      const authUpdate: Record<string, unknown> = { email, email_confirm: true, user_metadata: { full_name } };
      if (password) authUpdate.password = password;
      const { error: authUpdateError } = await admin.auth.admin.updateUserById(current.auth_user_id, authUpdate);
      if (authUpdateError) return reply({ error: "Não foi possível atualizar a conta de acesso. " + authUpdateError.message }, 400);

      const { data: row, error: updateError } = await admin.from("raul_kite_instructors")
        .update({ full_name, phone, email, updated_at: new Date().toISOString() })
        .eq("id", id).select("id,auth_user_id,full_name,phone,email,is_active,created_at").single();
      if (updateError) return reply({ error: "Não foi possível atualizar o cadastro do instrutor." }, 400);
      return reply({ instructor: row });
    }

    if (action === "set_active") {
      const is_active = body.is_active === true;
      const { error: authError } = await admin.auth.admin.updateUserById(current.auth_user_id, {
        ban_duration: is_active ? "none" : "876000h",
      });
      if (authError) return reply({ error: "Não foi possível alterar o acesso da conta." }, 400);
      const { data: row, error } = await admin.from("raul_kite_instructors")
        .update({ is_active, updated_at: new Date().toISOString() })
        .eq("id", id).select("id,auth_user_id,full_name,phone,email,is_active,created_at").single();
      if (error) return reply({ error: "Não foi possível atualizar o status do instrutor." }, 400);
      return reply({ instructor: row });
    }

    if (action === "delete") {
      const { error } = await admin.auth.admin.deleteUser(current.auth_user_id);
      if (error) return reply({ error: "Não foi possível excluir a conta do instrutor." }, 400);
      return reply({ success: true, id });
    }

    return reply({ error: "Ação não reconhecida." }, 400);
  } catch (_error) {
    return reply({ error: "Ocorreu um erro inesperado. Tente novamente." }, 500);
  }
});
