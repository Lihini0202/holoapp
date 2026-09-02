select policyname, cmd, roles::text, qual, with_check from pg_policies where tablename = 'user_profiles';
