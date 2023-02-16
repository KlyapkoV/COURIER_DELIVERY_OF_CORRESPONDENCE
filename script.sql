-- Для доступа к данным в базе данных должен быть создан пользователь 
-- логин: netocourier
-- пароль: ********
-- права: полный доступ на схему public, к information_schema и pg_catalog права только на чтение,
   	      -- предусмотреть доступ к иным схемам, если они нужны. 

CREATE ROLE netocourier WITH PASSWORD ('пароль')

GRANT ALL PRIVILEGES ON SCHEMA public TO netocourier

GRANT SELECT ON information_schema, pg_catalog TO netocourier


CREATE EXTENSION "uuid-ossp";


CREATE TYPE status AS ENUM('В очереди', 'Выполняется', 'Выполнено', 'Отменен')


CREATE TABLE account (
                       id uuid PRIMARY KEY-- PK
                       , "name" VARCHAR (50) NOT NULL --название контрагента
                     )  

                     
CREATE TABLE contact (
                       id uuid PRIMARY KEY
                       , last_name VARCHAR (50) NOT NULL--фамилия контакта
                       , first_name VARCHAR (50) NOT NULL--имя контакта
                       , account_id uuid REFERENCES account (id) --id контрагента
                     ) 
                     
                     
 
CREATE TABLE "user" (
                    id uuid PRIMARY KEY
                    , last_name VARCHAR (50) NOT NULL --фамилия сотрудника
                    , first_name VARCHAR (50) NOT NULL --имя сотрудника
                    , dismissed BOOLEAN --уволен или нет, значение по умолчанию "нет"
                   )                      

                  

CREATE TABLE courier (
                      id uuid PRIMARY KEY
                      , from_place VARCHAR (50) NOT NULL --откуда
                      , where_place VARCHAR (50) NOT NULL --куда
                      , "name" VARCHAR (50) NOT NULL --название документа
                      , account_id uuid REFERENCES account (id) --id контрагента
                      , contact_id uuid REFERENCES contact (id) --id контакта 
                      , description TEXT--описание
                      , user_id uuid REFERENCES "user" (id) --id сотрудника отправителя
                      , status status DEFAULT 'В очереди' -- статусы 'В очереди', 'Выполняется', 'Выполнено', 'Отменен'. По умолчанию 'В очереди'
                      , created_date DATE DEFAULT NOW()--дата создания заявки, значение по умолчанию now()
                     )
                     

-- Процедура, для возможности тестирования приложения (заполнение таблиц сущностями)
CREATE PROCEDURE insert_test_data (value INTEGER) AS $$
BEGIN 
     LOOP
         INSERT INTO account (id, "name")
         VALUES (
                 (SELECT gen_random_uuid ())
                 , (SELECT REPEAT(SUBSTRING('абвгдеёжзийклмнопрстуфхцчшщьыъэюя',1,(RANDOM()*33)::INTEGER),(RANDOM()*1)::INTEGER) )
                );
        IF (SELECT COUNT (*) FROM account) =  value * 1 THEN
        EXIT;  -- выход из цикла
        END IF;
     END LOOP;
     LOOP 
         INSERT INTO contact (id, last_name, first_name, account_id)
         VALUES (
                 (SELECT gen_random_uuid () )
                 , ( SELECT REPEAT(SUBSTRING('абвгдеёжзийклмнопрстуфхцчшщьыъэюя',1,(RANDOM()*33)::INTEGER),(RANDOM()*1)::INTEGER) )
                 , ( SELECT REPEAT(SUBSTRING('абвгдеёжзийклмнопрстуфхцчшщьыъэюя',1,(RANDOM()*33)::INTEGER),(RANDOM()*1)::INTEGER) )
                 , ( SELECT id
                     FROM account
                     ORDER BY RANDOM ()
                    LIMIT 1 )
                );
        IF (SELECT COUNT (*) FROM contact) =  value * 2 THEN
        EXIT;  -- выход из цикла
        END IF;      
     END LOOP;
     LOOP 
         INSERT INTO "user" (id, last_name, first_name, dismissed)
         VALUES (
                 ( SELECT gen_random_uuid () )
                 , ( SELECT REPEAT(SUBSTRING('абвгдеёжзийклмнопрстуфхцчшщьыъэюя',1,(RANDOM()*33)::INTEGER),(RANDOM()*1)::INTEGER) )
                 , ( SELECT REPEAT(SUBSTRING('абвгдеёжзийклмнопрстуфхцчшщьыъэюя',1,(RANDOM()*33)::INTEGER),(RANDOM()*1)::INTEGER) ) 
                 , ( SELECT ((random()*1)::INTEGER)::BOOLEAN )
                );
        IF (SELECT COUNT (*) FROM "user") =  value * 1 THEN
        EXIT;  -- выход из цикла
        END IF;
     END LOOP;  
     LOOP 
         INSERT INTO courier (id, from_place, where_place, "name", account_id
                             , contact_id, description, user_id 
                             , status, created_date)
         VALUES ( 
                 ( SELECT gen_random_uuid ()  )
                 , ( SELECT REPEAT(SUBSTRING('абвгдеёжзийклмнопрстуфхцчшщьыъэюя',1,(RANDOM()*33)::INTEGER),(RANDOM()*1)::INTEGER) )
                 , ( SELECT REPEAT(SUBSTRING('абвгдеёжзийклмнопрстуфхцчшщьыъэюя',1,(RANDOM()*33)::INTEGER),(RANDOM()*1)::INTEGER) ) 
                 , ( SELECT REPEAT(SUBSTRING('абвгдеёжзийклмнопрстуфхцчшщьыъэюя',1,(RANDOM()*33)::INTEGER),(RANDOM()*1)::INTEGER) )
                 , ( SELECT id
                     FROM account
                     ORDER BY RANDOM ()
                     LIMIT 1 )
                 , ( SELECT id
                     FROM contact
                     ORDER BY RANDOM ()
                     LIMIT 1 )
                 , ( SELECT REPEAT(SUBSTRING('абвгдеёжзийклмнопрстуфхцчшщьыъэюя',1,(RANDOM()*33)::INTEGER),(RANDOM()*1)::INTEGER) )
                 , ( SELECT id
                     FROM "user"
                     ORDER BY RANDOM ()
                     LIMIT 1 )
                 , ( SELECT (array['В очереди', 'Выполняется', 'Выполнено', 'Отменен'])[floor(random() * 4 + 1)] )::status
                 , ( SELECT  NOW() - INTERVAL '1 day' * ROUND(RANDOM() * 1000) AS timestamp )
                );
         IF (SELECT COUNT (*) FROM courier) =  value * 5 THEN
         EXIT;  -- выход из цикла
         END IF;
     END LOOP; 
