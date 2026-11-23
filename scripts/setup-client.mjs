import { createHash, createPublicKey } from 'node:crypto';
import { writeFileSync, mkdirSync } from 'node:fs';
import { readFileSync } from 'node:fs';

const id = process.env.WORKSHOP_CLIENT_ID;
const host = process.env.WORKSHOP_HOST;
const server = 'http://esignet:8088';

if (!id || !host) throw new Error('WORKSHOP_CLIENT_ID e WORKSHOP_HOST são obrigatórios');

mkdirSync('/workshop/config', { recursive: true });
writeFileSync('/workshop/config/mimoto-issuers-config.json', JSON.stringify({ issuers: [{
  credential_issuer: 'Farmer', issuer_id: 'Farmer', protocol: 'OpenId4VCI',
  display: [{ name: 'Emissor da oficina', title: 'Credenciais da oficina',
    description: 'Farmer e maioridade', language: 'en',
    logo: { url: 'https://mosip.github.io/inji-config/logos/agro-vertias-logo.png', alt_text: 'Oficina' } }],
  client_id: id, client_alias: 'wallet-demo-client',
  redirect_uri: 'io.mosip.residentapp.inji://oauthredirect',
  token_endpoint: `http://${host}:31099/v1/mimoto/get-token/Farmer`,
  authorization_audience: `http://${host}:31080/v1/esignet/oauth/v2/token`,
  proxy_token_endpoint: `http://${host}:31080/v1/esignet/oauth/v2/token`,
  qr_code_type: 'EmbeddedVC', enabled: 'true',
  credential_issuer_host: `http://${host}:31091`,
  wellknown_endpoint: `http://${host}:31091/.well-known/openid-credential-issuer`,
}] }, null, 2) + '\n');

const jwk = createPublicKey(readFileSync('/workshop/client-public.pem')).export({ format: 'jwk' });
const publicKey = {
  kty: jwk.kty, n: jwk.n, e: jwk.e,
  kid: createHash('sha256').update(`${jwk.n}.${jwk.e}`).digest('hex'),
  alg: 'RS256', use: 'sig',
};

for (let attempt = 0; attempt < 30; attempt++) {
  try {
    const health = await fetch(`${server}/v1/esignet/actuator/health`);
    if (health.ok) break;
  } catch {
    // Aguarda o eSignet inicializar.
  }
  if (attempt === 29) throw new Error('eSignet não iniciou em tempo hábil');
  await new Promise((resolve) => setTimeout(resolve, 2000));
}

const body = {
  requestTime: new Date().toISOString(),
  request: {
    clientId: id,
    clientName: 'Carteira da oficina',
    clientNameLangMap: { eng: 'Workshop Wallet' },
    relyingPartyId: id,
    logoUri: 'https://mosip.github.io/inji-config/logos/agro-vertias-logo.png',
    redirectUris: ['io.mosip.residentapp.inji://oauthredirect'],
    userClaims: ['name'],
    authContextRefs: ['mosip:idp:acr:generated-code', 'mosip:idp:acr:password'],
    publicKey,
    grantTypes: ['authorization_code'],
    clientAuthMethods: ['private_key_jwt'],
  },
};
const response = await fetch(`${server}/v1/esignet/client-mgmt/client`, {
  method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body),
});
const result = await response.json().catch(() => ({}));
if (response.ok && result.errors?.some((error) => error.errorCode === 'duplicate_client_id')) {
  console.log('Cliente OIDC da oficina já cadastrado.');
  process.exit(0);
}
if (!response.ok || result.errors?.length || result.response?.clientId !== id) {
  throw new Error(`Cadastro do cliente falhou: HTTP ${response.status}; códigos: ${
    (result.errors ?? []).map((error) => error.errorCode).join(',')}`);
}
console.log('Cliente OIDC local cadastrado; chave privada mantida apenas no Mimoto.');