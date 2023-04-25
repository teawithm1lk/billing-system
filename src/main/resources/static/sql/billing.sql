PGDMP     "    '                {            billing    15.2    15.1 6    ;           0    0    ENCODING    ENCODING        SET client_encoding = 'UTF8';
                      false            <           0    0 
   STDSTRINGS 
   STDSTRINGS     (   SET standard_conforming_strings = 'on';
                      false            =           0    0 
   SEARCHPATH 
   SEARCHPATH     8   SELECT pg_catalog.set_config('search_path', '', false);
                      false            >           1262    65536    billing    DATABASE     {   CREATE DATABASE billing WITH TEMPLATE = template0 ENCODING = 'UTF8' LOCALE_PROVIDER = libc LOCALE = 'Russian_Russia.1251';
    DROP DATABASE billing;
                postgres    false            �            1255    65658    call_trigger_func()    FUNCTION     �  CREATE FUNCTION public.call_trigger_func() RETURNS trigger
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
 *   DROP FUNCTION public.call_trigger_func();
       public          postgres    false            �            1255    65738    change_tariff_trigger_func()    FUNCTION     �   CREATE FUNCTION public.change_tariff_trigger_func() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
    update phone
    set tariff_id = new.new_tariff_id
    where user_phone = new.user_phone;
    return new;
end
$$;
 3   DROP FUNCTION public.change_tariff_trigger_func();
       public          postgres    false            �            1255    73932 %   get_tariff_minutes(character varying)    FUNCTION     �  CREATE FUNCTION public.get_tariff_minutes(tariff_id_par character varying) RETURNS integer
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
 J   DROP FUNCTION public.get_tariff_minutes(tariff_id_par character varying);
       public          postgres    false            �            1255    65588    insert_call_trigger_func()    FUNCTION     �   CREATE FUNCTION public.insert_call_trigger_func() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
    update Call
    set duration = new.end_timestamp - new.start_timestamp
    where Call.call_id=new.call_id;
end;
$$;
 1   DROP FUNCTION public.insert_call_trigger_func();
       public          postgres    false            �            1255    65656    payment_trigger_func()    FUNCTION     �   CREATE FUNCTION public.payment_trigger_func() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
    update phone
    set user_balance = user_balance + new.money
    where phone.user_phone = new.user_phone;
    return new;
end
$$;
 -   DROP FUNCTION public.payment_trigger_func();
       public          postgres    false            �            1255    65660    phone_trigger_func()    FUNCTION     G  CREATE FUNCTION public.phone_trigger_func() RETURNS trigger
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
 +   DROP FUNCTION public.phone_trigger_func();
       public          postgres    false            �            1255    65714 .   select_max_of_three(integer, integer, integer)    FUNCTION       CREATE FUNCTION public.select_max_of_three(a integer, b integer, c integer) RETURNS integer
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
 K   DROP FUNCTION public.select_max_of_three(a integer, b integer, c integer);
       public          postgres    false            �            1255    73933    start_new_period(character) 	   PROCEDURE     �  CREATE PROCEDURE public.start_new_period(IN user_phone_param character)
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
 G   DROP PROCEDURE public.start_new_period(IN user_phone_param character);
       public          postgres    false            �            1259    65745 	   authority    TABLE     �   CREATE TABLE public.authority (
    user_phone character(11),
    authority character varying(50) DEFAULT 'ROLE_USER'::character varying
);
    DROP TABLE public.authority;
       public         heap    postgres    false            �            1259    65674    call    TABLE     �   CREATE TABLE public.call (
    call_id integer NOT NULL,
    call_type character(2),
    user_phone character(11),
    start_timestamp timestamp without time zone,
    end_timestamp timestamp without time zone,
    duration bigint,
    cost real
);
    DROP TABLE public.call;
       public         heap    postgres    false            �            1259    65673    call_call_id_seq    SEQUENCE     �   CREATE SEQUENCE public.call_call_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 '   DROP SEQUENCE public.call_call_id_seq;
       public          postgres    false    217            ?           0    0    call_call_id_seq    SEQUENCE OWNED BY     E   ALTER SEQUENCE public.call_call_id_seq OWNED BY public.call.call_id;
          public          postgres    false    216            �            1259    65717    change_tariff    TABLE     �   CREATE TABLE public.change_tariff (
    id integer NOT NULL,
    user_phone character(11),
    new_tariff_id character varying(3)
);
 !   DROP TABLE public.change_tariff;
       public         heap    postgres    false            �            1259    65716    change_tariff_id_seq    SEQUENCE     �   CREATE SEQUENCE public.change_tariff_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 +   DROP SEQUENCE public.change_tariff_id_seq;
       public          postgres    false    222            @           0    0    change_tariff_id_seq    SEQUENCE OWNED BY     M   ALTER SEQUENCE public.change_tariff_id_seq OWNED BY public.change_tariff.id;
          public          postgres    false    221            �            1259    65698 
   credential    TABLE     y   CREATE TABLE public.credential (
    user_phone character(11),
    user_password text,
    enabled smallint DEFAULT 1
);
    DROP TABLE public.credential;
       public         heap    postgres    false            �            1259    65687    payment    TABLE     g   CREATE TABLE public.payment (
    id integer NOT NULL,
    user_phone character(11),
    money real
);
    DROP TABLE public.payment;
       public         heap    postgres    false            �            1259    65686    payment_id_seq    SEQUENCE     �   CREATE SEQUENCE public.payment_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 %   DROP SEQUENCE public.payment_id_seq;
       public          postgres    false    219            A           0    0    payment_id_seq    SEQUENCE OWNED BY     A   ALTER SEQUENCE public.payment_id_seq OWNED BY public.payment.id;
          public          postgres    false    218            �            1259    65662    phone    TABLE     �   CREATE TABLE public.phone (
    user_phone character(11) NOT NULL,
    full_name character varying(50),
    tariff_id character(2),
    user_balance real,
    minutes_balance integer
);
    DROP TABLE public.phone;
       public         heap    postgres    false            �            1259    65537    tariff    TABLE     �  CREATE TABLE public.tariff (
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
    DROP TABLE public.tariff;
       public         heap    postgres    false            �           2604    65677    call call_id    DEFAULT     l   ALTER TABLE ONLY public.call ALTER COLUMN call_id SET DEFAULT nextval('public.call_call_id_seq'::regclass);
 ;   ALTER TABLE public.call ALTER COLUMN call_id DROP DEFAULT;
       public          postgres    false    216    217    217            �           2604    65720    change_tariff id    DEFAULT     t   ALTER TABLE ONLY public.change_tariff ALTER COLUMN id SET DEFAULT nextval('public.change_tariff_id_seq'::regclass);
 ?   ALTER TABLE public.change_tariff ALTER COLUMN id DROP DEFAULT;
       public          postgres    false    221    222    222            �           2604    65690 
   payment id    DEFAULT     h   ALTER TABLE ONLY public.payment ALTER COLUMN id SET DEFAULT nextval('public.payment_id_seq'::regclass);
 9   ALTER TABLE public.payment ALTER COLUMN id DROP DEFAULT;
       public          postgres    false    219    218    219            8          0    65745 	   authority 
   TABLE DATA           :   COPY public.authority (user_phone, authority) FROM stdin;
    public          postgres    false    223   �W       2          0    65674    call 
   TABLE DATA           n   COPY public.call (call_id, call_type, user_phone, start_timestamp, end_timestamp, duration, cost) FROM stdin;
    public          postgres    false    217   �p       7          0    65717    change_tariff 
   TABLE DATA           F   COPY public.change_tariff (id, user_phone, new_tariff_id) FROM stdin;
    public          postgres    false    222   q       5          0    65698 
   credential 
   TABLE DATA           H   COPY public.credential (user_phone, user_password, enabled) FROM stdin;
    public          postgres    false    220   $q       4          0    65687    payment 
   TABLE DATA           8   COPY public.payment (id, user_phone, money) FROM stdin;
    public          postgres    false    219   B�       0          0    65662    phone 
   TABLE DATA           `   COPY public.phone (user_phone, full_name, tariff_id, user_balance, minutes_balance) FROM stdin;
    public          postgres    false    215   _�       /          0    65537    tariff 
   TABLE DATA           �   COPY public.tariff (tariff_id, tariff_name, period_price, minutes_balance_out, minutes_balance_in, minutes_balance_summary, minute_price_out, minute_price_in, expired_minute_price_out, expired_minute_price_in, currency) FROM stdin;
    public          postgres    false    214   ��       B           0    0    call_call_id_seq    SEQUENCE SET     ?   SELECT pg_catalog.setval('public.call_call_id_seq', 42, true);
          public          postgres    false    216            C           0    0    change_tariff_id_seq    SEQUENCE SET     B   SELECT pg_catalog.setval('public.change_tariff_id_seq', 3, true);
          public          postgres    false    221            D           0    0    payment_id_seq    SEQUENCE SET     <   SELECT pg_catalog.setval('public.payment_id_seq', 9, true);
          public          postgres    false    218            �           2606    65666    phone User_pkey 
   CONSTRAINT     W   ALTER TABLE ONLY public.phone
    ADD CONSTRAINT "User_pkey" PRIMARY KEY (user_phone);
 ;   ALTER TABLE ONLY public.phone DROP CONSTRAINT "User_pkey";
       public            postgres    false    215            �           2606    65679    call call_pkey 
   CONSTRAINT     Q   ALTER TABLE ONLY public.call
    ADD CONSTRAINT call_pkey PRIMARY KEY (call_id);
 8   ALTER TABLE ONLY public.call DROP CONSTRAINT call_pkey;
       public            postgres    false    217            �           2606    65722     change_tariff change_tariff_pkey 
   CONSTRAINT     ^   ALTER TABLE ONLY public.change_tariff
    ADD CONSTRAINT change_tariff_pkey PRIMARY KEY (id);
 J   ALTER TABLE ONLY public.change_tariff DROP CONSTRAINT change_tariff_pkey;
       public            postgres    false    222            �           2606    65692    payment payment_pkey 
   CONSTRAINT     R   ALTER TABLE ONLY public.payment
    ADD CONSTRAINT payment_pkey PRIMARY KEY (id);
 >   ALTER TABLE ONLY public.payment DROP CONSTRAINT payment_pkey;
       public            postgres    false    219            �           2606    65606    tariff tariff_pkey 
   CONSTRAINT     W   ALTER TABLE ONLY public.tariff
    ADD CONSTRAINT tariff_pkey PRIMARY KEY (tariff_id);
 <   ALTER TABLE ONLY public.tariff DROP CONSTRAINT tariff_pkey;
       public            postgres    false    214            �           2620    65685    call call_trigger_func    TRIGGER     x   CREATE TRIGGER call_trigger_func BEFORE INSERT ON public.call FOR EACH ROW EXECUTE FUNCTION public.call_trigger_func();
 /   DROP TRIGGER call_trigger_func ON public.call;
       public          postgres    false    241    217            �           2620    65739 (   change_tariff change_tariff_trigger_func    TRIGGER     �   CREATE TRIGGER change_tariff_trigger_func BEFORE INSERT ON public.change_tariff FOR EACH ROW EXECUTE FUNCTION public.change_tariff_trigger_func();
 A   DROP TRIGGER change_tariff_trigger_func ON public.change_tariff;
       public          postgres    false    225    222            �           2620    65713    payment payment_trigger_func    TRIGGER     �   CREATE TRIGGER payment_trigger_func BEFORE INSERT ON public.payment FOR EACH ROW EXECUTE FUNCTION public.payment_trigger_func();
 5   DROP TRIGGER payment_trigger_func ON public.payment;
       public          postgres    false    219    226            �           2620    65672    phone phone_trigger_func    TRIGGER     {   CREATE TRIGGER phone_trigger_func BEFORE INSERT ON public.phone FOR EACH ROW EXECUTE FUNCTION public.phone_trigger_func();
 1   DROP TRIGGER phone_trigger_func ON public.phone;
       public          postgres    false    240    215            �           2606    65667    phone User_tariff_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.phone
    ADD CONSTRAINT "User_tariff_id_fkey" FOREIGN KEY (tariff_id) REFERENCES public.tariff(tariff_id);
 E   ALTER TABLE ONLY public.phone DROP CONSTRAINT "User_tariff_id_fkey";
       public          postgres    false    214    3213    215            �           2606    65748 #   authority authority_user_phone_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.authority
    ADD CONSTRAINT authority_user_phone_fkey FOREIGN KEY (user_phone) REFERENCES public.phone(user_phone);
 M   ALTER TABLE ONLY public.authority DROP CONSTRAINT authority_user_phone_fkey;
       public          postgres    false    215    3215    223            �           2606    65680    call call_user_phone_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.call
    ADD CONSTRAINT call_user_phone_fkey FOREIGN KEY (user_phone) REFERENCES public.phone(user_phone);
 C   ALTER TABLE ONLY public.call DROP CONSTRAINT call_user_phone_fkey;
       public          postgres    false    217    3215    215            �           2606    65733 .   change_tariff change_tariff_new_tariff_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.change_tariff
    ADD CONSTRAINT change_tariff_new_tariff_id_fkey FOREIGN KEY (new_tariff_id) REFERENCES public.tariff(tariff_id);
 X   ALTER TABLE ONLY public.change_tariff DROP CONSTRAINT change_tariff_new_tariff_id_fkey;
       public          postgres    false    214    222    3213            �           2606    65723 +   change_tariff change_tariff_user_phone_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.change_tariff
    ADD CONSTRAINT change_tariff_user_phone_fkey FOREIGN KEY (user_phone) REFERENCES public.phone(user_phone);
 U   ALTER TABLE ONLY public.change_tariff DROP CONSTRAINT change_tariff_user_phone_fkey;
       public          postgres    false    3215    222    215            �           2606    65703 &   credential credentials_user_phone_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.credential
    ADD CONSTRAINT credentials_user_phone_fkey FOREIGN KEY (user_phone) REFERENCES public.phone(user_phone);
 P   ALTER TABLE ONLY public.credential DROP CONSTRAINT credentials_user_phone_fkey;
       public          postgres    false    215    220    3215            �           2606    65693    payment payment_user_phone_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.payment
    ADD CONSTRAINT payment_user_phone_fkey FOREIGN KEY (user_phone) REFERENCES public.phone(user_phone);
 I   ALTER TABLE ONLY public.payment DROP CONSTRAINT payment_user_phone_fkey;
       public          postgres    false    219    215    3215            8      x�e���mIn��>c2����=0�m<3����_�����Sհk���"�B!i����g�3�����������������|����O׻������o�ժ���	k�=yJ����{V�m�6ۻ�����N�>�)����[�<[��5�����Ӛ��~�<����雕اm�1�O��ms�}���ԫ�f���p+�w��z����V��G�O�h��׎�C��y�_�5|��Ͽ{fը�g���X�u.g��ؾ޳6'?؈����ӟ�������?��~�s,~��t{�����]ؚ��ݓ|���v_o.�Ի��<a�M��E\�t�6ޛm�m뚇�O�����\��>�n~��jo6�+;���C����̴ץ����W�����������7j�u�.����|�Яq˶�1��:;3�g��S�=
����P,�3���l�$��@��?��8��˽{��V���6��1U�E��C�b�������cǲ+{�\��/fo�+�S{n�B����*���u ������{ �:�טq�p���y�ł��1��?����ˬ�����q�����,܇���R��x���}��������Əqw�>]X����:82;#<�^�q[�r�
��VB��5?�ۚn��_�Hq�r���6&�07��@D����U�x'�Z~C\$����w���*a �����Wq����aH7�ޭ�o��L��QpI��z]�7�4)��c�6�!G�����[ƹ�!��v|�Zx�Ǭ�02�{7���,��N����a��,[�]�1����@"h��;aX�s�1�`��FH���܏��D�}�֋�>�����|K��`n�p9,�ws�xW����ȱ7�	,��.>n���[�[ ����/�;��+�h�G�{�.ݞ}J@n�/�ʎ�h�q��8ax��:ǸyD���UD��5�tLm�u��H���n���n}�}p'y��[��G�vU8Q� W�_�t����(B������<�팧b�V�>�9�1kbUñz?m��m0�h��7�]a��Y�p�����$,�ʰ��#R�='��kę�ڰI���]e�5�y`v�E�|�;�:�l��B��w��q� ��?Il���s��C��g_
XE��O����2�&�����|գ|�[�g��s+Q�G8�������`Q��+k%�ӯߐ���=�Q.��cM(⼉;���s?fB�V�ס卤��)�$:O���.��~Eqy��?'�8^4co��)�r+!��rM�c!so��֯��w�Ĥn�-�(����@���mv���ǭ�}�kw�,<�-�h�&a�p�h�{e��9u����"��~��@ٍ2	�������<On�_�y�� &X��[�/�����EQđ�X�gAd��.�qGۛ�w�aA�D_wD�/��~C���;������ԯ�!��-2�Si�gP�I�q�_���s,W�� ҃/;s�,�}���(��������&.�=��"�ǋO��8��	���wpKR�G��˱B��9*�^a�+N}+���^S\T&�*�{l��I�#�?��^�Y'C�
U��d93�c��[���y&��g 8k0��!�A�UbaA+l�l5�uد��P�DF�g��@���#�bH$r�}i�xD�'��I�ی�#ć^o�@0�qb��/�Khp�QdKb��1�џ{�ؤJ���A[#l��^�8�6�vX�3ݻpy[������)�C(���+��	�l����|���u�.6���@�]�1-�U��]�؂�9��r�~O���`,�k��H�����d�`rd��@�P% xp���*'^x�M�E4��&]���2B>��������@���>�B��-���J�"$'�����NU�J3in;]�e�����b/��T.%���)x���(���aN(T�|�6IY$ńE��O�b�x��ù"oy[A#������nw�R�N�oD=�JI��������L�,���ը�*�=�֣4�I*F`T�V�E�"pl�ޠ��8\��ц�qn��ޣ*��b�2�5b�BD��^���M�!ܢ+�����ɜ���qI�P"R�pF��0�AfJ�=�*�Wd�g='k�g����Q=�zh\�da�%#$x�c~|ˏ|�k��Ay���L7?��9�
+����F,Ħ�
n��#��	;%���T����w�od�O�zG(���$���D�WE~��]1��������a}�r*Rq�3������C��L����h1!��7���G F
F%��Uˉ�ꨘ5ݢT�v�\��#�3��T\`;����6-���A6&�������K�WT���S�?!=X��{.�
�ȥ�F�ߨ�r�W�Gڣr.��rl��TVd������Z��4O��3VR�5TێZ��O��j��+S#�o�,�q?Y��2 �M��߃(Z<��XBT���YDc������)��ʲ�e��$�F,��(�:�6%�\���̈�����"���T��[�Z
�(��ਘk�K��qS�
e+����W0&�r��8Q{W\.���*��*�Ί/���5�)U�y$����S�Ë�:	���Ձh
�-X��_�h{d�c�_o	h�ų����K�gY��yO��@�l�G5I��sH%���qL�3�'�t�����J�a���Ø��ؒ?HZ1�.p��0��@W��2�P;�?�xe�R�k�
C�����
�H�"罪[�Z�Q����E m���jV�7�Z0&��J��x�}E�KMCٷ��8�qT�T���͗��&�K-ȓ���J�a�0ϡj�G���ř��J��o�K�ǗSA�wEΠRa�徉���;�M�&��.�tA.l�:�OWS�ۭO9�	�ɦ��|�I���׋Jg���*�\]*���%
�m[X���O����Q�$j�s��B�Β�=��梧l)j�����J���M�*{�H>t�v���a8S ��wq:�'K��*�<�p3��1FEwH�+1������Ծ�����xv�w�2Y5jJɆ�8����3K��R�� Rp����Z&1R�c��C@��O8�#�DW)\t����]lܭ��nژÝ��s�T�聓"1��_���O�6�&�~u[<���'R=l.�>�h�2�ĮJdn�R��:b���j��](� g'"N��Y�
�������|*��i�Ua�>!'�7�
z�\���!�B�C�Эz)�*_�����{L��U�K��Po%^������ݞ��R˞�F"� ��/�z���s����I��N�����n %ұ�����6BVW%(Y=6�iYۀ�y��p�t��	ۜD�O��5�NpSv�3�����זI�����0QU�_i�}fMB����^��W��d����?����;-:A#�Y.٪���$93���j;��Q���_��Zh�ё�UY��F�j�+:�����E��	�A����8v_T��}�.�r�hI�j�EGē:��F%T��P�꾭�V�@$teiZE��8�����$[��J�bԋ���^��ƚ>)%�W�g����=���z�  �x,]-��
�'��*g�0�+r�R;��;��R*���̞R������~XP�û�dB,vH��l��������zI����B^J��T���0�Z���]�3�E_WyU��/s�y�Bg�b�A*$<*�m����Ϳ����;m���8�l _���Q��$ũ����)�F�k�S�\Ú�$9��L�Q����Z�H0��/���I}橤oI����p^����U��u�Xnc�������YX�RS��d=$�+�F)��ȳfMaO��K�V�j�����z��EF=���#0��/a<��_Ǩ*��qw���=9�eP$�Z�����AE���a�M3��R �8��k�Fg��\j�����8��d|D���� �j�{�I��E�j>mċȥU��[�J�rz��"T�}�u9U
�g�P�����_�9|.�g��(��=� O	  ?�M+g*�Y=fa W
~�OZ����7a��-߅���W	��*���$up�P-u�qզ$���
7����U;��z(�#���׊�����=����D|����Q�~KMeY�Ӿ-j��\1T��͉ա]E��]�����i_�@L�)8]E�Ю4C�t�B<c�5أ��'���m*�W���ƕ*
��J��(����ss�_��B���h�����@T�Դ����F4��P=�����y�}�rl��9��[��OP�kW��[_׀cNh�I��S5����%�@���ԥ��F���E}}+3z�H���y؃��/�vJ�"�)Ɍؘ�b���VgM#Q�S�w�#�axO�L���x�j���eﭶ�o��h�HR�}��T���c��աvH(�������w�ЫI8ۍ������eO=e�E���/�)8��CU��nn�F1�9L�R��ݻ�b��~b�B �#�54�%.�k��5����F��i���0�d������d��qfѩ�����m�~j,r+��H�LaJe���_��&�XoWo�+.�d8���a�5}����Q��z̿��?M��2���>#g��L�eԇ��O�����t���V�c{�أ��~L3&��*�-�HU縟�[U���]�L�wu���`WW|i���ނՓl[�Ѝ`�9����d嬸�E����T͎1e��n���Y���ǫ�)|E�5�:ǯ>]�\���ted�==D�A΍4)$���0e'��ќ�Y�m^H��Q�P���ګv��s9N6"��V=������L�D+�-�!!=8�2�H�5�����B?T!���Z�T�!���
(�pL]d2_Ӳ}W�8�E�H$5u��H�}z�{����{.}58,��S �F��/�Z�OhLM���O�g��ǹ��S2ν�K%�+�Wv�2�}W?sE~�N#��"^�湿�ɕ$sT���:u���z5�j[K��4
�K��*��-uRgV���ǟ�;����}���N	8"~�k1��T|9�����{�Ww���(zA�P�X�Fɰ_��9U%����8Z0&Rž�H
������bA��GY��9߈cJ�c�E�:����R����*�7x�Rv����j���E�����ig�"�j�MΦ�!�Z_��ηy��l��Z�lB���ΠV�d��#w��+�|�WU��K��JHb�U��[X�7��A�����:�4G�C����$��G�v��p��S�2�)�` ��k��(o)���ͫ
�z@�KF�� �@1qr�ר�`A�h׋r<�n]q���|��O�jw�.���x��T\�s�����@Z��΄2�5H0[�CK}�Y/��4�� �`W�mQrd��r����JpWś?��U�)��e�<�P&�i���R��JꁋN�Ҫ���㛒�u���4�s㻰�s_,K�ݥxQ�J�dRXզ>�&�{.=�]�C�����~����3b�\�^c�J���OW׉r��p����qxg��k�Y�/0jk��c�z�#��%���-�r���S�^�LUz���:���Y�KYUxi(n�;����^�"�jQ��|He4�Ւ�d�ǹ��3 �9���.�㛶���cQ�����W-��n�{�����+2	����M�U�yl��ioxmK[c�#j��W�.�Z?���%V��4V'�1�Ե��O�$�'�D�D/Y���Z��V�*6>�E��<�&54��;�<0q/���6�g-��B?;JN�yS*���\����Kf��N�0�`��k9�k�0��.#1>��EKZ�M�������m8z��FE�x��<mxF�$��u�~�o5�/��Xj�(������Q��Q#R x�ei��(A׻k����I�2��t#5�;�j�_����Ȋ�?������{3��+�Wk.(����]���%��m'��_����w�+zD�ߴW��<�ѓ3������?���z���l)�d���
+��mk�I�Q_g]YJCڙZQ��5��q{h�����2��^����q!gA��"�7@�)�>���덷�L�P����dT��K!n�	����E��dpMć|��/���R�r�XST��?���w�7��؀3�\��
��W����<?u�P��������5�^�>����=(�L�G�6d�_�[��sD/��*:���qR���c�^j)J����{�R�V+����^�����;�z+_� O���a}�^�7��$�I���3�. _�$�O��_�JTz�آ� ]����xLW5���*WM�|��1�r�<��M����R���z�Prz�r�6�wL��D�����PCǹ�����*��o�������?��������%�      2      x������ � �      7      x������ � �      5      x�=\ǒ�8�<c�c��@��(CyG#�BI��奯�,{"�Dt�(���,G{�g:�똢�%��h
��P�azҰ,�%��(��c�smGږm�d�-i����Ӯ%��,C4_��g�~��X�e�x�?�m~��C��\�R�m
��?�����M鹖g{��~�?Ǎ�5�_���ah�Qb6�|{���(�հ�Ҏg���힗���n�7�Vڳ�";��z�����3�5�V��lx�W�w�(G��a��ģ���^]�ϥ�iS�-��^ԍ�}��+�!Mmێ���I+�野�k������t��S�:����i
38���Ԋ%R;��E0��à�^��WUV`hi	�t���~��:Ň�tۓ�-�������m�x.^@�e����d`�Ⱝ'ü�/�b�S)�\�TB��Fۜ�K���JC�˴~T��������a�T��������X�/T��)��ֶtóţaL���VX�d:85l�c��.��j�Q؎-E�^��_X�kj_�=�r�F�ϧ��c��K�%�Az���b�=׳l�Ƣ�5˴8pӵM|�g)q����m�f6L۰<ӂ}ϵ3�Y���Q��kx�vDv���0�����\G�+϶��5�)����D�5�/w�(~�������-l-���8��-�Ƒkl�~��j�XN��嚆i�+�ݢ��|w?�&�A�qX�%��~d�+�9��nm�7����q=gx
�i���Ulm�E϶�h��&*{4
�TxCOY.^f����찹��R���W.��[�yZY���f:;�a���Z�4L������j�F�-�L��p2�]m�n9b����|�i$�[�4�>\}?�.�]�~�V�
�u�5�J��i>�l5x;�k�������w�FM֋�A�84'�b �c8�����yi]��{vL�J�]S�jY,�nHˀ-��+댜�:+�ֆs0m[��A�}��IF��qx��^�M~:l�[i��[�]��,[AV(Rc���1�S�g���j!{A;V��(�'��p5���N��-�pEJ8qt����F'�/�d��vE�n�Z�����HZ�{S���m"_�Y�Uc"�Ҁ+�n#����/�֌���԰�`��qm�g��18
O���t�lԛ������y�7�wi��G�������`�y�y��Ie���I�U�}�9�w�m�M�<�U���^�*<@c�������������6��(����e7�?@8Lo�Wi{͞�g�#p�nR\n��38l���aoVo�њI�;qܞv�p	�Ǎ���`�PX�����av��o`�B���[ڌ�lg_����+ӟ�� 
����-:���{3�!�jGJl��m}:�����x	�Nn�j?��d�{��)8�����QP��2���l��X�lް>Xl�tڸćG��	l�M�l��NWm���^��Ѵ�$#�nI�Q��^��3�B��a��9?��D~ݱ�P$+%V�dS���ð6��N���H��H',��=j��q��D�s��>��wM۰��h��C�}6��s+�a�r�J���I�<�r�J�'�D���e��&��P�t���z�Q���b�\�A�K���?vn����������s?�'<
	g2��ҫ.���r��nP�35���[%.�I��,���]�:2w��
�C�&�ET�ͮ���|�y��l��(�{n��X3�#V�����MC{�y|~� h@*���z�Ս��83)���l����Z�a��p���R��l�~�U?�!�/�V�B(�u'�i�k���=PG\kM5ڔ!n��D��[��/m|ZD1A�\��o�Q�_e�?�
��ш�Y��ޚY�4�����J��	 �V�;U�jʎ�a������y���v�i�VD�v؞�w���=�0�J3�u��a��LW+�ݮ��W,��J���(<?��-yg\�Vt�B�γW�%�2	��6<=��|�\��L/ۄ�mkQ��x�$(폐��e������7�ރ�!�LZ�ȱ�rbm<�P��F��&���,�"�T�|ô�Q���;�j�����3�?�����~a�6�B �큱�<����g���S���]Ie��BZDfa{�1����A�DqpX�����޼;.H��?��Q��������P���0R���'� ��yw��s��욠
�:Xe3���;k1����� ����hT�O%��S�;��!�5�}e��e@5a��bܸ>��ݠ�y���u���a�l��C+p�������*W��AJD���Q�� ��!n��b̒x|.�L>��F�t��)�X;D�ᛋE�>����	�0N�w���y?`�8�^��=���zpI.�m��i�S3?�d�. 8/*���8{1F���v�?�u��i&֪�:{�X�Z���hD��A�X�]���(�VOK� 2��CX��4Cƫ�ٷ��u��U%��������g�Y0<��ǄW�(�@Y,�Ko��&/h�M�J)��U�[m��(��j�����z����;g�M����Hz͸���u�H,��j8�������Xn����V,� �� Ȣ��ߒ���^�Wb�m�~<��<�m���C�dQs` �����y�&Y.=��i�f��/���6w����6I��]��������{ �9o�S�9�/A�+�H���[�J��
M"��<�Yo�V�+%��|�T&�L�_R��8)����&敶Kl@�\1O��\�%�D��_|����8BH����N����h��H�Tٜ݉璧�JXOs��W&�K����|��Q=��rG�-5vB^�G��D�x�ɽ��}���� �u}��o՛qF�=��M�{�y*��̻a���]��6�6�ɪ�m��,u�GZ����N�r�}��#�"Z)Q�.��zp�dhʱha��zw.���f��|+�a�c`fFaB��������� F}>�u�i���_�MQ���x�Y��:�t��O�.��ۜ]Abp���:����Q�����/�/&?���RK�{ڻ��saHa�8�tk�0ǋ(�1�����F`8��h����e��&х�"��yX-�9�Զa!�-���gUc��=G��n��c�iC��0pt�9Z��Q���YZIÙ�%�B��lqy�U��w����OB�1E�H�)^m�-E"��H���z#s�`�g��@/l�ʏߤb3��M�G��i�2[������$�nv�� A�ʦ����c=�u��{�Yp
�b1[��Զ'_>/,��o���s���8g�e���9bvi�����M(��oN�F�^2@)�1�f����{�m�I�	\�����{���q<�qlq�A�|kU�8OR����x���6�Å�Q���;�o~W�L�@����T���7����S�-�T�3o>����k�K�Gt'"\U���`sH��X ]Pr�{oc֮߮��<8$���>���vc� ������Σr�:����%mB�|�����6s�}�4��?�[����g�&[�r�Y��Dr�w;����X��"R���&�Vq��?�UIJ���ʞi��`��4�_h��q��L��/n������J�8�;��Q�[ީk���9-p���1��k�̲��#+�U�P�SkS�F��2Y�ˈOɨ�f�1G8���rv���Y�^'�K"v���`�/�~���-��U���j�uA=�^i�J��W�ig�w����G�^���r�Y9�~&��t�vr�/8��^a:�A���77_sJAAY��#����=	Xq��:��"�����P�hh.��띛*�[l���/�`�&�=��	$������M�* }�x��]��i�y�-�
���T^�ֽ�KJ)�%��麿l;��i��
�ەU�G���'�=<� ���}[����Q�����J��o�f��qP��k��Ixx# @ԣ<�DG^�Ip?��������ٚ�~|vr��#+.?��j��ZB�_�C��\A�&�lf�    M���v+��o�v%�R��V�g��zQ$4�D�k6l�z%w@ ��z�7�G�8Gp��q��t�p�T_C,��������/�a N9�h���;�%kE�S1i�ۛM"9��}H�+ �E�Cu�AYT��Q���S�'�i%hwY�!j!�!��M���/���,�ɂ�Qh��?n�U��w���06ӵ%V��m��o��^�.�a3W��3)�>�%d�a�s��]��t��",4���~eP���ģ�V7V�V-,P�����yS�:�v���ԍ׿����C�ᢅ�2��<���s��,a����0����! �V������]��Pn����I���.u%t5��a4�MV���Rv+0�i�G;�����2��l�cp��4k���2!��5SVuU_���M��a�Cp�hL��3f�VJ���<>�d���;g��kR��^�'��=�}� p7��Ivӧ�'O���p�Q���;���I~� ���ا�i�nA�ģ494�g;ܬ�^ֿgbQ�XX�ȵY�Yj]��ȥ����9���-NBNh� ��&�/R�+�m0	�k��y>ܵ�A�MfWFb�Ql���ן���gPJ`�g8梏�?��a	f�����?&U�5���{���Z�i���K>{�î�	��U���a<�9�"�)Xر���l�*������I5E� ��~�x���P<"}�����_�r�xvt�[q=`YU��	����Z�z���R@0���w�HY��s�Jp�T�ˋ��EK#O/&p�.���|x[a<����t��}�-v�N5��Q�)� mY�f���4dܯ5:����T 6�Ĭ��:�n�	%�#V��kթr��<g��.0}1�3Wip4@䥺����u�8"���@����Iu�ef�M�((߰n��l'������犡d����&ف�7�T�u�æ���2b�o\����5�cQ�r*� ^��������2	K���<��X�n�w���!�')nX�c4s��ϙC8���O �~�vA������ʀ�����o�'����)�O��l����6a��Ge$��m�����,]��㴏��r��]��y�i=�T����F X����_e��J� bP>�~���sv�0s�#���T���S�)��PE����I�*��k�.h��f88�*�AREp
�������G�bS��&/F�$�5%�̯��F�l�Y3�/#e8ZTԴ�Gc>�,9����r��{��޹����fZ�R�kS>na�"�m(	�y�u>�4
Tϥ
�}�W��4����t���K���cL�����>�f�N�-�@�Qv��\]�ld5�Ǻ�����e:�圪�ֻT��'�x!�.P�\&�b$w�y�H�T���6�����G���r�}r���s��!�l��6�ǫ��%��q�ϵ���S���,�H��N�w�b{ �,MmJD��ߓ�Ђ�B]8�ǭ��9U4B @�d��{\V�(}b���x�����Qe����CkŴ�W����y�z�l4���O�� ԁW�v:���w�*��`a����t�=�8A�2������ʰX-Շ@L�Ѯ�s&��D\PU��X��iA�tQ8�*��^����im�����ʧx���ǜ%��/�'@A�Ux_[O~>I{XN��ܛ!K/ ��P��5�_�7�^-��(�	*q8��ñ2�ܮ@�5��F�#��Փ٘G�18J)gVK���Q�R������_�m�-�
`����٩F�(���ݍYZ���(A�g��h7n���,�T��q�im�u~>���>Y��Y��^K�I�9��TG�ߺ��gUl6�\͢
l�qX���."�4Ar�7o�#xq0Q�r��q�v�SiR�!R$��-1���@&��P�e���o�pʅ3\��{E�n�RU�SD��@�Xm���2�5�U ����f�<���r�p!�lQ��������-b��kZ��V���3�Uj�_�&?9i,�E�E\���X�PM�HE��q�Ѝ��K�%ECܥ��8�¥��D��p'�Y6��#�^�H���/؅�W��)���kq��-�����j�\�0mx�+T�ٮ�<8�+	��ݶ쫽c��;�S�]�g�E�SI�`���[��n�^4}1����[�����୧r�'r�3	��'�%,_AC���eP-7��m�rz8Q���)ݐ0�E|_�\��')��Y2��q�U��v�4��^�AJ�X��-~����/�$v��&����+�+�������O뱛pW)l &"��ۺe[���F�d84���V�vEg#%��m�np���l\��������j������xI�QJW�f�{�=-mfUԫ�)�!�a�k-&S�R�Ӡ#���p�1��v������g�O8zD֍�L��L�K���NYV��F�u'j:�xP64��oF<�]?�u���$�؞_ԹF�)ga{��o��j7����pKZcQ�����
�Kމ�"��W�v���(���
Xzj}�uT*EK[��׃� �}���d��q�4���>l斆e������T�����MQ�G0R���f�_��"q$IB=^�گ�}��0u�˫�_��~��Zmʤ �eK��'�G�S�!X�8^�ݼ�z�fʞS��~\���rͯk_A�k��79�&oY�<���D�������Z*18�v���U�f��X��ty��(���k��Tp�A��m�z~G�(\�*��f�����qT��ӛk��88�J��q���y��L�'��#fA��<�g�5x�Ku�w]8�RE,:[��Ecs�4~\� �t��g�?���]>�\`���L�� ���b�����h�8>�l�R�����Wb=:À]�O��bg�� ��/间�*[¬}U���
���Hj��/,_���+�[��L�LS\�^��9� @܁CK?��BW�&�AuO�x�	*�8fM�?%�
�"���������*����S�}��{��ԡ$���[�͖������Qd�u�E�ka��bGL֟��R_���E#nS#���xr}M���_00ɐ)_��w%�g9T� ����Y\8��!VO��3=��ʢ7��KC����&��6aNh�w�I=�����F��a?�iS�J�2O�ˏw�pC�����jU�yd��40M��;k��Ԏ��L��f��:�����#���/�t�_���W+��Q{�������Zm�,�(,w��{W�OE� Av��sk;�V���G�cB�=-��p~Т���~0�O�~�nLY���%�EQ�^k5>�8S�l0�w�F˃�Р�>�GO�ӕd-�%y���z}p����R��Q��k���ag��� /%,�g��9�y5�XHZw�h�5w���=�M7w?�#�M
��_����U�2	����e��%�2�j�bt����qa��S���ɠׂ����⣲(�i!���q�����P�
,[�S�{��}W|�ک5��=��G�s��u�%�"koM򾱿�x�m+�(K�Q���� 7���-����6@a53}7�~>����&�����o�+�Ƥ�!E��Ǳ\�'�~~��8�4� k��sY�*�Xm����Z�����;`^M�&�9[Pw��M�%qJn��ӕIe��C{$�q��9���>B�]H���� �]�Q�|4ך5�	f�m���1[�&F!��E�E[�N�Kp����ځ�sD '����m��ۣ�h���?���x����!Df�Q�ٶ���=�W�)�8�j�6v�	/�h���g��:{q��4	3(�iz��,(�5|�ڿ�r/w��X���b9v�.� ��d��t����Uz�ePf�"��n���'�+�l�h[�Z��>�PSh3��p^MU����d]��4�y��mB�O�V��z~��l��DB��Z��������}����O��t���E�	8c�Qmzۭ.ܬhP���A;X>�>k:2�J�V{U֛�eŴ�,�WԿ���v�Ðgy_b����բl9�Rp]    q�]���V:f�0l�n���}:���Ӄ�C������.5ʔ"%+%5�f�n^�qN�}�g4
��2��đ����A���E_=u؈��N�@!s��#ÿ�>��P6RA�Iq7��<�6�b.
O����zb��%�!UZ���3:5�x����W�R����q0sI���O���>`EDm�E~�׉o�ℑ���I�]�ƍ�k�WvZ�������Q_���O٦
��$t{�9/ƛ��~��Ť��D��k�-�+�Z�iO�7��_Xz�*�����,λi�D�J{Z�eÔ�Q�^9�ݢ����*9��7BS�����I���/�-xvԼ5ҳ�v�r.��4��~�%��רGE�Q7Z/����B�eZi>��O�� �,�Z������/AR�Fn�����q�?ii,Nb'�v~䢤�D�iC��*���1��Q_6�����Uii��)3��i��V��$-�@��2���2�CS<T����T�g�b��S�0�m�O�ǳZ�Ɓ�;�Z=,��
�[�p"�C���%�A	��j�V��}��6<��g!���=�~�M�$�)#� ���y?
�I�R.�4l�[��ަ�5f�cFZ��7nY�^�r(|O�Ɓ>$m�����dQ��7[���_r2\s� N�<r���{�?��K����x1}�B{p䷲L�X����~�0Ǆ' `[E����3��4��(�qĳڱ��ro}F���]T���d5��^��ԥj�w�O��ݦ���P���QG������u�S���5�����(jQ�E��x<����7�|�O:��Ŏ;̂��X3"��?�A�۸� K� �Iw�'��m̝f�k۲�Lub����|��&)�v0z��^��I8G�(�����̜�˱]7)��-�@}��/z�;nk�Q��*�A�Q8n��ّY��Q���/�p�/b*ܡ�,���n<�F��# ��{�V�S�G��Q�~��6���xh(��Y�6דZ4����j�P���|J�b�����85��JI��s{|��)i�
Κ�fZ�̎H4�L���6/�r�q��ڞH���|�,c�iQ���A�0�G��$7\b���Wz߽��8��B�z��]�x<r�_�3��]��׸�{��	��:d@�S9���ɷo�,	��%=��=[}����ʳ�� 1�I�R�)��1q���"�i�h�G�$���	֎f�vl�ӷ����U�� B�Xm���52��~��R�ya6��ˌ�Hw�H��.��.afS�%�z�'�jڨqY�����q�����������cM�KF,���cL���?vl4�DS�P�N;�E��}�$�K��Z"�xj�S������*�̏�{���Z����^�@�Q��M���;�~v�OF�.*ʋ�h�&�l���=�N�`��vc{h.�	�4�Dz{܇�ϓ���M}�`z�`%���yD�Ȼ+��Z���z?�.wez2�QU�nMWY/��5"f!�_��y=x�ǐ�(j���y��ϢN�a���<�J�I��g$�F�}~)r�d'��Ejz���}se�Z�Pb:h��O�¼���#A.�l�uUgEC��嬻�˓��藡iܽ��ڭ�m�.})�qH�ͽ�0.!	;��d���~�~�U �4�澦s
��pQ[X�S"eشh@	n�W�ڒ�Y(���]�󖚜�7��n�7�'��{5ϸh�4�GMzB�붞H����4������]��>���צ��*\�y��Ғ� ��MN�Jr�5���)MՏ����[:�Q.|a�z�_�˽R�~�.�l-�n�?8�L6���e�~c=�y��-r�w�q��F�k�[lSUQ���&v��'7Y�`}�Mx����=�d�l��jX??�{4�]�'��������4j���}���@N�f��Ė�i|�Fon{�l����y��řY�m������S㴩0��;e�ű�u���8�h�2���\�n����"�C���Y�c^$�>p���u~���|W[7(J#�~M�d�?���C�R�����{\���h�.��ASYT����Ė:l'Fh�n�s��6�)�G���Ι���`�/�ft��
a�@��`�����;���ޔ�"�ޏO撣-�f�U�ebN���$"Tl�n�߅-E�!��g~�5v昝�4IZP.J�ts���%m(s��>魪�ھ6g� U�B�p�F~�u{��t�G�]�T��ؿEwŽ����q���X[����M�FNKR�i��v��s�V܁Hmx��%=�����X@����Dф�{:Ό無Ӣ?�r1�򵑚[� s,���ŪRfn�C�p�b��w�ND��EAg(��;ٺ�n�׾�s�D"���Ρ�8�����F5�ũjsn\�E�9ձ��h,˛5�P���nX��@�$%����	}��܍Oe[�$M��q:�>�ܧB�ʤ	���#s1[δȘA[xԭ��Y��P7n6x%0`���v��|�߁50u��j7�j�qS���b��$�|{���
�����d5���S�����]�@����n�J�l�F� N��=�|O���"�}O�Wo�U#�6}�AS��]e�[�w_f��`<�qs�g|X���;�!j5(S'����~\���n���3M6��f���!����౅��T-�Խ�q��\6u�@�iO��W��� ��G�}���ɯ^p� YpkJ����~8l�?uj����m���Ä�n� �%~4���nI8�5_."�87��3Ժ��X��C/c�t)
f$������$�-!�g���ˡ��n��t��|�	�|��I�Aw���5��Vj�c�-uV��-�q�ɠ�CE-q����������S�⩿!�@Z�Ao�y������Q=�G�������eh�PD�)�ۀ���*����QK�;πSɌ;�?��l�/�[Es}rG�.v�9ڶg�?�OfI1�h�Q}5r��P����N|��7�}xc�G�T��&�p�h{�<h�ޜ�z�7T84o���^^O��xq%��l*�����W<�:(��@�Y���6��I�j��[tPڢ��V���-�g�����f�f��Ԧm'�y3{�ϊ��(EE��=f���m�#TǺN���rRL��'tG���;�:�ܮ����-w�nQ��ĥ�yBGQ��^��u���_"]L��ⷨܣ<�$��%۱E�s�8�J��W-�켭\Ӏ��<
������{u�<� ���90^<v��A�y)6����o�����)qIM��꣹��ֶu/�KW1��APm彾
k���hBS䭝�`mEa�T�8�t>��A��e/TJr隍��˳��2�ĳљζ��~/�w܂J�8�F'��&���v�@�F������,�ӆ���~J��b���=�X ����_a�.Jo���\Ĵx��춲�������4�}[�$
;�-5D8L~�[sG-M�P���'�Wנ$��.�P�kp~u���y4�����Q�s�4�<G�T�N�}��������;T+�������x�.�����ڜԦl,u�k1w��,�)s������z1y׬���cU�G�E�s#�G�o�'��� A�O�l���b6���/��Q���v��լӹTttV�_�s�E)���.�Cq�c#pb����`Z)�qT���@�\N�<J���!��m�~�!�!4,���3�l��.i��"۟|g�j��?�L�,pn̂w���e��~0B�0�5%�Y�=(#��3']l���q:�sۛ��k������+���p�ѕ�&8�m�V�2qGw�xt��x!�}?��?V4�A	�qī���׊���t_*N8�r��H˦N�0���9G���{P�e���O�_JC�va��_�Y��A��s�.��@M�n[�v���@��TXtj{7k�k>s7jL�i�/ۮ��%C"̣v�Q��Z<;-	h\�Y���aSY�)D[�WG�U|�8��C��b�*\������\ $o��Qh߿�3�� i����]Rk� �
  �xqq�Y����a@H����o19�˘@��P��Lw���8�9���Q��Ӿ�u�{{4�fS}B�ws�-�Ԑ���E˝��Voɗ��=�CQ	��K��6D�dD|�v�N�tj=��)0���==��������^�c�<�Aj��J�I��:��i�#��.NE"Rab�~��@�jR��}y�9�g�Y�C�����i��:�6�+����h$�n��g���z�M1V{A��Xrޙ�5�؋S�>��AYC���b9;�^�yP���/��/��ͽ�gܟa�t�+d��z�|{�:�(��y��bw2� L�u���:��X�*j1C���Wؔ�R��L�MI3��j�6��,@��P��^?F�*�J�4e	zv���ʌ/eE�#*�Y��/[�)���t� �����U&@X��1��_ɵ\����v��s�]�wܣ�C�4��|����>�7d�k*����ֻ��wU����T��0D;��)��#]�O����ZxWɲ�qQ����CN��v�ch�޲H���p�ٞ����)'��8ލw�Nz��jEӃ]u���OA3�sLTf��0Q4ZKLE��m�^y���_�p��Ú��[���,�7H#u����W\B��N����r����wT涨E�����q*����qZ�.D��`-f��qkU��>�D��tD�Q]�=�t2%�\��Hx��O��%=�ס��h�N���d*dP_IEWl��v4���z0U1�!��^��Y�ە���0 ��a;P�Q^d�-�e�xi?��fZ M�Ո��l0�n��ʛ��+�D��b�NO�C�`�$�F0��8���=Jz�ͳq�yvy5U�]벰~���t8� *%]��í�r'�
�a��e��a�}�[�c�Ai�7>�s�h,8�[4�kӵ����W;,I�\�U`������nX��Ao�u��mbr4Ȗ�Mc�6��K4z4/G[�֓q0��j�6l��7�>~��6lP��$���w��<���N��G���5o\���i�5Wq�cxOe�.�e�W��$,TuY�L�w���x��&�C\,���g\B��c�4�LRg�2һ���J{��P�n�t�ezIo���c����]<q�����ߒ
t/��1�����ns�����/�ϩLV�rƝ����C�ٵ�ᑖ��O�j)��*�RA�-����f�-L� 1qB���df��(~p�-��S��r���_�B��XP*�UN�4�l~�gGDYEs>hg�c�9)h�p�R��H?��=Es%���{/��[N�Ҭ'�pvn]�P���?�u�sľ����''U��i%Ů9t�D1 *�Z��e���1_"y��E�����|%�ˢ�J-v^}��&ܨ�iL�Ҁ���ˬ��A�7yH=�f��� T�D�T���O��c��c�3��!����G�����?{��"���z.㬶\-��-�����i�UQt��S����bɥ1�w�C&�k����j-��x��l� g"$�]���o���y\�(��������_tn��iz���2�M��:��E���+��8����vv��f&b���'���R��rPFEWB���:��e*��K��U��[�oo(/�$E��4^�O��:|u`�ȣ��w+R�]҂ �[��U>j�Aѐ�E}��l���,�����++L|&O���*����G��=��ו��Ӕ���͆v3I:u�z����T74�F�Gl���vl�u�:��D��uP�����sE�DAm����{�n�2��@q���e<����4@.~�q��sUS-��\Wo�n��<6��1y�g��;�l0H��S�M�=�����$��N0��=��o�MX�hv	�ݰ_
xMXk6��J��Cĕ
J�Q�6l����m���
wQA�,̴gw)m[X�C�Etu��V�WE���5(�ߪ};�ps^1�A���e�\2�U�nڵ����;�� >�aF�Yn�ր�g�aDQ	\؏W>��n5*~�O�+�B)Qo�x͌u���6�<L�r�\]e�JpU4h�:g���+�?)9ib�Sq=�:os%��60L�=m��V�ls�VeImy�k��5��:.ɕ.�Åş$=��(V�Î㶚�߼_���-�����j��&\.�ԡQ\��V;n��']���1Kuy��E͸4y$E�s]l���ei�T���k�{k�lt_&�_����g����%OUPJ�j����T��^?}��oD��n�|����k�ح�_)�E�]���n����
kф�'j��%�=Y�+�7�R"�ԐYcn��!��4~��&�U�����Zt��|�x<dw���`?���0��KQ�T��bᭇ_��T�fhb��7��T^�l��d���S����A�}B��e͎��=���D6]V-�0��۪2R<�aQ�Ф�S�&��fZ!V�h5�ͽ��hf���A�	��r�:�6�8U3��z�L��Ltk�)2'mM��`��3�̸E~V̯��o9�$��c8��ש�pV��DןY�|��^� �e���͕ͥ~�yi�fC4��k�~v�t�$��R^�fu�Ch��&*�pݟ6�F���IQ�M]t[C�v%�����5_�����BL	�Ѷ2��uZ^JiRF��1��st=�S�t����y���e�a ��nO�f�9�䳟;g\Լ-�|�?*��!���z��^U�����8�$NZ��k����o�Zg��Tz��?SM��mqRϡ�Ʃ���ٵ;=�f�"G�=mE'��<��vT�tݍ�Lv�m���o��*Ƣ�������� @��      4      x������ � �      0      x�m}IsI���W�mN�ڗ#WI\$~$G�i{���Q���B
���=�$20Ϭ��lU����e\FE��E]W�7ӯ����A�Q��L��ʼ*���,�nܘ���A�q���Igu�y�}�t��6//އ�*�[yQg�U^[�zpSD>��#uZ�Q�y\�v՛�Kk�U�5����<ˋ?_Lkç�l�~>rY�9���#��~amx�6���KUUWe��E<���5�`��ɢ�ʱ0u|���/έ��k�6I�Y���i�'����צ����Ӳ΃��ߙ.�����;���"�����5]�kc��u�O%~%.������Қ�~�q]FYx),\cW&��^ٿ�۰m���NgI��E���s�������{�*�Ң(+l�m��i�g�3X���MeR'U�EY����Cx����G��"�M\e0�4��r�n�8>tGi��5V���&�Z��$0�"N�<8�ҭ�;�J�FU\�Qw�K�M�G��q��
��Y|��췼����R^)�:�ng�f��;ӭG���KgI�&U�%���:����߁��Ӽ��(x�҆_����G}��6EiZ`i;�.�Ռ������Wa�{Ӿ��o��{���b^�ET�q]�B�mx�z�`�װ�Y	��\�޵��㋔�'���"
�[�r/�a����������	��fZoL��T�Um���;�ܾ5ʺҺ��������tذ�X$�DYUdx�:ǩr��7]�x=�;nj^�y��t8�bq6����=wQ1~,-��+,V�ssP����Ue��7�嗖vXn1x�ɳ(��,����`#fٸqT�I��Y���݂?�`Z��H��l>��S`�8��9~�s��̫,β"���p<8Ͱ�al:ߌ��E���E�����[���,���<`���G����u������`���Ѱ/է�9��}=��M�L(��I^�~a7�*��������8J*��Ӻ6����N������a܄�S�}��U��`��(�c�4��ʽ6��iE����(�kc3�^o�vZ��a{8���Jc�h\Z�B�x6o* ����Y���� R�7G�T�	bH\U���5��6,��%xe�VU����L`���S R�g��tx�����UD)�������ay|��α�Q�$8r�����8�;��q��8	�}�D�xp�i�t��VR_�uz�Q�4�p�,�a4�/�*d��pkY�H��6��ُ�v3u^c�yp�G��b]�Z�3zXo���|2�]���p{|�`x��h�o��޾�ժ��sƟ(��~2���R�e��S�<�qZ�b��`����>�_zs��<��b1��OL��p�x�[8%{�d�v��Ⱎ�6�x�+�w�	�L��:,JC���J}A3�pk��Ύ�G�i}�+�7c �Z�[�(2�-�ֳ[��,fM����Z�~�㑳��GO�q�w�h��;�oI�Y��'����s����[L��L�_�ߘ�rc��	.�Ѵ{n����#��.\����`�*�<�c��!����uo�C�iaǵ��Մ��0��c)�i	/��{F�l�C��r1�[�x�!�J�e�Τ�{��x�k|������� Ѐ���w�r�x�,-���>���UǺ�"Z�*a�"�0z,�πkK��.6���l�0�qgIã�l�~��<�������!״f� l�`xH��?����?�{�u㥁�������F���ɣ:�w �)?`���G��&)\D ��������Z� F�]-?��3�l;�65��`q�'0��$��-�bqʕ3)�@���q �0//���a�����v�0 ��9�E�d�R�kl�_�u<��|M�7+��G�*6��LhBdZ-"��Կ����%��G���ǘ���D3�<U9��p��f�m��^	>��� �c��f�[
�vF�
�?��۲�i׌��a�[hcB�,Ey�`�	ӹ��->8B(���pM��`��n�>PQe�c&�o�}�	!���$x|@�-@�3[�/�j0���[44$<�KD����*�2�nҔI�T���������v�Bi�2Rb�������M�� x�:'��'��'8�} 	��&[u8m>%�lE�T_�Dϡ��� Nã�H�l�c`���%d��g�|�+_�H�}�Òd�m�����q�qqd�Oa|4����Q��{�� �=�g�G(8ň��qp�,�$�9ڲ��''��K�*���
U�p� )�I|�K��2<hV���8�O!�zeS�8'B��1�l�~��*�1�������?���b�㦟��;��|�ͷ�Y��.k^�s�Q- �+��+xt�7�$�h���p@M����@�0t��W��Q'%|~���?�ed%YٳY���'<�`-�,�RBɅ�o	z}�\������P؎�m�n�g`^�����n�	f��(HXpi�pa�>pș���Z� u�7�?�L��FprYN~,��q�V�Qh(�S��r�-�t�h7�<�^�/HM`i�ݶ�b'n�Sz��C^8���@��	�}�?�)d����;C�4�R̈́x�
 | ���4|j^�� �����Hn���? ��p�ӄό�� \�O�����X3��"��GvXhߍ�%�
�73�g���Aa�*�Oe	���]x��kQ�E`�%�9��aEt�[ ~��Ih&�O��ׅ�H��LZ��>�7,I���>��?b NF���pLbа���yĐ����!"?u�z�R0��L��@@��"�Ʒ%}��[�j@6 8�7D�p���wҮA�*~�ߜmtv�V�������݈��8�s8�" �V��>;8�L]���|�iL[��8�:�/��h�ݠQ�)�Mr#�����P��l	s�&ޘ6�ɚp ��U0��$8��r0.���u�u���3O���T��_)Ip����&,y��{��x F�#�����Q�g���"tV�8wW��7��O+�7`��ڴێv�Mj��1�3{�{�VKؕ�l��Bq~�"�ux�K7�7�3c]�)AZ���HR�2����@ʌzT'i0�&�r����(
 ��:C�39g����)f�d�3�y�5;�|S��0�ϳ�����oF��s
և��l�3|���</*����Χ�Y��6�T �"�f�����!�Ri����
�2
n�&��:]��GUL? �d�ɺ=m����d	��2l�t�b�zm�C�����~���6��Q��x�q ���o�#����;s��{SE��$�,�ley���#ó1q^g�k���HS�&#f����S��L�p��$e�eغ�����Zu�Ĉ/�q��V�i?H%��c,NFQ3��^��=�]�R�^1�(�ƪ18��2�	�\���/o�S�g�}�&L	���7�EHIY�Iad���}�O+�L�2�S�b:w�ۃ�����49�'oc��� �^�'���k(�9�ש�a���
P; ?DRp-�~M��uEҟ"D�L�u�x�(�ڀ�5K�2����gГ2�iF�:vFŐ8*�s�������;U�<W�Ĉ#@<S7��u��X@� ���a�=�T�����>"66�Պ��C��y����H�:��\87,v��GՇr�^&_�r���:f�s}1��^�H�F�r��B�T�!�C,1�r*�b8��R�"-��8g���A������H@��G��t�A�2�N�3Ibm���f��
y�� 
˺a��h���5c#��80%��^�@D����Y�k���=n��dQ���Y���T����*O�;z����"���GS�Yl���]��2�%׵��V!��T<N�8ex�y {l�Cx���AEc;��I
�t3^���	��TL������v=�V>���eM�K�� �9�*7�L<���͉���>h���f�5���    �wɉW�ˁC�'B@
��tG�� � �Y,��~K��L���4"i�����5!dI� �	k���: 'e�	�*od��t��ѧ	����E0C�vu��/@�R�b�eA�f�|�����O�FY� �)�
�����Q�:�BvYÄY`�~��>�+�����x/u�V2l�Sv\�2`�����Ԃ�~^=�4���p��2�%�X7�(�3\�I�������8Čn�K712^�Q:���т����������`*�U/,}��5�b�$�BO��AP?�T.'� �c��u��o�����#������cp�H
_q�rrx6l��'q5s-8�T���P�c8%��� �2���F+/
�Lj�*ɂ� �fO��y= ��T�x@�`6J�|p@b�G���dQ�t��Ԧ����<咅/�U�Y�>�3�р\]������U���sw���d�����t�6���^t��#���E�M�3�>�O���Lê�s�2�*Gt�9g��y>Ļ���gI�22ز����D�ګ� � \���`�B@<DϦbf5�3���_�o������@_��Z��UyO��3 ��a��W�j�U�m�Déí1���]�4)�:�T�-�k%0����Hsd@���7�K���t� ��͋�?gՉa�_�Q3�GF������\���}�)�I��[fUD�7�^�/�64�Y������Ww̥�9���'K#Rmp�>|h����1��@ ��ߪWn8g )�>4ϧ���`�53��-#��~�R<~�b���,w-Ǆx��[��D�J��3�c��9�~/��q2B.���N����mR��Wü��;����ur�~�W�)T5Q5�=����"H�3��
�n�"��fzyi��K�������㈇�YT�p&��$.������I�0�Xًx"���6�`'�6�Ɣ@����507t����X�T��Y���z��x�"��ֆ�4x!����S�/����8�*�g��U��"�@��Q#7�z�T7�n��R+U^zGu�r:Q�$)�ux��n��8 PQ��sA�R�G���Y�`��mgE�`�������D|#��+,��d*c�iR�.upi���8-���p$�J�_0T��e����H`��6@���%�����/aU8����Z�sU��N��nU�?ev*=�2e�|��?X���YrR1���i��l���� �RSkR'@+I��[9�� ��2��6*~_2+��谙3��C� ��h� ⛀�2r��R�=_*P`1,1���N��OBcc|�׭��G���W����)Ԍ���2�n��bU�����yD�����~c��+�櫏E�[��	� �����޺c\S�>�����E���n�M�
�5��Xp�Iy�n�hw�ȩ��D�
����o]�uLg��^+����4/0T�s���f���k{iFD�
��i�JM�'9�#-��>��p!��Nyck�P��*��`B�;j�`��%76������EP{���5-EK��+9s�u��T�N+-��t���_����Κcϋ�J�3#�Y��5�/S.�Vx�FEH�e:&�%���M��q�ť�2v���,7*X� �%À��y��p#uEu`|#N[Ï�� ����聑`� �̎�,��u0��}_ʹ�GE\	��pm����p�E YW%��{���4�I�H�*��CG��
��ZX�<#�㕄�ӛi�h!cb'O��q3���K}��� I,�s+�z�Y(�#ԗ��G�ф����Q9��j�?��mC��Y�I	|�5f����n��<Ȯ����֭����rӞ�z����8s&v�RZ3�'=#�(�"����рa�s ��S��L��6��>�E����HXc���U����N��{>��A�W�M���B��UB�e���	%)7*8񗱸��a�*�g�l1����&� ���S�OT	ՈV|�m�-Q2O�:�Y��7��+�I/A�#�6�^35�K��O�#즴�Y�2p7�6�H���������5G[I���{�fO����J7�0�'����y�^+�	��bA%���;�yh:������$�'��?)�Pu=R��HJ<��f�A���𑜉�T��	�M�l%eC��� -p���×E�^*��Z�ص�x�z)Nv	$���o�z7 �TiA�]"RxF3����CBD�c�x�i �զ�0�?O���!��/�n[�d��`�P��( ��U)����J��8��k7�jY�K���7uD+�(5NJX9�A���l:��kǌ�G��K"��Ü&���l���� 'p~�1U�� �d�� ����%x80���#\,E���Ӭy���R�zJ&`H8c&�Z���<1A�;Q^G�y76w"�<�jə����a�5N����y0�E�4o�Ƃ����#H�kch3�ZX*!
~YۆE�[�)cͩ9�b? ��'���g�i��/�@xľ�Cg=�CYO-F���oܟӪm�0�K⼯z��>���U�S8_Lw�L����i���"g�v����X���B���`)͇/@���.BDFQN�,`��7gtV��� Xÿ_��E}�pR���
�;Bя��ۓH;/gR�f5+��x����ڽ�/��YB^K`��v��!�[�+Y�����Ĝ�	,���K~��>b��0�A�s
|0��^��=��� b��\Y,ւ�*Jj&�q��v��t��(�`��`�$���F+����+�QzI�SJ��	��6���VG���d����&pB���4��� #�@��_�*Ԡq)�^���~���ޮ�Q�9���pѮ���	�R��C�)g.�����{�|�l@Ɇ�'7�6(��Me+��&��=��E`�������kt��ʀ���pVoBV�I�!�l��ݹ7i��:ay�S��OcVVU銬  g��v���?Q����ۄ�'5�ҪN��>S}��k��}������*�'+ju�'Z.�
_yFM�b1%��X�����4� K���E�l���6�Y_Vͮ�P��J7i�9��K�8P=�lS;�r(t�#�r��a�VY19Q�>�:����	�j�*F�*I)�r�.ͫ�N��EEElV3; ��	�$�^�&aN�8�!�"�����J:a[��+)۪_��Q����A�'�	�E���8tyժ�VR���ƨ23��ԡ#l�i�lk�P������!<��i7���jR᜕R�h8�l����f��5>i'��ٲ9-F�d8f
jú��UiB�M}�3<��9���4Z$ь�0��ϡ0�-�(��xnh�4TI���EQs�ϘJx0R���|�6I�ۦA�#�h�JIU,���8H�3��'|��]�>۩�5�6�M�����!H� �
�e�̟c��/mH=VZ��yƲs��P�6֜tB!(�"0��O
e��"��lVX���T�
G�=\4�"*��˙X�5��G�`���DUU5�'e.��Q̱��n}D�YJ�	���J��i�p㬧��p|@w 0��`���յɠ�(��޺�� /���2���ط�:�����u��c�!�m�^D��}"J��<	�N�_�"֭֬_��sN�Ϲ���m���A�toI��w+d��5'��w,1���Ty�ztN��<a畠TI�=�����c�f1�"������e�ֽ*Ӡ-���w����V
t�{��V��Hh��"��4`�a�4��L�7�,z����(��ǉ�����,��
��`�]VG�! �{!J\�e��T�����k����*?X�H��Zs�W"� I"��T
yP	MQk��p���fŎ[!2"�3�=ǹN*&,v�U��9����/�`���{ꈹ]�������џ����'9�+S�iZ��s��: &b���]E��Y6K�j���z�dT!�_�n����K���S�L���V��*1p8{��ˎ��ϗr    e��'�=���kǌ5���(�[���0I:f#�b@ �pǍ
�`F`����o��ˌ�ż�2��κ������]�UYQҫ�Җ�qIA������&`�9.���|��q���ib��Xa�
�^��w��[��˧kN�p���� �>|���$
��q��!t���;e3:�-��m7���6�f�9�|=�2 .�6|Q
��������l�l{X�4^���#����َ����6(��P�J��;i��R(�b*k�8�qp��et3A^��K,+>gTQ��<q͹�!Rc*�[��E�m$�:c�2۟E���G0�o}2q|C��:ߛ��I�[TKi���^h��=&bҬb���`���f;Pb� ���n�+|֜��	Ŋ*Y�"�l^��J����G�h����F�Q���<�dG{(ρ*��f�:`�����ݠ���7R�k�>g��W�U�X4O��D��Y�\�Ɠ�E���nѳ�nx�̨HA�ʴ`@r�0�`���J�3jvH���ŗ����f��J8��_Xc�f�g�IAy������{e~Ce.0ʈCC��tf/�0�R���;KF���"j�IR9f�哩_1
S
1՟����@ߤ ��)A�ܙ�\ *�dx���@辳;OҶ;U j�)d�7�CYf]P��'3�nNT�x�>�6�9�΅����-r`�t�|\�MK��R�Qi�4%���(�8��%�����)`%Ҵ�B�>�ě����᎑h�~)��R2DX&�j����)E���t����2{? IM3�ަ�Y��qk�ҬE�䖳��ήu�
J��O��`5%���#�����7z�G���W��?	��� BkV�E�k�3���{��rT�s��gm>����˅*�
�Y�Fx_\b:�,�H����|�wRטG5_Y��%ϳ��HirTĶ��;�ͦ�۽!�H��t���<����:��.De�������l7�$QʟerZ'E5�a�4$�e��f6pܹ���_{L��U��6I�Y(NaȈ��M�~��޳������Qv��w^qk��_� L�h��2���ޱ+uc�	�̋a�Qp�8���I�K�����lZO�%D�Vu��^<����,�d�y�(�)C�2 MI0��Bˡ=a�,�R���縝G������+����%�7}Z:��ϱdtsDʏ�k�E�Y��8����^5���kfL�P����vX@��ő�3-CN��gB}��H�������0&�XO�Y-w������L*���`M����^=����Dro&��ti��PQ�T2Mȡ�0��F��9�F�����<�MdE+����Q��G�^O'�??V�2������|�
�d)�q:�K�h(�5�";h�!7,��v'3K�����1��-�/Lʩ�D������p�Y��\5>R��ѓ"��Nc^��z}2�Cǒ�N��|�ګ�~���@2�(�UQ���[�mh`��S��<	)�Kƚ<{b(�_����U�4+���(Bh�Ծ��0E��i�]��`��9d��E�����`m	��w��1�{Ӵ�%G+q���p�j�k�!@wa��<�$��^6㘀��gM���\ǭ��
�?����g}y�ւL������/�S>s�C��Q�7iI�KruQ���3�Ꮾ7V	@��Lr*���̤�% ���t��l�a���tFpzp��ݫ֊�֝4��SD
�r)�ENC5�$���7�@8�^c�nFf��8�����U���	_;#�8��n��q�?V�K���J�+��Gj���g�d����w����ٍs�Eڬóa��<4�6.��r��>��Ƃ,����ٌ���u�𛲳K�W�<Jg��o�$�;7�
f�3ʇE���~�SyN�uI����W_�E�RVg̾~��~ο�Q��$cH�8�y���v�_��'�b�*���d���^df�T�����/��Z�:�L�E8 d��T�S��9���𯞽��#�$s�7淨g�U����G���pӨ<��~��)�w2�AERΣ# #{�\tf9�'*69!���>�\]�^%��H4IY�����P/��+e�Yq^.q��1�fU|+�:cf����b�a���gv�TI��=S�}�-����l��e?K��V��m&�*a��F��3��mzo�>���"3�����
&���6[.�-w�W������#C˺W�gO���.O� x��~��j!.�Ӄ�(Ï�1	�����I����Ŭ�0��&����J=�'�cv\"��<tA� �-�D��~�'�^X$e]��>���?�5fph9�p��i��u������P7n�>O�a^E�(6"�J ���hU�D;�� �����v߻�OJ����B�Ł�#����U�5+�����!Lx�{���{�Z�βnl�5,� � [bޛH9���Ȳ��b�^��낀��&�y'�P`g6Z�I�;�O�쮥��[��{d��p� É����쬑��ln︶�޶*5��R���#��%�p�0.�Ex"��6�R�lDy���=��x�؅*��?lӥ��/����}`W,��,��6��7J�-n�4�W�7[��rҳZ��섙MB���������IQS�A� ���9���yO�n33��U�\�$"��L����-���Ɠ0!H����$�죤����fGk��u]5��	��z�� ���s���3&�xt����
�.�QU$%�=��m�P!�Z�ɭRμ�#_�O���̹�t���p���B���$p@�(�-���SUy"�	<I!#<�~弮c$�c���8��1v+S!�Fe~��n��l�H��=Qج�T6 fp�ғH6����!|[�Ra;��Y�<��qq(�c�J��kMOq�a���]�epa'�i�l@��q�2;��Yn��(g
F �R����/Kj�e���_f�s�2ِӹAX£��w��2��j�@pJV�c�⺶�0p��c�׹�;�9B�n/9j
p�t^�dݿ�e�G�Re�ج��E��d��e6���/njW���R��a�]�~�����P�R�8��Q�x�6/޴u�_������0��Q�.D�aĴ�t���elkej�!g���i<���� V1�$!ʊ�[2�n�t��3���}%_�f��[�.*�*�܁��
;�g�%@H�D�L�md�.:�uŜ��S��-�z�*�8ߐ�e�G�I)AM�`@A3bm��:��P|���zN/[����oTb(�Q9�~pLwn��M��d(	E:���J�0t^Gys��A�0�C�9C٫grr(+Hs*&�F,�Q��H�@��:��,�(g˘��C�&	��9S �|%�mN��t��5r�Ѽ�$yҢ�eu2ͥfF<�(�}b�y�c�TT#�(��]J��k�ؙ�G���s���W3J�"��!���D�[���"e�I�aM�va� �?�q��� 6�Z�W�BBM���g3��ΰ]�P���[��]#ӏ�e4�(���[��
X)��U.:y%��[2�,x���!Z�W5��J�贓���8C��S�+"�:�֟Z�	qk�<N3V��D1��?'M{1{5s��g��>���ź�ۺ��(�d���9��9�2�d�0��XF��"vc�<cW@�[������j%9�g�ؾf�P�?	T�Z;%$�H�6+i�8ah��e�;}W2��o����}�y%�#T�r[�Ye����"<`2��1^�A.8�/�~b�~j~t�,e�}$�P�2u^{>f�iČ�r2s�z�5�)� ��h�Y�Hh)@�e��~�α:�E��H���tls0 ���Z�톊�E$U�R.�L��ǒ2?�K���h'S%c����j~P䭗sA8�LE\}��b���U `�A�!�l%�"��ɵ�.!�w!�a��U����b��햽{A�&vH*P��_���I�I��0o��T�	�����H�d��Y2S�k�~�k���0�Ȥd^Ifg��    ڦS�3ㄡ�����
u��)a3ۂ��R|��)�>�G���7�{Ĭ9�8D���L��I�\��T�YJ��ѽ_���ƚC�a����z��
,�$�8T�:��Ç�t˓*����?�Ç����ȩ��gĜ��H�fql��2�c�9��T��nݟH�*�q�g�s��l�W��������߆c�����ԫ<&��I�O�ŀ�p����ހ3SX����9˻���O�Y��^𨱓�YV��u�5�������y��ݴzm�Z�C�,ޟ8��]C���'ꨒ�b2�A�_a��¸j��j!o`��pT�Ɇؠ�I<���35~o��ٍ��]�C����:)�q!��N���RV`g�\�(���@��V�̩��cw*=#A�t1��l1��	������5���?� x=<kO	��#�'��<����j�7��������rÉ�άN����"��l~�D���ť"���Y����昅�93�ؕ�ݒ����%*A��d ��{|�o�o���y��ꒊc?�[��L�FjU"�͎�������Ǽ���,�6'A��2�R������T��إ���*V��q�Y�*ZQ�V�ڎ�B��luR����2��i�;AKz����v}�ȿ�>=�A�`WV�إ�8�4�#�dk�e;D0�+�:Qt��!�Q�^����уC�|�*J�и�0L#-=���Q�T�X��r�ޗ�Y����D��.)cV;�&f4��P�K�C�1I��G����粔l��8����JJ�/Ų�Vԇg���`uo�n��X)�f��ȴ��3�8'�S�9W���i��
����#
�>���kU{`��L��`+?'��a<	'��������k�~sB!����yⴎۍ�b��A5�z�8C``�.Шen0g33����W�q��G,h�e��Fw|r�56��e�
�r���H�JQHٵ�)[?��=��Ce�����Ξ�^�Lw�k���#ڇ��� �8����l��1��.�8$:��^J���~P��H��s2�AFYlDX��L�	2���Ka~6;�A����������B���EEfJ��86���Fa���ƒ�k��pA�j�.S"f��=��Mnl�~M���o$C�G����ؾ����\�c����6zv��Tdļ]���TKLsfy)K�E|u��:�3�Ǔc:`?Z�K��z�BN�(b[]�fZ�n=-f��c!�Ӧ��A��Y�(~ Y8x~(��ǂv�J/y�$�!8x��H�%af`l��̺�a��Srl��43*r��2	 J������\�饹�ӗw*�͓D�+��4��HʾHy��Lj�Eʹ�� 8o��^��9��[������2*�V���??x35�?�R��߉mٝ�F����q^�2��`-�j�s��3�oXP\D���&CH:1$fn@ոf��,�Ϟ�*L�-}�u/G��|2H��9´�o��G̹�V/_�,	���VrR��eҽ�	���;[�x��d� ��7�@�Ss�s�)N+��V�`?Y,b��JMd�+fx�ɬ8����g�J�˚�W�Y�V��J���2���Sk�失*�k�>ˀ��F��1����ly¹�d�Ȋ�qU�eG'}9��}��੍Y���́��L��8;2�iu�7�n^MQ_\�B��R��{�^׀���Ƚ�p$<aD�*�eɚ�AT�g6�,u� �����;k�?zX@5�'��5����a���0�������k��Z�+�3��^ȘRVκN���
�x��A�a��vr�#'� �=6�mC�Iy3_��bjî)͟*٪<!39�����{m�`1lT�6�,��Zr���´�k'5c�'�=��5"b�Eӻ�'lOe����^�)	"�G�04'"j6E=֑�E������%|k)��������3T9��;�b^�b3M
�yo!<�] ��ɜo��=�=��Z������`6�<���Ӓ98D���~�Z&�A���KA���ᤦ
>�1�S�xI�]��޼w��5+���yi� <����"1��F�1�fKHq�zNE�s��/��OQ�_�)���H���M]3 1݁���`D����Tk0�lV*>�Ɏ�R�=̥��oN 7ۨ��G!�q �>�dX�S����dz̻!�n̎������Co�q�9���L;>w�#���W�9h�o;�`U�8��Lb#4�yi���z����k�	e.U�eߒ���)k��󲖶��V�/�M�Ɨ�Q��+�6]x6��V�y+�DL2��5o�O�,$���{���sDc+�N��,�m��36��	�1��H+c8���F��v9B�6Gs/Rd��H^ y�cμ#UG� �7&��ד��8�0"�*�mԞ(I�'�f&����sO9j=K8�A�����xMN!gJV�ä-�/�>����C�*n���SaL��K,�A�l9y��<�K2��"�������K�Ǿ��II�[�sj����=!{
}�M�l�����En�}/˱���!ʳ�B���zy��m�:�{ߖ�yQ���@����6Ś�N�W�\�l�%p�M�r�1I,���[ �o��!%kR��9�xBq���JoY=L>0��w�yE[.�욨��u�n`1�yK�c�G�P8_UJ��q�$7�[�4�|ӈc�8[�q�(��=�G�� J��`��7k��8*����8dT}��D(y���h����IX��J�V��ד6":�z9G �9�4��'n�/�T�:�aa6�	�3�g嵚:�Rd�S�s�a'�SgyI��'����c.�+�R
^�I�F8�op~@lTX��E𕱛_ʄwF�@���EThWL���� �܉��S�"���Q�ڎdw��J}�H��cҔw���^�^�i���w�P�x5�J��R`��c�<,�~]3��=8 ^n��Hm5�{'��.by�}:������>�;%o�c���h�
��E�C�����^%�a	$h��u���֙�u�'5�[*eU���`֡����>�v&]��/:��e��֩K�E�qui�[�l�Na-
�Rlu���|�mZ-Q�/n<�8�F���=X�\,|�1%7�dtgqfg�HGzn�����*�\@%�����~���w'O�,.#E�>�O�� �:��+�Lݻ��di,��V����嗱����Ay��j�[y�y/'x�.���9aB�3�DZi��%�!�8�pe�(����>f���
��"�����A\Z�6�3C��B��H��=�}|��Ih*ҙ-��R-�s���x	p�� C�'�W���j#eD4���n҃ȩ!��$S�̻���6���X�0-���att/�fV�T��)P�[�l\U�8S���A�2Ə3�����^I�#��t�,��l�,2Г�.�I-���㋳%��;���\�;u-{��-���΁�\��kC%���g������R� 
�'�9w� �w�$��"��8������I�Ѫ�v���z�4khI8�G:�{7)�s�CĶ�[Iمߘ�U��)��+�ŉ���\B%����+�^q�g����p`��(d��r:�/S�Vߘ%ϼ�c!�T�e���r� ��5��[3r�� 6޶��tR�u�[����|���{���m�Z<52�(��q���ݫk�7�,*��6Mٷ��E�H.�:˱ W��|9Fͻr��)a�an�?�R���&)�x�4�O�	�yj(_��x�9�(�O�+�g�{���i+�-l�*+E��r� )J�ձ���Fx_^%�j�w�f@���K�k����r@��$ќ%�a��䝙:A���r��#�/��V��ZE��;�$u�'��dx�����c?���Tk+����������>5��G]��QSE���9��:��3�r;R��/�6�T2r�$�M�f�2��7TÍ�8T�b0Q|d9D�oכ���p3��Δ�>2��f�^{��I��<Fb�+VW��J/� p��:0�޻�$�0��27P.G��@�D��gq���B����"b��fR��� y   p��w��DLN�2�DJ0�N��[Ī�T���488�V�A�F�L���.��~Eո�>���V�Il3�$j�F%�Ky'�B�y�W�kZ���T��1?{�o8�����������<W�      /   T   x�30�����+-�ˬ�4@��z�`\T��e`��Z����Y�`l �3��1�҆@Rgh�韔��1�� h
�<��=... t�u     