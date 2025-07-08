-- tests/002_test_framework.sql
-- Simple assertion helpers for SQL tests

CREATE SCHEMA IF NOT EXISTS test;

CREATE OR REPLACE FUNCTION test.assert_true(p_condition boolean, p_message text)
RETURNS void AS $$
BEGIN
  IF NOT p_condition THEN
    RAISE EXCEPTION 'FAIL: %', p_message;
  ELSE
    RAISE NOTICE 'PASS: %', p_message;
  END IF;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION test.assert_raises(p_sql text, p_message text)
RETURNS void AS $$
BEGIN
  BEGIN
    EXECUTE p_sql;
    RAISE EXCEPTION 'FAIL: % (no error)', p_message;
  EXCEPTION WHEN others THEN
    RAISE NOTICE 'PASS: %', p_message;
  END;
END;
$$ LANGUAGE plpgsql;
