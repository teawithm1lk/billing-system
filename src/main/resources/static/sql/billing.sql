PGDMP                         {            billing    15.2    15.1 4    9           0    0    ENCODING    ENCODING        SET client_encoding = 'UTF8';
                      false            :           0    0 
   STDSTRINGS 
   STDSTRINGS     (   SET standard_conforming_strings = 'on';
                      false            ;           0    0 
   SEARCHPATH 
   SEARCHPATH     8   SELECT pg_catalog.set_config('search_path', '', false);
                      false            <           1262    65536    billing    DATABASE     {   CREATE DATABASE billing WITH TEMPLATE = template0 ENCODING = 'UTF8' LOCALE_PROVIDER = libc LOCALE = 'Russian_Russia.1251';
    DROP DATABASE billing;
                postgres    false            �            1255    65658    call_trigger_func()    FUNCTION     Q  CREATE FUNCTION public.call_trigger_func() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
declare seconds int;
    call_minutes int;
    minutes_balance_value int;
    spent_minutes int;
    duration_interval interval;
begin
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
       public          postgres    false    217            =           0    0    call_call_id_seq    SEQUENCE OWNED BY     E   ALTER SEQUENCE public.call_call_id_seq OWNED BY public.call.call_id;
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
       public          postgres    false    222            >           0    0    change_tariff_id_seq    SEQUENCE OWNED BY     M   ALTER SEQUENCE public.change_tariff_id_seq OWNED BY public.change_tariff.id;
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
       public          postgres    false    219            ?           0    0    payment_id_seq    SEQUENCE OWNED BY     A   ALTER SEQUENCE public.payment_id_seq OWNED BY public.payment.id;
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
       public          postgres    false    222    221    222            �           2604    65690 
   payment id    DEFAULT     h   ALTER TABLE ONLY public.payment ALTER COLUMN id SET DEFAULT nextval('public.payment_id_seq'::regclass);
 9   ALTER TABLE public.payment ALTER COLUMN id DROP DEFAULT;
       public          postgres    false    219    218    219            6          0    65745 	   authority 
   TABLE DATA                 public          postgres    false    223   .L       0          0    65674    call 
   TABLE DATA                 public          postgres    false    217   �h       5          0    65717    change_tariff 
   TABLE DATA                 public          postgres    false    222   
i       3          0    65698 
   credential 
   TABLE DATA                 public          postgres    false    220   $i       2          0    65687    payment 
   TABLE DATA                 public          postgres    false    219   3�       .          0    65662    phone 
   TABLE DATA                 public          postgres    false    215   M�       -          0    65537    tariff 
   TABLE DATA                 public          postgres    false    214   +�       @           0    0    call_call_id_seq    SEQUENCE SET     ?   SELECT pg_catalog.setval('public.call_call_id_seq', 42, true);
          public          postgres    false    216            A           0    0    change_tariff_id_seq    SEQUENCE SET     B   SELECT pg_catalog.setval('public.change_tariff_id_seq', 3, true);
          public          postgres    false    221            B           0    0    payment_id_seq    SEQUENCE SET     <   SELECT pg_catalog.setval('public.payment_id_seq', 9, true);
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
       public          postgres    false    240    217            �           2620    65739 (   change_tariff change_tariff_trigger_func    TRIGGER     �   CREATE TRIGGER change_tariff_trigger_func BEFORE INSERT ON public.change_tariff FOR EACH ROW EXECUTE FUNCTION public.change_tariff_trigger_func();
 A   DROP TRIGGER change_tariff_trigger_func ON public.change_tariff;
       public          postgres    false    225    222            �           2620    65713    payment payment_trigger_func    TRIGGER     �   CREATE TRIGGER payment_trigger_func BEFORE INSERT ON public.payment FOR EACH ROW EXECUTE FUNCTION public.payment_trigger_func();
 5   DROP TRIGGER payment_trigger_func ON public.payment;
       public          postgres    false    219    226            �           2620    65672    phone phone_trigger_func    TRIGGER     {   CREATE TRIGGER phone_trigger_func BEFORE INSERT ON public.phone FOR EACH ROW EXECUTE FUNCTION public.phone_trigger_func();
 1   DROP TRIGGER phone_trigger_func ON public.phone;
       public          postgres    false    239    215            �           2606    65667    phone User_tariff_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.phone
    ADD CONSTRAINT "User_tariff_id_fkey" FOREIGN KEY (tariff_id) REFERENCES public.tariff(tariff_id);
 E   ALTER TABLE ONLY public.phone DROP CONSTRAINT "User_tariff_id_fkey";
       public          postgres    false    214    3211    215            �           2606    65748 #   authority authority_user_phone_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.authority
    ADD CONSTRAINT authority_user_phone_fkey FOREIGN KEY (user_phone) REFERENCES public.phone(user_phone);
 M   ALTER TABLE ONLY public.authority DROP CONSTRAINT authority_user_phone_fkey;
       public          postgres    false    3213    215    223            �           2606    65680    call call_user_phone_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.call
    ADD CONSTRAINT call_user_phone_fkey FOREIGN KEY (user_phone) REFERENCES public.phone(user_phone);
 C   ALTER TABLE ONLY public.call DROP CONSTRAINT call_user_phone_fkey;
       public          postgres    false    215    217    3213            �           2606    65733 .   change_tariff change_tariff_new_tariff_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.change_tariff
    ADD CONSTRAINT change_tariff_new_tariff_id_fkey FOREIGN KEY (new_tariff_id) REFERENCES public.tariff(tariff_id);
 X   ALTER TABLE ONLY public.change_tariff DROP CONSTRAINT change_tariff_new_tariff_id_fkey;
       public          postgres    false    222    3211    214            �           2606    65723 +   change_tariff change_tariff_user_phone_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.change_tariff
    ADD CONSTRAINT change_tariff_user_phone_fkey FOREIGN KEY (user_phone) REFERENCES public.phone(user_phone);
 U   ALTER TABLE ONLY public.change_tariff DROP CONSTRAINT change_tariff_user_phone_fkey;
       public          postgres    false    222    3213    215            �           2606    65703 &   credential credentials_user_phone_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.credential
    ADD CONSTRAINT credentials_user_phone_fkey FOREIGN KEY (user_phone) REFERENCES public.phone(user_phone);
 P   ALTER TABLE ONLY public.credential DROP CONSTRAINT credentials_user_phone_fkey;
       public          postgres    false    220    215    3213            �           2606    65693    payment payment_user_phone_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.payment
    ADD CONSTRAINT payment_user_phone_fkey FOREIGN KEY (user_phone) REFERENCES public.phone(user_phone);
 I   ALTER TABLE ONLY public.payment DROP CONSTRAINT payment_user_phone_fkey;
       public          postgres    false    219    3213    215            6      x��]��M����]��$7�	��(h�ᶨ���{�y�ޓ����,���79IN���/��_���_����O������������_����?�������?��~����������~�����?}16�e��ӟ���_���~����?�˿��/�O6�s,S�䜮w*��O��<~&M�5�f]|��~r��K%��Ω�;�s���忠�M�������O��a���w��	�?���u��;��F�k��~>�y���胓a}�w�N<�џgw��8�'�8m5����L�W����t����]�𶫏uȁ�}L��3ND����B�\9*���<n�܇̢����(=*����K�x�n�[�)1=��v�(�u�#N��eY�M=���2|���:&+��h��㞘�'��q��CP�?9_!Æ>�f��{���3N\.��Խ��=}mu�l\�x��Z��p�Ƴ�g#�ڞ�#��3�Y)r_�-�c��\�_�[~�":�!I�p8P���G~�pT�����8p��-�ΙA(��7��!B_{�X7��t��}��4�p�/X ����)�o8N�1
�k�>���v�ɿ3�	���xc
�O#��1�%;�,T��� �,�}$T�q�|}��`����{�������k���w��)ɟ\��l�F����O&�ݑ�	���E�9;����w<���y�g��1|����-CMj#w��ȅ#ry=�~}��啙mT�݉c���H�H)xk=�ɺ���G�>�Y����E���:�� ���-���<"��y��)�bq�R���\�[���nc� �F��G���g�t�����ǧ��P_����:��:���g#���&�,���}!�j+}�*sQ��g@���P����&��6�憾����'��<�c�^|�,���[~Sn�T����F���k��9�n|E[>�;h7�ꍾDWV�����=��^?OAц|��7q��(ׁ6�P�7Pd�,У�H�P_���^uز�甏[���o�
�갅��ůw;�On�(�]����.g6�?9� ���Qi��=�M�{:Ç��!Bg,��B��\�	�����hw���O���B�Gx6=b����c�$�1�Sd���2Gqu �S�(�����y�_�\}��x����u�� ��M�D~%�1}�sD$����kxQf�_Wu��q����v���3�9;8�ZS�E/>���*I���-�E�6��g�V�ҡ<� Ns#C�9i�3v���������>>�M3>=�;=�h�����8z��<����~c��6?7�O..����ԣQ��� ��?jM��~"�,Q�/��HfF�d��X�s}Ն㱂ی�+�_�e��s�ɃK�g\_�%�q��y���-��l�{�����`���Uf��y�I��w���\�&^�������=3e
~ć|��?7��w0��%��N�i�������uc��T�[���!���<�|����ϸy��c���NN��H�|d�2}Նj�$ȅk�q��C��>���1�F�G��?�R˅ݥ�P�d.��+�[$�>^z��@}� _��hy�g?�XF���"'x��9��.��-t!��-�L�ְ,���PV�U2��#�W?k��uL���ˋ�}�1� ���ψdIJ��l��v�r�7_�#za���7�\����^���Qs�׆ƂE�������w��/���|�������n}��t��s�8����t �$e2�S�9�����8�C�(}g��2@�\��E�B==���gq�X�l���"�-���n�g�!�O�~���Ä��7a�P�O�r��=�Ģ�l�h��Ѝǹ;[QAv<��7`��L/(�Ö��c���ͽ�E�l~Hw�͒l��ͮ	����	d��`�9��_������:������\��x�;PZ�>��/���� 3>l��fT��:���2N��~o�� W��-=K���	�j+�]}ǕT�$Y�LӸ�������˸~АO�����o�Q=�e��Q�X�h��$����e�)��Y!�������j$Ie���)�uY�G���(�Gܲ��eo��г����n�ߣ���+�H��S|6��C���ϭ&�YrX��w�p�����:�]gA���RD:}��O�4�P�kj�=F2���t�l��}�ϻ��j\���7��n�5����W�7��1I�a#Y^���c���¦�j��]!��8TY�OI/zY����8�ֻ���%~^�<&5���(p��gc�ZC3z�հ�����ݷyQ �'��IE��ޗ�������������_CR�w��^xA�>Qt]�3�;��(U���K����3���HF��V(S�;h��Oq����@M���gN�0�Ƥ�qT��9����̐��z�>���OK@zU7�M���d�Hٔ��s%WG�q(����vg������.�~��z���݂F�d��&pyӜE�rϻ�n-��o�􋾏4�ΐɨ����۔�fnǂ�-~A�,,h�T�����@�du�{�T�������4ugO�	���®G��|,����_�>b@�x���(c�︢������@6��k�mx�轴�}�h�v��T�U���܎���	l���ԍ9�N��to��b:�p0?j=���r5_p�@�:����&e�T��g�\O�˟J���1�sӝE�%~�~��p���h�g)ӅĐg6@)��'��$�@<�:��n�v�E���/d�`��w��?����nn��ӥ�ڐ[k�����9��h�#�G�Ŕ�:����Xp�@����F�E��I:���<wJ�4�[`gQ�ya�I�Kj�/h�q��@�S"#�c =��pca+�y��;�<z
����Y��a<��:V?����/(��xw��b��}��E�����g�SӉ����TU��Ղ>4~�fu.����;�jʣ���������GTW���h�}�f⻗�t}Ow��M��c'r��p�o.hTm�Ȃ�<���[p(K{3F]�M�AU���u(O���R.#�<}/�n5 c�o���J��
u�8+yDB!qG�J�e�J��wf�F=��� h��P���.(�L�wI�2y|���e��|�,z�Y�Yd���H6�v���K���8���\ M_P����n<1]����b,�]��:F��-8���	n���F �e,8�ю��[�
�����9����N֘��.`�H:m��u�Y�u��紾�j^Z��MK��\�����)�װ(1��Ѽ�Ι��jz-�;�T�������J�G��K|W\����/�=����:�Z�γt�G*�P�8���6z_�9B��'�c�W:�ދ
K7^����y
��P m� ���%�or
�o��Bĥ���-t/���V��H�݅p��>�ȰY�&3J�����}O�����A1F������� ���#iR��{yܽ��_�ܣG��u���ݥ9A;?�o�&������Q|,(�7)��Ww���t=�;ۗPT��y3����$)s�P�ɕ��k_�)�r�ܧw�*���5��ѱ�\=CҼ礖�A�X�*r�����\����n��9?�q=� �̍�jz�!-��-l��΃ۢ��^��N����6�4/lr!��,�� ����us^�9z����?��\�����p�����D���<�RӴV��g�M���F%%����4����)��~?�{Ҷ����z0���[uՋZ�k������b�����9��E߱�
��T��̑S(T��hå�ѳg'�����x)E�f礖��� ;"ǂ.�<�d�u��䱷����n���,2ʎ^��*��\=~�V��/���b���M��O!I��NE��gy^m�O�������Ca� ���E}%���*��8�_�kC�8k���MO[3}����=y�jQ��v���z��3���u>Ʌ.���ׂN B��\p���>�O����K��TP]�����m&Y=/�Q �  z�g�t� �eAg��gnG?I�����e���ZP�ovM���w�����@^�\͂�/P�%3W�5f\��I�*=ǁ�H߂�4��la�+�C���^�g4�G_�I-�]➠����Y��B�J,l�E�Y�T.��s���BE��J�.t�Ogxm�go�A=�wʑ�2�0�����ud\
nh�2�.Lx�b��/��ަ�B�@Zq��a��G?�*���<x�z��?�\��z醏X�Wp��ˠ�ɔ��W�1g������%�}����X�S��Am�q6�ґK��0�c��\n�u�{"�Go������_�綦���8nz+ �ρc���Y���D"���¬�+���������8��wa���e/)���"�-����~n���dQca�J����h�o	�黗T��*�?������j�A�Bυ��쩫�H�8�X��׽���#W&����n ����>����5���b���w��X��Ǻ�χ|���*��W�#s<�䉅�t�y��Q�@�E��` j�u餉��ȑ�Y�^_�j��p��O���u���ҷ>w�PJL�7�$�֣�����~��Ks���5�^p%��d4WI�1�H�,(�2hX/�� OQoa���R�YP�6���/��Q/��]��4~=�~m9�[.�Bܠ�`.�u'b��}2HD]PP!{�ς(nwM-(����?CE�r�=P}_��+����fo�����5'�e��ѥ��-�M�zA/�W�m��|^��Y�(� ?�7�j���[p��:|��W0�V��O]~c�ZP#������kA����H�Wϯk�(��Ԃ������x�R�G_,�O�0J?;���p� ��#�1���l|=���߳�ϔ�1@;}E���0w��C�X�O0���zǐy1d�/�Rgo��U������a�ޤ�んE�~O�ԣ� �Ă�#=��1za���ۆ�ܻ��O?��E9�3��F�	j���M���?%�S��U�K����
�!�̵0�=�Vw�'Å��^~t�� �U��EQ�g���q��T�4���:��G�y�=N�i}EqPy��w{̼)���"������}{�-�%�
�C�u��~7NsZg�w�跇X�G����~���h�p=��Xg���WǗJ�������E�c~`T����"����od���� :��1��ş�J�+ �옾Xnwa��ˁ\\]�Nk���p�~\���p��+������O�?6����A�s|Ħ����B#e��Z��^S<K�̧�_���&7�~�_�v��`�? �sl���O����PQ��-d+�����[�ϳ��38p9O�D?���b��3~�Oc��~FϽ���w����nC�j�A,�x㺗U��g�˸^K��+��g�D�]pf�����>�<���Q轡�P!�yQ���bp��?��p��/p���q���P���=>�9\�}�U���ԃ~N��)���}���@�r�Xń�A���i�Zn�u/�P��s�U[�}y�w��ػ\DПj�_�AlC��ȷ��uh8�W7����.ԃW��y0ƍB���Ҥ>SZ� lp4��7)��Gy�Q�K�� ���w��Rz⑵���j�K�ׂvV9v��<�@�l��jT������j>7���
�l�X��[�$���Q������bC��ٵs��A���+z�)�秏�ۏ�:�F�a{��}Q�
(N��s��pS��K'��:���v�W[nt�,�̂#*n2��}���R�/��M�}�<��';݂�����{������Z`,p7W��xon��c��,zO ���kg�ĐC��}p��|�:�,��N������d ;GZςs�*7�L��KSq�:'4*�b�~�8��Q�=�dզ���P_gA�Ał�9�υo��.É&�L~���oA��[,�6�3:���Xtځ���t-�߄���Y��7�QM ��sU��T@c⢦�6�9S�B�؋����S�1 Fɭ�OĐ��r���j��ջe=<�B��䞌�(?�t)�O��~@~���bS���zU��(�˙U����l��6}��9Yt�~�����N�72�G�g�_WC2K}�Y��ҮW�(�o�[�&x�>i�|��~��S�z0I�٦��h,lry1"��{�fg����6U5���H}�e�����͗{x��!���7��������>�Ɛ��^Q������������&�г:�%_����uN�~v��}�o�Ap�-\���4�����1]��-�:��|NS�J7��K�3�-���I����3pP��1���i�p,lEݺE�6�lb���s�_7�����'��X��A^�E���� P�W�@t�sǓ���K��9��}���A�-d�p @��AZ�9O��s���/�c���J��
�R˃ ��a���������G�oS޲�WԂI}B58�f�x�^3$��:sz�tԙ@_
�q����I�^e��J�"f�#ia�-����_��6���W��x] ��G�> �����HZ`u2Α���FŹ�j��T@��
�d�o`ѹ�4��o��w�M_���鮅=����PS���z��r�LT�w�j�ۂ7eE�c��P��&��q��Bm|h5��H���T�����1~:Tz���t���s��@��oEY5I��;s$֔��c���Ԝ�'s�������\>^Pi�ou\�����0���
�`��3g����ː���*�$U�ͫ�?w�p�a��%Wbq>z�������l0c��H�!��ң/�����u/^����9A�˶�� )�m����S���W��5z��l#Ѻt����?��Z�}�����ȅ�G2~�Y��8^���K�f��D�����L\z�E��H�\}5Axt(`*��.U�\ը$�Ze���>�̅�C�߳�⚔U�o�SE�۩��&�B��ei�)Uoa�����?MDQd���!�f�_>#����EE������B�ؾ����?*�~G���=s��ѽ~�����ŉ���-��˥�ڝ��#gn�~s���6:��F��-�
ȱ�O�Q�W2 ��^p���ݦI�K��,��Ά�2�rAcᱷ�o��\�dU��9m�_��4�6t�Rv���qz�x��� �ˎ�~�d��|R���L7Ԭ��������_�����O���t      0   
   x���          5   
   x���          3      x��}Ǯ$K�徾�-
x�@�ڴ��Bk�7����&�"�C�M��twyHV�I�������:?����߳�b�8�7����z���{^�������n��u����t�_����A��/$���Vz��Ϊ������]Z��������G���A\x�<�Z�A�\:/�w��$흱�hc�t&5����8�K��`^s<��d߭ʫI����F�;�w���}J�,�9�yg��&�|��{��8J1�7އG�6�ˣ_L�C����RY�g�F�O}\�r���{-���v��q�lUmEq�4Bz��a����/�IB����)�'�D�=j���Z�,7`��[d��nĩHr3^*�Up�U=�%���t��\/��1�E�����+P�c�N+����=}�ڴy 1@����S�_�^Ӟ�C�#q�I+��7k�i&�m�V��I�]@p4\�p�?��9Ѿ���*ɣI���_XV��+�/5�$����w`xV��z�1�+�>>�v���n�S�$�X%����	���+�$����R;��c����ؒ|&�LJo�he���u#yw�@��p���D��ohf�a�r�߽ȇz����@���B,���>\�'��+x��&XC�2��N�l:%5X<�O[���~7h@ W�������Ag$��;o��`�|R\��tA�_�3
l�������q�,v$ޜkõW:&;ci�rw�4�	��2�px�2X���d��O^ r�	�pR�6�F[[��I���tjj�t�;�I]Yp�!1�^�����G� %�5�`d��)볖Ֆ�ki�Wʰx��פ9R�ڛ$�p�vc�m�_��dHl���k�B
��h|!)Xx��{;/��'��E���;�7�nnj��݋$Ef�v��Vr�-MV���������$�V(���pN����@�]�pm%�!T���v�R�D� �,�$9��Nrt����Ӻz��=M6�8��*��Mw�i.�iwMb�F
�����3��w�^�A`�]�V��������Zb�a�����4��$� (�m�^Y�l�N�ӄ�Zy��`ٺ$����
�S�ih	:?wնm�w$Va E�������똣q�L�p�B��_9[�h��F˵;[��m%_#y�^{�M��Xk��!M��T���z���A{W'0�@����h�[31$�s�E9�b=$��;�&c�b�K��$�h.���-�.�kL��:��KG��%��=�R��4��@sTV+^����{I�4�m-��Hwf�ˑ$���v8o��R1_Z����*0����ج��l�F$�oi>���pZ��?�A���y�,Vd�(�����,C��Գ��+Ob�aIp�1�_*W��Ӄ��u0Cc�3��ݷq{G���*���u!�\TH��1xy�`�SK���uIb�\9 ?��nT��i�i !� ���Y��=u��%�x�B��љD������;k�p��s�c�g�ֈ��vN����q����๓���p�h�̽���������E����ӭ')�:�0;�b������Y@�������um�CR*�n ������6��B��Iz�� ���Er�bX<���I�	b�������j��<���\�`ߟ����t��(�5��1%e�{n���u�9��$$%��o�k���>�orV@l�wl�.�î�!gq�D[���Vih8�	o8�<�x�ߒJ�H��X�Ќ�ه�]�H���8�~�6�;�����W��iIV����jP<�W4�X`�
7�Ҟl��J-�)M�k��� �׻����l��:���\5r��ya_�6Iʃ�:��p<k�2�Ǧ��h�vBYj$�S=;�7�M�ñ�d�q���Ѵ���!�Ƚ[+d�j�Hp�a�3����
�T����$mG�I���{��������qX�ǃ��E�̗����uk�t`�&Rb��SA\ipg[��V�^�K����p!%�Y���f����[���>��g����hZ	�+$7.�޽8O{�uH�l� 䅰[�s%�^�������߅r��]�$6]08��h��,��vҘ�H�r�y�X�j�ll�H{���-2��<T_���<�Ԑ����X2-1���<����G�U.�J��D��]�X�嶫����I���n'y��/I^�V`��p���+闤k�0fVE;�<ޭ�uA��,�$!��:	VG�+���e�r�4$Ѕ+�Vn����U.I.$dy���}`�ܳ�����$�3�!Vi��9�iۚI����W�ET�=n.I��f�̏��L��1I-Z1(]	���?s���4w�m ���T�5s��@,���c6p�4�����w/���+���5���+�`y�2�8h�c���{a�\W]��,��4�����oI�L�z�@�}�^^����I�֥A2��p�򬛈��2p��T��箪����J0		7"�R����?�2M%��qn�ݨ-x��3$J�BM�Zn�o�n2�w���up���ؔ�O۷ �V��%���z�����.I���,ެ�0����f�B�݅��8�U9�Z4�Dle2�Vq�v2|���$��v���9�E�����*/-���dR2�r�J9�U ����~��m�-AVo��q=��vJu�o��ۀ,��)�h��0�ΩwQ��A��\E$��������)\�H*�gO�R�g$�%�2p��!�\.��b�$�	
�5�6���\�4�6�Zh"1Di��{������t��>.m�$�hht�H�-�i�/�N�p��I�F>�`J��֋�+���U�
ab���Y���aJ9��U.D����$�hK/�� �TiONK�^cW&������.���-�9����}Ĝ�尹���4���Xl���+��kZk�D�c^���{#_�;	hw�#��qz(��۔��
�Ih��
����v�4��[�qoY�N$ϣ��H#�p�����$�K�,�矐šR+|&K�AI�S�XT���2���'���î�1>�H����gH����q�m�H-�+[�	��:��7<����̠�:G�	wx�~�~�� CC*7�)����mFz��$iaB��a!Ї���,�Ozl�hZ�!��..y����r��*{�TFE������ �X��a���~��k�H>���=�Q|��L䞆��!'E���LY�m��{�E��8�����$SH��9�X�>�󗨏hdƼ�Bsӏ:�ԇӍ.H���������֭di�6,�&!���,�)}4���R��<�BgnK���C�����[���]����;�F ��}7�%�k�"�a"#������+6�V� oHbc�p��t}�dvF�%��kW��z���g$#y�h���f{�/��/'�LṼCV~x�֤���$U>cp�b�s��O�� q�X�D������M�$�2˙A���w[�o�@�uBc�;$o��1���'8��}=e���NS�3�"���[��Łm�Djz��E�֖.�V�dH�Cje �Eվ����L���)�HA.�=	��Q����U{�I�7����$xOuZ��꘶ ' q�~��F4Zu2��5#����>�4�m������_��˓�׳,?����i��5�J
���W��'͐�a���w�rg�J�J���D@aB�M^8.~�y&ǹ�LG{�5���|��i��`�:��ź��1�M`o����K��5�^�H�R Ex�bt*���V��(!��JR�F��xP̑~(�0��b9��6�[ٕI*���e���b��v���9]��}�[ܺ�Y?��\��"�2RD�l�+[|�V���{aIg�qͺ"i)"���"��MJB��k-v=�]l*�M^uA2ۇ�!�+�b?�Zw��$o���Aj�D��5��G�30>j�#Ն�n����5I��Y��R.����&�\Hb	8\#��QAe��̹9��I0�e<�Tq���h����Dd�z�1�~.cs�IZ}�R����=��ٙ�W��+��K����Q�$�0y��o�����I    �Q�t����5����/�'1wY��Ϻ���w��d���oc��Y�_����qA�n�
c����[�N��yO3��]�(ܭ���̝�A[0�ؤM۵�nէ�o;�5�8p�w}ޕ�$Z�% ���u6nN��������k]��3�\�:'�C{�M0���m΅���/]e� ��{[<]�it��tF��k!���瞘�������#),H���_�H��䮥���.s=$!%��߬-����:4�
��$�h��c�$9������xN���k�4O�i���ܥS�����Z�~�2Vk���
�ag������k�e��s��Cb�y�$	8d�(��b��~8oN�j�f)���I�2!j,+���m�̽������Wb�L�}?e�.PӋ�^1��3���f^4��ric�$�z�F�rG�H$R�K:HH��^*,����U����$gp��k_ĳLž�m�#z.��f&����%�4��X���o�\�Z$�1:�P���{C�I`&�L!�1	>���9	� ����\1���n�\�i�`' hFW��\�4S-�3㴉ӥ��Z�-�>?��BƱ��d�o���ocG�iF�-�y�*�7�ֳ�)��QB�G�nQ��G����"Du�#/�'�m��3�%��q�[l�W��47�t*5�)q�8��w�%�?��]u�IJ�~=Fb��~=�2�Q-~Iʜ7N9��-+�W�m��߈��걞z�J�����>�ܒi.���1�uZ5K��K�Pz�Ed�>O�$������^��+�$��5�倠��盧q���Qg�y�6�Zo�}mI�:�1 �JG]y5S�g����C��*�?=O+���$�M�G)�8� .���.��v#5f�.�g�>�]�J#��Whq�ݪf��$ӄ�+���q���e�KcBR^7����K�UK�|��p�Qc	7��D�g����\Y;%I�"�(��-����L{�0��������|\k$tJ��(�O�ksK
$�
�HFT�BV[<�e�`%O�4ӣ��q��Z~�*��x]əF�cd3m��R"��)�~��8��^����5N$�X{�Q]1V��'6WY�[h�9VG�o��X���U�F�Y9/�g�b��NLv�$J&�x�_Z����F$���5�T�-
�OaМ�Ie�������7m�O�T�A~���6��ۊ䡰E�#��n=��kLR_���� J�ŝs�t�z����̘�jA(g��m���.	�'x 1q�j�o�m�)!�h\�s�d��҈�
dGC�y���iv�8T6�6?���/�����g�W�q	�ۆ��;43�a!�<J�>��ܢ��H��fBsiw���e�Nip$-�`�kNE,�&U�L�eA9xZ�P 1\��u������dpqQ��GǴ��'��d!���<?:��vwY�H�('��q���+V��)~Xh�}��v��͡^8 ����������1�?�Zbq�Ş���R����H����x���C�3y_��)ȬV��?|��1������xp�v���Z�ЈD{n��<�e:����2F�O4�ev�wU����d\��iO��q�I�$�Q�m���XٯR�*��K�!����7���}�կ�W��[d�_wN����}r�#WEa��&�~]?[w:4 �uv������X�v4W���&i�ۮ*���:����6lX�f�v�~�:��H#<á�Xت��~�$ <!QV�0���/I��ɜ��6���.�M�N
����nW�٣%	^Xw���)�_~�Z�xC�]�[��ǚ��6�ei&�p��D���z�l5��	��u�\[$��m��DCC RSN��Cqu����v�=�R�L����$�y�Jz�Ү��MaH�tV�[�Q���[�)MA;�E���z�a��fC�@C��8X^��Mz.���K�Nս����/�G/O!�3���sa�S�d�$�im^��؇s��gO��uiA�N#l�\��17�U4�����;�givJw��.G�t��	,�|,�G����*�ۊco)-����ik�A���buN>i��jL�1F\Lg��r1��6���	<_��l|��^ ��s�]/��gn�i+	������*CG�w�����v֢�ΐ�@�O
�#�NN�B�)��������%;�~�����X�x���xR.�i�0j�yr&r�ݒf�c�#Xo���l>����g44v�8do"��ּt���=�� �\\ob���*���߿�'��$���b�vgQ��C�G�_��v�}�dZ$���eg%���H��!��1�x�A���9$!<ʰ�.V\&sz4Ò^J���x�Ig;��B�O��P�ڸ�X��u��s�A�P�`Y����FuiF����q�y�9M��%�)��7�j^����S���U(/�2w�ɱك���-qc��X��$�Æ&n��R����[���K"r��Ri,���T��Z�V���X�s�cm��0-8u���ikTy���b�d�`&�%�#-g{�jy�!�U��� �!�I��v��%	`G�^$�����O��u�(H"	�:�a?����dTIh��:~c^�9_�.��EǄG����u�:�ш%0��|$A���5�gI4�<�[���v�o���!���؇���U�>E�������ZW,��l嗲C���Y��0k���v9+�s��P���b��ʴg�2I�c$�L�Wz^��ٲDr�$3����L����Y^-���HT���eNS�V���ȃ���Y,}J�䬹����uZ�Cw�I�-�N%S,:�崨��m���r��U:*�\f��a��$�} ���aξnuQ\Ь�S�Az�~�z���;����+�%QMh���I���̄������B���EA$��d?�맞I>JXz����	M�b�� ;h��vW�-�z��p6�U�L;$�@\�ǽ��(y��nR]k��G(P�������	)���C��v�.KY;m�ֺ؁�m�&?�Hz�(���Qs�ۘ/+�1�xП���w��ͺLdy�I��Z�0ﻔ�#N�����>��n%i����.�����{ۑ�V�f�/F\�~,�U��8�os(�4�e�O�۳t��nC�-x`�(%΂W�����;L��I�%�e��-��d0����F�`<����	Q�X�#E8�-���n���+��$�>�M|�S�[n��$t@#�Sl�,JYM*��ߤ�s����h}~�HB=�%c?�rόO��&4C�(^e�ϻ�\�\)}���f�E@�d��z�k9�HR射 �5�t�,^�ꐓ�]���J�VHˋ�h��TR97���5�ys��~�|E2� �T
O�����!�s��}�����~u[=I�n��s����x��uI���c�a����6H����|��ͼ����i�e�'�OaPD-�BXY��ܒ5	Y�9�R`6^��)_��L�;%q��x��LU?S��I����������Iڃ%@����F7["A����70���A�X�ip����}��M�L���x����n��'�$Gn5k����K�52� ��mά�W�Մ&o���8-�N��{5.$�N#F@��|ԩV���ь�+�C��Ν�ybiv.{�*��+�M������Y�lT��]�E�͗��&3 �d��G�����U$8
��6\FG;��g{����q�1�����_�����-������:�NH���a�ĵ���S�'q������r��k���m��2���m��{ޱg��� (�(jv.V�ōF�1!�������^�Md���eA����M���z4���@�� �pz�4ؼ/4�T&�Q�&��]g�_��yO�+4�T�����$�O�>��'�u�BH���X$��I�f#�t8���
�����O�)ܺ$i0J�{gl�(=��ۏ^��V>$�	�c
S����L_�89��E��ڨ�kZ):�BI� 7GrT��34ҩ>�˃�_������q���p�)�"KJ5��6�����c�Oux�H�hznq�%Sq�ne���mW�i@F)��    Sͮ8#���▊���$=T�)_i���>��X���r��IH� �@(���jv{N9�CIa�(���R?�~-&"T�W#?�4S����I.>4�Ϋ4���쥴Q꩑v��*����P��g�Ú�ˁ�t�d�c^=�L�$���q\?����⶘1�x��^�ߨ�2�onfI��A����`��;l���N����=��0�`��3���q�aZHx�B���E�^����.�Q��#���_M��t�2]d8n��E�3��,��Z0�~�\sv��!qvv����c>���'$�z\y�}4�ùs�v7�YF�`���ő�?����rK���*�������o�5Ƀy��q���K�cy0�)��A����7'ћ�4D��5:b�ҟ-[Z;�h�a�3�J�@��*�����[���A�W�7`���������ӔҔ�R��r�>����e��L�F*�X��n�43��Ќ�*l�X�#�N2:���?M��\�?��8��$��
�2Jd�@�*ů�2�I��A����|�k�G�KߤI$%~,�#'��찚�goI���N;)��r�^��I}��)�A,�(]��5��&�S��!)?)췣�K�c6h|�ɿW$�y�4ϸ��(ln��g�$��p7 �i�5V�}0�4 )�;�c��6�s���Y���,��3�רz��4�ɍ�8�uK�:d$,Ed������|3�#��J7�Cjlbs����-�ވ ~��ul-3�L��*pk
������Z�|H�J�:&)G]�eʯ#���Ė1�>�D�;�.Ă$'�(p*%G���=ɐ7�8��QQ�eP|�K��;��'.uG�V�.��c&��\^i��Q��n��L����#w�c�!��Inx]�N$�q\��Y��T:��څ��8��5��̗�ӌ�Y�\3�dqZ�=~#�a��u���#�7����H���D	�C}�ث��I�/� 62�eL��j�A"�ÝwLh�Yw�s��D��( Θ���Y:��>���T�D4�|$�N��+9l9D0xХ\�f�F��2B���j���p")e��U�\�Ja���@B�P(�-8�4�C�4�_R��P��{%�ҏ;��=��'	cW��c����j�P��Z$��aIR�J�п��N�O��:h4h���+�5iFD�� N����YD�"�
�|���K��F�I�K��S�{�M���yC� "e�D.�����I9�+�) _�b�^���[��t�4�a##xuu��fl�3���_��=�4F�KmA2��p)"�fE�v{�}^H���!'M�V+%��`Ij弔J�!h;[HE�t�a�Bs}���� �=*������y!�&�Sm��h!�%�	IS'�9��t�)=t�+��+!6��Ĺ�/Op�i)L�Ѽ�{���^�FEB�U�TѤ��e�#�����c#����#˒��4�_��p�G�^ۭs��T�-�r�O�P��h�g$a�`���a��en=O$��ǖ`8j�+1|��4�n��>y�[���#�;
xy�E��^��攤ڍ�U,Қ��m��I�ǭL�_�q(F�l���J���=.ު�}SH�$�2���%��Pj��F�}�$�M'r�XlM��E֗��%G3P�z��>X�x�u�#�,�؍7Q^����mZ+��8�.�o]�w4�<��ש1�Yg#q��1��v����I06�n��)�S��5M���V`�&6����v;Ѱ�!s��X�ݹ^clǚHJ�@����H��V5?O'�	��1)�}0�\�::�ҞF���[/��|��%	�?���>ק]����1!��w����F�tE�G��F�`���򛑟�h��  �����dzUJ��:z�Os�^:���~���a��mJ�k�$IP�;���Y�º�!y*ܗ����(T:�{�R/�x%�pedi��W�ID��
���wu-LYB��y�k�~ZnrY߯r�v��-�f�/¦�9��4�"��F=��)L����TA��C1�����-P�մbvu��v��fzm"�p�c������r��O��vO��]�bR*d'^� w�km�Q�ގ�TN��x����"Y@�8����I�w�0�����h7�"�h�8����>��{�N/�Y)Hyp�tD1���=ސܮ���E��y5K\�bG��9�|�`�L��Q�F^���o_���=�n:����u��~q� �J5Rq0�8h�`�ac�~���h$�LF�I�Qn�/O�)i8�:�I'�$I�M��g1	Q�	�����`{����~��ަ=v�Q��H��"a?��\�/���.���6a�>��n��<�Yͥ��x���Ro�$i��AM�1-ޟ)��Iz
�5E�t�_��Ά���pwE���X�x���6� ��E�f�zП��9Q�_��˄��ˈ�5b�x0��$�<I�Āk2�b	��K����9�![h�G{��-2�=#�u�Q�@��"����!�����q�b|��𽮿wQ����R�?�T�<0��n_nhH�*p�~�f\ϴԄ�S�%[�+����o���A��0VCt�M�>��ط�]}NRJpa��*|���N����H�oh��9����Yk��ٮޡ��Qҡ�[䬜j�q�s��qj^y)����8�$�@'��8���J��.�zR�Cy�y����cs9��Bpf�����]�ڕ�:Fb�!L�J��J��eh�C�7y�C	E��p�$�Jx ���w��kƑ��s�qQ
j#��JyHCV��= В�w�=���	�\ \�Tq�P:Z��_!�TG	+J;Վ��I���)�����C�Hl(�,�+��l/GR�H�"R:�ڟ�Mu](�5G�;���7����k6����u��������fg���hͣ������lv��dܟK2�}���F�-�:��OӼ�)&��7��&$#�0;����e�w�
���9$!��T�w�iԶv���@ȃ-sބo��J���N���bq5U��J�8�=� �(��#��Onr�Λb�f�ל�����ɲgw��E�L��U��c|��[�-�I�a� C�1笕?>h��\K���b����!ih�E[������z=}��®���>���?Ԓ��nq2 {x�\���$%o	�X3�t�1�m�=��aI��'�*�F��Zs>��컄�{�\܎{����e��;ӌ�[�q�0"��Z�i��h�N�()T���o�|?^ٲ'!#�gw8��۲����P��z	�4n]���Qa}?�����H�Pްحe��m.4�P2���G�B7.C���!�Ơ���7F�^�J�HZH��x�+*9�E�_$w%H�[�؃Ζv��IRaRw!0��f�?(���p����/5k�ͶG��	��vu�b�`��	Z�Aƚ�ؽ/?.�zq��4��pL�'5)��4-H��(T�rϑ3�ϲ��&GRJE!z��u�iv�VR����'��G��L���6�ImF2��!�;��/��9�g��X�_��-dW�{uP����^����#��Q�+R��v[,�{���;�8�]��~�$7-Ҙ";u�/s�P$�o���rŊV����2Dx�K�m,����p{N*��ɅC��ȷ�\a�,�Hl���H���nNB�%�I�䮷���$	ָ���ߺ�Ż�ٓ�(<�E.�O���*�`�Ɂ�1	^u��v��HB�5� R71�<m��<�$)���T��X[�DMZݲ���Z\S��W��rq%�v\ǡ!ϏE�I�S^�w�ɾ$�,�{�p�I�<���In�/��t��RF�޽���=����u8m��`6�Ά$b.8D��F��d}.�F�U&GS;�^0�~���o�_$� ;7�O�s�?��]6�!��	n"�l�δ����CC]��F��պw;�~ΧWB�C.'W�!�l�PZeI,>��t	v��?�dl�k���?��`�%�L�!i���T�_�hĘ�_����2�\��hb~���1�6�oe�>rB�(�z�R~bt�y��m��o�]�Nz�Ҍź��XI�+���]X�*t����(mb- �f&^݄�    �	%��dǥ��$�/��u�����!�)	��-0
��U�N��+��뱠�i��c�x�ٲ�?�H.ZH��׳�>�#���eZ���Ԋ�ho��+͢Wnu`c�P߫ܖ�m��*�P��y!Y8�!?]�IutoUp��t�8�Iu�x0t�mU^�E�I"�9H������Z�ժC�wQ^8V(�I��=���7�����
.WHQߩ�o��5#I8�8����V���P�Ue���B���7�K򳶕�&��7�e���-��KRdRB!q_�Y^4jV�+��"��a#ǖf�QX��"���a�����'4�Ҝ5����������$���yҸ�Ӝ,v�k�h�A#���4�b��M��tE�G���q�l�Y�r~�Hb1��4�M:������\d����2�����MH��wR
ܪޟ���u QC�.�ԯ�$��0 �����F��z>���M,��R�f�N��X���I%������\�6)��Lp��ݥ�E��$sK.]��1`8��I/!aWm$$�*� ��*s^tZ$�rR�ӑS븳m,h�4��<2�����-��Z��VL���|�,��N�	��{���R�{i����|#�,;ƭ�9��`l��-?��H�
�`���iw��6Ν�b<��:�w�����Du�7R[�^v�~������r8Z���[�'�N��+N�W�on������*�}�t9=��F�Ǯp�U0���ݸ��$�O8 ��0<����\z�� �%N+���Af�I�����i%,
;�hL�ri=���.���E�J��~�פG2D�7�׊�����-��4#��q��%W��Y��{4���l�x��mw�W���Y��^�u:�]s���W�.�p��X���F��ʦG"/��"ca5����;�\+4_p? 8����J�!�&B ��vC�'�WN߶�d��	�Z�6��c�kګ� ��ꭌ�������2�8;�c��t:ދ4��!�(!x,dew��)#��(��!�c�e�̈��6���8��Xi��M��-���:j��^��ѝ�����"�)E5�Mẜ�H���!����錪��jO�c4S
W�FĴ9�lV*�Ppt�쑶<��+�[kΔ�q����]�J�F�M� θ��?Fv1YҰ����{cK��G�ּ0#IT-
������Λ�0ۡQ��ҡ�Y����h"�`�P;�ӟ�¦�%!YxTܑ�����I�7H����T�+z�ɵ����GfmoӤ6�l<�����V����y�hl�ze�������i3�	� �e���>W*��� ҥ
���۸]�#0H�8b7կjb�"�<� ���%�xP{��ez�0�҅w����{��L̂��m��)���,z�o�KSO�|�I�+n�I2��D�GJ�:�t��C��p>�ɢ����
V^4JF��#�۳	f�3��� �k������qk&bO������*4=$�EL�ûr��i6�@�T��7���U5'qE8`e�S�V�����9��)I��	i�!g�6��{H/�p��i���v]��|)ゎ
��N�����Ii����pse��<6�ٶH�;8�- �Ɣ�^��mw=$����.;X��L#Q��f.3~��mz�Ѩ�B
X��԰2�/�"G����4�;^L��7�4?/���G=�q+[����)�ja"�Z-�|~�cM���g��-�mgO{$i����u�I��p?.mDc�!!�"�F��CrwQ�\V����!Cv�\լ�Th%�
�"v~^MM��$TJ�\T-k����}6Z%F�,�;p=�ҽ��Ɲ��a$-1WsG���ۧ,��=�9�G���g�G���l��?�5�����i£¦���Ш/�zg���j��㱊p(�؜MI�Y�i	_�ã����$�>p��[��t�����Vx��OGh�օ�U��*_�~?�̗��c��XF�e�J7i-H�X���ǩ�7׽�tZ�ѬF6���19��gϘ�b4��4ҹV��:6���gh�c�K�H�Jj) ����j����vVB�1�ˌ�Ji�s� �2j���5��l��!�8g^��nN=
�{�)������r�qF�]�h�WRG�t�fV�v_4�Kt�
"c�>�߷��f�'#1)�掚�x��گt�C��It�L�B'oQӯ&�.T2u^�ⷹ�8���y�/p�����<]�7E�>��ő������$�,	�I�d���p�����Ic/�K�)�U��]�!I�g���"��?5�t�$��h!cZDV�|��V�g�E����
M�ie�j���� �xX�1~�#[�i}Hb0��q�J��,��� �����⎗���~jiĐ��̡�qxy�F�N$��
>���b3؎v�R���5J\�[{v�܋j��(H�"?�6�s��6͓f���+��麕9�N}�I�.N�!0>�n^,�ɜ���Ie���'0S����x� �=Ü�Fz���޿4[�P���~3֋�~��TӀ�1"���s�W�t=���R��l�H�cѫЬGc��nԫ<�Ӻ�8+C#���Ȉ��#M_��]��	���&J�����|���5���WJ�i���|q3��#SY���d��Ԝ���5;n���d^0��绹��@tF���{_���ۼB"����(��	�ǐ���w�Fpyq,�y��n�"�5�� �.�F��	�pN�m��Qe5�����(�	�#��ޝ��	e��5�Wޒ��aI�EI� ���Do�9����Ku9�Ri8.\�K��3�v� hŒ;�z��8�GvOC�A�
���&�E�_�¢F��i���Q\�;�v���6��(a�8�2W��I<$t����χ�$%q� ��9�c?K��M�ϗ���#���X0�}���Qh��݅���e��H��c�AJG5����(�;�� �A���l�F�R��o� ��h��a�I��ԟ���՘wi6`��q�:�Һ����@�Jy�L�R�1��r�ٔ��䕁���uZY�̛���x̅'�]��h$�GbΙ�⧧s.7˓� ܣ/B6I(�_�n@S�U�C8����g�e�1�>m�78}>R������I*�������*Ou�/�ٞD��H	oP�((uX�NuQ]��T�!3҂�mٔEm5��3	���86.���dT��d�}P^�����HLP�@�o<+×���ݨ.,	[ �������&A�rz��]�/�l-˞�K�e��D	n=N»Q���]��(�s�PuQ�'���f�$�t�
{�b���}�i�3�CA��8^3�L)M�$��$����hT��h6SjHLq�1�R��/�3�<��2h=E����W��٦��9)�#,7N��B�� �C��,J�\���I�FhLzϼ�����[�����:@�m�?��g��Z��ʎ�]Ni�X|��'Q�t�{���n3�d_�[eC"�`4�ŀFx{q���\p��#�'������$��ȶ���9P%���j�Mh6ȡ,x\�t~ٿ�WS�<�Q
���M-n< �M�a&�V�_1��h����^ӻf&Y�D�l}���Jv�1�A��M��:N���	��h)��so��.�&	�������?/CCS�D��P��&--�-�
�5�۾?MF|�!ioKn5@
Q��x:kBӤ� ����qw=�^k�40qx"�s���&/�_Y+�� (�
�ay뗳$�<�\�d"x���I�d>��S"���ܴ�Nۍ]p�mn�����*`i��z�Ug@� �Q��Uo�x�h���*5���E��j$��7�ӽ֑˱�-��E����!g.�*��d�}e%��3T��#�p5�3��t0q�S�|��e��Q��
�)�v򖌳:V�Gu����IJ��c�����xv��e����&�(p~(����Ҟ��"�����[�O��A#�F�ә8ٮ8��J�f�����c4	��,�����U�L�YLEȾ���$%�)^�9G8}��#C2W˱C!+�{&~��x� �  Y%��I�3U_K�<�h% ����8���G�E��m�*�����=��G��F��_���+,��L[��v�Q3Z�8�|�A�@�?WZ�*-3�r�_���dǮ��{�\Ty:L��uY��"��(���~�̧4C((Li��L������n��-f2�\�k������[�49θ�U��/J��h`K��1A Ƴj��_F9����v�q�q���!!H\S�
�g�~~�I��R{�Si��g$�4[c����$�ycX,��CT� ���K���d4	�������T���U�Y���ΐrǙ��*3N�yHR��du�M=���yG�ڀ9 �(it>Gr����<d;�}�=��J5���׍i�3,���+b��"�'g�|�V,�Ϭ��ݲg�v��Z�r���Q6+��r����L����İ�6�F=�2������7:׆ǋjdX{q[������{�r)��B;s��%��鵽X�>�by�6���%�6�      2   
   x���          .      x�Ž�r�8�-���o��ٜmĕ��'ݕ�dj$M�u��!�PB�RE~�v�=?��S��ӕ�䐀�r��k}��r��ʾ|}��ޗ�����Oc`�{�B������-��ߣ?��}�oo���`�wl���-��C�9L������g�u����-o�3���쏫���}�a�����k����}��#w�նU����m�޳� υ����x���Ǖk��� /}�C�?��0��"z&������8�Ȯ��8������'�������2��Ρ˞�a���շ�J߯���C`/s:�a 9�m�5�'SO��ϛ����=�g���V�֔'zNS(����)}3�8�! ���n��MJ�_?��Ip��R�����^B�1P�$�wZ��Ĥې~d�Iy��n��#����G���F��&|2�ZՖȽ?���s ���mTˍ�y��N��#��W�����0�+�UI#C<��4��3�':F�QҘ���v��4�������4м�V8a�j���m�Gv��2H��3nUIx�1h_.�664�[�F�B�����@"��jG�k� 0i�l��a�����*)�Xn\Ӗ���0��e��I�7�p��xA����.��H���rٸ�o�2���=�q7����~%����خ�2B�To����6�����o�Y"�F��І��HijHz�aΉ��s?z*�0^�I������=�5Hos��$}>m�iږ;S���g�)c�M�� N�eEI>�a��9�&�
@�RL�r¿�0`�]��ꁬ��6 ���Ҙr�p�_v��J(B���*َ����Hޤ����?��FHr���B��F�w�Vo)xO�.^:��]m�vJ������8b�[��7�p�r�D��q�`J(��d�  �v�<�k��϶Ӷ��Z�␫F:�]��{�	#��ۘ���B.����o���
�H�($_�8 v�4�s�~c�j�j��R�)���X����8R�&�@��k 6]��} {$�� �ˊO�����S��NA��NT8p� S������%{(�'OS-/��#{�dp��ж޷�pÑ}{{�T��r�[�[k�	��kޝ�:��:'�6����q������)Qa��H��S�ҥ��]���DO�ē%���n�3��;�_6�c�iZ^�J�I�`���ث�$�R���R	UA�3��.Mὧiv)ZeS9ڗ�1���iC�}�n���� U�����Ls����5iO�{��@sɄm!)���1���?�[��c���!j%�a����3U6Ӝ7�CMR�'n�G��~����m�y��r�o ��#9� d��\�j��=��$��v�f��t��B�8��ܿϑ��䴃���vyGa1��#`�om%S�E��	x�R�=�x����N6�r� +�7��}�
��5��)��(�q��4������*�=U�#w���,q髟=��t���|9a�l�J����^�=$�+Ǎ,�𕾕�a8�q7�@�����m�d���>����2�$�Ռh[��m�og#����8;�gj�j(j]�ׇ0��n��
?�wָSP;(hqB�{"�����5 �����Ȋ��t���J�eH�}M����[#$$��c�p=����Bv�o�-��`-T�?|�=�q9�j����ؐ�E���b�j��qF�$�m������^�"G���Ӑ>��kp�s���[ �_�9�m�u�!���B!%�)�q�m���ĳ?�)��ԑn�ܷ�~m�A���_Ë�
�P� z�wTn�e�ߺK�"�ϦJ�p��l��b��ؤ9���J�4�!-��c8�3ԶO~���v\�m  ���;.;�l<]�_	c�S��b�z��=~�i!)���9q��|Gד 0bpB#�};�G���H�?�@k���
jo���/�)����\7��7�Ώ�	�q��D���GR��H^ ��<��~?�z\� ��߯�-߽���j�ա�\�'���	D��e����{�6����t&�7o��[�DN��R�k���������6�R�)��k�*[xI��DDs��Ym�����A���>�0P�n�@�T[ ��<{]��M��[�d�&_�4�Z��fYA���t���l*��k��p/�c����s�Z@�mJN��q�#��Ӵ��BV�X'��JV���!��rJ���(��J�!�k8 W0p灌_������:��\�)�1O]�3UU`��7J���eJ��x��ۜg��%�*���9�{Ϯ�����u�"5�q�DNp��*�VK!���S8���B�cV@�v�Qv>R�fN~�K���Ǩ5����0��;�X��vܴ����d�9%azKn��� �U�f��O�m��7�Lr�8ND��w�n�k�!�=B-��qUo��}�U�:��7�������#��3��'@a"u�R���D����L�8ͥ�5f_��8!�ц�����i�P^�C��)�x"�]� ���������ƢD�? TH ��$.<E�H��QjgZY�>�<�1,�.�i�d�;�M�j 8�ĝ�;;�}5a�51wy������qJ�T�$�m���'�=�yy��&�tix\q��m���P��Gw�L'�j�n0��<��GL_�p�v�����J{;�t��4��T/�i�����)��t�<�;²�+����.L�<��!��TӴ�ۄ��=9lB��G�4U����h�[9Gw��i��#z��kk�i���X��b%�ɕ<q68���t�#�C�Ą�ų����}���*��p'�^W̋��<�3u�'#O	iU#�����8Ɖ��eX[ ���@ �j>�=��;������խ�Q5ŝ�eI���;!�\����z��4�J�˦��@�˅E�U�~�C��q$k)i(��,4nPO=VMT�N@�N��xC�'�Η�j�eFK�2�� |S5p�Q�ŠT�?�u]g�9S�����)n���5���=�ݎ�g�<�F[ծ� ,u��J5#������uZ�E��')�o<�u�r�lQ����_�'�"��=<���n�(\�0S�p�|L���
��� ���!��e\vTp���\X��yN]@�`������p���qUk�/Ä�H��	
�JAi}G~\Up#�
.�D��% ����C��S��ps��ۺ�����@W4A���FU� 
7��ɲO$G�	a! �z����� K��0���2�-*a)�p@Yޟ����O#qY4J�b�����	UgP�Q�N-A�n�� c/s�*�* K�!�e'�u<���^Py��R���5��H�y̦�s+g�� _m.B�gd�x�('����հ��#�F-u�"[��m?�G�m����M��ӯ��#�,n�����Ǚ��j9Ǣ[V�/#��˴�z���Hh�Ur�/��;*քD��Ɖm�F	���a?�q��'F�y�FT9�+8ܨ_�kQ�J�U���O�<x��hOY]���\��<U
��&B9P͗��!����'p(���s&{OZ���}�+�z}�cG8l�V�n����.#��Ȕ9
P[�ꕻ��\�X��5�J��(ԡe��{�E)���D�@c�� or��P^}�J]aqO`����9n��	'kH��ɨZW����%�T1�pgq(��OD����O2אV�B9��S�u�D̍S�Z��������v�w�׼�*Zzb��e���F����T�ʁ: ��%��h�9���6�N`���'ݐD4���=��gl��ǔ��N��)��=��/]��21@(���A�x�K'�Qn`���d �n�LYՕpP��n����A����9�č>���U�k� �n�z��\�҃��@�`䅓�u�1|ĵA�x���[&Y�Mk�Ӻҗ.��n����_�h�Z�u����,�m���q5����[?�Hǥ�p��bR�c��4��5�TKJbUY���gt�9x�9on{�:ǁ*�+:�g��0L��n�F�i    �,-�"�i�(�D�Mp^�',)=�Ι0�us�9n��]u��B��-o\���/�\�C�q��@Ŵ����B��왴�-
�T��C*b�7�w�!�����Kd���HS�Yn��W�7Y��5{ T��p��ʙ]�&�=���@�*���k�*�혡
��]m ���U�d�Ҝ���#��[Ç�v��AL�I(�0Ď�6Ds��0��;��a/���9�ZȺP)U_�!N}��2��M zf����[J��t�
�s�]�7ԑG��L[2f ��(ǭ.o�!��Yz������ �Kҍ�'��x	�\�� P=�n%�n�N�f]8�/�_"}�%�Ljer��8����H�f�����B��Uy�c�����ml��xN��hQ�+��o$�Ps���������<���Qb\�l|Qi������jC�	���X���h#�qG�&�e��7K]D������cp�ʴU]�l��8��{�H�!7�3��
�L����;Ѳ���R�fKD���8�t�@̦-׫��g���G���l�]��U�{:�d�q{�?�uR�K9�#g媍�tG��)/sO���Aj��j^F���[7���������Ɓ=�㘆�Ȩ�L�IW���R�����%2�d�ʡ�K��]>fv�U1���#��7��s�Y��E��WE��$ʘAr���b��n��"��C\��sj"%���9l�DC�K����vܾ�XN�&���j*$��_���7�egt���.�m%Me"�>p.^�+�'&��k:�@��?�5^��� �-���!qY����*�s����l���ʢC}����s�$��K�(w�29�ʇ>���}$�T���ʽA��#{���W���d+���<�i��`���GRC��R]z��$���m ��BJHn֭3�u;�M{HnW(_&��>�aL����z:�7'�5
{Wd�*��tɘ��-k��:�?��i�'� ��mۺf]Y�y�&B&�%�O���7����"Z��t�o� -��^@��3*=q�?��LG7sU9.�j6��F������J�
��2@^c�-� G�W�fu��y��c?��tcI���N4����m`�aa S��r�V �RA���4��܌jq�]ՕŇ2|���ڨޒ�
�nfq쐿��Ld��V;�o�y�p�����G:k#�����T���	H��WE�U-������W���D���, �vM {�W�!���n
���-�ёNצ�U��s�P��J��m�V������]��i~��L䒃=.e��$�u�������j#�d˶y�*7�!���NY���?n}��@T�X���Wg�n�#���	(��������Է�n 
 �H�*�
�4v��}X�����l%M���Q�l��d"aN+�58�.}aJ��%���T� &���L�G�x�ބy�-3*��
���a�qy{�#���T�ʅ{ �NK}���G2K#��FsQ-)o�|��7�fcѓ�Y[�!a������qd�J� �6�z�i��ۡ���@)OE���	W�7�leN�i8��W�? �=D��D֗�Xt+�W��fsd�9���,�r�R���<�ʆ�R�6�pھM�P��SJV�i���Zo�)��6u;��g��t�j;e��#9	`-��}�dkT	�O�=�B��Mmk�A��/�"H �;j�l�xb��n��'���a]����P\��@e��m�1����ˀ�oD�$�U�N����(��HK�daR��G�n~jp�� ������	H'���������UС��s���/�pd�?Ս��Ѹ	X�J�}`�ŵMT�DY�-��eױ+J硔�TH�	�F}�i=9�t�N92 ��wT��=�i�7u� 8!�-���sM�~�������4Bq��շ3���Q��C�5���-��zH�=���vKH�%��fU���.ӆ̣�jx7J�1��C��Y7�>x�n	�8P�����{� �d�F���rjM�����
Bh��W���8��~�X\�y#m����1��?L=]��捰�2��S ����'de..s7rwJ��"ͫR( E�u[��W�C��y��J�S��֭���#J("[�j����F�uZ�)��0%�.�n����z��L�x�����"$�[ŕ+;�~.L���djH��u�E��R�@�G��.��Fun׮����v�&:=N�l��D�^� ��!x>�6ʊV�*ys�}�Aэ�@�@�Xv��u�W9�?�g�K��퀗��5�����z88�ҧ�R�$NK���P��Ւ	��mD���g[�Vݴ/HܱM����>�v^�V�V�ʚ h���RAI$���c���ż��.�4U��m�PZ���'$���}�d˜hk�K5 |��
n�����������9����u��-p�[�&��Pָ�8�˧�4�BNZ����8�9�[����EE���z &!۞�Do�B��Meݬ�����O\�4 .��@P�	�1�+M�J!�"Hl�h�e��2Ri\h�
�����5�.�M�v��Xp��� 
9��<��e�J��moJV�`�q=���!��\��\.�%?���O[���#ɲīh£��ɇ�`я�iC�@[F	k�Y�^��}y��$�	5DHi,z��Gr_��RBYk���V ��B�}>N{O�m�(�m̉P����%ਛ�%!�<R>\������~9���*˭v�g����>U��%]SS	�k�U�~2S#1�>]�G_#��&L�t��~\������\�%�`#��ߩ*�v�>n/��~*>��#�^ֈ4Ľg�q�#k��m��w�(�O ���8&*2��M)�ם�+, ����t���
h�h�a�Z9n7iuU�z(x"��塐xwd/s�d%�ѤF�[ ��C�n}�UT� R���#U�|[@I9���Kkd��3��.厎�n��b[�ug�C�4�?���&{��,�j�+&ݗ�%wD�n����"/C`�����醤�pn7U�	���p��@d�<F(�-�n�MJ�޺N�Y��4'��YF�����L"4��J8]�R�#�cxI�Lr�- &' ӭ�)U���ҞJ�u��ƚ�M^��	Ÿ�0���	h�Mcv��b@���q�p�(�r��z+�e�3<�����@O�qm���[,r�����i�m�*L|�*w��_ �2� �j��:u��� '��%�Ѹ�4�Y�>ѓG�9�L�T�WHk�����Cb�^�B��'��k\�>Y�����a$C��b;��x��Cd�߄rEK]TQ����4	�&i9h5!�^Z!寙�]�IiA-��)��)�a���sz'�!��UiݺqJ�~���,�n�d=KȘ�%�x=��x]� lB��.�Y>Lt�<Ⱦ���j���6�����h�q(����b���D�����@v}��w�}OD�7I�ʭ���p�ؗi4B�PLB9"��iܑ`waؓ8��l @����a�sw���J�%�NF9�{�BT-7 i�u;)��!�m�@�|���3�J9�]�?�dAm#
��r����B�}�(�b��(�%#՞P�Q���T�|@��3�0�ȭ0����n݅qO7��2=:���?,c����2S��l�.�ԡ�C醠��D���hͭ�~�ڱŕ�t#Qb�o�^�J��Ul��;�)B`sk s(]��~J8�����@�ɋ�TI!���KZ&O�Z�����և�F��$C"�uR�6�-���|�#ټ��QMʹ�:�^��P�Ѻ�ܟ
Ǉ���wRp�������������_�������`����f�:���y��$@&+��WBe�u[�� 'qI����m8�h ��&o���>�D 	(R�FC�V:�$?���t����x���3�DھɄd�8-�m���w �e`g�L�� ߢ��jQx5<{�*��d%��(��n����#��K�O�)"�v�d�6���/	w��fC CܸE�B�����&T&bG��fq�l�\7�xv�?�H�N��@�ܪl�u��    
�*82�4�JUl��Q�A���Vj�:��Ď=x2�B�o��d*�=����S�M&$��l�uS���5�n �n��C^{7\5�e��;�����MM�>bg"v�l� �tN��Mi���>��q��*P:	��F���˜�RI��F��+�Z&�B�=�:4+�;G�x!��n�:�P� �'Yo�H�����^}�j�,�It���zKn{v�N9LDMj!М��SĐ4`l"���[Ƹ���Ɠ/^wd%%�ޚ���q�����=�=�_���2���@*b`ߓ'��@�ӲQ�rH�,)��Hp����sIΈ:�~r|��,;:��h ���)�o#��=`&[��Z+tww�v�~��ӱ��rJK[Gʧ\�=Md�ܵŔ�iV㋈�AO���N���]�\�ݩˈ�ۥ�4���;U2ɳߠ����.�2�C��V���.�4�����3��E����Ɖ��#&�@�������i���%n�$A L�]ޯ�s���"@����{�r��/i�g�9~�BM��p.���r]Η��/��Q!�l�+P�F��)���c���xZ�� ��$o��o�P/�n��U�l�<%@d��e�Qx	����%:57\�Կ����Ld��]�8����������A�M+�c]4}}i~Q�\4uP���Wfd�� '�ꫀ�b T���G(R���T�
�m�\�K3{^0v�ǛĜW#�4u+���Ȟ�!�H�L,����Ցe�|��GB<)d�%F���=Bi	� Q8rP�	��	zM�82��T�{�KIn��� t���mI�䪋��04��G[���#�0m�|����a"tB�#W�C*�Ή�6�#:��zP_ZV)��an�X��.��p��F�����}� x{X�8h�\�5p�ʛ�j�ߥ���[�K'�A�be��)�9�)���Ң���u��?C�'2)����U��v'�59�9 }Ja��$�5�PRG�čI�ӥ���ݔ�{)tI�R�+B5�ZNzd�\�q�d�\����:9��ˇ'R�sFXۨ�VB@@
���	~(�"(�kV���v�n}G�Ex��U�7�#��$0z�)�l}EȜN�ws�[�h3�@V+'	�e���¸I�$UU�:r�4]��(�|��0�d�8P�I Q�z��8�8�=�����Qf]5�����tY%���FԲ�9�t�d2k �ҷ��+�45�d�ut�8���m5P�[� ��ot�\Y�@���`b]���O�8�tD3��6V�ν��|�?�9,'�9ŝ���P��w�2�q|�c牼� �j'�*��үFX}�dF��Q�_�;�p �G�J�k&�w9״�4M����p#Ue)��	)Vi�;��������9$!)��+v@����ˡ�A-<��+�<#��ŧ{@T�
õhZ������Y$\��(�i�����b/d!2y>�J��k��\<;@NG93Zr�uS�/�,Tع�l�ؔ����J˻�x�<Nd	š�9�Z�_��Ͱ��;:.:sp�tU1ԏp����B0�s��kW�>6ٳ�0��6i�i�Y'^i�f�-G��?���P̵(T/�C1�}�W4�T����`�TI��'��ą�f�R�T�i����/���C�@]2	$��W��*��p��vT�ؐ�T�G��?�9�-��4�v櫭�?�"�˒74,���¸�8s6���Oķ4YD�����<�@l���JnDG+�����8E�p ��p��4���m���M�7q�MT7Y�(�_�0Ғg41�E&Ύh�J4�ťJ^y�y�{FsU�F��
" ����^���\���ԤD��k��1 ����.�7Uz�~b8�!�Jn4G9�*\��G]���$>�X��Ƭ�e�d�+!�*C�䭪j�/�o@ُq����sF܆�]n�g���>D��\���U�K��>��=��L�S����iǾ�L��Ȕ���]8��q��=ՠġ7��b�@��0����I�<𡜶FU�������ƓPI\������c�Ճ��LAT��i�	�d_��q�����;�u���`�m[v=4�\)�u�ֻ_�ɗX���~� $_�k�S��~�qڇLS^+�e��|5�� 0z��v:HD
��q�"�ˀ�e=�}���ԍ�������

�;nO��qp�H-�ʜ<�}����u��������ԑd��]ݛ�����G�QH�����RiS��� �u�f�~{���
q,���U���<�}��Rx.#��K8�1aMr����9��ԍ����e�LsB"g��
M�o��E��8Q�|�خ�S�ZM�:���[:��J�Ht�n��·��Ȟᶍt���ٟp�vm��s'��M����gm��>��^z�c��x	
��⋩jSbxc�<��:�*��)�����[�6 
�R`])֠T\���қL[�uncVY4	�u9�a�z&a �9ۺ�y��'*),��S�ߨ�)�:��}@uI4�nN�W�ͣ_ ���2�����|��_��}Yy��t��ƒn+���X4TzvQ�q���I��i���l���g��� *q��M�[BQ�aO����h�V�
5�>@�$��[�FWU�����x8D��[�/�_�6i�nP���3�Je���o�q��,�"���Z
S�e��n
>�0����2TS�����p0a�H��T&lh����B�V����L�,{��@���$8֫���rd�P<�]��Do� -ҞV��gv�G�\�vw�cM}CHn���T}m�D�VjŲC�����$6Oq��kvU��� �q`��G*�R}5u��9슮3\{2��tS�b�slA<��-ͭw����Q��8v�}��H)�X��Zỷ}��t��t��m���3����y�r��C�h�����3�+����8S���u�*Ͼ���r�
�B�:y�<��_ئ%׬TP�Q��E�"�@�[���F����F�ՀK>�)d�g+��o*��2���3�q�(�\4��g��?eu坎"n��r�
��g����m�x�k�q`_���q�	���oI����G�;��B%���E�r�^��t(*it$�VC֗��r��sܱ�i�,dn�P��V�N��h
  s?��$7(�k��{���#ŉl-�pmO�c��e��4Q�[�i�&�%�K����@��������K�?R�8%���K�W�B�W?��j$��l4+�ge]�G�'H%�!�-U���l�+�����ryC�{�w�����R/��=n�Γ !���j)�[��p�!Pu��r݉*_�rd�>d:{�""�VF�k���Cfߋ��D�����Mm!� 5Q�B�ك�=���<�K<��M�P׵��0R�Vi��!��.yHd#��Q�Q�����G��g2�6�"�W��T.�@�u}�"C�3�F8W�8�E���>��8�(���m}"D��C�Ӷ?��
)�s�+��E5��Au��۵U����Q��>����m�"[W�� З��>L!�"Ŀ������֓��v5��I�F�������#���;�ƈ�F*G��l\��(Ϳ���R�*�<V�Y][�qη)Br�h�L���(i �Wuۗe�#޳?�)j@%��3i��]��v��8��t��/�l |B�re�����p�qWT��8��)�1�]{�*���h*[c[ͥ�uvt�6a��.�U#�ץ�㑻��SBR&:y���'�29C���p�j{�RA�P��Zke���#��\����dZ\:��V�8���n��7�F�����ZIo_�ɳ������-�4���q�n�~3��#�ڭ��zO�؋���F%Ҭ^[i�=�t��q��$T-��t�Oݚ4��-�
+f3nW����-Qv���D�_ f�B_Ҫ�Q��q{��nT�lU�S%Y���ه��@�͈�Z)!"U�_dkp'k��q´�Z%�܄N$��8n��VS�-k�͐Ӟ���jFh��,�kLz9��I%>��m����*��찁|�C���E�X�,���r�CtK+V8-Q�d    U�E�ȷ?
�&�J���m\��~H��ը�l�G���
��En{2!-���-WH��H��T��`"q�!_��yF���n��i����ٮn��xd��=�gsc�Fb�#�k��;\����#Bt���kq�V#�����~�ҬP�xM����D�Ϲ���l�lp�OBh:�du�>�F��؍���@P����;�����O�a�Wk!��ܾ(��a��J	UǄYn.�[��fN���Z�W�F�9챯�7�ܐ�I.|��L�v	���d|�}�ʼ�UFk^� .�@���2E*�.i�O^��ul:��m�F���iAS;��;�%h�����j�2áۨ�\*�ݬ���g]@��i���.c�9�}B��n �є$��ڴ��Z�X�ʞ��{:�
��lZ�Z��8k"�d=�y�洗�C���u;�#-!.��o��C:Nq��s|����J;��XIy� �"C!Is�5ײuv�E���wt�ex�Jig�-w�����I��ͥ"�z�F�g�����������d�Q�#9W5���7�#���h8e��n��rhO��n�΃�j��m4rU��:Hh�㇙��(��N+�p�7�ƈ[��~��q7Z�P��n����V��cz����jԋQR�rğ��@�z�a����p�>���g�| 7�}	�  ԭ<���G��:�6-!�8��k:�Y�&�ge�~YY �Kc�B����s�� �Vס#���m��dB"���_b�C��O��T�P�NR[�_C�y���}�cnA@�Rɉ�k���R	��PIS�p��ۺQ�	p\��54@ p��=��X��]�����I*�ߍ�����Q���V��GS
5�V�xGu[��h4��غp�Q:�f�����lP���J��θH��e�&���C��ƚ�"%�+=�9n��6��wd�[H�h��4`"ޖЭjt �����Z"4�Mu�ݿ���=��l<�,�q�W��M�{vy�Jbn�U��<�=���i
#����P�\�8�d/�F~���z5\��]��fTbe�����B�]���6X���)�#]c�'����u�r͞���h�t�ؒ��}�v�����@e\�%�4��:� ���"�e�ȓP�j�9�P��`e�H3���ҙ�����U���7�|�4�|S;5�!#��]�Y�ڑn�-ek�����*�=���d�r���2Al�J���嘠��ՃA�u�n�=�ڱ��<Q9�hߍ�]��J����>bѭ�����)��TƵ-z|p]}=/�%�.���Q�2\�VŦ��q���H�t��v�ՃO��@'��>7͉���@�e l�����"�&'�%>�iOs�Q�����V%����)�P�Ȭ���U�q�g:�|BU�#�F��X�P����m��#H����f ��{��@v�y��-�j�x=�e�3%�`dZ8��r�Cq�������[������D*D��E!e����A8����N�tPm7M�g�+IB�;���t5��.W���m�]�te��8sje�ۜ�fv�Hq3e˙֢Stu��ֱcO��B�)��m�-��C���i��$��~��j���<�m��&B�)C�M�j���K.'�6đl	X�-|���m(��q5�mO����m�E$��	7k�#�u����ZS�s����g&&c�sB�s�Ǘ�y�Xn��9��dO/	ʁ{�����9ڵ����\�?q�/�M�Y�*
\�xF����w4�	'�F�k�;����g [�����[7g�X��c�mK�T�ʖ�t]eJ]�)"i���A�P��N�����=����u�鸬U�? ��_�Ð�DޱB!��G��z(�Bw��5(����n9H�#@<z��&��u(ޢ5�?uM�!�)����	K��Z�#�'��tq7�����V��J7��Эq9x �NuTQr�/$�[@�d��ݠTq��u���2��~��s�D (ε����m���h7�U�s��8ԛu�=�"P6���iVA��j�
y�%"��"��69�=U�Bߝ�Q+/���v�^攷T�\)8�b�)����.dj�N8��^5���އ�Άi&�ZRI�l+I��G߳��TS��Dg�:<69l�UT}7�t�T��h���F���:(0�Q�J�Ah#5|�UL�&v�#�P��z�5�V+-���0����T��x�_��c���+�=��F9�U[�gE��2��L�Sd��Us��0���s؅��TS��V�޿O\��U7UHc�r�*_��g?|.�B�`���*x�!��J�x��B����"%����!G,�'2x��d;^�]wĕMd�ז5xS1���R`ix��	.[k�e���� �P��N-*)�fe	]zd� 2����VX(�ܵ_��ç�霒��P7�e�x���{�["��V�E��:��&���K1Sq<���m�I��o^w����nJ67�V��R�n�A-Nf�a�S��]N����'����B'����(ЬRӻ�G$辇L�h�p�mV}�4�(z�6���l#��3�WY��cr�l�1J�����y�t�Ѣc���L�T�*dp�z6��j*'������C���Y�$��׹���+�#���2�78��u�{�	�W�\6D�X���r�p�ˮ�R1Օ�L����E[�o�H���Zl,�5�],9#���;A\(GZ�TC�t�yq�ϟ�(�	���M�'{���eQ@Ң�|�P��dP'M�L� 8)4R*6g�4�s!��F)��k���� � ���M3�j7J��T@ݣ�z�&$��~��a,�'���c>�w��&ے?�Bȅ�N��$/.��a����	8@�F�bQ^SQxH�r�'���2��Xsi�L�B���y��t���'�a�M}}*������ ��h?�$��<�m��P;&����?a�-ox��{�M܁���R���R՟H6�L�#�ڹ�LD%V��<�mH=�\��9U��H�<��!�4� ĳPiK�k���~$�eZ5
����p�-�#Q[7;��\��7s���� J4��UR0¢��>��"*�48٪�`E�г�4��v-Pl-�ӎ���Yj�C=y���W��)m������\Y��#zvފ�4լ�]��M5����g/!S��a�_�w�ָ���dI��� ��{�����Q�z΍��qe���Ft�KSx���ڡ?��l�A�jz�cO�9��M[Wr��\֨��] �i��d�8���y���>|��q�!*��y$#���)�ӉN�������*�#	���)A��E�������QBi��F@�&�z��P���c�⣡�Դ�9r�q�<�)��Le�[#xS9$�i�C � Vd��N.Wٲ����g�l�*�(E��m6�ۭ��5��[;�PӚf}�!��<�NyF-,::�TB+W�B�s���G$KM1T��V�PV��k���{$3��z��	@mI>ơCF�S��]$2T��jܦ���逛oK7��Qq8W�q��)���%6%���Z��_J�t�Qg�r��d�1x�h:'dS��G�N	;;�Z"3�Ѹk��<�\�nǟdZx���)�*��&�]�h^�SO�]PIX͛�w,|��N�ـ��v� ����8��#��n������pk��O�D�q�B��i��9�����c���j뜵����c�-'��L5�*<�b]:f�j����1*�iHnڵ��J��w"�[���j����n� �bo�Q8�H9�	������9��$���8�(�Z�Q~*��1LS�[�RFB6�[�_����L��׿����a/����BU-��"���Z���r��� ��^��5)���R�Ҥ�+G`w駏s$3°�t"k�����U]�g�! Q7�������#��W*���p�8�vr�OZJ�q����V�:<���޳�0�t�S�/I��P���S�J��$� P ު*&����Ode�j0�]����о�$����̋�Y����T����x�Z'* )�? �	  ���DF%��&p�\�����=vd3i� n�����e8Htl{+��ve��1B�T�{�a	�GԜ�� w���a�l���z<��mw�8�x�ҙ��gB��Ѣ�G<�����&mI��v哙_���}9��9 C�W���0�f(��/���Hj�h ��ZZaDu�;�M����o%j%;Ŀ�%�q~�-F��5m��NG�gӁl�0��Cd*�~D�Ԍc�'�z�FC(=j��<�~]��S-�(��^N�U͋�5�%DF2zT�M�Pu�=��Ȼ0P���5���^q����_$
M���tV�~f˸��GU)��!-_S+j�ŏ@�/�2k��҆��tX���XC9���T��$)�"Z��̡�^��\�2�#������%��U6yAU���;�'��$T� ��o���*:�~�
ܡ�}��C�[�G2g�d�� �x��2��>�vd{�
�W��@��J������^���V����o	�Ȗ��!�K��8`��7���J�m+�9nQw�=�9�XH#���Yѷ=A���.}n�#Kn�ș�S�����D�|a�h�XS���8�{��D�(�TЖ6Gv�������p(GL���i�T),d�~��˪��|\Fx��[�PH�R�T��U̶C��Ӑ&���V;n�4�.m=ǟtD_���R�T��#�g�q�ɠ�l���8y�n��a�"f(aGDR詏u0�#��z����jU~���O9ҩ{@m��4|e��DU��Pࣅ��ikS������-�����BkxM-D�Ln�&#�p��0����m�C�i^� �?���.�7$!2�)�t�_����2��3P��"@���C���	���\�v� ��F�Ě�rk����8�����bsR�˭�x�>�-�pW%��M�P���8�� +.��N��N����e�ӭ�r[R�}�)u�!�|��
���ZS;��X�M|�qU�S�k�\�B��Y"���H�V^čG��+~z�i�V;�
)���"{NHk����B@��S޳+?��J�A�WSm�u����I����oQ�^�ɏ�u�7�q�0 -۶J��mD��}L㺺M��)[��jax�����Ⱥ]�Hm��{��Ⱦ�ρ�ϭX)i�ڠ���_�'��t�P���á���V�[�$$�*"{�	6��>�D�g�Ƣ��/��x`��G��E�������B��H�	�U��\���a��\��6}���.�qO�����
]$ւ�� d��d�B��v���}5��d���
%�*�������S�� �j8I���^� /'w��ڔ9�\㬨������Q ���)Lj�C")A)�}{X��H>�5Y�Ue%a�vd/�̏��P_�^�>����˚h��Ѩ�׭o��5���f
�E��z�D���r"��F�F�Y���(~�#U�G�Vȳ��֗a<2x�9-dw���T�?'� ��ȴ�[�Z$����r`x��H	P�⿪����b���l� H�P5,_o�n�v��|敀o��^%���^��9�(:JQ�5���x?��<М�����٭l*�X�����e$���ܺp5�m�.R�OdZ[H�iNs���.M�>}ğT׍�ж�$3 U"�qC���(��Y)� l�BL3UD ����{�w`�i]�#QCQ"c�{���|~OY;�W��J�>��8���F�S�E!R⪯�=���6C>@|d�_X������PHҁ��.v�F�k�B��j��2�7���ߓ'3�Dgpnt}�Gt�c�i��@����5��֕V�F�cZ�7�� k��㍭k@��G#"�&�tʭ�O$?����8����& ���i&K(rQv�*%�;l�MNi85�	2���VW��q��Ly��0m�L���r�1m%O^E��:�M�R�M���e(��~d?|7}�<Si� H���^ɊeI�%��!�Dl��m��t�r�����[$�Occ�!X)���W���B�&kx�P@����& �XY���BT=i�ڹ��b�?.H�&3oE���:������/|O(S�D� �]���NtJi����UG��RgQ[Y��jӨ*M|q����#�U��A \���h���}]�mO���t[�2^�;����%�]�#�xB�깶�)P�={(0��(Vj电�!��p��=������D{"'\a�[�4j�hl��v(=����\+����eW�Iv;Ԑ��n(�j�P�_�[��׸# R8�! %@�Q�gWh�4P:�#oSV!�������ʹ��I.[.�V�����s"�F�h��z��z]�2;���Z�J�Y���O(����=�qw�D[��.�Y%����]A��-�Tw�+�\cy��,]>s�t~7�6[�����)�)�<[)Totk���E�焿a�;���-5�AU"+�=�(1��M�;�V��.'�E6We���6�s�U�������������      -   �   x��M
�0��=��b�HBэ+Q��6�iā&-���m��B��0$���,>&٦����q��
��ZX�\`��9�t�ZEP)�e�+��U��Սg�F*^�zl�{7���ͧ���=�9~V�+�*��֟?"����&��rsZ�0!4&�}��5ش���Mg�C��H��B4��V�Q��bJ[�hO'R���Ę���P^�+�bD��|.����	,�,�     