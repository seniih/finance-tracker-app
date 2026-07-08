-- Mevcut sorunlu kuralı siliyoruz
DROP POLICY IF EXISTS "categories_own" ON categories;

-- Yerine sonsuz döngü (infinite recursion) oluşturmayacak şekilde
-- SELECT, INSERT, UPDATE, DELETE için ayrı ayrı kurallar oluşturuyoruz

CREATE POLICY "categories_select" ON categories 
  FOR SELECT 
  USING (user_id = (select auth.uid()));

CREATE POLICY "categories_insert" ON categories 
  FOR INSERT 
  WITH CHECK (
    user_id = (select auth.uid())
    AND (
      parent_id IS NULL 
      OR parent_id IN (SELECT id FROM categories)
    )
  );

CREATE POLICY "categories_update" ON categories 
  FOR UPDATE 
  USING (user_id = (select auth.uid()))
  WITH CHECK (
    user_id = (select auth.uid())
    AND (
      parent_id IS NULL 
      OR parent_id IN (SELECT id FROM categories)
    )
  );

CREATE POLICY "categories_delete" ON categories 
  FOR DELETE 
  USING (user_id = (select auth.uid()));
