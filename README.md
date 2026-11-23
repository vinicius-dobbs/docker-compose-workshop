# Oficina Inji — emissão e verificação local de credenciais

Esta oficina demonstra, com **identidades fictícias**, o login no eSignet, a emissão de
`ECACredential` e `FarmerCredential` no Certify, a guarda da VC no app Guarda e a
verificação de maioridade pelo Breja.me com o backend Inji Verify. O Compose sobe a
infraestrutura e o **backend** do Verify; Guarda e Breja.me são apps separados.

**Somente laboratório em rede controlada.** Os endpoints dos apps usam HTTP, o login
mock usa credenciais compartilhadas e o identificador de teste substitui o CPF.
Não exponha as portas, não use dados de pessoas reais e não trate o DID local como
identificador publicamente verificável.

## Antes de começar

- Docker com Compose e cerca de 8 GB de RAM disponíveis; portas `31000`, `31080`,
  `31082`, `31090`, `31091`, `31099` e `31180` livres.
- O app [Guarda](https://github.com/vinicius-dobbs/guarda-workshop) no branch
  `workshop` e o app Breja.me devem estar disponíveis **separadamente** do Compose.
  Cada app precisa das suas dependências instaladas e de um emulador Android.
- Um IPv4 da máquina alcançável pelo host, pelos contêineres e pelo emulador.
  Use **o mesmo IP** nas configurações dos três projetos. Não coloque
  `localhost` nem `10.0.2.2` em `WORKSHOP_HOST`: o eSignet publica esse endereço
  como issuer OAuth e o Certify o usa na audiência.
- Em rede com inspeção corporativa de HTTPS, coloque **somente a CA pública já
  confiável** da máquina em `local-ca/` (`.der`, `.crt` ou `.pem`) antes de subir.
  Certify e Verify importam a CA na JVM. Não desative a verificação TLS.

## 1. Preparar e subir os serviços

No diretório deste kit, copie `.env.example` para `.env` e preencha `WORKSHOP_HOST`
com seu IPv4. Os valores mock do cliente e da senha do PKCS#12 podem permanecer
como no exemplo **somente para a oficina**.

```powershell
Copy-Item .env.example .env
# Edite WORKSHOP_HOST no .env antes de continuar.
docker compose config --quiet
docker compose up -d
docker compose ps -a
```

`extract-client`, `setup-client` e `verify-db-setup` devem terminar em `Exited (0)`;
os demais serviços devem permanecer em execução. Na primeira subida, o Compose
cria bancos, chaves e o cliente `wallet-demo` em volumes Docker. Aguarde a
inicialização do Certify antes de testar a emissão.

Substitua `<IP>` pelo valor de `WORKSHOP_HOST` para conferir:

| Serviço | URL de conferência |
|---|---|
| Login eSignet (UI) | `http://<IP>:31000` |
| eSignet (health) | `http://<IP>:31080/v1/esignet/actuator/health` |
| Mock Identity (health) | `http://<IP>:31082/v1/mock-identity-system/actuator/health` |
| Certify (health) | `http://<IP>:31090/v1/certify/actuator/health` |
| Tipos de VC disponíveis | `http://<IP>:31090/v1/certify/.well-known/openid-credential-issuer` |
| Mimoto (emissores) | `http://<IP>:31099/v1/mimoto/issuers` |
| Verify (health) | `http://<IP>:31180/v1/verify/actuator/health` |
| DID do emissor (diagnóstico HTTP) | `http://<IP>:31091/.well-known/did.json` |

HTTP 200 em health ou no catálogo **não substitui** o teste de emissão e
verificação nos apps.

## 2. Emitir uma credencial no Guarda

No repositório do Guarda, copie `.env.example` para `.env`, substitua
`SEU_IP_DA_REDE` pelo mesmo IPv4 da oficina e confira estas variáveis:

```properties
EXPO_PUBLIC_WORKSHOP_AUTH_URL=http://<IP>:31080/authorize
EXPO_PUBLIC_WORKSHOP_CERTIFY_URL=http://<IP>:31090/v1/certify
EXPO_PUBLIC_WORKSHOP_MIMOTO_URL=http://<IP>:31099
```

Inicie o Guarda no emulador com `npm run android` (ou o comando indicado no
README do app). Se o Metro já estava aberto antes de editar o `.env`, reinicie-o
com `npx expo start --clear`. Não inclua segredos em variáveis `EXPO_PUBLIC_*`:
elas são embutidas no app.

Use **somente** as identidades do seed, com PIN de demonstração `545411` ou
OTP mock `111111`:

| Cenário | ID fictício | Valor esperado na ECA |
|---|---|---|
| Maior de idade | `2154189532` | `isOver18=true` |
| Menor de idade | `3963293078` | `isOver18=false` |

No Guarda, faça login com uma dessas identidades, abra **Adicionar documento** e
baixe `ECACredential`. Confirme que ela aparece na carteira. `FarmerCredential`
também é anunciada pelo Certify, mas o cenário de decisão de maioridade do
Breja.me solicita **ECA**. O app obtém os tipos do catálogo do Certify; não
é necessário cadastrar um emissor por credencial no Mimoto.

## 3. Verificar no Breja.me

O Breja.me **não é iniciado pelo Compose**. No repositório do app, mantenha um
`.env` local com as duas entradas ativas abaixo (com o mesmo IP):

```properties
EXPO_PUBLIC_BASE_URL=http://<IP>:31180
EXPO_PUBLIC_CLIENT_ID=did:web:<IP>%3A31180:v1:verify
```

O `%3A` codifica os dois-pontos da **porta dentro do DID**; não troque o
`EXPO_PUBLIC_CLIENT_ID` pela URL HTTP. Instale as dependências do Breja.me e
inicie-o no emulador (`npm run android`). Reinicie o Metro do app após alterar o
`.env`. O Breja.me cria a VP request no Verify, abre o Guarda pelo deep link
`openid4vp://` e consulta o resultado usando o `transactionId`.

1. No Breja.me, escolha **Comprar → Verificar Idade**.
2. No Guarda, confirme o compartilhamento da `ECACredential` já armazenada.
3. Volte ao Breja.me e confira o resultado. Para repetir com o outro perfil,
   saia da sessão no Guarda, entre com o **outro ID fictício**, baixe outra
   `ECACredential` e refaça a solicitação no Breja.me. A identidade adulta
   deve ser aprovada e a menor, recusada.

O Verify valida a VP e a assinatura da VC. O status `VP_SUBMITTED` informa
apenas que a carteira respondeu; confira também o **resultado da verificação**.
Não conclua sucesso com base apenas no health ou na submissão.

## Diagnóstico sem apagar a oficina

```powershell
docker compose config --quiet
docker compose ps -a
docker compose logs --tail 80 esignet mock-identity mimoto certify verify certify-nginx
```

- **Login funciona, mas emitir outra VC dá `invalid_proof` com `c_nonce`:** o
  nonce vence independentemente do access token. O SDK 1.0.11 do Guarda não
  trata o desafio sozinho; o adaptador `src/workshopFetch.js` do branch
  `workshop` repete **uma vez** com uma nova proof Ed25519 assinada pela mesma
  chave. Reinicie o Metro do Guarda para carregar o adaptador. Não aumente o
  prazo de login como substituto do retry.
- **Verify rejeita a assinatura da VC ou não resolve DID:** as VCs emitidas
  com a configuração atual usam `did:web:certify-nginx`. O Certify serve seu documento por
  `https://certify-nginx/.well-known/did.json` **na rede Docker**, com
  certificado TLS local persistido em `workshop-did-tls` e confiado pela JVM
  do Verify. VCs antigas com DID ngrok exigem **nova emissão**, não edição
  da credencial ou substituição da chave. O DID local não serve para
  verificadores externos.
- **Erro ao buscar contexto JSON-LD:** Certify e Verify consultam os
  contextos HTTPS canônicos. Em rede com interceptação TLS, configure apenas
  a CA pública confiável em `local-ca/` e recrie o serviço afetado. Não
  substitua os contextos canônicos por mocks nem desative a validação TLS.
- **A VC desaparece ao compartilhar:** confira se o Guarda está no branch
  `workshop` e usando a VC **já armazenada**. Nesse modo, ele não deve
  chamar a rotina do SDK que remove credenciais antes de novo download.

Para parar sem perder o estado: `docker compose down`. Para voltar:
`docker compose up -d`. **Não use `down -v` durante a oficina:** apaga bancos,
keystores e o certificado local do DID; `down` sem `-v` não reaplica SQLs de
inicialização. Não registre tokens, PINs, chaves privadas ou VCs completas
nos logs de diagnóstico.

## Para quem prepara a oficina

Para acrescentar **identidades fictícias** em uma instalação existente,
atualize juntos `sql/mock-identities.sql` e `config/workshop_identity_data.csv`
com o mesmo `id`, revise os arquivos e execute:

```powershell
docker compose --profile maintenance run --rm sync-identities
docker compose up -d --no-deps --force-recreate certify
```

Para cadastrar **novos tipos de VC**, adicione um SQL revisado em
`sql/credentials/` tomando `sql/eca-demo.sql` como referência e execute:

```powershell
docker compose --profile maintenance run --rm sync-credentials
docker compose up -d --no-deps --force-recreate certify
```

Esses jobs não rodam na subida comum. `ON CONFLICT DO NOTHING` cria, mas
**não atualiza** configurações existentes. Ambos executam entradas fornecidas
por quem opera a oficina: revise SQL e CSV antes. Alterar o seed após a
inicialização do volume também **não altera o banco existente**.

Para contratos técnicos e cuidados ao modificar o kit, leia
[`CONTEXTO-IA.md`](CONTEXTO-IA.md).