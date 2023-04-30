--
-- PostgreSQL database dump
--

-- Dumped from database version 15.2
-- Dumped by pg_dump version 15.2

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
-- Name: billing; Type: DATABASE; Schema: -; Owner: -
--

\connect billing

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
-- Name: call_trigger_func(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.call_trigger_func() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
declare seconds int;
    call_minutes int;
    minutes_balance_value int;
    spent_minutes int;
    duration_interval interval;
begin
    if (extract(month from new.start_timestamp) != (select extract(month from max(start_timestamp))
                                                    from call
                                                    where user_phone = new.user_phone))
        then
        execute start_new_period(new.user_phone);
    end if;

    duration_interval := new.end_timestamp - new.start_timestamp;
    seconds := extract(second from duration_interval);
    call_minutes := (extract(day from duration_interval) * 24 + extract(hour from duration_interval)) * 60
                               + extract(minutes from duration_interval);

    if seconds != 0 then
        call_minutes := call_minutes + 1;
    end if;

    if new.call_type = '01' then
        if (select minutes_balance_in from tariff
            join phone p3 on tariff.tariff_id = p3.tariff_id
            where p3.user_phone = new.user_phone) = 0 then
            minutes_balance_value = (select minutes_balance
                                     from phone
                                     where user_phone = new.user_phone);
        else
            minutes_balance_value = 0;
        end if;
    else
        if (select minutes_balance_out from tariff
            join phone p3 on tariff.tariff_id = p3.tariff_id
            where p3.user_phone = new.user_phone) = 0 then
            minutes_balance_value = (select minutes_balance
                                     from phone
                                     where user_phone = new.user_phone);
        else
            minutes_balance_value = 0;
        end if;
    end if;

    if minutes_balance_value > call_minutes then
        spent_minutes = call_minutes;
    else
        spent_minutes = minutes_balance_value;
    end if;

    if new.call_type = '01' then
        new.cost = spent_minutes * (select minute_price_out from tariff
                                    join phone p2 on tariff.tariff_id = p2.tariff_id
                                    where p2.user_phone = new.user_phone)
                    + (call_minutes - spent_minutes) * (select expired_minute_price_out from tariff
                                                        join phone p2 on tariff.tariff_id = p2.tariff_id
                                                        where p2.user_phone = new.user_phone);
    else
        new.cost = spent_minutes * (select minute_price_in from tariff
                                    join phone p2 on tariff.tariff_id = p2.tariff_id
                                    where p2.user_phone = new.user_phone)
                    + (call_minutes - spent_minutes) * (select expired_minute_price_in from tariff
                                                        join phone p2 on tariff.tariff_id = p2.tariff_id
                                                        where p2.user_phone = new.user_phone);
    end if;

    update phone p
    set minutes_balance = minutes_balance - spent_minutes
    where new.user_phone = p.user_phone;

    update phone
    set user_balance = user_balance - new.cost
    where user_phone = new.user_phone;

    new.duration = extract(epoch from duration_interval);
    return new;
end
$$;


--
-- Name: change_tariff_trigger_func(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.change_tariff_trigger_func() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
    update phone
    set tariff_id = new.new_tariff_id
    where user_phone = new.user_phone;
    return new;
end
$$;


--
-- Name: get_tariff_minutes(character varying); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_tariff_minutes(tariff_id_par character varying) RETURNS integer
    LANGUAGE plpgsql
    AS $$
declare minutes_balance_in_value int;
        minutes_balance_out_value int;
        minutes_balance_summary_value int;
        minutes int;
begin
    minutes_balance_in_value = (select minutes_balance_in from tariff where tariff_id = tariff_id_par);
    minutes_balance_out_value = (select minutes_balance_out from tariff where tariff_id = tariff_id_par);
    minutes_balance_summary_value = (select minutes_balance_summary from tariff where tariff_id = tariff_id_par);
    minutes = select_max_of_three(minutes_balance_in_value, minutes_balance_out_value, minutes_balance_summary_value);
    return minutes;
end
$$;


--
-- Name: insert_call_trigger_func(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.insert_call_trigger_func() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
    update Call
    set duration = new.end_timestamp - new.start_timestamp
    where Call.call_id=new.call_id;
end;
$$;


--
-- Name: payment_trigger_func(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.payment_trigger_func() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
    update phone
    set user_balance = user_balance + new.money
    where phone.user_phone = new.user_phone;
    return new;
end
$$;


--
-- Name: phone_trigger_func(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.phone_trigger_func() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
declare minutes_balance_in_value int;
        minutes_balance_out_value int;
        minutes_balance_summary_value int;
        minutes int;
begin
    if new.user_balance is null then
        new.user_balance := 0;
    end if;

    minutes_balance_in_value = (select minutes_balance_in from tariff where tariff_id = new.tariff_id);
    minutes_balance_out_value = (select minutes_balance_out from tariff where tariff_id = new.tariff_id);
    minutes_balance_summary_value = (select minutes_balance_summary from tariff where tariff_id = new.tariff_id);
    minutes = select_max_of_three(minutes_balance_in_value, minutes_balance_out_value, minutes_balance_summary_value);
    new.minutes_balance := minutes;
    return new;
end
$$;


--
-- Name: select_max_of_three(integer, integer, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.select_max_of_three(a integer, b integer, c integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
BEGIN
    if a >= b and a >= c then
        return a;
    end if;
    if b >= c then
        return b;
    else
        return c;
    end if;
END;
$$;


--
-- Name: start_new_period(character); Type: PROCEDURE; Schema: public; Owner: -
--

CREATE PROCEDURE public.start_new_period(IN user_phone_param character)
    LANGUAGE plpgsql
    AS $$
declare tariff_id_value varchar(3);
begin
    tariff_id_value = (select tariff_id
                       from phone
                       where user_phone = user_phone_param);
    update phone
    set minutes_balance = get_tariff_minutes(tariff_id_value)
    where user_phone = user_phone_param;

    update phone
    set user_balance = user_balance - (select period_price
                                        from tariff
                                        where tariff_id = tariff_id_value)
    where user_phone = user_phone_param;
end
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: authority; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.authority (
    user_phone character(11),
    authority character varying(50) DEFAULT 'ROLE_USER'::character varying
);


--
-- Name: call; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.call (
    call_id integer NOT NULL,
    call_type character(2),
    user_phone character(11),
    start_timestamp timestamp without time zone,
    end_timestamp timestamp without time zone,
    duration bigint,
    cost real
);


--
-- Name: call_call_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.call_call_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: call_call_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.call_call_id_seq OWNED BY public.call.call_id;


--
-- Name: change_tariff; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.change_tariff (
    id integer NOT NULL,
    user_phone character(11),
    new_tariff_id character varying(3)
);


--
-- Name: change_tariff_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.change_tariff_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: change_tariff_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.change_tariff_id_seq OWNED BY public.change_tariff.id;


--
-- Name: credential; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.credential (
    user_phone character(11),
    user_password text,
    enabled smallint DEFAULT 1
);


--
-- Name: payment; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.payment (
    id integer NOT NULL,
    user_phone character(11),
    money real
);


--
-- Name: payment_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.payment_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: payment_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.payment_id_seq OWNED BY public.payment.id;


--
-- Name: phone; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.phone (
    user_phone character(11) NOT NULL,
    full_name character varying(50),
    tariff_id character(2),
    user_balance real,
    minutes_balance integer
);


--
-- Name: tariff; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tariff (
    tariff_id character varying(3) NOT NULL,
    tariff_name character varying(20),
    period_price integer,
    minutes_balance_out integer,
    minutes_balance_in integer,
    minutes_balance_summary integer,
    minute_price_out real,
    minute_price_in real,
    expired_minute_price_out real,
    expired_minute_price_in real,
    currency character varying(10)
);


--
-- Name: call call_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.call ALTER COLUMN call_id SET DEFAULT nextval('public.call_call_id_seq'::regclass);


--
-- Name: change_tariff id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.change_tariff ALTER COLUMN id SET DEFAULT nextval('public.change_tariff_id_seq'::regclass);


--
-- Name: payment id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment ALTER COLUMN id SET DEFAULT nextval('public.payment_id_seq'::regclass);


--
-- Data for Name: authority; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.authority (user_phone, authority) VALUES ('73919475874', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('71291490155', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('75986706566', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('79385020951', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('71545649140', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('78898752764', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('74098596990', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('76562113472', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('79161953795', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('73623967362', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('72447217847', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('79704716898', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('79069342146', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('78043667866', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('77292854049', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('73806731844', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('74103725995', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('72273961305', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('74308169070', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('71671698285', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('77772921970', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('77422328142', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('79065358010', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('71168033644', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('77567653731', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('75636077196', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('72734779147', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('74218502060', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('78435364043', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('78814887970', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('73989628674', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('74864734952', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('71561594555', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('78686128637', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('78067136487', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('73403994059', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('73288747033', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('73576725310', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('75584144600', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('71945668145', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('78762998936', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('79443519260', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('74952514465', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('72033925810', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('73818171028', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('74899325658', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('78423103014', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('76352510776', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('73383199407', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('77201342455', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('72632752188', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('74202848786', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('75533580710', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('72875764175', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('78954430622', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('72511051868', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('74606517716', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('73046122424', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('78831164190', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('79593191561', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('74563629313', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('79665385109', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('71518440042', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('79537470138', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('79281309534', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('71637260174', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('79157704345', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('72627778789', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('72741384959', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('76349198699', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('72672870339', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('77355774798', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('71762356387', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('79572627678', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('71971991436', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('78035695737', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('76148606622', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('72023504692', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('75487718131', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('71879411133', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('73588562714', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('75614704116', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('73564370089', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('78006372818', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('71417407207', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('72426875109', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('74645692064', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('76236446526', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('75784116599', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('78494215091', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('71173813293', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('78729911659', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('75115220267', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('77029616276', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('77255770545', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('73536773606', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('71398585342', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('79175721470', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('73841739318', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('78574143096', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('73781920701', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('78925254344', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('77181484324', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('74431325703', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('76001044819', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('78031847052', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('74889680134', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('77538378640', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('78751155960', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('76333788396', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('71459167975', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('72816531682', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('75234492277', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('79419957779', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('79202094108', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('71291117739', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('75573501621', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('71355262640', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('72996018441', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('78134725398', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('74596378312', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('72546214832', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('78206407439', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('72888624431', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('72328075739', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('71416018721', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('79408507920', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('74528153561', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('79956601127', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('71484146952', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('74007184283', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('76842567531', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('76911016103', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('79723177737', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('78056907538', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('75019245147', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('72384038355', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('73642314592', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('74926230420', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('73753340882', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('78401626251', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('75637573511', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('79284129322', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('76969079526', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('76644783558', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('76282941895', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('74692058471', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('71455802090', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('74937784396', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('75747451237', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('72347067403', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('75679817845', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('78818091421', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('74479964185', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('77972418320', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('72195085728', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('78055257656', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('79228123485', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('79463946325', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('75704120435', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('76739622691', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('71874374829', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('73895466919', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('74715299052', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('75863349982', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('77938677705', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('74576714592', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('78111626365', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('76222555048', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('72367060923', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('76545936200', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('73547644898', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('74582654927', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('77812094020', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('75568109709', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('77854496186', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('71816983400', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('76859315314', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('72847817204', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('74283606923', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('73934996428', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('76198408862', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('77272491342', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('76943937257', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('77961488033', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('72357872406', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('79921251756', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('78698578579', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('74048771617', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('72972057796', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('72361684412', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('74469387523', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('76004495724', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('71145911510', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('73076395583', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('76658580726', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('77309800893', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('75711000578', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('77843120904', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('77106384150', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('78782540855', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('72065821120', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('72682401370', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('78069156245', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('79826661966', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('75417856261', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('71385020179', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('76816042037', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('75748761836', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('77309157800', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('79576212244', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('79557438322', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('75154326926', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('78558788447', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('74382005263', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('78811350544', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('72202491853', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('77885082203', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('77573312997', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('72213618678', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('74525465464', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('77474010838', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('73666573496', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('76902625205', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('79259804335', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('77557583536', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('77617776718', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('76235302384', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('74716963835', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('72154358158', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('78759744840', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('73126298374', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('77094643467', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('77184944770', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('72628662029', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('78543957748', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('72721310109', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('73744358366', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('78183175966', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('77708033061', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('73443358970', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('71844557621', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('76965772798', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('78955861599', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('71932059398', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('74945961295', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('79698504096', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('74679159106', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('75738237366', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('73574061725', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('78233759896', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('71426263194', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('79368645741', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('71462105378', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('74187790919', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('77968693777', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('71852127169', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('72217194493', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('71832834350', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('76133377166', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('79238519201', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('71615713799', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('76471809452', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('79347881625', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('72635950112', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('79375650675', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('76335221319', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('79823386317', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('79555695567', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('71845665430', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('71737426126', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('75843285631', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('71281952311', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('78202621176', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('72642575109', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('71878032924', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('71194043655', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('79541156661', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('72389008948', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('76775686031', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('75711031958', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('73203051216', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('73087356069', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('71091538844', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('78367051873', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('75126015462', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('78161334513', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('78283673425', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('74442800327', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('79351426852', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('79801412605', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('77943198646', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('76696745296', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('75526693434', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('76955203772', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('72984881663', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('78585258851', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('71319233446', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('79915229968', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('73105211222', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('74879807192', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('75925488906', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('75171372847', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('75489399094', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('73602413454', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('79676094387', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('76491699014', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('78594343222', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('73574779392', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('76059048771', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('71225712195', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('78579305657', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('73233510288', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('78241780300', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('71847455775', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('76294581797', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('77594556215', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('75025159588', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('75214144219', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('71491587141', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('75656739971', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('77976109195', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('75648273304', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('79015491165', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('74313585134', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('79533051899', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('71669876723', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('78074274630', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('71338614845', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('79917097884', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('71347939865', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('76984568307', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('72074725124', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('74196652796', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('76738350567', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('79421411676', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('75884979931', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('77421305726', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('75972242407', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('78512007632', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('71487407356', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('71284451858', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('71314262135', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('74428826835', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('72143681816', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('72378637419', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('73392126613', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('72358483682', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('75598322895', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('74596439007', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('77278523567', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('78911633758', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('75272379453', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('77231261239', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('77167015296', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('73945295096', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('71832662753', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('71662579923', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('74844840049', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('78828267251', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('77667820453', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('76636350429', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('76622171278', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('77644871230', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('78163181003', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('77624666183', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('74015321132', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('75552428547', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('78272928323', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('79576008665', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('79006971317', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('76901240235', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('79711569684', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('72595285293', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('79505931676', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('75367647676', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('77238809848', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('73713556653', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('75842888851', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('79526129185', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('77574399278', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('73533294349', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('72945400374', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('78952849385', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('73979167760', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('76215841410', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('71885154368', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('75498692756', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('76605949257', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('71818542069', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('75466068477', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('76198156696', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('74296855622', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('72538605112', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('78029747117', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('77046375915', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('72249704431', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('79759482634', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('71939708226', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('78744571207', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('75461838282', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('76301035425', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('73065664527', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('77063108220', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('72732634606', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('75179947156', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('75884304012', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('74408265521', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('77272068713', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('76468992826', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('71073390466', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('74848926476', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('78665094890', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('75054965181', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('71029681298', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('76095228732', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('77067194678', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('79512228415', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('73885690829', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('73585773389', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('77875558236', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('74686797494', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('74732322989', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('78328352467', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('75751678656', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('74826500219', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('75181644685', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('71582017908', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('71039935738', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('79373053312', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('76728068721', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('72935761612', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('76324390703', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('75622023520', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('72351300630', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('78212769494', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('71285700831', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('74819396946', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('77515304551', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('71168206234', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('72072886311', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('71155447409', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('74498841869', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('79775738006', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('76053887304', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('74946851910', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('78897263751', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('78438431975', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('74465039493', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('71035287915', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('72637495308', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('73785183977', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('72148441021', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('71753505249', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('77094284204', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('74965685362', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('75156927355', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('73411863956', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('79996437207', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('76166297480', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('72035697287', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('74072561393', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('71458730635', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('78743963981', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('72387915640', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('73944728593', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('73059308411', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('75293263944', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('77002226790', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('78351463282', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('77905102371', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('79034479254', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('75886904111', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('75223665666', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('77385972537', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('77142986742', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('74848437515', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('77371135760', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('79116314149', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('71586778271', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('79628804786', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('76118846960', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('79177681043', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('74126444860', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('75518700416', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('76958795842', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('79179256795', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('73732864607', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('71275510240', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('77574218172', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('75347833700', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('71485017713', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('74228408375', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('73811759356', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('74695929132', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('79064019060', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('79907560011', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('73592232726', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('78336124154', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('76806636825', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('76152078944', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('75452983616', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('77973499911', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('76531955068', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('76714442294', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('79828391349', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('76251215741', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('75993237882', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('76386673693', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('75847849368', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('72464072658', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('73363450087', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('74148470142', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('74983775105', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('74907785826', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('77193126922', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('79384702146', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('76348668229', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('79499554886', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('74605372377', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('72097558218', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('76147499273', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('75335685182', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('74956681202', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('73165161835', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('73283614061', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('73748617423', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('79624915801', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('76133045219', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('72804886269', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('73643719961', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('79484535993', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('78629586483', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('74464338008', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('73618207677', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('71811001143', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('78144555099', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('73883605318', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('74414621116', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('74296609435', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('73821292688', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('78316035342', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('71898025769', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('78011650064', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('79631345629', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('78741285161', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('74787622555', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('76335650325', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('74799121080', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('77916194253', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('71031167031', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('78999129305', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('71637595894', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('74174752724', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('73661340687', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('71327364225', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('79439493662', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('72668898792', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('75357368069', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('79027982726', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('78478813208', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('74878355771', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('78933435249', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('78495651553', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('71928887304', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('75845216585', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('73885101273', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('77348468364', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('79808532610', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('78843082743', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('72536737491', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('73554282992', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('74786468185', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('76983680240', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('73992199320', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('71348054462', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('72024357238', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('72078487072', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('79076302369', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('79416213892', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('79489851211', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('78264218082', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('73718896259', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('73972879689', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('75513025288', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('78345576264', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('76042521011', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('78254121602', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('79281120199', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('76649314460', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('78033239724', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('79692848971', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('77691701039', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('77538932152', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('74917857954', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('79928784608', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('75642604586', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('74012179041', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('74318655944', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('75279494006', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('74247479313', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('72141803118', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('74746211878', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('72335297182', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('74495974929', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('75472072755', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('71291181620', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('74786128110', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('73989374416', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('77776406489', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('71764332315', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('77644029985', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('77411106357', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('79259997139', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('78744579200', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('74486891346', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('79891203978', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('78106186041', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('79163415994', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('76163050309', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('74043617690', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('75641481971', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('72703931517', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('71663166468', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('77633644670', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('76875136392', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('76248265659', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('74212772055', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('78959314187', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('73975668820', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('79222872054', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('77741385969', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('71622268852', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('74571383478', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('72654615912', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('78166418311', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('76046476325', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('73435650622', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('79521033228', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('74267570338', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('78466062345', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('75905441578', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('77438273526', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('77228449333', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('78295312025', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('74401428097', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('77166696156', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('73036625352', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('76734394126', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('76628686378', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('74087803866', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('79921801270', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('72336238627', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('76642234016', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('75829589136', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('79075522046', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('77137533262', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('75198541714', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('78413098543', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('77974655127', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('75826426593', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('79404302234', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('71546722640', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('71347578405', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('78141708963', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('76629073343', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('73564375538', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('73151066246', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('73746630543', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('75459144125', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('75153798640', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('75186071967', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('75031860729', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('78236611427', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('73771504935', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('76912003993', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('72281954896', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('79739189816', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('75364243247', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('76298847808', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('72445384307', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('75351596015', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('78304173049', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('74116615104', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('75231061193', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('71474515757', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('74642840928', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('76143242184', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('71535883272', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('71886900639', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('76447368356', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('77653484810', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('73084958568', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('79328308676', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('71003834681', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('72574050298', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('72718719344', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('76369842982', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('77451176486', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('72665053436', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('73301371778', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('71128714471', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('71199191784', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('79195431253', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('75373091389', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('79715134269', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('75118003540', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('77606808696', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('75337824523', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('77079345193', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('77588550346', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('74458710235', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('79475273386', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('79711161558', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('72165199794', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('75392088238', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('73271609333', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('74673381692', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('78962910167', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('72843214072', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('73717774758', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('79599054611', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('71071380476', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('76267221337', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('79279496837', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('77987449518', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('78395050029', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('73969827551', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('79528100672', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('71967812694', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('76981215571', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('72864464145', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('76675157006', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('74773000122', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('72203705215', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('71175482653', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('74683792303', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('76982112698', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('76914559776', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('79346128125', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('74928326374', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('75839744770', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('71217337916', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('79898238993', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('78975831358', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('74226231870', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('74945990275', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('77276767626', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('73876896480', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('77008733307', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('77908712196', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('77059679097', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('76754973675', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('71169417956', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('79833248607', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('73992004568', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('71449672082', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('79298535055', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('72343200184', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('71543723846', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('79552068376', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('72563518445', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('79691900547', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('75502692301', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('73649540418', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('73099962502', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('78017489596', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('72368249817', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('76684435787', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('71057428455', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('79966073431', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('72804302697', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('73921378807', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('78809776346', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('72877297877', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('78545767175', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('75427878372', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('78988827081', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('77306147467', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('75819407195', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('73863374607', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('79052145800', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('78032677316', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('74297751550', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('73134073423', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('72254350142', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('78216983745', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('77125482353', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('71998178511', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('73772422158', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('76973200767', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('74287482666', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('75692892606', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('72871783141', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('74272569142', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('75044785846', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('79739523139', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('76268156374', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('72615063473', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('77568834625', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('77726561528', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('79138860400', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('79628879600', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('79622231111', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('74428428344', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('75985456386', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('76392750251', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('79794667195', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('77377905367', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('75403580348', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('75193976142', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('79712343775', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('74848009998', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('76525384511', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('74358352753', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('75227542722', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('75643963090', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('72576751803', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('79111362422', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('71165374670', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('73159061805', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('71927216792', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('73468611184', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('71612276519', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('76095197978', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('76855127129', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('73162628236', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('76298240074', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('75756021087', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('79714413298', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('78044466839', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('71985636039', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('73934254914', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('77263437807', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('79467928973', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('79348540035', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('71567557398', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('77599999432', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('73428023075', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('75698253318', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('72018948402', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('71855285105', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('74599721594', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('73097661215', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('76457876746', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('73589988151', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('75845285268', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('74855970840', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('76285129606', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('76929261541', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('71089911285', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('74639482790', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('72881554591', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('78871009771', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('74353221058', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('78873894384', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('79265739230', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('75011094236', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('73064884148', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('76509763575', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('78452421538', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('74074354663', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('73312003667', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('77582689206', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('73996488249', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('71387971118', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('78328247251', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('71541557180', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('76104125497', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('75226005250', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('75954155629', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('79894743696', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('72656397545', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('78933562920', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('72729083022', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('77884947684', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('75511992109', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('74513106472', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('77567912487', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('72767297772', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('71464626102', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('79907463717', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('78413927053', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('78059263879', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('74462925352', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('79248135094', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('73148072536', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('78677009905', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('74433899350', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('74972191497', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('73217587509', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('79907628059', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('74257793273', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('73621223640', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('78253505671', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('78711952561', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('73686178542', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('72461884605', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('77468429855', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('71013452989', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('75318591891', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('76242083345', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('73058516937', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('74266193507', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('77432775470', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('77057826015', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('77174870718', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('75501572983', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('73802903831', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('76494926767', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('71785827015', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('77363047316', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('75792103348', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('73253802879', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('74946592818', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('71827754172', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('76033088687', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('71948704003', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('74994209538', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('75759663472', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('76478021954', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('76332094793', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('75035272232', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('79262607777', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('77337252551', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('76625029715', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('72165192388', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('73972407040', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('71714365981', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('71682203440', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('71887187492', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('77063953377', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('78036290593', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('75358425637', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('76239853574', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('77125243146', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('71945290280', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('79399098202', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('74238851704', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('77614845484', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('78699860437', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('76578802522', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('71414742072', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('79892053094', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('75977395603', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('71433244003', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('77378792406', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('76637581471', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('73946781522', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('79422404957', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('76532744288', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('75834523050', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('77435249180', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('78119528005', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('73175623240', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('72462770470', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('72224240226', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('71543949822', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('76161180677', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('76534353651', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('76357407284', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('79064990266', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('79226216566', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('79642295553', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('75066310820', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('75262331423', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('73386061802', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('72977687516', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('74462966742', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('72332024578', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('72464525959', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('77274561998', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('73998694394', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('78606393882', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('75636208388', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('71603334393', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('74342112854', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('71148013558', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('72378560419', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('76887163967', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('74549544635', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('74537949780', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('78359948886', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('78733272388', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('77837477704', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('71758811694', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('74158997404', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('73294342024', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('72801827363', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('73137136543', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('75204915344', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('77721629463', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('72108395929', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('73149990813', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('73296071596', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('72841057630', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('73089362358', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('79338337732', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('71706939698', 'ROLE_USER');
INSERT INTO public.authority (user_phone, authority) VALUES ('77755385674', 'ROLE_ADMIN');


--
-- Data for Name: call; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: change_tariff; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: credential; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('73919475874', 'FkaIR1G', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('71291490155', 'tCadFPk0', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('75986706566', 'ac3501LW9', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('79385020951', 'GvVBxOIwN', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('71545649140', 'z0yGyB', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('78898752764', '3vsuktPEu', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('74098596990', 'rMaquUFavW', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('76562113472', 'XXJyLYLb1', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('79161953795', 'x8yKnbSj4Kg', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('73623967362', 'kn8WDeQz', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('72447217847', 'w2GxXOnMARw', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('79704716898', 'tA25zi2oF', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('79069342146', 'GgLSKSsPiGoL', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('78043667866', '97VHkE', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('77292854049', 'bx7KbNm', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('73806731844', '4TN7pMumaC', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('74103725995', 'ZQNSTjNKIdP', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('72273961305', '9msUC2PsppzJ', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('74308169070', 'H4miwCUGMb', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('71671698285', 'I0TTPY', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('77772921970', 'jgD1m14sDoJu', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('77422328142', '3wp1I4W', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('79065358010', 'oWDl2j', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('71168033644', '2OAmCPvws', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('77567653731', 'UZ2Dxx', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('75636077196', 'tF1W5hyr0', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('72734779147', 'tWhpZi', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('74218502060', 'QIdj1QM9', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('78435364043', '1bOeSFxxM', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('78814887970', '1Nem5Wc', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('73989628674', '1ZFg1jbez', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('74864734952', 'npDeMriekJ', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('71561594555', 'Y37P3kqqMlS', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('78686128637', 'kpN0irjU', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('78067136487', 'NKc96579', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('73403994059', 'QK4dv8ht', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('73288747033', 'XbrRHbiqg1nu', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('73576725310', '3v3LcO757U', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('75584144600', '1hrSNX4wKxs', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('71945668145', 'gnMS5IA', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('78762998936', 'EzNXYqG', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('79443519260', '1EoSvM', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('74952514465', 'PNiKa2ktFN', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('72033925810', 'g3dkWn7', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('73818171028', 'xEAo3B', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('74899325658', 'BxNKIXmxx', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('78423103014', 'TmiE58q', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('76352510776', '7k243w', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('73383199407', 'UaL4vYdQl', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('77201342455', 'iRbQMEqBbRh', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('72632752188', '5Pp07lxGtI', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('74202848786', 'HW4iTV97U4s', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('75533580710', 'QF1jGVWM', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('72875764175', 'B3NOGoHoZ', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('78954430622', 'hG382bB', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('72511051868', 'pvkJP7Odk', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('74606517716', 'CDNNJwnC7', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('73046122424', 'jv2z3ceGZ', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('78831164190', 'k7E5RjIDKk', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('79593191561', 'e1XE0Ola0WB', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('74563629313', '0LQIT2wVPkLA', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('79665385109', 'Ch02Wg', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('71518440042', 'SstQFN00uFJR', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('79537470138', 'Tef8CCMZzMC', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('79281309534', 'cSHrV0vMXGHC', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('71637260174', '0KFqBwTmzqSd', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('79157704345', 'QcM3TCd', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('72627778789', 'dMgeYGFDGhc', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('72741384959', 'zY6heAC3PoXE', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('76349198699', 'GpUn7VAOv', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('72672870339', 'iMGXURsl', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('77355774798', 'VLBKqwD', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('71762356387', 'f48K3Toud', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('79572627678', 'gPRx68l8', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('71971991436', 'LhEANeId', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('78035695737', 'KaDNorf', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('76148606622', 'gji4BrAPdM', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('72023504692', '6IjoQ0x8Se', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('75487718131', 'AS3OjExuRkp5', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('71879411133', 'VBWKC7', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('73588562714', 'iCs8oVvk3xG8', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('75614704116', 'JAK1zwc', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('73564370089', 'NI5xJnPbj9z', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('78006372818', 'kpIukFVYQ', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('71417407207', 'Y8R7UyJ', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('72426875109', 'cp7NfKEU0DF', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('74645692064', 'eWFoTjtAN', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('76236446526', 'RU9JK0F', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('75784116599', 'UZPWM7aP', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('78494215091', 'SH4kvjn7Y', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('71173813293', '7lOxKLV0y8U7', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('78729911659', 'cmafBWR90', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('75115220267', 'NPt7RJb1', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('77029616276', 'FrlsSITnR', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('77255770545', 'WikEF0', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('73536773606', 'HLQjTkxfXTJr', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('71398585342', 'mbgVFnYgF', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('79175721470', 'SqPZjbTIKa', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('73841739318', 'U5kLhPa3BCN', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('78574143096', 'aUqdElJrNs', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('73781920701', 'b0AmuiNglV', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('78925254344', 'toLBbdMVbgl', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('77181484324', 'mzca8i', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('74431325703', 'KRKEBP4h0c', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('76001044819', 'BdGK5bs0qVxu', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('78031847052', 'zufn5U3', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('74889680134', 'ryeR6dftxzt', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('77538378640', 'tpoE2rz', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('78751155960', 'l2xGHUp', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('76333788396', '1ONTwTX', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('71459167975', 'MDvBRxbO', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('72816531682', 'tFdaTarWN', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('75234492277', 'pCG2PfG', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('79419957779', 'EHGvzeFxt', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('79202094108', 'hifDLPSMcku', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('71291117739', 'Pn03Mi5X59N', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('75573501621', 'HW4z5eju', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('71355262640', 'hmAO2WJ', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('72996018441', 'kIqkIEe', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('78134725398', 'CCjgnls4tyCP', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('74596378312', 'tek9Hn', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('72546214832', '9rpIazI', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('78206407439', 'QuxOhreR', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('72888624431', '22JuLr', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('72328075739', 'F93NqqqNuc', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('71416018721', 'U5gCSSqL', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('79408507920', '0tBoihsjYEU9', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('74528153561', 'VHaP76iD', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('79956601127', '9PYNfe', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('71484146952', 'vS442eYf', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('74007184283', '9lvCE8esE', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('76842567531', 'JCNCMV', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('76911016103', 'pIN1bJuyDkwM', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('79723177737', 'l7qwAe0DP', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('78056907538', '71tEdvhJ8QW', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('75019245147', 'zzuiLjw', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('72384038355', 'z4l3qPHxwNR', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('73642314592', 'D0RS2S7', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('74926230420', 'wJyt4JoLjG', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('73753340882', 'GQNeTdyXH', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('78401626251', 'xMKe1PPC6m', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('75637573511', 'fjazF7iAcxU6', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('79284129322', 'UFojx29', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('76969079526', 'QpUiWjgRv', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('76644783558', 'W4JljVc5qE', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('76282941895', 'IokOQl', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('74692058471', 'rzQA1XaTUn', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('71455802090', 'reSTWd3kW', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('74937784396', 'ZZG6nHBrr', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('75747451237', 'LpD1jGD', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('72347067403', 'LAlbQGL4lMt', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('75679817845', 'IgwWAxC4xF4', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('78818091421', 'ArVNlXv', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('74479964185', 'QdBoJGa5cX', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('77972418320', 'HHWfHtFSfk', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('72195085728', 'V26rDe', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('78055257656', 'f458zw', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('79228123485', 'rqKy8aN4SB0C', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('79463946325', 'Nz12XQOmmqtV', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('75704120435', 'herwBfqZ', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('76739622691', 'zAgg34D', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('71874374829', '6q6SdZ2OFGwq', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('73895466919', 'aLGTMkHX', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('74715299052', 'cOUO4AmN', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('75863349982', 'bfWNe7kcY', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('77938677705', 'ITEoSraKPt', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('74576714592', 'Ul63wttG', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('78111626365', 'B8djau', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('76222555048', 'zUBRNh', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('72367060923', 'XfFXXo', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('76545936200', '4I4hq4', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('73547644898', 'mIKEyZfE', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('74582654927', '77ng6maxlx', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('77812094020', 'BS31DL5E5DAk', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('75568109709', 'fdg7HDy00', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('77854496186', 'UaAVE8QVa', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('71816983400', '9Vxx7jVASd', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('76859315314', 'jA4mT8uNp', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('72847817204', '26ifDZyanOKP', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('74283606923', 'qq3qzUJTHK', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('73934996428', 'ad9qqMm', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('76198408862', '5u4X8Ngp', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('77272491342', '95qZ3lc', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('76943937257', '6H2U7R0', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('77961488033', 'tqasHZ', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('72357872406', 'S5pwmdw2LX9', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('79921251756', 'L0ILWbi5GmX', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('78698578579', 'qKRIBi', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('74048771617', '2fYVcByGzMtI', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('72972057796', 'EQd7GAjryb', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('72361684412', 'BRU8AOv1vt3', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('74469387523', '6w3dhn', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('76004495724', 'CYg0bRJx354', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('71145911510', 'Qwg3BcVa', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('73076395583', '3pOudD7G1cg', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('76658580726', 'pUfxdz1D', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('77309800893', 'OZKfrY', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('75711000578', 'Vyr5nyGruZ', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('77843120904', 'hqyTZBv', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('77106384150', 'seLs8mm', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('78782540855', 'TRfJa5Ya', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('72065821120', 'hb0ydWtk', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('72682401370', 'ICFrFV7NlNL', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('78069156245', 'GqnOB5', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('79826661966', 'u99MCd', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('75417856261', 'WfMolK', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('71385020179', '94Pc14l', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('76816042037', 'xb5aF7Vq', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('75748761836', 'oui2MOLD', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('77309157800', '3jjvUGZ', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('79576212244', 'vI9tgk', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('79557438322', 'HvlS4btWg', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('75154326926', '2qlyaA6', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('78558788447', 'qt0JIQJJ', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('74382005263', 'Sw1637r6', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('78811350544', 'kMNFtdYCJWk', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('72202491853', 'Xbs8e66Vy', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('77885082203', 'SGNxrCPeTq', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('77573312997', 'XoHXFJOEq', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('72213618678', 'GVYVFCs', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('74525465464', 'fZqXissH8HN', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('77474010838', '0zYdKoqTVa', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('73666573496', 'sR5NLmayCBo', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('76902625205', 'iUg7LuyD7E', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('79259804335', 'SQdy8NL4w', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('77557583536', '1AU6aH', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('77617776718', 'jM4DrcZwL21', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('76235302384', 'X9YU6KRdy5w', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('74716963835', '82Dvz6ZNhT', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('72154358158', '1gsLf6rp5h', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('78759744840', 'duhiaAqk', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('73126298374', 'e8JtApNXJxd', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('77094643467', 'yMNw2irfY6', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('77184944770', '29d3VY6qXLG', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('72628662029', 'an0s6k6aTEG', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('78543957748', 'EvVXHy', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('72721310109', 'Ef1WAi', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('73744358366', 'NF1zR5w7Uk', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('78183175966', 'rXrPxIESAR2X', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('77708033061', 'we84vRUneP', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('73443358970', 'HOSk55IplX', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('71844557621', '2PmHfCpSM', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('76965772798', 'aPKekgUNh', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('78955861599', '5pkHDx', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('71932059398', 'TQi8do', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('74945961295', 'tRYB86yCCJd7', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('79698504096', 'kipEu6yXVwS', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('74679159106', 'R9QMQacbcU', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('75738237366', '07JaIF813wTZ', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('73574061725', 'QCrGRpr8qdd', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('78233759896', 'P3vsEq6VQr', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('71426263194', 'a5y6jJ', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('79368645741', 'LT1dh8e2', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('71462105378', 'Nd8abD', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('74187790919', '0KNXRMg', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('77968693777', 'uzjVhKJfIw', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('71852127169', 'fAvmHs', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('72217194493', 'tmpiogJAj', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('71832834350', 'yK0B37nPzOz', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('76133377166', '00ZAF0zyH7', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('79238519201', 'YQdAGjhs6ww', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('71615713799', 'ISpLJf', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('76471809452', 'DSqaVSl', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('79347881625', 'EEgBUTWgj3', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('72635950112', '6anAYFP5Tl', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('79375650675', '2ivyja', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('76335221319', 'kffXOf', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('79823386317', '3tM4Ph', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('79555695567', 'nXbCdZ', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('71845665430', 'pkYNgYs', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('71737426126', '0DqqFr', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('75843285631', '7uOed7N', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('71281952311', 'bZWDPxzizMkm', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('78202621176', 'HUi0sT7ubn', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('72642575109', 'eKKLXVS0XREZ', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('71878032924', '9SPjBNT6QwN', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('71194043655', 'JDDaCWAQIKD', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('79541156661', 'fB9y8v18Jh51', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('72389008948', 'trncA9MJFzT', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('76775686031', 'GLgyjEg', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('75711031958', 'oVOGq2AWwJVE', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('73203051216', 'nSKQOK7x', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('73087356069', 'hmWo7S', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('71091538844', 'tLI2r4', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('78367051873', 'aoyzDr', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('75126015462', 'xsimKTdzwjj', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('78161334513', '4c4SyYag', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('78283673425', '5daIYjY6Ssmo', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('74442800327', 'r8R8q85', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('79351426852', '04yDkEJM', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('79801412605', 'NPOLVcVY92e', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('77943198646', 'tIR0HqMZy', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('76696745296', 'J0JGCDD0p', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('75526693434', 'ccDdYwSr0Pa7', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('76955203772', 'FWSu7UD', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('72984881663', 'Ul0aZq3urKY', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('78585258851', '9aEawisSEE', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('71319233446', '0Keu0qVu0G9W', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('79915229968', 'h3z6gaqj', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('73105211222', 'ieHWqIG6', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('74879807192', 'xgOfdM9kMoS', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('75925488906', 'Do0d4B3ke5o', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('75171372847', 'Y4UBHgHF', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('75489399094', 'fqEo03Qjp', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('73602413454', 'YqOhHbQRkVXp', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('79676094387', 'DyEVNbUX', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('76491699014', 'Pe1N7OUM', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('78594343222', '4JMMoSP4X', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('73574779392', 'vdawY2', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('76059048771', 'tQpOoqXwTeTn', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('71225712195', '2G97OTNPRq', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('78579305657', 'YlMnzPD', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('73233510288', 'oSbxzu', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('78241780300', '32zATP8', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('71847455775', 'yyygolEpn0U', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('76294581797', 'jM5TDQx', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('77594556215', 'MvnBCeHwLE7', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('75025159588', 'e70DQGVnc', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('75214144219', 'SJ9Sb1qeo', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('71491587141', 'YOrdQRTWAB', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('75656739971', 'hZhZJBkA', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('77976109195', 'Ejkqek3', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('75648273304', 'ECFJEmV', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('79015491165', 'zLJPKA', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('74313585134', 'kUCBW28y1Yq', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('79533051899', 'do4a994tp01', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('71669876723', 'Zw69JZ', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('78074274630', 'VztkNnaBVREr', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('71338614845', 'BRD5qa77gVG', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('79917097884', 'O6Qkq3YM', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('71347939865', 'fBWD8J2', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('76984568307', 'iMFousnXySFU', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('72074725124', 'KVa1gEOWfJ', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('74196652796', 'xt6lU0LrmwAX', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('76738350567', '5atPX8yCxnJ', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('79421411676', 'MR9chQQp', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('75884979931', 'flsxMfOkR', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('77421305726', '3x7gIIgzrVd', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('75972242407', 'rbQv9b8QnML', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('78512007632', 'FJ7Ilix27', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('71487407356', 'mdXoByzq', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('71284451858', 'ip0qioN', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('71314262135', 'hssu8FC7n7Z', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('74428826835', '8T429w9iOeU', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('72143681816', 'bcY7aTBk', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('72378637419', '95jfONnLAo', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('73392126613', 'qE7O6Yt9', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('72358483682', 'tr8cVvo', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('75598322895', '4y6KU2', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('74596439007', 'kGksbS26F', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('77278523567', 'l1YOAbm', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('78911633758', '35Zi0wBs8', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('75272379453', 'T00iapG0trRQ', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('77231261239', 'qfuTDR', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('77167015296', 'q02QEiAzC', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('73945295096', 'mpPP9cv0hkR4', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('71832662753', 'DInCXKJeg', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('71662579923', 'vGcoakcQkC9', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('74844840049', 'DoWXrqXo', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('78828267251', 'aF6dy5', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('77667820453', 'QoV1ZP0hgYS', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('76636350429', '9fedlyMDPc', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('76622171278', '0YtQW5', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('77644871230', 'U7hfNtvCiQOk', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('78163181003', 'KXIW8Ka', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('77624666183', 'h2IhAR', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('74015321132', 'SobEL04Z', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('75552428547', 'o3UHRvX', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('78272928323', 'VZHELF', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('79576008665', 'V3V98ft', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('79006971317', 'sPAiyhDsO5cz', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('76901240235', 'OdGs5LnkPWVN', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('79711569684', 't0IeUWUUs2vn', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('72595285293', 'VWPQeLqj', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('79505931676', '6skMlQ6AOa', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('75367647676', 'ShHz7VO', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('77238809848', 'cHYvWT', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('73713556653', 'pouMMWG5f3Z', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('75842888851', 'QjY9YERUsE', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('79526129185', 'ecRjUpHuO', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('77574399278', 'KGi4Ri', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('73533294349', 'Ppkiobr8sBD', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('72945400374', 'ONqUOU21bS', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('78952849385', '6t1QC0cux', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('73979167760', 'tnEXCe18', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('76215841410', 'q8jldOHdizH', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('71885154368', 'SN4sOI', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('75498692756', '8jnKf4c', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('76605949257', 'aOXIuPhUFIl', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('71818542069', 'BTRJHgyD', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('75466068477', 'ZI1XkMve9H35', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('76198156696', '10yD67hGn2T', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('74296855622', 'DFjcEzf', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('72538605112', 'apDGretQv', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('78029747117', 'lghOJdkX', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('77046375915', 'aGwra1p3s', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('72249704431', 'hbREUzU7k', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('79759482634', '9vSwKRv2Bq', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('71939708226', 'mE1cg9f3Q8i', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('78744571207', 'dljfcGlCiw', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('75461838282', 'APcOHt', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('76301035425', 'bpeDfhcfGv', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('73065664527', 'EpzQfqmOY', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('77063108220', 'p1H1DR', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('72732634606', 'JlPZ3FFW9ab', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('75179947156', 'ZlmRb9f', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('75884304012', 'fbF5r70i9eC', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('74408265521', 'qcZrmk5Yi', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('77272068713', '087wsL2Fev', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('76468992826', 'QB5XhL7ta', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('71073390466', 'NiBLlH', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('74848926476', 'm3XUZIVy', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('78665094890', 'yByrryLSWv', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('75054965181', 'Sg3xZq', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('71029681298', 'uaRgsjd', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('76095228732', '4L6bQB', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('77067194678', 'Gt7SkZJh5E', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('79512228415', 'Tsdxu0', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('73885690829', 'p0kQRD', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('73585773389', 'qCjVFN1psU', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('77875558236', 'zMdfIMh', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('74686797494', '89QJpsl', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('74732322989', '2KEmdU8a9', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('78328352467', 'XyHrkg33', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('75751678656', '3ixjQ3IOA7', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('74826500219', 'gMz972ohsdw', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('75181644685', 'GomsvGmKXsWD', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('71582017908', 'rXBsK8mb6r', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('71039935738', 'bRF9HZVWag', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('79373053312', 'URUx4G', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('76728068721', 'zEXFxRPtS5rG', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('72935761612', 'oQRHMpJp', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('76324390703', '33JSIxJeUN8', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('75622023520', 'Xhpxcd', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('72351300630', 'T6Yo2nBRS4', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('78212769494', 'w8AHIGyfTJZ8', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('71285700831', 'wfdXof', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('74819396946', 'k5Up2wOJW17', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('77515304551', 'O92ZXVSc', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('71168206234', 'dNgNRzx1gV', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('72072886311', 'u1yt6M', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('71155447409', '8MxAlgsguS3B', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('74498841869', 'lpYlfcR6y', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('79775738006', 'DtvpCzMN', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('76053887304', 'ovFEoWj0wv8', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('74946851910', '0H24SxSsShF', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('78897263751', 'loDKqW', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('78438431975', 'slc4Jybd', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('74465039493', 'G3hyamrVw0', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('71035287915', 'Qi5niZ7Gw', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('72637495308', '6K2VGFFRPE', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('73785183977', 'lSa6iApI', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('72148441021', 'srVyB9ER', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('71753505249', '1wfYRU', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('77094284204', 'JOer814Zh', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('74965685362', 'TRkwMqR', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('75156927355', 'XQJIumRn8X', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('73411863956', 'p1pZ7tG', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('79996437207', 'DwZFflxFzg', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('76166297480', 'syXdfEYWG', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('72035697287', '9vs6A74e', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('74072561393', 'YDtcl1h3s', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('71458730635', 'YHw6xQQ9', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('78743963981', '4JbzZu', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('72387915640', 'RRw9zaM', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('73944728593', '4Cy2k9h9Aq', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('73059308411', 'Xhbv9l1Q7pt', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('75293263944', 'pFJLqesg', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('77002226790', '53utKKZ3At', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('78351463282', 'TiJQAWTTeo', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('77905102371', 'OGVixqF', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('79034479254', 'DkQW1wlRpls', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('75886904111', 'ySoyBLXb1w1m', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('75223665666', 'zJ4ZM0', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('77385972537', 'Vdxi5v2yEsRc', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('77142986742', 'bBUPuTDpaIyU', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('74848437515', 'QC3awAS', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('77371135760', 'c0KXTCN7M', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('79116314149', 'X3XJQhAZ', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('71586778271', 'rjZhnr01ngaN', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('79628804786', '14MzLPIw', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('76118846960', 'av4mwkK', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('79177681043', 'OIi5HBjR4le', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('74126444860', 'F6kFcp', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('75518700416', 'GSamJja1hzOI', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('76958795842', 'MbHEU9C', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('79179256795', 'U4Kq0svb1I', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('73732864607', 'PhqLp0', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('71275510240', '43q5gX9cKWVF', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('77574218172', 'Fu51zdJEZ', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('75347833700', 'MaRMAs1W4', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('71485017713', 'LHcUmhH', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('74228408375', 'EwT8Sbj6', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('73811759356', '92sec0Z', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('74695929132', 'fDDNjV6f7', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('79064019060', 'vbhRWPOJhQIb', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('79907560011', 'JTk6fGYuq5E', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('73592232726', 'UtGi3CP', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('78336124154', 'TGhz5G', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('76806636825', 'izQeQQZz1', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('76152078944', 'NcqbaIg', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('75452983616', 'PnDCMklZ4', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('77973499911', 'mpQqJRizcA2I', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('76531955068', 'c1nDUZVfjw', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('76714442294', '0mkzw1iLshI', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('79828391349', '3qtGxnTyDw', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('76251215741', '5VqM1io2TZW', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('75993237882', 'o5yj0f77cq50', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('76386673693', 'cX4E8Rgxxt7m', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('75847849368', '4RTar5UgWc9u', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('72464072658', 'lU0bdVWMqlCC', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('73363450087', 'iu7oc62QSLF', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('74148470142', 'SA5DlKYyNT', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('74983775105', 'h2pChn', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('74907785826', '8IFz3AVAXiP', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('77193126922', 'uPKquM939NK', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('79384702146', 'RNQ0K6tAVx3n', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('76348668229', 'KHH7rlkZLVjF', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('79499554886', 'OXBsZjoQmyc', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('74605372377', 'Q0VMy26DxgA', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('72097558218', 'MuEislnye8fu', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('76147499273', '4I9tVY9p', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('75335685182', 'BMUd1hJV', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('74956681202', 'k6QwXJmdkvhF', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('73165161835', 'fG9rW0r', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('73283614061', 'IzAbi0h', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('73748617423', 'iolKpZdd', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('79624915801', 'Q7KAX1kALV', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('76133045219', 'fLjrIyy7', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('72804886269', 'I5JCAHwnO', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('73643719961', 'QRYBe2e1', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('79484535993', '4Speflx', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('78629586483', 'VFxHG1K9Eke', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('74464338008', 'SH9luc3uMU', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('73618207677', 'vxM9k3adpTL', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('71811001143', 'jSCWrhcoV', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('78144555099', 'QIQbuT', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('73883605318', 'BrCvAdfloc7', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('74414621116', 'SeoggVT1sN', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('74296609435', 'Gozi3yO2Z7', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('73821292688', 'mLl80wJCc3T', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('78316035342', 'LxJDuz', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('71898025769', '6hR7vhe1Z', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('78011650064', 'kE3Go9', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('79631345629', 'NuSPQOU', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('78741285161', 'qHE1ONFA', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('74787622555', 'P3PhmoW', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('76335650325', 'N1Er8Et', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('74799121080', 'mUGbDqat', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('77916194253', '8m3GtDa4vB', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('71031167031', 'yzRJPmFTTON', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('78999129305', 'EUYDTQPUj', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('71637595894', 'jDwSsNZq', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('74174752724', '1JTr92y5', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('73661340687', 'LUFGvbi26em', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('71327364225', 'RSM281Vpie', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('79439493662', '3IXJnZUfV3gx', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('72668898792', 'HmzHqH', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('75357368069', '4r1BEoev', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('79027982726', 'xWyMXTqKea', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('78478813208', '0F40kl0zvqw', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('74878355771', 'Scam64O', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('78933435249', '87EaeFh', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('78495651553', '4rFenEnK', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('71928887304', 'VGtxviNqQ', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('75845216585', 'ESKSdZb', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('73885101273', 'beAGu5Fz24J', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('77348468364', 'o21Mwm', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('79808532610', '51NTuxreTKi', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('78843082743', '6amIqlTl', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('72536737491', '3WuB0Sp59q', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('73554282992', 'KkhCy2ac', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('74786468185', '23mXc9cx', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('76983680240', 'LmH1yMXDx', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('73992199320', 'dyY42WukHj', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('71348054462', 'eCfKu9zk0', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('72024357238', 'gCDkNbp', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('72078487072', 'DJjKx5w', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('79076302369', 'IW2XeBKsiB3w', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('79416213892', 'htiESDP', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('79489851211', 'GPDeYMSRua1', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('78264218082', 'g0q3LfFRqCX', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('73718896259', 'MFrkRRXQ', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('73972879689', 'rUQ3jaI2gr', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('75513025288', 'zXbiuNdwoMbL', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('78345576264', 'nP8sqdKpYum', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('76042521011', '3oUHR6Nl', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('78254121602', 'SyhssoM', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('79281120199', 'k8TMY7Y518', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('76649314460', 'uBJ51pbZTgE', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('78033239724', 'CKrXm5Glj', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('79692848971', 'ydiaWuhfC', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('77691701039', 'yPJ3cluMZF', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('77538932152', 'DXFag4', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('74917857954', 'HsUUXDiX9csF', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('79928784608', 'm3wo6TJg', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('75642604586', 'TxyNehf8P', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('74012179041', 'Kc7OVGNrUi', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('74318655944', 'JT2EhOyP', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('75279494006', 'IQPtPqLGE', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('74247479313', 'zJtwINgA', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('72141803118', 'rEb0SQ', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('74746211878', 'G3fLlgCKPIC', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('72335297182', 'G6nXl3n', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('74495974929', 'EZSRcP', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('75472072755', 'Y71zvrb', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('71291181620', 'tyskcS7ATPQ', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('74786128110', 'hzjffY8Sm8P', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('73989374416', 'fpm2ZGEBZ921', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('77776406489', 'snma3ZPZ3uvx', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('71764332315', 'eDTudT9', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('77644029985', '2ePN4eC0P', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('77411106357', 'if3l34owC', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('79259997139', 'elmxYib', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('78744579200', 'wNG14Wl2ku', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('74486891346', 'sALyi4ary', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('79891203978', 'hGlllv', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('78106186041', 'cRlvUFhuM', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('79163415994', 'Ne0OWMbayM5u', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('76163050309', 'ZLuHM6zF', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('74043617690', 'QQZQa1j', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('75641481971', '4UZ1V8M4e', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('72703931517', 'FwPjaT0teo', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('71663166468', 'ClIqWw6yrH', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('77633644670', 'cgyXN5P4', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('76875136392', 'xZ4GTWvK', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('76248265659', 'exyb1Lha', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('74212772055', 'qDq3V7cWFCM', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('78959314187', 's0QntyYx', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('73975668820', '7J5VUbP', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('79222872054', 'fS10Eth', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('77741385969', 'Vd7ISCSvw', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('71622268852', 'NCa06TW5cNWq', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('74571383478', '4ceAYl0a', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('72654615912', 'zHvNQ2', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('78166418311', 'x8PWxhLxk630', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('76046476325', 'GHV6XdklGWir', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('73435650622', '8T6O4Zw', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('79521033228', 'ertsOtxuv', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('74267570338', 'U0bc0zN98LdA', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('78466062345', 'K5kVovwus8Y', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('75905441578', '1B76HWckLQo', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('77438273526', 'oKIYDQt1', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('77228449333', 'Opnd3g', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('78295312025', 'g3kFYRR', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('74401428097', 'TxrPuiqok', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('77166696156', 'ZPEj7g6r80A', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('73036625352', 'WNIEyxKAV', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('76734394126', 'EkWg8jB', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('76628686378', '7dK68z', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('74087803866', 'i3pLIHW9', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('79921801270', '6UR77ngLFOT', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('72336238627', 'aXgKhz3', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('76642234016', '1WQJQ4iC22', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('75829589136', '5bma0z', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('79075522046', 'LUBTCb', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('77137533262', 'h59oUN4re4f', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('75198541714', 'JQYaUuwcYkvn', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('78413098543', '04j5rdV05', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('77974655127', 't9lOaw', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('75826426593', 'lpG3Ajw2Rds9', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('79404302234', 'EQFSVmzATRSd', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('71546722640', 'MTtvgErVM', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('71347578405', 'Rvu364jKosA', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('78141708963', 'SKGxgstdw', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('76629073343', 'IEFdWh9S', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('73564375538', 'DZs3f8piFIv', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('73151066246', 'PlSfT7kfxq4U', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('73746630543', 'ysajGLq', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('75459144125', 'cODnuH', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('75153798640', '3LYtiC', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('75186071967', 'cbmgwv9Qy', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('75031860729', 'xmUmKSw6', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('78236611427', 'CJt4tu', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('73771504935', 'H7Gxc1mFmfA', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('76912003993', 'lJkKNdWzHt', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('72281954896', 'olllWfOJkpd', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('79739189816', 'dh5nlaRo0f', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('75364243247', 'aJzSNxuwBH9X', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('76298847808', 'r8aUimL2acy', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('72445384307', 'NXEhtoWJVPWw', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('75351596015', '0xQsd2mn', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('78304173049', 'sMe8Ah', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('74116615104', '6tMXqTBJn', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('75231061193', 'I4Sop2Ax5wt', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('71474515757', 'BGkFWlNo', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('74642840928', '6iUm4b', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('76143242184', 'cMH6jTS4', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('71535883272', 't96Fwwv', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('71886900639', 'HuqnLFh4UV', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('76447368356', '3v3GbEEe', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('77653484810', 'VLcBVCiCY', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('73084958568', 'RVhOSEJHrvvs', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('79328308676', 'x6zZKcN', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('71003834681', 'gdlBU5FG1zy', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('72574050298', 'VFyK6n7r9c3', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('72718719344', '3VssefWlR', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('76369842982', '8mlX1uV', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('77451176486', 'V5qd1e4g', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('72665053436', 'FEkZcAC', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('73301371778', 'sl9msxmo4ar', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('71128714471', 'Vg8EhfECy', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('71199191784', 'SnR8dQ', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('79195431253', 'C3kTe2GlqU', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('75373091389', 'exPilk', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('79715134269', 'nwF5RgS', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('75118003540', 'gQ5p7RE3u0v', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('77606808696', 'Zv7UeUyuld', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('75337824523', 'P36S4ZORH7WI', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('77079345193', 'r5CR12rQ', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('77588550346', 'ZHyHhYk4v0zj', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('74458710235', 'PchNSClUG3XJ', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('79475273386', 'RqgjEy', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('79711161558', 'OnSCVcWBcWW', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('72165199794', 'ZhpEwXrgACq', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('75392088238', 'lk9Ptwg', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('73271609333', 'ymDvLbkBSq', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('74673381692', 'WhAOzcMhyT9', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('78962910167', 'xUjcjypowSh', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('72843214072', 'BNEGgBy', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('73717774758', 'Alueafp', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('79599054611', 'ngVYj9', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('71071380476', 'JD9UlgkW', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('76267221337', 'AlCRp4k', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('79279496837', '0iIzIh0y3ZpI', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('77987449518', 'BidDMROGUxD', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('78395050029', 'gFISWgJ', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('73969827551', 'NESOyI4K', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('79528100672', 'S0FnFQF', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('71967812694', 'oqIO9k', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('76981215571', 'lLqtu3UaQ', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('72864464145', 'wojJwAR9hY2g', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('76675157006', 'YcfQUn7', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('74773000122', '1hcplDC6', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('72203705215', 'b72n2PirTrR', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('71175482653', 'TIsfLjROOFv', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('74683792303', 'u3yRNl', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('76982112698', 'YQbgMn7Ot', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('76914559776', 'I1I2NeFvZ', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('79346128125', 'nh40ggQX', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('74928326374', 'XotCaDxse', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('75839744770', 'xa9uHsoVrA3a', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('71217337916', 'hnM4PgIXwy', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('79898238993', '1G8SDcP73En', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('78975831358', 'y8RE1RiRr', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('74226231870', 'QfqV4J', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('74945990275', 'q3fmi3Y79', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('77276767626', 'Ki0pmrpUUSI', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('73876896480', 'ErBPpTA95q', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('77008733307', 'ZekPrRF6tm2F', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('77908712196', 'BShtag2', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('77059679097', 'n0EqpxO6', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('76754973675', '6aYz4r4L8Eo', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('71169417956', 'FsqukZR', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('79833248607', '2J5pWOmc', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('73992004568', '3J0EV2', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('71449672082', 'frpmoWvQp', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('79298535055', 'oDTY4l', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('72343200184', 'bCKKZHE', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('71543723846', 'zZAsSqRt', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('79552068376', 'qz7STSw', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('72563518445', 'kngApeQOa', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('79691900547', 'KQ8p7MeP', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('75502692301', 'thVCj0Yc', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('73649540418', 'difGPrV1s', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('73099962502', 'BtGf5FcHgHs5', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('78017489596', 'VPg0sDcRCIC', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('72368249817', 'qHh1t4', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('76684435787', 'm3eYXBTQTxCk', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('71057428455', 'qLzqkqJ', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('79966073431', 'JWXgTbssEq', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('72804302697', 'FJSzCVyZd68', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('73921378807', '3d996fbnWF3L', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('78809776346', 'bbxMtLDF', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('72877297877', '4zo23gET4Jet', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('78545767175', 'qAhQShzxt8', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('75427878372', 'tRHGhWck', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('78988827081', 'ROazrrSTx', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('77306147467', 'wXxREcpQ2', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('75819407195', 'Qsuy3FstT8', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('73863374607', 'dP8mlJjfFp54', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('79052145800', 'LnE07LgLRb', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('78032677316', 'KOyzLyH6TO', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('74297751550', 'RVyrI7', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('73134073423', 'Y8IUkQJ', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('72254350142', 'dZVwC5sj5H', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('78216983745', 'nFR6Pgyb', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('77125482353', 'nhnxJ4HK', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('71998178511', 'oontFE', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('73772422158', 'BkJJoA3Sn2Gv', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('76973200767', 'A2gbsXjkSn', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('74287482666', 'N2Dsfu265AG', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('75692892606', '5Qom8m', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('72871783141', 'iErfcOy', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('74272569142', 'yQXJWxglF', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('75044785846', 'imE7ccGEh', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('79739523139', 'Y1XQwA1Ohd', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('76268156374', 'ReXG00P', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('72615063473', '9uX7eZfCY', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('77568834625', 'I9XzOdEcs', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('77726561528', 'piGWBQj', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('79138860400', 'gq8A5j', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('79628879600', 'UZ0EiMRW', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('79622231111', 'GUSQTcYms', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('74428428344', 'WiCO2Q', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('75985456386', 'YW7TiNV', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('76392750251', 'yj2HbadTQxTj', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('79794667195', 'vzF7cUQNFAqB', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('77377905367', 'dI5pIIZ4', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('75403580348', 'JCi8kGsCE', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('75193976142', 'ogK2gOi', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('79712343775', 'Pev5HD', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('74848009998', 'fZ6nxjfAZ6eZ', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('76525384511', 'yeTRzUReP', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('74358352753', '6SAZrm1', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('75227542722', 'SR6syms', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('75643963090', '9Qpmy6', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('72576751803', 'nC5Pcwn', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('79111362422', 'VzZVjD', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('71165374670', 'yaWhFLj1mIa1', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('73159061805', 'xIrqDj', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('71927216792', '0whJ4di', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('73468611184', '9ZH8YvY5Lb5', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('71612276519', 'ARMMokxWY', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('76095197978', 'U8jhJJj', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('76855127129', 'QJzR93W', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('73162628236', 'n3KLvnN76jO7', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('76298240074', 'tLc2jRhWz', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('75756021087', '8mV4Hz', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('79714413298', 'DCsbpTM', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('78044466839', 'IXDe8eCy5', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('71985636039', 'k1FaehWvTX9s', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('73934254914', 'YOBLQDlFbC', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('77263437807', 'mDDWC0N1', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('79467928973', 'bXjcv7nN', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('79348540035', 'zqWlYGi2MkAS', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('71567557398', '0Ct2LAqgsy7v', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('77599999432', 'hm4NLH', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('73428023075', 'vr6K2pNX', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('75698253318', 'dLl7vMOG0I', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('72018948402', '95kcYQXfvi0O', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('71855285105', 'AUtPoBu', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('74599721594', 'n7iIDc4To', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('73097661215', '9XMWtYbHMWH7', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('76457876746', '5qtLQiBI', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('73589988151', 'mEc0d0bZ', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('75845285268', 'rmuOydDh8', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('74855970840', '7y5ZisExxDvS', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('76285129606', '1gDKBzycAzc', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('76929261541', 'IRSOeQ', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('71089911285', 'ECRs2abIkw', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('74639482790', '7BvT66RYs', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('72881554591', 'yOPxgnMdBi5', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('78871009771', '1f9pyVL', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('74353221058', 'AK2sy2', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('78873894384', 'AX84aa', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('79265739230', 'M0riwc9fBNG', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('75011094236', 'RC4uEHtSAGY', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('73064884148', 'Canc5w', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('76509763575', 'SR0icKrRwSn', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('78452421538', 'ttjQAic1ZXh', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('74074354663', 'Xpglg5AQz', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('73312003667', 'Sx2K5wNH', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('77582689206', '9jCz2mu', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('73996488249', 'PPdagas4t4', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('71387971118', 'gOAISUBK', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('78328247251', 'FWii3RNXJ9h', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('71541557180', 'gOIQ2R1AN', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('76104125497', 'Ub6talfW', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('75226005250', 'dkNYKglvAwX', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('75954155629', 'B3gjT2SmmuE', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('79894743696', 'j1QOyL', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('72656397545', 'fuFjz96Z', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('78933562920', 'Z5zDM9b7g', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('72729083022', 'jrMH8Vo6', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('77884947684', 'iVjXkxGMb', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('75511992109', 'ETm0nQtFZn', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('74513106472', 'KbUzCjZjaDn', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('77567912487', 'RbhOAp4QLY9K', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('72767297772', 'kdFG1Zd1g0b', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('71464626102', '004kdVUQV9u', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('79907463717', 'wykBtzha', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('78413927053', 'TepwLry7', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('78059263879', 'RztCrwLGrnK', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('74462925352', 'SHY2TIF', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('79248135094', 'co7ohEep46S', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('73148072536', 'uaawGIt5Y', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('78677009905', 'b9izz1oR6JEg', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('74433899350', 'v1es6EEuAIgO', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('74972191497', 'oWoerBYNW', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('73217587509', 'myzirg', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('79907628059', 'htU3KUssdIf', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('74257793273', 'iuW0acoa', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('73621223640', '96Cjjted', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('78253505671', '5H2ElD', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('78711952561', 'Lx7UHXIgcz', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('73686178542', 'gVX4C2PTtd', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('72461884605', 'nO3IUmfk', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('77468429855', '2ThAmLeeofzZ', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('71013452989', 'qNIk6tPJm2z', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('75318591891', 'exuBly6', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('76242083345', 'eS9wZEeKx', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('73058516937', 'RXrQrKEjDSSI', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('74266193507', 'iJhQ21a', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('77432775470', 'gdWQSaf', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('77057826015', 'p32hTbMtyzB', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('77174870718', 'CzWsMx', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('75501572983', 'h9DfIKaER', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('73802903831', 'WqbkMMEtQeX', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('76494926767', 'kX3IHO', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('71785827015', 'Ydmk5z', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('77363047316', 'JXOMdRfA', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('75792103348', '5HUllfEkwmr', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('73253802879', 'Y0TkCbcbw', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('74946592818', 'ofFeBn', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('71827754172', 'ZwkLT0K', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('76033088687', 'aopCCcDY', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('71948704003', 'tr4kVBK', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('74994209538', 'ykz0mYT', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('75759663472', 'COv7dMZzSnH', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('76478021954', 'Iv4tlfDocl9', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('76332094793', 'mh5QJeJhNW', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('75035272232', '7H6H2KgbN', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('79262607777', '2NOncm', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('77337252551', 'HgESBbUrKo', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('76625029715', 'A1fFvvxMJe7c', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('72165192388', 'RszzP6', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('73972407040', '247KB0vcqPI', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('71714365981', '8XNzij5kaSU', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('71682203440', 'qUV1K6HL', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('71887187492', '7x9uyBvpa', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('77063953377', 'dXXO6GaaJE', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('78036290593', '4inolF', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('75358425637', 'g34TUw6T6TD9', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('76239853574', 'pNBTDMr0D5', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('77125243146', 'CYa8oqw', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('71945290280', 'LX8Sv5jZDR', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('79399098202', 'zT1sAszY9u', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('74238851704', 'udBrlKT7', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('77614845484', '1Vuqn79e', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('78699860437', '7A0G7wPsIiJ', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('76578802522', 'Zq8PtoW', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('71414742072', 'PXoRYJhO', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('79892053094', '4G34vagVjScy', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('75977395603', 'DfUqDgM6L3Am', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('71433244003', 'L6K558', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('77378792406', 'Nz2crc0', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('76637581471', 'TrBM6SfF', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('73946781522', 'wSkTY0', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('79422404957', '3plKwQ', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('76532744288', 'JbgqHNc', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('75834523050', '6tvqW6Kx', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('77435249180', 'gaEW7n', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('78119528005', 'slUbSX1dAb', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('73175623240', 'onopFK25c', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('72462770470', 'nkrpcwhq', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('72224240226', '92TDS03qIqQ', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('71543949822', 'ymfsUHB1', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('76161180677', 'cpLIZPG6ydTw', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('76534353651', 'Txaeji7e1R', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('76357407284', '5GYzYGTogQVR', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('79064990266', '2YhSVQ', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('79226216566', 'eBJ8KL', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('79642295553', 'lke3qwD', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('75066310820', 'IxpZfjwB3U', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('75262331423', 'NPy6dLd', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('73386061802', 'O62quKrkEtbV', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('72977687516', 'XL2A9ypxM9H', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('74462966742', 'qYcqYDpH1hcH', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('72332024578', 'e71dGlS', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('72464525959', 'CfloShus', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('77274561998', 'mF0kFY5HIRJn', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('73998694394', '4cCjRn', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('78606393882', 'bVF945lljkm', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('75636208388', 'bwYjX6C', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('71603334393', 'Z9dOy92', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('74342112854', 'Jwf8vmj', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('71148013558', '2zz2uNwl', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('72378560419', '4J6kd9gS', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('76887163967', 'kRTEercAP2d', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('74549544635', 'mQ2VTmB', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('74537949780', 'HGUGi9Ff3', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('78359948886', 'mbVcjrfF5', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('78733272388', 'jLrydbH', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('77837477704', 'k7eHVqxNUfOf', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('71758811694', 'YphSMTgK', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('74158997404', 'qU2GpW3VCk', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('73294342024', 'KEX5YqXCX', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('72801827363', 'MrLY06A', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('73137136543', 'FesvNtpxhj', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('75204915344', 'r5K10i', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('77721629463', 'ASOdMWFEFJVG', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('72108395929', 'KHO22h', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('73149990813', 'HYcwGJ', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('73296071596', 'PgAYS0pWO', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('72841057630', 'p0xl898c', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('73089362358', 'XnWvX3bSx', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('79338337732', 'ng4NfqXz8Yv', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('77755385674', '$2a$10$xy9j2ezvB3cP8fT6f7baTOVHDx85n3NIMwfeCJYdAAL./42WEx65K', 1);
INSERT INTO public.credential (user_phone, user_password, enabled) VALUES ('71706939698', '$2a$10$XpKWnq4MA0PeseHSm9u7t.T0IqEcujEPAoK8f0AVharPeeOyGFHbm', 1);


--
-- Data for Name: payment; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: phone; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('71706939698', 'Edward Olyet', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('73919475874', 'Jacintha Jewar', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('71291490155', 'Sherline Olliff', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('75986706566', 'Addi Feavyour', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('79385020951', 'Fredra Glendining', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('71545649140', 'Gale Stoyell', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('77755385674', 'Barbee Elijah', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('78898752764', 'Roseline Harse', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('74098596990', 'Haley Goodall', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('76562113472', 'Cyril Serrier', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('79161953795', 'Herman Leyborne', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('73623967362', 'Aloin Whetson', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('72447217847', 'Sky Deare', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('79704716898', 'Frieda Maciejewski', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('79069342146', 'Clim Bolesworth', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('78043667866', 'Kristal Tomaselli', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('77292854049', 'Henry Corsor', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('73806731844', 'Jermaine Duncombe', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('74103725995', 'Pamelina Egell', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('72273961305', 'Armand Cohen', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('74308169070', 'Lorrie Auletta', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('71671698285', 'Leandra Axworthy', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('77772921970', 'Domenico Langton', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('77422328142', 'Faun Sepey', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('79065358010', 'Stace Guilliland', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('71168033644', 'Pietro Withnall', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('77567653731', 'Malva Kettlestringe', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('75636077196', 'Hank Forward', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('72734779147', 'Carolus Beste', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('74218502060', 'Neely Coushe', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('78435364043', 'Honoria Henaughan', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('78814887970', 'Maren Duckwith', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('73989628674', 'Wrennie Hilland', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('74864734952', 'Coreen Frankom', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('71561594555', 'Sibby Vinnicombe', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('78686128637', 'Ernaline Deary', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('78067136487', 'Trix Franceschielli', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('73403994059', 'Karin Ciciotti', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('73288747033', 'Bobine Palay', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('73576725310', 'Harrison Branno', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('75584144600', 'Valeda Faustin', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('71945668145', 'Harlen Chaplin', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('78762998936', 'Horton Ramsey', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('79443519260', 'Johnathon Sexcey', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('74952514465', 'Alvy Tilte', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('72033925810', 'Willey Offa', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('73818171028', 'Lesley Horrigan', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('74899325658', 'Fayth Burkwood', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('78423103014', 'Jennie Davidovits', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('76352510776', 'Letitia Jakubovsky', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('73383199407', 'Deedee Tawse', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('77201342455', 'Ring Joseph', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('72632752188', 'Damien Cowsby', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('74202848786', 'Merola Dulinty', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('75533580710', 'Winni Sayes', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('72875764175', 'Ashbey Wych', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('78954430622', 'Mab Lippatt', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('72511051868', 'Micky Polland', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('74606517716', 'Gilly Lantiff', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('73046122424', 'Rita Walling', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('78831164190', 'Ernst Baptiste', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('79593191561', 'Regen Everington', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('74563629313', 'Morganne Copelli', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('79665385109', 'Sharla Trevillion', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('71518440042', 'Sarah Danilenko', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('79537470138', 'Natala Tomala', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('79281309534', 'Gray Schelle', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('71637260174', 'Jocelyne Kibbey', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('79157704345', 'Avivah Emeline', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('72627778789', 'Antoni Burnsyde', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('72741384959', 'Demeter Guly', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('76349198699', 'Shandy Ondracek', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('72672870339', 'Sarge Oldridge', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('77355774798', 'Orlando Noble', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('71762356387', 'Tatiana Ventom', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('79572627678', 'Kippie Warham', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('71971991436', 'Ralph Daborn', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('78035695737', 'Sargent Stollard', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('76148606622', 'Trey Munslow', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('72023504692', 'Cordula Cato', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('75487718131', 'Averil Storer', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('71879411133', 'Raynor Boden', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('73588562714', 'Burlie Ferie', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('75614704116', 'Domingo Croney', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('73564370089', 'Nola Basnett', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('78006372818', 'Loretta Pastor', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('71417407207', 'Cornelius Abbate', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('72426875109', 'Teirtza McBeath', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('74645692064', 'Jeralee Glading', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('76236446526', 'Brynne Lortz', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('75784116599', 'Hal Thulborn', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('78494215091', 'Brendan Pentycross', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('71173813293', 'Sergeant Bricklebank', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('78729911659', 'Bradford St Louis', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('75115220267', 'Sibel McCutcheon', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('77029616276', 'Gayle Saffran', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('77255770545', 'Ginevra Stanmore', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('73536773606', 'Felicle Huson', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('71398585342', 'Biddy Rowsel', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('79175721470', 'Shelia Turfs', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('73841739318', 'Nessa Stuchburie', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('78574143096', 'Nikolaus Shevlin', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('73781920701', 'Kaitlyn Fassbender', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('78925254344', 'Smitty Brecknall', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('77181484324', 'Thornie Atcherley', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('74431325703', 'Dulsea Stodhart', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('76001044819', 'Normand Twelftree', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('78031847052', 'Katinka Foakes', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('74889680134', 'Bambi Brierly', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('77538378640', 'Kaitlyn Wasmuth', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('78751155960', 'Devora Carpenter', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('76333788396', 'Carmella Sturdy', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('71459167975', 'Karla Rein', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('72816531682', 'Gavra McConnel', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('75234492277', 'Gene Cosins', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('79419957779', 'Sharity Malek', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('79202094108', 'Geneva Ca', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('71291117739', 'Selina Woodwind', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('75573501621', 'Aurilia Patron', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('71355262640', 'Chrysler Cockland', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('72996018441', 'Lib Cadlock', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('78134725398', 'Cecilio Connor', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('74596378312', 'Malia Devil', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('72546214832', 'Matthieu Jenoure', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('78206407439', 'Abigail Amor', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('72888624431', 'Alfy Blenkensop', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('72328075739', 'Northrup Amesbury', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('71416018721', 'Cally Livingston', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('79408507920', 'Rozalie Iacobini', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('74528153561', 'Avram Colleford', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('79956601127', 'Niall McNea', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('71484146952', 'Tades McMyler', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('74007184283', 'Gilberto Krolak', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('76842567531', 'Juliet Klossek', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('76911016103', 'Yoko Dalling', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('79723177737', 'Debor Bausmann', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('78056907538', 'Andromache Rameau', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('75019245147', 'Barbette Radnage', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('72384038355', 'Hannis Boulter', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('73642314592', 'Berkie Jambrozek', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('74926230420', 'Austina Kipling', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('73753340882', 'Alejoa Horsefield', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('78401626251', 'Donelle Sivyer', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('75637573511', 'Trish Cade', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('79284129322', 'Beatrisa Butson', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('76969079526', 'Keane Simmans', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('76644783558', 'Washington Starrs', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('76282941895', 'Flinn Moggle', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('74692058471', 'Lilia Lydden', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('71455802090', 'Wilbert Simoncelli', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('74937784396', 'Sawyer Spraberry', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('75747451237', 'Derron McMychem', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('72347067403', 'Windy Snugg', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('75679817845', 'Broderick Bawcock', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('78818091421', 'Ilse Kippie', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('74479964185', 'Brandi Feaviour', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('77972418320', 'Barclay Lethbury', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('72195085728', 'Cole Olding', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('78055257656', 'Dayle Grishukov', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('79228123485', 'Zahara Blumson', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('79463946325', 'Graeme Hazart', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('75704120435', 'Leonore Rubroe', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('76739622691', 'Cale Somersett', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('71874374829', 'Ruby Ville', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('73895466919', 'Cristina Trowill', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('74715299052', 'Amaleta MacAne', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('75863349982', 'Elke Aldins', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('77938677705', 'Falkner Savile', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('74576714592', 'Mariellen Matzkaitis', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('78111626365', 'Inna Doughill', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('76222555048', 'Paulette Hendin', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('72367060923', 'Josephine Aleksankin', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('76545936200', 'Eileen Daen', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('73547644898', 'Basile Mattisssen', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('74582654927', 'Phelia Abrahami', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('77812094020', 'Kingsley Tarren', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('75568109709', 'Elva Stidston', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('77854496186', 'Felizio Di Carli', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('71816983400', 'Jaquenette Fettes', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('76859315314', 'Maison Shipcott', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('72847817204', 'Rodd Dungee', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('74283606923', 'Natala Bridgstock', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('73934996428', 'Shina Ionn', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('76198408862', 'Ailyn Towll', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('77272491342', 'Adele Oxton', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('76943937257', 'Arv O''Crigane', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('77961488033', 'Devora Crunkhurn', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('72357872406', 'Aldo Surpliss', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('79921251756', 'Broddie Ornelas', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('78698578579', 'Bertrand Morsley', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('74048771617', 'Claudianus Kinworthy', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('72972057796', 'Gwen De Domenici', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('72361684412', 'Simon Cornewell', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('74469387523', 'Elnar Deave', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('76004495724', 'Clarette Lanphere', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('71145911510', 'Melicent Palffrey', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('73076395583', 'Dal Hullock', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('76658580726', 'Shena Kevlin', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('77309800893', 'Illa Wansbury', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('75711000578', 'Nicol Walburn', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('77843120904', 'Anitra Amar', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('77106384150', 'Benedetta Lezemore', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('78782540855', 'Huntlee Holdworth', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('72065821120', 'Therese Fealy', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('72682401370', 'Ricki Edleston', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('78069156245', 'Gusta Henden', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('79826661966', 'Anatollo Morten', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('75417856261', 'Lonnie Gypson', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('71385020179', 'Dane Guillerman', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('76816042037', 'Gianni Traice', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('75748761836', 'Elsbeth Langland', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('77309157800', 'Cyrus Galley', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('79576212244', 'Lorilyn Vanyukov', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('79557438322', 'Emelita Shelliday', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('75154326926', 'Jenda Sickert', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('78558788447', 'Elisha Turbern', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('74382005263', 'Debera Sopper', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('78811350544', 'Cory Ruscoe', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('72202491853', 'Lenora Maidment', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('77885082203', 'Ronica Cadany', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('77573312997', 'Cordey Iddiens', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('72213618678', 'Chrisy Ewles', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('74525465464', 'Bradan Simonnot', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('77474010838', 'Rowland Penrith', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('73666573496', 'Jedd Wiltshire', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('76902625205', 'Koralle Bradd', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('79259804335', 'Henry Lindro', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('77557583536', 'Jodi Coppens', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('77617776718', 'Abbie Markwelley', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('76235302384', 'Liz Adamini', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('74716963835', 'Juieta Anstice', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('72154358158', 'Lewes Evison', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('78759744840', 'Jasmina McGaraghan', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('73126298374', 'Judy Messruther', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('77094643467', 'Diarmid Master', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('77184944770', 'Mil Reynolds', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('72628662029', 'Merrielle Huggons', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('78543957748', 'Clair Fulop', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('72721310109', 'Rozelle Coviello', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('73744358366', 'Lorri Helin', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('78183175966', 'Guillermo Pantecost', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('77708033061', 'Oliviero Grolle', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('73443358970', 'Celeste Holdren', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('71844557621', 'Thedric Fetters', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('76965772798', 'Johnna Fley', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('78955861599', 'Haily Miners', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('71932059398', 'Karol Ashpole', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('74945961295', 'Shalna Thursfield', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('79698504096', 'Roi Baise', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('74679159106', 'Karly Philipeau', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('75738237366', 'Gussi Farmar', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('73574061725', 'Lamar Spenceley', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('78233759896', 'Eleonore Dandy', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('71426263194', 'Wenonah Crighton', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('79368645741', 'Milzie Boynes', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('71462105378', 'Fitz Gulliford', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('74187790919', 'Shelbi Milborn', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('77968693777', 'Sheila Dooland', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('71852127169', 'Katharine Ervin', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('72217194493', 'Crissie Bromage', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('71832834350', 'Ilise Berends', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('76133377166', 'Adaline Wixey', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('79238519201', 'Candice Meneely', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('71615713799', 'Barbi Pavolini', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('76471809452', 'Lisha MacCosty', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('79347881625', 'Lindon Crotty', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('72635950112', 'Lyndsie Quinney', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('79375650675', 'Sarita Lindl', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('76335221319', 'Anjela Duly', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('79823386317', 'Katrina Egle of Germany', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('79555695567', 'Edward Lodwig', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('71845665430', 'Granger Pleasants', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('71737426126', 'Emera Adran', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('75843285631', 'Cairistiona Tousey', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('71281952311', 'Kory O''Hartnedy', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('78202621176', 'Charissa Print', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('72642575109', 'Upton Odell', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('71878032924', 'Lamond le Keux', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('71194043655', 'Zia Bubbins', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('79541156661', 'Dannie Bourgourd', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('72389008948', 'Wilone McGettigan', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('76775686031', 'Muffin Gipp', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('75711031958', 'Marja Amys', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('73203051216', 'Hube Mixter', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('73087356069', 'Kristen Bocking', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('71091538844', 'Ashlan Posner', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('78367051873', 'Barbabas Tarbatt', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('75126015462', 'Griffith McKoy', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('78161334513', 'Robby Trigwell', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('78283673425', 'Boy Hartford', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('74442800327', 'Hollie Waight', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('79351426852', 'Brennan Hodgon', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('79801412605', 'Lorianne Maseyk', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('77943198646', 'Pepe Staff', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('76696745296', 'Carter Vasilchikov', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('75526693434', 'Deirdre Tolerton', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('76955203772', 'Giralda Iltchev', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('72984881663', 'Nita Gatheral', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('78585258851', 'Lind Leindecker', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('71319233446', 'Jacky Matcham', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('79915229968', 'Ikey Vlasyev', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('73105211222', 'Luke Chillcot', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('74879807192', 'Fidelia Beamond', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('75925488906', 'Sherlocke Bernette', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('75171372847', 'Kassia Cutforth', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('75489399094', 'Nickolaus Millar', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('73602413454', 'Terra Pogson', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('79676094387', 'Flor Razoux', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('76491699014', 'Gail Dobel', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('78594343222', 'Randee Calderhead', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('73574779392', 'Katinka Kernley', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('76059048771', 'Charley Landis', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('71225712195', 'Annice Kuhle', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('78579305657', 'Myrta Hamsher', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('73233510288', 'Rosemaria Baptiste', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('78241780300', 'Elissa Cottis', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('71847455775', 'Emmit Bohea', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('76294581797', 'Delainey Tromans', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('77594556215', 'Sabrina Sesons', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('75025159588', 'Zonnya Griffey', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('75214144219', 'Salvatore Dufoure', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('71491587141', 'Josee Polhill', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('75656739971', 'Aubert Hudson', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('77976109195', 'Thorvald Smeal', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('75648273304', 'Craig Gansbuhler', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('79015491165', 'Zea Muddicliffe', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('74313585134', 'Devin Glowach', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('79533051899', 'Dorris Pottell', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('71669876723', 'Irving Watson-Brown', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('78074274630', 'Keri Celiz', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('71338614845', 'Abram Haugeh', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('79917097884', 'Gipsy Phettiplace', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('71347939865', 'Norrie Cottu', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('76984568307', 'Steffane Frane', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('72074725124', 'Henryetta Swait', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('74196652796', 'Carlie Archer', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('76738350567', 'Reinald Arons', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('79421411676', 'Gilberta Zorzenoni', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('75884979931', 'Kiel Macoun', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('77421305726', 'Don Lunt', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('75972242407', 'Teodorico Hughlock', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('78512007632', 'Jacklyn Hirtzmann', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('71487407356', 'Corny Lobe', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('71284451858', 'Curtis Callicott', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('71314262135', 'Marcellus Gianullo', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('74428826835', 'Tye Verlander', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('72143681816', 'Evanne Dran', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('72378637419', 'Atlanta Kryska', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('73392126613', 'Rodrique Vasey', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('72358483682', 'Michale Yelding', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('75598322895', 'Alvis Nare', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('74596439007', 'Dorey Philippart', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('77278523567', 'Nikolas Lunck', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('78911633758', 'Kylila Zuppa', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('75272379453', 'Giulia McCumskay', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('77231261239', 'Alika Biggans', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('77167015296', 'Reinhold Yesinov', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('73945295096', 'Erie O''Sharry', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('71832662753', 'Nollie Gooderick', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('71662579923', 'Holly Strain', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('74844840049', 'Dorian Liccardo', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('78828267251', 'Sherman Scandred', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('77667820453', 'Derwin Jordan', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('76636350429', 'Shaughn Gasperi', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('76622171278', 'Trey Spurden', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('77644871230', 'Dee dee Walklate', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('78163181003', 'Marshall Delacoste', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('77624666183', 'Carlotta Foskin', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('74015321132', 'Gunilla Northen', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('75552428547', 'Vince Forber', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('78272928323', 'Elsbeth Clackers', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('79576008665', 'Reinaldos Gateland', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('79006971317', 'Peria Pyffe', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('76901240235', 'Loutitia Kubicek', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('79711569684', 'Hillel Lorie', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('72595285293', 'Valentijn Storrier', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('79505931676', 'Nettie Curley', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('75367647676', 'Paxton Scawen', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('77238809848', 'Adelheid Saull', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('73713556653', 'Devlin McKendo', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('75842888851', 'Tammi Luxton', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('79526129185', 'Zacherie Gayne', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('77574399278', 'Teodorico Jozaitis', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('73533294349', 'Adriana Roper', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('72945400374', 'Marilyn Mozzi', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('78952849385', 'Terrijo Shimman', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('73979167760', 'Jorry Armsden', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('76215841410', 'Perkin Ioan', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('71885154368', 'Yvette Willshere', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('75498692756', 'Olympe Booty', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('76605949257', 'Torr Islep', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('71818542069', 'Mill Jelks', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('75466068477', 'Armstrong Smoth', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('76198156696', 'Jere Kimm', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('74296855622', 'Frazer Bockett', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('72538605112', 'Christi Cawse', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('78029747117', 'Em Busher', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('77046375915', 'Ira Baynes', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('72249704431', 'Neda Reary', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('79759482634', 'Sarita Jenking', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('71939708226', 'Rosamund Norkutt', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('78744571207', 'Leland Trasler', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('75461838282', 'Tressa Jenny', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('76301035425', 'Shermy Schimonek', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('73065664527', 'Charline Bridges', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('77063108220', 'Finley Sousa', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('72732634606', 'Leonardo Henrys', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('75179947156', 'Adriena Petyanin', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('75884304012', 'Zared Rickard', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('74408265521', 'Marilyn Lowrance', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('77272068713', 'Nerta Vaadeland', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('76468992826', 'Amble Firbank', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('71073390466', 'Rea Tison', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('74848926476', 'Katrina Panther', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('78665094890', 'Hatti Keedy', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('75054965181', 'Donavon Aldrich', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('71029681298', 'Reinald Grinov', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('76095228732', 'Conny De Atta', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('77067194678', 'Esma Meredith', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('79512228415', 'Hilly Cruikshank', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('73885690829', 'Estell Millett', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('73585773389', 'Yoshiko Lye', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('77875558236', 'Gianina Davenell', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('74686797494', 'Teddy Rubanenko', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('74732322989', 'Bettina O''Connor', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('78328352467', 'Sid Lang', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('75751678656', 'Brett Pickerin', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('74826500219', 'Marshall Trodler', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('75181644685', 'Ilene Charman', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('71582017908', 'Raimundo Tibb', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('71039935738', 'Jackie Keuntje', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('79373053312', 'Norry Sillito', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('76728068721', 'Gianina Kettlestringe', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('72935761612', 'Ade Mathewes', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('76324390703', 'Taryn Airth', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('75622023520', 'Michael Ferrarese', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('72351300630', 'Desi Challener', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('78212769494', 'Anya Patterson', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('71285700831', 'Mufinella Reneke', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('74819396946', 'Athene Voase', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('77515304551', 'Merline Carmont', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('71168206234', 'Jennifer MacCoughen', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('72072886311', 'Giacinta Lundon', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('71155447409', 'Athene Wheaton', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('74498841869', 'Gianina Vosse', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('79775738006', 'Emilia Pearman', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('76053887304', 'Kylila Di Claudio', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('74946851910', 'Rabbi Plascott', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('78897263751', 'Miltie Kersting', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('78438431975', 'Lorens Skitterel', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('74465039493', 'Bessy Squibe', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('71035287915', 'Townsend Parris', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('72637495308', 'Benjy Scrivener', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('73785183977', 'Burgess Backler', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('72148441021', 'Zoe Ridgley', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('71753505249', 'Herschel MacLeese', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('77094284204', 'Neilla Pointer', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('74965685362', 'Seward MacColl', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('75156927355', 'Zacharia Prestedge', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('73411863956', 'Lorrie Fullilove', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('79996437207', 'Nollie Snashall', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('76166297480', 'Holt McKissack', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('72035697287', 'Eran Cauthra', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('74072561393', 'Clair Ruckledge', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('71458730635', 'Carlen Romeril', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('78743963981', 'Esma Waycott', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('72387915640', 'Vinni Pee', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('73944728593', 'Tobin Noli', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('73059308411', 'Nickey Haslen', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('75293263944', 'Pattie Spinnace', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('77002226790', 'Vanya Grimsell', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('78351463282', 'Lothario Zebedee', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('77905102371', 'Gabriell Vlasyuk', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('79034479254', 'Brunhilde Balham', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('75886904111', 'Felice Jovicic', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('75223665666', 'Joseito Worlidge', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('77385972537', 'Pace Brent', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('77142986742', 'Homer Moughton', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('74848437515', 'Donavon Brandon', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('77371135760', 'Antonella Burge', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('79116314149', 'Hally Fontin', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('71586778271', 'Marsh Ivatt', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('79628804786', 'Beatrix Puller', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('76118846960', 'Jorry Hartford', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('79177681043', 'Mechelle Josh', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('74126444860', 'Leonore Corrett', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('75518700416', 'Florry Queenborough', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('76958795842', 'Prissie Raulston', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('79179256795', 'Joellen Champley', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('73732864607', 'Lila Knudsen', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('71275510240', 'Royall Hurn', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('77574218172', 'Coretta Lavender', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('75347833700', 'Julee Jacmard', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('71485017713', 'Benedikt Khomishin', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('74228408375', 'Kathryne Reuther', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('73811759356', 'Joyous Winfindale', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('74695929132', 'Shandee Choat', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('79064019060', 'Philomena Carletto', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('79907560011', 'Reta Wrightim', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('73592232726', 'Jarret Shrawley', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('78336124154', 'Ashely Spinella', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('76806636825', 'Bertine Gallihaulk', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('76152078944', 'Joni Aikett', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('75452983616', 'Bobby Verlinden', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('77973499911', 'Madelyn Acheson', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('76531955068', 'Alford Babbs', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('76714442294', 'Ham Barnsdale', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('79828391349', 'Emmeline Hartigan', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('76251215741', 'Sanson Wagenen', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('75993237882', 'Kimbra Denyagin', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('76386673693', 'Constancy Jaze', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('75847849368', 'Lelia Magister', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('72464072658', 'Ardys Tanfield', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('73363450087', 'Launce Lovstrom', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('74148470142', 'Rad Bemand', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('74983775105', 'Elie Petrecz', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('74907785826', 'Damita Surby', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('77193126922', 'Angy Cartwight', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('79384702146', 'La verne Padell', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('76348668229', 'Nevil Pellman', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('79499554886', 'Grant Dobbings', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('74605372377', 'Courtney Horrigan', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('72097558218', 'Bruis Rainer', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('76147499273', 'Lucilia Gilbee', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('75335685182', 'Antony Coaster', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('74956681202', 'Tadeo Hallam', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('73165161835', 'Ranna Buckler', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('73283614061', 'Feodor Feld', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('73748617423', 'Saxon Milesap', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('79624915801', 'Lillian Chapling', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('76133045219', 'Karol Legge', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('72804886269', 'Rog Varley', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('73643719961', 'Leese Murphy', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('79484535993', 'Ewen Settle', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('78629586483', 'Zonnya Farrah', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('74464338008', 'Tiphani Barnsdall', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('73618207677', 'Coraline Richford', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('71811001143', 'Leonard Vaughan', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('78144555099', 'Rollie Dancy', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('73883605318', 'Alphonso Whiskerd', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('74414621116', 'Ebony Stickford', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('74296609435', 'Delilah Vakhrushin', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('73821292688', 'Reine Villar', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('78316035342', 'Loy Kubalek', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('71898025769', 'Tanney Nevill', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('78011650064', 'Mariellen Malenoir', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('79631345629', 'Remington MacKeever', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('78741285161', 'Marlee Brokenshaw', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('74787622555', 'Fionna Jurick', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('76335650325', 'Augusto Breede', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('74799121080', 'Creighton Wilkie', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('77916194253', 'Hill Kilfoyle', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('71031167031', 'Orrin Revening', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('78999129305', 'Roberto Scoone', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('71637595894', 'Kippie Lindro', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('74174752724', 'Ralf Casellas', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('73661340687', 'Bea Pfertner', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('71327364225', 'Albertine Karoly', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('79439493662', 'Adriane Tumilty', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('72668898792', 'Clarie Leisman', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('75357368069', 'Tiebold Avarne', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('79027982726', 'Maureen Depper', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('78478813208', 'Barrie Dilks', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('74878355771', 'Hyacinth Childes', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('78933435249', 'Robin Shearer', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('78495651553', 'Dacie Calkin', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('71928887304', 'Ty Skelbeck', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('75845216585', 'Judas Gammidge', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('73885101273', 'Cob Godley', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('77348468364', 'Barnabe Murdie', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('79808532610', 'Norene Mulligan', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('78843082743', 'Lillis Avann', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('72536737491', 'Sonnie Gregs', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('73554282992', 'Isidro Slowly', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('74786468185', 'Guy Medendorp', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('76983680240', 'Lemar Hanes', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('73992199320', 'Guthry Chirm', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('71348054462', 'Aldwin Baison', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('72024357238', 'Amabel Frail', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('72078487072', 'Regina Dreger', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('79076302369', 'Bill Prenty', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('79416213892', 'Lynde Oades', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('79489851211', 'Tito Newcomb', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('78264218082', 'Jakob Brealey', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('73718896259', 'Howey Tall', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('73972879689', 'Odille Onraet', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('75513025288', 'Twyla Decourcy', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('78345576264', 'Codi Creser', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('76042521011', 'Elena Toolin', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('78254121602', 'Diana Bucknell', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('79281120199', 'Jemmie Galpin', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('76649314460', 'Leigh Domelaw', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('78033239724', 'Beryl Inglesfield', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('79692848971', 'Felicdad Rousell', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('77691701039', 'Stacie Lorriman', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('77538932152', 'Brig Astbury', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('74917857954', 'Netti Titcombe', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('79928784608', 'Vite Jervoise', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('75642604586', 'Brendis Driussi', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('74012179041', 'Dasie Blaber', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('74318655944', 'Dill Worvell', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('75279494006', 'Nathalia Peete', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('74247479313', 'Yoko Doumerc', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('72141803118', 'Cherey Duferie', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('74746211878', 'Saw McLagain', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('72335297182', 'Carlyn Tomek', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('74495974929', 'Uri Faers', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('75472072755', 'Thaxter Vickers', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('71291181620', 'Hillie Rout', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('74786128110', 'Simmonds Rollings', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('73989374416', 'Jordana Scurlock', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('77776406489', 'Demeter Farge', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('71764332315', 'Heloise Bromehed', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('77644029985', 'Maurice Vardy', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('77411106357', 'Matti Fleischmann', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('79259997139', 'Mirna Cleve', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('78744579200', 'Kaiser Kinavan', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('74486891346', 'Johanna Theseira', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('79891203978', 'Martin Ethington', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('78106186041', 'Darcy Blampey', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('79163415994', 'Granville Sycamore', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('76163050309', 'Bonnibelle Mickan', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('74043617690', 'Susannah Canon', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('75641481971', 'Gustave Guillart', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('72703931517', 'Al Roon', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('71663166468', 'Evangelia Belly', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('77633644670', 'Lena Schustl', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('76875136392', 'Bobette Rumford', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('76248265659', 'Jody Pollastrino', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('74212772055', 'Abra Lemmertz', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('78959314187', 'Jayson Deeprose', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('73975668820', 'Cyndy Greenleaf', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('79222872054', 'Ilsa Ardy', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('77741385969', 'Rici Keable', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('71622268852', 'Lorilyn Hannon', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('74571383478', 'Naomi McNeigh', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('72654615912', 'Carolyne Kahane', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('78166418311', 'Lovell Gorling', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('76046476325', 'Barry McCorkell', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('73435650622', 'Madelena Leipelt', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('79521033228', 'Damita Leverson', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('74267570338', 'Genovera Minci', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('78466062345', 'Aron Pheby', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('75905441578', 'Terencio Antos', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('77438273526', 'Ambrosi Lowsely', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('77228449333', 'Ulrike Simner', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('78295312025', 'Kayla O''Lenane', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('74401428097', 'Lenna Hows', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('77166696156', 'Jania MacKerley', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('73036625352', 'Lela Woodison', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('76734394126', 'Kalindi Castagna', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('76628686378', 'Jaime Kauschke', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('74087803866', 'Thorpe Staresmeare', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('79921801270', 'Chad Flamank', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('72336238627', 'Frayda Owthwaite', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('76642234016', 'Maud Searson', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('75829589136', 'Hank Sparrowhawk', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('79075522046', 'Corry Kenton', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('77137533262', 'Marabel Harmes', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('75198541714', 'Derrek Schenfisch', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('78413098543', 'Agosto Yurchenko', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('77974655127', 'Sonny Marusic', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('75826426593', 'Clyde Dadd', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('79404302234', 'Louie Sallenger', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('71546722640', 'Egor Bonnavant', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('71347578405', 'Adey Fosserd', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('78141708963', 'Clarke Goody', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('76629073343', 'Sherman Waker', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('73564375538', 'Binni Castel', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('73151066246', 'Sharona Fendt', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('73746630543', 'Aloysius Riping', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('75459144125', 'Herculie Craney', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('75153798640', 'Harland Ridulfo', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('75186071967', 'Elbertine Gouldthorpe', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('75031860729', 'Sophie Noyes', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('78236611427', 'Zacherie Clift', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('73771504935', 'Phyllis Atlay', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('76912003993', 'Augustus Walters', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('72281954896', 'Leonidas MacVay', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('79739189816', 'Sallyanne Antonopoulos', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('75364243247', 'Raymund Tregidga', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('76298847808', 'Gwenni Haddock', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('72445384307', 'Micki Leyburn', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('75351596015', 'Kale Acors', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('78304173049', 'Jordon Hartly', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('74116615104', 'Joyce Bollini', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('75231061193', 'Lucienne Szapiro', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('71474515757', 'Nedda Lochran', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('74642840928', 'Jacquetta Worsnop', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('76143242184', 'Cassandra Tilt', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('71535883272', 'Barri Filyukov', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('71886900639', 'Teador Brealey', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('76447368356', 'Carr Ingle', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('77653484810', 'Erwin Glennard', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('73084958568', 'Frasier Dodsley', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('79328308676', 'Sela Petican', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('71003834681', 'Brett Blase', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('72574050298', 'Kaile Lavelle', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('72718719344', 'Drake Pottle', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('76369842982', 'Rebeka Dyson', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('77451176486', 'Virgie Cosens', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('72665053436', 'Fritz Smallcombe', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('73301371778', 'Steven Dimitrescu', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('71128714471', 'Koren Fandrey', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('71199191784', 'Penelope Gilbee', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('79195431253', 'Humbert Anselm', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('75373091389', 'Yvon Sleep', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('79715134269', 'Brockie Devote', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('75118003540', 'Tedie Londer', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('77606808696', 'Merrily Dumbarton', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('75337824523', 'Erik Cadlock', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('77079345193', 'Estrellita Guyonneau', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('77588550346', 'Magdalene MacNeish', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('74458710235', 'Vida McCann', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('79475273386', 'Wilden Dahle', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('79711161558', 'Dorella Cheesman', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('72165199794', 'Corina Corhard', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('75392088238', 'Wilek Neilson', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('73271609333', 'Tammie Dean', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('74673381692', 'Sophronia Paske', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('78962910167', 'Barry Tillerton', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('72843214072', 'Murry Brik', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('73717774758', 'Glenda Marchant', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('79599054611', 'Tally Roseman', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('71071380476', 'Winn Bellwood', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('76267221337', 'Bernice Suckling', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('79279496837', 'Caitlin Kinker', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('77987449518', 'Claudia Cramp', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('78395050029', 'Carolyn Tampin', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('73969827551', 'Christan McElwee', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('79528100672', 'Bancroft Grummitt', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('71967812694', 'Rolland Pordall', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('76981215571', 'Thelma Casemore', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('72864464145', 'Guglielma Hirschmann', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('76675157006', 'Thurstan Heintz', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('74773000122', 'Carola McLanachan', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('72203705215', 'Christan Good', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('71175482653', 'Matthieu Bowry', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('74683792303', 'Irving Barnby', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('76982112698', 'Mattie Kittow', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('76914559776', 'Marquita Hancox', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('79346128125', 'Geordie Prowse', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('74928326374', 'Con Pizzey', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('75839744770', 'Ardenia Bartocci', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('71217337916', 'Desi Trengrove', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('79898238993', 'Armand Lergan', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('78975831358', 'Yanaton de Lloyd', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('74226231870', 'Gawain Pedycan', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('74945990275', 'Daveta Plumbridge', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('77276767626', 'Linoel Pennaman', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('73876896480', 'Carine Ludvigsen', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('77008733307', 'Jorrie Filon', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('77908712196', 'Barbaraanne Helmke', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('77059679097', 'Franciskus Vasilischev', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('76754973675', 'Oswald Antuk', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('71169417956', 'Florencia Macknish', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('79833248607', 'Leroi Edbrooke', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('73992004568', 'Murdock Storck', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('71449672082', 'Barris Huie', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('79298535055', 'Walther Alster', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('72343200184', 'Talyah Beekman', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('71543723846', 'Albrecht Broadstock', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('79552068376', 'Ethelred Bourdis', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('72563518445', 'Antons Caig', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('79691900547', 'Nelie Bartkiewicz', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('75502692301', 'Maire Bjerkan', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('73649540418', 'Angelique Codron', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('73099962502', 'Benson Regenhardt', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('78017489596', 'Thorpe Fadell', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('72368249817', 'Lynda Warhurst', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('76684435787', 'Katerine MacManus', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('71057428455', 'Neely Treske', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('79966073431', 'Andy Lockier', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('72804302697', 'Aime Uttley', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('73921378807', 'Mercedes Hookes', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('78809776346', 'Darell Beveridge', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('72877297877', 'Lynde Delwater', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('78545767175', 'Dionysus Tacon', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('75427878372', 'Nesta Grigoire', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('78988827081', 'Darsie Summerskill', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('77306147467', 'Bunnie Orans', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('75819407195', 'Suzie Fairleigh', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('73863374607', 'Algernon Spera', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('79052145800', 'Leontyne Jepensen', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('78032677316', 'Hallie Ducker', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('74297751550', 'Laurianne Margetts', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('73134073423', 'Clea McAneny', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('72254350142', 'Valli MacLardie', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('78216983745', 'Tucky Khotler', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('77125482353', 'Dalston Estable', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('71998178511', 'Barn Fielden', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('73772422158', 'Dotti Okie', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('76973200767', 'Curran Houseley', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('74287482666', 'Billi Bernuzzi', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('75692892606', 'Law Stuehmeier', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('72871783141', 'Wesley Cockshtt', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('74272569142', 'Morna Conquer', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('75044785846', 'Charmian Tapscott', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('79739523139', 'Nyssa Chaunce', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('76268156374', 'Tedi McLagain', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('72615063473', 'Jeremie Foux', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('77568834625', 'Angeline Colaco', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('77726561528', 'Lotte Chominski', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('79138860400', 'Brittney Burnsell', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('79628879600', 'Bartolemo Dymocke', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('79622231111', 'Micheal Mariot', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('74428428344', 'Mareah Thorley', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('75985456386', 'Zita Downe', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('76392750251', 'Nelli Olohan', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('79794667195', 'Kristyn Lind', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('77377905367', 'Bernardine Bruhnke', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('75403580348', 'Flynn Byre', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('75193976142', 'Ardyth Biffen', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('79712343775', 'Carmina Coveney', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('74848009998', 'Elberta Ponton', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('76525384511', 'Rog Pedycan', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('74358352753', 'Patten Toffoletto', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('75227542722', 'Livia Jefferies', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('75643963090', 'Noach Serck', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('72576751803', 'Kendall Broady', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('79111362422', 'Morna Elby', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('71165374670', 'Quentin Josefer', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('73159061805', 'Aubrey Espinho', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('71927216792', 'Petrina Edgerley', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('73468611184', 'Toinette Shevlane', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('71612276519', 'Benedict Shipton', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('76095197978', 'Edie Brookwood', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('76855127129', 'Kerrill Rook', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('73162628236', 'Vera Ticehurst', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('76298240074', 'Erna Biasioli', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('75756021087', 'Rosaleen Seefeldt', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('79714413298', 'Lola Matchell', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('78044466839', 'Antoinette Tibalt', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('71985636039', 'Alejoa Fortescue', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('73934254914', 'Quintana Wasiela', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('77263437807', 'Ted Spire', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('79467928973', 'Mildred Piaggia', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('79348540035', 'Thom Proudlove', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('71567557398', 'Goraud Domini', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('77599999432', 'Fanni Duffell', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('73428023075', 'Maynard Aymerich', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('75698253318', 'Andy Linzey', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('72018948402', 'Gregory Grayshon', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('71855285105', 'Kalinda Wiper', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('74599721594', 'Jobina MacKenny', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('73097661215', 'Hastie Casbolt', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('76457876746', 'Rikki Stiell', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('73589988151', 'Veriee Clampe', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('75845285268', 'Myrtie Yakovlev', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('74855970840', 'Augusto Hullah', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('76285129606', 'Katerine Kyndred', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('76929261541', 'Ciro Vesco', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('71089911285', 'Glendon Messiter', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('74639482790', 'Callida Eberts', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('72881554591', 'Addie Ianilli', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('78871009771', 'Alexandr Dusting', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('74353221058', 'Mickie Jozaitis', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('78873894384', 'Isahella Charer', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('79265739230', 'Brandyn Orpin', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('75011094236', 'Laurette Witsey', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('73064884148', 'Adolph Lethley', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('76509763575', 'Oona Posnette', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('78452421538', 'Ulrich Shore', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('74074354663', 'Farica Lodge', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('73312003667', 'Caroline But', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('77582689206', 'Brittany Farfoot', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('73996488249', 'Ashla Vido', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('71387971118', 'Artus Warricker', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('78328247251', 'Carey Bothe', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('71541557180', 'Jodi Lubbock', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('76104125497', 'Jamill Liepina', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('75226005250', 'Roobbie Boc', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('75954155629', 'Cara Imos', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('79894743696', 'Bengt St. John', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('72656397545', 'Henrik Jacob', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('78933562920', 'Alix De Gowe', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('72729083022', 'Moyna Asmus', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('77884947684', 'Merna Menelaws', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('75511992109', 'Athene Farrear', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('74513106472', 'Codie Dillon', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('77567912487', 'Vinnie Jelk', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('72767297772', 'Terri Caslane', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('71464626102', 'Pat Cuncliffe', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('79907463717', 'Jade Livett', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('78413927053', 'Perrine Beane', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('78059263879', 'Leanora Cory', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('74462925352', 'Nerte Martyns', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('79248135094', 'Rutherford Zanneli', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('73148072536', 'Guthry Brandes', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('78677009905', 'Clerc Fayre', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('74433899350', 'Dorelia McKeggie', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('74972191497', 'Wendall Grimmer', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('73217587509', 'Burr Mc Mechan', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('79907628059', 'Romona Jellis', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('74257793273', 'Richard Motion', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('73621223640', 'Odille Meadowcraft', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('78253505671', 'Gordie Wildman', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('78711952561', 'Kent Melling', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('73686178542', 'Toby Docwra', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('72461884605', 'Rogers Domino', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('77468429855', 'Ryun Dosdill', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('71013452989', 'Pegeen Plose', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('75318591891', 'Jobey Rizon', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('76242083345', 'Katharyn Langfitt', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('73058516937', 'Rosco Vicent', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('74266193507', 'Phillida Wragge', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('77432775470', 'Waldon Pridie', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('77057826015', 'Malena Pargetter', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('77174870718', 'Natalina Honeyghan', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('75501572983', 'Gabriellia Venton', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('73802903831', 'Pasquale Jorgensen', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('76494926767', 'Carrol Sneezem', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('71785827015', 'Melicent Jacques', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('77363047316', 'Bernadina Byneth', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('75792103348', 'Belita Lacey', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('73253802879', 'Essa Ayshford', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('74946592818', 'Gabriell MacNaughton', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('71827754172', 'Wood Lorryman', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('76033088687', 'Datha Gipp', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('71948704003', 'Paulette de Guise', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('74994209538', 'Gaven Gillaspy', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('75759663472', 'Hallie Di Roberto', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('76478021954', 'Terra Eastope', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('76332094793', 'Izak Burnip', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('75035272232', 'Susanna Calf', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('79262607777', 'Brook McMonies', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('77337252551', 'Jolene Kleis', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('76625029715', 'Kali Nowlan', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('72165192388', 'Burke Jurkowski', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('73972407040', 'Natka Cluney', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('71714365981', 'Abeu Grishelyov', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('71682203440', 'Kym Merrett', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('71887187492', 'Dael Jerdan', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('77063953377', 'Jakie Beswell', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('78036290593', 'Arnaldo Dunkley', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('75358425637', 'Candy Brotherhed', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('76239853574', 'Mandie Elphey', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('77125243146', 'Colleen Thring', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('71945290280', 'Shepherd Davidge', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('79399098202', 'Lacy Forrestall', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('74238851704', 'Dido Lulham', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('77614845484', 'Woody Spong', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('78699860437', 'Gilligan Marriot', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('76578802522', 'Thia Malyj', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('71414742072', 'Chane Brickstock', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('79892053094', 'Randa Gillyett', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('75977395603', 'Deny Rantoull', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('71433244003', 'Rooney McLarens', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('77378792406', 'Kare Crickmer', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('76637581471', 'Reinwald Mucillo', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('73946781522', 'Perice Free', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('79422404957', 'Jolyn Symmers', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('76532744288', 'Aleece Hammerstone', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('75834523050', 'Beverlee Gunby', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('77435249180', 'Enoch Cookson', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('78119528005', 'Melony Josskoviz', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('73175623240', 'Margy Doornbos', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('72462770470', 'Gunilla Munro', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('72224240226', 'Axe Rotte', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('71543949822', 'Susannah Sharpous', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('76161180677', 'Kerwinn Inskipp', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('76534353651', 'Donal Philipet', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('76357407284', 'Olivette Alliberton', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('79064990266', 'Stefania Voak', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('79226216566', 'Madel Holbarrow', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('79642295553', 'Renae Mounfield', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('75066310820', 'Thayne Mackro', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('75262331423', 'Chrystel Rumbellow', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('73386061802', 'Angie Dobrovolski', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('72977687516', 'Lynsey Tewkesbury', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('74462966742', 'Ellynn Firby', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('72332024578', 'Happy Wadsworth', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('72464525959', 'Pennie Singleton', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('77274561998', 'Sydney Chaffin', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('73998694394', 'Evangelin Mitchard', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('78606393882', 'Ruthann Henrique', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('75636208388', 'Billie Mullins', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('71603334393', 'Marleen Cahan', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('74342112854', 'Ronnie Jesper', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('71148013558', 'Rita Adam', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('72378560419', 'Cyrus Kick', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('76887163967', 'Gertrud Nusche', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('74549544635', 'Marylee O''Siaghail', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('74537949780', 'Kendra Rozet', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('78359948886', 'Natalya Prando', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('78733272388', 'Eddie Hamal', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('77837477704', 'Pet Bail', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('71758811694', 'Carolina Mineghelli', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('74158997404', 'Madeleine Tighe', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('73294342024', 'Sarena Eicheler', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('72801827363', 'Yoshiko Beards', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('73137136543', 'Lindy Victory', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('75204915344', 'Turner Atter', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('77721629463', 'Zackariah Longmate', '03', 0, 0);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('72108395929', 'Krishnah Vallentin', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('73149990813', 'Audrye Pettican', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('73296071596', 'Eyde Gooden', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('72841057630', 'Cordie Cornilleau', '11', 0, 100);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('73089362358', 'Avictor Ashplant', '06', 0, 300);
INSERT INTO public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) VALUES ('79338337732', 'Hyacinth Jessard', '06', 0, 300);


--
-- Data for Name: tariff; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.tariff (tariff_id, tariff_name, period_price, minutes_balance_out, minutes_balance_in, minutes_balance_summary, minute_price_out, minute_price_in, expired_minute_price_out, expired_minute_price_in, currency) VALUES ('03', 'Pominutniy', 0, 0, 0, 0, 0, 0, 1.5, 1.5, 'rub');
INSERT INTO public.tariff (tariff_id, tariff_name, period_price, minutes_balance_out, minutes_balance_in, minutes_balance_summary, minute_price_out, minute_price_in, expired_minute_price_out, expired_minute_price_in, currency) VALUES ('06', 'Bezlimit 300', 100, 0, 0, 300, 0, 0, 1, 1, 'rub');
INSERT INTO public.tariff (tariff_id, tariff_name, period_price, minutes_balance_out, minutes_balance_in, minutes_balance_summary, minute_price_out, minute_price_in, expired_minute_price_out, expired_minute_price_in, currency) VALUES ('11', 'Obichniy', 0, 100, 0, 0, 0.5, 0, 1.5, 0, 'rub');


--
-- Name: call_call_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.call_call_id_seq', 42, true);


--
-- Name: change_tariff_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.change_tariff_id_seq', 3, true);


--
-- Name: payment_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.payment_id_seq', 9, true);


--
-- Name: phone User_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.phone
    ADD CONSTRAINT "User_pkey" PRIMARY KEY (user_phone);


--
-- Name: call call_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.call
    ADD CONSTRAINT call_pkey PRIMARY KEY (call_id);


--
-- Name: change_tariff change_tariff_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.change_tariff
    ADD CONSTRAINT change_tariff_pkey PRIMARY KEY (id);


--
-- Name: payment payment_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment
    ADD CONSTRAINT payment_pkey PRIMARY KEY (id);


--
-- Name: tariff tariff_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tariff
    ADD CONSTRAINT tariff_pkey PRIMARY KEY (tariff_id);


--
-- Name: call call_trigger_func; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER call_trigger_func BEFORE INSERT ON public.call FOR EACH ROW EXECUTE FUNCTION public.call_trigger_func();


--
-- Name: change_tariff change_tariff_trigger_func; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER change_tariff_trigger_func BEFORE INSERT ON public.change_tariff FOR EACH ROW EXECUTE FUNCTION public.change_tariff_trigger_func();


--
-- Name: payment payment_trigger_func; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER payment_trigger_func BEFORE INSERT ON public.payment FOR EACH ROW EXECUTE FUNCTION public.payment_trigger_func();


--
-- Name: phone phone_trigger_func; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER phone_trigger_func BEFORE INSERT ON public.phone FOR EACH ROW EXECUTE FUNCTION public.phone_trigger_func();


--
-- Name: phone User_tariff_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.phone
    ADD CONSTRAINT "User_tariff_id_fkey" FOREIGN KEY (tariff_id) REFERENCES public.tariff(tariff_id);


--
-- Name: authority authority_user_phone_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.authority
    ADD CONSTRAINT authority_user_phone_fkey FOREIGN KEY (user_phone) REFERENCES public.phone(user_phone);


--
-- Name: call call_user_phone_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.call
    ADD CONSTRAINT call_user_phone_fkey FOREIGN KEY (user_phone) REFERENCES public.phone(user_phone);


--
-- Name: change_tariff change_tariff_new_tariff_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.change_tariff
    ADD CONSTRAINT change_tariff_new_tariff_id_fkey FOREIGN KEY (new_tariff_id) REFERENCES public.tariff(tariff_id);


--
-- Name: change_tariff change_tariff_user_phone_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.change_tariff
    ADD CONSTRAINT change_tariff_user_phone_fkey FOREIGN KEY (user_phone) REFERENCES public.phone(user_phone);


--
-- Name: credential credentials_user_phone_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.credential
    ADD CONSTRAINT credentials_user_phone_fkey FOREIGN KEY (user_phone) REFERENCES public.phone(user_phone);


--
-- Name: payment payment_user_phone_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment
    ADD CONSTRAINT payment_user_phone_fkey FOREIGN KEY (user_phone) REFERENCES public.phone(user_phone);


--
-- PostgreSQL database dump complete
--

