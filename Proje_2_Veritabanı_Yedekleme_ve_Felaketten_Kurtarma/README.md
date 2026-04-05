# Proje 2 - Veritabanı Yedekleme ve Felaketten Kurtarma

## Kısa Amaç
Bu projenin amacı, veri kaybı ve servis kesintisi risklerini azaltmak için ölçülebilir bir yedekleme ve felaketten kurtarma (DR) planı tasarlamak; planı adım adım uygulayıp test ederek RTO/RPO hedeflerini doğrulamaktır.

## Adım 1 Dosyaları
- [sql/01_adim_yedekleme_stratejisi_modulu.sql](sql/01_adim_yedekleme_stratejisi_modulu.sql)

## Adım 2 Dosyaları
- [sql/02_adim_tam_yedekleme_ve_arsivleme_hazirlik.sql](sql/02_adim_tam_yedekleme_ve_arsivleme_hazirlik.sql)
- [scripts/backup_full_logical_pg_dump.bat](scripts/backup_full_logical_pg_dump.bat)
- [scripts/backup_full_physical_pg_basebackup.bat](scripts/backup_full_physical_pg_basebackup.bat)

