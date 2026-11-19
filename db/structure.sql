SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: pg_trgm; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA public;


--
-- Name: EXTENSION pg_trgm; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pg_trgm IS 'text similarity measurement and index searching based on trigrams';


--
-- Name: unaccent; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS unaccent WITH SCHEMA public;


--
-- Name: EXTENSION unaccent; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION unaccent IS 'text search dictionary that removes accents';


--
-- Name: listings_searchable_tsvector(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.listings_searchable_tsvector() RETURNS trigger
    LANGUAGE plpgsql
    AS $_$
DECLARE
  source record;
  word   text;
  parts  text := '';
  weight tsvector;
BEGIN
  NEW.searchable := NULL;
  FOR source IN
    SELECT * FROM (VALUES
      (coalesce(NEW.title, '')::text, 'A'),
      (coalesce(NEW.specs::text, '')::text, 'B'),
      (coalesce(NEW.description, '')::text, 'C')
    ) AS s(txt, w)
  LOOP
    parts := '';
    FOR word IN
      SELECT DISTINCT w
      FROM ts_debug('simple'::regconfig, unaccent('unaccent', source.txt)) d,
           unnest(d.lexemes) w
      WHERE w ~ '^[[:alnum:]]+$'
    LOOP
      parts := parts || ' ' || word;
    END LOOP;
    IF parts <> '' THEN
      weight := setweight(to_tsvector('simple'::regconfig, parts), source.w::"char");
      NEW.searchable := COALESCE(NEW.searchable || weight, weight);
    END IF;
  END LOOP;
  RETURN NEW;
END
$_$;


--
-- Name: listings_unaccented; Type: TEXT SEARCH CONFIGURATION; Schema: public; Owner: -
--

CREATE TEXT SEARCH CONFIGURATION public.listings_unaccented (
    PARSER = pg_catalog."default" );

ALTER TEXT SEARCH CONFIGURATION public.listings_unaccented
    ADD MAPPING FOR asciiword WITH public.unaccent, simple;

ALTER TEXT SEARCH CONFIGURATION public.listings_unaccented
    ADD MAPPING FOR word WITH public.unaccent, simple;

ALTER TEXT SEARCH CONFIGURATION public.listings_unaccented
    ADD MAPPING FOR numword WITH public.unaccent, simple;

ALTER TEXT SEARCH CONFIGURATION public.listings_unaccented
    ADD MAPPING FOR email WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.listings_unaccented
    ADD MAPPING FOR url WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.listings_unaccented
    ADD MAPPING FOR host WITH public.unaccent, simple;

ALTER TEXT SEARCH CONFIGURATION public.listings_unaccented
    ADD MAPPING FOR sfloat WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.listings_unaccented
    ADD MAPPING FOR version WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.listings_unaccented
    ADD MAPPING FOR hword_numpart WITH public.unaccent, simple;

ALTER TEXT SEARCH CONFIGURATION public.listings_unaccented
    ADD MAPPING FOR hword_part WITH public.unaccent, simple;

ALTER TEXT SEARCH CONFIGURATION public.listings_unaccented
    ADD MAPPING FOR hword_asciipart WITH public.unaccent, simple;

ALTER TEXT SEARCH CONFIGURATION public.listings_unaccented
    ADD MAPPING FOR numhword WITH public.unaccent, simple;

ALTER TEXT SEARCH CONFIGURATION public.listings_unaccented
    ADD MAPPING FOR asciihword WITH public.unaccent, simple;

ALTER TEXT SEARCH CONFIGURATION public.listings_unaccented
    ADD MAPPING FOR hword WITH public.unaccent, simple;

ALTER TEXT SEARCH CONFIGURATION public.listings_unaccented
    ADD MAPPING FOR url_path WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.listings_unaccented
    ADD MAPPING FOR file WITH public.unaccent, simple;

ALTER TEXT SEARCH CONFIGURATION public.listings_unaccented
    ADD MAPPING FOR "float" WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.listings_unaccented
    ADD MAPPING FOR "int" WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.listings_unaccented
    ADD MAPPING FOR uint WITH simple;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: active_storage_attachments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.active_storage_attachments (
    id bigint NOT NULL,
    name character varying NOT NULL,
    record_type character varying NOT NULL,
    record_id bigint NOT NULL,
    blob_id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL
);


--
-- Name: active_storage_attachments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.active_storage_attachments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: active_storage_attachments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.active_storage_attachments_id_seq OWNED BY public.active_storage_attachments.id;


--
-- Name: active_storage_blobs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.active_storage_blobs (
    id bigint NOT NULL,
    key character varying NOT NULL,
    filename character varying NOT NULL,
    content_type character varying,
    metadata text,
    service_name character varying NOT NULL,
    byte_size bigint NOT NULL,
    checksum character varying,
    created_at timestamp(6) without time zone NOT NULL
);


--
-- Name: active_storage_blobs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.active_storage_blobs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: active_storage_blobs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.active_storage_blobs_id_seq OWNED BY public.active_storage_blobs.id;


--
-- Name: active_storage_variant_records; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.active_storage_variant_records (
    id bigint NOT NULL,
    blob_id bigint NOT NULL,
    variation_digest character varying NOT NULL
);


--
-- Name: active_storage_variant_records_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.active_storage_variant_records_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: active_storage_variant_records_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.active_storage_variant_records_id_seq OWNED BY public.active_storage_variant_records.id;


--
-- Name: ar_internal_metadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ar_internal_metadata (
    key character varying NOT NULL,
    value character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: categories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.categories (
    id bigint NOT NULL,
    parent_id bigint,
    slug character varying NOT NULL,
    "position" integer DEFAULT 0 NOT NULL,
    name_translations jsonb DEFAULT '{}'::jsonb NOT NULL,
    description_translations jsonb DEFAULT '{}'::jsonb NOT NULL,
    seo_title_translations jsonb DEFAULT '{}'::jsonb NOT NULL,
    seo_description_translations jsonb DEFAULT '{}'::jsonb NOT NULL,
    icon character varying,
    active boolean DEFAULT true NOT NULL,
    listings_count integer DEFAULT 0 NOT NULL,
    kind integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: categories_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.categories_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: categories_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.categories_id_seq OWNED BY public.categories.id;


--
-- Name: category_filters; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.category_filters (
    id bigint NOT NULL,
    category_id bigint NOT NULL,
    filter_definition_id bigint NOT NULL,
    "position" integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: category_filters_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.category_filters_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: category_filters_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.category_filters_id_seq OWNED BY public.category_filters.id;


--
-- Name: countries; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.countries (
    id bigint NOT NULL,
    code character varying NOT NULL,
    name_key character varying NOT NULL,
    currency character varying DEFAULT 'EUR'::character varying NOT NULL,
    default_locale character varying DEFAULT 'es'::character varying NOT NULL,
    enabled boolean DEFAULT false NOT NULL,
    launched_at timestamp(6) without time zone,
    vat_rate numeric(5,2) DEFAULT 0.0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: countries_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.countries_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: countries_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.countries_id_seq OWNED BY public.countries.id;


--
-- Name: filter_definitions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.filter_definitions (
    id bigint NOT NULL,
    key character varying NOT NULL,
    label_translations jsonb DEFAULT '{}'::jsonb NOT NULL,
    group_translations jsonb DEFAULT '{}'::jsonb NOT NULL,
    input_type integer DEFAULT 0 NOT NULL,
    unit character varying,
    "position" integer DEFAULT 0 NOT NULL,
    active boolean DEFAULT true NOT NULL,
    show_in_sidebar boolean DEFAULT true NOT NULL,
    show_in_listing_form boolean DEFAULT true NOT NULL,
    required_in_form boolean DEFAULT false NOT NULL,
    searchable boolean DEFAULT true NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: filter_definitions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.filter_definitions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: filter_definitions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.filter_definitions_id_seq OWNED BY public.filter_definitions.id;


--
-- Name: filter_options; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.filter_options (
    id bigint NOT NULL,
    filter_definition_id bigint NOT NULL,
    value character varying NOT NULL,
    label_translations jsonb DEFAULT '{}'::jsonb NOT NULL,
    "position" integer DEFAULT 0 NOT NULL,
    numeric_value numeric(12,4),
    featured boolean DEFAULT false NOT NULL,
    active boolean DEFAULT true NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    performance_score integer
);


--
-- Name: filter_options_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.filter_options_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: filter_options_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.filter_options_id_seq OWNED BY public.filter_options.id;


--
-- Name: follows; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.follows (
    id bigint NOT NULL,
    follower_id bigint NOT NULL,
    store_id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: follows_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.follows_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: follows_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.follows_id_seq OWNED BY public.follows.id;


--
-- Name: friendly_id_slugs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.friendly_id_slugs (
    id bigint NOT NULL,
    slug character varying NOT NULL,
    sluggable_id integer NOT NULL,
    sluggable_type character varying(50),
    scope character varying,
    created_at timestamp(6) without time zone
);


--
-- Name: friendly_id_slugs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.friendly_id_slugs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: friendly_id_slugs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.friendly_id_slugs_id_seq OWNED BY public.friendly_id_slugs.id;


--
-- Name: games; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.games (
    id bigint NOT NULL,
    slug character varying NOT NULL,
    name character varying NOT NULL,
    "position" integer DEFAULT 0,
    active boolean DEFAULT true NOT NULL,
    demand jsonb DEFAULT '{}'::jsonb NOT NULL,
    cpu_weight numeric(4,2) DEFAULT 0.3 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: games_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.games_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: games_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.games_id_seq OWNED BY public.games.id;


--
-- Name: listing_labels; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.listing_labels (
    id bigint NOT NULL,
    listing_id bigint NOT NULL,
    product_label_id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: listing_labels_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.listing_labels_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: listing_labels_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.listing_labels_id_seq OWNED BY public.listing_labels.id;


--
-- Name: listing_seller_tags; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.listing_seller_tags (
    id bigint NOT NULL,
    listing_id bigint NOT NULL,
    seller_tag_id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: listing_seller_tags_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.listing_seller_tags_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: listing_seller_tags_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.listing_seller_tags_id_seq OWNED BY public.listing_seller_tags.id;


--
-- Name: listings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.listings (
    id bigint NOT NULL,
    store_id bigint NOT NULL,
    category_id bigint NOT NULL,
    title character varying NOT NULL,
    slug character varying NOT NULL,
    description text,
    price_cents integer DEFAULT 0 NOT NULL,
    original_price_cents integer,
    currency character varying DEFAULT 'EUR'::character varying NOT NULL,
    condition integer DEFAULT 0 NOT NULL,
    quantity integer DEFAULT 1 NOT NULL,
    status character varying DEFAULT 'draft'::character varying NOT NULL,
    rejection_reason text,
    reviewed_by_id bigint,
    reviewed_at timestamp(6) without time zone,
    published_at timestamp(6) without time zone,
    sold_at timestamp(6) without time zone,
    specs jsonb DEFAULT '{}'::jsonb NOT NULL,
    highlights jsonb DEFAULT '[]'::jsonb NOT NULL,
    shipping_method integer DEFAULT 0 NOT NULL,
    shipping_price_cents integer DEFAULT 0 NOT NULL,
    free_shipping boolean DEFAULT false NOT NULL,
    ships_within_days integer DEFAULT 3 NOT NULL,
    local_pickup boolean DEFAULT false NOT NULL,
    weight_grams integer,
    length_cm numeric(8,2),
    width_cm numeric(8,2),
    height_cm numeric(8,2),
    country_id bigint,
    province character varying,
    city character varying,
    postal_code character varying,
    allow_offers boolean DEFAULT true NOT NULL,
    featured_until timestamp(6) without time zone,
    views_count integer DEFAULT 0 NOT NULL,
    favorites_count integer DEFAULT 0 NOT NULL,
    watchers_count integer DEFAULT 0 NOT NULL,
    searchable tsvector,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    performance_score integer
);


--
-- Name: listings_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.listings_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: listings_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.listings_id_seq OWNED BY public.listings.id;


--
-- Name: probe_things; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.probe_things (
    id bigint NOT NULL,
    a jsonb DEFAULT '{}'::jsonb NOT NULL,
    b jsonb DEFAULT '[]'::jsonb NOT NULL
);


--
-- Name: probe_things_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.probe_things_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: probe_things_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.probe_things_id_seq OWNED BY public.probe_things.id;


--
-- Name: product_labels; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.product_labels (
    id bigint NOT NULL,
    slug character varying NOT NULL,
    name_translations jsonb DEFAULT '{}'::jsonb NOT NULL,
    color character varying,
    "position" integer DEFAULT 0 NOT NULL,
    active boolean DEFAULT true NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: product_labels_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.product_labels_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: product_labels_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.product_labels_id_seq OWNED BY public.product_labels.id;


--
-- Name: reviews; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.reviews (
    id bigint NOT NULL,
    store_id bigint NOT NULL,
    author_id bigint NOT NULL,
    listing_id bigint,
    order_id bigint,
    rating smallint NOT NULL,
    title character varying,
    body text,
    seller_reply text,
    seller_replied_at timestamp(6) without time zone,
    status character varying DEFAULT 'published'::character varying NOT NULL,
    verified_purchase boolean DEFAULT false NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT chk_reviews_rating_range CHECK (((rating >= 1) AND (rating <= 5)))
);


--
-- Name: reviews_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.reviews_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: reviews_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.reviews_id_seq OWNED BY public.reviews.id;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: seller_tags; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.seller_tags (
    id bigint NOT NULL,
    slug character varying NOT NULL,
    name_translations jsonb DEFAULT '{}'::jsonb NOT NULL,
    "position" integer DEFAULT 0 NOT NULL,
    active boolean DEFAULT true NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: seller_tags_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.seller_tags_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: seller_tags_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.seller_tags_id_seq OWNED BY public.seller_tags.id;


--
-- Name: settings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.settings (
    id bigint NOT NULL,
    key character varying NOT NULL,
    value jsonb,
    value_type character varying DEFAULT 'string'::character varying NOT NULL,
    "group" character varying DEFAULT 'general'::character varying NOT NULL,
    description_key character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: settings_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.settings_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: settings_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.settings_id_seq OWNED BY public.settings.id;


--
-- Name: stores; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.stores (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    name character varying NOT NULL,
    slug character varying NOT NULL,
    bio text,
    verified boolean DEFAULT false NOT NULL,
    verified_at timestamp(6) without time zone,
    kind integer DEFAULT 0 NOT NULL,
    business_name character varying,
    tax_id character varying,
    vacation_mode boolean DEFAULT false NOT NULL,
    vacation_message text,
    allow_offers_default boolean DEFAULT true NOT NULL,
    rating_avg numeric(4,2) DEFAULT 0.0 NOT NULL,
    ratings_count integer DEFAULT 0 NOT NULL,
    sales_count integer DEFAULT 0 NOT NULL,
    followers_count integer DEFAULT 0 NOT NULL,
    active_listings_count integer DEFAULT 0 NOT NULL,
    country_id bigint,
    city character varying,
    province character varying,
    postal_code character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: stores_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.stores_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: stores_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.stores_id_seq OWNED BY public.stores.id;


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id bigint NOT NULL,
    email character varying DEFAULT ''::character varying NOT NULL,
    encrypted_password character varying DEFAULT ''::character varying NOT NULL,
    reset_password_token character varying,
    reset_password_sent_at timestamp(6) without time zone,
    remember_created_at timestamp(6) without time zone,
    sign_in_count integer DEFAULT 0 NOT NULL,
    current_sign_in_at timestamp(6) without time zone,
    last_sign_in_at timestamp(6) without time zone,
    current_sign_in_ip character varying,
    last_sign_in_ip character varying,
    confirmation_token character varying,
    confirmed_at timestamp(6) without time zone,
    confirmation_sent_at timestamp(6) without time zone,
    unconfirmed_email character varying,
    failed_attempts integer DEFAULT 0 NOT NULL,
    unlock_token character varying,
    locked_at timestamp(6) without time zone,
    username character varying NOT NULL,
    first_name character varying,
    last_name character varying,
    phone character varying,
    role integer DEFAULT 0 NOT NULL,
    locale character varying,
    country_id bigint,
    provider character varying,
    uid character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.users_id_seq OWNED BY public.users.id;


--
-- Name: active_storage_attachments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_attachments ALTER COLUMN id SET DEFAULT nextval('public.active_storage_attachments_id_seq'::regclass);


--
-- Name: active_storage_blobs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_blobs ALTER COLUMN id SET DEFAULT nextval('public.active_storage_blobs_id_seq'::regclass);


--
-- Name: active_storage_variant_records id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_variant_records ALTER COLUMN id SET DEFAULT nextval('public.active_storage_variant_records_id_seq'::regclass);


--
-- Name: categories id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.categories ALTER COLUMN id SET DEFAULT nextval('public.categories_id_seq'::regclass);


--
-- Name: category_filters id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.category_filters ALTER COLUMN id SET DEFAULT nextval('public.category_filters_id_seq'::regclass);


--
-- Name: countries id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.countries ALTER COLUMN id SET DEFAULT nextval('public.countries_id_seq'::regclass);


--
-- Name: filter_definitions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.filter_definitions ALTER COLUMN id SET DEFAULT nextval('public.filter_definitions_id_seq'::regclass);


--
-- Name: filter_options id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.filter_options ALTER COLUMN id SET DEFAULT nextval('public.filter_options_id_seq'::regclass);


--
-- Name: follows id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.follows ALTER COLUMN id SET DEFAULT nextval('public.follows_id_seq'::regclass);


--
-- Name: friendly_id_slugs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.friendly_id_slugs ALTER COLUMN id SET DEFAULT nextval('public.friendly_id_slugs_id_seq'::regclass);


--
-- Name: games id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.games ALTER COLUMN id SET DEFAULT nextval('public.games_id_seq'::regclass);


--
-- Name: listing_labels id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.listing_labels ALTER COLUMN id SET DEFAULT nextval('public.listing_labels_id_seq'::regclass);


--
-- Name: listing_seller_tags id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.listing_seller_tags ALTER COLUMN id SET DEFAULT nextval('public.listing_seller_tags_id_seq'::regclass);


--
-- Name: listings id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.listings ALTER COLUMN id SET DEFAULT nextval('public.listings_id_seq'::regclass);


--
-- Name: probe_things id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.probe_things ALTER COLUMN id SET DEFAULT nextval('public.probe_things_id_seq'::regclass);


--
-- Name: product_labels id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_labels ALTER COLUMN id SET DEFAULT nextval('public.product_labels_id_seq'::regclass);


--
-- Name: reviews id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reviews ALTER COLUMN id SET DEFAULT nextval('public.reviews_id_seq'::regclass);


--
-- Name: seller_tags id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.seller_tags ALTER COLUMN id SET DEFAULT nextval('public.seller_tags_id_seq'::regclass);


--
-- Name: settings id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.settings ALTER COLUMN id SET DEFAULT nextval('public.settings_id_seq'::regclass);


--
-- Name: stores id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stores ALTER COLUMN id SET DEFAULT nextval('public.stores_id_seq'::regclass);


--
-- Name: users id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- Name: active_storage_attachments active_storage_attachments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_attachments
    ADD CONSTRAINT active_storage_attachments_pkey PRIMARY KEY (id);


--
-- Name: active_storage_blobs active_storage_blobs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_blobs
    ADD CONSTRAINT active_storage_blobs_pkey PRIMARY KEY (id);


--
-- Name: active_storage_variant_records active_storage_variant_records_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_variant_records
    ADD CONSTRAINT active_storage_variant_records_pkey PRIMARY KEY (id);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: categories categories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.categories
    ADD CONSTRAINT categories_pkey PRIMARY KEY (id);


--
-- Name: category_filters category_filters_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.category_filters
    ADD CONSTRAINT category_filters_pkey PRIMARY KEY (id);


--
-- Name: countries countries_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.countries
    ADD CONSTRAINT countries_pkey PRIMARY KEY (id);


--
-- Name: filter_definitions filter_definitions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.filter_definitions
    ADD CONSTRAINT filter_definitions_pkey PRIMARY KEY (id);


--
-- Name: filter_options filter_options_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.filter_options
    ADD CONSTRAINT filter_options_pkey PRIMARY KEY (id);


--
-- Name: follows follows_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.follows
    ADD CONSTRAINT follows_pkey PRIMARY KEY (id);


--
-- Name: friendly_id_slugs friendly_id_slugs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.friendly_id_slugs
    ADD CONSTRAINT friendly_id_slugs_pkey PRIMARY KEY (id);


--
-- Name: games games_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.games
    ADD CONSTRAINT games_pkey PRIMARY KEY (id);


--
-- Name: listing_labels listing_labels_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.listing_labels
    ADD CONSTRAINT listing_labels_pkey PRIMARY KEY (id);


--
-- Name: listing_seller_tags listing_seller_tags_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.listing_seller_tags
    ADD CONSTRAINT listing_seller_tags_pkey PRIMARY KEY (id);


--
-- Name: listings listings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.listings
    ADD CONSTRAINT listings_pkey PRIMARY KEY (id);


--
-- Name: probe_things probe_things_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.probe_things
    ADD CONSTRAINT probe_things_pkey PRIMARY KEY (id);


--
-- Name: product_labels product_labels_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_labels
    ADD CONSTRAINT product_labels_pkey PRIMARY KEY (id);


--
-- Name: reviews reviews_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reviews
    ADD CONSTRAINT reviews_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: seller_tags seller_tags_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.seller_tags
    ADD CONSTRAINT seller_tags_pkey PRIMARY KEY (id);


--
-- Name: settings settings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.settings
    ADD CONSTRAINT settings_pkey PRIMARY KEY (id);


--
-- Name: stores stores_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stores
    ADD CONSTRAINT stores_pkey PRIMARY KEY (id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: idx_listings_category_published; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_listings_category_published ON public.listings USING btree (category_id, published_at) WHERE ((status)::text = 'published'::text);


--
-- Name: idx_listings_featured; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_listings_featured ON public.listings USING btree (status, featured_until) WHERE ((status)::text = 'published'::text);


--
-- Name: idx_listings_price_published; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_listings_price_published ON public.listings USING btree (price_cents) WHERE ((status)::text = 'published'::text);


--
-- Name: idx_listings_status_performance_score; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_listings_status_performance_score ON public.listings USING btree (status, performance_score) WHERE ((status)::text = 'published'::text);


--
-- Name: index_active_storage_attachments_on_blob_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_active_storage_attachments_on_blob_id ON public.active_storage_attachments USING btree (blob_id);


--
-- Name: index_active_storage_attachments_uniqueness; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_active_storage_attachments_uniqueness ON public.active_storage_attachments USING btree (record_type, record_id, name, blob_id);


--
-- Name: index_active_storage_blobs_on_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_active_storage_blobs_on_key ON public.active_storage_blobs USING btree (key);


--
-- Name: index_active_storage_variant_records_uniqueness; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_active_storage_variant_records_uniqueness ON public.active_storage_variant_records USING btree (blob_id, variation_digest);


--
-- Name: index_categories_on_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_categories_on_active ON public.categories USING btree (active);


--
-- Name: index_categories_on_kind; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_categories_on_kind ON public.categories USING btree (kind);


--
-- Name: index_categories_on_parent_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_categories_on_parent_id ON public.categories USING btree (parent_id);


--
-- Name: index_categories_on_parent_id_and_position; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_categories_on_parent_id_and_position ON public.categories USING btree (parent_id, "position");


--
-- Name: index_categories_on_slug; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_categories_on_slug ON public.categories USING btree (slug);


--
-- Name: index_category_filters_on_category_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_category_filters_on_category_id ON public.category_filters USING btree (category_id);


--
-- Name: index_category_filters_on_category_id_and_filter_definition_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_category_filters_on_category_id_and_filter_definition_id ON public.category_filters USING btree (category_id, filter_definition_id);


--
-- Name: index_category_filters_on_category_id_and_position; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_category_filters_on_category_id_and_position ON public.category_filters USING btree (category_id, "position");


--
-- Name: index_category_filters_on_filter_definition_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_category_filters_on_filter_definition_id ON public.category_filters USING btree (filter_definition_id);


--
-- Name: index_countries_on_code; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_countries_on_code ON public.countries USING btree (code);


--
-- Name: index_countries_on_enabled; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_countries_on_enabled ON public.countries USING btree (enabled);


--
-- Name: index_filter_definitions_on_active_and_position; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_filter_definitions_on_active_and_position ON public.filter_definitions USING btree (active, "position");


--
-- Name: index_filter_definitions_on_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_filter_definitions_on_key ON public.filter_definitions USING btree (key);


--
-- Name: index_filter_options_on_featured; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_filter_options_on_featured ON public.filter_options USING btree (featured);


--
-- Name: index_filter_options_on_filter_definition_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_filter_options_on_filter_definition_id ON public.filter_options USING btree (filter_definition_id);


--
-- Name: index_filter_options_on_filter_definition_id_and_position; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_filter_options_on_filter_definition_id_and_position ON public.filter_options USING btree (filter_definition_id, "position");


--
-- Name: index_filter_options_on_filter_definition_id_and_value; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_filter_options_on_filter_definition_id_and_value ON public.filter_options USING btree (filter_definition_id, value);


--
-- Name: index_follows_on_follower_id_and_store_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_follows_on_follower_id_and_store_id ON public.follows USING btree (follower_id, store_id);


--
-- Name: index_follows_on_store_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_follows_on_store_id ON public.follows USING btree (store_id);


--
-- Name: index_friendly_id_slugs_on_slug_and_sluggable_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_friendly_id_slugs_on_slug_and_sluggable_type ON public.friendly_id_slugs USING btree (slug, sluggable_type);


--
-- Name: index_friendly_id_slugs_on_slug_and_sluggable_type_and_scope; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_friendly_id_slugs_on_slug_and_sluggable_type_and_scope ON public.friendly_id_slugs USING btree (slug, sluggable_type, scope);


--
-- Name: index_friendly_id_slugs_on_sluggable_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_friendly_id_slugs_on_sluggable_type ON public.friendly_id_slugs USING btree (sluggable_type);


--
-- Name: index_friendly_id_slugs_on_sluggable_type_and_sluggable_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_friendly_id_slugs_on_sluggable_type_and_sluggable_id ON public.friendly_id_slugs USING btree (sluggable_type, sluggable_id);


--
-- Name: index_games_on_slug; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_games_on_slug ON public.games USING btree (slug);


--
-- Name: index_listing_labels_on_listing_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_listing_labels_on_listing_id ON public.listing_labels USING btree (listing_id);


--
-- Name: index_listing_labels_on_listing_id_and_product_label_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_listing_labels_on_listing_id_and_product_label_id ON public.listing_labels USING btree (listing_id, product_label_id);


--
-- Name: index_listing_labels_on_product_label_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_listing_labels_on_product_label_id ON public.listing_labels USING btree (product_label_id);


--
-- Name: index_listing_seller_tags_on_listing_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_listing_seller_tags_on_listing_id ON public.listing_seller_tags USING btree (listing_id);


--
-- Name: index_listing_seller_tags_on_listing_id_and_seller_tag_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_listing_seller_tags_on_listing_id_and_seller_tag_id ON public.listing_seller_tags USING btree (listing_id, seller_tag_id);


--
-- Name: index_listing_seller_tags_on_seller_tag_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_listing_seller_tags_on_seller_tag_id ON public.listing_seller_tags USING btree (seller_tag_id);


--
-- Name: index_listings_on_category_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_listings_on_category_id ON public.listings USING btree (category_id);


--
-- Name: index_listings_on_country_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_listings_on_country_id ON public.listings USING btree (country_id);


--
-- Name: index_listings_on_featured_until; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_listings_on_featured_until ON public.listings USING btree (featured_until);


--
-- Name: index_listings_on_searchable; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_listings_on_searchable ON public.listings USING gin (searchable);


--
-- Name: index_listings_on_slug; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_listings_on_slug ON public.listings USING btree (slug);


--
-- Name: index_listings_on_specs; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_listings_on_specs ON public.listings USING gin (specs jsonb_path_ops);


--
-- Name: index_listings_on_status_and_updated_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_listings_on_status_and_updated_at ON public.listings USING btree (status, updated_at);


--
-- Name: index_listings_on_store_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_listings_on_store_id ON public.listings USING btree (store_id);


--
-- Name: index_listings_on_store_id_and_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_listings_on_store_id_and_status ON public.listings USING btree (store_id, status);


--
-- Name: index_listings_on_title; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_listings_on_title ON public.listings USING gin (title public.gin_trgm_ops);


--
-- Name: index_product_labels_on_active_and_position; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_product_labels_on_active_and_position ON public.product_labels USING btree (active, "position");


--
-- Name: index_product_labels_on_slug; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_product_labels_on_slug ON public.product_labels USING btree (slug);


--
-- Name: index_reviews_on_author_id_and_order_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_reviews_on_author_id_and_order_id ON public.reviews USING btree (author_id, order_id) WHERE (order_id IS NOT NULL);


--
-- Name: index_reviews_on_listing_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_reviews_on_listing_id ON public.reviews USING btree (listing_id);


--
-- Name: index_reviews_on_store_id_and_status_and_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_reviews_on_store_id_and_status_and_created_at ON public.reviews USING btree (store_id, status, created_at DESC);


--
-- Name: index_seller_tags_on_slug; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_seller_tags_on_slug ON public.seller_tags USING btree (slug);


--
-- Name: index_settings_on_group; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_settings_on_group ON public.settings USING btree ("group");


--
-- Name: index_settings_on_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_settings_on_key ON public.settings USING btree (key);


--
-- Name: index_stores_on_country_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_stores_on_country_id ON public.stores USING btree (country_id);


--
-- Name: index_stores_on_slug; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_stores_on_slug ON public.stores USING btree (slug);


--
-- Name: index_stores_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_stores_on_user_id ON public.stores USING btree (user_id);


--
-- Name: index_stores_on_verified_and_rating_avg; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_stores_on_verified_and_rating_avg ON public.stores USING btree (verified, rating_avg);


--
-- Name: index_users_on_confirmation_token; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_confirmation_token ON public.users USING btree (confirmation_token);


--
-- Name: index_users_on_country_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_users_on_country_id ON public.users USING btree (country_id);


--
-- Name: index_users_on_email; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_email ON public.users USING btree (email);


--
-- Name: index_users_on_provider_and_uid; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_provider_and_uid ON public.users USING btree (provider, uid);


--
-- Name: index_users_on_reset_password_token; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_reset_password_token ON public.users USING btree (reset_password_token);


--
-- Name: index_users_on_unlock_token; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_unlock_token ON public.users USING btree (unlock_token);


--
-- Name: index_users_on_username; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_username ON public.users USING btree (username);


--
-- Name: listings set_listings_searchable; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER set_listings_searchable BEFORE INSERT OR UPDATE OF title, description, specs ON public.listings FOR EACH ROW EXECUTE FUNCTION public.listings_searchable_tsvector();


--
-- Name: filter_options fk_rails_02a7e331ce; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.filter_options
    ADD CONSTRAINT fk_rails_02a7e331ce FOREIGN KEY (filter_definition_id) REFERENCES public.filter_definitions(id);


--
-- Name: reviews fk_rails_08a5ebb739; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reviews
    ADD CONSTRAINT fk_rails_08a5ebb739 FOREIGN KEY (store_id) REFERENCES public.stores(id);


--
-- Name: reviews fk_rails_29e6f859c4; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reviews
    ADD CONSTRAINT fk_rails_29e6f859c4 FOREIGN KEY (author_id) REFERENCES public.users(id);


--
-- Name: listing_seller_tags fk_rails_2d0fc795ec; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.listing_seller_tags
    ADD CONSTRAINT fk_rails_2d0fc795ec FOREIGN KEY (seller_tag_id) REFERENCES public.seller_tags(id);


--
-- Name: follows fk_rails_3975726f96; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.follows
    ADD CONSTRAINT fk_rails_3975726f96 FOREIGN KEY (store_id) REFERENCES public.stores(id);


--
-- Name: category_filters fk_rails_447c0a3fda; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.category_filters
    ADD CONSTRAINT fk_rails_447c0a3fda FOREIGN KEY (filter_definition_id) REFERENCES public.filter_definitions(id);


--
-- Name: category_filters fk_rails_534a815bc7; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.category_filters
    ADD CONSTRAINT fk_rails_534a815bc7 FOREIGN KEY (category_id) REFERENCES public.categories(id);


--
-- Name: listings fk_rails_5b5873986f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.listings
    ADD CONSTRAINT fk_rails_5b5873986f FOREIGN KEY (country_id) REFERENCES public.countries(id);


--
-- Name: reviews fk_rails_60def33a58; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reviews
    ADD CONSTRAINT fk_rails_60def33a58 FOREIGN KEY (listing_id) REFERENCES public.listings(id) ON DELETE SET NULL;


--
-- Name: follows fk_rails_622d34a301; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.follows
    ADD CONSTRAINT fk_rails_622d34a301 FOREIGN KEY (follower_id) REFERENCES public.users(id);


--
-- Name: listings fk_rails_6ba36fa2a8; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.listings
    ADD CONSTRAINT fk_rails_6ba36fa2a8 FOREIGN KEY (store_id) REFERENCES public.stores(id);


--
-- Name: users fk_rails_7325e2cdfa; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT fk_rails_7325e2cdfa FOREIGN KEY (country_id) REFERENCES public.countries(id);


--
-- Name: listings fk_rails_7a79c1d41c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.listings
    ADD CONSTRAINT fk_rails_7a79c1d41c FOREIGN KEY (reviewed_by_id) REFERENCES public.users(id);


--
-- Name: categories fk_rails_82f48f7407; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.categories
    ADD CONSTRAINT fk_rails_82f48f7407 FOREIGN KEY (parent_id) REFERENCES public.categories(id);


--
-- Name: active_storage_variant_records fk_rails_993965df05; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_variant_records
    ADD CONSTRAINT fk_rails_993965df05 FOREIGN KEY (blob_id) REFERENCES public.active_storage_blobs(id);


--
-- Name: listings fk_rails_a855f030e2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.listings
    ADD CONSTRAINT fk_rails_a855f030e2 FOREIGN KEY (category_id) REFERENCES public.categories(id);


--
-- Name: stores fk_rails_b46c39c5fd; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stores
    ADD CONSTRAINT fk_rails_b46c39c5fd FOREIGN KEY (country_id) REFERENCES public.countries(id);


--
-- Name: stores fk_rails_b526db2ffb; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stores
    ADD CONSTRAINT fk_rails_b526db2ffb FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: active_storage_attachments fk_rails_c3b3935057; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_attachments
    ADD CONSTRAINT fk_rails_c3b3935057 FOREIGN KEY (blob_id) REFERENCES public.active_storage_blobs(id);


--
-- Name: listing_labels fk_rails_c6c2668ad8; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.listing_labels
    ADD CONSTRAINT fk_rails_c6c2668ad8 FOREIGN KEY (product_label_id) REFERENCES public.product_labels(id);


--
-- Name: listing_seller_tags fk_rails_eefd13c54c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.listing_seller_tags
    ADD CONSTRAINT fk_rails_eefd13c54c FOREIGN KEY (listing_id) REFERENCES public.listings(id);


--
-- Name: listing_labels fk_rails_f7a124c136; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.listing_labels
    ADD CONSTRAINT fk_rails_f7a124c136 FOREIGN KEY (listing_id) REFERENCES public.listings(id);


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
('20261119180002'),
('20261119180001'),
('20261119170002'),
('20261119170001'),
('20261119160012'),
('20261119160011'),
('20261119160010'),
('20261119160009'),
('20261119160008'),
('20261119160007'),
('20261119160006'),
('20261119160005'),
('20261119160004'),
('20261119160003'),
('20261119160002'),
('20261119160001'),
('20261119143449'),
('20261119090002'),
('20261119090001');

