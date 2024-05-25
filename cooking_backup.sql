--
-- PostgreSQL database dump
--

-- Dumped from database version 14.7
-- Dumped by pg_dump version 16.2

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: public; Type: SCHEMA; Schema: -; Owner: postgres
--

-- *not* creating schema, since initdb creates it


ALTER SCHEMA public OWNER TO postgres;

--
-- Name: cooking_type; Type: TYPE; Schema: public; Owner: yiannis
--

CREATE TYPE public.cooking_type AS ENUM (
    'BAKING',
    'CONFECTIONERY'
);


ALTER TYPE public.cooking_type OWNER TO yiannis;

--
-- Name: difficulty; Type: TYPE; Schema: public; Owner: yiannis
--

CREATE TYPE public.difficulty AS ENUM (
    'VERY EASY',
    'EASY',
    'MEDIUM',
    'HARD',
    'VERY HARD'
);


ALTER TYPE public.difficulty OWNER TO yiannis;

--
-- Name: job_title; Type: TYPE; Schema: public; Owner: yiannis
--

CREATE TYPE public.job_title AS ENUM (
    'CHEF',
    'SOUS_CHEF',
    'LINE_COOK',
    'PASTRY_CHEF',
    'EXECUTIVE_CHEF'
);


ALTER TYPE public.job_title OWNER TO yiannis;

--
-- Name: meal_group; Type: TYPE; Schema: public; Owner: yiannis
--

CREATE TYPE public.meal_group AS ENUM (
    'BREAKFAST',
    'LUNCH',
    'DINNER',
    'SNACK',
    'DESSERT'
);


ALTER TYPE public.meal_group OWNER TO yiannis;

--
-- Name: user_role; Type: TYPE; Schema: public; Owner: yiannis
--

CREATE TYPE public.user_role AS ENUM (
    'ADMIN',
    'CHEF'
);


ALTER TYPE public.user_role OWNER TO yiannis;

--
-- Name: calculate_age(date); Type: FUNCTION; Schema: public; Owner: yiannis
--

CREATE FUNCTION public.calculate_age(birth_date date) RETURNS integer
    LANGUAGE plpgsql IMMUTABLE
    AS $$
BEGIN
    RETURN EXTRACT(YEAR FROM AGE(birth_date));
END;
$$;


ALTER FUNCTION public.calculate_age(birth_date date) OWNER TO yiannis;

--
-- Name: calories_content(integer); Type: FUNCTION; Schema: public; Owner: yiannis
--

