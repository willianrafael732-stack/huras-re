# Mesa Hurras Fantasy

Acesse `/mesa/`. E-mail e senha são gerenciados pelo Supabase Auth; nenhuma senha é armazenada pelo site. O projeto Supabase usa tabelas `hf_`, sem modificar as tabelas do quiz.

- O criador da sala é Mestre/ADM; convidados são jogadores. Essa função é determinada pelo banco, não por dados editáveis do usuário.
- Convites aleatórios de 12 caracteres (72 bits), hash SHA-256 no banco, validade de 7 dias e renovação pelo mestre. O jogador tem no máximo oito tentativas por minuto.
- Mensagens persistentes, consulta a cada três segundos, paginação, PDF aberto, imagens, arquivos de áudio e microfone (até cinco minutos). Anexos privados até 20 MB, com links temporários de uma hora.
- `/roll 5d10` registra uma rolagem calculada no servidor, sem aceitar resultados enviados pelo cliente.
- 6–9: +1; 2–4: −1; 5: 0; 10: +2; 1: −2. Cada par 1/10 é anulado. A pontuação pode ser negativa.
- Mestre remove/reabilita jogadores e apaga mensagens da mesa; jogador apaga as próprias mensagens.

A estrutura do banco está em `database/hurras-mesa.sql` e já foi aplicada. A biblioteca Supabase JS 2.57.4 está incluída localmente. Para recuperação de senha e retorno da confirmação de e-mail, autorize a URL pública da instalação na lista de redirecionamentos do Supabase Auth. Login de contas já confirmadas não depende do redirecionamento.

Validação local: `node tests/d10.cjs`. Login, microfone e aparência devem ser verificados no navegador da publicação. A página funciona como HTML estático no Netlify. Autenticação necessária apenas para as mesas; consulta às fichas continua livre.

## Portal inspirado na referência Dark Fantasy

A página inicial agora reúne personagens, fichas, deuses, mesa, guia e livro. O conteúdo vem do repositório Hurras/Nexalis. A pesquisa usa 174 entradas e o leitor reúne 12 capítulos do sistema original.

O cofre unificado exporta/importa backup, lê fichas clássicas do IndexedDB e Dark/animal do navegador, salva cópias online e compartilha com o mestre. Abrir uma ficha online cria uma cópia local. O mestre só pode atualizar vida/mana de fichas explicitamente compartilhadas; o nível limita os recursos.

A mesa tem abas de conversa, dados, fichas e participantes; enquetes de voto único, emojis, preferências pessoais de cor e conversas privadas entre membros que já dividem uma mesa. Conversas privadas não permitem convites. As tabelas e funções adicionais estão em `database/hurras-portal-social.sql`.

## Ficha única, acesso e personalização

O portal apresenta a ficha Hurras e seus companheiros. Os editores independentes Dark foram removidos; URLs antigas encaminham ao editor Hurras. Dados antigos não são apagados. A ficha Hurras recebeu bolinhas coloridas, navegação por teclado e backup JSON.

`portal/auth-client.js` centraliza a sessão e aguarda o retorno de autenticação antes de mudar a rota. Suporta cadastro, reenvio de confirmação, link de acesso e confirmação por código. O template de e-mail precisa incluir `{{ .Token }}` para a confirmação por código. O botão Google consulta o estado real do provedor e só inicia OAuth quando ativo. O retorno Google solicita verificação adicional por e-mail.

Dependências externas pendentes: ativar Google no Supabase com cliente OAuth, autorizar a URL pública nos redirecionamentos e configurar SMTP próprio para evitar o limite de envio padrão. Segredos OAuth/SMTP não são incluídos no cliente.

Personalização local de cores, fontes, espaçamento, imagens, textos, menus, chat e ficha. O Mestre do site pode aplicar a aparência para todos. A ativação exige conta com e-mail confirmado e código aleatório de uso único, protegido por hash no schema privado. Esse acesso não abre conversas privadas de outros usuários.

`portal/teste-mestre.html` é uma simulação local de conversa, dados, fichas e controles de mestre, sem credenciais compartilhadas ou mensagens reais.

## Sessão e voz ao vivo — arsenal v2

- `/mesa/` concentra login, criação/entrada por código ou link, estado da sessão, chamada de voz, conversa, dados, fichas e participantes.
- O mestre inicia, pausa, retoma e encerra a sessão; a autorização é verificada no banco. Convites continuam com expiração de sete dias e podem ser renovados.
- O jogador salva sua ficha online e usa **Fichas da mesa → Adicionar minha ficha à mesa**. O mestre pode ler e ajustar vida/mana das fichas compartilhadas, sem assumir sua propriedade.
- **Dados → Dano da arma após acerto** lê a ficha online e as regras do servidor, separando dados da arma, bônus da arma, material e minério. Condições de noite/alvo são explicitadas no registro. Resistências e habilidades especiais seguem resolução manual; não há desconto automático de Mana por técnicas.
- O arsenal v2 reduz os picos: armas leves comuns usam 1d10, duas mãos comuns 2d10, bônus explícito de dano fica limitado a +2 e armas lendárias chegam a 4d10. Simulação de referência com 50 PV sem defesa: espada 8,20 acertos; montante 4,36; marreta lendária 2,80. Isso é calibração numérica, não substitui teste de mesa.
- A voz usa WebRTC de áudio e sinalização autenticada com RLS (`hf_voice_presence`, `hf_voice_signals`). Microfone somente por clique, com silenciar/sair; sair da conta, trocar de mesa, perder acesso ou encerrar a sessão interrompe o áudio. A presença expira após 45 segundos sem atualização. SDP/ICE temporários não são gravações de voz.
- Até oito presenças simultâneas são previstas. STUN público da Cloudflare; sem TURN configurado, certas redes móveis/corporativas podem impedir conexão. `window.HurrasVoiceIceServers` pode receber servidores TURN com credenciais temporárias fornecidas por backend próprio. Nunca inclua segredo TURN permanente no cliente. Arquivos de áudio continuam disponíveis como alternativa.
- Migração aplicada: `database/hurras-play-session.sql`; regras do servidor em `database/hurras-arsenal-seed.sql`. As tabelas do quiz não são alteradas.
- Verificado: permissões mestre/jogador/terceiro, convite, sinalização privada e dano no banco em transação com rollback; rascunho de arma/material/minério reaberto no navegador. Voz entre dois dispositivos e login real completo não foram testados nesta execução.

## Cofre exclusivo e consulta simples do bestiário

A política `hf_sheets_read` retorna somente registros de `owner_id = auth.uid()`, inclusive para quem é mestre em outra mesa. O mestre consulta fichas explicitamente autorizadas somente por `hf_room_sheets(room_id)`, dentro da mesa; os outros jogadores não leem a ficha nem a lista de autorizações de terceiros. Login Google e login por e-mail usam o identificador autenticado do Supabase. Não há migração automática de fichas de visitante para outra conta. Teste reproduzível: `tests/private-vault-rollback.sql`, que termina em rollback.

O bestiário principal lê as 123 fichas de `funcoes/dados/bestiario-original.txt`: vida/mana e até duas técnicas em destaque; atributos, resistências e texto integral permanecem disponíveis. Não são inferidos valores de dano quando o texto original não os informa. Os números foram conferidos com o teste `tests/bestiary-original.cjs` e pela busca de Albatroz Colossal no navegador.
