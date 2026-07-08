DROP POLICY IF EXISTS "categories_insert" ON categories;
DROP POLICY IF EXISTS "categories_update" ON categories;

-- Aynı tabloya (categories) yapılan SELECT sorguları, ayrı kural olsa bile 
-- Postgres tarafından potansiyel sonsuz döngü (42P17) olarak algılanıp engelleniyor.
-- Bu yüzden parent_id kontrolünü RLS içinden çıkarıyoruz. Yabancı anahtar (Foreign Key)
-- zaten var olmayan bir id girilmesini engelliyor.

CREATE POLICY "categories_insert" ON categories 
  FOR INSERT 
  WITH CHECK (user_id = (select auth.uid()));

CREATE POLICY "categories_update" ON categories 
  FOR UPDATE 
  USING (user_id = (select auth.uid()))
  WITH CHECK (user_id = (select auth.uid()));
