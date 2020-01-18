--
-- Name: artist_commentaries; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.artist_commentaries (
    id serial NOT NULL,
    post_id integer NOT NULL,
    original_title text DEFAULT ''::text NOT NULL,
    original_description text DEFAULT ''::text NOT NULL,
    translated_title text DEFAULT ''::text NOT NULL,
    translated_description text DEFAULT ''::text NOT NULL,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: artist_commentary_versions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.artist_commentary_versions (
    id serial NOT NULL,
    post_id integer NOT NULL,
    updater_id integer NOT NULL,
    updater_ip_addr inet NOT NULL,
    original_title text,
    original_description text,
    translated_title text,
    translated_description text,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: bulk_update_requests; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.bulk_update_requests (
    id serial NOT NULL,
    user_id integer NOT NULL,
    forum_topic_id integer,
    script text NOT NULL,
    status character varying DEFAULT 'pending'::character varying NOT NULL,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    approver_id integer,
    forum_post_id integer,
    title text
);

--
-- Name: dmail_filters; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.dmail_filters (
    id serial NOT NULL,
    user_id integer NOT NULL,
    words text NOT NULL,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);

--
-- Name: forum_post_votes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.forum_post_votes (
    id bigserial NOT NULL,
    forum_post_id integer NOT NULL,
    creator_id integer NOT NULL,
    score integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);

--
-- Name: forum_subscriptions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.forum_subscriptions (
    id serial NOT NULL,
    user_id integer,
    forum_topic_id integer,
    last_read_at timestamp without time zone,
    delete_key character varying
);


--
-- Name: forum_topic_visits; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.forum_topic_visits (
    id serial NOT NULL,
    user_id integer,
    forum_topic_id integer,
    last_read_at timestamp without time zone,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: janitor_trials; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.janitor_trials (
    id serial NOT NULL,
    creator_id integer NOT NULL,
    user_id integer NOT NULL,
    original_level integer,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    status character varying DEFAULT 'active'::character varying NOT NULL
);

--
-- Name: pixiv_ugoira_frame_data; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.pixiv_ugoira_frame_data (
    id serial NOT NULL,
    post_id integer,
    data text NOT NULL,
    content_type character varying NOT NULL
);

--
-- Name: post_appeals; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.post_appeals (
    id serial NOT NULL,
    post_id integer NOT NULL,
    creator_id integer NOT NULL,
    creator_ip_addr inet,
    reason text,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: post_approvals; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.post_approvals (
    id serial NOT NULL,
    user_id integer NOT NULL,
    post_id integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: post_disapprovals; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.post_disapprovals (
    id bigserial NOT NULL,
    user_id integer NOT NULL,
    post_id integer NOT NULL,
    reason character varying DEFAULT 'legacy'::character varying,
    message text,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);

--
-- Name: post_replacements; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.post_replacements (
    id serial NOT NULL,
    post_id integer NOT NULL,
    creator_id integer NOT NULL,
    original_url text NOT NULL,
    replacement_url text NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    file_ext_was character varying,
    file_size_was integer,
    image_width_was integer,
    image_height_was integer,
    md5_was character varying,
    file_ext character varying,
    file_size integer,
    image_width integer,
    image_height integer,
    md5 character varying
);

--
-- Name: saved_searches; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.saved_searches (
    id serial NOT NULL,
    user_id integer,
    query text,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    labels text[] DEFAULT '{}'::text[] NOT NULL
);

CREATE TABLE public.tag_rel_undos (
    id bigserial NOT NULL,
    tag_rel_type character varying,
    tag_rel_id bigint,
    undo_data json,
    applied boolean DEFAULT false,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);

--
-- Name: uploads; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.uploads (
    id bigserial NOT NULL,
    source text,
    file_path character varying,
    content_type character varying,
    rating character(1) NOT NULL,
    uploader_id integer NOT NULL,
    uploader_ip_addr inet NOT NULL,
    tag_string text NOT NULL,
    status text DEFAULT 'pending'::text NOT NULL,
    backtrace text,
    post_id integer,
    md5_confirmation character varying,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    server text,
    parent_id integer,
    md5 character varying,
    file_ext character varying,
    file_size integer,
    image_width integer,
    image_height integer,
    artist_commentary_desc text,
    artist_commentary_title text,
    include_artist_commentary boolean,
    context text,
    referer_url text,
    description text not null default ''::text
);
