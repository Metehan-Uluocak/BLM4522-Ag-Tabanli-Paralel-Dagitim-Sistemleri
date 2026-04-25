-- Adım 6: Rol ve yetki yönetimi (least privilege)
-- Bu dosyayı blm4522_perf veritabanında yetkili kullanıcı ile çalıştır.

-- -----------------------------------------------------
-- A) Roller
-- -----------------------------------------------------
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'role_admin') THEN
        CREATE ROLE role_admin NOLOGIN;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'role_analyst') THEN
        CREATE ROLE role_analyst NOLOGIN;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'role_app_user') THEN
        CREATE ROLE role_app_user NOLOGIN;
    END IF;
END
$$;

-- -----------------------------------------------------
-- B) Varsayılan geniş yetkileri daralt
-- -----------------------------------------------------
REVOKE CREATE ON SCHEMA public FROM PUBLIC;

-- -----------------------------------------------------
-- C) Veritabanı / şema erişimi
-- -----------------------------------------------------
GRANT CONNECT ON DATABASE blm4522_perf TO role_admin, role_analyst, role_app_user;
GRANT USAGE ON SCHEMA public TO role_admin, role_analyst, role_app_user;

-- -----------------------------------------------------
-- D) Mevcut tablolar için yetkiler
-- -----------------------------------------------------
-- Önce rollerin eski yetkilerini temizle (idempotent kalması için)
REVOKE ALL PRIVILEGES ON ALL TABLES IN SCHEMA public FROM role_analyst, role_app_user;
REVOKE ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public FROM role_analyst, role_app_user;

-- role_admin: yönetim rolü (tam tablo/sequence yetkisi)
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO role_admin;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO role_admin;

-- role_analyst: sadece okuma
GRANT SELECT ON ALL TABLES IN SCHEMA public TO role_analyst;

-- role_app_user: uygulamanın ihtiyaç duyduğu en düşük yetki
-- users ve instruments: sadece okuma
DO $$
BEGIN
    IF to_regclass('public.users') IS NOT NULL THEN
        GRANT SELECT ON TABLE public.users TO role_app_user;
    END IF;

    IF to_regclass('public.instruments') IS NOT NULL THEN
        GRANT SELECT ON TABLE public.instruments TO role_app_user;
    END IF;
END
$$;

-- orders ve trades: okuma + yazma (silme/truncate yok)
DO $$
BEGIN
    IF to_regclass('public.orders') IS NOT NULL THEN
        GRANT SELECT, INSERT, UPDATE ON TABLE public.orders TO role_app_user;
    END IF;

    IF to_regclass('public.trades') IS NOT NULL THEN
        GRANT SELECT, INSERT, UPDATE ON TABLE public.trades TO role_app_user;
    END IF;
END
$$;

-- BIGSERIAL sequence'leri için kullanım yetkisi
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO role_app_user;

-- -----------------------------------------------------
-- E) Gelecekte oluşacak nesneler için varsayılan yetkiler
-- -----------------------------------------------------
-- Not: Bu komutlar, komutu çalıştıran sahibin gelecekte oluşturacağı nesneleri etkiler.
ALTER DEFAULT PRIVILEGES IN SCHEMA public
GRANT ALL PRIVILEGES ON TABLES TO role_admin;

ALTER DEFAULT PRIVILEGES IN SCHEMA public
GRANT ALL PRIVILEGES ON SEQUENCES TO role_admin;

ALTER DEFAULT PRIVILEGES IN SCHEMA public
GRANT SELECT ON TABLES TO role_analyst;

ALTER DEFAULT PRIVILEGES IN SCHEMA public
GRANT SELECT, INSERT, UPDATE ON TABLES TO role_app_user;

ALTER DEFAULT PRIVILEGES IN SCHEMA public
GRANT USAGE, SELECT ON SEQUENCES TO role_app_user;

-- -----------------------------------------------------
-- F) Doğrulama sorguları
-- -----------------------------------------------------
SELECT rolname AS role_name
FROM pg_roles
WHERE rolname IN ('role_admin', 'role_analyst', 'role_app_user')
ORDER BY rolname;

SELECT
    grantee,
    table_name,
    string_agg(privilege_type, ', ' ORDER BY privilege_type) AS privileges
FROM information_schema.table_privileges
WHERE table_schema = 'public'
  AND grantee IN ('role_admin', 'role_analyst', 'role_app_user')
GROUP BY grantee, table_name
ORDER BY grantee, table_name;