END;
$$ LANGUAGE plpgsql;


-- Вызов процедуры
CALL insert_test_data ('10')


-- Процедура, которая удаляет тестовые данные из отношений
CREATE PROCEDURE erase_test_data () AS $$
BEGIN 
	 TRUNCATE account, contact, "user" , courier ;
END;
$$ LANGUAGE plpgsql


-- Вызов процедуры удаления тестовых данных
CALL erase_test_data ()



-- Функция по добавлению новой записи о заявке на курьера
CREATE PROCEDURE add_courier(from_placeIN VARCHAR (50), where_placeIN VARCHAR (50), nameIN VARCHAR (50)
                             , account_idIN uuid, contact_idIN uuid, descriptionIN TEXT
                             , user_idIN uuid) AS $$
BEGIN
	 INSERT INTO courier ( id
	                      , from_place, where_place, "name"
                          , account_id, contact_id, description
                          , user_id) 
	 VALUES ( ( SELECT gen_random_uuid ()  )
	         ,from_placeIN , where_placeIN, nameIN
             , account_idIN, contact_idIN, descriptionIN
             , user_idIN);
END;
$$ LANGUAGE plpgsql


-- Вызов процедуры на добавление новой записи о заявке на курьера
CALL add_courier('Иваново', 'Москва', 'Сидоров'
                 , '1cb39b10-bad4-4c87-a72b-75ea7a646cd5', '0bf1e314-e320-4e65-acd6-5a068e8dc68b', 'Шкаф'
                 , '9b282a49-5ce3-44e1-acdd-a6aaff2de4d3') 


                
-- Функция get_courier(), которая возвращает таблицу
CREATE FUNCTION get_courier () RETURNS TABLE (id uuid
                                             , from_place VARCHAR (50) --откуда
                                             , where_place VARCHAR (50) --куда
                                             , "name" VARCHAR (50) --название документа
                                             , account_id uuid --id контрагента
                                             , account VARCHAR (50)
                                             , contact_id uuid  --id контакта 
                                             , contact TEXT
                                             , description TEXT --описание
                                             , user_id uuid  --id сотрудника отправителя
                                             , "user"  TEXT
                                             , status status  -- статусы 'В очереди', 'Выполняется', 'Выполнено', 'Отменен'. По умолчанию 'В очереди'
                                             , created_date DATE) AS $$      
#variable_conflict use_column                                            
BEGIN
	 RETURN QUERY
	 SELECT cou.id--идентификатор заявки
	       , from_place --откуда
	       , where_place --куда
           , "name" --название документа
           , account_id --идентификатор контрагента
           , account --название контрагента
           , contact_id --идентификатор контакта
           , contact --фамилия и имя контакта через пробел
           , description --описание
           , user_id --идентификатор сотрудника
           , "user" --фамилия и имя сотрудника через пробел
           , status --статус заявки
           , created_date --дата создания заявки
     FROM courier AS cou JOIN (
                               SELECT id AS id
                                     , "name" AS account
                               FROM account
                              ) AS acc ON cou.account_id = acc.id
                         JOIN (
                               SELECT id AS id
                                     , CONCAT (last_name,' ',first_name) AS contact
                               FROM contact
                              ) AS con ON cou.contact_id = con.id
                         JOIN (
                               SELECT id AS id
                                     , CONCAT (last_name,' ',first_name) AS "user"
                               FROM "user"
                              ) AS us ON cou.user_id = us.id
     ORDER BY status, created_date DESC;
