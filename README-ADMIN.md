# Painel administrativo Raulzito Kite

- Acesse `/admin.html`.
- No projeto Supabase Meniuza, crie o usuário do Raul em Authentication > Users.
- Copie o UUID do usuário.
- Execute `supabase-raul-kite.sql` no SQL Editor.
- Preencha `admin-config.js` com Project URL, chave publicável (anon/publishable) e UUID do Raul.
- Não use `service_role`/secret key no navegador.
- Publique a pasta inteira na Vercel.
- O painel usa autenticação Supabase e RLS; somente o UUID configurado entra no painel.


## Atualização PWA e calendário (31/10/2026)
- O painel agora oferece calendário mensal, semanal e diário, horários, busca de alunos e gestão de status.
- O manifest e service worker armazenam somente o shell estático; chamadas do Supabase/Auth/REST não são cacheadas.
- A migração incremental adiciona dados opcionais de pagamento, local e segurança e uma restrição de exclusão no banco para impedir sobreposição de aulas do mesmo instrutor, considerando a duração.
- O botão Área do Instrutor foi removido do menu público; o painel continua acessível diretamente por `/admin.html`.
- Para iPhone: Safari > Compartilhar > Adicionar à Tela de Início. Em Android, use a opção Instalar app quando o navegador oferecer.