CREATE FUNCTION public.calories_content(recipe_id integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
    calories_content INT;
    total_servings INT;
BEGIN
    SELECT servings INTO total_servings
    FROM recipes
    WHERE id = recipe_id;

    SELECT SUM(calories) INTO calories_content
    FROM ingredients
    WHERE id IN (
        SELECT ingredient_id
        FROM recipe_ingredients
        WHERE id = recipe_id
    );

    RETURN calories_content / total_servings;
END;
$$;


ALTER FUNCTION public.calories_content(recipe_id integer) OWNER TO yiannis;

--
-- Name: carbs_content(integer); Type: FUNCTION; Schema: public; Owner: yiannis
--

CREATE FUNCTION public.carbs_content(recipe_id integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
    carbs_content INT;
    total_servings INT;
BEGIN
    SELECT servings INTO total_servings
    FROM recipes
    WHERE id = recipe_id;

    SELECT SUM(carbs) INTO carbs_content
    FROM ingredients
    WHERE id IN (
        SELECT ingredient_id
        FROM recipe_ingredients
        WHERE id = recipe_id
    );

    RETURN carbs_content / total_servings;
END;
$$;


ALTER FUNCTION public.carbs_content(recipe_id integer) OWNER TO yiannis;

--
-- Name: check_chef_in_episode(); Type: FUNCTION; Schema: public; Owner: yiannis
--

CREATE FUNCTION public.check_chef_in_episode() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM episodes_cuisines_chefs
        WHERE episode_id = NEW.episode_id
        AND chef_id = NEW.chef_id
    ) THEN
        RAISE EXCEPTION 'A chef must be participating in the episode.';
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.check_chef_in_episode() OWNER TO yiannis;

--
-- Name: check_episodes_cuisines_chefs_limit(); Type: FUNCTION; Schema: public; Owner: yiannis
--

CREATE FUNCTION public.check_episodes_cuisines_chefs_limit() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF (SELECT COUNT(*) FROM episodes_cuisines_chefs WHERE episode_cuisine_id = NEW.episode_cuisine_id) != 10 THEN
        RAISE EXCEPTION 'There can be only 10 chefs per cuisine in an episode.';
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.check_episodes_cuisines_chefs_limit() OWNER TO yiannis;

--
-- Name: check_episodes_cuisines_chefs_recipe(); Type: FUNCTION; Schema: public; Owner: yiannis
--

CREATE FUNCTION public.check_episodes_cuisines_chefs_recipe() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF (SELECT cuisine FROM recipes WHERE id = NEW.recipe_id) != NEW.cuisine_id THEN
        RAISE EXCEPTION 'A recipe must be from the same cuisine as the chef.';
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.check_episodes_cuisines_chefs_recipe() OWNER TO yiannis;

--
-- Name: check_episodes_cuisines_limit(); Type: FUNCTION; Schema: public; Owner: yiannis
--

CREATE FUNCTION public.check_episodes_cuisines_limit() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF (SELECT COUNT(*) FROM episodes_cuisines WHERE episode_id = NEW.episode_id) != 10 THEN
        RAISE EXCEPTION 'There can be only 10 cuisines per episode.';
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.check_episodes_cuisines_limit() OWNER TO yiannis;

--
-- Name: check_episodes_limit(); Type: FUNCTION; Schema: public; Owner: yiannis
--

CREATE FUNCTION public.check_episodes_limit() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF (SELECT COUNT(*) FROM episodes WHERE season = NEW.season) >= 10 THEN
        RAISE EXCEPTION 'There can be only 10 episodes per season.';
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.check_episodes_limit() OWNER TO yiannis;

--
-- Name: check_judge_chef_episode(); Type: FUNCTION; Schema: public; Owner: yiannis
--

CREATE FUNCTION public.check_judge_chef_episode() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Check that the judge is not selected as a chef in the same episode
    IF EXISTS (
        SELECT 1
        FROM episodes_cuisines_chefs
        WHERE episode_id = NEW.episode_id
        AND chef_id = NEW.judge_id
    ) THEN
        RAISE EXCEPTION 'A judge cannot be selected as a chef in the same episode.';
    END IF;

    -- Check that there are 3 judges per episode
    IF (SELECT COUNT(*) FROM judges WHERE episode_id = NEW.episode_id) != 3 THEN
        RAISE EXCEPTION 'There must be 3 judges per episode.';
    END IF;

    RETURN NEW;
END;
$$;


ALTER FUNCTION public.check_judge_chef_episode() OWNER TO yiannis;

--
-- Name: check_judge_count(); Type: FUNCTION; Schema: public; Owner: yiannis
--

CREATE FUNCTION public.check_judge_count() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Check that there are exactly 3 judges per episode
    IF (SELECT COUNT(*) FROM judges WHERE episode_id = NEW.episode_id) != 3 THEN
        RAISE EXCEPTION 'There must be exactly 3 judges per episode.';
    END IF;

    RETURN NEW;
END;
$$;


ALTER FUNCTION public.check_judge_count() OWNER TO yiannis;

--
-- Name: check_recipe_equipment_after_insert(); Type: FUNCTION; Schema: public; Owner: yiannis
--

CREATE FUNCTION public.check_recipe_equipment_after_insert() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    PERFORM 1
    FROM recipe_equipment
    WHERE recipe_id = NEW.id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'A recipe must have at least one equipment.';
    END IF;

    RETURN NEW;
END;
$$;


ALTER FUNCTION public.check_recipe_equipment_after_insert() OWNER TO yiannis;

--
-- Name: check_recipe_steps_after_insert(); Type: FUNCTION; Schema: public; Owner: yiannis
--

CREATE FUNCTION public.check_recipe_steps_after_insert() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- We use PERFORM 1 to check if there is at least one step and discard the result
    PERFORM 1
    FROM recipe_steps
    WHERE recipe_id = NEW.id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'A recipe must have at least one step.';
    END IF;

    RETURN NEW;
END;
$$;


ALTER FUNCTION public.check_recipe_steps_after_insert() OWNER TO yiannis;

--
-- Name: check_recipe_tips_limit(); Type: FUNCTION; Schema: public; Owner: yiannis
--

CREATE FUNCTION public.check_recipe_tips_limit() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF (SELECT COUNT(*) FROM recipe_tips WHERE recipe_id = NEW.recipe_id) >= 3 THEN
        RAISE EXCEPTION 'A recipe can have up to 3 tips.';
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.check_recipe_tips_limit() OWNER TO yiannis;

--
-- Name: chef_age(integer); Type: FUNCTION; Schema: public; Owner: yiannis
--

CREATE FUNCTION public.chef_age(chef_id integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
    age INT;
BEGIN
    SELECT EXTRACT(YEAR FROM AGE(birth_date)) INTO age
    FROM chefs
    WHERE id = chef_id;
    RETURN age;
END;
$$;


ALTER FUNCTION public.chef_age(chef_id integer) OWNER TO yiannis;

--
-- Name: cooking_time(integer); Type: FUNCTION; Schema: public; Owner: yiannis
--

CREATE FUNCTION public.cooking_time(recipe_id integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
    total_time INT;
BEGIN
    SELECT SUM(cooking_time) INTO total_time
    FROM steps
    WHERE id IN (
        SELECT step_id
        FROM recipe_steps
        WHERE id = recipe_id
    );
    RETURN total_time;
END;
$$;


ALTER FUNCTION public.cooking_time(recipe_id integer) OWNER TO yiannis;

--
-- Name: fat_content(integer); Type: FUNCTION; Schema: public; Owner: yiannis
--

CREATE FUNCTION public.fat_content(recipe_id integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
    fat_content INT;
    total_servings INT;
BEGIN
    SELECT servings INTO total_servings
    FROM recipes
    WHERE id = recipe_id;

    SELECT SUM(fat) INTO fat_content
    FROM ingredients
    WHERE id IN (
        SELECT ingredient_id
        FROM recipe_ingredients
        WHERE id = recipe_id
    );

    RETURN fat_content / total_servings;
END;
$$;


ALTER FUNCTION public.fat_content(recipe_id integer) OWNER TO yiannis;

--
-- Name: login_user(text, text); Type: FUNCTION; Schema: public; Owner: yiannis
--

CREATE FUNCTION public.login_user(_username text, _password text) RETURNS public.user_role
    LANGUAGE plpgsql
    AS $$
DECLARE
    user_id INT;
    _user_role USER_ROLE;
BEGIN
    SELECT id, user_role INTO user_id, _user_role
    FROM users
    WHERE username = _username
    AND password = _password;

    IF user_id IS NOT NULL THEN
        UPDATE users
        SET auth_state = TRUE
        WHERE id = user_id;
        RETURN _user_role;
    ELSE
        RETURN NULL;
    END IF;
END;
$$;


ALTER FUNCTION public.login_user(_username text, _password text) OWNER TO yiannis;

--
-- Name: logout_user(text); Type: FUNCTION; Schema: public; Owner: yiannis
--

CREATE FUNCTION public.logout_user(_username text) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
DECLARE
    user_id INT;
BEGIN
    SELECT id INTO user_id
    FROM users
    WHERE username = _username
    AND auth_state = TRUE;

    IF user_id IS NOT NULL THEN
        UPDATE users
        SET auth_state = FALSE
        WHERE id = user_id;
        RETURN TRUE;
    ELSE
        RETURN FALSE;
    END IF;
END;
$$;


ALTER FUNCTION public.logout_user(_username text) OWNER TO yiannis;

--
-- Name: preparation_time(integer); Type: FUNCTION; Schema: public; Owner: yiannis
--

CREATE FUNCTION public.preparation_time(recipe_id integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
    total_time INT;
BEGIN
    SELECT SUM(preparation_time) INTO total_time
    FROM steps
    WHERE id IN (
        SELECT step_id
        FROM recipe_steps
        WHERE id = recipe_id
    );
    RETURN total_time;
END;
$$;


ALTER FUNCTION public.preparation_time(recipe_id integer) OWNER TO yiannis;

--
-- Name: protein_content(integer); Type: FUNCTION; Schema: public; Owner: yiannis
--

CREATE FUNCTION public.protein_content(recipe_id integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
    protein_content INT;
    total_servings INT;
BEGIN
    SELECT servings INTO total_servings
    FROM recipes
    WHERE id = recipe_id;

    SELECT SUM(protein) INTO protein_content
    FROM ingredients
    WHERE id IN (
        SELECT ingredient_id
        FROM recipe_ingredients
        WHERE id = recipe_id
    );

    RETURN protein_content / total_servings;
END;
$$;


ALTER FUNCTION public.protein_content(recipe_id integer) OWNER TO yiannis;

--
-- Name: recipe_food_group(integer); Type: FUNCTION; Schema: public; Owner: yiannis
--

CREATE FUNCTION public.recipe_food_group(recipe_id integer) RETURNS text
    LANGUAGE plpgsql
    AS $$
DECLARE
    food_group_name TEXT;
BEGIN
    SELECT name INTO food_group_name
    FROM food_groups
    WHERE id = (
        SELECT food_group_id
        FROM ingredients
        WHERE id = (
            SELECT basic_ingredient_id
            FROM recipes
            WHERE id = recipe_id
        )
    );
    RETURN food_group_name;
END;
$$;


ALTER FUNCTION public.recipe_food_group(recipe_id integer) OWNER TO yiannis;

--
-- Name: total_time(integer); Type: FUNCTION; Schema: public; Owner: yiannis
--

CREATE FUNCTION public.total_time(recipe_id integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
    total_time INT;
BEGIN
    total_time := preparation_time(recipe_id) + cooking_time(recipe_id);
    RETURN total_time;
END;
$$;


ALTER FUNCTION public.total_time(recipe_id integer) OWNER TO yiannis;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: chefs; Type: TABLE; Schema: public; Owner: yiannis
--

CREATE TABLE public.chefs (
    id integer NOT NULL,
    image_id integer,
    name text,
    surname text,
    phone_number text,
    birth_date date,
    experience integer,
    job_title public.job_title
);


ALTER TABLE public.chefs OWNER TO yiannis;

--
-- Name: content_images; Type: TABLE; Schema: public; Owner: yiannis
--

CREATE TABLE public.content_images (
    id integer NOT NULL,
    description text
);


ALTER TABLE public.content_images OWNER TO yiannis;

--
-- Name: content_images_id_seq; Type: SEQUENCE; Schema: public; Owner: yiannis
--

CREATE SEQUENCE public.content_images_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.content_images_id_seq OWNER TO yiannis;

--
-- Name: content_images_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: yiannis
--

ALTER SEQUENCE public.content_images_id_seq OWNED BY public.content_images.id;


--
-- Name: cuisines; Type: TABLE; Schema: public; Owner: yiannis
--

CREATE TABLE public.cuisines (
    id integer NOT NULL,
    image_id integer,
    name text
);


ALTER TABLE public.cuisines OWNER TO yiannis;

--
-- Name: cuisines_id_seq; Type: SEQUENCE; Schema: public; Owner: yiannis
--

CREATE SEQUENCE public.cuisines_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.cuisines_id_seq OWNER TO yiannis;

--
-- Name: cuisines_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: yiannis
--

ALTER SEQUENCE public.cuisines_id_seq OWNED BY public.cuisines.id;


--
-- Name: episodes; Type: TABLE; Schema: public; Owner: yiannis
--

CREATE TABLE public.episodes (
    id integer NOT NULL,
    image_id integer,
    season integer
);


ALTER TABLE public.episodes OWNER TO yiannis;

--
-- Name: episodes_cuisines; Type: TABLE; Schema: public; Owner: yiannis
--

CREATE TABLE public.episodes_cuisines (
    episode_id integer NOT NULL,
    cuisine_id integer NOT NULL
);


ALTER TABLE public.episodes_cuisines OWNER TO yiannis;

--
-- Name: episodes_cuisines_chefs; Type: TABLE; Schema: public; Owner: yiannis
--

CREATE TABLE public.episodes_cuisines_chefs (
    id integer NOT NULL,
    episode_id integer,
    cuisine_id integer,
    chef_id integer,
    recipe_id integer
);


ALTER TABLE public.episodes_cuisines_chefs OWNER TO yiannis;

--
-- Name: episodes_cuisines_chefs_id_seq; Type: SEQUENCE; Schema: public; Owner: yiannis
--

CREATE SEQUENCE public.episodes_cuisines_chefs_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.episodes_cuisines_chefs_id_seq OWNER TO yiannis;

--
-- Name: episodes_cuisines_chefs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: yiannis
--

ALTER SEQUENCE public.episodes_cuisines_chefs_id_seq OWNED BY public.episodes_cuisines_chefs.id;


--
-- Name: episodes_id_seq; Type: SEQUENCE; Schema: public; Owner: yiannis
--

CREATE SEQUENCE public.episodes_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.episodes_id_seq OWNER TO yiannis;

--
-- Name: episodes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: yiannis
--

ALTER SEQUENCE public.episodes_id_seq OWNED BY public.episodes.id;


--
-- Name: equipment; Type: TABLE; Schema: public; Owner: yiannis
--

CREATE TABLE public.equipment (
    id integer NOT NULL,
    image_id integer,
    name text,
    instructions text
);


ALTER TABLE public.equipment OWNER TO yiannis;

--
-- Name: equipment_id_seq; Type: SEQUENCE; Schema: public; Owner: yiannis
--

CREATE SEQUENCE public.equipment_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.equipment_id_seq OWNER TO yiannis;

--
-- Name: equipment_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: yiannis
--

ALTER SEQUENCE public.equipment_id_seq OWNED BY public.equipment.id;


--
-- Name: food_groups; Type: TABLE; Schema: public; Owner: yiannis
--

CREATE TABLE public.food_groups (
    id integer NOT NULL,
    image_id integer,
    name text,
    description text
);


ALTER TABLE public.food_groups OWNER TO yiannis;

--
-- Name: food_groups_id_seq; Type: SEQUENCE; Schema: public; Owner: yiannis
--

CREATE SEQUENCE public.food_groups_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.food_groups_id_seq OWNER TO yiannis;

--
-- Name: food_groups_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: yiannis
--

ALTER SEQUENCE public.food_groups_id_seq OWNED BY public.food_groups.id;


--
-- Name: images; Type: TABLE; Schema: public; Owner: yiannis
--

CREATE TABLE public.images (
    id integer NOT NULL,
    description text
);


ALTER TABLE public.images OWNER TO yiannis;

--
-- Name: images_id_seq; Type: SEQUENCE; Schema: public; Owner: yiannis
--

CREATE SEQUENCE public.images_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.images_id_seq OWNER TO yiannis;

--
-- Name: images_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: yiannis
--

ALTER SEQUENCE public.images_id_seq OWNED BY public.images.id;


--
-- Name: ingredients; Type: TABLE; Schema: public; Owner: yiannis
--

CREATE TABLE public.ingredients (
    id integer NOT NULL,
    image_id integer,
    name text,
    food_group_id integer,
    calories double precision,
    fat double precision,
    protein double precision,
    carbs double precision
);


ALTER TABLE public.ingredients OWNER TO yiannis;

--
-- Name: ingredients_id_seq; Type: SEQUENCE; Schema: public; Owner: yiannis
--

CREATE SEQUENCE public.ingredients_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.ingredients_id_seq OWNER TO yiannis;

--
-- Name: ingredients_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: yiannis
--

ALTER SEQUENCE public.ingredients_id_seq OWNED BY public.ingredients.id;


--
-- Name: judges; Type: TABLE; Schema: public; Owner: yiannis
--

CREATE TABLE public.judges (
    episode_id integer NOT NULL,
    judge_id integer NOT NULL
);


ALTER TABLE public.judges OWNER TO yiannis;

--
-- Name: marks; Type: TABLE; Schema: public; Owner: yiannis
--

CREATE TABLE public.marks (
    id integer NOT NULL,
    episode_id integer,
    judge_id integer,
    chef_id integer,
    mark integer,
    CONSTRAINT marks_mark_check CHECK (((mark >= 1) AND (mark <= 5)))
);


ALTER TABLE public.marks OWNER TO yiannis;

--
-- Name: marks_id_seq; Type: SEQUENCE; Schema: public; Owner: yiannis
--

CREATE SEQUENCE public.marks_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.marks_id_seq OWNER TO yiannis;

--
-- Name: marks_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: yiannis
--

ALTER SEQUENCE public.marks_id_seq OWNED BY public.marks.id;


--
-- Name: recipe_equipment; Type: TABLE; Schema: public; Owner: yiannis
--

CREATE TABLE public.recipe_equipment (
    recipe_id integer,
    equipment_id integer,
    quantity integer
);


ALTER TABLE public.recipe_equipment OWNER TO yiannis;

--
-- Name: recipe_ingredients; Type: TABLE; Schema: public; Owner: yiannis
--

CREATE TABLE public.recipe_ingredients (
    recipe_id integer,
    ingredient_id integer,
    quantity integer
);


ALTER TABLE public.recipe_ingredients OWNER TO yiannis;

--
-- Name: recipe_steps; Type: TABLE; Schema: public; Owner: yiannis
--

CREATE TABLE public.recipe_steps (
    recipe_id integer,
    step_id integer
);


ALTER TABLE public.recipe_steps OWNER TO yiannis;

--
-- Name: recipe_tags; Type: TABLE; Schema: public; Owner: yiannis
--

CREATE TABLE public.recipe_tags (
    recipe_id integer,
    tag text
);


ALTER TABLE public.recipe_tags OWNER TO yiannis;

--
-- Name: recipe_thematic_categories; Type: TABLE; Schema: public; Owner: yiannis
--

CREATE TABLE public.recipe_thematic_categories (
    recipe_id integer,
    thematic_category_id integer
);


ALTER TABLE public.recipe_thematic_categories OWNER TO yiannis;

--
-- Name: recipe_tips; Type: TABLE; Schema: public; Owner: yiannis
--

CREATE TABLE public.recipe_tips (
    recipe_id integer,
    tip text
);


ALTER TABLE public.recipe_tips OWNER TO yiannis;

--
-- Name: recipes; Type: TABLE; Schema: public; Owner: yiannis
--

CREATE TABLE public.recipes (
    id integer NOT NULL,
    image_id integer,
    basic_ingredient_id integer,
    cooking_type public.cooking_type,
    cuisine integer,
    difficulty public.difficulty,
    name text,
    meal_group public.meal_group,
    servings integer
);


ALTER TABLE public.recipes OWNER TO yiannis;

--
-- Name: recipes_id_seq; Type: SEQUENCE; Schema: public; Owner: yiannis
--

CREATE SEQUENCE public.recipes_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.recipes_id_seq OWNER TO yiannis;

--
-- Name: recipes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: yiannis
--

ALTER SEQUENCE public.recipes_id_seq OWNED BY public.recipes.id;


--
-- Name: steps; Type: TABLE; Schema: public; Owner: yiannis
--

CREATE TABLE public.steps (
    id integer NOT NULL,
    image_id integer,
    description text,
    cooking_time integer,
    preparation_time integer
);


ALTER TABLE public.steps OWNER TO yiannis;

--
-- Name: steps_id_seq; Type: SEQUENCE; Schema: public; Owner: yiannis
--

CREATE SEQUENCE public.steps_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.steps_id_seq OWNER TO yiannis;

--
-- Name: steps_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: yiannis
--

ALTER SEQUENCE public.steps_id_seq OWNED BY public.steps.id;


--
-- Name: test; Type: TABLE; Schema: public; Owner: yiannis
--

CREATE TABLE public.test (
    id integer NOT NULL,
    calories integer
);


ALTER TABLE public.test OWNER TO yiannis;

--
-- Name: test2; Type: TABLE; Schema: public; Owner: yiannis
--

CREATE TABLE public.test2 (
    id integer NOT NULL,
    test_id integer,
    quantity integer
);


ALTER TABLE public.test2 OWNER TO yiannis;

--
-- Name: test2_id_seq; Type: SEQUENCE; Schema: public; Owner: yiannis
--

CREATE SEQUENCE public.test2_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.test2_id_seq OWNER TO yiannis;

--
-- Name: test2_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: yiannis
--

ALTER SEQUENCE public.test2_id_seq OWNED BY public.test2.id;


--
-- Name: test_id_seq; Type: SEQUENCE; Schema: public; Owner: yiannis
--

CREATE SEQUENCE public.test_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.test_id_seq OWNER TO yiannis;

--
-- Name: test_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: yiannis
--

ALTER SEQUENCE public.test_id_seq OWNED BY public.test.id;


--
-- Name: thematic_categories; Type: TABLE; Schema: public; Owner: yiannis
--

CREATE TABLE public.thematic_categories (
    id integer NOT NULL,
    image_id integer,
    name text,
    description text
);


ALTER TABLE public.thematic_categories OWNER TO yiannis;

--
-- Name: thematic_categories_id_seq; Type: SEQUENCE; Schema: public; Owner: yiannis
--

CREATE SEQUENCE public.thematic_categories_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.thematic_categories_id_seq OWNER TO yiannis;

--
-- Name: thematic_categories_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: yiannis
--

ALTER SEQUENCE public.thematic_categories_id_seq OWNED BY public.thematic_categories.id;


--
-- Name: users; Type: TABLE; Schema: public; Owner: yiannis
--

CREATE TABLE public.users (
    id integer NOT NULL,
    username text,
    password text,
    user_role public.user_role,
    auth_state boolean DEFAULT false
);


ALTER TABLE public.users OWNER TO yiannis;

--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: yiannis
--

CREATE SEQUENCE public.users_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.users_id_seq OWNER TO yiannis;

--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: yiannis
--

ALTER SEQUENCE public.users_id_seq OWNED BY public.users.id;


--
-- Name: content_images id; Type: DEFAULT; Schema: public; Owner: yiannis
--

ALTER TABLE ONLY public.content_images ALTER COLUMN id SET DEFAULT nextval('public.content_images_id_seq'::regclass);


--
-- Name: cuisines id; Type: DEFAULT; Schema: public; Owner: yiannis
--

ALTER TABLE ONLY public.cuisines ALTER COLUMN id SET DEFAULT nextval('public.cuisines_id_seq'::regclass);


--
-- Name: episodes id; Type: DEFAULT; Schema: public; Owner: yiannis
--

ALTER TABLE ONLY public.episodes ALTER COLUMN id SET DEFAULT nextval('public.episodes_id_seq'::regclass);


--
-- Name: episodes_cuisines_chefs id; Type: DEFAULT; Schema: public; Owner: yiannis
--

ALTER TABLE ONLY public.episodes_cuisines_chefs ALTER COLUMN id SET DEFAULT nextval('public.episodes_cuisines_chefs_id_seq'::regclass);


--
-- Name: equipment id; Type: DEFAULT; Schema: public; Owner: yiannis
--

ALTER TABLE ONLY public.equipment ALTER COLUMN id SET DEFAULT nextval('public.equipment_id_seq'::regclass);


--
-- Name: food_groups id; Type: DEFAULT; Schema: public; Owner: yiannis
--

ALTER TABLE ONLY public.food_groups ALTER COLUMN id SET DEFAULT nextval('public.food_groups_id_seq'::regclass);


--
-- Name: images id; Type: DEFAULT; Schema: public; Owner: yiannis
--

ALTER TABLE ONLY public.images ALTER COLUMN id SET DEFAULT nextval('public.images_id_seq'::regclass);


--
-- Name: ingredients id; Type: DEFAULT; Schema: public; Owner: yiannis
--

ALTER TABLE ONLY public.ingredients ALTER COLUMN id SET DEFAULT nextval('public.ingredients_id_seq'::regclass);


--
-- Name: marks id; Type: DEFAULT; Schema: public; Owner: yiannis
--

ALTER TABLE ONLY public.marks ALTER COLUMN id SET DEFAULT nextval('public.marks_id_seq'::regclass);


--
-- Name: recipes id; Type: DEFAULT; Schema: public; Owner: yiannis
--

ALTER TABLE ONLY public.recipes ALTER COLUMN id SET DEFAULT nextval('public.recipes_id_seq'::regclass);


--
-- Name: steps id; Type: DEFAULT; Schema: public; Owner: yiannis
--

ALTER TABLE ONLY public.steps ALTER COLUMN id SET DEFAULT nextval('public.steps_id_seq'::regclass);


--
-- Name: test id; Type: DEFAULT; Schema: public; Owner: yiannis
--

ALTER TABLE ONLY public.test ALTER COLUMN id SET DEFAULT nextval('public.test_id_seq'::regclass);


--
-- Name: test2 id; Type: DEFAULT; Schema: public; Owner: yiannis
--

ALTER TABLE ONLY public.test2 ALTER COLUMN id SET DEFAULT nextval('public.test2_id_seq'::regclass);


--
-- Name: thematic_categories id; Type: DEFAULT; Schema: public; Owner: yiannis
--

ALTER TABLE ONLY public.thematic_categories ALTER COLUMN id SET DEFAULT nextval('public.thematic_categories_id_seq'::regclass);


--
-- Name: users id; Type: DEFAULT; Schema: public; Owner: yiannis
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- Data for Name: chefs; Type: TABLE DATA; Schema: public; Owner: yiannis
--

COPY public.chefs (id, image_id, name, surname, phone_number, birth_date, experience, job_title) FROM stdin;
1	701	John	Doe	123-456-7890	1980-01-15	15	CHEF
2	702	Jane	Smith	234-567-8901	1985-03-22	10	SOUS_CHEF
3	703	Michael	Johnson	345-678-9012	1978-05-30	20	EXECUTIVE_CHEF
4	704	Emily	Williams	456-789-0123	1990-07-14	8	LINE_COOK
5	705	David	Brown	567-890-1234	1982-09-10	12	PASTRY_CHEF
6	706	Sarah	Jones	678-901-2345	1988-11-25	9	SOUS_CHEF
7	707	Chris	Garcia	789-012-3456	1975-12-05	22	CHEF
8	708	Laura	Martinez	890-123-4567	1991-04-18	7	LINE_COOK
9	709	James	Rodriguez	901-234-5678	1983-06-12	14	PASTRY_CHEF
10	710	Olivia	Davis	012-345-6789	1987-08-22	11	SOUS_CHEF
11	711	Daniel	Hernandez	123-456-7891	1979-02-17	18	CHEF
12	712	Sophia	Lopez	234-567-8902	1986-01-29	12	PASTRY_CHEF
13	713	Matthew	Gonzalez	345-678-9013	1992-10-14	5	LINE_COOK
14	714	Emma	Wilson	456-789-0124	1981-03-09	15	CHEF
15	715	Joseph	Anderson	567-890-1235	1989-07-27	10	SOUS_CHEF
16	716	Mia	Thomas	678-901-2346	1993-05-30	6	PASTRY_CHEF
17	717	Joshua	Taylor	789-012-3457	1984-09-15	13	LINE_COOK
18	718	Isabella	Moore	890-123-4568	1982-11-23	16	CHEF
19	719	Andrew	Martin	901-234-5679	1980-04-11	17	SOUS_CHEF
20	720	Charlotte	Lee	012-345-6790	1994-06-19	5	PASTRY_CHEF
21	721	William	Perez	123-456-7892	1977-08-25	20	EXECUTIVE_CHEF
22	722	Ava	White	234-567-8903	1989-12-20	8	SOUS_CHEF
23	723	Alexander	Harris	345-678-9014	1983-07-07	14	PASTRY_CHEF
24	724	Amelia	Clark	456-789-0125	1991-10-03	7	LINE_COOK
25	725	Ethan	Lewis	567-890-1236	1985-02-08	12	CHEF
26	726	Harper	Walker	678-901-2347	1992-01-21	5	PASTRY_CHEF
27	727	Jacob	Hall	789-012-3458	1980-03-14	18	SOUS_CHEF
28	728	Ella	Allen	890-123-4569	1987-05-05	11	CHEF
29	729	Benjamin	Young	901-234-5680	1988-07-18	10	SOUS_CHEF
30	730	Avery	King	012-345-6791	1990-11-09	9	PASTRY_CHEF
31	731	Sebastian	Wright	123-456-7893	1979-01-17	18	CHEF
32	732	Abigail	Lopez	234-567-8904	1986-03-11	12	SOUS_CHEF
33	733	Jack	Hill	345-678-9015	1981-05-21	15	PASTRY_CHEF
34	734	Scarlett	Scott	456-789-0126	1983-09-26	14	SOUS_CHEF
35	735	Henry	Green	567-890-1237	1982-11-17	17	CHEF
36	736	Emily	Adams	678-901-2348	1991-02-14	7	SOUS_CHEF
37	737	Ryan	Baker	789-012-3459	1985-06-03	10	PASTRY_CHEF
38	738	Aria	Nelson	890-123-4570	1993-10-07	6	LINE_COOK
39	739	Lucas	Carter	901-234-5681	1980-12-15	18	CHEF
40	740	Grace	Mitchell	012-345-6792	1987-01-19	10	SOUS_CHEF
41	741	Mason	Perez	123-456-7894	1984-04-29	13	PASTRY_CHEF
42	742	Sophie	Roberts	234-567-8905	1990-05-11	9	LINE_COOK
43	743	Logan	Campbell	345-678-9016	1982-07-23	16	CHEF
44	744	Lily	Gonzalez	456-789-0127	1989-09-13	8	SOUS_CHEF
45	745	Eli	Parker	567-890-1238	1981-11-30	15	PASTRY_CHEF
46	746	Zoe	Collins	678-901-2349	1992-02-26	6	LINE_COOK
47	747	Dylan	Edwards	789-012-3460	1980-05-16	19	CHEF
48	748	Riley	Turner	890-123-4571	1988-10-22	10	SOUS_CHEF
49	749	Gabriel	Morris	901-234-5682	1985-08-18	11	PASTRY_CHEF
50	750	Victoria	Nguyen	012-345-6793	1991-06-29	7	LINE_COOK
51	751	Liam	Murphy	123-456-7895	1983-02-14	14	CHEF
52	752	Ella	Ward	234-567-8906	1986-05-20	12	SOUS_CHEF
53	753	Nathan	Peterson	345-678-9017	1984-08-07	15	PASTRY_CHEF
54	754	Chloe	Sanchez	456-789-0128	1989-12-11	8	LINE_COOK
55	755	Christian	Bailey	567-890-1239	1990-09-03	9	SOUS_CHEF
56	756	Grace	Rivera	678-901-2340	1981-04-18	17	PASTRY_CHEF
57	757	Noah	Gray	789-012-3451	1992-01-05	6	LINE_COOK
58	758	Victoria	Kim	890-123-4562	1980-07-12	18	CHEF
59	759	David	Cruz	901-234-5673	1987-11-24	10	SOUS_CHEF
60	760	Layla	Bennett	012-345-6784	1984-05-22	13	PASTRY_CHEF
61	761	Christopher	Torres	123-456-7896	1991-03-11	7	LINE_COOK
62	762	Hannah	Howard	234-567-8907	1982-09-08	16	SOUS_CHEF
63	763	Jackson	Brooks	345-678-9018	1986-12-30	12	PASTRY_CHEF
64	764	Emily	Bell	456-789-0129	1990-06-13	9	LINE_COOK
65	765	Dylan	Sanders	567-890-1230	1983-10-27	14	CHEF
66	766	Anna	Price	678-901-2341	1988-07-14	8	SOUS_CHEF
67	767	Cameron	Jenkins	789-012-3452	1993-11-17	5	LINE_COOK
68	768	Madison	Mitchell	890-123-4563	1987-02-07	10	PASTRY_CHEF
69	769	Grayson	Sullivan	901-234-5674	1984-06-15	13	CHEF
70	770	Avery	Morris	012-345-6785	1989-09-10	8	SOUS_CHEF
71	771	Samuel	Myers	123-456-7897	1992-08-20	5	LINE_COOK
72	772	Victoria	Cook	234-567-8908	1980-01-13	18	PASTRY_CHEF
73	773	Luke	Cooper	345-678-9019	1983-03-18	15	CHEF
74	774	Layla	Bailey	456-789-0130	1985-04-23	12	SOUS_CHEF
75	775	Hunter	Watson	567-890-1231	1981-11-26	16	CHEF
76	776	Hannah	Jenkins	678-901-2342	1988-01-30	8	SOUS_CHEF
77	777	Aaron	Perry	789-012-3453	1990-10-28	9	LINE_COOK
78	778	Scarlett	Reed	890-123-4564	1992-07-22	6	PASTRY_CHEF
79	779	Eli	Foster	901-234-5675	1986-02-24	11	SOUS_CHEF
80	780	Brooklyn	Ward	012-345-6786	1984-08-05	13	CHEF
81	781	Gabriel	Wright	123-456-7898	1987-11-21	10	PASTRY_CHEF
82	782	Lily	Ramirez	234-567-8909	1990-12-17	7	LINE_COOK
83	783	Isaac	Flores	345-678-9020	1982-10-25	16	CHEF
84	784	Victoria	Bennett	456-789-0131	1989-05-12	9	SOUS_CHEF
85	785	Elijah	Bell	567-890-1232	1985-11-18	12	PASTRY_CHEF
86	786	Zoey	Coleman	678-901-2343	1991-04-21	6	LINE_COOK
87	787	Caleb	Jenkins	789-012-3454	1984-07-19	13	SOUS_CHEF
88	788	Samantha	Perry	890-123-4565	1983-06-16	15	CHEF
89	789	Nathan	Bennett	901-234-5676	1986-09-29	11	PASTRY_CHEF
90	790	Ava	Cruz	012-345-6787	1992-03-24	5	LINE_COOK
91	791	Aiden	Bailey	123-456-7899	1988-01-09	10	SOUS_CHEF
92	792	Madison	Gonzalez	234-567-8910	1982-11-13	16	CHEF
93	793	Oliver	Reed	345-678-9021	1990-08-30	7	LINE_COOK
94	794	Sophia	Mitchell	456-789-0132	1986-02-26	12	PASTRY_CHEF
95	795	Jackson	Phillips	567-890-1233	1989-04-15	9	SOUS_CHEF
96	796	Amelia	Stewart	678-901-2344	1985-07-04	13	CHEF
97	797	Benjamin	Barnes	789-012-3455	1983-12-14	15	PASTRY_CHEF
98	798	Mia	Howard	890-123-4566	1987-09-07	10	SOUS_CHEF
99	799	Evelyn	Evans	901-234-5677	1981-03-27	18	CHEF
100	800	Mason	Turner	012-345-6788	1992-10-12	6	LINE_COOK
101	801	Liam	James	123-456-7910	1985-04-17	12	PASTRY_CHEF
102	802	Charlotte	Lee	234-567-8920	1989-05-21	9	SOUS_CHEF
103	803	Elijah	Hughes	345-678-9030	1981-11-15	18	CHEF
104	804	Avery	Harris	456-789-0140	1992-06-16	5	LINE_COOK
105	805	Layla	Gomez	567-890-1250	1987-12-19	11	PASTRY_CHEF
106	806	Oliver	Ward	678-901-2350	1984-02-14	15	SOUS_CHEF
107	807	Sophia	Flores	789-012-3470	1989-10-23	9	LINE_COOK
108	808	Mason	Turner	890-123-4580	1981-06-22	17	CHEF
109	809	Madison	Roberts	901-234-5690	1985-12-11	11	PASTRY_CHEF
110	810	Logan	Jenkins	012-345-6794	1993-01-29	7	LINE_COOK
111	811	Victoria	Evans	123-456-7920	1984-03-13	16	SOUS_CHEF
112	812	Caleb	James	234-567-8930	1989-09-25	9	PASTRY_CHEF
113	813	Evelyn	Lee	345-678-9040	1982-04-26	14	CHEF
114	814	Aiden	Hughes	456-789-0150	1990-05-22	8	SOUS_CHEF
115	815	Brooklyn	Flores	567-890-1260	1985-10-21	12	PASTRY_CHEF
116	816	Noah	Gonzalez	678-901-2360	1984-08-27	13	CHEF
117	817	Liam	Ramirez	789-012-3480	1993-11-16	5	LINE_COOK
118	818	Chloe	Harris	890-123-4590	1986-02-20	10	SOUS_CHEF
119	819	Christian	Ward	901-234-5700	1983-07-11	15	PASTRY_CHEF
120	820	Zoey	Flores	012-345-6800	1991-09-09	8	LINE_COOK
121	821	David	Cook	123-456-7930	1987-05-04	12	SOUS_CHEF
122	822	Hannah	Evans	234-567-8940	1982-06-13	16	CHEF
123	823	Emily	Hughes	345-678-9050	1990-09-03	7	LINE_COOK
124	824	Mason	Ramirez	456-789-0160	1986-12-14	11	PASTRY_CHEF
125	825	Victoria	Gomez	567-890-1270	1983-10-07	14	SOUS_CHEF
126	826	Jackson	Turner	678-901-2370	1992-11-01	6	LINE_COOK
127	827	Charlotte	Gonzalez	789-012-3490	1989-01-15	10	PASTRY_CHEF
128	828	Aiden	Flores	890-123-4600	1981-05-29	17	CHEF
129	829	Samantha	Jenkins	901-234-5710	1985-06-09	13	SOUS_CHEF
130	830	Gabriel	Harris	012-345-6810	1993-08-25	5	LINE_COOK
131	831	Ava	Cook	123-456-7940	1986-09-22	12	PASTRY_CHEF
132	832	Eli	Evans	234-567-8950	1982-03-31	15	SOUS_CHEF
133	833	Grayson	Hughes	345-678-9060	1988-11-27	10	LINE_COOK
134	834	Layla	Ramirez	456-789-0170	1984-08-16	16	CHEF
135	835	Victoria	Flores	567-890-1280	1985-05-02	13	PASTRY_CHEF
136	836	Lily	Ward	678-901-2380	1990-11-06	9	SOUS_CHEF
137	837	Caleb	Turner	789-012-3500	1989-02-28	7	LINE_COOK
138	838	David	Jenkins	890-123-4610	1981-12-17	18	CHEF
139	839	Sophie	Harris	901-234-5720	1987-03-12	11	PASTRY_CHEF
140	840	Emily	Cook	012-345-6820	1984-06-21	14	SOUS_CHEF
141	841	Liam	Evans	123-456-7950	1992-07-04	6	LINE_COOK
142	842	Olivia	Hughes	234-567-8960	1988-10-26	9	SOUS_CHEF
143	843	Madison	Ramirez	345-678-9070	1981-01-13	16	CHEF
144	844	Henry	Flores	456-789-0180	1989-06-28	8	PASTRY_CHEF
145	845	Victoria	Ward	567-890-1290	1984-09-05	13	SOUS_CHEF
146	846	Liam	Turner	678-901-2390	1990-04-03	5	LINE_COOK
147	847	Scarlett	Jenkins	789-012-3510	1983-08-09	15	PASTRY_CHEF
148	848	Chloe	Harris	890-123-4620	1986-11-27	11	SOUS_CHEF
149	849	Ethan	Cook	901-234-5730	1992-05-08	6	LINE_COOK
150	850	Grace	Evans	012-345-6830	1985-12-24	13	PASTRY_CHEF
\.


--
-- Data for Name: content_images; Type: TABLE DATA; Schema: public; Owner: yiannis
--

COPY public.content_images (id, description) FROM stdin;
\.


--
-- Data for Name: cuisines; Type: TABLE DATA; Schema: public; Owner: yiannis
--

COPY public.cuisines (id, image_id, name) FROM stdin;
1	401	Ελληνική Κουζίνα
2	402	Ιταλική Κουζίνα
3	403	Γαλλική Κουζίνα
4	404	Ισπανική Κουζίνα
5	405	Μεξικάνικη Κουζίνα
6	406	Ινδική Κουζίνα
7	407	Κινέζικη Κουζίνα
8	408	Ιαπωνική Κουζίνα
9	409	Ταϊλανδέζικη Κουζίνα
10	410	Βιετναμέζικη Κουζίνα
11	411	Τουρκική Κουζίνα
12	412	Λιβανέζικη Κουζίνα
13	413	Κορεάτικη Κουζίνα
14	414	Βραζιλιάνικη Κουζίνα
15	415	Αργεντίνικη Κουζίνα
16	416	Μαροκινή Κουζίνα
17	417	Ρωσική Κουζίνα
18	418	Αιγυπτιακή Κουζίνα
19	419	Νιγηριανή Κουζίνα
20	420	Ελβετική Κουζίνα
\.


--
-- Data for Name: episodes; Type: TABLE DATA; Schema: public; Owner: yiannis
--

COPY public.episodes (id, image_id, season) FROM stdin;
1	801	1
2	802	1
3	803	1
4	804	1
5	805	1
6	806	1
7	807	1
8	808	1
9	809	1
10	810	1
11	811	2
12	812	2
13	813	2
14	814	2
15	815	2
16	816	2
17	817	2
18	818	2
19	819	2
20	820	2
21	821	3
22	822	3
23	823	3
24	824	3
25	825	3
26	826	3
27	827	3
28	828	3
29	829	3
30	830	3
31	831	4
32	832	4
33	833	4
34	834	4
35	835	4
36	836	4
37	837	4
38	838	4
39	839	4
40	840	4
41	841	5
42	842	5
43	843	5
44	844	5
45	845	5
46	846	5
47	847	5
48	848	5
49	849	5
50	850	5
\.


--
-- Data for Name: episodes_cuisines; Type: TABLE DATA; Schema: public; Owner: yiannis
--

COPY public.episodes_cuisines (episode_id, cuisine_id) FROM stdin;
1	1
1	2
1	3
1	4
1	5
1	6
1	7
1	8
1	9
1	10
2	11
2	12
2	13
2	14
2	15
2	16
2	17
2	18
2	19
2	20
3	1
3	2
3	3
3	4
3	5
3	6
3	7
3	8
3	9
3	10
4	11
4	12
4	13
4	14
4	15
4	16
4	17
4	18
4	19
4	20
5	1
5	2
5	3
5	4
5	5
5	6
5	7
5	8
5	9
5	10
6	11
6	12
6	13
6	14
6	15
6	16
6	17
6	18
6	19
6	20
7	1
7	2
7	3
7	4
7	5
7	6
7	7
7	8
7	9
7	10
8	11
8	12
8	13
8	14
8	15
8	16
8	17
8	18
8	19
8	20
9	1
9	2
9	3
9	4
9	5
9	6
9	7
9	8
9	9
9	10
10	11
10	12
10	13
10	14
10	15
10	16
10	17
10	18
10	19
10	20
11	1
11	2
11	3
11	4
11	5
11	6
11	7
11	8
11	9
11	10
12	11
12	12
12	13
12	14
12	15
12	16
12	17
12	18
12	19
12	20
13	1
13	2
13	3
13	4
13	5
13	6
13	7
13	8
13	9
13	10
14	11
14	12
14	13
14	14
14	15
14	16
14	17
14	18
14	19
14	20
15	1
15	2
15	3
15	4
15	5
15	6
15	7
15	8
15	9
15	10
16	11
16	12
16	13
16	14
16	15
16	16
16	17
16	18
16	19
16	20
17	1
17	2
17	3
17	4
17	5
17	6
17	7
17	8
17	9
17	10
18	11
18	12
18	13
18	14
18	15
18	16
18	17
18	18
18	19
18	20
19	1
19	2
19	3
19	4
19	5
19	6
19	7
19	8
19	9
19	10
20	11
20	12
20	13
20	14
20	15
20	16
20	17
20	18
20	19
20	20
21	1
21	2
21	3
21	4
21	5
21	6
21	7
21	8
21	9
21	10
22	11
22	12
22	13
22	14
22	15
22	16
22	17
22	18
22	19
22	20
23	1
23	2
23	3
23	4
23	5
23	6
23	7
23	8
23	9
23	10
24	11
24	12
24	13
24	14
24	15
24	16
24	17
24	18
24	19
24	20
25	1
25	2
25	3
25	4
25	5
25	6
25	7
25	8
25	9
25	10
26	11
26	12
26	13
26	14
26	15
26	16
26	17
26	18
26	19
26	20
27	1
27	2
27	3
27	4
27	5
27	6
27	7
27	8
27	9
27	10
28	11
28	12
28	13
28	14
28	15
28	16
28	17
28	18
28	19
28	20
29	1
29	2
29	3
29	4
29	5
29	6
29	7
29	8
29	9
29	10
30	11
30	12
30	13
30	14
30	15
30	16
30	17
30	18
30	19
30	20
31	1
31	2
31	3
31	4
31	5
31	6
31	7
31	8
31	9
31	10
32	11
32	12
32	13
32	14
32	15
32	16
32	17
32	18
32	19
32	20
33	1
33	2
33	3
33	4
33	5
33	6
33	7
33	8
33	9
33	10
34	11
34	12
34	13
34	14
34	15
34	16
34	17
34	18
34	19
34	20
35	1
35	2
35	3
35	4
35	5
35	6
35	7
35	8
35	9
35	10
36	11
36	12
36	13
36	14
36	15
36	16
36	17
36	18
36	19
36	20
37	1
37	2
37	3
37	4
37	5
37	6
37	7
37	8
37	9
37	10
38	11
38	12
38	13
38	14
38	15
38	16
38	17
38	18
38	19
38	20
39	1
39	2
39	3
39	4
39	5
39	6
39	7
39	8
39	9
39	10
40	11
40	12
40	13
40	14
40	15
40	16
40	17
40	18
40	19
40	20
41	1
41	2
41	3
41	4
41	5
41	6
41	7
41	8
41	9
41	10
42	11
42	12
42	13
42	14
42	15
42	16
42	17
42	18
42	19
42	20
43	1
43	2
43	3
43	4
43	5
43	6
43	7
43	8
43	9
43	10
44	11
44	12
44	13
44	14
44	15
44	16
44	17
44	18
44	19
44	20
45	1
45	2
45	3
45	4
45	5
45	6
45	7
45	8
45	9
45	10
46	11
46	12
46	13
46	14
46	15
46	16
46	17
46	18
46	19
46	20
47	1
47	2
47	3
47	4
47	5
47	6
47	7
47	8
47	9
47	10
48	11
48	12
48	13
48	14
48	15
48	16
48	17
48	18
48	19
48	20
49	1
49	2
49	3
49	4
49	5
49	6
49	7
49	8
49	9
49	10
50	11
50	12
50	13
50	14
50	15
50	16
50	17
50	18
50	19
50	20
\.


--
-- Data for Name: episodes_cuisines_chefs; Type: TABLE DATA; Schema: public; Owner: yiannis
--

COPY public.episodes_cuisines_chefs (id, episode_id, cuisine_id, chef_id, recipe_id) FROM stdin;
1	1	1	1	1
2	1	1	2	21
3	1	1	3	41
4	1	2	11	2
5	1	2	12	22
6	1	2	13	42
7	1	3	21	3
8	1	3	22	23
9	1	3	23	43
10	1	4	31	4
11	1	4	32	24
12	1	4	33	44
13	1	5	41	5
14	1	5	42	25
15	1	5	43	45
16	1	6	51	6
17	1	6	52	26
18	1	6	53	46
19	1	7	61	7
20	1	7	62	27
21	1	7	63	47
22	1	8	71	8
23	1	8	72	28
24	1	8	73	48
25	1	9	81	9
26	1	9	82	29
27	1	9	83	49
28	1	10	91	10
29	1	10	92	30
30	1	10	93	50
31	2	11	101	11
32	2	11	102	31
33	2	12	111	12
34	2	12	112	32
35	2	13	121	13
36	2	13	122	33
37	2	14	131	14
38	2	14	132	34
39	2	15	141	15
40	2	15	142	35
41	2	16	1	16
42	2	16	2	36
43	2	17	11	17
44	2	17	12	37
45	2	18	21	18
46	2	18	22	38
47	2	19	31	19
48	2	19	32	39
49	2	20	41	20
50	2	20	42	40
51	3	1	51	1
52	3	1	52	21
53	3	1	53	41
54	3	2	61	2
55	3	2	62	22
56	3	2	63	42
57	3	3	71	3
58	3	3	72	23
59	3	3	73	43
60	3	4	81	4
61	3	4	82	24
62	3	4	83	44
63	3	5	91	5
64	3	5	92	25
65	3	5	93	45
66	3	6	101	6
67	3	6	102	26
68	3	6	103	46
69	3	7	111	7
70	3	7	112	27
71	3	7	113	47
72	3	8	121	8
73	3	8	122	28
74	3	8	123	48
75	3	9	131	9
76	3	9	132	29
77	3	9	133	49
78	3	10	141	30
79	3	10	142	50
80	4	11	1	11
81	4	11	2	31
82	4	12	11	12
83	4	12	12	32
84	4	13	21	13
85	4	13	22	33
86	4	14	31	14
87	4	14	32	34
88	4	15	41	15
89	4	15	42	35
90	4	16	51	16
91	4	16	52	36
92	4	17	61	17
93	4	17	62	37
94	4	18	71	18
95	4	18	72	38
96	4	19	81	19
97	4	19	82	39
98	4	20	91	20
99	4	20	92	40
100	5	1	101	1
101	5	1	102	21
102	5	1	103	41
103	5	2	111	2
104	5	2	112	22
105	5	2	113	42
106	5	3	121	3
107	5	3	122	23
108	5	3	123	43
109	5	4	131	4
110	5	4	132	24
111	5	4	133	44
112	5	5	141	5
113	5	5	142	25
114	5	5	143	45
115	5	6	1	6
116	5	6	2	26
117	5	6	3	46
118	5	7	11	7
119	5	7	12	27
120	5	7	13	47
121	5	8	21	8
122	5	8	22	28
123	5	8	23	48
124	5	9	31	9
125	5	9	32	29
126	5	9	33	49
127	5	10	41	30
128	5	10	42	50
\.


--
-- Data for Name: equipment; Type: TABLE DATA; Schema: public; Owner: yiannis
--

COPY public.equipment (id, image_id, name, instructions) FROM stdin;
1	301	Μίξερ χειρός	Χρησιμοποιήστε το για να ανακατέψετε υλικά και να χτυπήσετε αυγά ή κρέμες.
2	302	Μίξερ βάσης	Ιδανικό για ζύμωμα ζύμης και ανακάτεμα βαριών μειγμάτων.
3	303	Μπλέντερ	Χρησιμοποιήστε το για να φτιάξετε smoothies, σάλτσες και να πολτοποιήσετε υλικά.
4	304	Κόφτης λαχανικών	Χρησιμοποιήστε το για να κόψετε και να τεμαχίσετε λαχανικά γρήγορα και ομοιόμορφα.
5	305	Ζυγαριά κουζίνας	Ζυγίστε τα υλικά σας για ακριβείς μετρήσεις στις συνταγές.
6	306	Μαντολίνο	Χρησιμοποιήστε το για να κόψετε λαχανικά σε λεπτές, ομοιόμορφες φέτες.
7	307	Γουδί και γουδοχέρι	Χρησιμοποιήστε το για να πολτοποιήσετε μπαχαρικά και βότανα.
8	308	Τρίφτης	Χρησιμοποιήστε το για να τρίψετε τυρί, λαχανικά ή φρούτα.
9	309	Κουτάλα	Χρησιμοποιήστε την για να ανακατέψετε και να σερβίρετε σούπες και σάλτσες.
10	310	Μαχαίρι σεφ	Χρησιμοποιήστε το για να κόψετε, να τεμαχίσετε και να φιλετάρετε κρέας και λαχανικά.
11	311	Μαχαίρι ξεφλουδίσματος	Χρησιμοποιήστε το για να ξεφλουδίσετε φρούτα και λαχανικά.
12	312	Μαχαίρι ψωμιού	Χρησιμοποιήστε το για να κόψετε ψωμί και άλλα αρτοσκευάσματα.
13	313	Ξύλινη κουτάλα	Χρησιμοποιήστε την για να ανακατέψετε ζεστά φαγητά χωρίς να χαράξετε τα σκεύη μαγειρικής.
14	314	Σπάτουλα	Χρησιμοποιήστε την για να αναποδογυρίσετε και να σερβίρετε φαγητά από τηγάνι ή σχάρα.
15	315	Σχάρα φούρνου	Χρησιμοποιήστε την για να ψήσετε φαγητά στο φούρνο ομοιόμορφα.
16	316	Ταψί	Χρησιμοποιήστε το για να ψήσετε φαγητά στον φούρνο.
17	317	Κατσαρόλα	Χρησιμοποιήστε την για να βράσετε νερό, σούπες και μαγειρευτά.
18	318	Τηγάνι	Χρησιμοποιήστε το για να τηγανίσετε και να σοτάρετε φαγητά.
19	319	Καφετιέρα	Χρησιμοποιήστε την για να φτιάξετε καφέ.
20	320	Πίτσα πέτρα	Χρησιμοποιήστε την για να ψήσετε πίτσα με τραγανή βάση.
21	321	Ανοιχτήρι κονσέρβας	Χρησιμοποιήστε το για να ανοίξετε κονσέρβες.
22	322	Πρέσα σκόρδου	Χρησιμοποιήστε την για να λιώσετε σκόρδο γρήγορα και εύκολα.
23	323	Σουρωτήρι	Χρησιμοποιήστε το για να στραγγίσετε νερό από μαγειρεμένα φαγητά όπως ζυμαρικά.
24	324	Μπουκαλοανοικτήρι	Χρησιμοποιήστε το για να ανοίξετε μπουκάλια με καπάκι.
25	325	Τσουγκράνα κρέατος	Χρησιμοποιήστε την για να γυρίσετε και να μετακινήσετε μεγάλα κομμάτια κρέατος κατά το ψήσιμο.
\.


--
-- Data for Name: food_groups; Type: TABLE DATA; Schema: public; Owner: yiannis
--

COPY public.food_groups (id, image_id, name, description) FROM stdin;
1	\N	Λαχανικά	Όλα τα ωμά λαχανικά, π.χ., μαρούλι, λάχανο, καρότο, ντομάτα, αγγούρι, κρεμμύδι κ.ά.\nΌλα τα μαγειρεμένα λαχανικά, π.χ., μπρόκολο, κουνουπίδι, κολοκυθάκια, χόρτα, παντζάρια κ.ά.\nΤα αμυλώδη λαχανικά, π.χ., αρακάς, καλαμπόκι, κολοκύθα\nΔΕΝ περιλαμβάνεται η πατάτα και οι ποικιλίες της
2	\N	Φρούτα	Όλα τα ωμά φρούτα, π.χ., πορτοκάλι, μήλο, αχλάδι, μπανάνα, ροδάκινο κ.ά.\nΌλα τα αποξηραμένα φρούτα, π.χ., δαμάσκηνα, σταφίδες, βερίκοκα κ.ά.\nΟι φυσικοί χυμοί φρούτων (100% χωρίς προσθήκη ζάχαρης).
3	\N	Δημητριακά (ψωμί, ρύζι, ζυμαρικά) και Πατάτες	Τα δημητριακά\nΣιτάρι, βρόμη, κριθάρι, σίκαλη κ.ά.\nΡύζι\n\nΤα προϊόντα δημητριακών\nΑλεύρι\nΨωμί\nΑπλά αρτοσκευάσματα, π.χ., φρυγανιές, παξιμάδια, κριτσίνια, κράκερ\nΣύνθετα αρτοσκευάσματα, π.χ., ζύμες, πίτες\nΖυμαρικά, π.χ., μακαρόνια, κριθαράκι, χυλοπίτες\nΔιάφορα προϊόντα δημητριακών, π.χ., πλιγούρι,τραχανάς\nΔημητριακά πρωινού\nΗ πατάτα και οι ποικιλίες της
4	\N	Γάλα και γαλακτοκομικά προϊόντα	Το γάλα\nΤα γαλακτοκομικά προϊόντα, π.χ., γιαούρτι, τυρί, ξινόγαλο κ.ά.\nΔΕΝ περιλαμβάνεται το βούτυρο (συγκαταλέγεται στα λίπη και έλαια)
5	\N	Όσπρια	Οι φακές\nΤα φασόλια\nΤα ρεβίθια\nΗ φάβα\nΤα ξερά κουκιά\nΟι ποικιλίες όλων των παραπάνω
6	\N	Κόκκινο κρέας	Μοσχάρι, βοδινό\nΧοιρινό\nΑρνί, πρόβατο\nΚατσίκι, γίδα\nΚυνήγι: π.χ., αγριογούρουνο, ελάφι, ζαρκάδι\nΌλα τα επεξεργασμένα προϊόντα των παραπάνω
7	\N	Λευκό κρέας	Κοτόπουλο\nΓαλοπούλα\nΠάπια\nΚουνέλι\nΚυνήγι: π.χ., φασιανός, ορτύκι, πέρδικα\nΌλα τα επεξεργασμένα προϊόντα των παραπάνω
8	\N	Αυγά	Αυγά
9	\N	Ψάρια και θαλασσινά	Τα ψάρια, π.χ., σαρδέλα, μαρίδα, γόπα, γαύρος, αθερίνα, ροφός, συναγρίδα, σφυρίδα, μπακαλιάρος, γαλέος, τόνος, λαβράκι, σαργός, τσιπούρα, λυθρίνι\nΤα θαλασσινά (μαλάκια, οστρακοειδή, οστρακόδερμα), π.χ., καλαμάρι, σουπιά, χταπόδι, γαρίδα, μύδια, στρείδια.
10	\N	Προστιθέμενα λίπη και ελαία, ελιές και ξηροί καρποί	Τα προστιθέμενα λίπη και έλαια:\nΕλαιόλαδο\nΆλλα έλαια φυτικής προέλευσης (σπορέλαια): ηλιέλαιο, καλαμποκέλαιο, σογιέλαιο, σησαμέλαιο κ.ά.\nΜαργαρίνη\nΒούτυρο\nΟι ελιές\nΟι ξηροί καρποί\nΚαρύδια, αμύγδαλα, φιστίκια, φουντούκια κ.ά.\nΗλιόσποροι, σουσάμι κ.ά.\nΠροϊόντα επάλειψης που προέρχονται από τα παραπάνω (π.χ., ταχίνι)
\.


--
-- Data for Name: images; Type: TABLE DATA; Schema: public; Owner: yiannis
--

COPY public.images (id, description) FROM stdin;
101	Μαρούλι
102	Ντομάτα
103	Καρότο
104	Αγγούρι
105	Κρεμμύδι
106	Μπρόκολο
107	Κουνουπίδι
108	Κολοκυθάκια
109	Χόρτα
110	Παντζάρια
111	Αρακάς
112	Καλαμπόκι
113	Κολοκύθα
114	Πορτοκάλι
115	Μήλο
116	Αχλάδι
117	Μπανάνα
118	Ροδάκινο
119	Δαμάσκηνα
120	Σταφίδες
121	Βερίκοκα
122	Φυσικός Χυμός Πορτοκάλι
123	Σιτάρι
124	Βρόμη
125	Κριθάρι
126	Σίκαλη
127	Ρύζι
128	Αλεύρι
129	Ψωμί
130	Φρυγανιές
131	Παξιμάδια
132	Κριτσίνια
133	Κράκερ
134	Πίτες
135	Μακαρόνια
136	Κριθαράκι
137	Χυλοπίτες
138	Πλιγούρι
139	Τραχανάς
140	Δημητριακά Πρωινού
141	Πατάτες
142	Γάλα
143	Γιαούρτι
144	Τυρί
145	Ξινόγαλο
146	Φακές
147	Φασόλια
148	Ρεβίθια
149	Φάβα
150	Ξερά Κουκιά
151	Μοσχάρι
152	Βοδινό
153	Χοιρινό
154	Αρνί
155	Πρόβατο
156	Κατσίκι
157	Γίδα
158	Αγριογούρουνο
159	Ελάφι
160	Ζαρκάδι
161	Κοτόπουλο
162	Γαλοπούλα
163	Πάπια
164	Κουνέλι
165	Φασιανός
166	Ορτύκι
167	Πέρδικα
168	Αυγό
169	Σαρδέλα
170	Μαρίδα
171	Γόπα
172	Γαύρος
173	Αθερίνα
174	Ροφός
175	Συναγρίδα
176	Σφυρίδα
177	Μπακαλιάρος
178	Γαλέος
179	Τόνος
180	Λαβράκι
181	Σαργός
182	Τσιπούρα
183	Λυθρίνι
184	Καλαμάρι
185	Σουπιά
186	Χταπόδι
187	Γαρίδα
188	Μύδια
189	Στρείδια
190	Ελαιόλαδο
191	Ηλιέλαιο
192	Καλαμποκέλαιο
193	Σογιέλαιο
194	Σησαμέλαιο
195	Μαργαρίνη
196	Βούτυρο
197	Ελιές
198	Καρύδια
199	Αμύγδαλα
200	Φιστίκια
201	συνταγές του χωρίου
202	ριζότο συνταγές
203	πασχαλινά γλυκά
204	χειμωνιάτικες σούπες
205	καλοκαιρινά σαλάτες
206	συνταγές για παιδιά
207	χορτοφαγικές συνταγές
208	συνταγές με ψάρι
209	χριστουγεννιάτικα γλυκά
210	συνταγές με κοτόπουλο
211	νηστίσιμες συνταγές
212	συνταγές με ζυμαρικά
213	συνταγές με κρέας
214	γρήγορες συνταγές
215	εορταστικές συνταγές
216	συνταγές με λαχανικά
217	συνταγές για πάρτι
218	διεθνείς συνταγές
219	ελαφριά γεύματα
220	συνταγές με αυγά
301	Μίξερ χειρός
302	Μίξερ βάσης
303	Μπλέντερ
304	Κόφτης λαχανικών
305	Ζυγαριά κουζίνας
306	Μαντολίνο
307	Γουδί και γουδοχέρι
308	Τρίφτης
309	Κουτάλα
310	Μαχαίρι σεφ
311	Μαχαίρι ξεφλουδίσματος
312	Μαχαίρι ψωμιού
313	Ξύλινη κουτάλα
314	Σπάτουλα
315	Σχάρα φούρνου
316	Ταψί
317	Κατσαρόλα
318	Τηγάνι
319	Καφετιέρα
320	Πίτσα πέτρα
321	Ανοιχτήρι κονσέρβας
322	Πρέσα σκόρδου
323	Σουρωτήρι
324	Μπουκαλοανοικτήρι
325	Τσουγκράνα κρέατος
401	Ελληνική Κουζίνα
402	Ιταλική Κουζίνα
403	Γαλλική Κουζίνα
404	Ισπανική Κουζίνα
405	Μεξικάνικη Κουζίνα
406	Ινδική Κουζίνα
407	Κινέζικη Κουζίνα
408	Ιαπωνική Κουζίνα
409	Ταϊλανδέζικη Κουζίνα
410	Βιετναμέζικη Κουζίνα
411	Τουρκική Κουζίνα
412	Λιβανέζικη Κουζίνα
413	Κορεάτικη Κουζίνα
414	Βραζιλιάνικη Κουζίνα
415	Αργεντίνικη Κουζίνα
416	Μαροκινή Κουζίνα
417	Ρωσική Κουζίνα
418	Αιγυπτιακή Κουζίνα
419	Νιγηριανή Κουζίνα
420	Ελβετική Κουζίνα
501	Μουσακάς
502	Πίτσα Μαργαρίτα
503	Κρουασάν
504	Τορτίγιας
505	Τακος
506	Τσάτνεϊ Μάνγκο
507	Ντάμπλινγκς
508	Σούσι
509	Πανγκατζές
510	Φο Μπο
511	Μπακλαβάς
512	Χούμους
513	Κίμτσι
514	Μπριγκαντέιρο
515	Εμπανάδας
516	Ταζίν
517	Μπλινί
518	Φαλάφελ
519	Τζολοφ Ράις
520	Ρακλέτ
521	Χωριάτικη Σαλάτα
522	Λαζάνια
523	Κρέπες
524	Παέγια
525	Κεσαδίγιας
526	Κόρμα
527	Σπρίνγκ Ρολς
528	Ραμέν
529	Πανγκατζές με σιρόπι
530	Γκοϊ Κουόν
531	Κανταΐφι
532	Ταμπουλέ
533	Μπουλγκόγκι
534	Πάο ντε Κέιζο
535	Τσουριπάνος
536	Χάριρα
537	Σιρόπ Κούλτ
538	Σακσούκα
539	Ακάρα
540	Φοντί
541	Σπανακόπιτα
542	Τιραμισού
543	Μακαρόν
544	Τορτίγια
545	Γκουακαμόλε
546	Κάρι
547	Γουόντον
548	Τεμπούρα
549	Μπάο
550	Νεμ
601	Preheat the oven to 180°C.
602	Chop the vegetables.
603	Mix all ingredients in a bowl.
604	Bake for 30 minutes.
605	Let it cool for 10 minutes.
606	Boil water in a pot.
607	Cook pasta until al dente.
608	Slice the bread.
609	Spread sauce on the bread.
610	Grill the bread for 5 minutes.
611	Whisk the eggs in a bowl.
612	Heat oil in a pan.
613	Fry the eggs until fully cooked.
614	Peel and dice the potatoes.
615	Cook potatoes in boiling water for 15 minutes.
616	Mash the potatoes.
617	Sauté onions until golden brown.
618	Add garlic and cook for 2 minutes.
619	Simmer the sauce for 20 minutes.
620	Marinate the meat for 30 minutes.
621	Grill the meat for 15 minutes.
622	Let the meat rest for 10 minutes.
623	Prepare the dressing.
624	Toss the salad with dressing.
625	Serve chilled.
626	Blend the ingredients until smooth.
627	Chill in the refrigerator for 1 hour.
628	Serve with a garnish of choice.
629	Heat milk in a saucepan.
630	Stir in the chocolate until melted.
631	Pour into cups and serve hot.
632	Prepare the dough.
633	Let the dough rise for 1 hour.
634	Bake the dough for 25 minutes.
635	Cut the dough into pieces.
636	Season the meat with salt and pepper.
637	Sear the meat on high heat.
638	Roast the meat in the oven for 20 minutes.
639	Prepare the sauce.
640	Drizzle the sauce over the meat.
641	Mix the dry ingredients.
642	Add wet ingredients and mix until combined.
643	Pour batter into a baking dish.
644	Bake for 35 minutes.
645	Let it cool before slicing.
646	Preheat the grill to high heat.
647	Grill the vegetables until tender.
648	Chop the herbs.
649	Mix the herbs with olive oil.
650	Drizzle the herb oil over the vegetables.
651	Chill the dough for 30 minutes.
652	Roll out the dough to 1/4 inch thick.
653	Cut out shapes using a cookie cutter.
654	Place the shapes on a baking sheet.
655	Bake the cookies for 12 minutes.
656	Decorate the cookies after they cool.
657	Whisk together the dressing ingredients.
658	Pour the dressing over the salad and toss to coat.
659	Top with nuts and seeds.
660	Serve the salad immediately.
701	Chef John Doe
702	Sous Chef Jane Smith
703	Executive Chef Michael Johnson
704	Line Cook Emily Williams
705	Pastry Chef David Brown
706	Sous Chef Sarah Jones
707	Chef Chris Garcia
708	Line Cook Laura Martinez
709	Pastry Chef James Rodriguez
710	Sous Chef Olivia Davis
711	Chef Daniel Hernandez
712	Pastry Chef Sophia Lopez
713	Line Cook Matthew Gonzalez
714	Chef Emma Wilson
715	Sous Chef Joseph Anderson
716	Pastry Chef Mia Thomas
717	Line Cook Joshua Taylor
718	Chef Isabella Moore
719	Sous Chef Andrew Martin
720	Pastry Chef Charlotte Lee
721	Executive Chef William Perez
722	Sous Chef Ava White
723	Pastry Chef Alexander Harris
724	Line Cook Amelia Clark
725	Chef Ethan Lewis
726	Pastry Chef Harper Walker
727	Sous Chef Jacob Hall
728	Chef Ella Allen
729	Sous Chef Benjamin Young
730	Pastry Chef Avery King
731	Chef Sebastian Wright
732	Sous Chef Abigail Lopez
733	Pastry Chef Jack Hill
734	Sous Chef Scarlett Scott
735	Chef Henry Green
736	Sous Chef Emily Adams
737	Pastry Chef Ryan Baker
738	Line Cook Aria Nelson
739	Chef Lucas Carter
740	Sous Chef Grace Mitchell
741	Pastry Chef Mason Perez
742	Line Cook Sophie Roberts
743	Chef Logan Campbell
744	Sous Chef Lily Gonzalez
745	Pastry Chef Eli Parker
746	Line Cook Zoe Collins
747	Chef Dylan Edwards
748	Sous Chef Riley Turner
749	Pastry Chef Gabriel Morris
750	Line Cook Victoria Nguyen
751	Chef Liam Murphy
752	Sous Chef Ella Ward
753	Pastry Chef Nathan Peterson
754	Line Cook Chloe Sanchez
755	Sous Chef Christian Bailey
756	Pastry Chef Grace Rivera
757	Line Cook Noah Gray
758	Chef Victoria Kim
759	Sous Chef David Cruz
760	Pastry Chef Layla Bennett
761	Line Cook Christopher Torres
762	Sous Chef Hannah Howard
763	Pastry Chef Jackson Brooks
764	Line Cook Emily Bell
765	Chef Dylan Sanders
766	Sous Chef Anna Price
767	Line Cook Cameron Jenkins
768	Pastry Chef Madison Mitchell
769	Chef Grayson Sullivan
770	Sous Chef Avery Morris
771	Line Cook Samuel Myers
772	Pastry Chef Victoria Cook
773	Chef Luke Cooper
774	Sous Chef Layla Bailey
775	Chef Hunter Watson
776	Sous Chef Hannah Jenkins
777	Line Cook Aaron Perry
778	Pastry Chef Scarlett Reed
779	Sous Chef Eli Foster
780	Chef Brooklyn Ward
781	Pastry Chef Gabriel Wright
782	Line Cook Lily Ramirez
783	Chef Isaac Flores
784	Sous Chef Victoria Bennett
785	Pastry Chef Elijah Bell
786	Line Cook Zoey Coleman
787	Sous Chef Caleb Jenkins
788	Chef Samantha Perry
789	Pastry Chef Nathan Bennett
790	Line Cook Ava Cruz
791	Sous Chef Aiden Bailey
792	Chef Madison Gonzalez
793	Line Cook Oliver Reed
794	Pastry Chef Sophia Mitchell
795	Sous Chef Jackson Phillips
796	Chef Amelia Stewart
797	Pastry Chef Benjamin Barnes
798	Sous Chef Mia Howard
799	Chef Evelyn Evans
800	Line Cook Mason Turner
801	Pastry Chef Liam James
802	Sous Chef Charlotte Lee
803	Chef Elijah Hughes
804	Line Cook Avery Harris
805	Pastry Chef Layla Gomez
806	Sous Chef Oliver Ward
807	Line Cook Sophia Flores
808	Chef Mason Turner
809	Pastry Chef Madison Roberts
810	Line Cook Logan Jenkins
811	Sous Chef Victoria Evans
812	Pastry Chef Caleb James
813	Chef Evelyn Lee
814	Sous Chef Aiden Hughes
815	Pastry Chef Brooklyn Flores
816	Chef Noah Gonzalez
817	Line Cook Liam Ramirez
818	Sous Chef Chloe Harris
819	Pastry Chef Christian Ward
820	Line Cook Zoey Flores
821	Sous Chef David Cook
822	Chef Hannah Evans
823	Line Cook Emily Hughes
824	Pastry Chef Mason Ramirez
825	Sous Chef Victoria Gomez
826	Line Cook Jackson Turner
827	Pastry Chef Charlotte Gonzalez
828	Chef Aiden Flores
829	Sous Chef Samantha Jenkins
830	Line Cook Gabriel Harris
831	Pastry Chef Ava Cook
832	Sous Chef Eli Evans
833	Line Cook Grayson Hughes
834	Chef Layla Ramirez
835	Pastry Chef Victoria Flores
836	Sous Chef Lily Ward
837	Line Cook Caleb Turner
838	Chef David Jenkins
839	Pastry Chef Sophie Harris
840	Sous Chef Emily Cook
841	Line Cook Liam Evans
842	Sous Chef Olivia Hughes
843	Chef Madison Ramirez
844	Pastry Chef Henry Flores
845	Sous Chef Victoria Ward
846	Line Cook Liam Turner
847	Pastry Chef Scarlett Jenkins
848	Sous Chef Chloe Harris
849	Line Cook Ethan Cook
850	Pastry Chef Grace Evans
\.


--
-- Data for Name: ingredients; Type: TABLE DATA; Schema: public; Owner: yiannis
--

COPY public.ingredients (id, image_id, name, food_group_id, calories, fat, protein, carbs) FROM stdin;
1	101	Μαρούλι	1	15	0.2	1.4	2.9
2	102	Ντομάτα	1	18	0.2	0.9	3.9
3	103	Καρότο	1	41	0.2	0.9	9.6
4	104	Αγγούρι	1	16	0.1	0.7	3.6
5	105	Κρεμμύδι	1	40	0.1	1.1	9.3
6	106	Μπρόκολο	1	34	0.4	2.8	6.6
7	107	Κουνουπίδι	1	25	0.3	1.9	4.8
8	108	Κολοκυθάκια	1	17	0.3	1.2	3.1
9	109	Χόρτα	1	23	0.4	2.1	3.8
10	110	Παντζάρια	1	43	0.2	1.6	10
11	111	Αρακάς	1	81	0.4	5.4	14.5
12	112	Καλαμπόκι	1	86	1.2	3.2	19
13	113	Κολοκύθα	1	26	0.1	1	6.5
14	114	Πορτοκάλι	2	47	0.1	0.9	11.8
15	115	Μήλο	2	52	0.2	0.3	13.8
16	116	Αχλάδι	2	57	0.1	0.4	15.2
17	117	Μπανάνα	2	89	0.3	1.1	22.8
18	118	Ροδάκινο	2	39	0.3	0.9	9.5
19	119	Δαμάσκηνα	2	240	0.4	2.2	63.9
20	120	Σταφίδες	2	299	0.5	3.1	79.2
21	121	Βερίκοκα	2	48	0.4	1.4	11.1
22	122	Φυσικός Χυμός Πορτοκάλι	2	45	0.2	0.7	10.4
23	123	Σιτάρι	3	340	2.5	13	72.6
24	124	Βρόμη	3	389	6.9	16.9	66.3
25	125	Κριθάρι	3	354	2.3	12.5	73.5
26	126	Σίκαλη	3	335	1.6	10.3	73
27	127	Ρύζι	3	130	0.3	2.4	28.2
28	128	Αλεύρι	3	364	1	10.3	76.3
29	129	Ψωμί	3	265	3.2	9	49.4
30	130	Φρυγανιές	3	407	5.9	9	77.3
31	131	Παξιμάδια	3	374	5.4	11.2	71.2
32	132	Κριτσίνια	3	410	9.5	10	73
33	133	Κράκερ	3	421	10.9	7	72.6
34	134	Πίτες	3	266	10	4.9	39.5
35	135	Μακαρόνια	3	158	0.9	5.8	30.9
36	136	Κριθαράκι	3	365	2	12.5	73
37	137	Χυλοπίτες	3	357	1.5	13	71
38	138	Πλιγούρι	3	342	1.3	12.3	76.9
39	139	Τραχανάς	3	350	1	13	72
40	140	Δημητριακά Πρωινού	3	370	2.5	8	80
41	141	Πατάτες	3	77	0.1	2	17.6
42	142	Γάλα	4	42	1	3.4	5
43	143	Γιαούρτι	4	59	0.4	10	3.6
44	144	Τυρί	4	402	33.1	25	1.3
45	145	Ξινόγαλο	4	40	1	3.3	4.7
46	146	Φακές	5	116	0.4	9	20.1
47	147	Φασόλια	5	347	1.2	21	63
48	148	Ρεβίθια	5	164	2.6	8.9	27.4
49	149	Φάβα	5	88	0.6	8	14
50	150	Ξερά Κουκιά	5	341	1.5	26.1	58
51	151	Μοσχάρι	6	250	15	26	0
52	152	Βοδινό	6	250	15	26	0
53	153	Χοιρινό	6	242	14	27	0
54	154	Αρνί	6	294	21	25	0
55	155	Πρόβατο	6	294	21	25	0
56	156	Κατσίκι	6	109	2.3	20.6	0
57	157	Γίδα	6	109	2.3	20.6	0
58	158	Αγριογούρουνο	6	158	3.5	30.2	0
59	159	Ελάφι	6	158	3.5	30.2	0
60	160	Ζαρκάδι	6	158	3.5	30.2	0
61	161	Κοτόπουλο	7	239	14	27	0
62	162	Γαλοπούλα	7	189	7	28	0
63	163	Πάπια	7	337	28	19	0
64	164	Κουνέλι	7	173	3.5	33	0
65	165	Φασιανός	7	133	2	25	0
66	166	Ορτύκι	7	134	3.5	21	0
67	167	Πέρδικα	7	140	2.5	23	0
68	168	Αυγό	8	155	11	13	1.1
69	169	Σαρδέλα	9	208	11.5	24.6	0
70	170	Μαρίδα	9	96	3.2	16.5	0
71	171	Γόπα	9	90	2.2	16	0
72	172	Γαύρος	9	131	4.8	20.4	0
73	173	Αθερίνα	9	120	3	22	0
74	174	Ροφός	9	70	0.5	15	0
75	175	Συναγρίδα	9	82	1.1	17	0
76	176	Σφυρίδα	9	79	0.7	17	0
77	177	Μπακαλιάρος	9	82	0.7	17	0
78	178	Γαλέος	9	130	4	22	0
79	179	Τόνος	9	144	4.9	23	0
80	180	Λαβράκι	9	124	2.8	23	0
81	181	Σαργός	9	105	1.7	21.3	0
82	182	Τσιπούρα	9	96	2.8	19	0
83	183	Λυθρίνι	9	95	2	19	0
84	184	Καλαμάρι	9	92	1.4	15.6	3.1
85	185	Σουπιά	9	79	0.7	16.2	0.8
86	186	Χταπόδι	9	82	1	14.9	2.2
87	187	Γαρίδα	9	99	0.3	20.3	1.4
88	188	Μύδια	9	86	2.2	11.9	3.7
89	189	Στρείδια	9	81	2.3	9.5	4.2
90	190	Ελαιόλαδο	10	884	100	0	0
91	191	Ηλιέλαιο	10	884	100	0	0
92	192	Καλαμποκέλαιο	10	884	100	0	0
93	193	Σογιέλαιο	10	884	100	0	0
94	194	Σησαμέλαιο	10	884	100	0	0
95	195	Μαργαρίνη	10	717	81	0.2	0.7
96	196	Βούτυρο	10	717	81	0.9	0.1
97	197	Ελιές	10	115	10.7	0.8	6
98	198	Καρύδια	10	654	65	15.2	13.7
99	199	Αμύγδαλα	10	576	49.4	21.2	21.7
100	200	Φιστίκια	10	562	45.4	25.2	27.2
\.


--
-- Data for Name: judges; Type: TABLE DATA; Schema: public; Owner: yiannis
--

COPY public.judges (episode_id, judge_id) FROM stdin;
1	101
1	102
1	103
2	104
2	105
2	106
3	107
3	108
3	109
4	110
4	111
4	112
5	113
5	114
5	115
6	116
6	117
6	118
7	119
7	120
7	121
8	122
8	123
8	124
9	125
9	126
9	127
10	128
10	129
10	130
11	131
11	132
11	133
12	134
12	135
12	136
13	137
13	138
13	139
14	140
14	141
14	142
15	143
15	144
15	145
16	146
16	147
16	148
17	149
17	150
17	101
18	102
18	103
18	104
19	105
19	106
19	107
20	108
20	109
20	110
21	111
21	112
21	113
22	114
22	115
22	116
23	117
23	118
23	119
24	120
24	121
24	122
25	123
25	124
25	125
26	126
26	127
26	128
27	129
27	130
27	131
28	132
28	133
28	134
29	135
29	136
29	137
30	138
30	139
30	140
31	141
31	142
31	143
32	144
32	145
32	146
33	147
33	148
33	149
34	150
34	101
34	102
35	103
35	104
35	105
36	106
36	107
36	108
37	109
37	110
37	111
38	112
38	113
38	114
39	115
39	116
39	117
40	118
40	119
40	120
41	121
41	122
41	123
42	124
42	125
42	126
43	127
43	128
43	129
44	130
44	131
44	132
45	133
45	134
45	135
46	136
46	137
46	138
47	139
47	140
47	141
48	142
48	143
48	144
49	145
49	146
49	147
50	148
50	149
50	150
\.


--
-- Data for Name: marks; Type: TABLE DATA; Schema: public; Owner: yiannis
--

COPY public.marks (id, episode_id, judge_id, chef_id, mark) FROM stdin;
1	1	101	1	3
2	1	102	1	4
3	1	103	1	5
4	1	101	2	4
5	1	102	2	3
6	1	103	2	5
7	1	101	3	2
8	1	102	3	4
9	1	103	3	5
10	1	101	11	4
11	1	102	11	3
12	1	103	11	5
13	1	101	12	3
14	1	102	12	4
15	1	103	12	2
16	1	101	13	5
17	1	102	13	4
18	1	103	13	3
19	1	101	21	4
20	1	102	21	5
21	1	103	21	3
22	1	101	22	2
23	1	102	22	3
24	1	103	22	5
25	1	101	23	5
26	1	102	23	4
27	1	103	23	3
28	1	101	31	3
29	1	102	31	4
30	1	103	31	5
31	1	101	32	2
32	1	102	32	5
33	1	103	32	4
34	1	101	33	3
35	1	102	33	5
36	1	103	33	4
37	1	101	41	5
38	1	102	41	4
39	1	103	41	3
40	1	101	42	3
41	1	102	42	4
42	1	103	42	5
43	1	101	43	2
44	1	102	43	4
45	1	103	43	5
46	1	101	51	5
47	1	102	51	4
48	1	103	51	3
49	1	101	52	4
50	1	102	52	3
51	1	103	52	5
52	1	101	53	5
53	1	102	53	4
54	1	103	53	3
55	1	101	61	3
56	1	102	61	4
57	1	103	61	5
58	1	101	62	5
59	1	102	62	4
60	1	103	62	3
61	1	101	63	4
62	1	102	63	3
63	1	103	63	5
64	1	101	71	2
65	1	102	71	4
66	1	103	71	5
67	1	101	72	4
68	1	102	72	5
69	1	103	72	3
70	1	101	73	3
71	1	102	73	5
72	1	103	73	4
73	1	101	81	5
74	1	102	81	3
75	1	103	81	4
76	1	101	82	2
77	1	102	82	4
78	1	103	82	5
79	1	101	83	5
80	1	102	83	3
81	1	103	83	4
82	1	101	91	4
83	1	102	91	5
84	1	103	91	3
85	1	101	92	3
86	1	102	92	4
87	1	103	92	5
88	1	101	93	5
89	1	102	93	3
90	1	103	93	4
91	2	104	101	5
92	2	105	101	4
93	2	106	101	3
94	2	104	102	3
95	2	105	102	4
96	2	106	102	5
97	2	104	111	4
98	2	105	111	3
99	2	106	111	5
100	2	104	112	5
101	2	105	112	4
102	2	106	112	3
103	2	104	121	3
104	2	105	121	4
105	2	106	121	5
106	2	104	122	4
107	2	105	122	5
108	2	106	122	3
109	2	104	131	3
110	2	105	131	5
111	2	106	131	4
112	2	104	132	5
113	2	105	132	4
114	2	106	132	3
115	2	104	141	4
116	2	105	141	3
117	2	106	141	5
118	2	104	142	3
119	2	105	142	5
120	2	106	142	4
121	2	104	1	5
122	2	105	1	4
123	2	106	1	3
124	2	104	2	3
125	2	105	2	5
126	2	106	2	4
127	2	104	11	4
128	2	105	11	5
129	2	106	11	3
130	2	104	12	3
131	2	105	12	4
132	2	106	12	5
133	2	104	21	4
134	2	105	21	5
135	2	106	21	3
136	2	104	22	3
137	2	105	22	5
138	2	106	22	4
139	2	104	31	4
140	2	105	31	3
141	2	106	31	5
142	2	104	32	5
143	2	105	32	3
144	2	106	32	4
145	2	104	41	3
146	2	105	41	4
147	2	106	41	5
148	2	104	42	4
149	2	105	42	5
150	2	106	42	3
151	3	107	51	5
152	3	108	51	4
153	3	109	51	3
154	3	107	52	3
155	3	108	52	5
156	3	109	52	4
157	3	107	53	4
158	3	108	53	5
159	3	109	53	3
160	3	107	61	5
161	3	108	61	3
162	3	109	61	4
163	3	107	62	3
164	3	108	62	4
165	3	109	62	5
166	3	107	63	4
167	3	108	63	5
168	3	109	63	3
169	3	107	71	5
170	3	108	71	4
171	3	109	71	3
172	3	107	72	3
173	3	108	72	5
174	3	109	72	4
175	3	107	73	5
176	3	108	73	4
177	3	109	73	3
178	3	107	81	4
179	3	108	81	3
180	3	109	81	5
181	3	107	82	3
182	3	108	82	4
183	3	109	82	5
184	3	107	83	4
185	3	108	83	5
186	3	109	83	3
187	3	107	91	5
188	3	108	91	4
189	3	109	91	3
190	3	107	92	3
191	3	108	92	4
192	3	109	92	5
193	3	107	93	4
194	3	108	93	5
195	3	109	93	3
196	4	110	1	5
197	4	111	1	4
198	4	112	1	3
199	4	110	2	3
200	4	111	2	5
201	4	112	2	4
202	4	110	11	5
203	4	111	11	4
204	4	112	11	3
205	4	110	12	3
206	4	111	12	5
207	4	112	12	4
208	4	110	21	5
209	4	111	21	3
210	4	112	21	4
211	4	110	22	4
212	4	111	22	5
213	4	112	22	3
214	4	110	31	3
215	4	111	31	4
216	4	112	31	5
217	4	110	32	5
218	4	111	32	3
219	4	112	32	4
220	4	110	41	4
221	4	111	41	3
222	4	112	41	5
223	4	110	42	5
224	4	111	42	4
225	4	112	42	3
226	4	110	51	4
227	4	111	51	3
228	4	112	51	5
229	4	110	52	5
230	4	111	52	4
231	4	112	52	3
232	4	110	61	3
233	4	111	61	5
234	4	112	61	4
235	4	110	62	5
236	4	111	62	3
237	4	112	62	4
238	4	110	71	4
239	4	111	71	5
240	4	112	71	3
241	4	110	72	3
242	4	111	72	4
243	4	112	72	5
244	4	110	81	5
245	4	111	81	4
246	4	112	81	3
247	4	110	82	3
248	4	111	82	5
249	4	112	82	4
250	4	110	91	4
251	4	111	91	3
252	4	112	91	5
253	4	110	92	5
254	4	111	92	4
255	4	112	92	3
256	5	113	101	3
257	5	114	101	5
258	5	115	101	4
259	5	113	102	5
260	5	114	102	4
261	5	115	102	3
262	5	113	111	4
263	5	114	111	3
264	5	115	111	5
265	5	113	112	5
266	5	114	112	4
267	5	115	112	3
268	5	113	121	3
269	5	114	121	4
270	5	115	121	5
271	5	113	122	5
272	5	114	122	4
273	5	115	122	3
274	5	113	131	4
275	5	114	131	5
276	5	115	131	3
277	5	113	132	5
278	5	114	132	4
279	5	115	132	3
280	5	113	141	3
281	5	114	141	5
282	5	115	141	4
283	5	113	142	5
284	5	114	142	4
285	5	115	142	3
286	5	113	1	4
287	5	114	1	5
288	5	115	1	3
289	5	113	2	3
290	5	114	2	5
291	5	115	2	4
292	5	113	11	5
293	5	114	11	3
294	5	115	11	4
295	5	113	12	4
296	5	114	12	5
297	5	115	12	3
298	5	113	21	3
299	5	114	21	4
300	5	115	21	5
301	5	113	22	5
302	5	114	22	4
303	5	115	22	3
304	5	113	31	4
305	5	114	31	5
306	5	115	31	3
307	5	113	32	5
308	5	114	32	4
309	5	115	32	3
310	5	113	41	3
311	5	114	41	4
312	5	115	41	5
313	5	113	42	4
314	5	114	42	5
315	5	115	42	3
\.


--
-- Data for Name: recipe_equipment; Type: TABLE DATA; Schema: public; Owner: yiannis
--

COPY public.recipe_equipment (recipe_id, equipment_id, quantity) FROM stdin;
1	1	1
1	5	1
2	2	1
2	6	1
3	3	1
3	9	1
4	4	1
4	8	1
5	5	1
5	12	1
6	6	1
6	13	1
7	7	1
7	10	1
8	8	1
8	14	1
9	9	1
9	17	1
10	10	1
10	7	1
11	11	1
11	19	1
12	12	1
12	21	1
13	13	1
13	22	1
14	14	1
14	23	1
15	15	1
15	24	1
16	16	1
16	25	1
17	17	1
17	11	1
18	18	1
18	12	1
19	19	1
19	13	1
20	20	1
20	14	1
21	21	1
21	15	1
22	22	1
22	16	1
23	23	1
23	17	1
24	24	1
24	18	1
25	25	1
25	19	1
26	20	1
27	21	1
28	22	1
29	23	1
30	24	1
31	25	1
41	1	1
42	2	1
43	3	1
44	4	1
45	5	1
46	6	1
47	7	1
48	8	1
49	9	1
50	10	1
\.


--
-- Data for Name: recipe_ingredients; Type: TABLE DATA; Schema: public; Owner: yiannis
--

COPY public.recipe_ingredients (recipe_id, ingredient_id, quantity) FROM stdin;
1	1	300
1	2	200
1	3	150
2	2	250
2	4	200
2	5	150
3	3	200
3	6	100
3	7	50
4	4	300
4	8	150
4	9	100
5	5	250
5	10	200
5	11	100
6	6	200
6	12	150
6	13	50
7	7	300
7	14	200
7	15	150
8	8	250
8	16	200
8	17	100
9	9	200
9	18	150
9	19	50
10	10	300
10	20	200
10	21	150
11	11	250
11	22	200
11	23	100
12	12	200
12	24	150
12	25	50
13	13	300
13	26	200
13	27	150
14	14	250
14	28	200
14	29	100
15	15	200
15	30	150
15	31	50
16	16	300
16	32	200
16	33	150
17	17	250
17	34	200
17	35	100
18	18	200
18	36	150
18	37	50
19	19	300
19	38	200
19	39	150
20	20	250
20	40	200
20	41	100
21	21	200
21	42	150
21	43	50
22	22	300
22	44	200
22	45	150
23	23	250
23	46	200
23	47	100
24	24	200
24	48	150
24	49	50
25	25	300
25	50	200
25	1	150
26	26	250
26	2	200
26	3	100
27	27	200
27	4	150
27	5	50
28	28	300
28	6	200
28	7	150
29	29	250
29	8	200
29	9	100
30	30	200
30	10	150
30	11	50
31	31	300
31	12	200
31	13	150
32	32	250
32	14	200
32	15	100
33	33	200
33	16	150
33	17	50
34	34	300
34	18	200
34	19	150
35	35	250
35	20	200
35	21	100
36	36	200
36	22	150
36	23	50
37	37	300
37	24	200
37	25	150
38	38	250
38	26	200
38	27	100
39	39	200
39	28	150
39	29	50
40	40	300
40	30	200
40	31	150
41	41	250
41	32	200
41	33	100
42	42	200
42	34	150
42	35	50
43	43	300
43	36	200
43	37	150
44	44	250
44	38	200
44	39	100
45	45	200
45	40	150
45	41	50
46	46	300
46	42	200
46	43	150
47	47	250
47	44	200
47	45	100
48	48	200
48	46	150
48	47	50
49	49	300
49	48	200
49	49	150
50	50	250
50	50	200
50	1	100
\.


--
-- Data for Name: recipe_steps; Type: TABLE DATA; Schema: public; Owner: yiannis
--

COPY public.recipe_steps (recipe_id, step_id) FROM stdin;
1	1
1	2
1	3
2	4
2	5
3	6
3	7
4	8
4	9
5	10
6	11
6	12
7	13
8	14
8	15
9	16
9	17
10	18
10	19
11	20
11	21
12	22
12	23
13	24
14	25
15	26
15	27
16	28
17	29
17	30
18	31
19	32
20	33
21	34
21	35
22	36
22	37
23	38
23	39
24	40
25	41
25	42
26	43
26	44
27	45
28	46
28	47
29	48
29	49
30	50
31	51
31	52
32	53
32	54
33	55
34	56
34	57
35	58
35	59
36	60
37	1
37	2
38	3
38	4
39	5
39	6
40	7
40	8
41	9
41	10
42	11
42	12
43	13
43	14
44	15
44	16
45	17
45	18
46	19
46	20
47	21
47	22
48	23
48	24
49	25
49	26
50	27
50	28
\.


--
-- Data for Name: recipe_tags; Type: TABLE DATA; Schema: public; Owner: yiannis
--

COPY public.recipe_tags (recipe_id, tag) FROM stdin;
1	Vegetarian
1	Mediterranean
2	Italian
2	Comfort Food
3	French
3	Pastry
4	Mexican
4	Quick
5	Mexican
5	Street Food
6	Indian
6	Chutney
7	Chinese
7	Dim Sum
8	Japanese
8	Sushi
9	American
9	Breakfast
10	Vietnamese
10	Soup
11	Turkish
11	Dessert
12	Middle Eastern
12	Dip
13	Korean
13	Fermented
14	Brazilian
14	Sweet
15	Argentinian
15	Savory
16	Moroccan
16	Stew
17	Russian
17	Breakfast
18	Middle Eastern
18	Vegan
19	Nigerian
19	Rice
20	Swiss
20	Cheese
21	Greek
21	Salad
22	Italian
22	Pasta
23	French
23	Breakfast
24	Spanish
24	Seafood
25	Mexican
25	Quick
26	Indian
26	Curry
27	Chinese
27	Appetizer
28	Japanese
28	Noodles
29	American
29	Breakfast
30	Vietnamese
30	Spring Rolls
31	Greek
31	Dessert
32	Middle Eastern
32	Salad
33	Korean
33	BBQ
34	Brazilian
34	Cheese
35	Argentinian
35	Snack
36	Moroccan
36	Soup
37	Russian
37	Brunch
38	Middle Eastern
38	Breakfast
39	Nigerian
39	Appetizer
40	Swiss
40	Dinner
41	Greek
41	Pastry
42	Italian
42	Dessert
43	French
43	Dessert
44	Mexican
44	Snack
45	Mexican
45	Dip
46	Indian
46	Spicy
47	Chinese
47	Snack
48	Japanese
48	Fried
49	Chinese
49	Steamed
50	Vietnamese
50	Fried
\.


--
-- Data for Name: recipe_thematic_categories; Type: TABLE DATA; Schema: public; Owner: yiannis
--

COPY public.recipe_thematic_categories (recipe_id, thematic_category_id) FROM stdin;
1	1
1	6
2	2
2	14
3	3
3	15
4	4
5	5
5	17
6	6
7	7
8	8
8	18
9	9
10	10
11	11
12	12
13	13
14	2
15	14
16	15
17	3
17	7
18	16
19	17
20	18
21	1
22	2
23	9
23	19
24	4
25	5
26	6
27	7
28	8
29	9
30	10
30	15
31	11
32	12
33	13
34	2
34	17
35	14
36	15
37	3
38	16
38	19
39	17
40	18
41	1
42	2
43	9
44	4
45	5
45	19
46	6
47	7
48	8
49	9
50	10
\.


--
-- Data for Name: recipe_tips; Type: TABLE DATA; Schema: public; Owner: yiannis
--

COPY public.recipe_tips (recipe_id, tip) FROM stdin;
1	Use fresh vegetables for the best flavor.
1	Let the dish cool before serving to enhance flavors.
2	Use high-quality mozzarella for a better taste.
2	Preheat the baking sheet for a crispier crust.
3	Use cold butter for flaky layers in croissants.
4	Serve with a side of salsa for extra flavor.
5	Use fresh cilantro to garnish tacos.
6	Let the chutney sit overnight for enhanced taste.
7	Use a bamboo steamer for authentic dumplings.
8	Use sushi-grade fish for the best sushi.
9	Top with fresh berries for extra flavor.
9	Use buttermilk for fluffier pancakes.
10	Serve with fresh herbs for added freshness.
11	Use a sharp knife to cut baklava evenly.
11	Brush with melted butter for a golden finish.
12	Serve hummus with warm pita bread.
13	Use Napa cabbage for the best kimchi.
14	Roll brigadeiros in sprinkles for a festive look.
15	Serve empanadas with a side of salsa verde.
15	Use a fork to crimp the edges of empanadas.
16	Serve tajine with couscous for a complete meal.
17	Top blinis with sour cream and caviar.
18	Serve falafel with tahini sauce.
18	Use chickpea flour for gluten-free falafel.
19	Garnish Jollof rice with fresh herbs.
20	Use raclette cheese for authentic flavor.
21	Serve Greek salad with a drizzle of olive oil.
21	Use Kalamata olives for a traditional taste.
22	Layer lasagna with bechamel sauce for richness.
22	Use fresh basil for garnish.
23	Serve crepes with a variety of fillings.
24	Use saffron for authentic paella.
25	Serve quesadillas with guacamole.
26	Use fresh cream for a richer korma.
27	Serve spring rolls with sweet chili sauce.
28	Use homemade broth for the best ramen.
29	Top pancakes with syrup and butter.
30	Use fresh shrimp for Goi Cuon.
31	Drizzle syrup over kataifi for extra sweetness.
32	Serve tabbouleh with fresh lemon juice.
33	Marinate bulgogi overnight for the best flavor.
34	Serve Pão de Queijo warm.
35	Serve churros with chocolate sauce.
36	Garnish harira with fresh cilantro.
37	Top blinis with smoked salmon.
38	Serve shakshuka with crusty bread.
39	Use fresh herbs for akara.
40	Serve fondue with crusty bread and vegetables.
41	Use feta cheese for authentic spanakopita.
42	Dust tiramisu with cocoa powder before serving.
43	Serve macarons with tea or coffee.
44	Serve tortillas with salsa and guacamole.
45	Serve guacamole with tortilla chips.
46	Use fresh spices for the best curry.
47	Serve wontons with soy sauce.
48	Serve tempura with dipping sauce.
49	Steam bao buns for a soft texture.
50	Serve nem with fish sauce.
\.


--
-- Data for Name: recipes; Type: TABLE DATA; Schema: public; Owner: yiannis
--

COPY public.recipes (id, image_id, basic_ingredient_id, cooking_type, cuisine, difficulty, name, meal_group, servings) FROM stdin;
1	501	1	BAKING	1	EASY	Μουσακάς	DINNER	6
2	502	2	BAKING	2	MEDIUM	Πίτσα Μαργαρίτα	LUNCH	4
3	503	3	CONFECTIONERY	3	HARD	Κρουασάν	BREAKFAST	8
4	504	4	BAKING	4	VERY EASY	Τορτίγιας	SNACK	6
5	505	5	BAKING	5	EASY	Τακος	DINNER	4
6	506	6	CONFECTIONERY	6	MEDIUM	Τσάτνεϊ Μάνγκο	SNACK	8
7	507	7	BAKING	7	HARD	Ντάμπλινγκς	DINNER	6
8	508	8	CONFECTIONERY	8	VERY HARD	Σούσι	DINNER	4
9	509	9	BAKING	9	VERY EASY	Πανγκατζές	BREAKFAST	4
10	510	10	BAKING	10	MEDIUM	Φο Μπο	LUNCH	6
11	511	11	CONFECTIONERY	11	HARD	Μπακλαβάς	DESSERT	8
12	512	12	BAKING	12	VERY EASY	Χούμους	SNACK	6
13	513	13	BAKING	13	EASY	Κίμτσι	DINNER	4
14	514	14	CONFECTIONERY	14	MEDIUM	Μπριγκαντέιρο	DESSERT	8
15	515	15	BAKING	15	HARD	Εμπανάδας	DINNER	6
16	516	16	BAKING	16	VERY EASY	Ταζίν	LUNCH	6
17	517	17	CONFECTIONERY	17	EASY	Μπλινί	BREAKFAST	4
18	518	18	BAKING	18	MEDIUM	Φαλάφελ	DINNER	6
19	519	19	BAKING	19	HARD	Τζολοφ Ράις	LUNCH	8
20	520	20	CONFECTIONERY	20	VERY HARD	Ρακλέτ	DINNER	4
21	521	21	BAKING	1	VERY EASY	Χωριάτικη Σαλάτα	LUNCH	4
22	522	22	BAKING	2	EASY	Λαζάνια	DINNER	6
23	523	23	CONFECTIONERY	3	MEDIUM	Κρέπες	BREAKFAST	8
24	524	24	BAKING	4	HARD	Παέγια	DINNER	6
25	525	25	BAKING	5	VERY EASY	Κεσαδίγιας	SNACK	4
26	526	26	BAKING	6	EASY	Κόρμα	DINNER	6
27	527	27	CONFECTIONERY	7	MEDIUM	Σπρίνγκ Ρολς	SNACK	8
28	528	28	BAKING	8	HARD	Ραμέν	DINNER	4
29	529	29	BAKING	9	VERY EASY	Πανγκατζές με σιρόπι	BREAKFAST	4
30	530	30	BAKING	10	MEDIUM	Γκοϊ Κουόν	LUNCH	6
31	531	31	CONFECTIONERY	11	HARD	Κανταΐφι	DESSERT	8
32	532	32	BAKING	12	VERY EASY	Ταμπουλέ	SNACK	6
33	533	33	BAKING	13	EASY	Μπουλγκόγκι	DINNER	4
34	534	34	CONFECTIONERY	14	MEDIUM	Πάο ντε Κέιζο	DESSERT	8
35	535	35	BAKING	15	HARD	Τσουριπάνος	DINNER	6
36	536	36	BAKING	16	VERY EASY	Χάριρα	LUNCH	6
37	537	37	CONFECTIONERY	17	EASY	Σιρόπ Κούλτ	BREAKFAST	4
38	538	38	BAKING	18	MEDIUM	Σακσούκα	DINNER	6
39	539	39	BAKING	19	HARD	Ακάρα	LUNCH	8
40	540	40	CONFECTIONERY	20	VERY HARD	Φοντί	DINNER	4
41	541	41	BAKING	1	VERY EASY	Σπανακόπιτα	LUNCH	4
42	542	42	BAKING	2	EASY	Τιραμισού	DESSERT	6
43	543	43	CONFECTIONERY	3	MEDIUM	Μακαρόν	BREAKFAST	8
44	544	44	BAKING	4	HARD	Τορτίγια	DINNER	6
45	545	45	BAKING	5	VERY EASY	Γκουακαμόλε	SNACK	4
46	546	46	BAKING	6	EASY	Κάρι	DINNER	6
47	547	47	CONFECTIONERY	7	MEDIUM	Γουόντον	SNACK	8
48	548	48	BAKING	8	HARD	Τεμπούρα	DINNER	4
49	549	49	BAKING	9	VERY EASY	Μπάο	BREAKFAST	4
50	550	50	BAKING	10	MEDIUM	Νεμ	LUNCH	6
\.


--
-- Data for Name: steps; Type: TABLE DATA; Schema: public; Owner: yiannis
--

COPY public.steps (id, image_id, description, cooking_time, preparation_time) FROM stdin;
1	601	Preheat the oven to 180°C.	10	5
2	602	Chop the vegetables.	0	15
3	603	Mix all ingredients in a bowl.	0	10
4	604	Bake for 30 minutes.	30	0
5	605	Let it cool for 10 minutes.	10	0
6	606	Boil water in a pot.	5	5
7	607	Cook pasta until al dente.	10	0
8	608	Slice the bread.	0	5
9	609	Spread sauce on the bread.	0	5
10	610	Grill the bread for 5 minutes.	5	0
11	611	Whisk the eggs in a bowl.	0	5
12	612	Heat oil in a pan.	3	2
13	613	Fry the eggs until fully cooked.	5	0
14	614	Peel and dice the potatoes.	0	10
15	615	Cook potatoes in boiling water for 15 minutes.	15	0
16	616	Mash the potatoes.	0	5
17	617	Sauté onions until golden brown.	10	5
18	618	Add garlic and cook for 2 minutes.	2	0
19	619	Simmer the sauce for 20 minutes.	20	5
20	620	Marinate the meat for 30 minutes.	30	10
21	621	Grill the meat for 15 minutes.	15	5
22	622	Let the meat rest for 10 minutes.	10	0
23	623	Prepare the dressing.	0	10
24	624	Toss the salad with dressing.	0	5
25	625	Serve chilled.	0	5
26	626	Blend the ingredients until smooth.	0	5
27	627	Chill in the refrigerator for 1 hour.	0	60
28	628	Serve with a garnish of choice.	0	5
29	629	Heat milk in a saucepan.	5	2
30	630	Stir in the chocolate until melted.	3	2
31	631	Pour into cups and serve hot.	0	3
32	632	Prepare the dough.	0	20
33	633	Let the dough rise for 1 hour.	0	60
34	634	Bake the dough for 25 minutes.	25	5
35	635	Cut the dough into pieces.	0	5
36	636	Season the meat with salt and pepper.	0	5
37	637	Sear the meat on high heat.	5	5
38	638	Roast the meat in the oven for 20 minutes.	20	5
39	639	Prepare the sauce.	10	5
40	640	Drizzle the sauce over the meat.	0	5
41	641	Mix the dry ingredients.	0	10
42	642	Add wet ingredients and mix until combined.	0	10
43	643	Pour batter into a baking dish.	0	5
44	644	Bake for 35 minutes.	35	5
45	645	Let it cool before slicing.	10	0
46	646	Preheat the grill to high heat.	10	5
47	647	Grill the vegetables until tender.	15	10
48	648	Chop the herbs.	0	5
49	649	Mix the herbs with olive oil.	0	5
50	650	Drizzle the herb oil over the vegetables.	0	5
51	651	Chill the dough for 30 minutes.	0	30
52	652	Roll out the dough to 1/4 inch thick.	0	10
53	653	Cut out shapes using a cookie cutter.	0	10
54	654	Place the shapes on a baking sheet.	0	5
55	655	Bake the cookies for 12 minutes.	12	5
56	656	Decorate the cookies after they cool.	0	20
57	657	Whisk together the dressing ingredients.	0	5
58	658	Pour the dressing over the salad and toss to coat.	0	5
59	659	Top with nuts and seeds.	0	5
60	660	Serve the salad immediately.	0	5
\.


--
-- Data for Name: test; Type: TABLE DATA; Schema: public; Owner: yiannis
--

COPY public.test (id, calories) FROM stdin;
1	150
\.


--
-- Data for Name: test2; Type: TABLE DATA; Schema: public; Owner: yiannis
--

COPY public.test2 (id, test_id, quantity) FROM stdin;
1	1	10
\.


--
-- Data for Name: thematic_categories; Type: TABLE DATA; Schema: public; Owner: yiannis
--

COPY public.thematic_categories (id, image_id, name, description) FROM stdin;
1	201	συνταγές του χωρίου	Παραδοσιακές συνταγές από τα χωριά μας!
2	202	ριζότο συνταγές	Γευστικές συνταγές για ριζότο!
3	203	πασχαλινά γλυκά	Τα πιο νόστιμα γλυκά για το Πάσχα!
4	204	χειμωνιάτικες σούπες	Ζεστές και νόστιμες σούπες για το χειμώνα!
5	205	καλοκαιρινά σαλάτες	Δροσερές σαλάτες για το καλοκαίρι!
6	206	συνταγές για παιδιά	Νόστιμες και υγιεινές συνταγές για τα παιδιά!
7	207	χορτοφαγικές συνταγές	Νόστιμες συνταγές χωρίς κρέας!
8	208	συνταγές με ψάρι	Γευστικές συνταγές με φρέσκο ψάρι!
9	209	χριστουγεννιάτικα γλυκά	Τα καλύτερα γλυκά για τα Χριστούγεννα!
10	210	συνταγές με κοτόπουλο	Νόστιμες και εύκολες συνταγές με κοτόπουλο!
11	211	νηστίσιμες συνταγές	Νόστιμες συνταγές για τη νηστεία!
12	212	συνταγές με ζυμαρικά	Λαχταριστές συνταγές με ζυμαρικά!
13	213	συνταγές με κρέας	Γευστικές συνταγές με κόκκινο κρέας!
14	214	γρήγορες συνταγές	Γρήγορες και εύκολες συνταγές για κάθε μέρα!
15	215	εορταστικές συνταγές	Συνταγές για κάθε γιορτινή περίσταση!
16	216	συνταγές με λαχανικά	Υγιεινές και νόστιμες συνταγές με λαχανικά!
17	217	συνταγές για πάρτι	Ιδέες για νόστιμα σνακ και πιάτα για πάρτι!
18	218	διεθνείς συνταγές	Συνταγές από όλο τον κόσμο!
19	219	ελαφριά γεύματα	Ελαφριά και υγιεινά γεύματα για κάθε μέρα!
20	220	συνταγές με αυγά	Νόστιμες και εύκολες συνταγές με αυγά!
\.


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: yiannis
--

COPY public.users (id, username, password, user_role, auth_state) FROM stdin;
1	user1	password123	CHEF	f
2	user2	password123	CHEF	f
3	user3	password123	CHEF	f
4	user4	password123	CHEF	f
5	user5	password123	CHEF	f
6	user6	password123	CHEF	f
7	user7	password123	CHEF	f
8	user8	password123	CHEF	f
9	user9	password123	CHEF	f
10	user10	password123	CHEF	f
11	user11	password123	CHEF	f
12	user12	password123	CHEF	f
13	user13	password123	CHEF	f
14	user14	password123	CHEF	f
15	user15	password123	CHEF	f
16	user16	password123	CHEF	f
17	user17	password123	CHEF	f
18	user18	password123	CHEF	f
19	user19	password123	CHEF	f
20	user20	password123	CHEF	f
21	user21	password123	CHEF	f
22	user22	password123	CHEF	f
23	user23	password123	CHEF	f
24	user24	password123	CHEF	f
25	user25	password123	CHEF	f
26	user26	password123	CHEF	f
27	user27	password123	CHEF	f
28	user28	password123	CHEF	f
29	user29	password123	CHEF	f
30	user30	password123	CHEF	f
31	user31	password123	CHEF	f
32	user32	password123	CHEF	f
33	user33	password123	CHEF	f
34	user34	password123	CHEF	f
35	user35	password123	CHEF	f
36	user36	password123	CHEF	f
37	user37	password123	CHEF	f
38	user38	password123	CHEF	f
39	user39	password123	CHEF	f
40	user40	password123	CHEF	f
41	user41	password123	CHEF	f
42	user42	password123	CHEF	f
43	user43	password123	CHEF	f
44	user44	password123	CHEF	f
45	user45	password123	CHEF	f
46	user46	password123	CHEF	f
47	user47	password123	CHEF	f
48	user48	password123	CHEF	f
49	user49	password123	CHEF	f
50	user50	password123	CHEF	f
51	user51	password123	CHEF	f
52	user52	password123	CHEF	f
53	user53	password123	CHEF	f
54	user54	password123	CHEF	f
55	user55	password123	CHEF	f
56	user56	password123	CHEF	f
57	user57	password123	CHEF	f
58	user58	password123	CHEF	f
59	user59	password123	CHEF	f
60	user60	password123	CHEF	f
61	user61	password123	CHEF	f
62	user62	password123	CHEF	f
63	user63	password123	CHEF	f
64	user64	password123	CHEF	f
65	user65	password123	CHEF	f
66	user66	password123	CHEF	f
67	user67	password123	CHEF	f
68	user68	password123	CHEF	f
69	user69	password123	CHEF	f
70	user70	password123	CHEF	f
71	user71	password123	CHEF	f
72	user72	password123	CHEF	f
73	user73	password123	CHEF	f
74	user74	password123	CHEF	f
75	user75	password123	CHEF	f
76	user76	password123	CHEF	f
77	user77	password123	CHEF	f
78	user78	password123	CHEF	f
79	user79	password123	CHEF	f
80	user80	password123	CHEF	f
81	user81	password123	CHEF	f
82	user82	password123	CHEF	f
83	user83	password123	CHEF	f
84	user84	password123	CHEF	f
85	user85	password123	CHEF	f
86	user86	password123	CHEF	f
87	user87	password123	CHEF	f
88	user88	password123	CHEF	f
89	user89	password123	CHEF	f
90	user90	password123	CHEF	f
91	user91	password123	CHEF	f
92	user92	password123	CHEF	f
93	user93	password123	CHEF	f
94	user94	password123	CHEF	f
95	user95	password123	CHEF	f
96	user96	password123	CHEF	f
97	user97	password123	CHEF	f
98	user98	password123	CHEF	f
99	user99	password123	CHEF	f
100	user100	password123	CHEF	f
101	user101	password123	CHEF	f
102	user102	password123	CHEF	f
103	user103	password123	CHEF	f
104	user104	password123	CHEF	f
105	user105	password123	CHEF	f
106	user106	password123	CHEF	f
107	user107	password123	CHEF	f
108	user108	password123	CHEF	f
109	user109	password123	CHEF	f
110	user110	password123	CHEF	f
111	user111	password123	CHEF	f
112	user112	password123	CHEF	f
113	user113	password123	CHEF	f
114	user114	password123	CHEF	f
115	user115	password123	CHEF	f
116	user116	password123	CHEF	f
117	user117	password123	CHEF	f
118	user118	password123	CHEF	f
119	user119	password123	CHEF	f
120	user120	password123	CHEF	f
121	user121	password123	CHEF	f
122	user122	password123	CHEF	f
123	user123	password123	CHEF	f
124	user124	password123	CHEF	f
125	user125	password123	CHEF	f
126	user126	password123	CHEF	f
127	user127	password123	CHEF	f
128	user128	password123	CHEF	f
129	user129	password123	CHEF	f
130	user130	password123	CHEF	f
131	user131	password123	CHEF	f
132	user132	password123	CHEF	f
133	user133	password123	CHEF	f
134	user134	password123	CHEF	f
135	user135	password123	CHEF	f
136	user136	password123	CHEF	f
137	user137	password123	CHEF	f
138	user138	password123	CHEF	f
139	user139	password123	CHEF	f
140	user140	password123	CHEF	f
141	user141	password123	CHEF	f
142	user142	password123	CHEF	f
143	user143	password123	CHEF	f
144	user144	password123	CHEF	f
145	user145	password123	CHEF	f
146	user146	password123	CHEF	f
147	user147	password123	CHEF	f
148	user148	password123	CHEF	f
149	user149	password123	CHEF	f
150	user150	password123	CHEF	f
151	admin	admin	ADMIN	t
\.


--
-- Name: content_images_id_seq; Type: SEQUENCE SET; Schema: public; Owner: yiannis
--

SELECT pg_catalog.setval('public.content_images_id_seq', 1, false);


--
-- Name: cuisines_id_seq; Type: SEQUENCE SET; Schema: public; Owner: yiannis
--

SELECT pg_catalog.setval('public.cuisines_id_seq', 1, false);


--
-- Name: episodes_cuisines_chefs_id_seq; Type: SEQUENCE SET; Schema: public; Owner: yiannis
--

SELECT pg_catalog.setval('public.episodes_cuisines_chefs_id_seq', 128, true);


--
-- Name: episodes_id_seq; Type: SEQUENCE SET; Schema: public; Owner: yiannis
--

SELECT pg_catalog.setval('public.episodes_id_seq', 50, true);


--
-- Name: equipment_id_seq; Type: SEQUENCE SET; Schema: public; Owner: yiannis
--

SELECT pg_catalog.setval('public.equipment_id_seq', 1, false);


--
-- Name: food_groups_id_seq; Type: SEQUENCE SET; Schema: public; Owner: yiannis
--

SELECT pg_catalog.setval('public.food_groups_id_seq', 10, true);


--
-- Name: images_id_seq; Type: SEQUENCE SET; Schema: public; Owner: yiannis
--

SELECT pg_catalog.setval('public.images_id_seq', 1, false);


--
-- Name: ingredients_id_seq; Type: SEQUENCE SET; Schema: public; Owner: yiannis
--

SELECT pg_catalog.setval('public.ingredients_id_seq', 1, false);


--
-- Name: marks_id_seq; Type: SEQUENCE SET; Schema: public; Owner: yiannis
--

SELECT pg_catalog.setval('public.marks_id_seq', 315, true);


--
-- Name: recipes_id_seq; Type: SEQUENCE SET; Schema: public; Owner: yiannis
--

SELECT pg_catalog.setval('public.recipes_id_seq', 1, false);


--
-- Name: steps_id_seq; Type: SEQUENCE SET; Schema: public; Owner: yiannis
--

SELECT pg_catalog.setval('public.steps_id_seq', 1, false);


--
-- Name: test2_id_seq; Type: SEQUENCE SET; Schema: public; Owner: yiannis
--

SELECT pg_catalog.setval('public.test2_id_seq', 1, true);


--
-- Name: test_id_seq; Type: SEQUENCE SET; Schema: public; Owner: yiannis
--

SELECT pg_catalog.setval('public.test_id_seq', 1, true);


--
-- Name: thematic_categories_id_seq; Type: SEQUENCE SET; Schema: public; Owner: yiannis
--

SELECT pg_catalog.setval('public.thematic_categories_id_seq', 20, true);


--
-- Name: users_id_seq; Type: SEQUENCE SET; Schema: public; Owner: yiannis
--

SELECT pg_catalog.setval('public.users_id_seq', 151, true);


--
-- Name: chefs chefs_pkey; Type: CONSTRAINT; Schema: public; Owner: yiannis
--

ALTER TABLE ONLY public.chefs
    ADD CONSTRAINT chefs_pkey PRIMARY KEY (id);


--
-- Name: content_images content_images_pkey; Type: CONSTRAINT; Schema: public; Owner: yiannis
--

ALTER TABLE ONLY public.content_images
    ADD CONSTRAINT content_images_pkey PRIMARY KEY (id);


--
-- Name: cuisines cuisines_pkey; Type: CONSTRAINT; Schema: public; Owner: yiannis
--

ALTER TABLE ONLY public.cuisines
    ADD CONSTRAINT cuisines_pkey PRIMARY KEY (id);


--
-- Name: episodes_cuisines_chefs episodes_cuisines_chefs_pkey; Type: CONSTRAINT; Schema: public; Owner: yiannis
--

ALTER TABLE ONLY public.episodes_cuisines_chefs
    ADD CONSTRAINT episodes_cuisines_chefs_pkey PRIMARY KEY (id);


--
-- Name: episodes_cuisines episodes_cuisines_pkey; Type: CONSTRAINT; Schema: public; Owner: yiannis
--

ALTER TABLE ONLY public.episodes_cuisines
    ADD CONSTRAINT episodes_cuisines_pkey PRIMARY KEY (episode_id, cuisine_id);


--
-- Name: episodes episodes_pkey; Type: CONSTRAINT; Schema: public; Owner: yiannis
--

ALTER TABLE ONLY public.episodes
    ADD CONSTRAINT episodes_pkey PRIMARY KEY (id);


--
-- Name: equipment equipment_pkey; Type: CONSTRAINT; Schema: public; Owner: yiannis
--

ALTER TABLE ONLY public.equipment
    ADD CONSTRAINT equipment_pkey PRIMARY KEY (id);


--
-- Name: food_groups food_groups_pkey; Type: CONSTRAINT; Schema: public; Owner: yiannis
--

ALTER TABLE ONLY public.food_groups
    ADD CONSTRAINT food_groups_pkey PRIMARY KEY (id);


--
-- Name: images images_pkey; Type: CONSTRAINT; Schema: public; Owner: yiannis
--

ALTER TABLE ONLY public.images
    ADD CONSTRAINT images_pkey PRIMARY KEY (id);


--
-- Name: ingredients ingredients_pkey; Type: CONSTRAINT; Schema: public; Owner: yiannis
--

ALTER TABLE ONLY public.ingredients
    ADD CONSTRAINT ingredients_pkey PRIMARY KEY (id);


--
-- Name: judges judges_pkey; Type: CONSTRAINT; Schema: public; Owner: yiannis
--

ALTER TABLE ONLY public.judges
    ADD CONSTRAINT judges_pkey PRIMARY KEY (episode_id, judge_id);


--
-- Name: marks marks_pkey; Type: CONSTRAINT; Schema: public; Owner: yiannis
--

ALTER TABLE ONLY public.marks
    ADD CONSTRAINT marks_pkey PRIMARY KEY (id);


--
-- Name: recipes recipes_pkey; Type: CONSTRAINT; Schema: public; Owner: yiannis
--

ALTER TABLE ONLY public.recipes
    ADD CONSTRAINT recipes_pkey PRIMARY KEY (id);


--
-- Name: steps steps_pkey; Type: CONSTRAINT; Schema: public; Owner: yiannis
--

ALTER TABLE ONLY public.steps
    ADD CONSTRAINT steps_pkey PRIMARY KEY (id);


--
-- Name: test2 test2_pkey; Type: CONSTRAINT; Schema: public; Owner: yiannis
--

ALTER TABLE ONLY public.test2
    ADD CONSTRAINT test2_pkey PRIMARY KEY (id);


--
-- Name: test test_pkey; Type: CONSTRAINT; Schema: public; Owner: yiannis
--

ALTER TABLE ONLY public.test
    ADD CONSTRAINT test_pkey PRIMARY KEY (id);


--
-- Name: thematic_categories thematic_categories_pkey; Type: CONSTRAINT; Schema: public; Owner: yiannis
--

ALTER TABLE ONLY public.thematic_categories
    ADD CONSTRAINT thematic_categories_pkey PRIMARY KEY (id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: yiannis
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: marks ensure_chef_in_episode; Type: TRIGGER; Schema: public; Owner: yiannis
--

CREATE TRIGGER ensure_chef_in_episode AFTER INSERT ON public.marks FOR EACH ROW EXECUTE FUNCTION public.check_chef_in_episode();


--
-- Name: episodes_cuisines_chefs ensure_episodes_cuisines_chefs_recipe; Type: TRIGGER; Schema: public; Owner: yiannis
--

CREATE TRIGGER ensure_episodes_cuisines_chefs_recipe AFTER INSERT ON public.episodes_cuisines_chefs FOR EACH ROW EXECUTE FUNCTION public.check_episodes_cuisines_chefs_recipe();


--
-- Name: chefs chefs_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: yiannis
--

ALTER TABLE ONLY public.chefs
    ADD CONSTRAINT chefs_id_fkey FOREIGN KEY (id) REFERENCES public.users(id);


--
-- Name: chefs chefs_image_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: yiannis
--

ALTER TABLE ONLY public.chefs
    ADD CONSTRAINT chefs_image_id_fkey FOREIGN KEY (image_id) REFERENCES public.images(id);


--
-- Name: cuisines cuisines_image_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: yiannis
--

ALTER TABLE ONLY public.cuisines
    ADD CONSTRAINT cuisines_image_id_fkey FOREIGN KEY (image_id) REFERENCES public.images(id);


--
-- Name: episodes_cuisines_chefs episodes_cuisines_chefs_chef_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: yiannis
--

ALTER TABLE ONLY public.episodes_cuisines_chefs
    ADD CONSTRAINT episodes_cuisines_chefs_chef_id_fkey FOREIGN KEY (chef_id) REFERENCES public.chefs(id);


--
-- Name: episodes_cuisines_chefs episodes_cuisines_chefs_episode_id_cuisine_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: yiannis
--

ALTER TABLE ONLY public.episodes_cuisines_chefs
    ADD CONSTRAINT episodes_cuisines_chefs_episode_id_cuisine_id_fkey FOREIGN KEY (episode_id, cuisine_id) REFERENCES public.episodes_cuisines(episode_id, cuisine_id);


--
-- Name: episodes_cuisines_chefs episodes_cuisines_chefs_recipe_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: yiannis
--

ALTER TABLE ONLY public.episodes_cuisines_chefs
    ADD CONSTRAINT episodes_cuisines_chefs_recipe_id_fkey FOREIGN KEY (recipe_id) REFERENCES public.recipes(id);


--
-- Name: episodes_cuisines episodes_cuisines_cuisine_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: yiannis
--

ALTER TABLE ONLY public.episodes_cuisines
    ADD CONSTRAINT episodes_cuisines_cuisine_id_fkey FOREIGN KEY (cuisine_id) REFERENCES public.cuisines(id);


--
-- Name: episodes_cuisines episodes_cuisines_episode_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: yiannis
--

ALTER TABLE ONLY public.episodes_cuisines
    ADD CONSTRAINT episodes_cuisines_episode_id_fkey FOREIGN KEY (episode_id) REFERENCES public.episodes(id);


--
-- Name: episodes episodes_image_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: yiannis
--

ALTER TABLE ONLY public.episodes
    ADD CONSTRAINT episodes_image_id_fkey FOREIGN KEY (image_id) REFERENCES public.images(id);


--
-- Name: equipment equipment_image_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: yiannis
--

ALTER TABLE ONLY public.equipment
    ADD CONSTRAINT equipment_image_id_fkey FOREIGN KEY (image_id) REFERENCES public.images(id);


--
-- Name: food_groups food_groups_image_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: yiannis
--

ALTER TABLE ONLY public.food_groups
    ADD CONSTRAINT food_groups_image_id_fkey FOREIGN KEY (image_id) REFERENCES public.images(id);


--
-- Name: ingredients ingredients_food_group_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: yiannis
--

ALTER TABLE ONLY public.ingredients
    ADD CONSTRAINT ingredients_food_group_id_fkey FOREIGN KEY (food_group_id) REFERENCES public.food_groups(id);


--
-- Name: ingredients ingredients_image_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: yiannis
--

ALTER TABLE ONLY public.ingredients
    ADD CONSTRAINT ingredients_image_id_fkey FOREIGN KEY (image_id) REFERENCES public.images(id);


--
-- Name: judges judges_episode_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: yiannis
--

ALTER TABLE ONLY public.judges
    ADD CONSTRAINT judges_episode_id_fkey FOREIGN KEY (episode_id) REFERENCES public.episodes(id);


--
-- Name: judges judges_judge_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: yiannis
--

ALTER TABLE ONLY public.judges
    ADD CONSTRAINT judges_judge_id_fkey FOREIGN KEY (judge_id) REFERENCES public.chefs(id);


--
-- Name: marks marks_chef_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: yiannis
--

ALTER TABLE ONLY public.marks
    ADD CONSTRAINT marks_chef_id_fkey FOREIGN KEY (chef_id) REFERENCES public.chefs(id);


--
-- Name: marks marks_episode_id_judge_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: yiannis
--

ALTER TABLE ONLY public.marks
    ADD CONSTRAINT marks_episode_id_judge_id_fkey FOREIGN KEY (episode_id, judge_id) REFERENCES public.judges(episode_id, judge_id);


--
-- Name: recipe_equipment recipe_equipment_equipment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: yiannis
--

ALTER TABLE ONLY public.recipe_equipment
    ADD CONSTRAINT recipe_equipment_equipment_id_fkey FOREIGN KEY (equipment_id) REFERENCES public.equipment(id);


--
-- Name: recipe_equipment recipe_equipment_recipe_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: yiannis
--

ALTER TABLE ONLY public.recipe_equipment
    ADD CONSTRAINT recipe_equipment_recipe_id_fkey FOREIGN KEY (recipe_id) REFERENCES public.recipes(id);


--
-- Name: recipe_ingredients recipe_ingredients_ingredient_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: yiannis
--

ALTER TABLE ONLY public.recipe_ingredients
    ADD CONSTRAINT recipe_ingredients_ingredient_id_fkey FOREIGN KEY (ingredient_id) REFERENCES public.ingredients(id);


--
-- Name: recipe_ingredients recipe_ingredients_recipe_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: yiannis
--

ALTER TABLE ONLY public.recipe_ingredients
    ADD CONSTRAINT recipe_ingredients_recipe_id_fkey FOREIGN KEY (recipe_id) REFERENCES public.recipes(id);


--
-- Name: recipe_steps recipe_steps_recipe_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: yiannis
--

ALTER TABLE ONLY public.recipe_steps
    ADD CONSTRAINT recipe_steps_recipe_id_fkey FOREIGN KEY (recipe_id) REFERENCES public.recipes(id);


--
-- Name: recipe_steps recipe_steps_step_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: yiannis
--

ALTER TABLE ONLY public.recipe_steps
    ADD CONSTRAINT recipe_steps_step_id_fkey FOREIGN KEY (step_id) REFERENCES public.steps(id);


--
-- Name: recipe_tags recipe_tags_recipe_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: yiannis
--

ALTER TABLE ONLY public.recipe_tags
    ADD CONSTRAINT recipe_tags_recipe_id_fkey FOREIGN KEY (recipe_id) REFERENCES public.recipes(id);


--
-- Name: recipe_thematic_categories recipe_thematic_categories_recipe_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: yiannis
--

ALTER TABLE ONLY public.recipe_thematic_categories
    ADD CONSTRAINT recipe_thematic_categories_recipe_id_fkey FOREIGN KEY (recipe_id) REFERENCES public.recipes(id);


--
-- Name: recipe_thematic_categories recipe_thematic_categories_thematic_category_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: yiannis
--

ALTER TABLE ONLY public.recipe_thematic_categories
    ADD CONSTRAINT recipe_thematic_categories_thematic_category_id_fkey FOREIGN KEY (thematic_category_id) REFERENCES public.thematic_categories(id);


--
-- Name: recipe_tips recipe_tips_recipe_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: yiannis
--

ALTER TABLE ONLY public.recipe_tips
    ADD CONSTRAINT recipe_tips_recipe_id_fkey FOREIGN KEY (recipe_id) REFERENCES public.recipes(id);


--
-- Name: recipes recipes_basic_ingredient_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: yiannis
--

ALTER TABLE ONLY public.recipes
    ADD CONSTRAINT recipes_basic_ingredient_id_fkey FOREIGN KEY (basic_ingredient_id) REFERENCES public.ingredients(id);


--
-- Name: recipes recipes_cuisine_fkey; Type: FK CONSTRAINT; Schema: public; Owner: yiannis
--

ALTER TABLE ONLY public.recipes
    ADD CONSTRAINT recipes_cuisine_fkey FOREIGN KEY (cuisine) REFERENCES public.cuisines(id);


--
-- Name: recipes recipes_image_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: yiannis
--

ALTER TABLE ONLY public.recipes
    ADD CONSTRAINT recipes_image_id_fkey FOREIGN KEY (image_id) REFERENCES public.images(id);


--
-- Name: steps steps_image_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: yiannis
--

ALTER TABLE ONLY public.steps
    ADD CONSTRAINT steps_image_id_fkey FOREIGN KEY (image_id) REFERENCES public.images(id);


--
-- Name: test2 test2_test_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: yiannis
--

ALTER TABLE ONLY public.test2
    ADD CONSTRAINT test2_test_id_fkey FOREIGN KEY (test_id) REFERENCES public.test(id);


--
-- Name: thematic_categories thematic_categories_image_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: yiannis
--

ALTER TABLE ONLY public.thematic_categories
    ADD CONSTRAINT thematic_categories_image_id_fkey FOREIGN KEY (image_id) REFERENCES public.images(id);


--
-- Name: SCHEMA public; Type: ACL; Schema: -; Owner: postgres
--

REVOKE USAGE ON SCHEMA public FROM PUBLIC;
GRANT ALL ON SCHEMA public TO PUBLIC;


--
-- PostgreSQL database dump complete
--

