# Proje 1 - Veritabanı Performans Optimizasyonu ve İzleme

## Kısa Amaç
Bu projenin amacı, büyük veri hacmine sahip bir veritabanında yavaş çalışan sorguları tespit ederek performans darboğazlarını gidermek; sorgu optimizasyonu, indeks yönetimi, disk alanı ve veri yoğunluğu analizi ile sistem performansını ölçülebilir şekilde iyileştirmektir.

## Adım 1 Dosyası
- [01_adim_veri_hazirlama.sql](sql/01_adim_veri_hazirlama.sql)

## Adım 2 Dosyası
- [02_adim_pg_stat_ve_ilk_olcum.sql](sql/02_adim_pg_stat_ve_ilk_olcum.sql)

## Adım 3 Dosyası
- [03_adim_explain_analiz.sql](sql/03_adim_explain_analiz.sql)

## Adım 4 Dosyası
- [04_adim_index_optimizasyon.sql](sql/04_adim_index_optimizasyon.sql)

## Adım 5 Dosyası
- [05_adim_sorgu_iyilestirme.sql](sql/05_adim_sorgu_iyilestirme.sql)

## Adım 6 Dosyası
- [06_adim_rol_ve_yetki_yonetimi.sql](sql/06_adim_rol_ve_yetki_yonetimi.sql)

## Adım 7 Dosyası
- [07_adim_son_olcum_ve_karsilastirma.sql](sql/07_adim_son_olcum_ve_karsilastirma.sql)

## Proje Planı Uyum Durumu
- Adım 1: Tamamlandı (1M+ veri üretimi, PostgreSQL'e yükleme, veri tipi/null kontrolü mevcut)
- Adım 2: Tamamlandı (pg_stat_statements etkinleştirme, kritik sorgu çalıştırma, ilk ölçüm tablosu mevcut)
- Adım 3: Tamamlandı (EXPLAIN ANALYZE BUFFERS ile plan analizi ve notlama mevcut)
- Adım 4: Tamamlandı (WHERE/JOIN indeksleri, composite indeks denemesi, kullanılmayan indeks kontrolü mevcut)
- Adım 5: Tamamlandı (SELECT * azaltma, erken filtre, alt sorgu dönüşümü mevcut)
- Adım 6: Tamamlandı (role_admin, role_analyst, role_app_user ve en az yetki ilkesi eklendi)
- Adım 7: Tamamlandı (aynı sorgular için final ölçüm, önce/sonra tablo ve metinsel grafik eklendi)

## Çalıştırma Sırası
1. sql/01_adim_veri_hazirlama.sql
2. sql/02_adim_pg_stat_ve_ilk_olcum.sql
3. sql/03_adim_explain_analiz.sql
4. sql/04_adim_index_optimizasyon.sql
5. sql/05_adim_sorgu_iyilestirme.sql
6. sql/06_adim_rol_ve_yetki_yonetimi.sql
7. sql/07_adim_son_olcum_ve_karsilastirma.sql

Adım 7 tamamlandığında proje planındaki tüm maddeler karşılanmış olur.


