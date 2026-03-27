
-- ============================================================
-- PHASE 2: CREATE AUTH USERS
-- Password for all seed users: Sierra@123
-- ============================================================

-- kanin21stcentury@gmail.com already in staff_members (f3439b6b), add to auth
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, email_change,
  email_change_token_new, recovery_token
) VALUES (
  '00000000-0000-0000-0000-000000000000',
  'f3439b6b-e55e-4ac9-8608-f1ef8e4fd7d2',
  'authenticated', 'authenticated',
  'kanin21stcentury@gmail.com',
  crypt('Sierra@123', gen_salt('bf')),
  now(), '{"provider":"email","providers":["email"]}', '{}',
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;

INSERT INTO auth.identities (id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at)
VALUES (
  gen_random_uuid(),
  'f3439b6b-e55e-4ac9-8608-f1ef8e4fd7d2',
  jsonb_build_object('sub', 'f3439b6b-e55e-4ac9-8608-f1ef8e4fd7d2', 'email', 'kanin21stcentury@gmail.com'),
  'email', 'kanin21stcentury@gmail.com',
  now(), now(), now()
) ON CONFLICT DO NOTHING;

-- Driver 1: Rahul Nair
INSERT INTO auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, email_change, email_change_token_new, recovery_token)
VALUES ('00000000-0000-0000-0000-000000000000', 'bbbbbbbb-0001-4000-8000-000000000001', 'authenticated', 'authenticated', 'rahul.nair@sierra.fms', crypt('Sierra@123', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{}', now(), now(), '', '', '', '')
ON CONFLICT (id) DO NOTHING;
INSERT INTO auth.identities (id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at)
VALUES (gen_random_uuid(), 'bbbbbbbb-0001-4000-8000-000000000001', jsonb_build_object('sub','bbbbbbbb-0001-4000-8000-000000000001','email','rahul.nair@sierra.fms'), 'email', 'rahul.nair@sierra.fms', now(), now(), now()) ON CONFLICT DO NOTHING;

-- Driver 2: Divya Krishnan
INSERT INTO auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, email_change, email_change_token_new, recovery_token)
VALUES ('00000000-0000-0000-0000-000000000000', 'bbbbbbbb-0002-4000-8000-000000000002', 'authenticated', 'authenticated', 'divya.krishnan@sierra.fms', crypt('Sierra@123', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{}', now(), now(), '', '', '', '')
ON CONFLICT (id) DO NOTHING;
INSERT INTO auth.identities (id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at)
VALUES (gen_random_uuid(), 'bbbbbbbb-0002-4000-8000-000000000002', jsonb_build_object('sub','bbbbbbbb-0002-4000-8000-000000000002','email','divya.krishnan@sierra.fms'), 'email', 'divya.krishnan@sierra.fms', now(), now(), now()) ON CONFLICT DO NOTHING;

-- Driver 3: Mohit Saxena
INSERT INTO auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, email_change, email_change_token_new, recovery_token)
VALUES ('00000000-0000-0000-0000-000000000000', 'bbbbbbbb-0003-4000-8000-000000000003', 'authenticated', 'authenticated', 'mohit.saxena@sierra.fms', crypt('Sierra@123', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{}', now(), now(), '', '', '', '')
ON CONFLICT (id) DO NOTHING;
INSERT INTO auth.identities (id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at)
VALUES (gen_random_uuid(), 'bbbbbbbb-0003-4000-8000-000000000003', jsonb_build_object('sub','bbbbbbbb-0003-4000-8000-000000000003','email','mohit.saxena@sierra.fms'), 'email', 'mohit.saxena@sierra.fms', now(), now(), now()) ON CONFLICT DO NOTHING;

-- Driver 4: Sunita Yadav (Pending Approval)
INSERT INTO auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, email_change, email_change_token_new, recovery_token)
VALUES ('00000000-0000-0000-0000-000000000000', 'bbbbbbbb-0004-4000-8000-000000000004', 'authenticated', 'authenticated', 'sunita.yadav@sierra.fms', crypt('Sierra@123', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{}', now(), now(), '', '', '', '')
ON CONFLICT (id) DO NOTHING;
INSERT INTO auth.identities (id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at)
VALUES (gen_random_uuid(), 'bbbbbbbb-0004-4000-8000-000000000004', jsonb_build_object('sub','bbbbbbbb-0004-4000-8000-000000000004','email','sunita.yadav@sierra.fms'), 'email', 'sunita.yadav@sierra.fms', now(), now(), now()) ON CONFLICT DO NOTHING;

-- Maintenance 1: Vikram Reddy
INSERT INTO auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, email_change, email_change_token_new, recovery_token)
VALUES ('00000000-0000-0000-0000-000000000000', 'bbbbbbbb-0005-4000-8000-000000000005', 'authenticated', 'authenticated', 'vikram.reddy@sierra.fms', crypt('Sierra@123', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{}', now(), now(), '', '', '', '')
ON CONFLICT (id) DO NOTHING;
INSERT INTO auth.identities (id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at)
VALUES (gen_random_uuid(), 'bbbbbbbb-0005-4000-8000-000000000005', jsonb_build_object('sub','bbbbbbbb-0005-4000-8000-000000000005','email','vikram.reddy@sierra.fms'), 'email', 'vikram.reddy@sierra.fms', now(), now(), now()) ON CONFLICT DO NOTHING;

-- Maintenance 2: Aisha Patel
INSERT INTO auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, email_change, email_change_token_new, recovery_token)
VALUES ('00000000-0000-0000-0000-000000000000', 'bbbbbbbb-0006-4000-8000-000000000006', 'authenticated', 'authenticated', 'aisha.patel@sierra.fms', crypt('Sierra@123', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{}', now(), now(), '', '', '', '')
ON CONFLICT (id) DO NOTHING;
INSERT INTO auth.identities (id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at)
VALUES (gen_random_uuid(), 'bbbbbbbb-0006-4000-8000-000000000006', jsonb_build_object('sub','bbbbbbbb-0006-4000-8000-000000000006','email','aisha.patel@sierra.fms'), 'email', 'aisha.patel@sierra.fms', now(), now(), now()) ON CONFLICT DO NOTHING;

-- Maintenance 3: Karan Malhotra (Pending Approval)
INSERT INTO auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, email_change, email_change_token_new, recovery_token)
VALUES ('00000000-0000-0000-0000-000000000000', 'bbbbbbbb-0007-4000-8000-000000000007', 'authenticated', 'authenticated', 'karan.malhotra@sierra.fms', crypt('Sierra@123', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{}', now(), now(), '', '', '', '')
ON CONFLICT (id) DO NOTHING;
INSERT INTO auth.identities (id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at)
VALUES (gen_random_uuid(), 'bbbbbbbb-0007-4000-8000-000000000007', jsonb_build_object('sub','bbbbbbbb-0007-4000-8000-000000000007','email','karan.malhotra@sierra.fms'), 'email', 'karan.malhotra@sierra.fms', now(), now(), now()) ON CONFLICT DO NOTHING;
;
