-- Adım 1: Temel yapı ve örnek veri hazırlama
-- Amaç: Güvenlik senaryosu için kullanıcı, departman ve müşteri verisini kurmak.

DROP SCHEMA IF EXISTS security_demo CASCADE;
CREATE SCHEMA security_demo;
SET search_path TO security_demo;

CREATE TABLE departments (
    department_id SERIAL PRIMARY KEY,
    department_name TEXT NOT NULL UNIQUE
);

CREATE TABLE app_users (
    user_id SERIAL PRIMARY KEY,
    username TEXT NOT NULL UNIQUE,
    full_name TEXT NOT NULL,
    email TEXT NOT NULL UNIQUE,
    department_id INT NOT NULL REFERENCES departments(department_id),
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE TABLE customer_accounts (
    account_id BIGSERIAL PRIMARY KEY,
    owner_user_id INT NOT NULL REFERENCES app_users(user_id),
    account_no TEXT NOT NULL UNIQUE,
    customer_name TEXT NOT NULL,
    email TEXT NOT NULL,
    phone TEXT,
    national_id TEXT NOT NULL,
    salary NUMERIC(12,2) NOT NULL,
    account_status TEXT NOT NULL DEFAULT 'ACTIVE',
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

INSERT INTO departments (department_name) VALUES
('Finance'),
('Sales'),
('Support'),
('IT');

INSERT INTO app_users (username, full_name, email, department_id)
SELECT
    'user_' || gs,
    'Kullanici ' || gs,
    'user_' || gs || '@demo.local',
    ((gs - 1) % 4) + 1
FROM generate_series(1, 20) AS gs;

INSERT INTO customer_accounts (
    owner_user_id,
    account_no,
    customer_name,
    email,
    phone,
    national_id,
    salary,
    account_status
)
SELECT
    ((gs - 1) % 20) + 1,
    'ACC' || lpad(gs::text, 6, '0'),
    'Musteri ' || gs,
    'customer_' || gs || '@mail.local',
    '+90 5' || lpad(((gs % 10) + 10)::text, 2, '0') || ' 555 ' || lpad(gs::text, 4, '0'),
    lpad((10000000000 + gs)::text, 11, '0'),
    round((25000 + (random() * 75000))::numeric, 2),
    CASE WHEN gs % 7 = 0 THEN 'SUSPENDED' ELSE 'ACTIVE' END
FROM generate_series(1, 100) AS gs;

-- İlk veri kontrolü
SELECT COUNT(*) AS department_count FROM departments;
SELECT COUNT(*) AS user_count FROM app_users;
SELECT COUNT(*) AS account_count FROM customer_accounts;
SELECT * FROM customer_accounts ORDER BY account_id LIMIT 5;
