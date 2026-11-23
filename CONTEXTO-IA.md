# Regras para IA — oficina Inji local

> Use este arquivo como instruções operacionais para agentes que alterem **este kit**.
> O [README.md](README.md) é o roteiro para participantes humanos. Verifique o
> Compose, o código dos apps e os logs antes de afirmar que um fluxo funciona.

## Escopo e fatos conhecidos

- Produto: login mock com eSignet Java 1.8.0 → Mimoto 0.22.0 (código/PKCE →
  token) → Certify 0.14.0 (OpenID4VCI) → Guarda → Breja.me → Verify 0.18.2
  (OpenID4VP). `FarmerCredential` e `ECACredential` são `ldp_vc`; o Breja.me
  solicita `ECACredential` para conferir `isOver18`.
- O Compose sobe infraestrutura e a **API** Verify, mas não sobe a UI Verify,
  o Guarda nem o Breja.me. Os apps rodam separadamente no emulador Android.
  O fluxo de emissão ECA e verificação de maioridade com Guarda/Breja.me foi
  exercitado localmente; não extrapolar isso para outros ambientes, dispositivos
  físicos, novas credenciais ou interoperabilidade pública.
- Usa apenas IDs inventados e PIN/OTP mock. Não há Gov.br, CPF real, API ECA
  real ou confiança de produção. Portas de app usam HTTP; JSON-LD exige
  contextos HTTPS externos. **Não apresentar esta instalação como segura para
  produção ou aberta à internet.**
- `WORKSHOP_HOST` vem de `.env` (ignorado pelo Git): IPv4 alcançável pelo host,
  emulador e contêineres. A mesma origem deve aparecer nos `.env` **locais**
  do Guarda e Breja.me. Não substituir por `localhost` ou `10.0.2.2` apenas
  em um ponto: issuer OAuth, audience, redirects e `request_uri` dependem dela.

## Inventário que não deve ser confundido

| Serviço | Imagem / job | Porta host | Contrato |
|---|---|---:|---|
| `esignet-db` | `postgres:17-bookworm` | — | Bancos eSignet e Mock Identity |
| `mock-identity` | `mosipid/mock-identity-system:0.13.0` | 31082 | Identidades fictícias |
| `esignet` | `mosipid/esignet-with-plugins:1.8.0` | — | OAuth2/OIDC Java + plugin mock |
| `esignet-public` | `nginx:stable` | 31080 | Issuer, token e autorização |
| `esignet-ui` | `mosipid/oidc-ui:1.8.0` | 31000 | Login mock |
| `redis` | `redis:6.0` | — | Cache/sessões eSignet |
| `certify-db` | `postgres:15` | — | Bancos `inji_certify`, `inji_mimoto`, `inji_verify` |
| `certify` | `injistack/inji-certify-with-plugins:0.14.0` | 31090 | Emite VCs com plugin CSV |
| `certify-nginx` | `nginx:stable` | 31091 | HTTP para Mimoto e HTTPS 443 interno para DID |
| `mimoto` | `injistack/mimoto:0.22.0` | 31099 | Catálogo e troca de token da wallet |
| `verify-db-setup` | `postgres:15` | — | Prepara `inji_verify` sem recriar outros bancos |
| `verify` | `injistack/inji-verify-service:0.18.2` | 31180 | API de VP request/submissão/resultado |

`extract-client`, `setup-client` e `verify-db-setup` são jobs do `up -d` e
devem terminar com código 0. `sync-identities` e `sync-credentials` pertencem
ao profile `maintenance`; não são executados na subida comum.

## Regras de alteração e segurança

1. **Antes de editar:** leia o README, `docker-compose.yaml` e os arquivos
   envolvidos. Rode `docker compose config --quiet` e `docker compose ps -a`.
   Em erro de fluxo, localize a etapa: token → prova/nonce → VC → DID/JSON-LD →
   VP → resultado. Health 200 ou `VP_SUBMITTED` não provam verificação válida.
2. **Preserve os volumes.** Bancos e keystores persistem em volumes Docker.
   `workshop-did-tls` contém o certificado/chave TLS local do DID. Não rode
   `down -v`, não exclua chaves isoladamente do banco de aliases e não recrie
   o ambiente do participante para aplicar uma alteração pequena. `down` sem
   `-v` preserva dados e não reaplica scripts de inicialização.
3. **Não contorne criptografia.** Nunca aceite VC/VP sem assinatura, desabilite
   TLS, substitua contextos JSON-LD canônicos por mocks ou use a chave privada
   do eSignet como chave do holder. Em redes com interceptação HTTPS, importar
   somente a CA pública confiável de cada operador em `local-ca/`; Certify e
   Verify a carregam na JVM. Arquivos locais dessa pasta são ignorados pelo Git.
