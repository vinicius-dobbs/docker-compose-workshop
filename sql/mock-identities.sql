\connect mosip_mockidentitysystem postgres

INSERT INTO mockidentitysystem.mock_identity (individual_id, identity_json)
SELECT '2154189532', jsonb_build_object(
  'individualId', '2154189532', 'pin', '545411', 'email', 'adulto@example.test',
  'phone', '+5500000000000', 'dateOfBirth', '1990/01/01', 'preferredLang', 'eng', 'locale', 'en',
  'fullName', jsonb_build_array(jsonb_build_object('language', 'eng', 'value', 'Adulto da oficina')),
  'givenName', jsonb_build_array(jsonb_build_object('language', 'eng', 'value', 'Adulto')),
  'familyName', jsonb_build_array(jsonb_build_object('language', 'eng', 'value', 'Oficina')),
  'gender', jsonb_build_array(jsonb_build_object('language', 'eng', 'value', 'Other'))
)::text
WHERE NOT EXISTS (SELECT 1 FROM mockidentitysystem.mock_identity WHERE individual_id = '2154189532');

INSERT INTO mockidentitysystem.mock_identity (individual_id, identity_json)
SELECT '3963293078', jsonb_build_object(
  'individualId', '3963293078', 'pin', '545411', 'email', 'menor@example.test',
  'phone', '+5500000000000', 'dateOfBirth', '2012/01/01', 'preferredLang', 'eng', 'locale', 'en',
  'fullName', jsonb_build_array(jsonb_build_object('language', 'eng', 'value', 'Menor da oficina')),
  'givenName', jsonb_build_array(jsonb_build_object('language', 'eng', 'value', 'Menor')),
  'familyName', jsonb_build_array(jsonb_build_object('language', 'eng', 'value', 'Oficina')),
  'gender', jsonb_build_array(jsonb_build_object('language', 'eng', 'value', 'Other'))
)::text
WHERE NOT EXISTS (SELECT 1 FROM mockidentitysystem.mock_identity WHERE individual_id = '3963293078');