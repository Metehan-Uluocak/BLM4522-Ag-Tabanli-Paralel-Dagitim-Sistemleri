# Proje 2 - Veritabanı Yedekleme ve Felaketten Kurtarma

## Kısa Amaç
Bu projenin amacı, veri kaybı ve servis kesintisi risklerini azaltmak için ölçülebilir bir yedekleme ve felaketten kurtarma (DR) planı tasarlamak; planı adım adım uygulayıp test ederek RTO/RPO hedeflerini doğrulamaktır.

## Adım 1 Dosyaları
- [sql/01_adim_yedekleme_stratejisi_modulu.sql](sql/01_adim_yedekleme_stratejisi_modulu.sql)

## Adım 2 Dosyaları
- [sql/02_adim_tam_yedekleme_ve_arsivleme_hazirlik.sql](sql/02_adim_tam_yedekleme_ve_arsivleme_hazirlik.sql)
- [scripts/backup_full_logical_pg_dump.bat](scripts/backup_full_logical_pg_dump.bat)
- [scripts/backup_full_physical_pg_basebackup.bat](scripts/backup_full_physical_pg_basebackup.bat)

## Adım 3 Dosyaları
- [sql/03_adim_wal_arsivleme_dogrulama.sql](sql/03_adim_wal_arsivleme_dogrulama.sql)


## Adım 4 Dosyaları
- [sql/04_adim_task_scheduler_izleme.sql](sql/04_adim_task_scheduler_izleme.sql)
- [scripts/run_daily_logical_backup_with_alert.bat](scripts/run_daily_logical_backup_with_alert.bat)
- [scripts/setup_task_scheduler_jobs.bat](scripts/setup_task_scheduler_jobs.bat)


## Adım 5 Dosyaları
- [sql/05_adim_felaket_senaryosu_ve_pitr_test.sql](sql/05_adim_felaket_senaryosu_ve_pitr_test.sql)

## Adım 6 Dosyaları
- [sql/06_adim_geri_yukleme_tatbikati_ve_dogrulama.sql](sql/06_adim_geri_yukleme_tatbikati_ve_dogrulama.sql)

## Adım 7 Dosyaları
- [sql/07_adim_final_kpi_ve_kapanis_raporu.sql](sql/07_adim_final_kpi_ve_kapanis_raporu.sql)

## Proje Planı Uyum Durumu
- Adım 1: Tamamlandı (RPO/RTO hedefleri, saklama kuralları ve kritik varlık sınıflandırması mevcut)
- Adım 2: Tamamlandı (tam yedek envanteri, mantıksal/fiziksel yedek akışı, WAL ayar kontrolleri mevcut)
- Adım 3: Tamamlandı (WAL arşivleme doğrulaması ve kanıt kaydı mevcut)
- Adım 4: Tamamlandı (Task Scheduler izleme, job run ve alarm tabloları mevcut)
- Adım 5: Tamamlandı (kontrollü incident ve PITR test hazırlığı mevcut)
- Adım 6: Tamamlandı (geri yükleme tatbikatı ve doğrulama kontrolleri eklendi)
- Adım 7: Tamamlandı (final KPI, kapanış değerlendirmesi ve adım bazlı completion check eklendi)

## Çalıştırma Sırası
1. sql/01_adim_yedekleme_stratejisi_modulu.sql
2. sql/02_adim_tam_yedekleme_ve_arsivleme_hazirlik.sql
3. sql/03_adim_wal_arsivleme_dogrulama.sql
4. sql/04_adim_task_scheduler_izleme.sql
5. sql/05_adim_felaket_senaryosu_ve_pitr_test.sql
6. sql/06_adim_geri_yukleme_tatbikati_ve_dogrulama.sql
7. sql/07_adim_final_kpi_ve_kapanis_raporu.sql