4. **Não vaze dados.** Use só IDs fictícios, nunca CPF real. Não imprima token,
   proof JWT, c_nonce, PIN, chave privada, VC ou VP completas nos logs/testes.
   Não adicione segredos em variáveis `EXPO_PUBLIC_` (são embutidas no app).
   `.env` do kit e dos apps deve continuar fora do Git.
5. **Não mude de versão sem ensaio.** A combinação testada usa eSignet Java,
   não o eSignet Go 2.0.0 (este rejeitou a assertion `private_key_jwt` sem
   `kid` do Mimoto). Mimoto usa imagem oficial, não build/JAR customizado.
   Não altere o SDK do SCM como efeito colateral de ajustes neste kit.
6. **Ao criar dados:** revise SQL/CSV antes de rodar jobs. `ON CONFLICT DO
   NOTHING` evita duplicatas, mas não atualiza linhas. Script de
   `docker-entrypoint-initdb.d` só roda com volume vazio; `sql/verify_init.sql`
   roda no job `verify-db-setup` no banco `inji_verify` e não é migração.

## Contratos de identidade, credenciais e verificação

- `sql/mock-identities.sql` e `config/workshop_identity_data.csv` compartilham
  o mesmo `id` fictício. `sync-identities` reaplica o seed reconhecido sem
  validar completamente SQL/CSV; recrie **somente** o Certify ao mudar o CSV.
- Para novos tipos, crie `sql/credentials/<tipo>.sql` a partir de
  `sql/eca-demo.sql`; o job `sync-credentials` é manual inclusive na primeira
  subida. Manter o scope `mock_identity_vc_ldp` sem mexer isoladamente na
  audiência do eSignet. Template, contextos, `data-columns`, CSV e pedido da
  wallet devem concordar.
- Certify CSV 0.14.0 procura `claims["sub"]` na coluna `id`. O mock usa
  `MOSIP_MOCK_IDA_KYC_PSUT_FIELD=individualId` para devolver o ID em vez do
  PSUT pairwise; isso reduz privacidade e é **exclusivo deste laboratório**.
- `FarmerCredential` e `ECACredential` anunciam `EdDSA` na proof JWT; ambas
  consultam `config/workshop_identity_data.csv`. A chave da wallet assina
  a proof; o Certify assina a VC com sua própria chave.
- VCs **novas** usam `did:web:certify-nginx`. O Nginx serve
  `https://certify-nginx/.well-known/did.json` na rede Docker, com certificado
  TLS de `workshop-did-tls` importado na JVM do Verify. O DID não é público;
  VCs antigas que referenciam DID ngrok exigem reemissão, nunca reescrita da
  assinatura. Não confundir o DID do emissor com o DID/`client_id` do Verify.
- O Verify usa `sql/verify_init.sql` compatível com a imagem 0.18.2.
  `INJI_VP_SUBMISSION_BASE_URL` e DID do verificador estão no Compose; o
  Breja.me usa `EXPO_PUBLIC_BASE_URL=http://<IP>:31180` e
  `EXPO_PUBLIC_CLIENT_ID=did:web:<IP>%3A31180:v1:verify`. O backend não sobe
  UI, proxy HTTPS público nem o app Breja.me.
- O access token pode estar válido após vencer `c_nonce`. O Certify devolve
  `400 invalid_proof` com nonce novo (40 s); isso **não** indica expiração do
  login. O SDK 1.0.11 não repete sozinho. No branch `workshop` do Guarda,
  `src/workshopFetch.js` faz **um** retry na emissão local, reutilizando a
  mesma chave da proof JWT. Na apresentação, Guarda usa a VC armazenada e
  não deve disparar novo download/destruição das credenciais.

## Critérios de validação e limites

- Após mudança de Compose/config: `docker compose config --quiet`, `ps -a`,
  health do eSignet/Certify/Verify e DID retornando `did:web:certify-nginx`.
  Validar certificado HTTPS do DID **com verificação TLS**, não com `-k`.
- Após mudança de emissão: conferir catálogo, token/escopo de teste, VC
  recebida pelo Guarda e `isOver18` esperado com identidade fictícia.
- Após mudança de verificação: submeter uma VP real a partir do Guarda,
  consultar o resultado no Breja.me e confirmar `SUCCESS` **e** o desfecho
  adulto/menor; não concluir a partir de logs de submissão. Testes em
  dispositivo físico e verificação fora da rede Docker não estão validados.
- Se a alteração exigir um endpoint público, credenciais reais, mudança de
  issuer ou segurança de produção, explicitar a limitação e pedir o contexto
  necessário; não inventar host/túnel nem inserir fallback inseguro.