# Área do Aluno — Raulzito Kite

## Rotas
- Site público: `/`
- Área do aluno: `/aluno` (rewrite da Vercel para `aluno.html`)
- Painel do instrutor: `/admin.html`
- Gestão de alunos, evolução, vendas e conteúdo: `/admin-alunos.html`

## Autenticação
A Área do Aluno usa Supabase Auth com e-mail e senha. O cadastro envia `account_type=raul_kite_student` em metadados e um trigger de banco cria ou vincula o perfil em `raul_kite_students`. Se a confirmação de e-mail estiver habilitada no Supabase, o aluno confirma o e-mail antes do primeiro login.

O painel do instrutor reutiliza a sessão do Supabase e valida o e-mail permitido em `admin-config.js`. A chave no navegador é publishable/anon; nunca colocar `service_role` no frontend.

## Banco
A migração incremental está em `supabase-area-aluno.sql` e foi aplicada no projeto Supabase Meniuza usado pelo painel atual. Ela reaproveita `raul_kite_students` e `raul_kite_lessons` e cria:
- `raul_kite_lesson_types`
- `raul_kite_lesson_packages`
- `raul_kite_student_purchases`
- `raul_kite_student_credits`
- `raul_kite_student_progress`
- `raul_kite_student_tips`

As políticas RLS isolam perfil, aulas, compras, créditos, evolução e dicas. Os créditos não são graváveis pelo navegador. Um trigger libera créditos apenas quando o instrutor marca a compra como confirmada e o pagamento como confirmado. Outro trigger debita um crédito quando uma aula com saldo disponível passa para concluída.

O RPC `raul_kite_available_slots(date, integer)` retorna somente horários livres, sem nomes ou dados de outros alunos. A reserva é inserida em `raul_kite_lessons`, a mesma tabela usada pela agenda do instrutor. Uma constraint de exclusão no banco impede sobreposição por duração, inclusive em reservas concorrentes.

## Configuração operacional
1. Em `/admin.html`, entre com o usuário do instrutor.
2. Abra **Alunos e vendas**.
3. Cadastre os tipos de aula e suas durações reais em **Tipos de aula**.
4. Cadastre os pacotes e preços reais em **Pacotes**. Nenhum preço foi pré-preenchido ou inventado.
5. Publique dicas em **Dicas**. Imagens e vídeos podem ser adicionados por URL pública direta; upload de arquivos ainda depende da criação/configuração de um bucket Storage.
6. Compartilhe `https://www.raulzitokite.com.br/aluno` com os alunos.

O número de WhatsApp da contratação está em `aluno-config.js` e foi reaproveitado de `config.js`. A solicitação de compra fica salva no banco antes de abrir o WhatsApp. O pagamento é confirmado manualmente pelo instrutor; somente então os créditos são liberados.

## PWA
A configuração PWA existente foi mantida para o instrutor. A Área do Aluno usa um manifest próprio com o mesmo ícone, tema e service worker, mas com `start_url=/aluno`, evitando que a instalação do aluno abra o painel administrativo. O service worker existente inclui os arquivos estáticos das duas áreas e não armazena respostas privadas do Supabase.

## Limitações conhecidas antes da publicação final
- Não há gateway de pagamento integrado; a confirmação é manual, com contato pelo WhatsApp.
- Mídias de dicas usam URL pública. Upload direto requer bucket Storage e políticas próprias.
- O aluno recebe confirmação dentro da área e vê o status pendente/confirmado; notificações por e-mail/WhatsApp automáticas não foram configuradas.
- Para habilitar o fluxo de cadastro, revisar em Supabase Authentication se a confirmação de e-mail deve permanecer ativa e configurar os modelos de e-mail do projeto.
