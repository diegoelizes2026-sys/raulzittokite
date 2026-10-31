# Raulzito Kite — site premium

Site estático responsivo premium para apresentar Raul e suas aulas de kitesurf na Prainha, Aquiraz, Ceará. O design foi inspirado na estrutura de sites profissionais de escolas de kite, com método de aprendizagem, opções de aulas, galeria e formulário de consulta — sem copiar textos, identidade visual, preços ou promessas de outras escolas.

## Visualizar localmente

Abra `index.html` no navegador. Para uma experiência mais próxima da hospedagem, sirva a pasta com qualquer servidor estático local.

## Publicar gratuitamente na Vercel

1. Extraia o ZIP. Os arquivos `index.html`, `styles.css`, `script.js`, `config.js`, `vercel.json` e a pasta `assets` ficam diretamente na raiz.
2. Para publicar via Git, envie o conteúdo desta pasta para a raiz do repositório e importe-o na Vercel.
3. Use framework **Other**, sem build command e diretório de saída `.`.
4. Clique em Deploy. Para Vercel Drop, envie a pasta extraída (não o ZIP fechado, se a interface não aceitar ZIP).

Também pode publicar por qualquer hospedagem estática compatível.

## Configuração obrigatória do WhatsApp

Abra `config.js` e preencha `whatsappNumber` com o número oficial do Raul em formato internacional, somente números, incluindo `55` + DDD + número. Não inclua `+`, espaços ou parênteses. Exemplo meramente ilustrativo do formato: `55DD9XXXXXXXX`.

Enquanto o número não estiver configurado, o formulário valida os campos e informa que a configuração está pendente; não inventa contato nem simula envio. O formulário abre uma mensagem pré-preenchida no WhatsApp e não confirma automaticamente uma reserva.

`instagramUrl` está reservado para configurar o perfil oficial quando o proprietário confirmar a URL. O perfil não é inventado nem apresentado como link até essa configuração.

## Conteúdo e integridade

- Fotos fornecidas pelo usuário foram otimizadas para WebP e incluídas em `assets/`.
- Não foram inventados preços, duração, títulos específicos, recordes, certificados, depoimentos, avaliações ou número de alunos.
- Conquistas reais podem ser adicionadas quando Raul fornecer competição, ano, categoria e colocação confirmados.
- A política de privacidade deve ser revisada caso sejam adicionados analytics, publicidade, armazenamento de dados ou novas integrações.

## Arquivos

- `index.html`: página principal e formulário de solicitação de aula.
- `styles.css`: identidade visual, layout responsivo e acessibilidade básica.
- `script.js`: menu mobile, seleção de aula e fluxo do formulário WhatsApp.
- `config.js`: contatos configuráveis.
- `privacidade.html`: política de privacidade inicial.
- `favicon.svg`: ícone do navegador.
- `assets/`: fotografias otimizadas.