END;
$$ LANGUAGE plpgsql;

-- Вызов функции
SELECT * FROM get_courier ();


-- Процедура изменяющая статус заявки
CREATE PROCEDURE change_status (status_ status, id_ uuid) AS $$
#variable_conflict use_column 
BEGIN
	 UPDATE courier
	 SET status = status_
	 WHERE id = id_;
END;
$$ LANGUAGE plpgsql;

-- Вызов процедуры, изменяющей статус заявки
CALL change_status('В очереди','8e9d455e-40a6-4ecd-acc8-300b9c037018')



-- Функция get_users(), которая возвращает таблицу согласно следующей структуры: фамилия и имя сотрудника через пробел 
CREATE FUNCTION get_users() RETURNS SETOF TEXT AS $$
BEGIN 
	 RETURN QUERY
	 SELECT DISTINCT CONCAT (last_name,' ',first_name) AS users
     FROM "user"
     WHERE dismissed = TRUE
     ORDER BY users ;
END;
$$ LANGUAGE plpgsql;

-- Вызов функции
SELECT * FROM get_users();



-- Функция get_accounts(), которая возвращает список контрагентов
CREATE FUNCTION get_accounts() RETURNS SETOF VARCHAR (50) AS $$
#variable_conflict use_column 
BEGIN 
	 RETURN QUERY
	 SELECT DISTINCT "name"
     FROM account
     ORDER BY "name" ;
END;
$$ LANGUAGE plpgsql;


-- Вызов функции, которая возвращает список контрагентов
SELECT * FROM get_accounts();



-- Функция get_contacts(account_id_ uuid), которая возвращает таблицу с контактами переданного контрагента согласно  contact --фамилия и имя контакта через пробел 
CREATE FUNCTION get_contacts(account_id_ uuid) RETURNS SETOF TEXT AS $$
BEGIN
	 IF account_id_ IS NULL THEN RETURN QUERY SELECT 'Выберите контрагента';
	 ELSEIF account_id_ IN (SELECT account_id
                            FROM courier) THEN RETURN QUERY SELECT DISTINCT CONCAT (last_name,' ',first_name) AS con
	                                                        FROM contact
                                                            WHERE account_id = account_id_
                                                            ORDER BY con;
     ELSE RAISE EXCEPTION 'ОШИБКА ВВОДА ДАННЫХ';
	 END IF;
END;
$$ LANGUAGE plpgsql;


-- Вызов функции
SELECT * FROM --get_contacts('00c203d4-3d56-4856-91c0-d932908a620d') ;
                get_contacts (NULL)


                

                
-- Создание представления                
CREATE VIEW courier_statistic AS ( 
SELECT DISTINCT account_id
               , acc."name" AS account
               , COUNT (cou.id) OVER (PARTITION BY account_id) AS count_courier
               , COUNT (cou.id) FILTER (WHERE status = 'Выполнено') OVER (PARTITION BY account_id) AS count_complete
               , COUNT (cou.id) FILTER (WHERE status = 'Отменен') OVER (PARTITION BY account_id) AS count_canceled
               , percent_relative_prev_month
               , COUNT (where_place) OVER (PARTITION BY account_id) AS count_where_place
               , COUNT (con.id) OVER (PARTITION BY account_id) AS count_contact
               , cansel_user_array
FROM courier AS cou JOIN account AS acc ON cou.account_id = acc.id
                    JOIN (
                          SELECT id
                          FROM contact
                         ) AS con ON cou.contact_id  = con.id
                    JOIN (
                          SELECT DISTINCT account_id, ARRAY_AGG (user_id) FILTER (WHERE status = 'Отменен') AS cansel_user_array
                          FROM courier
                          GROUP BY account_id
                         ) AS arr USING (account_id)
                    JOIN (
                          SELECT *
                          FROM (
                                SELECT account_id
                                      , dat
                                      , "Количество заказов"
                                      , CONCAT (ROUND(100 * ("Количество заказов" / LAG("Количество заказов") OVER (ORDER BY dat) - 1)), '%') AS percent_relative_prev_month
                                      , ROW_NUMBER () OVER (PARTITION BY account_id ORDER BY dat DESC) AS "Нумерация строк внутри account_id"
                                FROM (
                                      SELECT account_id
                                            , TO_CHAR (created_date, 'YYYY-MM') AS dat
                                            , COUNT(id) "Количество заказов"
                                      FROM courier
                                      GROUP BY account_id, created_date
                                     ) AS  table_1
                                ORDER BY account_id
                               ) AS  table_2
                          WHERE "Нумерация строк внутри account_id" = 1
                         ) AS RET USING (account_id)
GROUP BY account_id
        , acc."name"
        , cou.id
        , con.id
        , percent_relative_prev_month
        , cansel_user_array)
                