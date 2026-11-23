-- Oficina: credencial de maioridade simulada pelo plugin CSV do Certify upstream.
-- Os IDs devem corresponder aos identificadores de teste do servidor de autorização.
-- Não aponta para a API ECA nem para o DID da Dataprev.
-- Cada arquivo em docker-entrypoint-initdb.d inicia conectado ao banco postgres.
\connect inji_certify postgres

INSERT INTO certify.credential_config (
    credential_config_key_id, config_id, status, vc_template, context,
    credential_type, credential_format, did_url, key_manager_app_id,
    key_manager_ref_id, signature_algo, signature_crypto_suite, display,
    display_order, scope, cryptographic_binding_methods_supported,
    credential_signing_alg_values_supported, proof_types_supported,
    credential_subject, plugin_configurations, cr_dtimes
)
SELECT
    'ECACredential', gen_random_uuid()::varchar(255), 'active',
    encode(convert_to($template${
      "@context": [
        "https://www.w3.org/2018/credentials/v1",
        "https://injibr.github.io/inji-did/contexts/eca/v1.jsonld",
        "https://w3id.org/security/suites/ed25519-2020/v1"
      ],
      "issuer": "${_issuer}",
      "type": ["VerifiableCredential", "ECACredential"],
      "issuanceDate": "${validFrom}",
      "expirationDate": "${validUntil}",
      "credentialSubject": {
        "id": "${_holderId}",
        "isOver18": ${isOver18}
      }
    }$template$, 'UTF8'), 'base64'),
    'https://www.w3.org/2018/credentials/v1',
    'ECACredential,VerifiableCredential', 'ldp_vc',
    did_url, key_manager_app_id, key_manager_ref_id, signature_algo,
    signature_crypto_suite,
    '[{"name":"Comprovante de Maioridade (demonstração)","locale":"pt","logo":{"url":"https://mosip.github.io/inji-config/logos/agro-vertias-logo.png","alt_text":"Credencial demonstrativa de maioridade"},"background_color":"#12107c","text_color":"#FFFFFF"}]'::jsonb,
    ARRAY['isOver18'], scope, cryptographic_binding_methods_supported,
    credential_signing_alg_values_supported,
    jsonb_set(proof_types_supported, '{jwt,proof_signing_alg_values_supported}',
              (proof_types_supported #> '{jwt,proof_signing_alg_values_supported}') || '["EdDSA"]'::jsonb),
    '{"isOver18":{"display":[{"name":"Maior de 18 anos","locale":"pt"}]}}'::jsonb,
    '[{"mosip.certify.mock.data-provider.csv-registry-uri":"/home/mosip/config/workshop_identity_data.csv","mosip.certify.mock.data-provider.csv.data-columns":"id,fullName,mobileNumber,dateOfBirth,gender,state,district,villageOrTown,postalCode,landArea,landOwnershipType,primaryCropType,secondaryCropType,face,farmerID,isOver18","mosip.certify.mock.data-provider.csv.identifier-column":"id"}]'::jsonb,
    now()
FROM certify.credential_config
WHERE credential_config_key_id = 'FarmerCredential'
ON CONFLICT (credential_config_key_id) DO NOTHING;